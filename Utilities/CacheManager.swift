import Foundation
import CoreData
import UIKit

class CacheManager {
    static let shared = CacheManager()
    
    // MARK: - Cache Configuration
    
    private let memoryCache = NSCache<NSString, AnyObject>()
    private let fileManager = FileManager.default
    private let diskCacheURL: URL
    
    // Cache limits
    private let maxMemoryCacheSize = 50 * 1024 * 1024  // 50 MB
    private let maxDiskCacheSize = 200 * 1024 * 1024   // 200 MB
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60  // 7 days
    
    // Cache types
    enum CacheType {
        case memory
        case disk
        case both
    }
    
    // MARK: - Initialization
    
    private init() {
        // Configure memory cache
        memoryCache.totalCostLimit = maxMemoryCacheSize
        memoryCache.countLimit = 1000
        
        // Set up disk cache directory
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cacheDirectory.appendingPathComponent("WatchAssistantCache")
        
        // Create cache directory if needed
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Set up cache cleanup
        setupCacheCleanup()
        
        // Subscribe to memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    // MARK: - Cache Operations
    
    func cache<T: Codable>(_ object: T,
                          forKey key: String,
                          type: CacheType = .both,
                          expiry: TimeInterval? = nil) throws {
        let data = try JSONEncoder().encode(object)
        
        // Cache in memory if specified
        if type == .memory || type == .both {
            memoryCache.setObject(data as NSData, forKey: key as NSString)
        }
        
        // Cache to disk if specified
        if type == .disk || type == .both {
            let fileURL = diskCacheURL.appendingPathComponent(key)
            try data.write(to: fileURL)
            
            // Set expiry if provided
            if let expiry = expiry {
                let expiryDate = Date().addingTimeInterval(expiry)
                let attributes: [FileAttributeKey: Any] = [
                    .modificationDate: expiryDate
                ]
                try fileManager.setAttributes(attributes, ofItemAtPath: fileURL.path)
            }
        }
    }
    
    func retrieve<T: Codable>(_ type: T.Type,
                             forKey key: String,
                             from cacheType: CacheType = .both) throws -> T? {
        // Try memory cache first if specified
        if cacheType == .memory || cacheType == .both {
            if let data = memoryCache.object(forKey: key as NSString) as? Data {
                return try JSONDecoder().decode(type, from: data)
            }
        }
        
        // Try disk cache if specified
        if cacheType == .disk || cacheType == .both {
            let fileURL = diskCacheURL.appendingPathComponent(key)
            if fileManager.fileExists(atPath: fileURL.path) {
                // Check if file has expired
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let modificationDate = attributes[.modificationDate] as? Date {
                    if Date().timeIntervalSince(modificationDate) > maxCacheAge {
                        try? fileManager.removeItem(at: fileURL)
                        return nil
                    }
                }
                
                let data = try Data(contentsOf: fileURL)
                let object = try JSONDecoder().decode(type, from: data)
                
                // Cache in memory for faster subsequent access
                if cacheType == .both {
                    memoryCache.setObject(data as NSData, forKey: key as NSString)
                }
                
                return object
            }
        }
        
        return nil
    }
    
    func removeCache(forKey key: String, from cacheType: CacheType = .both) {
        // Remove from memory cache if specified
        if cacheType == .memory || cacheType == .both {
            memoryCache.removeObject(forKey: key as NSString)
        }
        
        // Remove from disk cache if specified
        if cacheType == .disk || cacheType == .both {
            let fileURL = diskCacheURL.appendingPathComponent(key)
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    func clearCache(type: CacheType = .both) {
        // Clear memory cache if specified
        if type == .memory || type == .both {
            memoryCache.removeAllObjects()
        }
        
        // Clear disk cache if specified
        if type == .disk || type == .both {
            try? fileManager.removeItem(at: diskCacheURL)
            try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Cache Management
    
    private func setupCacheCleanup() {
        // Schedule periodic cache cleanup
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.performCacheCleanup()
        }
    }
    
    private func performCacheCleanup() {
        let cutoffDate = Date().addingTimeInterval(-maxCacheAge)
        
        // Clean up disk cache
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.modificationDateKey, .fileSizeKey]
        ) else { return }
        
        var totalSize: UInt64 = 0
        
        // Sort files by date, oldest first
        let sortedFiles = fileURLs.compactMap { url -> (URL, Date, UInt64)? in
            guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                  let modificationDate = attributes[.modificationDate] as? Date,
                  let fileSize = attributes[.size] as? UInt64 else {
                return nil
            }
            return (url, modificationDate, fileSize)
        }.sorted { $0.1 < $1.1 }
        
        // Remove expired and excess files
        for (url, modificationDate, fileSize) in sortedFiles {
            let shouldRemove = modificationDate < cutoffDate || totalSize + fileSize > maxDiskCacheSize
            
            if shouldRemove {
                try? fileManager.removeItem(at: url)
            } else {
                totalSize += fileSize
            }
        }
    }
    
    @objc private func handleMemoryWarning() {
        memoryCache.removeAllObjects()
    }
    
    // MARK: - Helper Methods
    
    func cacheExists(forKey key: String, in type: CacheType = .both) -> Bool {
        if type == .memory || type == .both {
            if memoryCache.object(forKey: key as NSString) != nil {
                return true
            }
        }
        
        if type == .disk || type == .both {
            let fileURL = diskCacheURL.appendingPathComponent(key)
            return fileManager.fileExists(atPath: fileURL.path)
        }
        
        return false
    }
    
    func getCacheSize() -> UInt64 {
        var totalSize: UInt64 = 0
        
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        
        for fileURL in fileURLs {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let fileSize = attributes[.size] as? UInt64 else {
                continue
            }
            totalSize += fileSize
        }
        
        return totalSize
    }
    
    func getCacheInfo() -> CacheInfo {
        let diskSize = getCacheSize()
        let fileCount = (try? fileManager.contentsOfDirectory(atPath: diskCacheURL.path).count) ?? 0
        
        return CacheInfo(
            memoryUsage: UInt64(memoryCache.totalCost),
            diskUsage: diskSize,
            itemCount: memoryCache.countLimit,
            fileCount: fileCount
        )
    }
}

// MARK: - Supporting Types

struct CacheInfo {
    let memoryUsage: UInt64
    let diskUsage: UInt64
    let itemCount: Int
    let fileCount: Int
    
    var formattedMemoryUsage: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .file)
    }
    
    var formattedDiskUsage: String {
        ByteCountFormatter.string(fromByteCount: Int64(diskUsage), countStyle: .file)
    }
}

// MARK: - Cache Keys

extension CacheManager {
    enum CacheKey {
        static let userPreferences = "userPreferences"
        static let healthData = "healthData"
        static let weatherData = "weatherData"
        static let locationHistory = "locationHistory"
        static let workoutHistory = "workoutHistory"
        static let reminderList = "reminderList"
        static let homeState = "homeState"
        
        static func weatherForLocation(_ latitude: Double, _ longitude: Double) -> String {
            return "weather_\(latitude)_\(longitude)"
        }
        
        static func workoutData(_ id: String) -> String {
            return "workout_\(id)"
        }
        
        static func reminderData(_ id: String) -> String {
            return "reminder_\(id)"
        }
    }
}
