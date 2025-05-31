import Foundation
import SwiftUI
import Combine

class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    // MARK: - Published Properties
    
    // General Settings
    @Published var useDarkMode: Bool {
        didSet { save(.useDarkMode, useDarkMode) }
    }
    
    @Published var hapticFeedbackEnabled: Bool {
        didSet { save(.hapticFeedbackEnabled, hapticFeedbackEnabled) }
    }
    
    // Voice Assistant Settings
    @Published var voiceFeedbackEnabled: Bool {
        didSet { save(.voiceFeedbackEnabled, voiceFeedbackEnabled) }
    }
    
    @Published var voiceVolume: Double {
        didSet { save(.voiceVolume, voiceVolume) }
    }
    
    @Published var preferredVoiceGender: VoiceGender {
        didSet { save(.preferredVoiceGender, preferredVoiceGender.rawValue) }
    }
    
    @Published var preferredLanguage: String {
        didSet { save(.preferredLanguage, preferredLanguage) }
    }
    
    // Health & Fitness Settings
    @Published var dailyStepGoal: Int {
        didSet { save(.dailyStepGoal, dailyStepGoal) }
    }
    
    @Published var preferredMeasurementSystem: MeasurementSystem {
        didSet { save(.preferredMeasurementSystem, preferredMeasurementSystem.rawValue) }
    }
    
    @Published var healthMetricsToDisplay: Set<HealthMetric> {
        didSet { save(.healthMetricsToDisplay, Array(healthMetricsToDisplay.map { $0.rawValue })) }
    }
    
    @Published var workoutReminderEnabled: Bool {
        didSet { save(.workoutReminderEnabled, workoutReminderEnabled) }
    }
    
    // Notification Settings
    @Published var notificationSettings: NotificationPreferences {
        didSet { save(.notificationSettings, try? JSONEncoder().encode(notificationSettings)) }
    }
    
    // Privacy Settings
    @Published var privacySettings: PrivacyPreferences {
        didSet { save(.privacySettings, try? JSONEncoder().encode(privacySettings)) }
    }
    
    // MARK: - Enums and Types
    
    enum VoiceGender: String, CaseIterable {
        case male = "Male"
        case female = "Female"
        case neutral = "Neutral"
    }
    
    enum MeasurementSystem: String, CaseIterable {
        case metric = "Metric"
        case imperial = "Imperial"
    }
    
    enum HealthMetric: String, CaseIterable {
        case steps = "Steps"
        case heartRate = "Heart Rate"
        case calories = "Calories"
        case distance = "Distance"
        case workouts = "Workouts"
        case sleep = "Sleep"
    }
    
    struct NotificationPreferences: Codable {
        var healthAlerts: Bool
        var workoutReminders: Bool
        var weatherAlerts: Bool
        var taskReminders: Bool
        var messageNotifications: Bool
        var quietHoursEnabled: Bool
        var quietHoursStart: Date
        var quietHoursEnd: Date
    }
    
    struct PrivacyPreferences: Codable {
        var shareHealthData: Bool
        var shareWorkoutData: Bool
        var shareLocationData: Bool
        var saveVoiceCommands: Bool
        var saveMessageHistory: Bool
        var dataRetentionPeriod: Int // days
    }
    
    // MARK: - Keys Enum
    
    private enum PreferenceKey: String {
        case useDarkMode
        case hapticFeedbackEnabled
        case voiceFeedbackEnabled
        case voiceVolume
        case preferredVoiceGender
        case preferredLanguage
        case dailyStepGoal
        case preferredMeasurementSystem
        case healthMetricsToDisplay
        case workoutReminderEnabled
        case notificationSettings
        case privacySettings
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load saved preferences or use defaults
        self.useDarkMode = load(.useDarkMode) ?? false
        self.hapticFeedbackEnabled = load(.hapticFeedbackEnabled) ?? true
        self.voiceFeedbackEnabled = load(.voiceFeedbackEnabled) ?? true
        self.voiceVolume = load(.voiceVolume) ?? 0.8
        self.preferredVoiceGender = VoiceGender(rawValue: load(.preferredVoiceGender) ?? "Neutral") ?? .neutral
        self.preferredLanguage = load(.preferredLanguage) ?? "en-US"
        self.dailyStepGoal = load(.dailyStepGoal) ?? 10000
        self.preferredMeasurementSystem = MeasurementSystem(rawValue: load(.preferredMeasurementSystem) ?? "Metric") ?? .metric
        self.healthMetricsToDisplay = Set(
            (load(.healthMetricsToDisplay) as? [String] ?? HealthMetric.allCases.map { $0.rawValue })
                .compactMap { HealthMetric(rawValue: $0) }
        )
        self.workoutReminderEnabled = load(.workoutReminderEnabled) ?? true
        
        // Load complex types
        if let notificationData: Data = load(.notificationSettings),
           let decodedNotifications = try? JSONDecoder().decode(NotificationPreferences.self, from: notificationData) {
            self.notificationSettings = decodedNotifications
        } else {
            self.notificationSettings = NotificationPreferences(
                healthAlerts: true,
                workoutReminders: true,
                weatherAlerts: true,
                taskReminders: true,
                messageNotifications: true,
                quietHoursEnabled: false,
                quietHoursStart: Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date(),
                quietHoursEnd: Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
            )
        }
        
        if let privacyData: Data = load(.privacySettings),
           let decodedPrivacy = try? JSONDecoder().decode(PrivacyPreferences.self, from: privacyData) {
            self.privacySettings = decodedPrivacy
        } else {
            self.privacySettings = PrivacyPreferences(
                shareHealthData: true,
                shareWorkoutData: true,
                shareLocationData: true,
                saveVoiceCommands: false,
                saveMessageHistory: true,
                dataRetentionPeriod: 30
            )
        }
    }
    
    // MARK: - Save and Load Methods
    
    private func save<T>(_ key: PreferenceKey, _ value: T) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
    
    private func load<T>(_ key: PreferenceKey) -> T? {
        UserDefaults.standard.object(forKey: key.rawValue) as? T
    }
    
    // MARK: - Reset Methods
    
    func resetToDefaults() {
        useDarkMode = false
        hapticFeedbackEnabled = true
        voiceFeedbackEnabled = true
        voiceVolume = 0.8
        preferredVoiceGender = .neutral
        preferredLanguage = "en-US"
        dailyStepGoal = 10000
        preferredMeasurementSystem = .metric
        healthMetricsToDisplay = Set(HealthMetric.allCases)
        workoutReminderEnabled = true
        
        notificationSettings = NotificationPreferences(
            healthAlerts: true,
            workoutReminders: true,
            weatherAlerts: true,
            taskReminders: true,
            messageNotifications: true,
            quietHoursEnabled: false,
            quietHoursStart: Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date(),
            quietHoursEnd: Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        )
        
        privacySettings = PrivacyPreferences(
            shareHealthData: true,
            shareWorkoutData: true,
            shareLocationData: true,
            saveVoiceCommands: false,
            saveMessageHistory: true,
            dataRetentionPeriod: 30
        )
    }
    
    // MARK: - Helper Methods
    
    func isQuietHours(at date: Date = Date()) -> Bool {
        guard notificationSettings.quietHoursEnabled else { return false }
        
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: notificationSettings.quietHoursStart)
        let endComponents = calendar.dateComponents([.hour, .minute], from: notificationSettings.quietHoursEnd)
        let currentComponents = calendar.dateComponents([.hour, .minute], from: date)
        
        let start = startComponents.hour! * 60 + startComponents.minute!
        let end = endComponents.hour! * 60 + endComponents.minute!
        let current = currentComponents.hour! * 60 + currentComponents.minute!
        
        if start <= end {
            return current >= start && current <= end
        } else {
            // Handles cases where quiet hours span midnight
            return current >= start || current <= end
        }
    }
    
    func shouldShowNotification(type: NotificationType, at date: Date = Date()) -> Bool {
        guard !isQuietHours(at: date) else { return false }
        
        switch type {
        case .health:
            return notificationSettings.healthAlerts
        case .workout:
            return notificationSettings.workoutReminders
        case .weather:
            return notificationSettings.weatherAlerts
        case .reminder:
            return notificationSettings.taskReminders
        case .message:
            return notificationSettings.messageNotifications
        }
    }
    
    enum NotificationType {
        case health
        case workout
        case weather
        case reminder
        case message
    }
    
    func formatMeasurement(_ value: Double, unit: MeasurementUnit) -> String {
        switch unit {
        case .distance:
            if preferredMeasurementSystem == .metric {
                return String(format: "%.1f km", value)
            } else {
                return String(format: "%.1f mi", value * 0.621371)
            }
        case .weight:
            if preferredMeasurementSystem == .metric {
                return String(format: "%.1f kg", value)
            } else {
                return String(format: "%.1f lb", value * 2.20462)
            }
        case .temperature:
            if preferredMeasurementSystem == .metric {
                return String(format: "%.1f°C", value)
            } else {
                return String(format: "%.1f°F", value * 9/5 + 32)
            }
        }
    }
    
    enum MeasurementUnit {
        case distance
        case weight
        case temperature
    }
}
