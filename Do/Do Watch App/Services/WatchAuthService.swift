//
//  WatchAuthService.swift
//  Do
//
//  Authentication service for watch app
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import WatchConnectivity
import Combine

/// Authentication service for watch app to handle login status and token management
class WatchAuthService: NSObject, ObservableObject {
    static let shared = WatchAuthService()
    
    private var session: WCSession?
    private let userDefaults = UserDefaults(suiteName: "group.com.do.fitness")
    private let connectivityManager = WatchConnectivityManager.shared
    
    private let authTokenKey = "cognito_id_token"
    private let accessTokenKey = "cognito_access_token"
    private let refreshTokenKey = "cognito_refresh_token"
    private let userIdKey = "cognito_user_id"
    private let emailKey = "email"
    private let usernameKey = "username"
    
    private var pendingAuthCompletions: [(Bool, [String: Any]?) -> Void] = []
    private var activationObserver: AnyCancellable?
    
    @Published var isAuthenticated: Bool = false {
        didSet {
            if isAuthenticated != oldValue {
                objectWillChange.send()
            }
        }
    }
    
    override init() {
        super.init()
        print("⌚️ [WatchAuthService] Initializing. Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        // Check initial authentication status
        isAuthenticated = userDefaults?.string(forKey: authTokenKey) != nil
        setupWatchConnectivity()
        observeActivation()
    }
    
    
    // MARK: - Watch Connectivity Setup
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("⚠️ [WatchAuthService] WatchConnectivity not supported")
            return
        }
        
        print("🔧 [WatchAuthService] Setting up WatchConnectivity...")
        
        // Use the shared session from WatchConnectivityManager to avoid conflicts
        // WatchConnectivityManager initializes first and activates the session
        session = WCSession.default
        
        let currentState = session?.activationState ?? .notActivated
        print("🔧 [WatchAuthService] Current activation state: \(currentState.rawValue)")
        
        if currentState == .activated {
            print("✅ [WatchAuthService] Session already activated by WatchConnectivityManager")
        } else {
            print("⏳ [WatchAuthService] Session activation in progress or not activated yet")
        }
    }
    
    private func observeActivation() {
        // Observe WatchConnectivityManager's activation state
        print("👀 [WatchAuthService] Setting up activation observer...")
        activationObserver = connectivityManager.$isActivated
            .sink { [weak self] isActivated in
                guard let self = self else { return }
                print("👀 [WatchAuthService] Activation state changed: \(isActivated)")
                if isActivated {
                    print("✅ [WatchAuthService] Detected session activation via WatchConnectivityManager")
                    // Process any pending auth requests
                    if !self.pendingAuthCompletions.isEmpty {
                        print("📱 [WatchAuthService] Processing \(self.pendingAuthCompletions.count) pending auth requests")
                        let completions = self.pendingAuthCompletions
                        self.pendingAuthCompletions.removeAll()
                        for (index, completion) in completions.enumerated() {
                            print("📱 [WatchAuthService] Processing pending request \(index + 1)/\(completions.count)")
                            self.performAuthCheck(completion: completion)
                        }
                    } else {
                        print("📱 [WatchAuthService] No pending requests, performing initial auth check")
                        self.performAuthCheck { isAuthenticated, _ in
                            print("📱 [WatchAuthService] Initial auth status: \(isAuthenticated)")
                        }
                    }
                }
            }
    }
    
    // MARK: - Authentication Status
    
    /// Request login status from iPhone
    func requestLoginStatus(completion: @escaping (Bool, [String: Any]?) -> Void) {
        guard let session = session else {
            print("⚠️ [WatchAuthService] Session is nil, setting up...")
            setupWatchConnectivity()
            // Return cached tokens immediately
            DispatchQueue.main.async {
                let cached = self.getCachedTokens()
                let authenticated = cached != nil
                self.isAuthenticated = authenticated
                completion(authenticated, cached)
            }
            return
        }
        
        // Check if session is activated via WatchConnectivityManager
        let currentState = session.activationState
        let isActivated = connectivityManager.isActivated
        print("📊 [WatchAuthService] Session state: \(currentState.rawValue), WatchConnectivityManager.isActivated: \(isActivated)")
        
        // If session is actually activated but manager says it's not, update manager state
        if currentState == .activated && !isActivated {
            print("⚠️ [WatchAuthService] Session is activated but manager says it's not, updating manager...")
            DispatchQueue.main.async {
                // Force update the connectivity manager's state
                self.connectivityManager.isActivated = true
            }
        }
        
        if currentState != .activated {
            print("⚠️ [WatchAuthService] Session not activated yet, state: \(currentState.rawValue)")
            
            // Store completion to call after activation
            pendingAuthCompletions.append(completion)
            print("📝 [WatchAuthService] Stored completion. Total pending: \(pendingAuthCompletions.count)")
            
            // Return cached tokens immediately for user feedback
            DispatchQueue.main.async {
                let cached = self.getCachedTokens()
                let authenticated = cached != nil
                print("💾 [WatchAuthService] Returning cached tokens, authenticated: \(authenticated)")
                if self.isAuthenticated != authenticated {
                    self.isAuthenticated = authenticated
                }
                completion(authenticated, cached)
            }
            return
        }
        
        print("✅ [WatchAuthService] Session is activated, proceeding with auth check")
        
        // Session is activated, perform the actual check
        performAuthCheck(completion: completion)
    }
    
    /// Perform the actual authentication check (called after session is activated)
    private func performAuthCheck(retryCount: Int = 0, completion: @escaping (Bool, [String: Any]?) -> Void) {
        guard let session = session, session.activationState == .activated else {
            // Fallback to cached tokens
            let cached = self.getCachedTokens()
            let authenticated = cached != nil
            DispatchQueue.main.async {
                self.isAuthenticated = authenticated
                completion(authenticated, cached)
            }
            return
        }
        
        print("📱 [WatchAuthService] Performing auth check, reachable: \(session.isReachable)")
        
        if session.isReachable {
            session.sendMessage(["request": "authStatus"], replyHandler: { response in
                print("✅ [WatchAuthService] Received auth status response")
                DispatchQueue.main.async {
                    let isAuthenticated = response["isAuthenticated"] as? Bool ?? false
                    if isAuthenticated {
                        self.storeTokens(from: response)
                    }
                    self.isAuthenticated = isAuthenticated
                    completion(isAuthenticated, response)
                }
            }, errorHandler: { error in
                print("❌ [WatchAuthService] Error requesting login status: \(error.localizedDescription)")
                
                // Retry on failure (e.g. timeout) up to 2 times
                if retryCount < 2 {
                    print("🔄 [WatchAuthService] Retrying auth check (attempt \(retryCount + 1))...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.performAuthCheck(retryCount: retryCount + 1, completion: completion)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    // Fallback to cached tokens
                    let cached = self.getCachedTokens()
                    let authenticated = cached != nil
                    self.isAuthenticated = authenticated
                    completion(authenticated, cached)
                }
            })
        } else {
            // Not reachable, check application context
            print("📱 [WatchAuthService] iPhone not reachable, checking application context")
            let context = session.receivedApplicationContext
            if let type = context["type"] as? String, type == "authTokens" {
                let idToken = context["idToken"] as? String ?? ""
                if !idToken.isEmpty {
                    print("✅ [WatchAuthService] Found tokens in application context")
                    self.storeTokens(from: context)
                    DispatchQueue.main.async {
                        self.isAuthenticated = true
                        completion(true, context)
                    }
                } else {
                    // Empty tokens means logout
                    print("⌚️ [WatchAuthService] Empty tokens in context, logging out")
                    self.clearTokens()
                    DispatchQueue.main.async {
                        completion(false, nil)
                    }
                }
            } else {
                // Fallback to cached tokens
                print("📱 [WatchAuthService] No context found, checking cached tokens")
                let cached = self.getCachedTokens()
                let authenticated = cached != nil
                DispatchQueue.main.async {
                    self.isAuthenticated = authenticated
                    completion(authenticated, cached)
                }
            }
        }
    }
    
    // MARK: - Token Storage
    
    /// Store tokens securely in watch app storage
    private func storeTokens(from response: [String: Any]) {
        guard let userDefaults = userDefaults else { return }
        
        let idToken = response["idToken"] as? String ?? ""
        let accessToken = response["accessToken"] as? String ?? ""
        let refreshToken = response["refreshToken"] as? String ?? ""
        let userId = response["userId"] as? String ?? ""
        let email = response["email"] as? String ?? ""
        let username = response["username"] as? String ?? ""
        
        // Handle logout case (empty idToken)
        if idToken.isEmpty {
            clearTokens()
            return
        }
        
        // Store tokens
        userDefaults.set(idToken, forKey: authTokenKey)
        if !accessToken.isEmpty {
            userDefaults.set(accessToken, forKey: accessTokenKey)
        }
        if !refreshToken.isEmpty {
            userDefaults.set(refreshToken, forKey: refreshTokenKey)
        }
        if !userId.isEmpty {
            userDefaults.set(userId, forKey: userIdKey)
        }
        if !email.isEmpty {
            userDefaults.set(email, forKey: emailKey)
        }
        if !username.isEmpty {
            userDefaults.set(username, forKey: usernameKey)
        }
        
        userDefaults.synchronize()
        
        // Update authentication status
        DispatchQueue.main.async {
            self.isAuthenticated = true
        }
        
        print("✅ [WatchAuthService] Tokens stored in watch app")
    }
    
    /// Get cached tokens
    func getCachedTokens() -> [String: Any]? {
        guard let userDefaults = userDefaults,
              let idToken = userDefaults.string(forKey: authTokenKey), !idToken.isEmpty else {
            return nil
        }
        
        return [
            "idToken": idToken,
            "accessToken": userDefaults.string(forKey: accessTokenKey) ?? "",
            "refreshToken": userDefaults.string(forKey: refreshTokenKey) ?? "",
            "userId": userDefaults.string(forKey: userIdKey) ?? "",
            "email": userDefaults.string(forKey: emailKey) ?? "",
            "username": userDefaults.string(forKey: usernameKey) ?? ""
        ]
    }
    
    /// Clear stored tokens
    func clearTokens() {
        guard let userDefaults = userDefaults else { return }
        
        userDefaults.removeObject(forKey: authTokenKey)
        userDefaults.removeObject(forKey: accessTokenKey)
        userDefaults.removeObject(forKey: refreshTokenKey)
        userDefaults.removeObject(forKey: userIdKey)
        userDefaults.removeObject(forKey: emailKey)
        userDefaults.removeObject(forKey: usernameKey)
        userDefaults.synchronize()
        
        // Update authentication status
        DispatchQueue.main.async {
            self.isAuthenticated = false
        }
        
        print("✅ [WatchAuthService] Tokens cleared from watch app")
    }
    
    // MARK: - Token Validation
    
    /// Validate if current tokens are still valid
    func validateTokens() -> Bool {
        guard let tokens = getCachedTokens(),
              let idToken = tokens["idToken"] as? String, !idToken.isEmpty else {
            return false
        }
        
        // Basic validation - in production, decode JWT and check expiration
        // For now, just check if token exists
        return true
    }


    // Note: WatchAuthService no longer implements WCSessionDelegate
    // WatchConnectivityManager handles all session delegate callbacks
    // We observe WatchConnectivityManager's isActivated property instead
    
    func handleApplicationContext(_ applicationContext: [String : Any]) {
        guard let type = applicationContext["type"] as? String, type == "authTokens" else {
            return
        }
        
        let idToken = applicationContext["idToken"] as? String ?? ""
        
        DispatchQueue.main.async {
            if idToken.isEmpty {
                // Empty tokens means logout
                print("⌚️ [WatchAuthService] Received logout signal from iPhone")
                self.clearTokens()
                
                // Notify that authentication state changed
                NotificationCenter.default.post(
                    name: NSNotification.Name("WatchAuthStateChanged"),
                    object: nil,
                    userInfo: ["isAuthenticated": false]
                )
            } else {
                // Store new tokens
                print("⌚️ [WatchAuthService] Received auth tokens from iPhone")
                self.storeTokens(from: applicationContext)
                
                // Notify that authentication state changed
                NotificationCenter.default.post(
                    name: NSNotification.Name("WatchAuthStateChanged"),
                    object: nil,
                    userInfo: applicationContext
                )
            }
        }
    }
}

