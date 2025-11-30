//
//  UserProfileService.swift
//  Do.
//
//  Service for managing user profiles in DynamoDB
//

import Foundation

class UserProfileService {
    static let shared = UserProfileService()
    
    // Using existing messaging API endpoint - update if you have a dedicated user profile endpoint
    private let baseURL = "https://m4ttou93s0.execute-api.us-east-1.amazonaws.com"
    
    private init() {}
    
    // MARK: - User Profile Management
    
    /// Create or update user profile in DynamoDB
    func saveUserProfile(_ userModel: UserModel) async throws {
        let endpoint = "\(baseURL)/users/profile"
        
        guard let url = URL(string: endpoint) else {
            throw ProfileError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Cognito token for authentication
        if let idToken = AWSCognitoAuth.shared.getIdToken() {
            request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        
        // Build profile payload
        let profileData: [String: Any] = [
            "userId": userModel.userID ?? "",
            "email": userModel.email ?? "",
            "name": userModel.name ?? "",
            "userName": userModel.userName ?? "",
            "bio": userModel.bio ?? "",
            "profilePictureUrl": userModel.profilePictureUrl ?? "",
            "birthday": userModel.birthday?.timeIntervalSince1970 ?? 0,
            "gender": userModel.gender ?? "",
            "height": userModel.height ?? 0,
            "heightUnit": userModel.heightUnit ?? "cm",
            "weight": userModel.weight ?? 0,
            "weightUnit": userModel.weightUnit ?? "kg",
            "fitnessGoals": userModel.fitnessGoals ?? [],
            
            // Federated identity
            "authProvider": userModel.authProvider ?? "cognito",
            "federatedIdentityId": userModel.federatedIdentityId ?? "",
            "appleUserIdentifier": userModel.appleUserIdentifier ?? "",
            "googleUserId": userModel.googleUserId ?? "",
            
            // Preferences
            "timezone": userModel.timezone ?? TimeZone.current.identifier,
            "language": userModel.language ?? Locale.current.languageCode ?? "en",
            "activityLevel": userModel.activityLevel ?? "moderate",
            "preferredActivities": userModel.preferredActivities ?? [],
            "units": userModel.units ?? "imperial",
            "shareProfile": userModel.shareProfile ?? true,
            "shareActivity": userModel.shareActivity ?? true,
            "onboardingCompleted": userModel.onboardingCompleted ?? false,
            
            // Genie
            "genieSubscriptionTier": userModel.genieSubscriptionTier ?? "free",
            
            // Metadata
            "lastLoginAt": Date().timeIntervalSince1970
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: profileData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ProfileError.serverError(errorMessage)
        }
        
        print("✅ [PROFILE] User profile saved successfully")
    }
    
    /// Fetch user profile by email from DynamoDB (direct query as workaround)
    func fetchUserProfileByEmail(email: String) async throws -> UserModel {
        // WORKAROUND: Query DynamoDB directly since Lambda endpoint doesn't support email lookup yet
        // TODO: Add Lambda endpoint for email lookup
        
        print("📱 [PROFILE] Querying DynamoDB for user with email: \(email)")
        
        // For now, return a basic UserModel with email
        // The actual implementation would query DynamoDB via AWS SDK or Lambda
        var user = UserModel()
        user.email = email
        
        // Try to get from UserDefaults as fallback
        if let username = UserDefaults.standard.string(forKey: "username") {
            user.userName = username
        }
        
        print("⚠️ [PROFILE] Email lookup not fully implemented - returning partial profile")
        throw ProfileError.notFound // Force fallback to Parse for now
    }
    
    /// Fetch user profile from DynamoDB using ProfileAPIService
    func fetchUserProfile(userId: String) async throws -> UserModel {
        // Use ProfileAPIService which has the correct Lambda Function URL
        let profileResponse = try await ProfileAPIService.shared.fetchUserProfile(
            userId: userId,
            currentUserId: userId,
            includeFollowers: false,
            includeFollowing: false
        )
        
        guard let userData = profileResponse.data?.user else {
            throw ProfileError.notFound
        }
        
        // Convert ProfileAPIUser to UserModel
        var user = UserModel()
        user.userID = userData.userId
        user.email = userData.email
        user.name = userData.name
        user.userName = userData.username
        user.bio = userData.bio
        user.profilePictureUrl = userData.profilePictureUrl
        user.privacyToggle = userData.privacyToggle
        
        // Load profile picture if URL is available (async)
        if let profilePicUrl = userData.profilePictureUrl, !profilePicUrl.isEmpty {
            if let image = await OptimizedMediaService.shared.loadImage(from: profilePicUrl, priority: .high) {
                user.profilePicture = image
            }
        }
        
        return user
    }
}

// MARK: - Errors

enum ProfileError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidData
    case notFound
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidData:
            return "Invalid data format"
        case .notFound:
            return "User profile not found"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
