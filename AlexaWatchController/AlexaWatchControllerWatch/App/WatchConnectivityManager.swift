//
//  WatchConnectivityManager.swift
//  AlexaWatchControllerWatch
//
//  Manages WatchConnectivity session for watchOS App
//

import Foundation
import WatchConnectivity

/// Manages WatchConnectivity session for the watchOS App
/// Handles receiving token synchronization from the iOS Companion App
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isReachable: Bool = false
    @Published var receivedTokenData: Data?
    
    private var session: WCSession?
    
    private override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity is not supported")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    /// Activates the WatchConnectivity session
    func activate() {
        setupSession()
    }
    
    /// Requests token from the iOS Companion App
    func requestToken() {
        guard let session = session, session.isReachable else {
            print("iPhone is not reachable")
            return
        }
        
        session.sendMessage(["request": "token"], replyHandler: { response in
            if let tokenData = response["authToken"] as? Data {
                DispatchQueue.main.async {
                    self.receivedTokenData = tokenData
                }
            }
        }, errorHandler: { error in
            print("Failed to request token: \(error)")
        })
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        
        if let error = error {
            print("WCSession activation failed: \(error)")
        }
        
        // Check for any pending application context
        if let tokenData = session.receivedApplicationContext["authToken"] as? Data {
            DispatchQueue.main.async {
                self.receivedTokenData = tokenData
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        DispatchQueue.main.async {
            self.receivedTokenData = messageData
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let tokenData = applicationContext["authToken"] as? Data {
            DispatchQueue.main.async {
                self.receivedTokenData = tokenData
            }
        }
    }
}
