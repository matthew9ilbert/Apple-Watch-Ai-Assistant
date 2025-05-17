import Foundation
import CoreData

// MARK: - UserPreference
@objc(UserPreference)
public class UserPreference: NSManagedObject {
    @NSManaged public var key: String
    @NSManaged public var value: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var modificationDate: Date
}

// MARK: - HealthMetric
@objc(HealthMetric)
public class HealthMetric: NSManagedObject {
    @NSManaged public var metricType: String
    @NSManaged public var value: Double
    @NSManaged public var unit: String
    @NSManaged public var timestamp: Date
    @NSManaged public var createdAt: Date
    @NSManaged public var modificationDate: Date
    
    var formattedValue: String {
        switch unit {
        case "count":
            return String(format: "%.0f", value)
        case "bpm":
            return String(format: "%.0f BPM", value)
        case "kcal":
            return String(format: "%.0f cal", value)
        case "km":
            return String(format: "%.1f km", value)
        default:
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - WorkoutSession
@objc(WorkoutSession)
public class WorkoutSession: NSManagedObject {
    @NSManaged public var activityType: String
    @NSManaged public var startDate: Date
    @NSManaged public var endDate: Date?
    @NSManaged public var duration: Double
    @NSManaged public var distance: Double
    @NSManaged public var calories: Double
    @NSManaged public var averageHeartRate: Double
    @NSManaged public var metrics: Set<WorkoutMetric>
    @NSManaged public var createdAt: Date
    @NSManaged public var modificationDate: Date
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var formattedDistance: String {
        String(format: "%.2f km", distance / 1000)
    }
}

// MARK: - WorkoutMetric
@objc(WorkoutMetric)
public class WorkoutMetric: NSManagedObject {
    @NSManaged public var metricType: String
    @NSManaged public var value: Double
    @NSManaged public var timestamp: Date
    @NSManaged public var session: WorkoutSession
    @NSManaged public var createdAt: Date
    @NSManaged public var modificationDate: Date
}

// MARK: - Reminder
@objc(Reminder)
public class Reminder: NSManagedObject {
    @NSManaged public var title: String
    @NSManaged public var notes: String?
    @NSManaged public var dueDate: Date?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var priority: Int16
    @NSManaged public var locationName: String?
    @NSManaged public var locationLatitude: Double
    @NSManaged public var locationLongitude: Double
    @NSManaged public var recurringType: String?
    @NSManaged public var recurringInterval: Int32
    @NSManaged public var createdAt: Date
    @NSManaged public var modificationDate: Date
    
    var isOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        return Date() > dueDate
    }
    
    var priorityLevel: PriorityLevel {
        get {
            PriorityLevel(rawValue: Int(priority)) ?? .none
        }
        set {
            priority = Int16(newValue.rawValue)
        }
    }
    
    enum PriorityLevel: Int {
        case none = 0
        case low = 1
        case medium = 2
        case high = 3
        
        var description: String {
            switch self {
            case .none: return "None"
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
    }
}

// MARK: - Message
@objc(Message)
public class Message: NSManagedObject {
    @NSManaged public var content: String
    @NSManaged public var timestamp: Date
    @NSManaged public var isFromUser: Bool
    @NSManaged public var recipientIdentifier: String
    @NSManaged public var recipientName: String
    @NSManaged public var status: String
    @NSManaged public var createdAt: Date
    @NSManaged public var modificationDate: Date
    
    var messageStatus: MessageStatus {
        get {
            MessageStatus(rawValue: status) ?? .sent
        }
        set {
            status = newValue.rawValue
        }
    }
    
    enum MessageStatus: String {
        case sending = "sending"
        case sent = "sent"
        case delivered = "delivered"
        case failed = "failed"
        
        var description: String {
            rawValue.capitalized
        }
    }
}

// MARK: - WeatherData
@objc(WeatherData)
public class WeatherData: NSManagedObject {
    @NSManaged public var temperature: Double
    @NSManaged public var condition: String
    @NSManaged public var humidity: Double
    @NSManaged public var windSpeed: Double
    @NSManaged public var windDirection: Double
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var locationName: String?
    @NSManaged public var timestamp: Date
    @NSManaged public var createdAt: Date
    @NSManaged public var modificationDate: Date
    
    var formattedTemperature: String {
        String(format: "%.1f°", temperature)
    }
    
    var formattedHumidity: String {
        String(format: "%.0f%%", humidity * 100)
    }
    
    var formattedWindSpeed: String {
        String(format: "%.1f mph", windSpeed)
    }
    
    var formattedWindDirection: String {
        String(format: "%.0f°", windDirection)
    }
}

// MARK: - VoiceCommand
@objc(VoiceCommand)
public class VoiceCommand: NSManagedObject {
    @NSManaged public var command: String
    @NSManaged public var category: String
    @NSManaged public var timestamp: Date
    @NSManaged public var successful: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var modificationDate: Date
    
    var commandCategory: CommandCategory {
        get {
            CommandCategory(rawValue: category) ?? .other
        }
        set {
            category = newValue.rawValue
        }
    }
    
    enum CommandCategory: String {
        case assistant = "Assistant"
        case health = "Health"
        case workout = "Workout"
        case weather = "Weather"
        case reminder = "Reminder"
        case message = "Message"
        case other = "Other"
        
        var description: String {
            rawValue
        }
    }
}

// MARK: - Extensions

extension UserPreference {
    convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "UserPreference", in: context)!
        self.init(entity: entity, insertInto: context)
        self.createdAt = Date()
        self.modificationDate = Date()
    }
}

extension HealthMetric {
    convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "HealthMetric", in: context)!
        self.init(entity: entity, insertInto: context)
        self.createdAt = Date()
        self.modificationDate = Date()
        self.timestamp = Date()
    }
}

extension WorkoutSession {
    convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "WorkoutSession", in: context)!
        self.init(entity: entity, insertInto: context)
        self.createdAt = Date()
        self.modificationDate = Date()
        self.startDate = Date()
    }
}

extension WorkoutMetric {
    convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "WorkoutMetric", in: context)!
        self.init(entity: entity, insertInto: context)
        self.createdAt = Date()
        self.modificationDate = Date()
        self.timestamp = Date()
    }
}

extension Reminder {
    convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Reminder", in: context)!
        self.init(entity: entity, insertInto: context)
        self.createdAt = Date()
        self.modificationDate = Date()
        self.isCompleted = false
        self.priority = 0
    }
}

extension Message {
    convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Message", in: context)!
        self.init(entity: entity, insertInto: context)
        self.createdAt = Date()
        self.modificationDate = Date()
        self.timestamp = Date()
        self.status = MessageStatus.sending.rawValue
    }
}

extension WeatherData {
    convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "WeatherData", in: context)!
        self.init(entity: entity, insertInto: context)
        self.createdAt = Date()
        self.modificationDate = Date()
        self.timestamp = Date()
    }
}

extension VoiceCommand {
    convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "VoiceCommand", in: context)!
        self.init(entity: entity, insertInto: context)
        self.createdAt = Date()
        self.modificationDate = Date()
        self.timestamp = Date()
    }
}
