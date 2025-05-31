import Foundation
import UIKit

/// App-wide configuration and constants
enum AppConstants {
    // MARK: - App Configuration
    
    enum Config {
        static let appName = "WatchAssistant"
        static let bundleId = "com.watchassistant"
        static let appGroup = "group.com.watchassistant.shared"
        static let iCloudContainer = "iCloud.com.watchassistant"
        
        static let minimumWatchOSVersion = "9.0"
        static let minimumIOSVersion = "16.0"
        
        enum Environment {
            case development
            case staging
            case production
            
            static var current: Environment {
                #if DEBUG
                return .development
                #else
                return .production
                #endif
            }
        }
        
        static var isDebugMode: Bool {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }
    }
    
    // MARK: - API Configuration
    
    enum API {
        static var baseURL: URL {
            switch Config.Environment.current {
            case .development:
                return URL(string: "https://dev-api.watchassistant.com")!
            case .staging:
                return URL(string: "https://staging-api.watchassistant.com")!
            case .production:
                return URL(string: "https://api.watchassistant.com")!
            }
        }
        
        static let version = "v1"
        static let timeout: TimeInterval = 30
        static let maxRetries = 3
        
        enum Endpoints {
            static let auth = "/auth"
            static let profile = "/profile"
            static let health = "/health"
            static let weather = "/weather"
            static let shortcuts = "/shortcuts"
            static let integrations = "/integrations"
        }
        
        enum Headers {
            static let authorization = "Authorization"
            static let contentType = "Content-Type"
            static let apiKey = "X-API-Key"
            static let clientVersion = "X-Client-Version"
            static let deviceId = "X-Device-ID"
        }
    }
    
    // MARK: - Feature Flags
    
    enum Features {
        static let enableBetaFeatures = false
        static let enableCloudSync = true
        static let enableOfflineMode = true
        static let enableVoiceControl = true
        static let enableHealthKit = true
        static let enableHomeKit = true
        static let enableWeatherKit = true
        static let enableAnalytics = true
        static let enableCrashReporting = true
        
        enum Beta {
            static let enableNewUI = false
            static let enableAdvancedAutomation = false
            static let enableCustomShortcuts = false
            static let enableAIFeatures = false
        }
    }
    
    // MARK: - App Limits
    
    enum Limits {
        static let maxShortcuts = 50
        static let maxAutomations = 30
        static let maxReminders = 100
        static let maxIntegrations = 20
        static let maxHistoryDays = 30
        static let maxSyncAttempts = 3
        
        enum Cache {
            static let maxSize: Int64 = 100 * 1024 * 1024  // 100 MB
            static let maxAge: TimeInterval = 7 * 24 * 60 * 60  // 7 days
        }
        
        enum Network {
            static let maxConcurrentRequests = 4
            static let maxRequestRetries = 3
            static let requestTimeout: TimeInterval = 30
        }
    }
    
    // MARK: - UI Constants
    
    enum UI {
        static let animationDuration: TimeInterval = 0.3
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 4
        static let defaultPadding: CGFloat = 16
        static let minimumTapArea: CGFloat = 44
        
        enum Fonts {
            static let titleSize: CGFloat = 24
            static let headlineSize: CGFloat = 18
            static let bodySize: CGFloat = 16
            static let captionSize: CGFloat = 12
        }
        
        enum Colors {
            static let primary = UIColor.systemBlue
            static let secondary = UIColor.systemGray
            static let success = UIColor.systemGreen
            static let warning = UIColor.systemOrange
            static let error = UIColor.systemRed
            static let background = UIColor.systemBackground
        }
    }
    
    // MARK: - Notification Names
    
    enum Notifications {
        static let didUpdateProfile = Notification.Name("didUpdateProfile")
        static let didUpdateHealth = Notification.Name("didUpdateHealth")
        static let didUpdateWeather = Notification.Name("didUpdateWeather")
        static let didUpdateShortcuts = Notification.Name("didUpdateShortcuts")
        static let didUpdateAutomations = Notification.Name("didUpdateAutomations")
        static let didUpdateIntegrations = Notification.Name("didUpdateIntegrations")
        static let didReceiveRemoteNotification = Notification.Name("didReceiveRemoteNotification")
        static let didChangeConnectivityStatus = Notification.Name("didChangeConnectivityStatus")
    }
    
    // MARK: - UserDefaults Keys
    
    enum UserDefaultsKeys {
        static let isFirstLaunch = "isFirstLaunch"
        static let lastSyncDate = "lastSyncDate"
        static let selectedLanguage = "selectedLanguage"
        static let pushToken = "pushToken"
        static let userPreferences = "userPreferences"
        static let deviceToken = "deviceToken"
        static let authToken = "authToken"
        static let savedShortcuts = "savedShortcuts"
        static let healthConsent = "healthConsent"
        static let locationConsent = "locationConsent"
    }
    
    // MARK: - Error Constants
    
    enum ErrorCodes {
        static let networkError = "NET_ERR"
        static let authError = "AUTH_ERR"
        static let syncError = "SYNC_ERR"
        static let healthError = "HEALTH_ERR"
        static let locationError = "LOC_ERR"
        static let storageError = "STORE_ERR"
        static let permissionError = "PERM_ERR"
    }
    
    // MARK: - Analytics Events
    
    enum AnalyticsEvents {
        static let appLaunch = "app_launch"
        static let userLogin = "user_login"
        static let userLogout = "user_logout"
        static let syncCompleted = "sync_completed"
        static let shortcutCreated = "shortcut_created"
        static let shortcutExecuted = "shortcut_executed"
        static let workoutStarted = "workout_started"
        static let workoutCompleted = "workout_completed"
        static let reminderCreated = "reminder_created"
        static let messageCreated = "message_created"
        static let integrationConnected = "integration_connected"
        static let integrationDisconnected = "integration_disconnected"
    }
    
    // MARK: - Localization
    
    enum LocalizationKeys {
        static let generalError = "error.general"
        static let networkError = "error.network"
        static let permissionDenied = "error.permission_denied"
        static let tryAgain = "action.try_again"
        static let cancel = "action.cancel"
        static let done = "action.done"
        static let settings = "action.settings"
    }
    
    // MARK: - Health Constants
    
    enum Health {
        static let defaultStepGoal = 10000
        static let defaultCalorieGoal = 500.0
        static let defaultSleepGoal = 8.0
        static let defaultHeartRateRange = 60...100
        static let workoutMinDuration: TimeInterval = 60
        static let healthDataRetention: TimeInterval = 365 * 24 * 60 * 60  // 1 year
    }
    
    // MARK: - Home Automation
    
    enum Home {
        static let defaultSceneTransitionDuration: TimeInterval = 1.0
        static let maxDevicesPerRoom = 30
        static let maxScenesPerHome = 100
        static let locationTriggerRadius: CLLocationDistance = 100  // meters
    }
    
    // MARK: - Security
    
    enum Security {
        static let minimumPasswordLength = 8
        static let passwordComplexityLevel = 3  // 1-5 scale
        static let tokenRefreshInterval: TimeInterval = 60 * 60  // 1 hour
        static let maxFailedAttempts = 5
        static let lockoutDuration: TimeInterval = 300  // 5 minutes
    }
}

// MARK: - Extensions

extension AppConstants {
    static var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    static var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    static var deviceIdentifier: String {
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }
}
