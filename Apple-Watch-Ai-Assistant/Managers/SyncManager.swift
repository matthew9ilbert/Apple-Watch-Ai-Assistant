import Foundation
import WatchConnectivity
import CoreData
import Combine

class SyncManager: NSObject, ObservableObject {
    static let shared = SyncManager()
    
    // MARK: - Published Properties
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    @Published var syncProgress: Double = 0
    
    // MARK: - Private Properties
    
    private let session: WCSession = .default
    private let dataStore = DataStoreManager.shared
    private let analyticsManager = AnalyticsManager.shared
    private var syncQueue = DispatchQueue(label: "com.watchassistant.sync")
    private var syncTask: Task<Void, Error>?
    private var observers: Set<AnyCancellable> = []
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupWatchConnectivity()
        setupObservers()
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }
    
    private func setupObservers() {
        // Monitor data changes that need syncing
        NotificationCenter.default.publisher(for: .dataStoreDidChange)
            .sink { [weak self] notification in
                self?.handleDataChange(notification)
            }
            .store(in: &observers)
    }
    
    // MARK: - Sync Control
    
    func startSync() {
        guard !isSyncing else { return }
        
        syncTask = Task {
            do {
                await setIsSyncing(true)
                try await performSync()
                await setIsSyncing(false)
                await updateLastSyncDate()
            } catch {
                await handleSyncError(error)
            }
        }
    }
    
    func cancelSync() {
        syncTask?.cancel()
        syncTask = nil
        isSyncing = false
        syncProgress = 0
    }
    
    // MARK: - Sync Implementation
    
    private func performSync() async throws {
        // 1. Prepare data for sync
        let changes = try await prepareChangesForSync()
        guard !changes.isEmpty else { return }
        
        // 2. Send changes to companion device
        try await sendChanges(changes)
        
        // 3. Receive and apply changes from companion
        try await receiveChanges()
        
        // 4. Update sync status
        analyticsManager.logEvent("sync_completed",
                                category: .settings,
                                parameters: ["changes_count": "\(changes.count)"])
    }
    
    private func prepareChangesForSync() async throws -> [SyncChange] {
        var changes: [SyncChange] = []
        
        // Fetch changes since last sync for each entity type
        try await withThrowingTaskGroup(of: [SyncChange].self) { group in
            for entityName in EntityType.allCases {
                group.addTask {
                    try await self.fetchChanges(for: entityName)
                }
            }
            
            for try await entityChanges in group {
                changes.append(contentsOf: entityChanges)
            }
        }
        
        return changes
    }
    
    private func fetchChanges(for entityType: EntityType) async throws -> [SyncChange] {
        let context = dataStore.backgroundContext
        let request = NSFetchRequest<NSManagedObject>(entityName: entityType.rawValue)
        
        if let lastSync = lastSyncDate {
            request.predicate = NSPredicate(
                format: "modificationDate > %@",
                lastSync as NSDate
            )
        }
        
        let results = try context.fetch(request)
        return results.map { object in
            SyncChange(
                entityType: entityType,
                objectID: object.objectID.uriRepresentation(),
                action: .update,
                data: object.dictionaryWithValues(forKeys: Array(object.entity.attributesByName.keys))
            )
        }
    }
    
    private func sendChanges(_ changes: [SyncChange]) async throws {
        guard session.isReachable else {
            throw SyncError.deviceUnreachable
        }
        
        let chunks = changes.chunked(into: 100)
        let totalChunks = chunks.count
        
        for (index, chunk) in chunks.enumerated() {
            try Task.checkCancellation()
            
            let data = try JSONEncoder().encode(chunk)
            try await session.sendMessageData(data, replyHandler: nil)
            
            await updateProgress(Double(index + 1) / Double(totalChunks))
        }
    }
    
    private func receiveChanges() async throws {
        // Implementation depends on WatchConnectivity response handling
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func setIsSyncing(_ syncing: Bool) {
        isSyncing = syncing
        if !syncing {
            syncProgress = 0
        }
    }
    
    @MainActor
    private func updateProgress(_ progress: Double) {
        syncProgress = progress
    }
    
    @MainActor
    private func updateLastSyncDate() {
        lastSyncDate = Date()
    }
    
    @MainActor
    private func handleSyncError(_ error: Error) {
        syncError = error
        isSyncing = false
        syncProgress = 0
        
        analyticsManager.logError(error,
                                code: "SYNC_ERROR",
                                severity: .error)
    }
    
    private func handleDataChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let entityName = userInfo["entityName"] as? String,
              let changeType = userInfo["changeType"] as? DataStoreManager.ChangeType else {
            return
        }
        
        // Schedule sync for changed data
        scheduleSync(for: entityName, changeType: changeType)
    }
    
    private func scheduleSync(for entityName: String, changeType: DataStoreManager.ChangeType) {
        // Debounce sync requests
        syncQueue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startSync()
        }
    }
    
    // MARK: - Types
    
    enum EntityType: String, CaseIterable {
        case userPreference = "UserPreference"
        case healthMetric = "HealthMetric"
        case workoutSession = "WorkoutSession"
        case reminder = "Reminder"
        case message = "Message"
        case weatherData = "WeatherData"
        case voiceCommand = "VoiceCommand"
    }
    
    struct SyncChange: Codable {
        let entityType: EntityType
        let objectID: URL
        let action: SyncAction
        let data: [String: Any]
        
        enum SyncAction: String, Codable {
            case insert
            case update
            case delete
        }
        
        enum CodingKeys: String, CodingKey {
            case entityType
            case objectID
            case action
            case data
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(entityType, forKey: .entityType)
            try container.encode(objectID, forKey: .objectID)
            try container.encode(action, forKey: .action)
            try container.encode(data.jsonString, forKey: .data)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            entityType = try container.decode(EntityType.self, forKey: .entityType)
            objectID = try container.decode(URL.self, forKey: .objectID)
            action = try container.decode(SyncAction.self, forKey: .action)
            let jsonString = try container.decode(String.self, forKey: .data)
            data = jsonString.jsonDictionary ?? [:]
        }
        
        init(entityType: EntityType, objectID: URL, action: SyncAction, data: [String: Any]) {
            self.entityType = entityType
            self.objectID = objectID
            self.action = action
            self.data = data
        }
    }
    
    enum SyncError: LocalizedError {
        case deviceUnreachable
        case syncInProgress
        case encodingError
        case decodingError
        case transferError
        
        var errorDescription: String? {
            switch self {
            case .deviceUnreachable:
                return "Companion device is not reachable"
            case .syncInProgress:
                return "Sync already in progress"
            case .encodingError:
                return "Failed to encode sync data"
            case .decodingError:
                return "Failed to decode received data"
            case .transferError:
                return "Error transferring data"
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension SyncManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error = error {
            analyticsManager.logError(error,
                                    code: "WATCH_SESSION",
                                    severity: .error)
        }
    }
    
    func session(_ session: WCSession,
                 didReceiveMessageData messageData: Data) {
        syncQueue.async {
            self.processReceivedData(messageData)
        }
    }
    
    private func processReceivedData(_ data: Data) {
        do {
            let changes = try JSONDecoder().decode([SyncChange].self, from: data)
            Task {
                try await applyReceivedChanges(changes)
            }
        } catch {
            analyticsManager.logError(error,
                                    code: "PROCESS_SYNC",
                                    severity: .error)
        }
    }
    
    private func applyReceivedChanges(_ changes: [SyncChange]) async throws {
        let context = dataStore.backgroundContext
        
        try await context.perform {
            for change in changes {
                let object = try self.dataStore.managedObject(for: change.objectID, in: context)
                
                switch change.action {
                case .insert, .update:
                    change.data.forEach { key, value in
                        object.setValue(value, forKey: key)
                    }
                case .delete:
                    context.delete(object)
                }
            }
            
            try context.save()
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}

// MARK: - Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
