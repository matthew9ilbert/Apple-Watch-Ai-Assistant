import SwiftUI
import EventKit

struct ReminderView: View {
    @EnvironmentObject var reminderManager: ReminderManager
    @State private var newReminderText = ""
    @State private var showingInput = false
    @State private var showingVoiceInput = false
    @State private var showingSuggestions = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var isProcessing = false
    @State private var selectedFilter: ReminderFilter = .all
    
    enum ReminderFilter {
        case all
        case today
        case scheduled
        case overdue
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Quick add button
                quickAddButton
                
                // Filter selection
                filterPicker
                
                // Reminders list
                remindersList
                
                // Suggestions (when no reminders)
                if filteredReminders.isEmpty && !isProcessing {
                    emptyStateView
                }
            }
            .padding()
        }
        .navigationTitle("Reminders")
        .sheet(isPresented: $showingInput) {
            ReminderInputView(
                reminderText: $newReminderText,
                isPresented: $showingInput,
                onSave: createReminder
            )
        }
        .sheet(isPresented: $showingVoiceInput) {
            VoiceInputView(onRecognized: { text in
                newReminderText = text
                showingVoiceInput = false
                showingInput = true
            })
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }
    
    // MARK: - Quick Add Button
    
    private var quickAddButton: some View {
        HStack(spacing: 12) {
            // Text input button
            Button(action: {
                showingInput = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Reminder")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            // Voice input button
            Button(action: {
                showingVoiceInput = true
            }) {
                Image(systemName: "mic.fill")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Filter Picker
    
    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            Text("All").tag(ReminderFilter.all)
            Text("Today").tag(ReminderFilter.today)
            Text("Scheduled").tag(ReminderFilter.scheduled)
            Text("Overdue").tag(ReminderFilter.overdue)
        }
        .pickerStyle(SegmentedPickerStyle())
    }
    
    // MARK: - Reminders List
    
    private var remindersList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredReminders, id: \.calendarItemIdentifier) { reminder in
                ReminderRowView(reminder: reminder) {
                    try? reminderManager.completeReminder(reminder)
                } onDelete: {
                    try? reminderManager.deleteReminder(reminder)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.circle")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No reminders")
                .font(.headline)
                .foregroundColor(.gray)
            
            // Quick suggestions
            if showingSuggestions {
                suggestionsList
            } else {
                Button("Show Suggestions") {
                    showingSuggestions = true
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 40)
    }
    
    private var suggestionsList: some View {
        VStack(spacing: 12) {
            Text("Quick Add")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ForEach(reminderManager.suggestCommonReminders(), id: \.self) { suggestion in
                Button(action: {
                    newReminderText = suggestion
                    showingInput = true
                }) {
                    HStack {
                        Text(suggestion)
                        Spacer()
                        Image(systemName: "plus.circle")
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var filteredReminders: [EKReminder] {
        let reminders = reminderManager.reminders
        
        switch selectedFilter {
        case .all:
            return reminders
            
        case .today:
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return Calendar.current.isDateInToday(dueDate)
            }
            
        case .scheduled:
            return reminders.filter { $0.dueDateComponents != nil }
            
        case .overdue:
            return reminders.filter { $0.isOverdue }
        }
    }
    
    private func createReminder() {
        guard !newReminderText.isEmpty else { return }
        isProcessing = true
        
        Task {
            do {
                try await reminderManager.createReminder(from: newReminderText)
                newReminderText = ""
                isProcessing = false
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
                isProcessing = false
            }
        }
    }
}

// MARK: - Supporting Views

struct ReminderRowView: View {
    let reminder: EKReminder
    let onComplete: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDetails = false
    
    var body: some View {
        Button(action: { showingDetails.toggle() }) {
            HStack {
                // Completion checkbox
                Button(action: onComplete) {
                    Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(reminder.isCompleted ? .green : .gray)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Reminder content
                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.title)
                        .strikethrough(reminder.isCompleted)
                        .foregroundColor(reminder.isCompleted ? .gray : .primary)
                    
                    if let dueDate = reminder.dueDateComponents?.date {
                        Text(dueDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(reminder.isOverdue ? .red : .secondary)
                    }
                }
                
                Spacer()
                
                // Priority indicator
                if reminder.priority > 0 {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(priorityColor(reminder.priority))
                }
                
                // Location indicator
                if reminder.hasStructuredLocation {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showingDetails) {
            ReminderDetailView(reminder: reminder, onComplete: onComplete, onDelete: onDelete)
        }
    }
    
    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 1: return .red      // High
        case 5: return .orange   // Medium
        case 9: return .yellow   // Low
        default: return .gray
        }
    }
}

struct ReminderInputView: View {
    @Binding var reminderText: String
    @Binding var isPresented: Bool
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextField("Add a reminder...", text: $reminderText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Text("Examples:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("• Call mom tomorrow at 2pm")
                    Text("• Buy groceries at Walmart")
                    Text("• Take medication every day at 9am")
                    Text("• High priority meeting next Monday at 10am")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave()
                        isPresented = false
                    }
                    .disabled(reminderText.isEmpty)
                }
            }
        }
    }
}

struct ReminderDetailView: View {
    let reminder: EKReminder
    let onComplete: () -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Details") {
                    HStack {
                        Text("Title")
                        Spacer()
                        Text(reminder.title)
                            .foregroundColor(.secondary)
                    }
                    
                    if let notes = reminder.notes {
                        HStack {
                            Text("Notes")
                            Spacer()
                            Text(notes)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let dueDate = reminder.dueDateComponents?.date {
                        HStack {
                            Text("Due Date")
                            Spacer()
                            Text(dueDate.formatted())
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if reminder.hasStructuredLocation {
                        HStack {
                            Text("Location")
                            Spacer()
                            Text(reminder.structuredLocation?.title ?? "")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if reminder.priority > 0 {
                        HStack {
                            Text("Priority")
                            Spacer()
                            Text(priorityText(reminder.priority))
                                .foregroundColor(priorityColor(reminder.priority))
                        }
                    }
                }
                
                Section {
                    Button(action: onComplete) {
                        HStack {
                            Text(reminder.isCompleted ? "Mark Incomplete" : "Mark Complete")
                            Spacer()
                            Image(systemName: reminder.isCompleted ? "xmark.circle" : "checkmark.circle")
                        }
                    }
                    
                    Button(role: .destructive, action: {
                        onDelete()
                        dismiss()
                    }) {
                        HStack {
                            Text("Delete Reminder")
                            Spacer()
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Reminder Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func priorityText(_ priority: Int) -> String {
        switch priority {
        case 1: return "High"
        case 5: return "Medium"
        case 9: return "Low"
        default: return "None"
        }
    }
    
    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 1: return .red
        case 5: return .orange
        case 9: return .yellow
        default: return .gray
        }
    }
}

struct VoiceInputView: View {
    let onRecognized: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var isListening = false
    @State private var recognizedText = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isListening ? "Listening..." : "Tap to speak")
                .font(.headline)
            
            Button(action: {
                if isListening {
                    stopListening()
                } else {
                    startListening()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isListening ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: isListening ? "waveform" : "mic.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
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
        }
        .padding()
    }
    
    private func startListening() {
        isListening = true
        // Implement speech recognition
    }
    
    private func stopListening() {
        isListening = false
        // Stop speech recognition
    }
}
