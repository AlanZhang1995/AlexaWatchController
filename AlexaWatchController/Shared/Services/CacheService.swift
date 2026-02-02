//
//  CacheService.swift
//  AlexaWatchController
//
//  Implementation of CacheServiceProtocol using UserDefaults with App Group.
//  Validates: Requirements 5.1, 5.2, 5.3, 5.4
//

import Foundation

/// Implementation of CacheServiceProtocol using UserDefaults with App Group.
/// Provides persistent caching of smart plug device lists with expiration detection.
///
/// This service uses the shared App Group UserDefaults to enable data sharing
/// between the iOS Companion App and the watchOS App.
///
/// Requirements:
/// - 5.1: Cache device list locally after successful fetch
/// - 5.2: Display cached data when offline
/// - 5.3: Indicate when displaying cached data
/// - 5.4: Prompt refresh if cache older than 24 hours
public final class CacheService: CacheServiceProtocol {
    
    // MARK: - Singleton
    
    /// Shared singleton instance
    public static let shared = CacheService()
    
    // MARK: - Properties
    
    /// The UserDefaults instance for storing cached data
    private let userDefaults: UserDefaults
    
    /// The JSON encoder for serializing data
    private let encoder: JSONEncoder
    
    /// The JSON decoder for deserializing data
    private let decoder: JSONDecoder
    
    // MARK: - Keys
    
    /// Keys for UserDefaults storage
    private enum Keys {
        static let cachedDeviceList = "cachedDeviceList"
    }
    
    // MARK: - Initialization
    
    /// Creates a new CacheService instance.
    ///
    /// - Parameter userDefaults: The UserDefaults instance to use for storage.
    ///   Defaults to the shared App Group UserDefaults.
    public init(userDefaults: UserDefaults = SharedUserDefaults.shared) {
        self.userDefaults = userDefaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        
        // Configure date encoding strategy for consistent serialization
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - CacheServiceProtocol Implementation
    
    /// Saves a list of smart plug devices to the cache.
    /// The cache timestamp is automatically set to the current time.
    ///
    /// - Parameter devices: The list of devices to cache
    /// - Note: Validates Requirement 5.1 - Cache device list locally after successful fetch
    public func saveDevices(_ devices: [SmartPlug]) {
        let cachedList = CachedDeviceList(devices: devices, cachedAt: Date())
        
        do {
            let data = try encoder.encode(cachedList)
            userDefaults.set(data, forKey: Keys.cachedDeviceList)
            userDefaults.synchronize()
        } catch {
            // Log error but don't throw - caching is a best-effort operation
            print("CacheService: Failed to save devices to cache: \(error.localizedDescription)")
        }
    }
    
    /// Loads the cached list of smart plug devices.
    ///
    /// - Returns: The cached devices if available, nil if no cache exists
    /// - Note: Validates Requirement 5.2 - Display cached data when offline
    public func loadDevices() -> [SmartPlug]? {
        return loadCachedDeviceList()?.devices
    }
    
    /// Returns the age of the current cache in seconds.
    ///
    /// - Returns: The cache age in seconds, or nil if no cache exists
    /// - Note: Validates Requirements 5.3, 5.4 - Cache staleness detection
    public func getCacheAge() -> TimeInterval? {
        guard let cachedList = loadCachedDeviceList() else {
            return nil
        }
        return Date().timeIntervalSince(cachedList.cachedAt)
    }
    
    /// Clears all cached device data.
    public func clearCache() {
        userDefaults.removeObject(forKey: Keys.cachedDeviceList)
        userDefaults.synchronize()
    }
    
    /// Returns whether the cache is stale (older than 24 hours).
    ///
    /// - Returns: true if cache is stale or doesn't exist, false otherwise
    /// - Note: Validates Requirement 5.4 - Prompt refresh if cache older than 24 hours
    public func isCacheStale() -> Bool {
        guard let cachedList = loadCachedDeviceList() else {
            return true // No cache exists
        }
        return cachedList.isStale
    }
    
    /// Returns the timestamp when the cache was last updated.
    ///
    /// - Returns: The cache timestamp, or nil if no cache exists
    public func getCacheTimestamp() -> Date? {
        return loadCachedDeviceList()?.cachedAt
    }
    
    /// Returns the full cached device list with metadata.
    ///
    /// - Returns: The CachedDeviceList if available, nil if no cache exists
    public func loadCachedDeviceList() -> CachedDeviceList? {
        guard let data = userDefaults.data(forKey: Keys.cachedDeviceList) else {
            return nil
        }
        
        do {
            return try decoder.decode(CachedDeviceList.self, from: data)
        } catch {
            // Log error and return nil - corrupted cache should be treated as no cache
            print("CacheService: Failed to load devices from cache: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Mock Implementation for Testing

/// Mock implementation of CacheServiceProtocol for testing purposes.
public final class MockCacheService: CacheServiceProtocol {
    
    // MARK: - Test Properties
    
    /// The stored cached device list (for test inspection)
    public var storedCachedList: CachedDeviceList?
    
    /// Flag to simulate save failures
    public var shouldFailOnSave: Bool = false
    
    /// Flag to simulate load failures
    public var shouldFailOnLoad: Bool = false
    
    /// Counter for save operations (for test verification)
    public private(set) var saveCallCount: Int = 0
    
    /// Counter for load operations (for test verification)
    public private(set) var loadCallCount: Int = 0
    
    /// Counter for clear operations (for test verification)
    public private(set) var clearCallCount: Int = 0
    
    // MARK: - Initialization
    
    public init() {}
    
    /// Convenience initializer with pre-populated cache
    public init(devices: [SmartPlug], cachedAt: Date = Date()) {
        self.storedCachedList = CachedDeviceList(devices: devices, cachedAt: cachedAt)
    }
    
    // MARK: - CacheServiceProtocol Implementation
    
    public func saveDevices(_ devices: [SmartPlug]) {
        saveCallCount += 1
        
        guard !shouldFailOnSave else {
            return
        }
        
        storedCachedList = CachedDeviceList(devices: devices, cachedAt: Date())
    }
    
    public func loadDevices() -> [SmartPlug]? {
        loadCallCount += 1
        
        guard !shouldFailOnLoad else {
            return nil
        }
        
        return storedCachedList?.devices
    }
    
    public func getCacheAge() -> TimeInterval? {
        guard let cachedList = storedCachedList else {
            return nil
        }
        return Date().timeIntervalSince(cachedList.cachedAt)
    }
    
    public func clearCache() {
        clearCallCount += 1
        storedCachedList = nil
    }
    
    public func isCacheStale() -> Bool {
        guard let cachedList = storedCachedList else {
            return true
        }
        return cachedList.isStale
    }
    
    public func getCacheTimestamp() -> Date? {
        return storedCachedList?.cachedAt
    }
    
    public func loadCachedDeviceList() -> CachedDeviceList? {
        loadCallCount += 1
        
        guard !shouldFailOnLoad else {
            return nil
        }
        
        return storedCachedList
    }
    
    // MARK: - Test Helpers
    
    /// Resets all counters and state for a fresh test
    public func reset() {
        storedCachedList = nil
        shouldFailOnSave = false
        shouldFailOnLoad = false
        saveCallCount = 0
        loadCallCount = 0
        clearCallCount = 0
    }
    
    /// Sets up a stale cache for testing staleness detection
    public func setupStaleCache(devices: [SmartPlug]) {
        let staleDate = Date().addingTimeInterval(-CachedDeviceList.cacheExpirationInterval - 1)
        storedCachedList = CachedDeviceList(devices: devices, cachedAt: staleDate)
    }
    
    /// Sets up a fresh cache for testing
    public func setupFreshCache(devices: [SmartPlug]) {
        storedCachedList = CachedDeviceList(devices: devices, cachedAt: Date())
    }
}
