import Foundation
import SwiftUI

// Model for a single message in a chat conversation
struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    var content: String
    var isUser: Bool
    var timestamp: Date
    var type: MessageType
    
    enum MessageType: String, Codable {
        case text
        case action         // For actions like setting a timer, playing music
        case healthUpdate   // For health-related updates
        case homeControl    // For home automation actions
        case weatherInfo    // For weather information
        case reminderSet    // For confirmation of setting reminders
        case alert          // For important alerts
    }
    
    var iconName: String {
        switch type {
        case .text:
            return isUser ? "person.circle" : "message"
        case .action:
            return "play.circle"
        case .healthUpdate:
            return "heart.circle"
        case .homeControl:
            return "house.circle"
        case .weatherInfo:
            return "cloud.sun"
        case .reminderSet:
            return "calendar.badge.clock"
        case .alert:
            return "exclamationmark.triangle"
        }
    }
    
    var iconColor: Color {
        switch type {
        case .text:
            return isUser ? .blue : .green
        case .action:
            return .purple
        case .healthUpdate:
            return .red
        case .homeControl:
            return .orange
        case .weatherInfo:
            return .blue
        case .reminderSet:
            return .indigo
        case .alert:
            return .red
        }
    }
}

// Model for a complete conversation
struct Conversation: Identifiable, Codable {
    var id = UUID()
    var title: String
    var messages: [ChatMessage]
    var startDate: Date
    var lastUpdated: Date
    var context: [String: String]  // Contextual information about the conversation
    
    var previewText: String {
        messages.last?.content.prefix(30) ?? "No messages"
    }
}

// Model for voice commands
struct VoiceCommand: Identifiable, Codable {
    var id = UUID()
    var command: String
    var timestamp: Date
    var successful: Bool
    var category: CommandCategory
    
    enum CommandCategory: String, Codable, CaseIterable {
        case assistant = "Assistant"
        case health = "Health & Fitness"
        case home = "Home Control"
        case reminder = "Reminders & Calendar"
        case message = "Messages"
        case weather = "Weather"
        case other = "Other"
    }
}

// Chat history manager
class ChatHistoryManager: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var recentCommands: [VoiceCommand] = []
    
    private let conversationsKey = "savedConversations"
    private let commandsKey = "recentCommands"
    private let maxSavedConversations = 50
    private let maxRecentCommands = 100
    
    init() {
        loadConversations()
        loadRecentCommands()
    }
    
    // MARK: - Conversation Management
    
    func addMessage(to conversationId: UUID, message: ChatMessage) {
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[index].messages.append(message)
            conversations[index].lastUpdated = Date()
            saveConversations()
        }
    }
    
    func createNewConversation(title: String = "New Conversation") -> UUID {
        let newConversation = Conversation(
            title: title,
            messages: [],
            startDate: Date(),
            lastUpdated: Date(),
            context: [:]
        )
        
        conversations.insert(newConversation, at: 0)
        
        // Limit the number of saved conversations
        if conversations.count > maxSavedConversations {
            conversations = Array(conversations.prefix(maxSavedConversations))
        }
        
        saveConversations()
        return newConversation.id
    }
    
    func deleteConversation(withId id: UUID) {
        conversations.removeAll(where: { $0.id == id })
        saveConversations()
    }
    
    func clearAllConversations() {
        conversations = []
        saveConversations()
    }
    
    func updateConversationContext(conversationId: UUID, key: String, value: String) {
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[index].context[key] = value
            saveConversations()
        }
    }
    
    // MARK: - Voice Command Management
    
    func logVoiceCommand(_ command: String, category: VoiceCommand.CommandCategory, successful: Bool) {
        let newCommand = VoiceCommand(
            command: command,
            timestamp: Date(),
            successful: successful,
            category: category
        )
        
        recentCommands.insert(newCommand, at: 0)
        
        // Limit the number of saved commands
        if recentCommands.count > maxRecentCommands {
            recentCommands = Array(recentCommands.prefix(maxRecentCommands))
        }
        
        saveRecentCommands()
    }
    
    func clearRecentCommands() {
        recentCommands = []
        saveRecentCommands()
    }
    
    // MARK: - Persistence
    
    private func saveConversations() {
        if let encodedData = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(encodedData, forKey: conversationsKey)
        }
    }
    
    private func loadConversations() {
        if let data = UserDefaults.standard.data(forKey: conversationsKey),
           let decodedConversations = try? JSONDecoder().decode([Conversation].self, from: data) {
            conversations = decodedConversations
        }
    }
    
    private func saveRecentCommands() {
        if let encodedData = try? JSONEncoder().encode(recentCommands) {
            UserDefaults.standard.set(encodedData, forKey: commandsKey)
        }
    }
    
    private func loadRecentCommands() {
        if let data = UserDefaults.standard.data(forKey: commandsKey),
           let decodedCommands = try? JSONDecoder().decode([VoiceCommand].self, from: data) {
            recentCommands = decodedCommands
        }
    }
}
