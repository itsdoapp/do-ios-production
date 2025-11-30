//
//  AppleWatchConnectionManager.swift
//  Do
//
//  Manages WatchConnectivity for Apple Watch
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import WatchConnectivity

class AppleWatchConnectionManager: NSObject {
    static let shared = AppleWatchConnectionManager()
    
    private var session: WCSession?
    @Published var isConnected = false
    @Published var isReachable = false
    
    private override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        guard WCSession.isSupported() else { return }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    func sendMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        guard let session = session, session.isReachable else { return }
        
        session.sendMessage(message, replyHandler: replyHandler ?? { _ in }) { error in
            print("❌ [AppleWatchConnectionManager] Error: \(error.localizedDescription)")
        }
    }
}

extension AppleWatchConnectionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = session.isWatchAppInstalled
            self.isReachable = session.isReachable
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if let request = message["request"] as? String, request == "authStatus" {
            let status = CrossDeviceAuthManager.shared.getCachedAuthStatus()
            replyHandler(status)
            // Also trigger sync just in case
            DispatchQueue.main.async {
                CrossDeviceAuthManager.shared.syncTokensToWatch()
            }
        } else {
            replyHandler(["error": "Unknown request"])
        }
    }
}

