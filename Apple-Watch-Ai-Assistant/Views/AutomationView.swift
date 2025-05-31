import SwiftUI
import Intents
import IntentsUI

struct AutomationView: View {
    @EnvironmentObject var automationManager: AutomationManager
    @State private var showingNewShortcut = false
    @State private var showingNewAutomation = false
    @State private var selectedSection: AutomationType = .shortcuts
    @State private var searchText = ""
    
    enum AutomationType {
        case shortcuts
        case automations
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Section picker
                Picker("Type", selection: $selectedSection) {
                    Text("Shortcuts").tag(AutomationType.shortcuts)
                    Text("Automations").tag(AutomationType.automations)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Search bar
                SearchBar(text: $searchText)
                
                // Content based on selected section
                switch selectedSection {
                case .shortcuts:
                    shortcutsSection
                case .automations:
                    automationsSection
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Automations")
        .sheet(isPresented: $showingNewShortcut) {
            ShortcutCreationView()
        }
        .sheet(isPresented: $showingNewAutomation) {
            AutomationCreationView()
        }
    }
    
    // MARK: - Shortcuts Section
    
    private var shortcutsSection: some View {
        VStack(spacing: 16) {
            // Quick actions
            quickActionsGrid
            
            // Existing shortcuts
            ForEach(filteredShortcuts) { shortcut in
                ShortcutCard(shortcut: shortcut)
            }
            
            // Add button
            addButton(type: .shortcuts)
        }
        .padding(.horizontal)
    }
    
    private var quickActionsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            QuickActionButton(
                title: "Morning Routine",
                icon: "sunrise.fill",
                color: .orange
            ) {
                activateShortcut("Morning Routine")
            }
            
            QuickActionButton(
                title: "Start Workout",
                icon: "figure.run",
                color: .green
            ) {
                activateShortcut("Start Workout")
            }
            
            QuickActionButton(
                title: "Weather Check",
                icon: "cloud.sun.fill",
                color: .blue
            ) {
                activateShortcut("Weather Check")
            }
            
            QuickActionButton(
                title: "Night Mode",
                icon: "moon.fill",
                color: .purple
            ) {
                activateShortcut("Night Mode")
            }
        }
    }
    
    // MARK: - Automations Section
    
    private var automationsSection: some View {
        VStack(spacing: 16) {
            // Existing automations
            ForEach(filteredAutomations) { automation in
                AutomationCard(automation: automation)
            }
            
            // Add button
            addButton(type: .automations)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Supporting Views
    
    private func addButton(type: AutomationType) -> some View {
        Button(action: {
            switch type {
            case .shortcuts:
                showingNewShortcut = true
            case .automations:
                showingNewAutomation = true
            }
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add \(type == .shortcuts ? "Shortcut" : "Automation")")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Helper Methods
    
    private var filteredShortcuts: [AutomationManager.ShortcutDefinition] {
        if searchText.isEmpty {
            return automationManager.availableShortcuts
        } else {
            return automationManager.availableShortcuts.filter {
                $0.name.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    private var filteredAutomations: [AutomationManager.AutomationRule] {
        if searchText.isEmpty {
            return automationManager.customAutomations
        } else {
            return automationManager.customAutomations.filter {
                $0.name.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    private func activateShortcut(_ name: String) {
        guard let shortcut = automationManager.availableShortcuts.first(where: { $0.name == name }) else {
            return
        }
        
        Task {
            await automationManager.executeAutomation(AutomationManager.AutomationRule(
                id: shortcut.id,
                name: shortcut.name,
                trigger: shortcut.trigger,
                actions: shortcut.actions,
                conditions: shortcut.conditions,
                isEnabled: true
            ))
        }
    }
}

// MARK: - Supporting Views

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.horizontal)
    }
}

struct ShortcutCard: View {
    let shortcut: AutomationManager.ShortcutDefinition
    @State private var isEnabled: Bool
    
    init(shortcut: AutomationManager.ShortcutDefinition) {
        self.shortcut = shortcut
        _isEnabled = State(initialValue: shortcut.isEnabled)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(shortcut.name)
                    .font(.headline)
                
                Spacer()
                
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
            }
            
            if let schedule = shortcut.schedule {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text(scheduleDescription(schedule))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                ForEach(shortcut.actions, id: \.rawValue) { action in
                    Image(systemName: iconName(for: action))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    private func scheduleDescription(_ schedule: AutomationManager.ShortcutDefinition.Schedule) -> String {
        switch schedule.frequency {
        case .once:
            return "One time"
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        }
    }
    
    private func iconName(for action: AutomationManager.ActionType) -> String {
        switch action {
        case .notification:
            return "bell.fill"
        case .healthCheck:
            return "heart.fill"
        case .weatherUpdate:
            return "cloud.sun.fill"
        case .homeControl:
            return "house.fill"
        case .appLaunch:
            return "app.fill"
        case .reminder:
            return "calendar"
        case .message:
            return "message.fill"
        case .shortcut:
            return "link"
        }
    }
}

struct AutomationCard: View {
    let automation: AutomationManager.AutomationRule
    @State private var isEnabled: Bool
    
    init(automation: AutomationManager.AutomationRule) {
        self.automation = automation
        _isEnabled = State(initialValue: automation.isEnabled)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(automation.name)
                    .font(.headline)
                
                Spacer()
                
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
            }
            
            HStack {
                Image(systemName: triggerIcon)
                    .foregroundColor(.orange)
                Text(triggerDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !automation.conditions.isEmpty {
                Text("Conditions: \(automation.conditions.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    private var triggerIcon: String {
        switch automation.trigger {
        case .time:
            return "clock.fill"
        case .location:
            return "location.fill"
        case .healthEvent:
            return "heart.fill"
        case .weatherChange:
            return "cloud.sun.fill"
        case .deviceEvent:
            return "iphone"
        case .appLaunch:
            return "app.fill"
        case .voiceCommand:
            return "waveform"
        }
    }
    
    private var triggerDescription: String {
        switch automation.trigger {
        case .time:
            return "Time-based"
        case .location:
            return "Location-based"
        case .healthEvent:
            return "Health event"
        case .weatherChange:
            return "Weather change"
        case .deviceEvent:
            return "Device event"
        case .appLaunch:
            return "App launch"
        case .voiceCommand:
            return "Voice command"
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(12)
        }
    }
}

// MARK: - Creation Views

struct ShortcutCreationView: View {
    @Environment(\.dismiss) var dismiss
    @State private var shortcutName = ""
    @State private var selectedTrigger: AutomationManager.TriggerType = .time
    @State private var selectedActions: Set<AutomationManager.ActionType> = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Info")) {
                    TextField("Shortcut Name", text: $shortcutName)
                }
                
                Section(header: Text("Trigger")) {
                    Picker("Trigger Type", selection: $selectedTrigger) {
                        ForEach(AutomationManager.TriggerType.allCases, id: \.rawValue) { trigger in
                            Text(trigger.rawValue.capitalized).tag(trigger)
                        }
                    }
                }
                
                Section(header: Text("Actions")) {
                    ForEach(AutomationManager.ActionType.allCases, id: \.rawValue) { action in
                        Toggle(action.rawValue.capitalized, isOn: Binding(
                            get: { selectedActions.contains(action) },
                            set: { isSelected in
                                if isSelected {
                                    selectedActions.insert(action)
                                } else {
                                    selectedActions.remove(action)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("New Shortcut")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createShortcut()
                        dismiss()
                    }
                    .disabled(shortcutName.isEmpty || selectedActions.isEmpty)
                }
            }
        }
    }
    
    private func createShortcut() {
        let shortcut = AutomationManager.ShortcutDefinition(
            id: UUID(),
            name: shortcutName,
            trigger: selectedTrigger,
            actions: Array(selectedActions),
            isEnabled: true,
            schedule: nil,
            conditions: []
        )
        AutomationManager.shared.createShortcut(shortcut)
    }
}

struct AutomationCreationView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Text("Create Automation")
                .navigationTitle("New Automation")
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
}

// MARK: - Extensions

extension AutomationManager.TriggerType: CaseIterable {
    static var allCases: [AutomationManager.TriggerType] = [
        .time,
        .location,
        .healthEvent,
        .weatherChange,
        .deviceEvent,
        .appLaunch,
        .voiceCommand
    ]
}

extension AutomationManager.ActionType: CaseIterable {
    static var allCases: [AutomationManager.ActionType] = [
        .notification,
        .healthCheck,
        .weatherUpdate,
        .homeControl,
        .appLaunch,
        .reminder,
        .message,
        .shortcut
    ]
}
