import Foundation
import OSLog

class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private let logger = Logger(subsystem: "com.watchassistant", category: "main")
    private let queue = DispatchQueue(label: "com.watchassistant.analytics")
    
    // MARK: - Analytics Properties
    
    private var sessionStartTime: Date?
    private var analyticsEnabled: Bool
    private var sessionEvents: [AnalyticEvent] = []
    private var errorLogs: [ErrorLog] = []
    
    // MARK: - Types
    
    struct AnalyticEvent: Codable {
        let eventName: String
        let timestamp: Date
        let parameters: [String: String]
        let duration: TimeInterval?
        let category: EventCategory
        
        enum EventCategory: String, Codable {
            case voice = "Voice"
            case health = "Health"
            case workout = "Workout"
            case weather = "Weather"
            case reminders = "Reminders"
            case messages = "Messages"
            case navigation = "Navigation"
            case settings = "Settings"
        }
    }
    
    struct ErrorLog: Codable {
        let errorCode: String
        let message: String
        let timestamp: Date
        let severity: ErrorSeverity
        let stackTrace: String?
        let userInfo: [String: String]?
        
        enum ErrorSeverity: String, Codable {
            case critical
            case error
            case warning
            case info
        }
    }
    
    struct PerformanceMetrics: Codable {
        var cpuUsage: Double
        var memoryUsage: Double
        var batteryLevel: Double
        var networkLatency: TimeInterval
        var timestamp: Date
    }
    
    // MARK: - Initialization
    
    private init() {
        self.analyticsEnabled = UserDefaults.standard.bool(forKey: "analyticsEnabled")
        startSession()
    }
    
    // MARK: - Session Management
    
    private func startSession() {
        sessionStartTime = Date()
        logger.info("Analytics session started")
    }
    
    func endSession() {
        guard let startTime = sessionStartTime else { return }
        let sessionDuration = Date().timeIntervalSince(startTime)
        
        logEvent("session_end", parameters: [
            "duration": String(format: "%.0f", sessionDuration),
            "events_count": "\(sessionEvents.count)",
            "errors_count": "\(errorLogs.count)"
        ])
        
        uploadAnalytics()
    }
    
    // MARK: - Event Logging
    
    func logEvent(_ name: String,
                  category: AnalyticEvent.EventCategory,
                  parameters: [String: String] = [:],
                  duration: TimeInterval? = nil) {
        guard analyticsEnabled else { return }
        
        let event = AnalyticEvent(
            eventName: name,
            timestamp: Date(),
            parameters: parameters,
            duration: duration,
            category: category
        )
        
        queue.async {
            self.sessionEvents.append(event)
            self.logger.debug("Logged event: \(name)")
        }
    }
    
    func logError(_ error: Error,
                  code: String,
                  severity: ErrorLog.ErrorSeverity,
                  userInfo: [String: String]? = nil) {
        let errorLog = ErrorLog(
            errorCode: code,
            message: error.localizedDescription,
            timestamp: Date(),
            severity: severity,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n"),
            userInfo: userInfo
        )
        
        queue.async {
            self.errorLogs.append(errorLog)
            
            switch severity {
            case .critical:
                self.logger.critical("[\(code)] \(error.localizedDescription)")
            case .error:
                self.logger.error("[\(code)] \(error.localizedDescription)")
            case .warning:
                self.logger.warning("[\(code)] \(error.localizedDescription)")
            case .info:
                self.logger.info("[\(code)] \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Performance Monitoring
    
    private var performanceMetrics: [PerformanceMetrics] = []
    private var performanceMonitoringTimer: Timer?
    
    func startPerformanceMonitoring() {
        performanceMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.collectPerformanceMetrics()
        }
    }
    
    func stopPerformanceMonitoring() {
        performanceMonitoringTimer?.invalidate()
        performanceMonitoringTimer = nil
    }
    
    private func collectPerformanceMetrics() {
        // Collect system metrics (simplified for demo)
        let metrics = PerformanceMetrics(
            cpuUsage: ProcessInfo.processInfo.systemUptime,
            memoryUsage: Double(ProcessInfo.processInfo.physicalMemory),
            batteryLevel: UIDevice.current.batteryLevel,
            networkLatency: measureNetworkLatency(),
            timestamp: Date()
        )
        
        queue.async {
            self.performanceMetrics.append(metrics)
            self.logger.debug("Performance metrics collected")
        }
    }
    
    private func measureNetworkLatency() -> TimeInterval {
        // Simplified network latency measurement
        let start = Date()
        // Perform a quick network request
        return Date().timeIntervalSince(start)
    }
    
    // MARK: - Analytics Processing
    
    private func uploadAnalytics() {
        queue.async {
            // Prepare analytics data
            let analyticsData = self.prepareAnalyticsData()
            
            // In a real app, this would send data to a server
            self.logger.info("Analytics data prepared for upload: \(analyticsData.count) events")
            
            // Clear local storage after successful upload
            self.clearLocalStorage()
        }
    }
    
    private func prepareAnalyticsData() -> Data? {
        let analyticsPackage = AnalyticsPackage(
            events: sessionEvents,
            errors: errorLogs,
            performanceMetrics: performanceMetrics,
            sessionStart: sessionStartTime ?? Date(),
            sessionEnd: Date()
        )
        
        return try? JSONEncoder().encode(analyticsPackage)
    }
    
    private struct AnalyticsPackage: Codable {
        let events: [AnalyticEvent]
        let errors: [ErrorLog]
        let performanceMetrics: [PerformanceMetrics]
        let sessionStart: Date
        let sessionEnd: Date
    }
    
    private func clearLocalStorage() {
        sessionEvents.removeAll()
        errorLogs.removeAll()
        performanceMetrics.removeAll()
    }
    
    // MARK: - Usage Analytics
    
    func trackFeatureUsage(_ feature: AppFeature) {
        logEvent("feature_used",
                 category: feature.category,
                 parameters: ["feature": feature.rawValue])
    }
    
    enum AppFeature: String {
        case voiceCommand = "voice_command"
        case healthCheck = "health_check"
        case workoutStart = "workout_start"
        case weatherCheck = "weather_check"
        case reminderCreate = "reminder_create"
        case messageSend = "message_send"
        
        var category: AnalyticEvent.EventCategory {
            switch self {
            case .voiceCommand:
                return .voice
            case .healthCheck:
                return .health
            case .workoutStart:
                return .workout
            case .weatherCheck:
                return .weather
            case .reminderCreate:
                return .reminders
            case .messageSend:
                return .messages
            }
        }
    }
    
    // MARK: - Settings
    
    func setAnalyticsEnabled(_ enabled: Bool) {
        analyticsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "analyticsEnabled")
        
        if enabled {
            startSession()
        } else {
            endSession()
            clearLocalStorage()
        }
    }
    
    // MARK: - Debug Helpers
    
    func getDebugLog() -> String {
        var log = "=== Debug Log ===\n"
        log += "Session Start: \(sessionStartTime?.formatted() ?? "N/A")\n"
        log += "Events Count: \(sessionEvents.count)\n"
        log += "Errors Count: \(errorLogs.count)\n"
        log += "Performance Metrics Count: \(performanceMetrics.count)\n"
        log += "\nRecent Events:\n"
        sessionEvents.suffix(5).forEach { event in
            log += "- [\(event.timestamp.formatted())] \(event.eventName)\n"
        }
        log += "\nRecent Errors:\n"
        errorLogs.suffix(5).forEach { error in
            log += "- [\(error.timestamp.formatted())] [\(error.severity)] \(error.message)\n"
        }
        return log
    }
}

// MARK: - Error Handling Extension

extension AnalyticsManager {
    enum AppError: Error {
        case networkError(String)
        case dataError(String)
        case authorizationError(String)
        case userError(String)
        
        var errorCode: String {
            switch self {
            case .networkError:
                return "NET_ERR"
            case .dataError:
                return "DATA_ERR"
            case .authorizationError:
                return "AUTH_ERR"
            case .userError:
                return "USER_ERR"
            }
        }
    }
    
    func handleError(_ error: Error, context: String? = nil) {
        var severity: ErrorLog.ErrorSeverity
        var code: String
        var userInfo: [String: String] = [:]
        
        if let context = context {
            userInfo["context"] = context
        }
        
        if let appError = error as? AppError {
            code = appError.errorCode
            switch appError {
            case .networkError:
                severity = .error
            case .dataError:
                severity = .warning
            case .authorizationError:
                severity = .critical
            case .userError:
                severity = .info
            }
        } else {
            code = "UNKNOWN_ERR"
            severity = .error
        }
        
        logError(error, code: code, severity: severity, userInfo: userInfo)
    }
}
