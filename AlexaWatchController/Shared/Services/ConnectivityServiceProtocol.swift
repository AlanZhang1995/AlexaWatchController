//
//  ConnectivityServiceProtocol.swift
//  AlexaWatchController
//
//  Protocol defining the interface for WatchConnectivity token synchronization.
//  Validates: Requirements 1.4
//

import Foundation

/// Protocol defining the interface for synchronizing authentication tokens
/// between the iOS Companion App and the watchOS App via WatchConnectivity.
///
/// Requirements:
/// - 1.4: Sync OAuth token from Companion App to Watch App via WatchConnectivity
public protocol ConnectivityServiceProtocol {
    
    /// Sends an authentication token to the paired device.
    /// On iOS, this sends the token to the Watch App.
    /// On watchOS, this is typically not used (Watch receives tokens).
    ///
    /// - Parameter token: The AuthToken to send
    /// - Note: Validates Requirement 1.4 - Sync OAuth token from Companion App to Watch App
    func sendToken(_ token: AuthToken)
    
    /// Receives the most recently synced authentication token.
    /// On watchOS, this retrieves the token sent from the iOS Companion App.
    /// On iOS, this may return nil as the Companion App is the token source.
    ///
    /// - Returns: The received AuthToken if available, nil otherwise
    /// - Note: Validates Requirement 1.4 - Sync OAuth token from Companion App to Watch App
    func receiveToken() -> AuthToken?
    
    /// Indicates whether the paired device is currently reachable.
    /// When true, messages can be sent immediately.
    /// When false, messages will be queued via application context.
    var isReachable: Bool { get }
    
    /// Requests a token from the paired device.
    /// On watchOS, this requests the token from the iOS Companion App.
    /// On iOS, this is typically not used.
    func requestToken()
    
    /// Clears any received token data.
    /// Used when logging out or when re-authentication is required.
    func clearReceivedToken()
}

// MARK: - Default Implementation

public extension ConnectivityServiceProtocol {
    
    /// Default implementation for requesting token (no-op on iOS).
    func requestToken() {
        // Default no-op implementation
    }
    
    /// Default implementation for clearing received token (no-op on iOS).
    func clearReceivedToken() {
        // Default no-op implementation
    }
}
