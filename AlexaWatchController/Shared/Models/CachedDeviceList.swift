//
//  CachedDeviceList.swift
//  AlexaWatchController
//
//  Core data model for caching device lists with staleness detection.
//

import Foundation

/// Represents a cached list of smart plug devices with timestamp.
/// Used for offline access and reducing API calls.
/// Conforms to Codable for persistence and Equatable for comparison.
public struct CachedDeviceList: Codable, Equatable, Sendable {
    /// The cached list of smart plug devices
    public let devices: [SmartPlug]
    
    /// The timestamp when the cache was created
    public let cachedAt: Date
    
    /// The cache expiration interval in seconds (24 hours)
    public static let cacheExpirationInterval: TimeInterval = 86400
    
    /// Creates a new CachedDeviceList instance.
    /// - Parameters:
    ///   - devices: The list of devices to cache
    ///   - cachedAt: The cache timestamp (defaults to current time)
    public init(devices: [SmartPlug], cachedAt: Date = Date()) {
        self.devices = devices
        self.cachedAt = cachedAt
    }
    
    /// Returns true if the cached data is stale (older than 24 hours).
    /// Validates: Requirements 5.3, 5.4 - Cache staleness detection
    public var isStale: Bool {
        Date().timeIntervalSince(cachedAt) > Self.cacheExpirationInterval
    }
    
    /// Returns the age of the cache in seconds.
    public var cacheAge: TimeInterval {
        Date().timeIntervalSince(cachedAt)
    }
    
    /// Returns a human-readable string describing the cache age.
    public var cacheAgeDescription: String {
        let age = cacheAge
        
        if age < 60 {
            return "刚刚更新"
        } else if age < 3600 {
            let minutes = Int(age / 60)
            return "\(minutes) 分钟前更新"
        } else if age < 86400 {
            let hours = Int(age / 3600)
            return "\(hours) 小时前更新"
        } else {
            let days = Int(age / 86400)
            return "\(days) 天前更新"
        }
    }
    
    /// Returns true if the cache is empty (no devices).
    public var isEmpty: Bool {
        devices.isEmpty
    }
    
    /// Returns the number of cached devices.
    public var deviceCount: Int {
        devices.count
    }
    
    /// Returns a device by its ID, if found in the cache.
    /// - Parameter id: The device ID to search for
    /// - Returns: The SmartPlug if found, nil otherwise
    public func device(withId id: String) -> SmartPlug? {
        devices.first { $0.id == id }
    }
    
    /// Returns a new CachedDeviceList with an updated device.
    /// - Parameter device: The device to update
    /// - Returns: A new CachedDeviceList with the device updated
    public func updatingDevice(_ device: SmartPlug) -> CachedDeviceList {
        let updatedDevices = devices.map { existingDevice in
            existingDevice.id == device.id ? device : existingDevice
        }
        return CachedDeviceList(devices: updatedDevices, cachedAt: cachedAt)
    }
}
