import Foundation
import EventKit
import NaturalLanguage
import CoreLocation

class ReminderManager: ObservableObject {
    private let eventStore = EKEventStore()
    private let locationManager = CLLocationManager()
    private let notificationManager = NotificationManager.shared
    
    @Published var reminders: [EKReminder] = []
    @Published var isAuthorized = false
    @Published var errorMessage: String?
    
    init() {
        requestAuthorization()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        eventStore.requestAccess(to: .reminder) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                }
                if granted {
                    self?.loadReminders()
                }
            }
        }
    }
    
    // MARK: - Natural Language Processing
    
    struct ParsedReminder {
        var title: String
        var dueDate: Date?
        var location: String?
        var priority: Int?
        var notes: String?
        var isRecurring: Bool
        var recurrenceRule: EKRecurrenceRule?
    }
    
    func parseReminderText(_ text: String) -> ParsedReminder {
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass, .tokenType])
        tagger.string = text
        
        var parsedReminder = ParsedReminder(title: "", isRecurring: false)
        var dateComponents: DateComponents = DateComponents()
        var hasTime = false
        
        // Extract time and date information
        let temporalTagger = NLTagger(tagSchemes: [.temporalExpression])
        temporalTagger.string = text
        
        temporalTagger.enumerateTags(in: text.startIndex..<text.endIndex,
                                   unit: .word,
                                   scheme: .temporalExpression,
                                   options: [.omitWhitespace]) { tag, tokenRange in
            if let tag = tag {
                let dateText = String(text[tokenRange])
                if let date = parseDateExpression(dateText) {
                    parsedReminder.dueDate = date
                    hasTime = dateText.lowercased().contains("at") || dateText.contains(":")
                }
            }
            return true
        }
        
        // Extract location
        if let locationRange = text.range(of: "at|in|near", options: .regularExpression) {
            let locationStart = text.index(after: locationRange.upperBound)
            if let nextPunctuation = text[locationStart...].firstIndex(where: { ",.!?".contains($0) }) {
                parsedReminder.location = String(text[locationStart..<nextPunctuation]).trimmingCharacters(in: .whitespaces)
            } else {
                parsedReminder.location = String(text[locationStart...]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Extract priority
        if text.lowercased().contains("high priority") || text.contains("!") {
            parsedReminder.priority = 1
        } else if text.lowercased().contains("medium priority") {
            parsedReminder.priority = 5
        } else if text.lowercased().contains("low priority") {
            parsedReminder.priority = 9
        }
        
        // Check for recurring patterns
        let recurringPatterns = [
            "every day": (component: Calendar.Component.day, interval: 1),
            "daily": (component: Calendar.Component.day, interval: 1),
            "every week": (component: Calendar.Component.weekOfYear, interval: 1),
            "weekly": (component: Calendar.Component.weekOfYear, interval: 1),
            "every month": (component: Calendar.Component.month, interval: 1),
            "monthly": (component: Calendar.Component.month, interval: 1),
            "every year": (component: Calendar.Component.year, interval: 1),
            "yearly": (component: Calendar.Component.year, interval: 1)
        ]
        
        for (pattern, rule) in recurringPatterns {
            if text.lowercased().contains(pattern) {
                parsedReminder.isRecurring = true
                parsedReminder.recurrenceRule = EKRecurrenceRule(
                    recurrenceWith: rule.component,
                    interval: rule.interval,
                    end: nil
                )
                break
            }
        }
        
        // Extract main title/task
        var title = text
        if let dateRange = text.range(of: "\\b(tomorrow|today|next|every|daily|weekly|monthly|yearly).*",
                                    options: .regularExpression) {
            title = String(text[..<dateRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        if let locationRange = text.range(of: "\\b(at|in|near)\\b.*", options: .regularExpression) {
            title = String(text[..<locationRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        parsedReminder.title = title
        
        return parsedReminder
    }
    
    private func parseDateExpression(_ expression: String) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let lowercased = expression.lowercased()
        
        // Handle relative dates
        if lowercased.contains("today") {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            if let timeRange = lowercased.range(of: "at\\s+\\d{1,2}(?::\\d{2})?\\s*(?:am|pm)?",
                                              options: .regularExpression) {
                let timeStr = String(lowercased[timeRange])
                if let time = parseTimeString(timeStr) {
                    components.hour = time.hour
                    components.minute = time.minute
                }
            }
            return calendar.date(from: components)
        }
        
        if lowercased.contains("tomorrow") {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.day! += 1
            if let timeRange = lowercased.range(of: "at\\s+\\d{1,2}(?::\\d{2})?\\s*(?:am|pm)?",
                                              options: .regularExpression) {
                let timeStr = String(lowercased[timeRange])
                if let time = parseTimeString(timeStr) {
                    components.hour = time.hour
                    components.minute = time.minute
                }
            }
            return calendar.date(from: components)
        }
        
        // Handle "next" expressions
        if lowercased.contains("next") {
            if lowercased.contains("week") {
                return calendar.date(byAdding: .weekOfYear, value: 1, to: now)
            }
            if lowercased.contains("month") {
                return calendar.date(byAdding: .month, value: 1, to: now)
            }
            if lowercased.contains("year") {
                return calendar.date(byAdding: .year, value: 1, to: now)
            }
        }
        
        // Try to parse explicit date/time
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return dateFormatter.date(from: expression)
    }
    
    private func parseTimeString(_ timeString: String) -> (hour: Int, minute: Int)? {
        let pattern = "at\\s+(\\d{1,2})(?::(\\d{2}))?(\\s*[ap]m)?"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        
        if let match = regex?.firstMatch(in: timeString,
                                       options: [],
                                       range: NSRange(timeString.startIndex..., in: timeString)) {
            let nsString = timeString as NSString
            var hour = Int(nsString.substring(with: match.range(at: 1))) ?? 0
            let minute = match.range(at: 2).location != NSNotFound ?
                Int(nsString.substring(with: match.range(at: 2))) ?? 0 : 0
            
            if match.range(at: 3).location != NSNotFound {
                let ampm = nsString.substring(with: match.range(at: 3)).lowercased()
                if ampm.contains("pm") && hour < 12 {
                    hour += 12
                } else if ampm.contains("am") && hour == 12 {
                    hour = 0
                }
            }
            
            return (hour: hour, minute: minute)
        }
        
        return nil
    }
    
    // MARK: - Reminder Management
    
    func createReminder(from text: String) async throws -> EKReminder {
        guard isAuthorized else {
            throw ReminderError.notAuthorized
        }
        
        let parsed = parseReminderText(text)
        let reminder = EKReminder(eventStore: eventStore)
        
        reminder.title = parsed.title
        reminder.notes = parsed.notes
        reminder.priority = parsed.priority ?? 0
        
        if let dueDate = parsed.dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
        }
        
        if parsed.isRecurring, let rule = parsed.recurrenceRule {
            reminder.addRecurrenceRule(rule)
        }
        
        if let locationName = parsed.location {
            // Try to geocode the location
            let geocoder = CLGeocoder()
            if let location = try? await geocoder.geocodeAddressString(locationName).first {
                let reminderLocation = EKStructuredLocation(title: locationName)
                reminderLocation.geoLocation = location.location
                reminderLocation.radius = 100 // meters
                reminder.structuredLocation = reminderLocation
            }
        }
        
        try eventStore.save(reminder, commit: true)
        
        // Schedule notification if there's a due date
        if let dueDate = parsed.dueDate {
            notificationManager.scheduleReminder(
                title: reminder.title,
                message: reminder.notes ?? "Reminder due",
                date: dueDate
            )
        }
        
        await loadReminders()
        return reminder
    }
    
    func deleteReminder(_ reminder: EKReminder) throws {
        try eventStore.remove(reminder, commit: true)
        Task {
            await loadReminders()
        }
    }
    
    func completeReminder(_ reminder: EKReminder) throws {
        reminder.isCompleted = true
        try eventStore.save(reminder, commit: true)
        Task {
            await loadReminders()
        }
    }
    
    @MainActor
    func loadReminders() async {
        guard isAuthorized else { return }
        
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )
        
        do {
            let reminders = try await eventStore.reminders(matching: predicate)
            self.reminders = reminders.sorted { reminder1, reminder2 in
                let date1 = reminder1.dueDateComponents?.date ?? .distantFuture
                let date2 = reminder2.dueDateComponents?.date ?? .distantFuture
                return date1 < date2
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Helper Methods
    
    func suggestCommonReminders() -> [String] {
        return [
            "Take medication",
            "Call mom",
            "Buy groceries",
            "Pay bills",
            "Exercise",
            "Drink water",
            "Schedule appointment",
            "Check email"
        ]
    }
    
    // MARK: - Error Handling
    
    enum ReminderError: Error {
        case notAuthorized
        case invalidDate
        case saveFailed
        case deleteFailed
        case loadFailed
        
        var localizedDescription: String {
            switch self {
            case .notAuthorized:
                return "Not authorized to access reminders"
            case .invalidDate:
                return "Invalid date format"
            case .saveFailed:
                return "Failed to save reminder"
            case .deleteFailed:
                return "Failed to delete reminder"
            case .loadFailed:
                return "Failed to load reminders"
            }
        }
    }
}

// MARK: - Extensions

extension DateComponents {
    var date: Date? {
        Calendar.current.date(from: self)
    }
}

extension EKReminder {
    var isOverdue: Bool {
        guard let dueDate = dueDateComponents?.date else { return false }
        return dueDate < Date()
    }
    
    var formattedDueDate: String {
        guard let date = dueDateComponents?.date else { return "No due date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
