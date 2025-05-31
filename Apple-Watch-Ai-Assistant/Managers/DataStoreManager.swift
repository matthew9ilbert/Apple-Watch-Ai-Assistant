import Foundation
import WatchConnectivity
import CoreData
import CloudKit

class DataStoreManager: NSObject, ObservableObject {
    static let shared = DataStoreManager()
    
    // MARK: - Properties
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private let session: WCSession = .default
    private let container: NSPersistentCloudKitContainer
    private let backgroundContext: NSManagedObjectContext
    private let analyticsManager = AnalyticsManager.shared
    
    // MARK: - Initialization
    
    override init() {
        // Initialize Core Data container
        container = NSPersistentCloudKitContainer(name: "WatchAssistant")
        
        // Configure persistent stores
        let storeDescription = container.persistentStoreDescriptions.first!
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        // Load persistent stores
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Failed to load Core Data stack: \(error)")
                self.analyticsManager.logError(error,
                                            code: "CORE_DATA_INIT",
                                            severity: .critical)
            }
        }
        
        // Configure automatic merging
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Create background context
        backgroundContext = container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        super.init()
        
        // Configure WatchConnectivity
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
        
        // Observe remote changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(processPersistentHistoryChanges),
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )
    }
    
    // MARK: - Core Data Operations
    
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    func save() {
        if viewContext.hasChanges {
            do {
                try viewContext.save()
            } catch {
                analyticsManager.logError(error,
                                        code: "CORE_DATA_SAVE",
                                        severity: .error)
            }
        }
    }
    
    func performBackgroundTask(_ task: @escaping (NSManagedObjectContext) -> Void) {
        backgroundContext.perform {
            task(self.backgroundContext)
            if self.backgroundContext.hasChanges {
                do {
                    try self.backgroundContext.save()
                } catch {
                    self.analyticsManager.logError(error,
                                                 code: "BACKGROUND_SAVE",
                                                 severity: .error)
                }
            }
        }
    }
    
    // MARK: - Sync Operations
    
    func syncData() {
        guard !isSyncing else { return }
        isSyncing = true
        
        backgroundContext.perform {
            do {
                // Fetch changes since last sync
                let changes = try self.fetchChanges()
                
                // Send changes to companion device
                if !changes.isEmpty {
                    try self.sendChangesToCompanion(changes)
                }
                
                // Update sync timestamp
                DispatchQueue.main.async {
                    self.lastSyncDate = Date()
                    self.isSyncing = false
                }
                
                self.analyticsManager.logEvent(
                    "data_sync_completed",
                    category: .settings,
                    parameters: ["changes_count": "\(changes.count)"]
                )
            } catch {
                DispatchQueue.main.async {
                    self.syncError = error
                    self.isSyncing = false
                }
                
                self.analyticsManager.logError(error,
                                             code: "SYNC_FAILED",
                                             severity: .error)
            }
        }
    }
    
    private func fetchChanges() throws -> [DataChange] {
        var changes: [DataChange] = []
        
        // Fetch and process changes for each entity type
        try changes.append(contentsOf: fetchEntityChanges(for: "UserPreference"))
        try changes.append(contentsOf: fetchEntityChanges(for: "HealthMetric"))
        try changes.append(contentsOf: fetchEntityChanges(for: "Reminder"))
        try changes.append(contentsOf: fetchEntityChanges(for: "Message"))
        
        return changes
    }
    
    private func fetchEntityChanges(for entityName: String) throws -> [DataChange] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "modificationDate > %@", lastSyncDate ?? Date.distantPast as NSDate)
        
        let objects = try backgroundContext.fetch(request)
        return objects.map { object in
            DataChange(
                entityName: entityName,
                objectID: object.objectID.uriRepresentation(),
                changeType: .update,
                data: object.dictionaryWithValues(forKeys: Array(object.entity.attributesByName.keys))
            )
        }
    }
    
    private func sendChangesToCompanion(_ changes: [DataChange]) throws {
        guard session.isReachable else {
            throw DataSyncError.companionUnreachable
        }
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(changes)
        
        session.sendMessageData(data, replyHandler: nil) { error in
            self.analyticsManager.logError(error,
                                         code: "SEND_CHANGES",
                                         severity: .error)
        }
    }
    
    // MARK: - Data Processing
    
    @objc private func processPersistentHistoryChanges() {
        backgroundContext.perform {
            do {
                let historyRequest = NSPersistentHistoryChangeRequest.fetchHistory(
                    after: self.lastSyncDate ?? .distantPast
                )
                
                let historyResult = try self.backgroundContext.execute(historyRequest)
                    as? NSPersistentHistoryResult
                let changes = historyResult?.result as? [NSPersistentHistoryChange] ?? []
                
                // Process each change
                for change in changes {
                    self.processHistoryChange(change)
                }
                
                // Update last sync date
                DispatchQueue.main.async {
                    self.lastSyncDate = Date()
                }
            } catch {
                self.analyticsManager.logError(error,
                                             code: "HISTORY_PROCESSING",
                                             severity: .error)
            }
        }
    }
    
    private func processHistoryChange(_ change: NSPersistentHistoryChange) {
        guard let changeType = change.changeType else { return }
        
        switch changeType {
        case .insert:
            handleInsertChange(change)
        case .update:
            handleUpdateChange(change)
        case .delete:
            handleDeleteChange(change)
        @unknown default:
            break
        }
    }
    
    private func handleInsertChange(_ change: NSPersistentHistoryChange) {
        guard let entityName = change.changedObjectID.entity.name else { return }
        notifyObservers(entityName: entityName, changeType: .insert)
    }
    
    private func handleUpdateChange(_ change: NSPersistentHistoryChange) {
        guard let entityName = change.changedObjectID.entity.name else { return }
        notifyObservers(entityName: entityName, changeType: .update)
    }
    
    private func handleDeleteChange(_ change: NSPersistentHistoryChange) {
        guard let entityName = change.changedObjectID.entity.name else { return }
        notifyObservers(entityName: entityName, changeType: .delete)
    }
    
    // MARK: - Notification Handling
    
    private func notifyObservers(entityName: String, changeType: ChangeType) {
        NotificationCenter.default.post(
            name: .dataStoreDidChange,
            object: nil,
            userInfo: [
                "entityName": entityName,
                "changeType": changeType
            ]
        )
    }
    
    // MARK: - Types
    
    struct DataChange: Codable {
        let entityName: String
        let objectID: URL
        let changeType: ChangeType
        let data: [String: Any]
        
        enum CodingKeys: String, CodingKey {
            case entityName
            case objectID
            case changeType
            case data
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(entityName, forKey: .entityName)
            try container.encode(objectID, forKey: .objectID)
            try container.encode(changeType, forKey: .changeType)
            try container.encode(data.jsonString, forKey: .data)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            entityName = try container.decode(String.self, forKey: .entityName)
            objectID = try container.decode(URL.self, forKey: .objectID)
            changeType = try container.decode(ChangeType.self, forKey: .changeType)
            let jsonString = try container.decode(String.self, forKey: .data)
            data = jsonString.jsonDictionary ?? [:]
        }
        
        init(entityName: String, objectID: URL, changeType: ChangeType, data: [String: Any]) {
            self.entityName = entityName
            self.objectID = objectID
            self.changeType = changeType
            self.data = data
        }
    }
    
    enum ChangeType: String, Codable {
        case insert
        case update
        case delete
    }
    
    enum DataSyncError: Error {
        case companionUnreachable
        case encodingFailed
        case decodingFailed
        case persistenceFailed
        
        var localizedDescription: String {
            switch self {
            case .companionUnreachable:
                return "Companion device is not reachable"
            case .encodingFailed:
                return "Failed to encode data for sync"
            case .decodingFailed:
                return "Failed to decode received data"
            case .persistenceFailed:
                return "Failed to persist synced data"
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension DataStoreManager: WCSessionDelegate {
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
        processReceivedData(messageData)
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
    
    private func processReceivedData(_ data: Data) {
        backgroundContext.perform {
            do {
                let decoder = JSONDecoder()
                let changes = try decoder.decode([DataChange].self, from: data)
                
                for change in changes {
                    try self.applyChange(change)
                }
                
                try self.backgroundContext.save()
                
                DispatchQueue.main.async {
                    self.lastSyncDate = Date()
                }
            } catch {
                self.analyticsManager.logError(error,
                                             code: "PROCESS_RECEIVED",
                                             severity: .error)
            }
        }
    }
    
    private func applyChange(_ change: DataChange) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: change.entityName,
                                                    in: backgroundContext) else {
            return
        }
        
        switch change.changeType {
        case .insert, .update:
            let object = backgroundContext.object(with: change.objectID)
            change.data.forEach { key, value in
                object.setValue(value, forKey: key)
            }
            
        case .delete:
            let object = backgroundContext.object(with: change.objectID)
            backgroundContext.delete(object)
        }
    }
}

// MARK: - Extensions

extension Notification.Name {
    static let dataStoreDidChange = Notification.Name("dataStoreDidChange")
}

extension Dictionary where Key == String {
    var jsonString: String {
        guard let data = try? JSONSerialization.data(withJSONObject: self),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

extension String {
    var jsonDictionary: [String: Any]? {
        guard let data = self.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }
}
