import Foundation
import HealthKit
import HomeKit
import CoreLocation
import UserNotifications
import Speech
import Contacts
import AVFoundation
import StoreKit
import CloudKit
import WatchConnectivity

class CapabilityChecker: ObservableObject {
    static let shared = CapabilityChecker()
    
    // MARK: - Published Properties
    
    @Published private(set) var capabilities: Capabilities = Capabilities()
    @Published private(set) var healthSupport = HealthSupport()
    @Published private(set) var locationSupport = LocationSupport()
    @Published private(set) var notificationSupport = NotificationSupport()
    @Published private(set) var speechSupport = SpeechSupport()
    @Published private(set) var homeSupport = HomeSupport()
    @Published private(set) var syncSupport = SyncSupport()
    @Published private(set) var contactsSupport = ContactsSupport()
    @Published private(set) var storeSupport = StoreSupport()
    
    // MARK: - Support Structures
    
    struct Capabilities {
        var healthKit = false
        var homeKit = false
        var locationServices = false
        var notifications = false
        var speechRecognition = false
        var contacts = false
        var camera = false
        var microphone = false
        var photoLibrary = false
        var cloudKit = false
        var watchConnectivity = false
        var siri = false
        var backgroundRefresh = false
    }
    
    struct HealthSupport {
        var isAvailable = false
        var isAuthorized = false
        var workoutTypes: Set<HKWorkoutActivityType> = []
        var readTypes: Set<HKObjectType> = []
        var writeTypes: Set<HKSampleType> = []
        var backgroundDelivery = false
    }
    
    struct LocationSupport {
        var isAvailable = false
        var isAuthorized = false
        var accuracyAuthorization: CLAccuracyAuthorization = .reducedAccuracy
        var allowsBackgroundLocationUpdates = false
        var significantLocationChangeMonitoringAvailable = false
    }
    
    struct NotificationSupport {
        var isAuthorized = false
        var allowedSettings: UNAuthorizationOptions = []
        var currentSettings: UNNotificationSettings?
        var supportsCriticalAlerts = false
        var supportsTimeSensitive = false
    }
    
    struct SpeechSupport {
        var isAvailable = false
        var isAuthorized = false
        var supportedLocales: [Locale] = []
        var onDeviceRecognitionAvailable = false
    }
    
    struct HomeSupport {
        var isAvailable = false
        var isAuthorized = false
        var primaryHome: HMHome?
        var accessoryTypes: Set<String> = []
        var serviceTypes: Set<String> = []
    }
    
    struct SyncSupport {
        var cloudKitAvailable = false
        var watchConnectivityAvailable = false
        var backgroundRefreshEnabled = false
        var pushNotificationsEnabled = false
        var iCloudAvailable = false
    }
    
    struct ContactsSupport {
        var isAvailable = false
        var isAuthorized = false
        var supportsContactsUI = false
        var containerIdentifier: String?
    }
    
    struct StoreSupport {
        var inAppPurchaseEnabled = false
        var canMakePayments = false
        var subscriptionsEnabled = false
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        checkCapabilities()
    }
    
    // MARK: - Capability Checking
    
    func checkCapabilities() {
        checkHealthCapabilities()
        checkLocationCapabilities()
        checkNotificationCapabilities()
        checkSpeechCapabilities()
        checkHomeCapabilities()
        checkSyncCapabilities()
        checkContactsCapabilities()
        checkStoreCapabilities()
        updateOverallCapabilities()
    }
    
    private func checkHealthCapabilities() {
        let healthStore = HKHealthStore()
        
        healthSupport.isAvailable = HKHealthStore.isHealthDataAvailable()
        
        if healthSupport.isAvailable {
            // Check authorization for required types
            let types = requiredHealthKitTypes()
            healthStore.getRequestStatusForAuthorization(toShare: types.write, read: types.read) { status, error in
                DispatchQueue.main.async {
                    self.healthSupport.isAuthorized = (status == .unnecessary)
                    self.healthSupport.readTypes = types.read
                    self.healthSupport.writeTypes = types.write
                    self.healthSupport.workoutTypes = self.supportedWorkoutTypes()
                }
            }
        }
    }
    
    private func checkLocationCapabilities() {
        let locationManager = CLLocationManager()
        
        locationSupport.isAvailable = CLLocationManager.locationServicesEnabled()
        locationSupport.isAuthorized = [.authorizedAlways, .authorizedWhenInUse].contains(locationManager.authorizationStatus)
        locationSupport.accuracyAuthorization = locationManager.accuracyAuthorization
        locationSupport.allowsBackgroundLocationUpdates = locationManager.allowsBackgroundLocationUpdates
        locationSupport.significantLocationChangeMonitoringAvailable = CLLocationManager.significantLocationChangeMonitoringAvailable()
    }
    
    private func checkNotificationCapabilities() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationSupport.isAuthorized = settings.authorizationStatus == .authorized
                self.notificationSupport.currentSettings = settings
                self.notificationSupport.supportsCriticalAlerts = settings.criticalAlertSetting == .enabled
                self.notificationSupport.supportsTimeSensitive = settings.timeSensitiveSetting == .enabled
            }
        }
    }
    
    private func checkSpeechCapabilities() {
        speechSupport.isAvailable = SFSpeechRecognizer.authorizationStatus() != .restricted
        speechSupport.isAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
        speechSupport.supportedLocales = SFSpeechRecognizer.supportedLocales()
        
        if #available(watchOS 10.0, *) {
            speechSupport.onDeviceRecognitionAvailable = SFSpeechRecognizer.isOnDeviceRecognitionAvailable()
        }
    }
    
    private func checkHomeCapabilities() {
        homeSupport.isAvailable = HMHomeManager.isHomeKitAvailable()
        
        let homeManager = HMHomeManager()
        homeSupport.primaryHome = homeManager.primaryHome
        homeSupport.isAuthorized = homeManager.primaryHome != nil
        
        // Collect supported accessory and service types
        if let home = homeManager.primaryHome {
            homeSupport.accessoryTypes = Set(home.accessories.map { $0.category.categoryType })
            homeSupport.serviceTypes = Set(home.accessories.flatMap { accessory in
                accessory.services.map { $0.serviceType }
            })
        }
    }
    
    private func checkSyncCapabilities() {
        syncSupport.cloudKitAvailable = CKContainer.default().accountStatus == .available
        syncSupport.watchConnectivityAvailable = WCSession.isSupported()
        syncSupport.backgroundRefreshEnabled = UIApplication.shared.backgroundRefreshStatus == .available
        syncSupport.pushNotificationsEnabled = notificationSupport.isAuthorized
        syncSupport.iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil
    }
    
    private func checkContactsCapabilities() {
        contactsSupport.isAvailable = true
        contactsSupport.isAuthorized = CNContactStore.authorizationStatus(for: .contacts) == .authorized
        contactsSupport.supportsContactsUI = true
        contactsSupport.containerIdentifier = CNContactStore().defaultContainerIdentifier()
    }
    
    private func checkStoreCapabilities() {
        storeSupport.inAppPurchaseEnabled = true
        storeSupport.canMakePayments = SKPaymentQueue.canMakePayments()
        storeSupport.subscriptionsEnabled = true
    }
    
    private func updateOverallCapabilities() {
        capabilities.healthKit = healthSupport.isAvailable && healthSupport.isAuthorized
        capabilities.homeKit = homeSupport.isAvailable && homeSupport.isAuthorized
        capabilities.locationServices = locationSupport.isAvailable && locationSupport.isAuthorized
        capabilities.notifications = notificationSupport.isAuthorized
        capabilities.speechRecognition = speechSupport.isAvailable && speechSupport.isAuthorized
        capabilities.contacts = contactsSupport.isAvailable && contactsSupport.isAuthorized
        capabilities.cloudKit = syncSupport.cloudKitAvailable
        capabilities.watchConnectivity = syncSupport.watchConnectivityAvailable
        capabilities.backgroundRefresh = syncSupport.backgroundRefreshEnabled
    }
    
    // MARK: - Helper Methods
    
    private func requiredHealthKitTypes() -> (read: Set<HKObjectType>, write: Set<HKSampleType>) {
        var readTypes: Set<HKObjectType> = []
        var writeTypes: Set<HKSampleType> = []
        
        // Reading types
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(heartRate)
        }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            readTypes.insert(steps)
        }
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            readTypes.insert(distance)
        }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypes.insert(energy)
        }
        
        // Writing types
        if let workout = HKObjectType.workoutType() {
            writeTypes.insert(workout)
        }
        
        return (readTypes, writeTypes)
    }
    
    private func supportedWorkoutTypes() -> Set<HKWorkoutActivityType> {
        return [
            .running,
            .walking,
            .cycling,
            .swimming,
            .hiking,
            .yoga,
            .functionalStrengthTraining,
            .traditionalStrengthTraining,
            .highIntensityIntervalTraining
        ]
    }
}

// MARK: - Public Interface

extension CapabilityChecker {
    func requiresSetup() -> Bool {
        return !capabilities.healthKit ||
               !capabilities.notifications ||
               !capabilities.locationServices
    }
    
    func missingCapabilities() -> [String] {
        var missing: [String] = []
        
        if !capabilities.healthKit { missing.append("Health") }
        if !capabilities.homeKit { missing.append("HomeKit") }
        if !capabilities.locationServices { missing.append("Location") }
        if !capabilities.notifications { missing.append("Notifications") }
        if !capabilities.speechRecognition { missing.append("Speech Recognition") }
        if !capabilities.contacts { missing.append("Contacts") }
        
        return missing
    }
    
    func canUseFeature(_ feature: AppFeature) -> Bool {
        switch feature {
        case .health:
            return capabilities.healthKit
        case .home:
            return capabilities.homeKit
        case .location:
            return capabilities.locationServices
        case .voice:
            return capabilities.speechRecognition
        case .sync:
            return capabilities.cloudKit && capabilities.watchConnectivity
        case .background:
            return capabilities.backgroundRefresh
        }
    }
    
    enum AppFeature {
        case health
        case home
        case location
        case voice
        case sync
        case background
    }
}
