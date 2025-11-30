//
//  AWSCognitoAuth.swift
//  Do
//
//  Adapter for GenieAPIService compatibility
//  Wraps existing AuthService and KeychainManager to provide AWSCognitoAuth interface
//

import Foundation

/// AWS Cognito authentication adapter
/// Provides compatibility interface for GenieAPIService
class AWSCognitoAuth {
    static let shared = AWSCognitoAuth()
    
    private let keychainManager = KeychainManager.shared
    private let cognitoService = CognitoService.shared
    
    private init() {}
    
    // MARK: - Token Management
    
    /// Get ID token from keychain
    func getIdToken() -> String? {
        return keychainManager.get(Constants.Keychain.idToken)
    }
    
    /// Get access token from keychain
    func getAccessToken() -> String? {
        return keychainManager.get(Constants.Keychain.accessToken)
    }
    
    /// Get refresh token from keychain
    func getRefreshToken() -> String? {
        return keychainManager.get(Constants.Keychain.refreshToken)
    }
    
    /// Refresh the current session
    func refreshToken() async throws {
        let tokens = try await cognitoService.refreshSession()
        
        // Save refreshed tokens
        _ = keychainManager.save(tokens.accessToken, forKey: Constants.Keychain.accessToken)
        _ = keychainManager.save(tokens.refreshToken, forKey: Constants.Keychain.refreshToken)
        _ = keychainManager.save(tokens.idToken, forKey: Constants.Keychain.idToken)
        
        // Sync refreshed tokens to Apple Watch
        await MainActor.run {
            CrossDeviceAuthManager.shared.syncTokensToWatch()
        }
    }
    
    // MARK: - User Info
    
    /// Get current user ID (Parse userId from custom attribute, fallback to sub)
    func getCurrentUserId() -> String? {
        // First try to get Parse userId from custom attribute
        if let parseUserId = getParseUserId() {
            return parseUserId
        }
        // Fallback to cognito_user_id in UserDefaults or keychain
        if let userId = UserDefaults.standard.string(forKey: "cognito_user_id"), !userId.isEmpty {
            return userId
        }
        return keychainManager.get(Constants.Keychain.userId)
    }
    
    /// Get Parse user ID from Cognito custom attribute
    func getParseUserId() -> String? {
        guard let idToken = getIdToken() else { return nil }
        
        // Decode JWT to get custom:parse_user_id
        let segments = idToken.components(separatedBy: ".")
        guard segments.count > 1 else { return nil }
        
        var base64 = segments[1]
        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 = base64.padding(toLength: base64.count + 4 - remainder, withPad: "=", startingAt: 0)
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let parseUserId = json["custom:parse_user_id"] as? String else {
            return nil
        }
        
        return parseUserId
    }
    
    /// Get current username
    func getCurrentUsername() -> String? {
        // Try to get from CurrentUserService
        if let username = CurrentUserService.shared.userName, !username.isEmpty {
            return username
        }
        
        // Try to decode from ID token
        guard let idToken = getIdToken() else { return nil }
        
        let segments = idToken.components(separatedBy: ".")
        guard segments.count > 1 else { return nil }
        
        var base64 = segments[1]
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 = base64.padding(toLength: base64.count + 4 - remainder, withPad: "=", startingAt: 0)
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Try different username fields
        if let username = json["cognito:username"] as? String {
            return username
        }
        if let username = json["preferred_username"] as? String {
            return username
        }
        if let email = json["email"] as? String {
            return email.components(separatedBy: "@").first
        }
        
        return nil
    }
    
    /// Check if user is authenticated
    func isAuthenticated() -> Bool {
        return getIdToken() != nil && getCurrentUserId() != nil
    }
    
    /// Check if token is expired
    func isTokenExpired() -> Bool {
        guard let idToken = getIdToken() else { return true }
        
        let segments = idToken.components(separatedBy: ".")
        guard segments.count > 1 else { return true }
        
        var base64 = segments[1]
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 = base64.padding(toLength: base64.count + 4 - remainder, withPad: "=", startingAt: 0)
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return true
        }
        
        let expirationDate = Date(timeIntervalSince1970: exp)
        return expirationDate < Date()
    }

    /// Sign the current user out
    func signOut() {
        // Clear tokens from keychain
        keychainManager.clear()
        
        // Ask AuthService to reset session state and notify observers
        // AuthService is @MainActor, so we need to call it on the main actor
        Task { @MainActor in
            AuthService.shared.signOut()
        }
        
        // Reset cached user info helpers
        CurrentUserService.shared.clearUser()
        
        print("🔐 [AWSCognitoAuth] User signed out and tokens cleared")
    }
}

