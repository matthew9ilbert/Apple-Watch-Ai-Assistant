import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var assistantManager: AssistantManager
    @EnvironmentObject var homeAutomationManager: HomeAutomationManager
    
    @State private var isListening = false
    @State private var inputText = ""
    @State private var responseText = "Hello! How can I help you today?"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Assistant response display
                Text(responseText)
                    .font(.system(.body, design: .rounded))
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)
                
                // Input methods
                HStack {
                    // Voice input button
                    Button(action: {
                        isListening.toggle()
                        if isListening {
                            startListening()
                        } else {
                            stopListening()
                        }
                    }) {
                        Image(systemName: isListening ? "waveform" : "mic.fill")
                            .font(.system(size: 24))
                            .foregroundColor(isListening ? .red : .blue)
                            .frame(width: 44, height: 44)
                            .background(Color(UIColor.systemGray6))
                            .clipShape(Circle())
                    }
                    
                    // Quick actions menu
                    Menu {
                        Button("Weather", action: { processQuery("What's the weather?") })
                        Button("Health Summary", action: { processQuery("Show my health summary") })
                        Button("Fitness", action: { processQuery("Start a workout") })
                        Button("Home", action: { processQuery("Control my smart home") })
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Color(UIColor.systemGray6))
                            .clipShape(Circle())
                    }
                }
                
                // Health data preview
                if let heartRate = healthManager.currentHeartRate {
                    HealthDataView(heartRate: heartRate, steps: healthManager.stepCount)
                }
            }
            .padding()
        }
    }
    
    func startListening() {
        // Implement speech recognition here
        assistantManager.startVoiceRecognition { recognizedText in
            self.inputText = recognizedText
            processQuery(recognizedText)
            self.isListening = false
        }
    }
    
    func stopListening() {
        assistantManager.stopVoiceRecognition()
    }
    
    func processQuery(_ query: String) {
        // Process the user's query and generate a response
        assistantManager.processQuery(query) { response in
            self.responseText = response
        }
    }
}

struct HealthDataView: View {
    let heartRate: Int
    let steps: Int
    
    var body: some View {
        HStack(spacing: 20) {
            VStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("\(heartRate) BPM")
                    .font(.caption)
            }
            
            VStack {
                Image(systemName: "figure.walk")
                    .foregroundColor(.green)
                Text("\(steps) steps")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(10)
    }
}
