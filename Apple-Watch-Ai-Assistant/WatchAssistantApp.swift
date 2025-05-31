import SwiftUI
import HealthKit
import CoreML
import NaturalLanguage

@main
struct WatchAssistantApp: App {
    // State objects to manage app data
    @StateObject private var healthManager = HealthManager()
    @StateObject private var assistantManager = AssistantManager()
    @StateObject private var homeAutomationManager = HomeAutomationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthManager)
                .environmentObject(assistantManager)
                .environmentObject(homeAutomationManager)
        }
    }
    
    init() {
        // Request necessary permissions when app launches
        healthManager.requestAuthorization()
        assistantManager.initialize()
    }
}
