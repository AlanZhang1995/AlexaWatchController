//
//  ConnectivityService.swift
//  AlexaWatchController
//
//  WatchConnectivity service implementation for token synchronization.
//  Validates: Requirements 1.4
//

import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// Implementation of the connectivity service for WatchConnectivity token synchronization.
/// Handles sending and receiving authentication tokens between iOS and watchOS apps.
///
/// This service provides a unified interface that works on both platforms:
/// - On iOS: Sends tokens to the Watch App
/// - On watchOS: Receives tokens from the iOS Companion App
///
/// Validates: Requirement 1.4 - Sync OAuth token from Companion App to Watch App via WatchConnectivity
public final class ConnectivityService: NSObject, ConnectivityServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether the paired device is currently reachable
    @Published public private(set) var isReachable: Bool = false
    
    /// The most recently received token data (watchOS only)
    @Published public private(set) var receivedTokenData: Data?
    
    #if os(iOS)
    /// Whether the Watch is paired (iOS only)
    @Published public private(set) var isPaired: Bool = false
    
    /// Whether the Watch App is installed (iOS only)
    @Published public private(set) var isWatchAppInstalled: Bool = false
    #endif
    
    // MARK: - Private Properties
    
    #if canImport(WatchConnectivity)
    /// The WatchConnectivity session
    private var session: WCSession?
    #endif
    
    /// JSON encoder for token serialization
    private let encoder = JSONEncoder()
    
    /// JSON decoder for token deserialization
    private let decoder = JSONDecoder()
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide use
    public static let shared = ConnectivityService()
    
    // MARK: - Initialization
    
    /// Creates a new ConnectivityService instance.
    /// Automatically activates the WatchConnectivity session if supported.
    public override init() {
        super.init()
        setupSession()
    }
    
    #if canImport(WatchConnectivity)
    /// Creates a ConnectivityService with a custom session (for testing).
    /// - Parameter session: The WCSession to use
    internal init(session: WCSession?) {
        self.session = session
        super.init()
        if session != nil {
            setupSession()
        }
    }
    #endif
    
    // MARK: - Session Setup
    
    /// Sets up and activates the WatchConnectivity session.
    private func setupSession() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else {
            print("WatchConnectivity is not supported on this device")
            return
        }
        
        if session == nil {
            session = WCSession.default
        }
        session?.delegate = self
        session?.activate()
        #else
        print("WatchConnectivity is not available on this platform")
        #endif
    }
    
    // MARK: - ConnectivityServiceProtocol
    
    /// Sends an authentication token to the paired device.
    /// Uses immediate message delivery if reachable, otherwise uses application context.
    ///
    /// - Parameter token: The AuthToken to send
    /// - Note: Validates Requirement 1.4 - Sync OAuth token from Companion App to Watch App
    public func sendToken(_ token: AuthToken) {
        guard let tokenData = try? encoder.encode(token) else {
            print("Failed to encode token for sending")
            return
        }
        
        #if canImport(WatchConnectivity)
        guard let session = session else {
            print("WCSession is not available")
            return
        }
        
        #if os(iOS)
        // On iOS, send token to Watch
        if session.isReachable {
            // Send immediately if Watch is reachable
            session.sendMessageData(tokenData, replyHandler: nil) { error in
                print("Failed to send token via message: \(error.localizedDescription)")
                // Fall back to application context
                self.sendTokenViaApplicationContext(tokenData)
            }
        } else {
            // Use application context for background transfer
            sendTokenViaApplicationContext(tokenData)
        }
        #elseif os(watchOS)
        // On watchOS, sending tokens is not typical but supported
        if session.isReachable {
            session.sendMessageData(tokenData, replyHandler: nil) { error in
                print("Failed to send token from Watch: \(error.localizedDescription)")
            }
        }
        #endif
        #else
        print("WatchConnectivity is not available - cannot send token")
        #endif
    }
    
    /// Receives the most recently synced authentication token.
    ///
    /// - Returns: The received AuthToken if available, nil otherwise
    /// - Note: Validates Requirement 1.4 - Sync OAuth token from Companion App to Watch App
    public func receiveToken() -> AuthToken? {
        guard let tokenData = receivedTokenData else {
            #if canImport(WatchConnectivity)
            // Check application context for any pending token
            if let contextData = session?.receivedApplicationContext[AppConfiguration.wcAuthTokenKey] as? Data {
                return try? decoder.decode(AuthToken.self, from: contextData)
            }
            #endif
            return nil
        }
        
        return try? decoder.decode(AuthToken.self, from: tokenData)
    }
    
    /// Requests a token from the paired device.
    /// On watchOS, this sends a request to the iOS Companion App.
    public func requestToken() {
        #if canImport(WatchConnectivity) && os(watchOS)
        guard let session = session, session.isReachable else {
            print("iPhone is not reachable for token request")
            return
        }
        
        let request: [String: Any] = [AppConfiguration.wcTokenRequestKey: "token"]
        session.sendMessage(request, replyHandler: { [weak self] response in
            if let tokenData = response[AppConfiguration.wcAuthTokenKey] as? Data {
                DispatchQueue.main.async {
                    self?.receivedTokenData = tokenData
                }
            }
        }, errorHandler: { error in
            print("Failed to request token: \(error.localizedDescription)")
        })
        #endif
    }
    
    /// Clears any received token data.
    public func clearReceivedToken() {
        DispatchQueue.main.async {
            self.receivedTokenData = nil
        }
    }
    
    // MARK: - Private Methods
    
    #if canImport(WatchConnectivity)
    /// Sends token data via application context for background delivery.
    /// - Parameter tokenData: The encoded token data to send
    private func sendTokenViaApplicationContext(_ tokenData: Data) {
        do {
            try session?.updateApplicationContext([AppConfiguration.wcAuthTokenKey: tokenData])
        } catch {
            print("Failed to update application context: \(error.localizedDescription)")
        }
    }
    #endif
}

// MARK: - WCSessionDelegate

#if canImport(WatchConnectivity)
extension ConnectivityService: WCSessionDelegate {
    
    /// Called when the session activation completes.
    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            
            #if os(iOS)
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            #endif
        }
        
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
            return
        }
        
        // Check for any pending token in application context
        if let tokenData = session.receivedApplicationContext[AppConfiguration.wcAuthTokenKey] as? Data {
            DispatchQueue.main.async {
                self.receivedTokenData = tokenData
            }
        }
    }
    
    #if os(iOS)
    /// Called when the session becomes inactive (iOS only).
    public func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }
    
    /// Called when the session deactivates (iOS only).
    public func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated")
        // Reactivate the session
        session.activate()
    }
    #endif
    
    /// Called when the reachability of the paired device changes.
    public func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
    
    /// Called when message data is received from the paired device.
    public func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        DispatchQueue.main.async {
            self.receivedTokenData = messageData
        }
    }
    
    /// Called when a message is received from the paired device.
    public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        #if os(iOS)
        // Handle token request from Watch
        if message[AppConfiguration.wcTokenRequestKey] as? String == "token" {
            // The iOS app should provide the token via AuthService
            // This is a placeholder - actual implementation would get token from AuthService
            replyHandler([:])
        }
        #else
        // Handle messages on watchOS
        if let tokenData = message[AppConfiguration.wcAuthTokenKey] as? Data {
            DispatchQueue.main.async {
                self.receivedTokenData = tokenData
            }
        }
        replyHandler([:])
        #endif
    }
    
    /// Called when application context is received from the paired device.
    public func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        if let tokenData = applicationContext[AppConfiguration.wcAuthTokenKey] as? Data {
            DispatchQueue.main.async {
                self.receivedTokenData = tokenData
            }
        }
    }
}
#endif

// MARK: - Mock for Testing

/// Mock implementation of ConnectivityServiceProtocol for testing.
public final class MockConnectivityService: ConnectivityServiceProtocol, ObservableObject {
    
    @Published public var isReachable: Bool = true
    
    public var sentToken: AuthToken?
    public var mockReceivedToken: AuthToken?
    public var tokenRequestCount: Int = 0
    public var clearTokenCount: Int = 0
    
    public init() {}
    
    public func sendToken(_ token: AuthToken) {
        sentToken = token
    }
    
    public func receiveToken() -> AuthToken? {
        return mockReceivedToken
    }
    
    public func requestToken() {
        tokenRequestCount += 1
    }
    
    public func clearReceivedToken() {
        clearTokenCount += 1
        mockReceivedToken = nil
    }
}
