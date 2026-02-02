//
//  WatchConnectivityManager.swift
//  AlexaWatchController
//
//  Manages WatchConnectivity session for iOS Companion App
//

import Foundation
import WatchConnectivity

/// Manages WatchConnectivity session for the iOS Companion App
/// Handles token synchronization with the Watch app
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isReachable: Bool = false
    @Published var isPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    
    private var session: WCSession?
    
    private override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity is not supported on this device")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    /// Sends authentication token to the Watch app
    /// - Parameter token: The AuthToken to sync
    func sendToken(_ tokenData: Data) {
        guard let session = session, session.isReachable else {
            // Use application context for background transfer
            do {
                try session?.updateApplicationContext(["authToken": tokenData])
            } catch {
                print("Failed to update application context: \(error)")
            }
            return
        }
        
        // Send immediately if reachable
        session.sendMessageData(tokenData, replyHandler: nil) { error in
            print("Failed to send token: \(error)")
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
        
        if let error = error {
            print("WCSession activation failed: \(error)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated")
        // Reactivate session
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
}
