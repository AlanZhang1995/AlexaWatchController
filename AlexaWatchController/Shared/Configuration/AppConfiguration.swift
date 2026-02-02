//
//  AppConfiguration.swift
//  Shared
//
//  Configuration constants for Alexa Watch Controller
//

import Foundation

/// App-wide configuration constants
public enum AppConfiguration {
    
    // MARK: - Bundle Identifiers
    
    /// iOS Companion App Bundle ID
    public static let iOSBundleIdentifier = "com.example.alexawatchcontroller"
    
    /// watchOS App Bundle ID
    public static let watchOSBundleIdentifier = "com.example.alexawatchcontroller.watchkitapp"
    
    // MARK: - App Groups
    
    /// Shared App Group identifier for data sharing between iOS and watchOS
    public static let appGroupIdentifier = "group.com.example.alexawatchcontroller"
    
    // MARK: - Keychain
    
    /// Keychain service name for secure storage
    public static let keychainServiceName = "com.example.alexawatchcontroller.keychain"
    
    /// Keychain access group for shared keychain items
    public static let keychainAccessGroup = "com.example.alexawatchcontroller"
    
    // MARK: - Cache
    
    /// Cache expiration time in seconds (24 hours)
    public static let cacheExpirationInterval: TimeInterval = 86400
    
    /// UserDefaults suite name for shared data
    public static let sharedUserDefaultsSuiteName = appGroupIdentifier
    
    // MARK: - API
    
    /// Alexa API base URL
    public static let alexaAPIBaseURL = "https://api.amazonalexa.com"
    
    /// OAuth authorization URL
    public static let oauthAuthorizationURL = "https://www.amazon.com/ap/oa"
    
    /// OAuth token URL
    public static let oauthTokenURL = "https://api.amazon.com/auth/o2/token"
    
    /// OAuth redirect URI scheme
    public static let oauthRedirectScheme = "alexawatchcontroller"
    
    /// OAuth redirect URI
    public static let oauthRedirectURI = "\(oauthRedirectScheme)://oauth/callback"
    
    // MARK: - WatchConnectivity Keys
    
    /// Key for auth token in WatchConnectivity messages
    public static let wcAuthTokenKey = "authToken"
    
    /// Key for token request in WatchConnectivity messages
    public static let wcTokenRequestKey = "request"
}
