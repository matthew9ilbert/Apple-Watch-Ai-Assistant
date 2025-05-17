import Foundation
import Speech
import NaturalLanguage
import CoreML
import AVFoundation

class AssistantManager: ObservableObject {
    // Speech recognition properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Speech synthesis for responses
    private let synthesizer = AVSpeechSynthesizer()
    
    // User preferences
    @Published var preferredLanguage = "en-US"
    @Published var voiceVolumeLevel: Float = 0.8
    @Published var useVoiceFeedback = true
    
    // Learning and personalization
    private var userInteractionHistory: [UserInteraction] = []
    private var userPreferences = UserPreferences()
    
    struct UserInteraction {
        let query: String
        let response: String
        let timestamp: Date
        let successful: Bool
    }
    
    struct UserPreferences {
        var favoriteTopics: [String: Int] = [:]
        var frequentQueries: [String: Int] = [:]
        var preferredResponseLength: ResponseLength = .medium
        
        enum ResponseLength {
            case short, medium, long
        }
    }
    
    func initialize() {
        // Request speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition authorization denied")
                @unknown default:
                    print("Speech recognition authorization unknown status")
                }
            }
        }
        
        // Load saved user preferences and interaction history
        loadUserData()
    }
    
    func startVoiceRecognition(completion: @escaping (String) -> Void) {
        // Check if recognition is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognition not available")
            return
        }
        
        // Cancel any existing task
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error.localizedDescription)")
            return
        }
        
        // Set up recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Prepare audio input
        let inputNode = audioEngine.inputNode
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                // Get recognized text
                let recognizedText = result.bestTranscription.formattedString
                isFinal = result.isFinal
                
                // If recognition is final, process the command
                if isFinal {
                    completion(recognizedText)
                }
            }
            
            // Handle errors or complete the task
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
        
        // Configure audio input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error.localizedDescription)")
        }
    }
    
    func stopVoiceRecognition() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    func processQuery(_ query: String, completion: @escaping (String) -> Void) {
        // Analyze intent of the query
        let intent = analyzeIntent(query)
        
        // Generate response based on intent
        let response = generateResponse(for: query, withIntent: intent)
        
        // Speak response if voice feedback is enabled
        if useVoiceFeedback {
            speakResponse(response)
        }
        
        // Log interaction for learning
        logInteraction(query: query, response: response)
        
        // Return the response
        completion(response)
    }
    
    private func analyzeIntent(_ query: String) -> String {
        // Simple intent detection - in a real app, this would use more sophisticated NLP
        let lowercasedQuery = query.lowercased()
        
        if lowercasedQuery.contains("weather") {
            return "weather"
        } else if lowercasedQuery.contains("reminder") || lowercasedQuery.contains("remind") {
            return "reminder"
        } else if lowercasedQuery.contains("message") || lowercasedQuery.contains("text") || lowercasedQuery.contains("send") {
            return "message"
        } else if lowercasedQuery.contains("heart") || lowercasedQuery.contains("health") || lowercasedQuery.contains("steps") {
            return "health"
        } else if lowercasedQuery.contains("workout") || lowercasedQuery.contains("exercise") || lowercasedQuery.contains("run") {
            return "fitness"
        } else if lowercasedQuery.contains("light") || lowercasedQuery.contains("thermostat") || lowercasedQuery.contains("home") {
            return "home"
        } else {
            return "general"
        }
    }
    
    private func generateResponse(for query: String, withIntent intent: String) -> String {
        // In a real app, this would connect to an AI service or use on-device ML
        switch intent {
        case "weather":
            return "It's currently 72°F and sunny. The forecast shows a 20% chance of rain later today."
            
        case "reminder":
            return "I've set a reminder for you. What would you like me to remind you about and when?"
            
        case "message":
            return "Who would you like to send a message to?"
            
        case "health":
            return "Your heart rate is currently 72 BPM and you've taken 5,432 steps today. You're making good progress toward your daily goal."
            
        case "fitness":
            return "Would you like to start tracking a workout? I can track running, walking, cycling, and more."
            
        case "home":
            return "I can control your smart home devices. Would you like to adjust the lights, temperature, or something else?"
            
        case "general":
            // For general inquiries, we would normally connect to a more sophisticated AI
            return "I'm your personal assistant. I can help with weather, reminders, messages, health tracking, workouts, and smart home control. What would you like to do?"
        default:
            return "I'm not sure how to help with that yet, but I'm learning new skills all the time."
        }
    }
    
    private func speakResponse(_ response: String) {
        let utterance = AVSpeechUtterance(string: response)
        utterance.voice = AVSpeechSynthesisVoice(language: preferredLanguage)
        utterance.rate = 0.5
        utterance.volume = voiceVolumeLevel
        
        synthesizer.speak(utterance)
    }
    
    private func logInteraction(query: String, response: String) {
        // Log the interaction for learning and personalization
        let interaction = UserInteraction(
            query: query,
            response: response,
            timestamp: Date(),
            successful: true
        )
        
        userInteractionHistory.append(interaction)
        
        // Update user preferences based on this interaction
        let queryWords = query.lowercased().split(separator: " ").map(String.init)
        for word in queryWords {
            if userPreferences.favoriteTopics[word] != nil {
                userPreferences.favoriteTopics[word]! += 1
            } else {
                userPreferences.favoriteTopics[word] = 1
            }
        }
        
        // Store frequent queries
        if userPreferences.frequentQueries[query] != nil {
            userPreferences.frequentQueries[query]! += 1
        } else {
            userPreferences.frequentQueries[query] = 1
        }
        
        // Save updated user data
        saveUserData()
    }
    
    private func loadUserData() {
        // In a real app, this would load from persistent storage
        // For demo purposes, we initialize with empty data
    }
    
    private func saveUserData() {
        // In a real app, this would save to persistent storage
        // For demo purposes, we just print some stats
        print("User has \(userInteractionHistory.count) logged interactions")
        
        if let topTopic = userPreferences.favoriteTopics.max(by: { $0.value < $1.value }) {
            print("User's top interest: \(topTopic.key) (\(topTopic.value) mentions)")
        }
    }
    
    func setPreferredLanguage(_ languageCode: String) {
        preferredLanguage = languageCode
        // Update speech recognizer for new language
        if let newRecognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode)) {
            if newRecognizer.isAvailable {
                self.speechRecognizer = newRecognizer
            }
        }
    }
}
