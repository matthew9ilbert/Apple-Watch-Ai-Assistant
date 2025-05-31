import SwiftUI

struct SettingsDetailView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @Environment(\.dismiss) var dismiss
    @State private var showingResetAlert = false
    @State private var selectedSection: SettingsSection = .general
    
    enum SettingsSection: String, CaseIterable {
        case general = "General"
        case voice = "Voice"
        case health = "Health"
        case notifications = "Notifications"
        case privacy = "Privacy"
    }
    
    var body: some View {
        NavigationView {
            List {
                // Section picker
                Picker("Section", selection: $selectedSection) {
                    ForEach(SettingsSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .listRowBackground(Color.clear)
                
                // Selected section settings
                switch selectedSection {
                case .general:
                    generalSettings
                case .voice:
                    voiceSettings
                case .health:
                    healthSettings
                case .notifications:
                    notificationSettings
                case .privacy:
                    privacySettings
                }
                
                // Reset settings button
                Section {
                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Label("Reset All Settings", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Reset", role: .destructive) {
                    preferencesManager.resetToDefaults()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to reset all settings to default values?")
            }
        }
    }
    
    // MARK: - General Settings
    
    private var generalSettings: some View {
        Section {
            Toggle("Dark Mode", isOn: $preferencesManager.useDarkMode)
            
            Toggle("Haptic Feedback", isOn: $preferencesManager.hapticFeedbackEnabled)
            
            Picker("Measurement System", selection: $preferencesManager.preferredMeasurementSystem) {
                ForEach(PreferencesManager.MeasurementSystem.allCases, id: \.self) { system in
                    Text(system.rawValue).tag(system)
                }
            }
        }
    }
    
    // MARK: - Voice Settings
    
    private var voiceSettings: some View {
        Section {
            Toggle("Voice Feedback", isOn: $preferencesManager.voiceFeedbackEnabled)
            
            if preferencesManager.voiceFeedbackEnabled {
                HStack {
                    Text("Volume")
                    Slider(value: $preferencesManager.voiceVolume, in: 0...1)
                }
                
                Picker("Voice Gender", selection: $preferencesManager.preferredVoiceGender) {
                    ForEach(PreferencesManager.VoiceGender.allCases, id: \.self) { gender in
                        Text(gender.rawValue).tag(gender)
                    }
                }
                
                Picker("Language", selection: $preferencesManager.preferredLanguage) {
                    Text("English (US)").tag("en-US")
                    Text("English (UK)").tag("en-GB")
                    Text("Spanish").tag("es")
                    Text("French").tag("fr")
                    Text("German").tag("de")
                }
            }
        }
    }
    
    // MARK: - Health Settings
    
    private var healthSettings: some View {
        Section {
            HStack {
                Text("Daily Step Goal")
                Spacer()
                TextField("Steps", value: $preferencesManager.dailyStepGoal, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
            
            Toggle("Workout Reminders", isOn: $preferencesManager.workoutReminderEnabled)
            
            NavigationLink("Health Metrics") {
                HealthMetricsSelectionView()
            }
        }
    }
    
    // MARK: - Notification Settings
    
    private var notificationSettings: some View {
        Section {
            Toggle("Health Alerts", isOn: $preferencesManager.notificationSettings.healthAlerts)
            Toggle("Workout Reminders", isOn: $preferencesManager.notificationSettings.workoutReminders)
            Toggle("Weather Alerts", isOn: $preferencesManager.notificationSettings.weatherAlerts)
            Toggle("Task Reminders", isOn: $preferencesManager.notificationSettings.taskReminders)
            Toggle("Messages", isOn: $preferencesManager.notificationSettings.messageNotifications)
            
            Toggle("Quiet Hours", isOn: $preferencesManager.notificationSettings.quietHoursEnabled)
            
            if preferencesManager.notificationSettings.quietHoursEnabled {
                DatePicker("Start Time",
                          selection: $preferencesManager.notificationSettings.quietHoursStart,
                          displayedComponents: .hourAndMinute)
                
                DatePicker("End Time",
                          selection: $preferencesManager.notificationSettings.quietHoursEnd,
                          displayedComponents: .hourAndMinute)
            }
        }
    }
    
    // MARK: - Privacy Settings
    
    private var privacySettings: some View {
        Section {
            Toggle("Share Health Data", isOn: $preferencesManager.privacySettings.shareHealthData)
            Toggle("Share Workout Data", isOn: $preferencesManager.privacySettings.shareWorkoutData)
            Toggle("Share Location", isOn: $preferencesManager.privacySettings.shareLocationData)
            Toggle("Save Voice Commands", isOn: $preferencesManager.privacySettings.saveVoiceCommands)
            Toggle("Save Message History", isOn: $preferencesManager.privacySettings.saveMessageHistory)
            
            Picker("Data Retention", selection: $preferencesManager.privacySettings.dataRetentionPeriod) {
                Text("7 days").tag(7)
                Text("30 days").tag(30)
                Text("90 days").tag(90)
                Text("1 year").tag(365)
            }
        } footer: {
            Text("Data older than the selected retention period will be automatically deleted.")
        }
    }
}

// MARK: - Health Metrics Selection View

struct HealthMetricsSelectionView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    
    var body: some View {
        List {
            ForEach(PreferencesManager.HealthMetric.allCases, id: \.self) { metric in
                Toggle(metric.rawValue, isOn: Binding(
                    get: { preferencesManager.healthMetricsToDisplay.contains(metric) },
                    set: { isEnabled in
                        if isEnabled {
                            preferencesManager.healthMetricsToDisplay.insert(metric)
                        } else {
                            preferencesManager.healthMetricsToDisplay.remove(metric)
                        }
                    }
                ))
            }
        }
        .navigationTitle("Health Metrics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview Provider

struct SettingsDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsDetailView()
            .environmentObject(PreferencesManager.shared)
    }
}
