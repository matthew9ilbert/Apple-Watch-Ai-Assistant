import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var assistantManager: AssistantManager
    
    @State private var useVoiceFeedback = true
    @State private var voiceVolume: Double = 0.8
    @State private var selectedLanguage = "en-US"
    @State private var preferDarkMode = false
    @State private var allowNotifications = true
    @State private var privacyModeEnabled = false
    
    private let availableLanguages = [
        "en-US": "English (US)",
        "en-GB": "English (UK)",
        "es-ES": "Spanish",
        "fr-FR": "French",
        "de-DE": "German",
        "it-IT": "Italian",
        "ja-JP": "Japanese",
        "zh-CN": "Chinese (Simplified)",
        "ru-RU": "Russian"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Voice settings
                GroupBox(label: headerLabel("Voice")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Voice Feedback", isOn: $useVoiceFeedback)
                            .onChange(of: useVoiceFeedback) { newValue in
                                assistantManager.useVoiceFeedback = newValue
                            }
                        
                        if useVoiceFeedback {
                            Text("Volume")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: "speaker.1.fill")
                                    .foregroundColor(.secondary)
                                
                                Slider(value: $voiceVolume, in: 0...1, step: 0.1)
                                    .onChange(of: voiceVolume) { newValue in
                                        assistantManager.voiceVolumeLevel = Float(newValue)
                                    }
                                
                                Image(systemName: "speaker.3.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Language settings
                GroupBox(label: headerLabel("Language")) {
                    Picker("Language", selection: $selectedLanguage) {
                        ForEach(availableLanguages.sorted(by: { $0.value < $1.value }), id: \.key) { key, value in
                            Text(value).tag(key)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedLanguage) { newValue in
                        assistantManager.setPreferredLanguage(newValue)
                    }
                }
                
                // Appearance settings
                GroupBox(label: headerLabel("Appearance")) {
                    Toggle("Dark Mode", isOn: $preferDarkMode)
                        .padding(.vertical, 4)
                }
                
                // Notifications and Privacy
                GroupBox(label: headerLabel("Notifications & Privacy")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Allow Notifications", isOn: $allowNotifications)
                        
                        Toggle("Privacy Mode", isOn: $privacyModeEnabled)
                            .onChange(of: privacyModeEnabled) { newValue in
                                // In a real app, this would apply privacy settings
                            }
                        
                        if privacyModeEnabled {
                            Text("Privacy mode limits data collection and processing to on-device only.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // About and version info
                GroupBox(label: headerLabel("About")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Version")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: {
                            // In a real app, this would show terms of service
                        }) {
                            Text("Terms of Service")
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: {
                            // In a real app, this would show privacy policy
                        }) {
                            Text("Privacy Policy")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Reset button
                Button(action: {
                    resetSettings()
                }) {
                    Text("Reset All Settings")
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.top)
            }
            .padding()
        }
        .onAppear {
            // Load current settings
            useVoiceFeedback = assistantManager.useVoiceFeedback
            voiceVolume = Double(assistantManager.voiceVolumeLevel)
            selectedLanguage = assistantManager.preferredLanguage
        }
    }
    
    private func headerLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.headline)
            Spacer()
        }
    }
    
    private func resetSettings() {
        // Reset to defaults
        useVoiceFeedback = true
        voiceVolume = 0.8
        selectedLanguage = "en-US"
        preferDarkMode = false
        allowNotifications = true
        privacyModeEnabled = false
        
        // Apply changes to assistant manager
        assistantManager.useVoiceFeedback = useVoiceFeedback
        assistantManager.voiceVolumeLevel = Float(voiceVolume)
        assistantManager.setPreferredLanguage(selectedLanguage)
    }
}
