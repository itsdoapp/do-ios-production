//
//  CrossDeviceAuthManager.swift
//  Do
//
//  Created for cross-device authentication synchronization
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import WatchConnectivity

/// Manages authentication state synchronization between iPhone and Apple Watch
class CrossDeviceAuthManager: NSObject {
    static let shared = CrossDeviceAuthManager()
    
    private var session: WCSession?
    private let keychainManager = KeychainManager.shared
    private let userDefaults = UserDefaults.standard
    
    private override init() {
        super.init()
        print("📱 [CrossDeviceAuthManager] Initializing. Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        setupWatchConnectivity()
    }
    
    // MARK: - Watch Connectivity Setup
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("⚠️ [CrossDeviceAuthManager] WatchConnectivity not supported")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    // MARK: - Token Synchronization
    
    /// Sync current authentication tokens to watch
    func syncTokensToWatch() {
        guard let session = session else { return }
        
        if !session.isWatchAppInstalled {
            print("⚠️ [CrossDeviceAuthManager] Warning: session.isWatchAppInstalled is false. Attempting sync anyway...")
        }
        
        guard session.activationState == .activated else {
            print("⚠️ [CrossDeviceAuthManager] Session not activated")
            return
        }
        
        // Read tokens from Keychain (primary source)
        let idToken = keychainManager.get(Constants.Keychain.idToken) ?? ""
        let accessToken = keychainManager.get(Constants.Keychain.accessToken) ?? ""
        let refreshToken = keychainManager.get(Constants.Keychain.refreshToken) ?? ""
        let userId = keychainManager.get(Constants.Keychain.userId) ?? userDefaults.string(forKey: "cognito_user_id") ?? ""
        
        // Read user info from UserDefaults (set by AuthService)
        let email = userDefaults.string(forKey: "email") ?? ""
        let username = userDefaults.string(forKey: "username") ?? ""
        
        // CRITICAL: Allow syncing if we have accessToken + userId (matches AuthService logic)
        // Don't require idToken since AuthService uses accessToken + userId for authentication
        let hasIdToken = !idToken.isEmpty
        let hasAccessToken = !accessToken.isEmpty
        let hasUserId = !userId.isEmpty
        
        guard hasIdToken || (hasAccessToken && hasUserId) else {
            print("⚠️ [CrossDeviceAuthManager] No valid tokens found (need idToken OR accessToken+userId), cannot sync")
            print("   - idToken exists: \(hasIdToken)")
            print("   - accessToken exists: \(hasAccessToken)")
            print("   - userId exists: \(hasUserId)")
            return
        }
        
        let tokens: [String: Any] = [
            "type": "authTokens",
            "idToken": idToken,
            "accessToken": accessToken,
            "refreshToken": refreshToken,
            "userId": userId,
            "email": email,
            "username": username,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        do {
            try session.updateApplicationContext(tokens)
            print("✅ [CrossDeviceAuthManager] Tokens synced to watch via application context")
        } catch {
            print("❌ [CrossDeviceAuthManager] Failed to sync tokens: \(error.localizedDescription)")
        }
    }
    
    /// Request authentication status from phone (called from watch)
    func requestAuthStatus(replyHandler: @escaping ([String: Any]) -> Void) {
        guard let session = session, session.isReachable else {
            // If not reachable, return cached status
            let cachedStatus = getCachedAuthStatus()
            replyHandler(cachedStatus)
            return
        }
        
        session.sendMessage(["request": "authStatus"], replyHandler: replyHandler) { error in
            print("❌ [CrossDeviceAuthManager] Error requesting auth status: \(error.localizedDescription)")
            let cachedStatus = self.getCachedAuthStatus()
            replyHandler(cachedStatus)
        }
    }
    
    /// Get current authentication status
    func getCachedAuthStatus() -> [String: Any] {
        // Read from Keychain (primary source)
        let idToken = keychainManager.get(Constants.Keychain.idToken) ?? ""
        let accessToken = keychainManager.get(Constants.Keychain.accessToken) ?? ""
        let refreshToken = keychainManager.get(Constants.Keychain.refreshToken) ?? ""
        let userId = keychainManager.get(Constants.Keychain.userId) ?? userDefaults.string(forKey: "cognito_user_id") ?? ""
        
        // Read user info from UserDefaults
        let email = userDefaults.string(forKey: "email") ?? ""
        let username = userDefaults.string(forKey: "username") ?? ""
        
        // CRITICAL: Check multiple sources for authentication status
        // AuthService uses accessToken + userId, so we should too
        let hasIdToken = !idToken.isEmpty
        let hasAccessToken = !accessToken.isEmpty
        let hasUserId = !userId.isEmpty
        
        // User is authenticated if they have EITHER idToken OR (accessToken AND userId)
        // This matches AuthService.checkAuthStatus() logic
        let isAuthenticated = hasIdToken || (hasAccessToken && hasUserId)
        
        // Debug logging
        print("🔍 [CrossDeviceAuthManager] Auth status check:")
        print("   - idToken exists: \(hasIdToken)")
        print("   - accessToken exists: \(hasAccessToken)")
        print("   - userId exists: \(hasUserId)")
        print("   - isAuthenticated: \(isAuthenticated)")
        
        return [
            "isAuthenticated": isAuthenticated,
            "idToken": idToken,
            "accessToken": accessToken,
            "refreshToken": refreshToken,
            "userId": userId,
            "email": email,
            "username": username
        ]
    }
    
    // MARK: - Token Refresh
    
    /// Handle token refresh and sync to watch
    func handleTokenRefresh(newTokens: [String: String]) {
        // Tokens should already be saved to Keychain by AuthService
        // Just sync to watch
        syncTokensToWatch()
    }
    
    // MARK: - Logout
    
    /// Clear authentication on both devices
    func logout() {
        // Send empty tokens to watch to clear authentication
        let emptyTokens: [String: Any] = [
            "type": "authTokens",
            "idToken": "",
            "accessToken": "",
            "refreshToken": "",
            "userId": "",
            "email": "",
            "username": "",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        guard let session = session, session.isWatchAppInstalled else {
            return
        }
        
        do {
            try session.updateApplicationContext(emptyTokens)
            print("✅ [CrossDeviceAuthManager] Logout synced to watch")
        } catch {
            print("❌ [CrossDeviceAuthManager] Failed to sync logout: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension CrossDeviceAuthManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ [CrossDeviceAuthManager] Session activation failed: \(error.localizedDescription)")
        } else {
            print("✅ [CrossDeviceAuthManager] Session activated with state: \(activationState.rawValue)")
            // Sync tokens on activation - use a small delay to ensure session is fully ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.syncTokensToWatch()
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ [CrossDeviceAuthManager] Session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("⚠️ [CrossDeviceAuthManager] Session deactivated, reactivating...")
        session.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if let request = message["request"] as? String, request == "authStatus" {
            let status = getCachedAuthStatus()
            replyHandler(status)
            // Also sync tokens after responding to auth status request
            DispatchQueue.main.async { [weak self] in
                self?.syncTokensToWatch()
            }
        } else {
            replyHandler(["error": "Unknown request"])
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let type = applicationContext["type"] as? String, type == "authTokens" {
            // Tokens received from watch (if watch initiated login)
            // This is less common but handle it for completeness
            print("📱 [CrossDeviceAuthManager] Received auth tokens from watch")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("📱 [CrossDeviceAuthManager] Watch reachability changed: \(session.isReachable)")
        // When watch becomes reachable, sync tokens immediately
        if session.isReachable {
            print("📱 [CrossDeviceAuthManager] Watch is now reachable, syncing tokens...")
            syncTokensToWatch()
        }
    }
}

