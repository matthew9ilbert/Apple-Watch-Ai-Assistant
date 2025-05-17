import Intents
import IntentsUI
import SwiftUI

class ShortcutProvider: INUIAppIntentProvider {
    override func suggestedShortcuts() -> [INShortcut] {
        var shortcuts: [INShortcut] = []
        
        // Add predefined shortcuts
        shortcuts += createWorkoutShortcuts()
        shortcuts += createHomeShortcuts()
        shortcuts += createWeatherShortcuts()
        shortcuts += createReminderShortcuts()
        shortcuts += createRoutineShortcuts()
        
        return shortcuts
    }
    
    override func shortcutImage(for shortcut: INShortcut) -> INImage? {
        // Provide custom images for shortcuts
        guard let intent = shortcut.intent else { return nil }
        
        switch intent {
        case is StartWorkoutIntent:
            return INImage(systemImageName: "figure.run")
        case is CheckWeatherIntent:
            return INImage(systemImageName: "cloud.sun.fill")
        case is ControlHomeDeviceIntent:
            return INImage(systemImageName: "house.fill")
        case is SetReminderIntent:
            return INImage(systemImageName: "calendar.badge.plus")
        case is SendMessageIntent:
            return INImage(systemImageName: "message.fill")
        case is ExecuteShortcutIntent:
            return INImage(systemImageName: "link")
        default:
            return nil
        }
    }
    
    // MARK: - Workout Shortcuts
    
    private func createWorkoutShortcuts() -> [INShortcut] {
        let workoutTypes = ["Running", "Walking", "Cycling", "Swimming", "Yoga", "HIIT"]
        
        return workoutTypes.map { workoutType in
            let intent = StartWorkoutIntent()
            intent.workoutType = workoutType
            intent.suggestedInvocationPhrase = "Start \(workoutType.lowercased()) workout"
            
            return INShortcut(intent: intent)
        }
    }
    
    // MARK: - Home Control Shortcuts
    
    private func createHomeShortcuts() -> [INShortcut] {
        var shortcuts: [INShortcut] = []
        
        // Morning scene
        let morningIntent = ControlHomeDeviceIntent()
        morningIntent.action = "Morning"
        morningIntent.suggestedInvocationPhrase = "Good morning scene"
        shortcuts.append(INShortcut(intent: morningIntent))
        
        // Night scene
        let nightIntent = ControlHomeDeviceIntent()
        nightIntent.action = "Night"
        nightIntent.suggestedInvocationPhrase = "Good night scene"
        shortcuts.append(INShortcut(intent: nightIntent))
        
        // Away mode
        let awayIntent = ControlHomeDeviceIntent()
        awayIntent.action = "Away"
        awayIntent.suggestedInvocationPhrase = "Set away mode"
        shortcuts.append(INShortcut(intent: awayIntent))
        
        return shortcuts
    }
    
    // MARK: - Weather Shortcuts
    
    private func createWeatherShortcuts() -> [INShortcut] {
        let weatherIntent = CheckWeatherIntent()
        weatherIntent.suggestedInvocationPhrase = "Check weather"
        
        return [INShortcut(intent: weatherIntent)]
    }
    
    // MARK: - Reminder Shortcuts
    
    private func createReminderShortcuts() -> [INShortcut] {
        var shortcuts: [INShortcut] = []
        
        // Quick reminder
        let quickIntent = SetReminderIntent()
        quickIntent.suggestedInvocationPhrase = "Set quick reminder"
        shortcuts.append(INShortcut(intent: quickIntent))
        
        // Scheduled reminder
        let scheduledIntent = SetReminderIntent()
        scheduledIntent.suggestedInvocationPhrase = "Schedule reminder"
        shortcuts.append(INShortcut(intent: scheduledIntent))
        
        return shortcuts
    }
    
    // MARK: - Routine Shortcuts
    
    private func createRoutineShortcuts() -> [INShortcut] {
        var shortcuts: [INShortcut] = []
        
        // Morning routine
        let morningRoutine = createRoutineShortcut(
            name: "Morning Routine",
            phrase: "Start my morning",
            actions: [
                (CheckWeatherIntent(), "Check weather"),
                (ControlHomeDeviceIntent(), "Morning lights"),
                (SetReminderIntent(), "Daily tasks")
            ]
        )
        shortcuts.append(morningRoutine)
        
        // Workout routine
        let workoutRoutine = createRoutineShortcut(
            name: "Workout Mode",
            phrase: "Start workout mode",
            actions: [
                (StartWorkoutIntent(), "Begin workout"),
                (ControlHomeDeviceIntent(), "Adjust temperature"),
                (SetReminderIntent(), "Post-workout reminder")
            ]
        )
        shortcuts.append(workoutRoutine)
        
        // Night routine
        let nightRoutine = createRoutineShortcut(
            name: "Night Mode",
            phrase: "Enable night mode",
            actions: [
                (ControlHomeDeviceIntent(), "Night scene"),
                (SetReminderIntent(), "Morning alarm"),
                (CheckWeatherIntent(), "Tomorrow's weather")
            ]
        )
        shortcuts.append(nightRoutine)
        
        return shortcuts
    }
    
    private func createRoutineShortcut(
        name: String,
        phrase: String,
        actions: [(INIntent, String)]
    ) -> INShortcut {
        let shortcut = ExecuteShortcutIntent()
        shortcut.shortcutName = name
        shortcut.suggestedInvocationPhrase = phrase
        
        return INShortcut(intent: shortcut)
    }
}

// MARK: - Shortcut Configuration UI

struct ShortcutConfigurationView: View {
    let shortcut: INShortcut
    @Binding var isEnabled: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Shortcut icon and name
            HStack {
                if let image = ShortcutProvider().shortcutImage(for: shortcut) {
                    Image(uiImage: image.image)
                        .resizable()
                        .frame(width: 40, height: 40)
                }
                
                VStack(alignment: .leading) {
                    Text(shortcut.intent?.intentDescription ?? "")
                        .font(.headline)
                    Text(shortcut.intent?.suggestedInvocationPhrase ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
            }
            
            // Shortcut options
            if let intent = shortcut.intent {
                ShortcutOptionsView(intent: intent)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
}

struct ShortcutOptionsView: View {
    let intent: INIntent
    
    var body: some View {
        Group {
            switch intent {
            case is StartWorkoutIntent:
                workoutOptions
            case is ControlHomeDeviceIntent:
                homeOptions
            case is SetReminderIntent:
                reminderOptions
            default:
                EmptyView()
            }
        }
    }
    
    private var workoutOptions: some View {
        VStack {
            Text("Workout Options")
                .font(.subheadline)
            // Add workout-specific options
        }
    }
    
    private var homeOptions: some View {
        VStack {
            Text("Home Control Options")
                .font(.subheadline)
            // Add home control options
        }
    }
    
    private var reminderOptions: some View {
        VStack {
            Text("Reminder Options")
                .font(.subheadline)
            // Add reminder options
        }
    }
}

// MARK: - Extensions

extension INIntent {
    var intentDescription: String {
        switch self {
        case is StartWorkoutIntent:
            return "Start Workout"
        case is CheckWeatherIntent:
            return "Check Weather"
        case is ControlHomeDeviceIntent:
            return "Control Home"
        case is SetReminderIntent:
            return "Set Reminder"
        case is SendMessageIntent:
            return "Send Message"
        case is ExecuteShortcutIntent:
            return "Run Shortcut"
        default:
            return "Unknown Intent"
        }
    }
}
