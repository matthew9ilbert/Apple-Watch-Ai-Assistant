import Foundation
import HealthKit
import CoreLocation
import UserNotifications
import Speech
import Contacts
import Photos
import AVFoundation
import HomeKit

class PermissionsManager: NSObject, ObservableObject {
    static let shared = PermissionsManager()
    
    // MARK: - Published Properties
    
    @Published var healthKitAuthorized = false
    @Published var locationAuthorized = false
    @Published var notificationsAuthorized = false
    @Published var microphoneAuthorized = false
    @Published var speechRecognitionAuthorized = false
    @Published var contactsAuthorized = false
    @Published var homeKitAuthorized = false
    
    // MARK: - Private Properties
    
    private let healthStore = HKHealthStore()
    private let locationManager = CLLocationManager()
    private let analyticsManager = AnalyticsManager.shared
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        locationManager.delegate = self
        checkCurrentAuthorizationStatus()
    }
    
    // MARK: - Status Checking
    
    private func checkCurrentAuthorizationStatus() {
        checkHealthKitAuthorization()
        checkLocationAuthorization()
        checkNotificationAuthorization()
        checkMicrophoneAuthorization()
        checkSpeechRecognitionAuthorization()
        checkContactsAuthorization()
        checkHomeKitAuthorization()
    }
    
    // MARK: - HealthKit Authorization
    
    func requestHealthKitAuthorization() async throws {
        // Define the health data types we want to read and write
        let typesToShare: Set<HKSampleType> = [
            HKQuantityType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!
        ]
        
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.activitySummaryType(),
            HKObjectType.workoutType()
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            await MainActor.run {
                healthKitAuthorized = true
            }
            analyticsManager.logEvent("health_permission_granted",
                                    category: .settings)
        } catch {
            analyticsManager.logError(error,
                                    code: "HEALTH_AUTH",
                                    severity: .error)
            throw PermissionError.healthKitDenied
        }
    }
    
    private func checkHealthKitAuthorization() {
        let authStatus = healthStore.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .heartRate)!)
        healthKitAuthorized = authStatus == .sharingAuthorized
    }
    
    // MARK: - Location Authorization
    
    func requestLocationAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func checkLocationAuthorization() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationAuthorized = true
        default:
            locationAuthorized = false
        }
    }
    
    // MARK: - Notifications Authorization
    
    func requestNotificationAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        
        do {
            let granted = try await center.requestAuthorization(options: options)
            await MainActor.run {
                notificationsAuthorized = granted
            }
            if granted {
                analyticsManager.logEvent("notification_permission_granted",
                                        category: .settings)
            }
        } catch {
            analyticsManager.logError(error,
                                    code: "NOTIFICATION_AUTH",
                                    severity: .error)
            throw PermissionError.notificationsDenied
        }
    }
    
    private func checkNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Microphone Authorization
    
    func requestMicrophoneAuthorization() async throws {
        guard await AVAudioSession.sharedInstance().hasPermissionToRecord() else {
            throw PermissionError.microphoneDenied
        }
        
        await MainActor.run {
            microphoneAuthorized = true
            analyticsManager.logEvent("microphone_permission_granted",
                                    category: .settings)
        }
    }
    
    private func checkMicrophoneAuthorization() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.microphoneAuthorized = granted
            }
        }
    }
    
    // MARK: - Speech Recognition Authorization
    
    func requestSpeechRecognitionAuthorization() async throws {
        let status = await SFSpeechRecognizer.authorizationStatus()
        
        switch status {
        case .authorized:
            await MainActor.run {
                speechRecognitionAuthorized = true
                analyticsManager.logEvent("speech_permission_granted",
                                        category: .settings)
            }
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            await MainActor.run {
                speechRecognitionAuthorized = granted
            }
        default:
            throw PermissionError.speechRecognitionDenied
        }
    }
    
    private func checkSpeechRecognitionAuthorization() {
        speechRecognitionAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
    }
    
    // MARK: - Contacts Authorization
    
    func requestContactsAuthorization() async throws {
        let store = CNContactStore()
        
        do {
            try await store.requestAccess(for: .contacts)
            await MainActor.run {
                contactsAuthorized = true
                analyticsManager.logEvent("contacts_permission_granted",
                                        category: .settings)
            }
        } catch {
            analyticsManager.logError(error,
                                    code: "CONTACTS_AUTH",
                                    severity: .error)
            throw PermissionError.contactsDenied
        }
    }
    
    private func checkContactsAuthorization() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        contactsAuthorized = status == .authorized
    }
    
    // MARK: - HomeKit Authorization
    
    func requestHomeKitAuthorization() async throws {
        let homeManager = HMHomeManager()
        
        do {
            try await withCheckedThrowingContinuation { continuation in
                homeManager.addHomeManagerDelegate(self) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            await MainActor.run {
                homeKitAuthorized = true
                analyticsManager.logEvent("homekit_permission_granted",
                                        category: .settings)
            }
        } catch {
            analyticsManager.logError(error,
                                    code: "HOMEKIT_AUTH",
                                    severity: .error)
            throw PermissionError.homeKitDenied
        }
    }
    
    private func checkHomeKitAuthorization() {
        // HomeKit authorization status can only be determined by attempting to use it
        homeKitAuthorized = false
    }
    
    // MARK: - Batch Authorization
    
    func requestAllPermissions() async {
        do {
            // Request permissions in parallel
            async let healthKit = requestHealthKitAuthorization()
            async let notifications = requestNotificationAuthorization()
            async let microphone = requestMicrophoneAuthorization()
            async let speech = requestSpeechRecognitionAuthorization()
            async let contacts = requestContactsAuthorization()
            async let homeKit = requestHomeKitAuthorization()
            
            // Location authorization is handled through delegate
            requestLocationAuthorization()
            
            // Wait for all async requests to complete
            try await (healthKit, notifications, microphone, speech, contacts, homeKit)
            
            analyticsManager.logEvent("all_permissions_requested",
                                    category: .settings,
                                    parameters: [
                                        "health_authorized": "\(healthKitAuthorized)",
                                        "location_authorized": "\(locationAuthorized)",
                                        "notifications_authorized": "\(notificationsAuthorized)",
                                        "microphone_authorized": "\(microphoneAuthorized)",
                                        "speech_authorized": "\(speechRecognitionAuthorized)",
                                        "contacts_authorized": "\(contactsAuthorized)",
                                        "homekit_authorized": "\(homeKitAuthorized)"
                                    ])
        } catch {
            analyticsManager.logError(error,
                                    code: "PERMISSION_BATCH",
                                    severity: .error)
        }
    }
    
    // MARK: - Permission Status
    
    var allPermissionsGranted: Bool {
        healthKitAuthorized &&
        locationAuthorized &&
        notificationsAuthorized &&
        microphoneAuthorized &&
        speechRecognitionAuthorized &&
        contactsAuthorized &&
        homeKitAuthorized
    }
    
    func getMissingPermissions() -> [PermissionType] {
        var missing: [PermissionType] = []
        
        if !healthKitAuthorized { missing.append(.healthKit) }
        if !locationAuthorized { missing.append(.location) }
        if !notificationsAuthorized { missing.append(.notifications) }
        if !microphoneAuthorized { missing.append(.microphone) }
        if !speechRecognitionAuthorized { missing.append(.speechRecognition) }
        if !contactsAuthorized { missing.append(.contacts) }
        if !homeKitAuthorized { missing.append(.homeKit) }
        
        return missing
    }
    
    enum PermissionType: String {
        case healthKit = "Health"
        case location = "Location"
        case notifications = "Notifications"
        case microphone = "Microphone"
        case speechRecognition = "Speech Recognition"
        case contacts = "Contacts"
        case homeKit = "HomeKit"
        
        var description: String {
            switch self {
            case .healthKit:
                return "Access to health and fitness data"
            case .location:
                return "Location access for weather and reminders"
            case .notifications:
                return "Send notifications and alerts"
            case .microphone:
                return "Voice command recognition"
            case .speechRecognition:
                return "Convert speech to text"
            case .contacts:
                return "Access contacts for messaging"
            case .homeKit:
                return "Control smart home devices"
            }
        }
    }
    
    enum PermissionError: LocalizedError {
        case healthKitDenied
        case locationDenied
        case notificationsDenied
        case microphoneDenied
        case speechRecognitionDenied
        case contactsDenied
        case homeKitDenied
        
        var errorDescription: String? {
            switch self {
            case .healthKitDenied:
                return "Health data access denied"
            case .locationDenied:
                return "Location access denied"
            case .notificationsDenied:
                return "Notification permission denied"
            case .microphoneDenied:
                return "Microphone access denied"
            case .speechRecognitionDenied:
                return "Speech recognition access denied"
            case .contactsDenied:
                return "Contacts access denied"
            case .homeKitDenied:
                return "HomeKit access denied"
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension PermissionsManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorization()
    }
}

// MARK: - Extensions

extension AVAudioSession {
    func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
