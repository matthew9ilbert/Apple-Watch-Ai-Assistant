import Foundation
import Contacts
import Messages
import Speech
import NaturalLanguage

class MessageManager: NSObject, ObservableObject {
    @Published var contacts: [CNContact] = []
    @Published var recentContacts: [CNContact] = []
    @Published var conversationHistory: [Conversation] = []
    @Published var isAuthorized = false
    @Published var errorMessage: String?
    
    private let contactStore = CNContactStore()
    private let messageStore = MSMessageStore()
    private let speechRecognizer = SFSpeechRecognizer()
    private let nlTokenizer = NLTokenizer(unit: .sentence)
    
    struct Conversation: Identifiable {
        let id = UUID()
        let contact: CNContact
        let messages: [Message]
        let lastUpdated: Date
    }
    
    struct Message: Identifiable {
        let id = UUID()
        let content: String
        let timestamp: Date
        let isFromUser: Bool
        var status: MessageStatus = .sent
        
        enum MessageStatus {
            case sending
            case sent
            case delivered
            case failed
        }
    }
    
    override init() {
        super.init()
        requestAuthorization()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        contactStore.requestAccess(for: .contacts) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted {
                    self?.loadContacts()
                } else if let error = error {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Contact Management
    
    private func loadContacts() {
        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactImageDataKey,
            CNContactThumbnailImageDataKey
        ] as [CNKeyDescriptor]
        
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        
        do {
            var fetchedContacts: [CNContact] = []
            try contactStore.enumerateContacts(with: request) { contact, _ in
                fetchedContacts.append(contact)
            }
            
            DispatchQueue.main.async {
                self.contacts = fetchedContacts.sorted { contact1, contact2 in
                    let name1 = contact1.givenName + contact1.familyName
                    let name2 = contact2.givenName + contact2.familyName
                    return name1 < name2
                }
                self.updateRecentContacts()
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func updateRecentContacts() {
        // Sort conversations by date and extract unique contacts
        let recentContactIds = Set(conversationHistory
            .sorted { $0.lastUpdated > $1.lastUpdated }
            .prefix(5)
            .map { $0.contact.identifier })
        
        recentContacts = contacts.filter { recentContactIds.contains($0.identifier) }
    }
    
    // MARK: - Message Processing
    
    func processVoiceCommand(_ text: String) -> (contact: CNContact?, message: String)? {
        nlTokenizer.string = text
        let tokens = nlTokenizer.tokens(for: text.startIndex..<text.endIndex)
            .map { String(text[$0]) }
        
        // Look for contact indicators
        let contactIndicators = ["to", "tell", "ask", "message", "text"]
        var contactName: String?
        var messageContent: String?
        
        for (index, token) in tokens.enumerated() {
            if contactIndicators.contains(token.lowercased()) && index + 1 < tokens.count {
                // Extract potential contact name
                contactName = tokens[index + 1]
                
                // Extract message content
                if index + 2 < tokens.count {
                    messageContent = tokens[(index + 2)...].joined(separator: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                break
            }
        }
        
        guard let name = contactName, let message = messageContent else { return nil }
        
        // Find matching contact
        let matchingContacts = contacts.filter { contact in
            contact.givenName.lowercased().contains(name.lowercased()) ||
            contact.familyName.lowercased().contains(name.lowercased())
        }
        
        if let contact = matchingContacts.first {
            return (contact, message)
        }
        
        return nil
    }
    
    func sendMessage(to contact: CNContact, content: String) async throws {
        guard let phoneNumber = contact.phoneNumbers.first?.value.stringValue else {
            throw MessageError.noPhoneNumber
        }
        
        // Create new message
        let message = Message(
            content: content,
            timestamp: Date(),
            isFromUser: true,
            status: .sending
        )
        
        // Update conversation history
        updateConversation(with: message, for: contact)
        
        do {
            // In a real app, this would use the Messages framework to send the message
            // For demo purposes, we'll simulate message sending
            try await simulateMessageSending()
            
            // Update message status
            updateMessageStatus(message.id, .delivered, for: contact)
        } catch {
            updateMessageStatus(message.id, .failed, for: contact)
            throw error
        }
    }
    
    private func simulateMessageSending() async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
        
        // Simulate random failure
        if Double.random(in: 0...1) < 0.1 {
            throw MessageError.sendingFailed
        }
    }
    
    private func updateConversation(with message: Message, for contact: CNContact) {
        DispatchQueue.main.async {
            if let index = self.conversationHistory.firstIndex(where: { $0.contact.identifier == contact.identifier }) {
                var conversation = self.conversationHistory[index]
                var messages = conversation.messages
                messages.append(message)
                
                self.conversationHistory[index] = Conversation(
                    contact: contact,
                    messages: messages,
                    lastUpdated: Date()
                )
            } else {
                self.conversationHistory.append(Conversation(
                    contact: contact,
                    messages: [message],
                    lastUpdated: Date()
                ))
            }
            
            self.updateRecentContacts()
        }
    }
    
    private func updateMessageStatus(_ messageId: UUID, _ status: Message.MessageStatus, for contact: CNContact) {
        DispatchQueue.main.async {
            if let conversationIndex = self.conversationHistory.firstIndex(where: { $0.contact.identifier == contact.identifier }),
               let messageIndex = self.conversationHistory[conversationIndex].messages.firstIndex(where: { $0.id == messageId }) {
                var conversation = self.conversationHistory[conversationIndex]
                var message = conversation.messages[messageIndex]
                message.status = status
                conversation.messages[messageIndex] = message
                self.conversationHistory[conversationIndex] = conversation
            }
        }
    }
    
    // MARK: - Quick Replies
    
    func generateQuickReplies(for contact: CNContact) -> [String] {
        let timeOfDay = Calendar.current.component(.hour, from: Date())
        var replies: [String] = []
        
        // Time-based greetings
        switch timeOfDay {
        case 5..<12:
            replies.append("Good morning!")
        case 12..<17:
            replies.append("Good afternoon!")
        case 17..<22:
            replies.append("Good evening!")
        default:
            replies.append("Hi!")
        }
        
        // Common responses
        replies += [
            "On my way!",
            "Running late, be there soon",
            "Can't talk right now, I'll call you later",
            "Thanks!",
            "Okay 👍",
            "Will do"
        ]
        
        return replies
    }
    
    // MARK: - Contact Helpers
    
    func formatContactName(_ contact: CNContact) -> String {
        let givenName = contact.givenName
        let familyName = contact.familyName
        
        if givenName.isEmpty && familyName.isEmpty {
            return "Unknown Contact"
        } else if givenName.isEmpty {
            return familyName
        } else if familyName.isEmpty {
            return givenName
        } else {
            return "\(givenName) \(familyName)"
        }
    }
    
    func contactDisplayName(_ contact: CNContact) -> String {
        contact.givenName.isEmpty ? contact.familyName : contact.givenName
    }
    
    // MARK: - Error Handling
    
    enum MessageError: Error {
        case notAuthorized
        case noPhoneNumber
        case sendingFailed
        case invalidContact
        
        var localizedDescription: String {
            switch self {
            case .notAuthorized:
                return "Not authorized to send messages"
            case .noPhoneNumber:
                return "No phone number available for contact"
            case .sendingFailed:
                return "Failed to send message"
            case .invalidContact:
                return "Invalid contact"
            }
        }
    }
}
