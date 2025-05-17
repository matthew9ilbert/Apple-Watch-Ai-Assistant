import Foundation
import SwiftUI

struct UserProfile: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var email: String?
    var healthPreferences: HealthPreferences
    var assistantPreferences: AssistantPreferences
    var homePreferences: HomePreferences
    
    struct HealthPreferences: Codable {
        var dailyStepGoal: Int
        var dailyCalorieGoal: Double
        var preferredWorkouts: [String]
        var shareHealthData: Bool
        var sendHealthAlerts: Bool
        var sleepTrackingEnabled: Bool
        var preferredMeasurementUnit: MeasurementUnit
        
        enum MeasurementUnit: String, Codable, CaseIterable {
            case metric = "Metric (kg, cm)"
            case imperial = "Imperial (lb, in)"
        }
        
        static let `default` = HealthPreferences(
            dailyStepGoal: 10000,
            dailyCalorieGoal: 500,
            preferredWorkouts: ["Walking", "Running", "Cycling"],
            shareHealthData: true,
            sendHealthAlerts: true,
            sleepTrackingEnabled: true,
            preferredMeasurementUnit: .metric
        )
    }
    
    struct AssistantPreferences: Codable {
        var preferredVoiceGender: VoiceGender
        var voiceResponseEnabled: Bool
        var voiceVolume: Double
        var preferredLanguage: String
        var responseLength: ResponseLength
        var personalizedSuggestions: Bool
        var suggestionsBasedOnTime: Bool
        var saveConversationHistory: Bool
        var proactiveAssistance: Bool
        
        enum VoiceGender: String, Codable, CaseIterable {
            case male = "Male"
            case female = "Female"
            case neutral = "Neutral"
        }
        
        enum ResponseLength: String, Codable, CaseIterable {
            case brief = "Brief"
            case detailed = "Detailed"
            case comprehensive = "Comprehensive"
        }
        
        static let `default` = AssistantPreferences(
            preferredVoiceGender: .neutral,
            voiceResponseEnabled: true,
            voiceVolume: 0.8,
            preferredLanguage: "en-US",
            responseLength: .detailed,
            personalizedSuggestions: true,
            suggestionsBasedOnTime: true,
            saveConversationHistory: true,
            proactiveAssistance: true
        )
    }
    
    struct HomePreferences: Codable {
        var favoriteAccessories: [String]
        var favoriteScenes: [String]
        var defaultRoom: String?
        var homeAutomationEnabled: Bool
        var locationBasedControl: Bool
        var timeBasedAutomation: Bool
        var energySavingMode: Bool
        
        static let `default` = HomePreferences(
            favoriteAccessories: [],
            favoriteScenes: [],
            defaultRoom: nil,
            homeAutomationEnabled: true,
            locationBasedControl: true,
            timeBasedAutomation: true,
            energySavingMode: false
        )
    }
    
    static let `default` = UserProfile(
        name: "User",
        email: nil,
        healthPreferences: .default,
        assistantPreferences: .default,
        homePreferences: .default
    )
}

// User Profile Manager to handle saving/loading profiles
class UserProfileManager: ObservableObject {
    @Published var currentProfile: UserProfile
    
    private let saveKey = "userProfile"
    
    init() {
        // Load profile from UserDefaults or use default
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decodedProfile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.currentProfile = decodedProfile
        } else {
            self.currentProfile = UserProfile.default
        }
    }
    
    func saveProfile() {
        if let encodedData = try? JSONEncoder().encode(currentProfile) {
            UserDefaults.standard.set(encodedData, forKey: saveKey)
        }
    }
    
    func updateProfile(name: String, email: String?) {
        currentProfile.name = name
        currentProfile.email = email
        saveProfile()
    }
    
    func updateHealthPreferences(_ preferences: UserProfile.HealthPreferences) {
        currentProfile.healthPreferences = preferences
        saveProfile()
    }
    
    func updateAssistantPreferences(_ preferences: UserProfile.AssistantPreferences) {
        currentProfile.assistantPreferences = preferences
        saveProfile()
    }
    
    func updateHomePreferences(_ preferences: UserProfile.HomePreferences) {
        currentProfile.homePreferences = preferences
        saveProfile()
    }
    
    func resetToDefaults() {
        currentProfile = UserProfile.default
        saveProfile()
    }
}
