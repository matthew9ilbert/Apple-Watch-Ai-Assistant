import Intents
import CoreLocation
import HealthKit
import HomeKit

class IntentHandler: INExtension {
    override func handler(for intent: INIntent) -> Any {
        switch intent {
        case is StartWorkoutIntent:
            return StartWorkoutIntentHandler()
        case is CheckWeatherIntent:
            return CheckWeatherIntentHandler()
        case is ControlHomeDeviceIntent:
            return ControlHomeDeviceIntentHandler()
        case is SetReminderIntent:
            return SetReminderIntentHandler()
        case is SendMessageIntent:
            return SendMessageIntentHandler()
        case is ExecuteShortcutIntent:
            return ExecuteShortcutIntentHandler()
        default:
            return self
        }
    }
}

// MARK: - Workout Intent Handler
class StartWorkoutIntentHandler: NSObject, StartWorkoutIntentHandling {
    func handle(intent: StartWorkoutIntent, completion: @escaping (StartWorkoutIntentResponse) -> Void) {
        let workoutManager = WorkoutManager()
        
        guard let workoutType = intent.workoutType else {
            completion(StartWorkoutIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        // Convert intent workout type to HKWorkoutActivityType
        let activityType = convertToHKWorkoutType(workoutType)
        
        // Start the workout
        workoutManager.startWorkout(activityType)
        
        completion(StartWorkoutIntentResponse(code: .success, userActivity: nil))
    }
    
    private func convertToHKWorkoutType(_ type: String) -> HKWorkoutActivityType {
        switch type.lowercased() {
        case "running":
            return .running
        case "walking":
            return .walking
        case "cycling":
            return .cycling
        case "swimming":
            return .swimming
        default:
            return .other
        }
    }
}

// MARK: - Weather Intent Handler
class CheckWeatherIntentHandler: NSObject, CheckWeatherIntentHandling {
    func handle(intent: CheckWeatherIntent, completion: @escaping (CheckWeatherIntentResponse) -> Void) {
        let weatherManager = WeatherManager()
        
        Task {
            do {
                await weatherManager.fetchWeather()
                
                if let weather = weatherManager.currentWeather {
                    let response = CheckWeatherIntentResponse(code: .success, userActivity: nil)
                    response.temperature = weather.formattedTemperature
                    response.condition = weather.condition.rawValue
                    completion(response)
                } else {
                    completion(CheckWeatherIntentResponse(code: .failure, userActivity: nil))
                }
            }
        }
    }
}

// MARK: - Home Control Intent Handler
class ControlHomeDeviceIntentHandler: NSObject, ControlHomeDeviceIntentHandling {
    func handle(intent: ControlHomeDeviceIntent, completion: @escaping (ControlHomeDeviceIntentResponse) -> Void) {
        let homeManager = HomeAutomationManager()
        
        guard let deviceId = intent.deviceIdentifier,
              let action = intent.action else {
            completion(ControlHomeDeviceIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        Task {
            do {
                try await homeManager.controlDevice(deviceId, action: action)
                completion(ControlHomeDeviceIntentResponse(code: .success, userActivity: nil))
            } catch {
                completion(ControlHomeDeviceIntentResponse(code: .failure, userActivity: nil))
            }
        }
    }
}

// MARK: - Reminder Intent Handler
class SetReminderIntentHandler: NSObject, SetReminderIntentHandling {
    func handle(intent: SetReminderIntent, completion: @escaping (SetReminderIntentResponse) -> Void) {
        let reminderManager = ReminderManager()
        
        guard let title = intent.title else {
            completion(SetReminderIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        Task {
            do {
                try await reminderManager.createReminder(from: title)
                completion(SetReminderIntentResponse(code: .success, userActivity: nil))
            } catch {
                completion(SetReminderIntentResponse(code: .failure, userActivity: nil))
            }
        }
    }
}

// MARK: - Message Intent Handler
class SendMessageIntentHandler: NSObject, SendMessageIntentHandling {
    func handle(intent: SendMessageIntent, completion: @escaping (SendMessageIntentResponse) -> Void) {
        let messageManager = MessageManager()
        
        guard let recipient = intent.recipient,
              let content = intent.content else {
            completion(SendMessageIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        Task {
            do {
                try await messageManager.sendMessage(to: recipient, content: content)
                completion(SendMessageIntentResponse(code: .success, userActivity: nil))
            } catch {
                completion(SendMessageIntentResponse(code: .failure, userActivity: nil))
            }
        }
    }
}

// MARK: - Shortcut Intent Handler
class ExecuteShortcutIntentHandler: NSObject, ExecuteShortcutIntentHandling {
    func handle(intent: ExecuteShortcutIntent, completion: @escaping (ExecuteShortcutIntentResponse) -> Void) {
        let automationManager = AutomationManager.shared
        
        guard let shortcutName = intent.shortcutName else {
            completion(ExecuteShortcutIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        if let shortcut = automationManager.availableShortcuts.first(where: { $0.name == shortcutName }) {
            Task {
                await automationManager.executeAutomation(AutomationManager.AutomationRule(
                    id: shortcut.id,
                    name: shortcut.name,
                    trigger: shortcut.trigger,
                    actions: shortcut.actions,
                    conditions: shortcut.conditions,
                    isEnabled: true
                ))
                completion(ExecuteShortcutIntentResponse(code: .success, userActivity: nil))
            }
        } else {
            completion(ExecuteShortcutIntentResponse(code: .failure, userActivity: nil))
        }
    }
}

// MARK: - Custom Intent Definitions
@objc(StartWorkoutIntent)
class StartWorkoutIntent: INIntent {
    @objc dynamic var workoutType: String?
}

@objc(CheckWeatherIntent)
class CheckWeatherIntent: INIntent {
}

@objc(ControlHomeDeviceIntent)
class ControlHomeDeviceIntent: INIntent {
    @objc dynamic var deviceIdentifier: String?
    @objc dynamic var action: String?
}

@objc(SetReminderIntent)
class SetReminderIntent: INIntent {
    @objc dynamic var title: String?
    @objc dynamic var dueDate: Date?
}

@objc(SendMessageIntent)
class SendMessageIntent: INIntent {
    @objc dynamic var recipient: INPerson?
    @objc dynamic var content: String?
}

@objc(ExecuteShortcutIntent)
class ExecuteShortcutIntent: INIntent {
    @objc dynamic var shortcutName: String?
}

// MARK: - Intent Response Definitions
@objc(StartWorkoutIntentResponse)
class StartWorkoutIntentResponse: INIntentResponse {
    @objc(StartWorkoutIntentResponseCode)
    enum ResponseCode: Int {
        case success
        case failure
    }
    
    @objc var code: ResponseCode = .success
}

@objc(CheckWeatherIntentResponse)
class CheckWeatherIntentResponse: INIntentResponse {
    @objc(CheckWeatherIntentResponseCode)
    enum ResponseCode: Int {
        case success
        case failure
    }
    
    @objc var code: ResponseCode = .success
    @objc dynamic var temperature: String?
    @objc dynamic var condition: String?
}

@objc(ControlHomeDeviceIntentResponse)
class ControlHomeDeviceIntentResponse: INIntentResponse {
    @objc(ControlHomeDeviceIntentResponseCode)
    enum ResponseCode: Int {
        case success
        case failure
    }
    
    @objc var code: ResponseCode = .success
}

@objc(SetReminderIntentResponse)
class SetReminderIntentResponse: INIntentResponse {
    @objc(SetReminderIntentResponseCode)
    enum ResponseCode: Int {
        case success
        case failure
    }
    
    @objc var code: ResponseCode = .success
}

@objc(SendMessageIntentResponse)
class SendMessageIntentResponse: INIntentResponse {
    @objc(SendMessageIntentResponseCode)
    enum ResponseCode: Int {
        case success
        case failure
    }
    
    @objc var code: ResponseCode = .success
}

@objc(ExecuteShortcutIntentResponse)
class ExecuteShortcutIntentResponse: INIntentResponse {
    @objc(ExecuteShortcutIntentResponseCode)
    enum ResponseCode: Int {
        case success
        case failure
    }
    
    @objc var code: ResponseCode = .success
}
