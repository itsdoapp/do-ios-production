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
    private var isCheckingAuth = false // Prevent duplicate auth checks
    
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
                        
                        // Check if we're already authenticated from cache
                        let cached = self.getCachedTokens()
                        let alreadyAuthenticated = cached != nil && self.isAuthenticated
                        
                        if alreadyAuthenticated {
                            print("📱 [WatchAuthService] Already authenticated from cache, completing pending requests with cached tokens")
                            // Complete all pending requests with cached tokens immediately
                            for completion in completions {
                                DispatchQueue.main.async {
                                    completion(true, cached)
                                }
                            }
                        } else {
                            // Only perform auth check if not already authenticated
                            for (index, completion) in completions.enumerated() {
                                print("📱 [WatchAuthService] Processing pending request \(index + 1)/\(completions.count)")
                                self.performAuthCheck(completion: completion)
                            }
                        }
                    } else {
                        // Only perform initial auth check if we don't have cached tokens
                        // This prevents unnecessary duplicate checks when we're already authenticated
                        let cached = self.getCachedTokens()
                        if cached == nil {
                            print("📱 [WatchAuthService] No cached tokens, performing initial auth check")
                            self.performAuthCheck { isAuthenticated, _ in
                                print("📱 [WatchAuthService] Initial auth status: \(isAuthenticated)")
                            }
                        } else {
                            print("📱 [WatchAuthService] Already have cached tokens, skipping initial auth check")
                            // Update auth status from cache
                            DispatchQueue.main.async {
                                self.isAuthenticated = true
                            }
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
        
        // Check if we're already authenticated from cache before making network request
        let cached = self.getCachedTokens()
        if cached != nil && self.isAuthenticated {
            print("✅ [WatchAuthService] Session is activated and already authenticated from cache, skipping network check")
            DispatchQueue.main.async {
                completion(true, cached)
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
        
        // Check if we're already authenticated from cache - if so, skip network check
        let cached = self.getCachedTokens()
        if cached != nil && self.isAuthenticated && retryCount == 0 {
            print("✅ [WatchAuthService] Already authenticated from cache, skipping network check")
            DispatchQueue.main.async {
                completion(true, cached)
            }
            return
        }
        
        // Prevent duplicate concurrent auth checks
        guard !isCheckingAuth || retryCount > 0 else {
            print("⚠️ [WatchAuthService] Auth check already in progress, using cached tokens")
            let authenticated = cached != nil
            DispatchQueue.main.async {
                self.isAuthenticated = authenticated
                completion(authenticated, cached)
            }
            return
        }
        
        print("📱 [WatchAuthService] Performing auth check, reachable: \(session.isReachable), retry: \(retryCount)")
        
        // Only set flag if this is not a retry
        if retryCount == 0 {
            isCheckingAuth = true
        }
        
        // Prioritize Application Context first as it's more reliable for initial sync
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
                return
            }
        }
        
        if session.isReachable {
            session.sendMessage(["request": "authStatus"], replyHandler: { [weak self] response in
                guard let self = self else { return }
                print("✅ [WatchAuthService] Received auth status response")
                self.isCheckingAuth = false
                DispatchQueue.main.async {
                    let isAuthenticated = response["isAuthenticated"] as? Bool ?? false
                    if isAuthenticated {
                        self.storeTokens(from: response)
                    } else {
                        // If phone says not authenticated, we should trust it, but verify if we have local tokens
                         let cached = self.getCachedTokens()
                         if cached != nil {
                             print("⚠️ [WatchAuthService] Phone says unauthenticated but we have local tokens. Keeping local tokens.")
                             self.isAuthenticated = true // Trust local cache if available to avoid logout loop
                             completion(true, cached)
                             return
                         }
                    }
                    self.isAuthenticated = isAuthenticated
                    completion(isAuthenticated, response)
                }
            }, errorHandler: { [weak self] error in
                guard let self = self else { return }
                print("❌ [WatchAuthService] Error requesting login status: \(error.localizedDescription)")
                
                // Check if we have cached tokens - if so, use them and don't retry
                let cached = self.getCachedTokens()
                if cached != nil && self.isAuthenticated {
                    print("✅ [WatchAuthService] Have cached tokens and already authenticated, using cache instead of retrying")
                    self.isCheckingAuth = false
                    DispatchQueue.main.async {
                        completion(true, cached)
                    }
                    return
                }
                
                // Only retry if session is still reachable, we haven't exceeded retry limit, and we don't have cached tokens
                if retryCount < 2 && session.isReachable && cached == nil {
                    print("🔄 [WatchAuthService] Retrying auth check (attempt \(retryCount + 1))...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.performAuthCheck(retryCount: retryCount + 1, completion: completion)
                    }
                    return
                }
                
                // Stop checking and fallback to cached tokens
                self.isCheckingAuth = false
                DispatchQueue.main.async {
                    // Fallback to cached tokens
                    let authenticated = cached != nil
                    self.isAuthenticated = authenticated
                    completion(authenticated, cached)
                }
            })
        } else {
            // Not reachable, check application context (again, in case it updated)
            print("📱 [WatchAuthService] iPhone not reachable, checking application context")
            isCheckingAuth = false
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
