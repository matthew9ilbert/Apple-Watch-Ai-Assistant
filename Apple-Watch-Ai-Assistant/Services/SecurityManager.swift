import Foundation
import Security
import LocalAuthentication
import CryptoKit

class SecurityManager {
    static let shared = SecurityManager()
    
    // MARK: - Properties
    
    private let keychainService = "com.watchassistant"
    private let analyticsManager = AnalyticsManager.shared
    private let context = LAContext()
    
    // MARK: - Security Configuration
    
    private let securityConfig = SecurityConfiguration(
        requireBiometrics: true,
        encryptData: true,
        minimumPasswordLength: 8,
        passwordComplexityRequired: true,
        autoLockTimeout: 300,  // 5 minutes
        maxFailedAttempts: 5
    )
    
    // MARK: - Authentication
    
    func authenticateUser() async throws -> Bool {
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            throw SecurityError.biometricsNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication,
                                 localizedReason: "Authenticate to access WatchAssistant") { success, error in
                if let error = error {
                    continuation.resume(throwing: SecurityError.authenticationFailed(error))
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    func validatePassword(_ password: String) -> Bool {
        guard password.count >= securityConfig.minimumPasswordLength else {
            return false
        }
        
        if securityConfig.passwordComplexityRequired {
            // Check for complexity requirements
            let hasUppercase = password.contains(where: { $0.isUppercase })
            let hasLowercase = password.contains(where: { $0.isLowercase })
            let hasNumber = password.contains(where: { $0.isNumber })
            let hasSpecial = password.contains(where: { "!@#$%^&*(),.?\":{}|<>".contains($0) })
            
            return hasUppercase && hasLowercase && hasNumber && hasSpecial
        }
        
        return true
    }
    
    // MARK: - Data Protection
    
    func encryptData(_ data: Data) throws -> Data {
        guard securityConfig.encryptData else {
            return data
        }
        
        let key = try getEncryptionKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined ?? Data()
    }
    
    func decryptData(_ data: Data) throws -> Data {
        guard securityConfig.encryptData else {
            return data
        }
        
        let key = try getEncryptionKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    // MARK: - Keychain Operations
    
    func saveToKeychain(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            try updateKeychainItem(data, forKey: key)
        } else if status != errSecSuccess {
            throw SecurityError.keychainSaveFailed(status)
        }
    }
    
    func loadFromKeychain(forKey key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw SecurityError.keychainLoadFailed(status)
        }
        
        return data
    }
    
    func deleteFromKeychain(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess {
            throw SecurityError.keychainDeleteFailed(status)
        }
    }
    
    // MARK: - Secure Storage
    
    func secureStore(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw SecurityError.invalidData
        }
        
        let encryptedData = try encryptData(data)
        try saveToKeychain(encryptedData, forKey: key)
    }
    
    func secureRetrieve(forKey key: String) throws -> String {
        let encryptedData = try loadFromKeychain(forKey: key)
        let decryptedData = try decryptData(encryptedData)
        
        guard let value = String(data: decryptedData, encoding: .utf8) else {
            throw SecurityError.invalidData
        }
        
        return value
    }
    
    // MARK: - Security Helpers
    
    private func getEncryptionKey() throws -> SymmetricKey {
        // Try to load existing key
        if let keyData = try? loadFromKeychain(forKey: "encryptionKey") {
            return SymmetricKey(data: keyData)
        }
        
        // Generate new key
        let key = SymmetricKey(size: .bits256)
        try saveToKeychain(key.withUnsafeBytes { Data($0) }, forKey: "encryptionKey")
        return key
    }
    
    private func updateKeychainItem(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        if status != errSecSuccess {
            throw SecurityError.keychainUpdateFailed(status)
        }
    }
    
    // MARK: - Security Monitoring
    
    func monitorSecurityStatus() {
        // Monitor for jailbreak
        if isDeviceJailbroken() {
            analyticsManager.logEvent(
                "security_warning",
                category: .settings,
                parameters: ["type": "jailbreak_detected"]
            )
        }
        
        // Monitor for debugging
        if isDebuggerAttached() {
            analyticsManager.logEvent(
                "security_warning",
                category: .settings,
                parameters: ["type": "debugger_detected"]
            )
        }
    }
    
    private func isDeviceJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        // Check for common jailbreak signs
        let paths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/"
        ]
        
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
        #endif
    }
    
    private func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let junk = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        assert(junk == 0, "sysctl failed")
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
}

// MARK: - Supporting Types

struct SecurityConfiguration {
    let requireBiometrics: Bool
    let encryptData: Bool
    let minimumPasswordLength: Int
    let passwordComplexityRequired: Bool
    let autoLockTimeout: TimeInterval
    let maxFailedAttempts: Int
}

enum SecurityError: LocalizedError {
    case biometricsNotAvailable
    case authenticationFailed(Error)
    case keychainSaveFailed(OSStatus)
    case keychainLoadFailed(OSStatus)
    case keychainDeleteFailed(OSStatus)
    case keychainUpdateFailed(OSStatus)
    case invalidData
    case encryptionFailed
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .biometricsNotAvailable:
            return "Biometric authentication is not available"
        case .authenticationFailed(let error):
            return "Authentication failed: \(error.localizedDescription)"
        case .keychainSaveFailed(let status):
            return "Failed to save to keychain: \(status)"
        case .keychainLoadFailed(let status):
            return "Failed to load from keychain: \(status)"
        case .keychainDeleteFailed(let status):
            return "Failed to delete from keychain: \(status)"
        case .keychainUpdateFailed(let status):
            return "Failed to update keychain item: \(status)"
        case .invalidData:
            return "Invalid data format"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        }
    }
}

// MARK: - Extensions

extension SecurityManager {
    enum KeychainKey {
        static let authToken = "authToken"
        static let refreshToken = "refreshToken"
        static let userId = "userId"
        static let deviceId = "deviceId"
        static let apiKey = "apiKey"
    }
}
