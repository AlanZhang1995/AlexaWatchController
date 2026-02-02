//
//  KeychainService.swift
//  AlexaWatchController
//
//  Secure Keychain storage service for sensitive data.
//  Validates: Requirement 1.3 - Companion_App SHALL securely store the OAuth_Token
//

import Foundation
import Security

/// Service for securely storing and retrieving data from the iOS Keychain.
/// Provides type-safe storage for Codable objects with encryption.
public final class KeychainService {
    
    // MARK: - Properties
    
    /// The service name used for Keychain items
    private let serviceName: String
    
    /// The access group for shared Keychain access (optional)
    private let accessGroup: String?
    
    // MARK: - Initialization
    
    /// Creates a new KeychainService instance.
    /// - Parameters:
    ///   - serviceName: The service name for Keychain items
    ///   - accessGroup: Optional access group for shared Keychain access
    public init(
        serviceName: String = AppConfiguration.keychainServiceName,
        accessGroup: String? = nil
    ) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }
    
    // MARK: - Public Methods
    
    /// Saves a Codable object to the Keychain.
    /// - Parameters:
    ///   - item: The item to save
    ///   - key: The key to store the item under
    /// - Returns: `true` if save was successful, `false` otherwise
    @discardableResult
    public func save<T: Codable>(_ item: T, forKey key: String) -> Bool {
        guard let data = try? JSONEncoder().encode(item) else {
            return false
        }
        
        // Delete any existing item first
        delete(forKey: key)
        
        var query = baseQuery(forKey: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieves a Codable object from the Keychain.
    /// - Parameters:
    ///   - type: The type of object to retrieve
    ///   - key: The key the item is stored under
    /// - Returns: The retrieved item, or nil if not found or decoding fails
    public func retrieve<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let item = try? JSONDecoder().decode(type, from: data) else {
            return nil
        }
        
        return item
    }
    
    /// Deletes an item from the Keychain.
    /// - Parameter key: The key of the item to delete
    /// - Returns: `true` if deletion was successful or item didn't exist
    @discardableResult
    public func delete(forKey key: String) -> Bool {
        let query = baseQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Checks if an item exists in the Keychain.
    /// - Parameter key: The key to check
    /// - Returns: `true` if the item exists
    public func exists(forKey key: String) -> Bool {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = false
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Updates an existing item in the Keychain.
    /// - Parameters:
    ///   - item: The new item value
    ///   - key: The key of the item to update
    /// - Returns: `true` if update was successful
    @discardableResult
    public func update<T: Codable>(_ item: T, forKey key: String) -> Bool {
        guard let data = try? JSONEncoder().encode(item) else {
            return false
        }
        
        let query = baseQuery(forKey: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        // If item doesn't exist, try to save it
        if status == errSecItemNotFound {
            return save(item, forKey: key)
        }
        
        return status == errSecSuccess
    }
    
    /// Clears all items stored by this service.
    /// - Returns: `true` if clearing was successful
    @discardableResult
    public func clearAll() -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Private Methods
    
    /// Creates the base query dictionary for Keychain operations.
    /// - Parameter key: The key for the item
    /// - Returns: A dictionary with common query parameters
    private func baseQuery(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
}

// MARK: - Keychain Keys

/// Keys used for storing items in the Keychain
public enum KeychainKeys {
    /// Key for storing the OAuth authentication token
    public static let authToken = "com.alexawatchcontroller.authToken"
    
    /// Key for storing the OAuth state parameter
    public static let oauthState = "com.alexawatchcontroller.oauthState"
}
