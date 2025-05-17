import SwiftUI
import Contacts

struct MessageView: View {
    @EnvironmentObject var messageManager: MessageManager
    @State private var selectedContact: CNContact?
    @State private var messageText = ""
    @State private var showingContactPicker = false
    @State private var showingVoiceInput = false
    @State private var isShowingError = false
    @State private var errorMessage = ""
    @State private var isSending = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Recent contacts
                if !messageManager.recentContacts.isEmpty {
                    recentContactsSection
                }
                
                // Message composition area
                messageCompositionArea
                
                // Quick actions
                quickActionButtons
                
                // Recent conversations
                if !messageManager.conversationHistory.isEmpty {
                    recentConversationsSection
                }
            }
            .padding()
        }
        .navigationTitle("Messages")
        .sheet(isPresented: $showingContactPicker) {
            ContactPickerView(selectedContact: $selectedContact)
        }
        .sheet(isPresented: $showingVoiceInput) {
            MessageVoiceInputView { text in
                processVoiceCommand(text)
            }
        }
        .alert("Error", isPresented: $isShowingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Recent Contacts Section
    
    private var recentContactsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(messageManager.recentContacts, id: \.identifier) { contact in
                        Button(action: {
                            selectedContact = contact
                        }) {
                            ContactAvatarView(contact: contact)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Message Composition Area
    
    private var messageCompositionArea: some View {
        VStack(spacing: 12) {
            // Selected contact or picker button
            if let contact = selectedContact {
                HStack {
                    ContactAvatarView(contact: contact)
                    
                    VStack(alignment: .leading) {
                        Text(messageManager.formatContactName(contact))
                            .font(.headline)
                        if let number = contact.phoneNumbers.first?.value.stringValue {
                            Text(number)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        selectedContact = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
            } else {
                Button(action: {
                    showingContactPicker = true
                }) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                        Text("Select Contact")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            
            // Message input
            if selectedContact != nil {
                HStack {
                    TextField("Message", text: $messageText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(messageText.isEmpty || isSending)
                }
            }
        }
    }
    
    // MARK: - Quick Action Buttons
    
    private var quickActionButtons: some View {
        HStack {
            // Voice input button
            Button(action: {
                showingVoiceInput = true
            }) {
                VStack {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                    Text("Voice")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.systemGray6))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
            
            // Quick replies
            if let contact = selectedContact {
                Button(action: {
                    showQuickReplies(for: contact)
                }) {
                    VStack {
                        Image(systemName: "text.bubble.fill")
                            .font(.title2)
                        Text("Quick Reply")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Recent Conversations Section
    
    private var recentConversationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Messages")
                .font(.headline)
            
            ForEach(messageManager.conversationHistory) { conversation in
                Button(action: {
                    selectedContact = conversation.contact
                }) {
                    ConversationRowView(conversation: conversation)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func sendMessage() {
        guard let contact = selectedContact else { return }
        let message = messageText
        messageText = ""
        isSending = true
        
        Task {
            do {
                try await messageManager.sendMessage(to: contact, content: message)
                isSending = false
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
                isSending = false
            }
        }
    }
    
    private func processVoiceCommand(_ text: String) {
        if let (contact, message) = messageManager.processVoiceCommand(text) {
            selectedContact = contact
            messageText = message
        } else {
            errorMessage = "Couldn't understand the command. Please try again."
            isShowingError = true
        }
    }
    
    private func showQuickReplies(for contact: CNContact) {
        let replies = messageManager.generateQuickReplies(for: contact)
        // Show quick replies in an action sheet or menu
    }
}

// MARK: - Supporting Views

struct ContactAvatarView: View {
    let contact: CNContact
    
    var body: some View {
        ZStack {
            if let imageData = contact.thumbnailImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }
}

struct ContactPickerView: View {
    @EnvironmentObject var messageManager: MessageManager
    @Environment(\.dismiss) var dismiss
    @Binding var selectedContact: CNContact?
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredContacts, id: \.identifier) { contact in
                    Button(action: {
                        selectedContact = contact
                        dismiss()
                    }) {
                        HStack {
                            ContactAvatarView(contact: contact)
                            Text(messageManager.formatContactName(contact))
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Select Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var filteredContacts: [CNContact] {
        if searchText.isEmpty {
            return messageManager.contacts
        } else {
            return messageManager.contacts.filter { contact in
                let name = messageManager.formatContactName(contact).lowercased()
                return name.contains(searchText.lowercased())
            }
        }
    }
}

struct ConversationRowView: View {
    let conversation: MessageManager.Conversation
    @EnvironmentObject var messageManager: MessageManager
    
    var body: some View {
        HStack {
            ContactAvatarView(contact: conversation.contact)
            
            VStack(alignment: .leading) {
                Text(messageManager.formatContactName(conversation.contact))
                    .font(.headline)
                
                if let lastMessage = conversation.messages.last {
                    Text(lastMessage.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(conversation.lastUpdated.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let lastMessage = conversation.messages.last,
                   lastMessage.isFromUser {
                    statusIcon(for: lastMessage.status)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    private func statusIcon(for status: MessageManager.Message.MessageStatus) -> some View {
        switch status {
        case .sending:
            return Image(systemName: "clock")
                .foregroundColor(.gray)
        case .sent:
            return Image(systemName: "checkmark")
                .foregroundColor(.gray)
        case .delivered:
            return Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.blue)
        case .failed:
            return Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
        }
    }
}

struct MessageVoiceInputView: View {
    let onRecognized: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var isListening = false
    @State private var recognizedText = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isListening ? "Listening..." : "Tap to speak")
                .font(.headline)
            
            ZStack {
                Circle()
                    .fill(isListening ? Color.red : Color.blue)
                    .frame(width: 80, height: 80)
                
                Image(systemName: isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
            .onTapGesture {
                if isListening {
                    stopListening()
                } else {
                    startListening()
                }
            }
            
            if !recognizedText.isEmpty {
                Text(recognizedText)
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
                
                Button("Use This") {
                    onRecognized(recognizedText)
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            
            Button("Cancel") {
                dismiss()
            }
            .padding(.top)
        }
        .padding()
    }
    
    private func startListening() {
        isListening = true
        // Implement actual speech recognition
    }
    
    private func stopListening() {
        isListening = false
        // Stop speech recognition
        
        // For demo purposes, simulate recognized text
        recognizedText = "Message John: I'll be there in 5 minutes"
    }
}
