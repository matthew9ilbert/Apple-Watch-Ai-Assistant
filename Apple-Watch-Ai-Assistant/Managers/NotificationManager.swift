import UserNotifications
import HealthKit
import CoreLocation

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var notificationsEnabled = false
    @Published var healthAlertsEnabled = true
    @Published var reminderAlertsEnabled = true
    @Published var homeAutomationAlertsEnabled = true
    @Published var weatherAlertsEnabled = true
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let locationManager = CLLocationManager()
    
    init() {
        requestAuthorization()
        configureCategories()
    }
    
    func requestAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.notificationsEnabled = granted
                if let error = error {
                    print("Notification authorization error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func configureCategories() {
        // Health Alert Category
        let healthCategory = UNNotificationCategory(
            identifier: "HEALTH_ALERT",
            actions: [
                UNNotificationAction(identifier: "VIEW_DETAILS", title: "View Details", options: .foreground),
                UNNotificationAction(identifier: "DISMISS", title: "Dismiss", options: .destructive)
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        // Reminder Category
        let reminderCategory = UNNotificationCategory(
            identifier: "REMINDER",
            actions: [
                UNNotificationAction(identifier: "COMPLETE", title: "Complete", options: .foreground),
                UNNotificationAction(identifier: "SNOOZE", title: "Snooze", options: .foreground),
                UNNotificationAction(identifier: "DISMISS", title: "Dismiss", options: .destructive)
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        // Home Automation Category
        let homeCategory = UNNotificationCategory(
            identifier: "HOME_AUTOMATION",
            actions: [
                UNNotificationAction(identifier: "EXECUTE", title: "Execute", options: .foreground),
                UNNotificationAction(identifier: "SKIP", title: "Skip", options: .destructive)
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        // Weather Alert Category
        let weatherCategory = UNNotificationCategory(
            identifier: "WEATHER_ALERT",
            actions: [
                UNNotificationAction(identifier: "VIEW_FORECAST", title: "View Forecast", options: .foreground),
                UNNotificationAction(identifier: "DISMISS", title: "Dismiss", options: .destructive)
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        notificationCenter.setNotificationCategories([
            healthCategory,
            reminderCategory,
            homeCategory,
            weatherCategory
        ])
    }
    
    // MARK: - Health Notifications
    
    func scheduleHealthAlert(type: HealthAlertType, message: String) {
        guard healthAlertsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = message
        content.sound = .default
        content.categoryIdentifier = "HEALTH_ALERT"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "health_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Reminder Notifications
    
    func scheduleReminder(title: String, message: String, date: Date) {
        guard reminderAlertsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        content.categoryIdentifier = "REMINDER"
        
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "reminder_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Home Automation Notifications
    
    func scheduleHomeAutomationAlert(title: String, message: String, action: String? = nil) {
        guard homeAutomationAlertsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        if let action = action {
            content.userInfo = ["action": action]
        }
        content.sound = .default
        content.categoryIdentifier = "HOME_AUTOMATION"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "home_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Weather Notifications
    
    func scheduleWeatherAlert(condition: WeatherCondition, message: String) {
        guard weatherAlertsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Weather Alert: \(condition.description)"
        content.body = message
        content.sound = .default
        content.categoryIdentifier = "WEATHER_ALERT"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "weather_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Notification Management
    
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
    
    func cancelNotification(withIdentifier identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    // MARK: - Supporting Types
    
    enum HealthAlertType {
        case highHeartRate
        case lowHeartRate
        case irregularHeartRhythm
        case inactivity
        case goalAchieved
        case workoutSuggestion
        
        var title: String {
            switch self {
            case .highHeartRate:
                return "High Heart Rate Detected"
            case .lowHeartRate:
                return "Low Heart Rate Detected"
            case .irregularHeartRhythm:
                return "Irregular Heart Rhythm"
            case .inactivity:
                return "Time to Move!"
            case .goalAchieved:
                return "Goal Achieved!"
            case .workoutSuggestion:
                return "Workout Suggestion"
            }
        }
    }
    
    enum WeatherCondition {
        case rain
        case snow
        case extreme
        case temperature
        case storm
        
        var description: String {
            switch self {
            case .rain:
                return "Rain Expected"
            case .snow:
                return "Snow Expected"
            case .extreme:
                return "Extreme Weather"
            case .temperature:
                return "Temperature Alert"
            case .storm:
                return "Storm Warning"
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.actionIdentifier
        let notification = response.notification
        
        switch identifier {
        case "VIEW_DETAILS":
            // Handle viewing health alert details
            break
            
        case "COMPLETE":
            // Handle completing a reminder
            break
            
        case "SNOOZE":
            // Reschedule the reminder for later
            if let originalDate = notification.date {
                let newDate = Calendar.current.date(byAdding: .minute, value: 15, to: originalDate) ?? Date()
                scheduleReminder(
                    title: notification.request.content.title,
                    message: notification.request.content.body,
                    date: newDate
                )
            }
            
        case "EXECUTE":
            // Execute home automation action
            if let action = notification.request.content.userInfo["action"] as? String {
                // Handle the automation action
                print("Executing home automation action: \(action)")
            }
            
        case "VIEW_FORECAST":
            // Handle viewing weather forecast
            break
            
        case UNNotificationDefaultActionIdentifier:
            // Handle default action (notification tapped)
            break
            
        case UNNotificationDismissActionIdentifier:
            // Handle notification dismissed
            break
            
        default:
            break
        }
        
        completionHandler()
    }
}
