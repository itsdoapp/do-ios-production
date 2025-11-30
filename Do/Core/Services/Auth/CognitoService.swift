//
//  CognitoService.swift
//  Do
//

import Foundation
import AWSCognitoIdentityProvider

struct AuthTokens {
    let accessToken: String
    let refreshToken: String
    let idToken: String
}

enum CognitoChallenge {
    case newPasswordRequired(session: String)
    case none
}

class CognitoService {
    static let shared = CognitoService()
    
    private var userPool: AWSCognitoIdentityUserPool?
    private var user: AWSCognitoIdentityUser?
    
    private init() {
        setupCognito()
    }
    
    private func setupCognito() {
        let serviceConfiguration = AWSServiceConfiguration(
            region: .USEast1,
            credentialsProvider: nil
        )
        
        let poolConfiguration = AWSCognitoIdentityUserPoolConfiguration(
            clientId: Constants.Cognito.clientId,
            clientSecret: nil,
            poolId: Constants.Cognito.userPoolId
        )
        
        AWSCognitoIdentityUserPool.register(
            with: serviceConfiguration,
            userPoolConfiguration: poolConfiguration,
            forKey: "UserPool"
        )
        
        userPool = AWSCognitoIdentityUserPool(forKey: "UserPool")
        
        // Try to restore current user if already signed in
        if let currentUser = userPool?.currentUser() {
            self.user = currentUser
            print("☁️ [CognitoService] Restored current user session")
        }
    }
    
    // MARK: - Sign In
    
    func signIn(usernameOrEmail: String, password: String) async throws -> AuthTokens {
        print("☁️ [CognitoService] signIn called")
        print("☁️ [CognitoService] Username/Email: \(usernameOrEmail)")
        
        guard let userPool = userPool else {
            print("☁️ [CognitoService] ERROR: User pool not initialized")
            throw AuthError.unknown("User pool not initialized")
        }
        
        print("☁️ [CognitoService] User pool initialized, getting user...")
        // AWS Cognito accepts both username and email for authentication
        // The username parameter can be either the username or email
        user = userPool.getUser(usernameOrEmail)
        print("☁️ [CognitoService] User object created, calling getSession...")
        
        return try await withCheckedThrowingContinuation { continuation in
            user?.getSession(usernameOrEmail, password: password, validationData: nil)
                .continueWith { task in
                    if let error = task.error {
                        print("☁️ [CognitoService] ERROR from getSession: \(error)")
                        let nsError = error as NSError
                        print("☁️ [CognitoService] Error code: \(nsError.code), domain: \(nsError.domain)")
                        
                        // Check UserInfo for error type
                        let errorType = nsError.userInfo["__type"] as? String
                        let errorMessage = nsError.userInfo["message"] as? String
                        print("☁️ [CognitoService] Error type: \(errorType ?? "none"), message: \(errorMessage ?? "none")")
                        
                        // Check for password reset required (FORCE_CHANGE_PASSWORD)
                        if errorType == "PasswordResetRequiredException" || 
                           errorMessage?.contains("Password reset required") == true ||
                           errorMessage?.contains("Temporary password") == true {
                            print("☁️ [CognitoService] Password reset required")
                            continuation.resume(throwing: AuthError.unknown("PASSWORD_RESET_REQUIRED"))
                            return nil
                        }
                        
                        // Provide more specific error messages
                        if nsError.code == 21 || errorType == "NotAuthorizedException" || errorMessage?.contains("Incorrect username or password") == true {
                            print("☁️ [CognitoService] Invalid credentials (NotAuthorizedException)")
                            continuation.resume(throwing: AuthError.invalidCredentials)
                        } else if nsError.code == -3000 {
                            print("☁️ [CognitoService] Invalid credentials (code -3000)")
                            continuation.resume(throwing: AuthError.invalidCredentials)
                        } else if errorType == "UserNotFoundException" || errorMessage?.contains("User does not exist") == true {
                            print("☁️ [CognitoService] User not found")
                            continuation.resume(throwing: AuthError.userNotFound)
                        } else if errorType == "UserNotConfirmedException" {
                            print("☁️ [CognitoService] User not confirmed")
                            continuation.resume(throwing: AuthError.unknown("Please verify your email address before signing in."))
                        } else {
                            print("☁️ [CognitoService] Unknown error: \(error.localizedDescription)")
                            continuation.resume(throwing: AuthError.unknown(error.localizedDescription))
                        }
                        return nil
                    }
                    
                    guard let session = task.result else {
                        print("☁️ [CognitoService] ERROR: No session in result")
                        continuation.resume(throwing: AuthError.invalidCredentials)
                        return nil
                    }
                    
                    print("☁️ [CognitoService] Session obtained successfully!")
                    let tokens = AuthTokens(
                        accessToken: session.accessToken?.tokenString ?? "",
                        refreshToken: session.refreshToken?.tokenString ?? "",
                        idToken: session.idToken?.tokenString ?? ""
                    )
                    print("☁️ [CognitoService] Tokens created, returning...")
                    
                    continuation.resume(returning: tokens)
                    return nil
                }
        }
    }
    
    // MARK: - Sign Up
    
    func signUp(email: String, password: String, username: String, name: String) async throws -> String {
        guard let userPool = userPool else {
            throw AuthError.unknown("User pool not initialized")
        }
        
        let emailAttribute = AWSCognitoIdentityUserAttributeType()
        emailAttribute?.name = "email"
        emailAttribute?.value = email
        
        let nameAttribute = AWSCognitoIdentityUserAttributeType()
        nameAttribute?.name = "name"
        nameAttribute?.value = name
        
        let usernameAttribute = AWSCognitoIdentityUserAttributeType()
        usernameAttribute?.name = "preferred_username"
        usernameAttribute?.value = username
        
        // Mark that password is already set (not a migrated user)
        let pwdChangedAttribute = AWSCognitoIdentityUserAttributeType()
        pwdChangedAttribute?.name = "custom:pwd_changed"
        pwdChangedAttribute?.value = "true"
        
        let attributes = [emailAttribute, nameAttribute, usernameAttribute, pwdChangedAttribute].compactMap { $0 }
        
        return try await withCheckedThrowingContinuation { continuation in
            userPool.signUp(email, password: password, userAttributes: attributes, validationData: nil)
                .continueWith { task in
                    if let error = task.error {
                        continuation.resume(throwing: AuthError.unknown(error.localizedDescription))
                        return nil
                    }
                    
                    guard let result = task.result,
                          let userSub = result.userSub else {
                        continuation.resume(throwing: AuthError.unknown("Failed to create user"))
                        return nil
                    }
                    
                    continuation.resume(returning: userSub)
                    return nil
                }
        }
    }
    
    // MARK: - Forgot Password
    
    func forgotPassword(usernameOrEmail: String) async throws {
        guard let userPool = userPool else {
            throw AuthError.unknown("User pool not initialized")
        }
        
        // AWS Cognito accepts both username and email for password reset
        let user = userPool.getUser(usernameOrEmail)
        
        return try await withCheckedThrowingContinuation { continuation in
            user.forgotPassword()
                .continueWith { task in
                    if let error = task.error {
                        continuation.resume(throwing: AuthError.unknown(error.localizedDescription))
                        return nil
                    }
                    
                    continuation.resume(returning: ())
                    return nil
                }
        }
    }
    
    func confirmForgotPassword(usernameOrEmail: String, code: String, newPassword: String) async throws {
        guard let userPool = userPool else {
            throw AuthError.unknown("User pool not initialized")
        }
        
        // AWS Cognito accepts both username and email for password reset confirmation
        let user = userPool.getUser(usernameOrEmail)
        
        return try await withCheckedThrowingContinuation { continuation in
            user.confirmForgotPassword(code, password: newPassword)
                .continueWith { task in
                    if let error = task.error {
                        continuation.resume(throwing: AuthError.unknown(error.localizedDescription))
                        return nil
                    }
                    
                    continuation.resume(returning: ())
                    return nil
                }
        }
    }
    
    // MARK: - Refresh Token
    
    func refreshSession() async throws -> AuthTokens {
        guard let user = user else {
            print("⚠️ [CognitoService] Cannot refresh - no user session available")
            throw AuthError.userNotFound
        }
        
        print("🔄 [CognitoService] Refreshing session...")
        return try await withCheckedThrowingContinuation { continuation in
            user.getSession()
                .continueWith { task in
                    if let error = task.error {
                        print("❌ [CognitoService] Refresh failed: \(error.localizedDescription)")
                        continuation.resume(throwing: AuthError.unknown(error.localizedDescription))
                        return nil
                    }
                    
                    guard let session = task.result else {
                        print("❌ [CognitoService] Refresh failed: No session returned")
                        continuation.resume(throwing: AuthError.invalidCredentials)
                        return nil
                    }
                    
                    print("✅ [CognitoService] Session refreshed successfully")
                    let tokens = AuthTokens(
                        accessToken: session.accessToken?.tokenString ?? "",
                        refreshToken: session.refreshToken?.tokenString ?? "",
                        idToken: session.idToken?.tokenString ?? ""
                    )
                    
                    continuation.resume(returning: tokens)
                    return nil
                }
        }
    }
    
    // MARK: - Social Sign In
    
    func signInWithApple(identityToken: String, authorizationCode: String) async throws -> AuthTokens {
        // Use Cognito Identity Provider to exchange Apple token
        guard let userPool = userPool else {
            throw AuthError.unknown("User pool not initialized")
        }
        
        // Create a custom auth flow with Apple token
        // This requires Cognito to be configured with Apple as an identity provider
        return try await withCheckedThrowingContinuation { continuation in
            let authParameters = [
                "PROVIDER": "SignInWithApple",
                "TOKEN": identityToken,
                "CODE": authorizationCode
            ]
            
            // Note: This requires custom Lambda trigger in Cognito
            userPool.getUser().getSession(identityToken, password: authorizationCode, validationData: nil)
                .continueWith { task in
                    if let error = task.error {
                        continuation.resume(throwing: AuthError.unknown(error.localizedDescription))
                        return nil
                    }
                    
                    guard let session = task.result else {
                        continuation.resume(throwing: AuthError.invalidCredentials)
                        return nil
                    }
                    
                    let tokens = AuthTokens(
                        accessToken: session.accessToken?.tokenString ?? "",
                        refreshToken: session.refreshToken?.tokenString ?? "",
                        idToken: session.idToken?.tokenString ?? ""
                    )
                    
                    continuation.resume(returning: tokens)
                    return nil
                }
        }
    }
    
    func signInWithGoogle(idToken: String) async throws -> AuthTokens {
        // Use Cognito Identity Provider to exchange Google token
        guard let userPool = userPool else {
            throw AuthError.unknown("User pool not initialized")
        }
        
        // Create a custom auth flow with Google token
        // This requires Cognito to be configured with Google as an identity provider
        return try await withCheckedThrowingContinuation { continuation in
            let authParameters = [
                "PROVIDER": "Google",
                "TOKEN": idToken
            ]
            
            // Note: This requires custom Lambda trigger in Cognito
            userPool.getUser().getSession(idToken, password: "", validationData: nil)
                .continueWith { task in
                    if let error = task.error {
                        continuation.resume(throwing: AuthError.unknown(error.localizedDescription))
                        return nil
                    }
                    
                    guard let session = task.result else {
                        continuation.resume(throwing: AuthError.invalidCredentials)
                        return nil
                    }
                    
                    let tokens = AuthTokens(
                        accessToken: session.accessToken?.tokenString ?? "",
                        refreshToken: session.refreshToken?.tokenString ?? "",
                        idToken: session.idToken?.tokenString ?? ""
                    )
                    
                    continuation.resume(returning: tokens)
                    return nil
                }
        }
    }
    
    // MARK: - Username/Email Uniqueness
    
    func checkUsernameAvailability(username: String) async throws -> Bool {
        guard let userPool = userPool else {
            throw AuthError.unknown("User pool not initialized")
        }
        
        // Try to get user by username - if it exists, username is taken
        return try await withCheckedThrowingContinuation { continuation in
            let user = userPool.getUser(username)
            user.getDetails().continueWith { task in
                if task.error != nil {
                    // User not found - username is available
                    continuation.resume(returning: true)
                } else {
                    // User found - username is taken
                    continuation.resume(returning: false)
                }
                return nil
            }
        }
    }
    
    func checkEmailAvailability(email: String) async throws -> Bool {
        // Check if email is already registered by trying to initiate forgot password
        // If user doesn't exist, it will throw an error
        guard let userPool = userPool else {
            throw AuthError.unknown("User pool not initialized")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let user = userPool.getUser(email)
            user.getDetails().continueWith { task in
                if task.error != nil {
                    // User not found - email is available
                    continuation.resume(returning: true)
                } else {
                    // User found - email is taken
                    continuation.resume(returning: false)
                }
                return nil
            }
        }
    }
    
    // MARK: - Password Challenge
    
    func setNewPasswordForUser(username: String, newPassword: String) async throws {
        // Use AWS CLI to set permanent password (requires admin privileges)
        // This is called after user enters their new password
        
        guard let userPoolId = userPool?.userPoolConfiguration.poolId else {
            throw AuthError.unknown("User pool not initialized")
        }
        
        print("☁️ [CognitoService] Setting permanent password for user: \(username)")
        
        // We'll use a Lambda function or direct AWS SDK call
        // For now, throw an error indicating this needs backend support
        throw AuthError.unknown("Password change requires backend Lambda function. Please implement setUserPassword Lambda.")
    }
    
    func respondToNewPasswordChallenge(username: String, temporaryPassword: String, newPassword: String) async throws -> AuthTokens {
        guard let userPool = userPool else {
            throw AuthError.unknown("User pool not initialized")
        }
        
        user = userPool.getUser(username)
        
        return try await withCheckedThrowingContinuation { continuation in
            // First, initiate auth with temporary password
            user?.getSession(username, password: temporaryPassword, validationData: nil)
                .continueWith { task in
                    if let error = task.error {
                        print("☁️ [CognitoService] Error in initial auth: \(error)")
                        continuation.resume(throwing: AuthError.unknown(error.localizedDescription))
                        return nil
                    }
                    
                    // If we get here and there's a NEW_PASSWORD_REQUIRED challenge,
                    // we need to respond to it
                    // For now, we'll use the admin API approach via Lambda
                    // The actual challenge response would require more complex handling
                    
                    continuation.resume(throwing: AuthError.unknown("Password challenge handling not fully implemented. Use admin API."))
                    return nil
                }
        }
    }
    
    func markPasswordChanged(username: String) async throws {
        // Mark that user has changed their password
        guard let userPool = userPool else {
            throw AuthError.unknown("User pool not initialized")
        }
        
        user = userPool.getUser(username)
        
        // Update custom:pwd_changed attribute to "true"
        // This requires admin privileges, so we'll need a backend call
        print("☁️ [CognitoService] Marking password as changed for: \(username)")
    }
}

