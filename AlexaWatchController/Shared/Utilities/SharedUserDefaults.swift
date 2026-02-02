//
//  SharedUserDefaults.swift
//  Shared
//
//  Shared UserDefaults for App Group data sharing
//

import Foundation

/// Provides access to shared UserDefaults using App Group
public class SharedUserDefaults {
    
    /// Shared instance using the App Group suite
    public static let shared: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: AppConfiguration.appGroupIdentifier) else {
            fatalError("Failed to create UserDefaults with App Group: \(AppConfiguration.appGroupIdentifier)")
        }
        return defaults
    }()
    
    // MARK: - Keys
    
    public enum Keys {
        public static let cachedDevices = "cachedDevices"
        public static let cacheTimestamp = "cacheTimestamp"
        public static let selectedComplicationDevice = "selectedComplicationDevice"
        public static let lastSyncTimestamp = "lastSyncTimestamp"
    }
    
    private init() {}
}
