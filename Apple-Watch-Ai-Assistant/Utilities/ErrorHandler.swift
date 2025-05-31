import Foundation
import OSLog

class ErrorHandler {
    static let shared = ErrorHandler()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: AppConstants.Config.bundleId, category: "errors")
    private let analyticsManager = AnalyticsManager.shared
    private let privacyConfig = PrivacyConfig.shared
    
    // Track error frequency
    private var errorCounts: [String: Int] = [:]
    private var lastErrorTime: [String: Date] = [:]
    
    // MARK: - Error Types
    
    enum AppError: LocalizedError {
        case network(NetworkError)
        case data(DataError)
        case permission(PermissionError)
        case sync(SyncError)
        case health(HealthError)
        case home(HomeError)
        case integration(IntegrationError)
        case security(SecurityError)
        
        var errorDescription: String? {
            switch self {
            case .network(let error):
                return "Network Error: \(error.localizedDescription)"
            case .data(let error):
                return "Data Error: \(error.localizedDescription)"
            case .permission(let error):
                return "Permission Error: \(error.localizedDescription)"
            case .sync(let error):
                return "Sync Error: \(error.localizedDescription)"
            case .health(let error):
                return "Health Error: \(error.localizedDescription)"
            case .home(let error):
                return "Home Error: \(error.localizedDescription)"
            case .integration(let error):
                return "Integration Error: \(error.localizedDescription)"
            case .security(let error):
                return "Security Error: \(error.localizedDescription)"
            }
        }
        
        var code: String {
            switch self {
            case .network:
                return AppConstants.ErrorCodes.networkError
            case .data:
                return AppConstants.ErrorCodes.storageError
            case .permission:
                return AppConstants.ErrorCodes.permissionError
            case .sync:
                return AppConstants.ErrorCodes.syncError
            case .health:
                return AppConstants.ErrorCodes.healthError
            case .home:
                return "HOME_ERR"
            case .integration:
                return "INT_ERR"
            case .security:
                return "SEC_ERR"
            }
        }
        
        var severity: ErrorSeverity {
            switch self {
            case .network(let error):
                return error.severity
            case .data(let error):
                return error.severity
            case .permission(let error):
                return error.severity
            case .sync(let error):
                return error.severity
            case .health(let error):
                return error.severity
            case .home(let error):
                return error.severity
            case .integration(let error):
                return error.severity
            case .security(let error):
                return error.severity
            }
        }
    }
    
    enum ErrorSeverity: Int {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4
        
        var logType: OSLogType {
            switch self {
            case .debug:
                return .debug
            case .info:
                return .info
            case .warning:
                return .default
            case .error:
                return .error
            case .critical:
                return .fault
            }
        }
    }
    
    // MARK: - Error Handling
    
    func handle(_ error: AppError,
                file: String = #file,
                function: String = #function,
                line: Int = #line) {
        // Log error
        logError(error, file: file, function: function, line: line)
        
        // Track error frequency
        trackErrorOccurrence(error)
        
        // Report to analytics if enabled
        if privacyConfig.analyticsEnabled {
            reportError(error)
        }
        
        // Handle based on severity
        switch error.severity {
        case .debug, .info:
            // Just log
            break
            
        case .warning:
            // Log and notify if frequent
            checkErrorFrequency(error)
            
        case .error:
            // Log, notify, and attempt recovery
            handleRecoverableError(error)
            
        case .critical:
            // Log, notify, and take immediate action
            handleCriticalError(error)
        }
    }
    
    private func logError(_ error: AppError,
                         file: String,
                         function: String,
                         line: Int) {
        let logMessage = """
            Error: \(error.localizedDescription)
            Code: \(error.code)
            Location: \(file):\(line) - \(function)
            """
        
        logger.log(level: error.severity.logType, "\(logMessage)")
    }
    
    private func trackErrorOccurrence(_ error: AppError) {
        let count = (errorCounts[error.code] ?? 0) + 1
        errorCounts[error.code] = count
        lastErrorTime[error.code] = Date()
    }
    
    private func reportError(_ error: AppError) {
        analyticsManager.logError(error,
                                code: error.code,
                                severity: error.severity)
    }
    
    private func checkErrorFrequency(_ error: AppError) {
        let errorCode = error.code
        guard let count = errorCounts[errorCode],
              let lastTime = lastErrorTime[errorCode] else {
            return
        }
        
        // Check if error is occurring frequently
        if count > 5 && lastTime.timeIntervalSinceNow < -300 { // 5 times in 5 minutes
            notifyFrequentError(error, count: count)
        }
    }
    
    private func handleRecoverableError(_ error: AppError) {
        // Attempt recovery based on error type
        switch error {
        case .network:
            attemptNetworkRecovery()
        case .data:
            attemptDataRecovery()
        case .sync:
            attemptSyncRecovery()
        default:
            break
        }
    }
    
    private func handleCriticalError(_ error: AppError) {
        // Handle critical errors
        switch error {
        case .security:
            performSecurityShutdown()
        case .health:
            resetHealthMonitoring()
        default:
            performEmergencyRecovery()
        }
    }
    
    // MARK: - Error Recovery
    
    private func attemptNetworkRecovery() {
        // Implement network recovery
    }
    
    private func attemptDataRecovery() {
        // Implement data recovery
    }
    
    private func attemptSyncRecovery() {
        // Implement sync recovery
    }
    
    private func performSecurityShutdown() {
        // Implement security shutdown
    }
    
    private func resetHealthMonitoring() {
        // Implement health monitoring reset
    }
    
    private func performEmergencyRecovery() {
        // Implement emergency recovery
    }
    
    // MARK: - Notifications
    
    private func notifyFrequentError(_ error: AppError, count: Int) {
        let notification = ErrorNotification(
            title: "Frequent Error Detected",
            message: "\(error.localizedDescription) occurred \(count) times",
            type: .warning
        )
        NotificationManager.shared.scheduleNotification(notification)
    }
}

// MARK: - Supporting Types

struct ErrorNotification {
    let title: String
    let message: String
    let type: NotificationType
    
    enum NotificationType {
        case info
        case warning
        case error
    }
}

// MARK: - Specific Error Types

enum NetworkError: LocalizedError {
    case connectionFailed
    case timeout
    case serverError
    case unauthorized
    
    var severity: ErrorSeverity {
        switch self {
        case .connectionFailed, .timeout:
            return .warning
        case .serverError:
            return .error
        case .unauthorized:
            return .critical
        }
    }
}

enum DataError: LocalizedError {
    case corrupted
    case notFound
    case saveFailed
    case invalidFormat
    
    var severity: ErrorSeverity {
        switch self {
        case .notFound:
            return .warning
        case .invalidFormat:
            return .warning
        case .saveFailed:
            return .error
        case .corrupted:
            return .critical
        }
    }
}

enum PermissionError: LocalizedError {
    case denied
    case restricted
    case notDetermined
    
    var severity: ErrorSeverity {
        switch self {
        case .notDetermined:
            return .info
        case .denied:
            return .warning
        case .restricted:
            return .error
        }
    }
}

enum SyncError: LocalizedError {
    case deviceUnavailable
    case dataConflict
    case syncFailed
    
    var severity: ErrorSeverity {
        switch self {
        case .deviceUnavailable:
            return .warning
        case .dataConflict:
            return .warning
        case .syncFailed:
            return .error
        }
    }
}

enum HealthError: LocalizedError {
    case dataUnavailable
    case sensorError
    case calibrationRequired
    
    var severity: ErrorSeverity {
        switch self {
        case .calibrationRequired:
            return .warning
        case .dataUnavailable:
            return .error
        case .sensorError:
            return .critical
        }
    }
}

enum HomeError: LocalizedError {
    case deviceOffline
    case actionFailed
    case hubUnavailable
    
    var severity: ErrorSeverity {
        switch self {
        case .deviceOffline:
            return .warning
        case .actionFailed:
            return .error
        case .hubUnavailable:
            return .critical
        }
    }
}

enum IntegrationError: LocalizedError {
    case connectionFailed
    case authenticationFailed
    case apiError
    
    var severity: ErrorSeverity {
        switch self {
        case .connectionFailed:
            return .warning
        case .authenticationFailed:
            return .error
        case .apiError:
            return .error
        }
    }
}

enum SecurityError: LocalizedError {
    case unauthorized
    case compromised
    case encryptionFailed
    
    var severity: ErrorSeverity {
        switch self {
        case .unauthorized:
            return .error
        case .encryptionFailed:
            return .critical
        case .compromised:
            return .critical
        }
    }
}
