//
//  AuthService.swift
//  Do
//

import Foundation
import Combine

enum AuthError: Error {
    case invalidCredentials
    case networkError
    case userNotFound
    case emailAlreadyExists
    case weakPassword
    case unknown(String)
}

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var needsPasswordChange = false
    @Published var temporaryPassword: String?
    @Published var usernameForPasswordChange: String?
    
    private let cognitoService = CognitoService.shared
    private let keychainManager = KeychainManager.shared
    
    private init() {
        checkAuthStatus()
    }
    
    // MARK: - Auth Status
    
    func checkAuthStatus() {
        print("🔐 [AuthService] checkAuthStatus() called")
        
        let token = keychainManager.get(Constants.Keychain.accessToken)
        let userId = keychainManager.get(Constants.Keychain.userId)
        
        print("🔐 [AuthService] Keychain token exists: \(token != nil)")
        print("🔐 [AuthService] Keychain userId: \(userId ?? "nil")")
        
        if let token = token, let userId = userId {
            isAuthenticated = true
            
            // Sync to UserDefaults for UserIDHelper
            UserDefaults.standard.set(userId, forKey: "cognito_user_id")
            UserDefaults.standard.set(userId, forKey: "userId")
            
            // Load basic user data immediately from UserDefaults
            var legacyUser = UserModel()
            legacyUser.userID = userId
            legacyUser.userName = UserDefaults.standard.string(forKey: "username")
            legacyUser.email = UserDefaults.standard.string(forKey: "email")
            legacyUser.name = UserDefaults.standard.string(forKey: "name")
            legacyUser.bio = UserDefaults.standard.string(forKey: "bio")
            
            print("🔐 [AuthService] Loading basic user: userID=\(userId), userName=\(legacyUser.userName ?? "nil")")
            CurrentUserService.shared.updateUser(legacyUser)
            print("🔐 [AuthService] Loaded basic user data to CurrentUserService (userID: \(userId))")
            
            // Check if we already have complete profile data before fetching
            let hasCompleteProfile = legacyUser.userName != nil && 
                                    legacyUser.email != nil && 
                                    !legacyUser.userName!.isEmpty
            
            // Only fetch if we don't have complete profile data
            if !hasCompleteProfile {
                // Fetch full user profile in background
                Task {
                    print("🔐 [AuthService] Starting background profile fetch (incomplete profile data)...")
                    await fetchOrCreateUserProfile(userId: userId)
                    print("🔐 [AuthService] Background profile fetch complete")
                }
            } else {
                print("📦 [AuthService] Using cached profile data, skipping fetch")
            }
        } else {
            print("🔐 [AuthService] No valid auth found in keychain, user not authenticated")
            isAuthenticated = false
            currentUser = nil
            CurrentUserService.shared.clearUser()
            
            // Clear UserDefaults
            UserDefaults.standard.removeObject(forKey: "cognito_user_id")
            UserDefaults.standard.removeObject(forKey: "userId")
        }
    }
    
    // MARK: - Email/Password Auth
    
    func signIn(email: String, password: String) async throws {
        print("🔐 [AuthService] signIn called")
        print("🔐 [AuthService] Email/Username: \(email)")
        
        isLoading = true
        defer { 
            isLoading = false
            print("🔐 [AuthService] isLoading set to false")
        }
        
        do {
            print("🔐 [AuthService] Calling CognitoService.signIn...")
            // CognitoService now accepts username or email
            let tokens = try await cognitoService.signIn(usernameOrEmail: email, password: password)
            print("🔐 [AuthService] Got tokens from Cognito")
            
            // Save tokens
            _ = keychainManager.save(tokens.accessToken, forKey: Constants.Keychain.accessToken)
            _ = keychainManager.save(tokens.refreshToken, forKey: Constants.Keychain.refreshToken)
            _ = keychainManager.save(tokens.idToken, forKey: Constants.Keychain.idToken)
            
            // Get user ID from token
            print("🔐 [AuthService] Decoding user ID from token...")
            let userId = try decodeUserId(from: tokens.idToken)
            print("🔐 [AuthService] User ID: \(userId)")
            _ = keychainManager.save(userId, forKey: Constants.Keychain.userId)
            
            // Also save to UserDefaults for UserIDHelper
            UserDefaults.standard.set(userId, forKey: "cognito_user_id")
            UserDefaults.standard.set(userId, forKey: "userId")
            print("🔐 [AuthService] Tokens and user ID saved to keychain and UserDefaults")
            
            // Fetch user profile (or create if doesn't exist)
            print("🔐 [AuthService] Fetching user profile...")
            await fetchOrCreateUserProfile(userId: userId)
            
            await MainActor.run {
                print("🔐 [AuthService] Setting isAuthenticated = true")
                isAuthenticated = true
                
                // Sync to CurrentUserService for legacy code
                if let currentUser = self.currentUser {
                    var legacyUser = UserModel()
                    legacyUser.userID = currentUser.id
                    legacyUser.userName = currentUser.username
                    legacyUser.email = currentUser.email
                    legacyUser.name = currentUser.name
                    legacyUser.profilePictureUrl = currentUser.profilePictureUrl
                    CurrentUserService.shared.updateUser(legacyUser)
                    print("🔐 [AuthService] Synced user to CurrentUserService")
                }
                
                print("🔐 [AuthService] Posting AuthStateChanged notification")
                NotificationCenter.default.post(name: NSNotification.Name("AuthStateChanged"), object: nil)
                print("🔐 [AuthService] Sign in complete!")
            }
        } catch let error as AuthError {
            print("🔐 [AuthService] Error during sign in: \(error)")
            
            // Check if this is a password reset required error
            if case .unknown(let message) = error, message.contains("PASSWORD_RESET_REQUIRED") {
                print("🔐 Password reset required - triggering password change flow")
                await MainActor.run {
                    self.needsPasswordChange = true
                    self.usernameForPasswordChange = email
                    self.temporaryPassword = password
                }
            }
            
            // Re-throw the error so LoginView can handle displaying it
            throw error
        } catch {
            print("🔐 [AuthService] Error during sign in: \(error)")
            throw error
        }
    }
    
    func signUp(email: String, password: String, username: String, name: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let userId = try await cognitoService.signUp(
                email: email,
                password: password,
                username: username,
                name: name
            )
            
            // Auto sign in after signup
            try await signIn(email: email, password: password)
        } catch {
            throw AuthError.emailAlreadyExists
        }
    }
    
    func forgotPassword(email: String) async throws {
        // Parameter named 'email' for backward compatibility, but accepts username too
        try await cognitoService.forgotPassword(usernameOrEmail: email)
    }
    
    func confirmForgotPassword(email: String, code: String, newPassword: String) async throws {
        // Parameter named 'email' for backward compatibility, but accepts username too
        try await cognitoService.confirmForgotPassword(
            usernameOrEmail: email,
            code: code,
            newPassword: newPassword
        )
    }
    
    // MARK: - Social Auth
    
    func signInWithApple() async throws {
        isLoading = true
        defer { isLoading = false }
        
        let (identityToken, authorizationCode) = try await AppleSignInService.shared.signIn()
        
        // Exchange Apple token with Cognito
        let tokens = try await cognitoService.signInWithApple(
            identityToken: identityToken,
            authorizationCode: authorizationCode
        )
        
        // Save tokens
        _ = keychainManager.save(tokens.accessToken, forKey: Constants.Keychain.accessToken)
        _ = keychainManager.save(tokens.refreshToken, forKey: Constants.Keychain.refreshToken)
        _ = keychainManager.save(tokens.idToken, forKey: Constants.Keychain.idToken)
        
        let userId = try decodeUserId(from: tokens.idToken)
        _ = keychainManager.save(userId, forKey: Constants.Keychain.userId)
        
        await fetchCurrentUser(userId: userId)
        
        await MainActor.run {
            isAuthenticated = true
            NotificationCenter.default.post(name: NSNotification.Name("AuthStateChanged"), object: nil)
        }
    }
    
    func signInWithGoogle() async throws {
        isLoading = true
        defer { isLoading = false }
        
        let idToken = try await GoogleSignInService.shared.signIn()
        
        // Exchange Google token with Cognito
        let tokens = try await cognitoService.signInWithGoogle(idToken: idToken)
        
        // Save tokens
        _ = keychainManager.save(tokens.accessToken, forKey: Constants.Keychain.accessToken)
        _ = keychainManager.save(tokens.refreshToken, forKey: Constants.Keychain.refreshToken)
        _ = keychainManager.save(tokens.idToken, forKey: Constants.Keychain.idToken)
        
        let userId = try decodeUserId(from: tokens.idToken)
        _ = keychainManager.save(userId, forKey: Constants.Keychain.userId)
        
        await fetchCurrentUser(userId: userId)
        
        await MainActor.run {
            isAuthenticated = true
            NotificationCenter.default.post(name: NSNotification.Name("AuthStateChanged"), object: nil)
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        keychainManager.clear()
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.isLoggedIn)
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.currentUserId)
        
        // Clear UserIDHelper keys
        UserDefaults.standard.removeObject(forKey: "cognito_user_id")
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "user_id")
        
        // Clear cached user data
        UserDefaults.standard.removeObject(forKey: "username")
        UserDefaults.standard.removeObject(forKey: "email")
        UserDefaults.standard.removeObject(forKey: "name")
        
        currentUser = nil
        isAuthenticated = false
        CurrentUserService.shared.clearUser()
        
        // Notify
        NotificationCenter.default.post(name: NSNotification.Name("AuthStateChanged"), object: nil)
        
        print("🔐 [AuthService] User signed out")
    }
    
    // MARK: - Username/Email Uniqueness
    
    func checkUsernameAvailability(username: String) async throws -> Bool {
        print("🔍 [AuthService] Checking username availability: \(username)")
        let isAvailable = try await cognitoService.checkUsernameAvailability(username: username)
        print("🔍 [AuthService] Username '\(username)' available: \(isAvailable)")
        return isAvailable
    }
    
    func checkEmailAvailability(email: String) async throws -> Bool {
        print("🔍 [AuthService] Checking email availability: \(email)")
        let isAvailable = try await cognitoService.checkEmailAvailability(email: email)
        print("🔍 [AuthService] Email '\(email)' available: \(isAvailable)")
        return isAvailable
    }
    
    // MARK: - Password Challenge
    
    func respondToNewPasswordChallenge(username: String, temporaryPassword: String, newPassword: String) async throws {
        print("🔐 [AuthService] Responding to new password challenge for: \(username)")
        
        // For now, we'll use the admin API via Lambda to set the password
        // This requires a backend Lambda function
        throw AuthError.unknown("Password challenge handling requires backend Lambda function")
    }
    
    // MARK: - Private Helpers
    
    private func fetchOrCreateUserProfile(userId: String, retryCount: Int = 0) async {
        // Prevent infinite recursion - limit retries to 1 attempt
        guard retryCount <= 1 else {
            print("❌ [AuthService] Maximum retry limit reached for fetchOrCreateUserProfile. Aborting to prevent infinite loop.")
            return
        }
        
        // Check ProfileViewModel cache first
        let cacheKey = userId
        if let cached = ProfileViewModel.getCachedProfile(for: cacheKey), !cached.isExpired {
            print("📦 [AuthService] Using cached profile from ProfileViewModel")
            await MainActor.run {
                var legacyUser = cached.profile
                CurrentUserService.shared.updateUser(legacyUser)
                
                // Save to UserDefaults for quick access
                UserDefaults.standard.set(legacyUser.userName, forKey: "username")
                UserDefaults.standard.set(legacyUser.email, forKey: "email")
                UserDefaults.standard.set(legacyUser.name, forKey: "name")
                UserDefaults.standard.set(legacyUser.bio, forKey: "bio")
                
                print("✅ [AuthService] Synced cached user to CurrentUserService: \(legacyUser.userName ?? "unknown")")
            }
            return
        }
        
        do {
            // Use ProfileAPIService instead of UserService (newer Lambda-based API)
            // Try all user IDs (Parse ID first, then Cognito ID)
            let userIdsToTry = UserIDResolver.shared.getUserIdsForDataFetch()
            
            var profileResponse: UserProfileResponse?
            var lastError: Error?
            
            for userIdToTry in userIdsToTry {
                do {
                    print("🌐 [AuthService] Trying to fetch profile with user ID: \(userIdToTry)")
                    let response = try await ProfileAPIService.shared.fetchUserProfile(
                        userId: userIdToTry,
                        currentUserId: userIdToTry,
                        includeFollowers: false,
                        includeFollowing: false
                    )
                    profileResponse = response
                    print("✅ [AuthService] Successfully fetched profile using user ID: \(userIdToTry)")
                    break
                } catch {
                    print("⚠️ [AuthService] Error fetching profile with user ID \(userIdToTry): \(error.localizedDescription)")
                    lastError = error
                    // Continue to next user ID
                }
            }
            
            guard let profileResponse = profileResponse, let userData = profileResponse.data?.user else {
                // Check if it's a 404 (user not found) before trying to create
                if let networkError = lastError as? NetworkError,
                   case .httpError(let statusCode, _) = networkError, statusCode == 404 {
                    print("⚠️ [AuthService] User profile not found (404), creating... (retryCount: \(retryCount))")
                    await createUserProfile(userId: userId, retryCount: retryCount + 1)
                } else {
                    print("⚠️ [AuthService] Error fetching user profile: \(lastError?.localizedDescription ?? "unknown") - not a 404, using cached data if available")
                    // Don't try to create if it's not a 404 - user might already exist
                    // Use cached data from CurrentUserService if available
                }
                return
            }
            
            await MainActor.run {
                // Convert ProfileAPIUser to UserModel
                var legacyUser = UserModel()
                legacyUser.userID = userData.userId
                legacyUser.userName = userData.username ?? ""
                legacyUser.email = userData.email
                legacyUser.name = userData.name
                legacyUser.bio = userData.bio
                legacyUser.profilePictureUrl = userData.profilePictureUrl
                legacyUser.privacyToggle = userData.privacyToggle
                
                // Save to UserDefaults for quick access on next launch
                UserDefaults.standard.set(legacyUser.userName, forKey: "username")
                UserDefaults.standard.set(legacyUser.email, forKey: "email")
                UserDefaults.standard.set(legacyUser.name, forKey: "name")
                UserDefaults.standard.set(legacyUser.bio, forKey: "bio")
                
                // Sync to CurrentUserService
                CurrentUserService.shared.updateUser(legacyUser)
                print("✅ [AuthService] Synced user to CurrentUserService: \(legacyUser.userName ?? "unknown")")
                
                // Cache in ProfileViewModel for future use
                ProfileViewModel.cacheProfile(
                    user: legacyUser,
                    followerCount: profileResponse.data?.followerCount ?? 0,
                    followingCount: profileResponse.data?.followingCount ?? 0,
                    isCurrentUser: true
                )
            }
            print("✅ [AuthService] User profile loaded and cached")
        } catch {
            print("⚠️ [AuthService] Unexpected error fetching user profile: \(error.localizedDescription)")
            // Use cached data from CurrentUserService if available - don't fail completely
        }
    }
    
    private func createUserProfile(userId: String, retryCount: Int = 0) async {
        // Prevent infinite recursion - limit retries to 1 attempt
        guard retryCount <= 1 else {
            print("❌ [AuthService] Maximum retry limit reached for createUserProfile. Aborting to prevent infinite loop.")
            return
        }
        
        do {
            // Get email and username from ID token (already decoded)
            guard let idToken = keychainManager.get(Constants.Keychain.idToken) else {
                print("❌ [AuthService] No ID token found")
                return
            }
            
            // Decode JWT to get email and username
            let claims = try decodeJWTClaims(from: idToken)
            let email = claims["email"] as? String ?? ""
            let username = claims["cognito:username"] as? String ?? claims["preferred_username"] as? String ?? email.components(separatedBy: "@").first ?? "user"
            let name = claims["name"] as? String
            
            print("📝 [AuthService] Creating user profile for: \(username) (\(email)) (retryCount: \(retryCount))")
            let user = try await UserService.shared.createUser(
                userId: userId,
                username: username,
                email: email,
                name: name
            )
            
            await MainActor.run {
                self.currentUser = user
                
                // Save to UserDefaults for quick access on next launch
                UserDefaults.standard.set(user.username, forKey: "username")
                UserDefaults.standard.set(user.email, forKey: "email")
                UserDefaults.standard.set(user.name, forKey: "name")
                
                // Sync to CurrentUserService for legacy code
                var legacyUser = UserModel()
                legacyUser.userID = user.id
                legacyUser.userName = user.username
                legacyUser.email = user.email
                legacyUser.name = user.name
                legacyUser.profilePictureUrl = user.profilePictureUrl
                CurrentUserService.shared.updateUser(legacyUser)
                print("✅ [AuthService] Synced new user to CurrentUserService: \(user.username)")
            }
            print("✅ [AuthService] User profile created successfully")
        } catch let error as APIError {
            // Handle specific error cases
            if case .serverError(let statusCode) = error {
                if statusCode == 403 {
                    print("⚠️ [AuthService] User creation failed with 403 - user may already exist or token invalid (retryCount: \(retryCount))")
                    // Only retry once - if we get 403 again, the user likely doesn't have permission or already exists
                    if retryCount < 1 {
                        print("⚠️ [AuthService] Attempting to fetch user profile again (retry \(retryCount + 1)/1)...")
                        // Try fetching again - user might have been created by another process
                        await fetchOrCreateUserProfile(userId: userId, retryCount: retryCount + 1)
                    } else {
                        print("❌ [AuthService] User creation failed with 403 after retry. User may not have permission or already exists. Aborting.")
                    }
                } else {
                    print("❌ [AuthService] Failed to create user profile: serverError(\(statusCode))")
                }
            } else {
                print("❌ [AuthService] Failed to create user profile: \(error)")
            }
            // Don't fail auth if profile creation fails
        } catch {
            print("❌ [AuthService] Failed to create user profile: \(error)")
            // Don't fail auth if profile creation fails
        }
    }
    
    private func decodeJWTClaims(from token: String) throws -> [String: Any] {
        let segments = token.components(separatedBy: ".")
        guard segments.count > 1 else {
            throw AuthError.unknown("Invalid token format")
        }
        
        let base64String = segments[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let padded = base64String.padding(toLength: ((base64String.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        
        guard let data = Data(base64Encoded: padded),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.unknown("Failed to decode token")
        }
        
        return json
    }
    
    private func fetchCurrentUser(userId: String) async {
        do {
            let user = try await UserService.shared.getUser(userId: userId)
            await MainActor.run {
                self.currentUser = user
                
                // Sync to CurrentUserService for legacy code
                var legacyUser = UserModel()
                legacyUser.userID = user.id
                legacyUser.userName = user.username
                legacyUser.email = user.email
                legacyUser.name = user.name
                legacyUser.profilePictureUrl = user.profilePictureUrl
                CurrentUserService.shared.updateUser(legacyUser)
                print("✅ [AuthService] Synced user to CurrentUserService")
            }
        } catch {
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
                CurrentUserService.shared.clearUser()
            }
        }
    }
    
    private func decodeUserId(from idToken: String) throws -> String {
        let segments = idToken.components(separatedBy: ".")
        guard segments.count > 1 else { throw AuthError.invalidCredentials }
        
        var base64 = segments[1]
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else {
            throw AuthError.invalidCredentials
        }
        
        return sub
    }
}

