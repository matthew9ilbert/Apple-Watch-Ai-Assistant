import SwiftUI

@main
struct WatchAssistantApp: App {
    // Core managers
    @StateObject private var dataStore = DataStoreManager.shared
    @StateObject private var preferencesManager = PreferencesManager.shared
    @StateObject private var analyticsManager = AnalyticsManager.shared
    @StateObject private var syncManager = SyncManager.shared
    
    // Feature managers
    @StateObject private var healthManager = HealthManager()
    @StateObject private var assistantManager = AssistantManager()
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var weatherManager = WeatherManager()
    @StateObject private var reminderManager = ReminderManager()
    @StateObject private var messageManager = MessageManager()
    @StateObject private var homeAutomationManager = HomeAutomationManager()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var permissionsManager = PermissionsManager.shared
    
    // App state
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true
    @State private var showingOnboarding = false
    @State private var showingPermissions = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app content
                MainTabView()
                    .environmentObject(dataStore)
                    .environmentObject(preferencesManager)
                    .environmentObject(healthManager)
                    .environmentObject(assistantManager)
                    .environmentObject(workoutManager)
                    .environmentObject(weatherManager)
                    .environmentObject(reminderManager)
                    .environmentObject(messageManager)
                    .environmentObject(homeAutomationManager)
                    .environmentObject(notificationManager)
                    .environmentObject(permissionsManager)
                    .task {
                        if isFirstLaunch {
                            showingOnboarding = true
                        }
                    }
                
                // Onboarding overlay
                if showingOnboarding {
                    OnboardingView(isOnboarding: $showingOnboarding)
                        .transition(.opacity)
                        .environmentObject(preferencesManager)
                        .environmentObject(healthManager)
                        .environmentObject(notificationManager)
                        .onDisappear {
                            showingPermissions = true
                            isFirstLaunch = false
                        }
                }
                
                // Permissions overlay
                if showingPermissions {
                    PermissionsView(isPresented: $showingPermissions)
                        .transition(.opacity)
                        .environmentObject(permissionsManager)
                }
            }
            .onChange(of: syncManager.syncError) { error in
                if let error = error {
                    analyticsManager.logError(error,
                                            code: "SYNC_ERROR",
                                            severity: .error)
                }
            }
        }
    }
    
    init() {
        setupAppearance()
        configureAnalytics()
    }
    
    private func setupAppearance() {
        // Configure global app appearance
        if preferencesManager.useDarkMode {
            UIApplication.shared.windows.first?.overrideUserInterfaceStyle = .dark
        }
    }
    
    private func configureAnalytics() {
        // Start performance monitoring if enabled
        if preferencesManager.privacySettings.shareHealthData {
            analyticsManager.startPerformanceMonitoring()
        }
        
        // Log app launch
        analyticsManager.logEvent("app_launched",
                                category: .settings,
                                parameters: [
                                    "first_launch": "\(isFirstLaunch)",
                                    "dark_mode": "\(preferencesManager.useDarkMode)",
                                    "language": preferencesManager.preferredLanguage
                                ])
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            AssistantView()
                .tabItem {
                    Label("Assistant", systemImage: "message.fill")
                }
                .tag(0)
            
            FitnessView()
                .tabItem {
                    Label("Fitness", systemImage: "heart.fill")
                }
                .tag(1)
            
            HomeControlView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(2)
            
            MessageView()
                .tabItem {
                    Label("Messages", systemImage: "bubble.left.fill")
                }
                .tag(3)
            
            SettingsDetailView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .onChange(of: selectedTab) { newTab in
            AnalyticsManager.shared.logEvent(
                "tab_selected",
                category: .navigation,
                parameters: ["tab": "\(newTab)"]
            )
        }
    }
}
