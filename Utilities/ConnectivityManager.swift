import Foundation
import WatchConnectivity
import CoreData
import Combine

class ConnectivityManager: NSObject, ObservableObject {
    static let shared = ConnectivityManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var isReachable = false
    @Published private(set) var isPaired = false
    @Published private(set) var isCompanionAppInstalled = false
    @Published private(set) var isActivated = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncStatus = SyncStatus.idle
    
    // MARK: - Properties
    
    private let session: WCSession
    private let dataStore = DataStoreManager.shared
    private let cacheManager = CacheManager.shared
    private let analyticsManager = AnalyticsManager.shared
    private var syncQueue = DispatchQueue(label: "com.watchassistant.sync")
    private var cancellables = Set<AnyCancellable>()
    
    // Sync configuration
    private let maxRetryAttempts = 3
    private let syncTimeout: TimeInterval = 30
    private var currentRetryAttempt = 0
    
    // MARK: - Types
    
    enum SyncStatus {
        case idle
        case syncing
        case error(Error)
        
        var description: String {
            switch self {
            case .idle:
                return "Idle"
            case .syncing:
                return "Syncing..."
            case .error(let error):
                return "Error: \(error.localizedDescription)"
            }
        }
    }
    
    struct SyncPayload: Codable {
        let type: PayloadType
        let data: Data
        let timestamp: Date
        let version: Int
        
        enum PayloadType: String, Codable {
            case healthData
            case workoutData
            case reminderData
            case homeData
            case preferences
            case fullSync
        }
    }
    
    // MARK: - Initialization
    
    private override init() {
        self.session = WCSession.default
        super.init()
        
        session.delegate = self
        session.activate()
        
        setupObservers()
    }
    
    private func setupObservers() {
        // Listen for data changes that need syncing
        NotificationCenter.default.publisher(for: .dataStoreDidChange)
            .sink { [weak self] notification in
                self?.handleDataChange(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Sync Operations
    
    func syncData() async throws {
        guard isReachable && isActivated else {
            throw ConnectivityError.deviceNotReachable
        }
        
        guard syncStatus != .syncing else {
            throw ConnectivityError.syncInProgress
        }
        
        await updateSyncStatus(.syncing)
        
        do {
            // Prepare sync data
            let payload = try await prepareSyncPayload()
            
            // Send sync request
            try await sendSyncPayload(payload)
            
            // Update sync status
            lastSyncDate = Date()
            await updateSyncStatus(.idle)
            
            // Log success
            analyticsManager.logEvent(
                "sync_completed",
                category: .settings,
                parameters: [
                    "payload_size": "\(payload.data.count)",
                    "payload_type": payload.type.rawValue
                ]
            )
        } catch {
            await handleSyncError(error)
        }
    }
    
    private func prepareSyncPayload() async throws -> SyncPayload {
        // Get changes since last sync
        let changes = try await dataStore.getChangesSinceLastSync()
        
        // Encode changes
        let data = try JSONEncoder().encode(changes)
        
        return SyncPayload(
            type: .fullSync,
            data: data,
            timestamp: Date(),
            version: 1
        )
    }
    
    private func sendSyncPayload(_ payload: SyncPayload) async throws {
        try await withCheckedThrowingContinuation { continuation in
            session.sendMessageData(try! JSONEncoder().encode(payload), replyHandler: { response in
                continuation.resume()
            }, errorHandler: { error in
                continuation.resume(throwing: error)
            })
        }
    }
    
    // MARK: - Data Transfer
    
    func transferFile(_ url: URL, metadata: [String: Any]? = nil) {
        session.transferFile(url, metadata: metadata)
    }
    
    func transferUserInfo(_ userInfo: [String: Any]) {
        session.transferUserInfo(userInfo)
    }
    
    func sendMessage(_ message: [String: Any],
                    replyHandler: ((NSDictionary) -> Void)? = nil,
                    errorHandler: ((Error) -> Void)? = nil) {
        guard isReachable else {
            errorHandler?(ConnectivityError.deviceNotReachable)
            return
        }
        
        session.sendMessage(message, replyHandler: { response in
            replyHandler?(response as NSDictionary)
        }, errorHandler: errorHandler)
    }
    
    // MARK: - Error Handling
    
    private func handleSyncError(_ error: Error) async {
        // Update status
        await updateSyncStatus(.error(error))
        
        // Log error
        analyticsManager.logError(error,
                                code: "SYNC_ERROR",
                                severity: .error)
        
        // Retry if possible
        if currentRetryAttempt < maxRetryAttempts {
            currentRetryAttempt += 1
            try? await syncData()
        } else {
            currentRetryAttempt = 0
        }
    }
    
    @MainActor
    private func updateSyncStatus(_ status: SyncStatus) {
        syncStatus = status
    }
    
    // MARK: - Data Change Handling
    
    private func handleDataChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let entityName = userInfo["entityName"] as? String else {
            return
        }
        
        // Schedule sync for changed data
        Task {
            try? await syncData()
        }
    }
}

// MARK: - WCSessionDelegate

extension ConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isActivated = activationState == .activated
            if let error = error {
                self.analyticsManager.logError(error,
                                             code: "ACTIVATION_ERROR",
                                             severity: .error)
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
    
    func session(_ session: WCSession,
                 didReceiveMessageData messageData: Data,
                 replyHandler: @escaping (Data) -> Void) {
        do {
            let payload = try JSONDecoder().decode(SyncPayload.self, from: messageData)
            handleReceivedPayload(payload)
            replyHandler(Data()) // Send empty acknowledgment
        } catch {
            analyticsManager.logError(error,
                                    code: "RECEIVE_ERROR",
                                    severity: .error)
        }
    }
    
    func session(_ session: WCSession,
                 didReceive file: WCSessionFile) {
        // Handle received file
        handleReceivedFile(file)
    }
    
    func session(_ session: WCSession,
                 didFinish fileTransfer: WCSessionFileTransfer,
                 error: Error?) {
        if let error = error {
            analyticsManager.logError(error,
                                    code: "FILE_TRANSFER_ERROR",
                                    severity: .error)
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        // Handle session becoming inactive
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // Activate the new session after the previous one is deactivated
        WCSession.default.activate()
    }
    #endif
    
    // MARK: - Payload Handling
    
    private func handleReceivedPayload(_ payload: SyncPayload) {
        switch payload.type {
        case .healthData:
            handleHealthData(payload.data)
        case .workoutData:
            handleWorkoutData(payload.data)
        case .reminderData:
            handleReminderData(payload.data)
        case .homeData:
            handleHomeData(payload.data)
        case .preferences:
            handlePreferences(payload.data)
        case .fullSync:
            handleFullSync(payload.data)
        }
    }
    
    private func handleHealthData(_ data: Data) {
        // Process health data
    }
    
    private func handleWorkoutData(_ data: Data) {
        // Process workout data
    }
    
    private func handleReminderData(_ data: Data) {
        // Process reminder data
    }
    
    private func handleHomeData(_ data: Data) {
        // Process home automation data
    }
    
    private func handlePreferences(_ data: Data) {
        // Process preferences data
    }
    
    private func handleFullSync(_ data: Data) {
        // Process full sync data
    }
    
    private func handleReceivedFile(_ file: WCSessionFile) {
        // Process received file
    }
}

// MARK: - Errors

enum ConnectivityError: LocalizedError {
    case deviceNotReachable
    case syncInProgress
    case syncFailed
    case invalidPayload
    case transferFailed
    
    var errorDescription: String? {
        switch self {
        case .deviceNotReachable:
            return "Companion device is not reachable"
        case .syncInProgress:
            return "Sync already in progress"
        case .syncFailed:
            return "Sync operation failed"
        case .invalidPayload:
            return "Invalid sync payload"
        case .transferFailed:
            return "File transfer failed"
        }
    }
}
