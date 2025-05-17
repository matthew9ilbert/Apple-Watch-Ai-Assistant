import SwiftUI

struct AssistantView: View {
    @EnvironmentObject var assistantManager: AssistantManager
    
    @State private var isListening = false
    @State private var messageText = ""
    @State private var assistantResponse = "Hello! How can I help you today?"
    @State private var animationAmount: CGFloat = 1.0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Assistant response bubble
                Text(assistantResponse)
                    .font(.system(.body, design: .rounded))
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(16)
                    .padding(.horizontal)
                
                // Voice input visualization
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .scaleEffect(isListening ? animationAmount : 1)
                        .animation(
                            isListening ?
                                Animation.easeOut(duration: 1)
                                    .repeatForever(autoreverses: true) : .default,
                            value: animationAmount
                        )
                    
                    Circle()
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: 60, height: 60)
                    
                    Button(action: {
                        isListening.toggle()
                        
                        if isListening {
                            animationAmount = 1.5
                            startListening()
                        } else {
                            animationAmount = 1.0
                            stopListening()
                        }
                    }) {
                        Image(systemName: isListening ? "waveform.circle.fill" : "mic.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .foregroundColor(.white)
                    }
                }
                .padding(.vertical)
                
                // Suggestions
                if !isListening {
                    SuggestionView(onSuggestionTapped: { suggestion in
                        processQuery(suggestion)
                    })
                }
            }
            .padding(.vertical)
        }
    }
    
    func startListening() {
        assistantManager.startVoiceRecognition { recognizedText in
            self.messageText = recognizedText
            processQuery(recognizedText)
            self.isListening = false
            self.animationAmount = 1.0
        }
    }
    
    func stopListening() {
        assistantManager.stopVoiceRecognition()
    }
    
    func processQuery(_ query: String) {
        assistantManager.processQuery(query) { response in
            self.assistantResponse = response
        }
    }
}

struct SuggestionView: View {
    let suggestions = [
        "What's the weather?",
        "How's my health today?",
        "Set a reminder",
        "Turn on the lights",
        "Start a workout"
    ]
    
    let onSuggestionTapped: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggestions:")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ForEach(suggestions, id: \.self) { suggestion in
                Button(action: {
                    onSuggestionTapped(suggestion)
                }) {
                    Text(suggestion)
                        .font(.system(.caption, design: .rounded))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(16)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }
}
