import SwiftUI
import HealthKit
import CoreLocation

struct OnboardingView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var notificationManager: NotificationManager
    @Binding var isOnboarding: Bool
    
    @State private var currentStep = 0
    @State private var userName = ""
    @State private var selectedLanguage = "en-US"
    @State private var healthMetrics: Set<PreferencesManager.HealthMetric> = []
    @State private var notificationTypes: Set<NotificationType> = []
    
    enum NotificationType: String, CaseIterable {
        case health = "Health Alerts"
        case workout = "Workout Reminders"
        case weather = "Weather Updates"
        case tasks = "Task Reminders"
        case messages = "Messages"
    }
    
    var body: some View {
        TabView(selection: $currentStep) {
            // Welcome
            welcomeView
                .tag(0)
            
            // Language Selection
            languageSelectionView
                .tag(1)
            
            // Health Permissions
            healthPermissionsView
                .tag(2)
            
            // Notification Permissions
            notificationPermissionsView
                .tag(3)
            
            // Location Permissions
            locationPermissionsView
                .tag(4)
            
            // Final Setup
            finalSetupView
                .tag(5)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
    
    // MARK: - Welcome View
    
    private var welcomeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "applewatch")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding()
            
            Text("Welcome to\nWatchAssistant")
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
            
            Text("Your intelligent assistant for Apple Watch")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            TextField("Your Name", text: $userName)
                .textFieldStyle(RoundedBorderTextStyle())
                .padding()
            
            NavigationButton(currentStep: $currentStep, direction: .forward)
        }
        .padding()
    }
    
    // MARK: - Language Selection View
    
    private var languageSelectionView: some View {
        VStack(spacing: 20) {
            Text("Select Your Language")
                .font(.title2)
                .bold()
            
            Text("Choose your preferred language for voice interactions")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Picker("Language", selection: $selectedLanguage) {
                Text("English (US)").tag("en-US")
                Text("English (UK)").tag("en-GB")
                Text("Spanish").tag("es")
                Text("French").tag("fr")
                Text("German").tag("de")
            }
            .pickerStyle(.wheel)
            
            NavigationButtons(currentStep: $currentStep)
        }
        .padding()
    }
    
    // MARK: - Health Permissions View
    
    private var healthPermissionsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Health & Fitness")
                .font(.title2)
                .bold()
            
            Text("Select the health metrics you'd like to track")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading) {
                ForEach(PreferencesManager.HealthMetric.allCases, id: \.self) { metric in
                    Toggle(metric.rawValue, isOn: Binding(
                        get: { healthMetrics.contains(metric) },
                        set: { isEnabled in
                            if isEnabled {
                                healthMetrics.insert(metric)
                            } else {
                                healthMetrics.remove(metric)
                            }
                        }
                    ))
                }
            }
            .padding()
            
            Button("Request Health Access") {
                healthManager.requestAuthorization()
            }
            .buttonStyle(.bordered)
            
            NavigationButtons(currentStep: $currentStep)
        }
        .padding()
    }
    
    // MARK: - Notification Permissions View
    
    private var notificationPermissionsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Notifications")
                .font(.title2)
                .bold()
            
            Text("Choose which notifications you'd like to receive")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading) {
                ForEach(NotificationType.allCases, id: \.self) { type in
                    Toggle(type.rawValue, isOn: Binding(
                        get: { notificationTypes.contains(type) },
                        set: { isEnabled in
                            if isEnabled {
                                notificationTypes.insert(type)
                            } else {
                                notificationTypes.remove(type)
                            }
                        }
                    ))
                }
            }
            .padding()
            
            Button("Enable Notifications") {
                notificationManager.requestAuthorization()
            }
            .buttonStyle(.bordered)
            
            NavigationButtons(currentStep: $currentStep)
        }
        .padding()
    }
    
    // MARK: - Location Permissions View
    
    private var locationPermissionsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.circle")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Location Services")
                .font(.title2)
                .bold()
            
            Text("Enable location services for weather updates and location-based reminders")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "cloud.sun.fill",
                          title: "Weather Updates",
                          description: "Get local weather forecasts")
                
                FeatureRow(icon: "mappin.circle.fill",
                          title: "Location Reminders",
                          description: "Set reminders based on your location")
                
                FeatureRow(icon: "house.fill",
                          title: "Home Automation",
                          description: "Automate your smart home based on location")
            }
            .padding()
            
            Button("Enable Location Services") {
                CLLocationManager().requestWhenInUseAuthorization()
            }
            .buttonStyle(.bordered)
            
            NavigationButtons(currentStep: $currentStep)
        }
        .padding()
    }
    
    // MARK: - Final Setup View
    
    private var finalSetupView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("You're All Set!")
                .font(.title)
                .bold()
            
            Text("Welcome aboard, \(userName)!")
                .font(.headline)
            
            Text("Your WatchAssistant is ready to help you stay healthy, organized, and connected.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Get Started") {
                completeOnboarding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
    }
    
    // MARK: - Helper Views
    
    struct NavigationButtons: View {
        @Binding var currentStep: Int
        
        var body: some View {
            HStack {
                NavigationButton(currentStep: $currentStep, direction: .back)
                Spacer()
                NavigationButton(currentStep: $currentStep, direction: .forward)
            }
            .padding(.horizontal)
        }
    }
    
    struct NavigationButton: View {
        @Binding var currentStep: Int
        let direction: NavigationDirection
        
        enum NavigationDirection {
            case back
            case forward
        }
        
        var body: some View {
            Button(action: {
                withAnimation {
                    switch direction {
                    case .back:
                        currentStep -= 1
                    case .forward:
                        currentStep += 1
                    }
                }
            }) {
                HStack {
                    if direction == .back {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    } else {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                }
                .padding()
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .opacity(direction == .back && currentStep == 0 ? 0 : 1)
        }
    }
    
    struct FeatureRow: View {
        let icon: String
        let title: String
        let description: String
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func completeOnboarding() {
        // Save preferences
        preferencesManager.preferredLanguage = selectedLanguage
        preferencesManager.healthMetricsToDisplay = healthMetrics
        
        // Update notification preferences
        var notificationPrefs = preferencesManager.notificationSettings
        notificationPrefs.healthAlerts = notificationTypes.contains(.health)
        notificationPrefs.workoutReminders = notificationTypes.contains(.workout)
        notificationPrefs.weatherAlerts = notificationTypes.contains(.weather)
        notificationPrefs.taskReminders = notificationTypes.contains(.tasks)
        notificationPrefs.messageNotifications = notificationTypes.contains(.messages)
        preferencesManager.notificationSettings = notificationPrefs
        
        // Complete onboarding
        isOnboarding = false
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isOnboarding: .constant(true))
            .environmentObject(PreferencesManager.shared)
            .environmentObject(HealthManager())
            .environmentObject(NotificationManager.shared)
    }
}
