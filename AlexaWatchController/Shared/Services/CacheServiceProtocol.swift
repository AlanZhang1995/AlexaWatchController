//
//  CacheServiceProtocol.swift
//  AlexaWatchController
//
//  Protocol defining the interface for device list caching.
//  Validates: Requirements 5.1, 5.2, 5.3, 5.4
//

import Foundation

/// Protocol defining the interface for caching smart plug device lists.
/// Implementations should provide persistent storage with expiration detection.
///
/// Requirements:
/// - 5.1: Cache device list locally after successful fetch
/// - 5.2: Display cached data when offline
/// - 5.3: Indicate when displaying cached data
/// - 5.4: Prompt refresh if cache older than 24 hours
public protocol CacheServiceProtocol {
    
    /// Saves a list of smart plug devices to the cache.
    /// The cache timestamp is automatically set to the current time.
    ///
    /// - Parameter devices: The list of devices to cache
    /// - Note: Validates Requirement 5.1 - Cache device list locally after successful fetch
    func saveDevices(_ devices: [SmartPlug])
    
    /// Loads the cached list of smart plug devices.
    ///
    /// - Returns: The cached devices if available, nil if no cache exists
    /// - Note: Validates Requirement 5.2 - Display cached data when offline
    func loadDevices() -> [SmartPlug]?
    
    /// Returns the age of the current cache in seconds.
    ///
    /// - Returns: The cache age in seconds, or nil if no cache exists
    /// - Note: Validates Requirements 5.3, 5.4 - Cache staleness detection
    func getCacheAge() -> TimeInterval?
    
    /// Clears all cached device data.
    func clearCache()
    
    /// Returns whether the cache is stale (older than 24 hours).
    ///
    /// - Returns: true if cache is stale or doesn't exist, false otherwise
    /// - Note: Validates Requirement 5.4 - Prompt refresh if cache older than 24 hours
    func isCacheStale() -> Bool
    
    /// Returns the timestamp when the cache was last updated.
    ///
    /// - Returns: The cache timestamp, or nil if no cache exists
    func getCacheTimestamp() -> Date?
    
    /// Returns the full cached device list with metadata.
    ///
    /// - Returns: The CachedDeviceList if available, nil if no cache exists
    func loadCachedDeviceList() -> CachedDeviceList?
}

// MARK: - Default Implementation

public extension CacheServiceProtocol {
    
    /// Default implementation for checking if cache is stale.
    /// Cache is considered stale if it's older than 24 hours or doesn't exist.
    func isCacheStale() -> Bool {
        guard let age = getCacheAge() else {
            return true // No cache exists
        }
        return age > CachedDeviceList.cacheExpirationInterval
    }
}
