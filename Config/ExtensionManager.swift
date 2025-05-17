import Foundation
import Intents
import IntentsUI
import WatchKit
import UserNotifications

class ExtensionManager: NSObject {
    static let shared = ExtensionManager()
    
    // MARK: - Properties
    
    private let shortcutProvider = ShortcutProvider()
    private let intentHandler = IntentHandler()
    private let analyticsManager = AnalyticsManager.shared
    
    // MARK: - Extension Configuration
    
    func configureExtensions() {
        configureSiriIntegration()
        configureShortcuts()
        configureNotifications()
        configureWatchExtension()
        configureWidgetExtension()
    }
    
    // MARK: - Siri Configuration
    
    private func configureSiriIntegration() {
        INPreferences.requestSiriAuthorization { status in
            switch status {
            case .authorized:
                self.setupSiriVocabulary()
                self.donateInitialInteractions()
            case .denied, .restricted, .notDetermined:
                self.analyticsManager.logEvent(
                    "siri_authorization_failed",
                    category: .settings,
                    parameters: ["status": "\(status.rawValue)"]
                )
            @unknown default:
                break
            }
        }
    }
    
    private func setupSiriVocabulary() {
        // Add custom vocabulary
        let vocabularyStrings = loadVocabularyStrings()
        
        INVocabulary.shared.setVocabularyStrings(
            Set(vocabularyStrings.workoutTypes),
            of: .workoutActivityName
        )
        
        INVocabulary.shared.setVocabularyStrings(
            Set(vocabularyStrings.homeActions),
            of: .homeAutomationAction
        )
        
        INVocabulary.shared.setVocabularyStrings(
            Set(vocabularyStrings.timeExpressions),
            of: .temporalEventName
        )
    }
    
    private func loadVocabularyStrings() -> VocabularyStrings {
        guard let path = Bundle.main.path(forResource: "Extension", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let vocabulary = dict["IntentVocabulary"] as? [String: [String]] else {
            return VocabularyStrings(workoutTypes: [], homeActions: [], timeExpressions: [])
        }
        
        return VocabularyStrings(
            workoutTypes: vocabulary["WorkoutTypes"] ?? [],
            homeActions: vocabulary["HomeActions"] ?? [],
            timeExpressions: vocabulary["TimeExpressions"] ?? []
        )
    }
    
    private struct VocabularyStrings {
        let workoutTypes: [String]
        let homeActions: [String]
        let timeExpressions: [String]
    }
    
    // MARK: - Shortcuts Configuration
    
    private func configureShortcuts() {
        // Register suggested shortcuts
        let shortcuts = shortcutProvider.suggestedShortcuts()
        INVoiceShortcutCenter.shared.setShortcutSuggestions(shortcuts)
        
        // Register app shortcuts
        registerAppShortcuts()
    }
    
    private func registerAppShortcuts() {
        guard let path = Bundle.main.path(forResource: "Extension", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let shortcuts = dict["AppShortcuts"] as? [[String: String]] else {
            return
        }
        
        for shortcutInfo in shortcuts {
            guard let name = shortcutInfo["ShortcutName"],
                  let description = shortcutInfo["ShortcutDescription"],
                  let phrase = shortcutInfo["SuggestedInvocationPhrase"] else {
                continue
            }
            
            let activity = NSUserActivity(activityType: "com.watchassistant.shortcut.\(name)")
            activity.title = name
            activity.userInfo = ["shortcutName": name]
            activity.isEligibleForSearch = true
            activity.isEligibleForPrediction = true
            activity.persistentIdentifier = name
            activity.suggestedInvocationPhrase = phrase
            
            activity.registerAsShortcut { error in
                if let error = error {
                    self.analyticsManager.logError(error,
                                                 code: "SHORTCUT_REGISTER",
                                                 severity: .error)
                }
            }
        }
    }
    
    // MARK: - Notifications Configuration
    
    private func configureNotifications() {
        // Register notification categories
        let categories = createNotificationCategories()
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }
    
    private func createNotificationCategories() -> Set<UNNotificationCategory> {
        var categories: Set<UNNotificationCategory> = []
        
        // Workout category
        let workoutCategory = UNNotificationCategory(
            identifier: "WORKOUT",
            actions: [
                UNNotificationAction(
                    identifier: "START_WORKOUT",
                    title: "Start",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "POSTPONE_WORKOUT",
                    title: "Postpone",
                    options: .destructive
                )
            ],
            intentIdentifiers: ["StartWorkoutIntent"],
            options: []
        )
        categories.insert(workoutCategory)
        
        // Reminder category
        let reminderCategory = UNNotificationCategory(
            identifier: "REMINDER",
            actions: [
                UNNotificationAction(
                    identifier: "COMPLETE_REMINDER",
                    title: "Complete",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "SNOOZE_REMINDER",
                    title: "Snooze",
                    options: .foreground
                )
            ],
            intentIdentifiers: ["SetReminderIntent"],
            options: []
        )
        categories.insert(reminderCategory)
        
        // Home automation category
        let homeCategory = UNNotificationCategory(
            identifier: "HOME_AUTOMATION",
            actions: [
                UNNotificationAction(
                    identifier: "EXECUTE_AUTOMATION",
                    title: "Execute",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "SKIP_AUTOMATION",
                    title: "Skip",
                    options: .destructive
                )
            ],
            intentIdentifiers: ["ControlHomeDeviceIntent"],
            options: []
        )
        categories.insert(homeCategory)
        
        return categories
    }
    
    // MARK: - Watch Extension Configuration
    
    private func configureWatchExtension() {
        // Configure complications
        configureComplications()
        
        // Configure background tasks
        configureBackgroundTasks()
    }
    
    private func configureComplications() {
        // Register complication descriptors
        let descriptors = createComplicationDescriptors()
        WKExtension.shared().complicationDescriptors = descriptors
    }
    
    private func createComplicationDescriptors() -> [WKComplicationDescriptor] {
        return [
            WKComplicationDescriptor(
                identifier: "WorkoutComplication",
                displayName: "Workout",
                supportedFamilies: [
                    .modularSmall,
                    .modularLarge,
                    .utilitarianSmall,
                    .utilitarianLarge
                ]
            ),
            WKComplicationDescriptor(
                identifier: "WeatherComplication",
                displayName: "Weather",
                supportedFamilies: [
                    .modularSmall,
                    .modularLarge,
                    .utilitarianSmall
                ]
            ),
            WKComplicationDescriptor(
                identifier: "HomeComplication",
                displayName: "Home Control",
                supportedFamilies: [
                    .modularSmall,
                    .circularSmall
                ]
            )
        ]
    }
    
    private func configureBackgroundTasks() {
        // Register background tasks
        WKExtension.shared().registerBackgroundTasks()
    }
    
    // MARK: - Widget Extension Configuration
    
    private func configureWidgetExtension() {
        // Configure widget kinds
        let widgetKinds = [
            "WorkoutWidget",
            "WeatherWidget",
            "HomeControlWidget",
            "ReminderWidget"
        ]
        
        // Register timeline providers
        registerTimelineProviders(for: widgetKinds)
    }
    
    private func registerTimelineProviders(for kinds: [String]) {
        for kind in kinds {
            // Register timeline provider for each widget kind
            TimelineManager.shared.registerProvider(for: kind)
        }
    }
}

// MARK: - WKExtension Extensions

extension WKExtension {
    func registerBackgroundTasks() {
        // Register refresh task
        let refreshTask = WKApplicationRefreshBackgroundTask(identifier: "RefreshTask")
        self.scheduleBackgroundRefresh(
            withPreferredDate: Date().addingTimeInterval(3600),
            userInfo: nil
        ) { error in
            if let error = error {
                AnalyticsManager.shared.logError(error,
                                               code: "BACKGROUND_REFRESH",
                                               severity: .error)
            }
        }
        
        // Register URLSession task
        let urlSessionTask = WKURLSessionRefreshBackgroundTask(identifier: "URLSessionTask")
        self.scheduleBackgroundRefresh(
            withPreferredDate: Date().addingTimeInterval(1800),
            userInfo: nil
        ) { error in
            if let error = error {
                AnalyticsManager.shared.logError(error,
                                               code: "BACKGROUND_URL",
                                               severity: .error)
            }
        }
    }
}

// MARK: - Timeline Management

class TimelineManager {
    static let shared = TimelineManager()
    
    func registerProvider(for kind: String) {
        // Register timeline provider for widget kind
    }
}
