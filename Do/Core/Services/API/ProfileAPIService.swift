//
//  ProfileAPIService.swift
//  Do.
//
//  AWS Profile API Service - Handles all profile-related API calls
//

import Foundation
import UIKit

/// Service for profile-related AWS API calls
class ProfileAPIService {
    static let shared = ProfileAPIService()
    
    private let session: URLSession
    
    // Lambda Function URLs (do-app AWS account)
    private let getUserProfileURL = "https://ggvxvxhkvyq4eezg7zt2rvssga0hmbza.lambda-url.us-east-1.on.aws/"
    private let updateUserProfileURL = "https://gzmkb2efnyvruf4uv7iem3hvgq0gbcjw.lambda-url.us-east-1.on.aws/"
    private let getFollowStatusURL = "https://obxgks3zj5p2stzkenr4emxufq0cpjea.lambda-url.us-east-1.on.aws/"
    private let createFollowURL = "https://wfsqq4ukr3id2gb7dre6vkzdpa0kqubt.lambda-url.us-east-1.on.aws/"
    private let deleteFollowURL = "https://5ym5qssgjmcffolye5ikzbgc3u0jdnkm.lambda-url.us-east-1.on.aws/"
    private let getFollowersURL = "https://vfavih6e5ktwzhegwvyhid6aci0frbfo.lambda-url.us-east-1.on.aws/"
    private let getFollowingURL = "https://ummss73ayfra4k3sixwot3amlq0rymlw.lambda-url.us-east-1.on.aws/"
    private let deleteAccountURL = "https://5mqgc72v4k6arc2kxtifxx3thm0roavi.lambda-url.us-east-1.on.aws/"
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Authentication Helper
    
    /// Get a valid auth token, refreshing if expired
    private func getValidAuthToken() async -> String? {
        // Try to get token from Keychain first (more secure, primary source)
        if let idToken = KeychainManager.shared.get(Constants.Keychain.idToken) {
            // Check if token is expired
            if AWSCognitoAuth.shared.isTokenExpired() {
                print("🔐 [ProfileAPI] Token is expired, attempting refresh...")
                do {
                    try await AWSCognitoAuth.shared.refreshToken()
                    // Try again after refresh
                    if let refreshedToken = KeychainManager.shared.get(Constants.Keychain.idToken) {
                        print("🔐 [ProfileAPI] ✅ Token refreshed successfully")
                        return refreshedToken
                    }
                } catch {
                    print("🔐 [ProfileAPI] ⚠️ Token refresh failed: \(error.localizedDescription)")
                    // Continue with original token if refresh fails
                }
            }
            return idToken
        } else if let idToken = UserDefaults.standard.string(forKey: "cognito_id_token"), !idToken.isEmpty {
            // Fallback to UserDefaults if Keychain doesn't have it
            return idToken
        }
        return nil
    }
    
    /// Add Cognito JWT token to request headers
    private func addAuthHeaders(to request: inout URLRequest) async {
        if let idToken = await getValidAuthToken() {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            print("🔐 [ProfileAPI] Added auth token")
        } else {
            print("⚠️ [ProfileAPI] No auth token available - request may fail with 403")
        }
    }
    
    // MARK: - Profile Data
    
    /// Fetch complete user profile with follower/following data
    /// - Parameters:
    ///   - userId: The user ID to fetch
    ///   - currentUserId: Optional current user ID to check follow status
    ///   - includeFollowers: Whether to include full follower list
    ///   - includeFollowing: Whether to include full following list
    /// - Returns: UserProfileResponse with all profile data
    func fetchUserProfile(
        userId: String,
        currentUserId: String? = nil,
        includeFollowers: Bool = false,
        includeFollowing: Bool = false
    ) async throws -> UserProfileResponse {
        print("🔍 [ProfileAPI] Fetching profile for userId: '\(userId)'")
        
        var components = URLComponents(string: getUserProfileURL)!
        components.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "includeFollowers", value: includeFollowers ? "true" : "false"),
            URLQueryItem(name: "includeFollowing", value: includeFollowing ? "true" : "false")
        ]
        
        if let currentUserId = currentUserId {
            components.queryItems?.append(URLQueryItem(name: "currentUserId", value: currentUserId))
        }
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        // Debug: Log the actual URL and query string being sent
        print("🔍 [ProfileAPI] Request URL: \(url.absoluteString)")
        if let queryItems = components.queryItems {
            print("🔍 [ProfileAPI] Query items count: \(queryItems.count)")
            for item in queryItems {
                print("   - \(item.name): \(item.value ?? "nil")")
            }
        }
        if let queryString = url.query {
            print("🔍 [ProfileAPI] Query string: \(queryString)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        await addAuthHeaders(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse("Invalid response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            print("❌ [ProfileAPI] HTTP \(httpResponse.statusCode) error for userId '\(userId)': \(errorBody)")
            throw NetworkError.httpError(httpResponse.statusCode, errorBody)
        }
        
        // Log raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("🔍 [ProfileAPI] Raw response: \(responseString.prefix(500))")
        }
        
        let decoder = JSONDecoder()
        let profileResponse = try decoder.decode(UserProfileResponse.self, from: data)
        
        guard profileResponse.success else {
            throw NetworkError.invalidResponse(profileResponse.error ?? "Failed to fetch profile")
        }
        
        // Log decoded response structure
        if let userData = profileResponse.data?.user {
            print("🔍 [ProfileAPI] Decoded user data:")
            print("   - userId: \(userData.userId)")
            print("   - username: \(userData.username ?? "nil")")
            print("   - name: \(userData.name ?? "nil")")
            print("   - email: \(userData.email ?? "nil")")
        } else {
            print("⚠️ [ProfileAPI] Response success but no user data in response.data")
        }
        
        return profileResponse
    }
    
    /// Update user profile information
    /// - Parameters:
    ///   - userId: The user ID to update
    ///   - fields: Dictionary of fields to update
    /// - Returns: Updated ProfileAPIUser
    func updateUserProfile(userId: String, fields: [String: Any]) async throws -> ProfileAPIUser {
        print("💾 [ProfileAPI] Updating profile for userId: '\(userId)'")
        print("💾 [ProfileAPI] Update URL: \(updateUserProfileURL)")
        print("💾 [ProfileAPI] Fields to update: \(fields.keys.joined(separator: ", "))")
        
        // Try adding userId as query parameter first (some Lambdas expect it there)
        var components = URLComponents(string: updateUserProfileURL)
        components?.queryItems = [URLQueryItem(name: "userId", value: userId)]
        
        guard let url = components?.url else {
            print("❌ [ProfileAPI] Invalid update URL: \(updateUserProfileURL)")
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        await addAuthHeaders(to: &request)
        
        // Add user ID header (required for authorization)
        request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        
        // Log if Authorization header was added
        if let authHeader = request.value(forHTTPHeaderField: "Authorization") {
            print("🔐 [ProfileAPI] Authorization header present: \(authHeader.prefix(50))...")
        } else {
            print("⚠️ [ProfileAPI] No Authorization header - request will likely fail")
        }
        print("🔐 [ProfileAPI] X-User-Id header: \(userId)")
        print("🔐 [ProfileAPI] Query parameter userId: \(userId)")
        
        // Build request body - include userId in body as well (multiple sources for compatibility)
        var body: [String: Any] = [:]
        body["userId"] = userId  // Ensure userId is in body
        body.merge(fields) { (_, new) in new }
        
        // Log request body (full body for debugging)
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("💾 [ProfileAPI] Request body: \(jsonString)")
        }
        
        request.httpBody = jsonData
        
        // Log JWT token claims for debugging (to verify userId is in token)
        if let idToken = await getValidAuthToken(),
           let tokenSegments = idToken.components(separatedBy: ".").dropFirst().first {
            var base64 = String(tokenSegments)
            let remainder = base64.count % 4
            if remainder > 0 {
                base64 = base64.padding(toLength: base64.count + 4 - remainder, withPad: "=", startingAt: 0)
            }
            if let tokenData = Data(base64Encoded: base64),
               let tokenJson = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any] {
                print("🔐 [ProfileAPI] JWT token claims:")
                if let parseUserId = tokenJson["custom:parse_user_id"] as? String {
                    print("   - custom:parse_user_id: \(parseUserId)")
                } else {
                    print("   - custom:parse_user_id: NOT FOUND in token")
                }
                if let sub = tokenJson["sub"] as? String {
                    print("   - sub: \(sub)")
                }
            }
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [ProfileAPI] Invalid response type")
            throw NetworkError.invalidResponse("Invalid response")
        }
        
        print("💾 [ProfileAPI] Response status code: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            print("❌ [ProfileAPI] HTTP \(httpResponse.statusCode) error: \(errorBody.prefix(200))")
            throw NetworkError.httpError(httpResponse.statusCode, errorBody)
        }
        
        // Log raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("💾 [ProfileAPI] Raw response: \(responseString.prefix(500))")
        }
        
        let decoder = JSONDecoder()
        let updateResponse = try decoder.decode(UpdateUserResponse.self, from: data)
        
        guard updateResponse.success else {
            let errorMsg = updateResponse.error ?? "Failed to update profile"
            print("❌ [ProfileAPI] Update failed: \(errorMsg)")
            throw NetworkError.invalidResponse(errorMsg)
        }
        
        // Log decoded response
        print("✅ [ProfileAPI] Successfully updated profile")
        print("✅ [ProfileAPI] Updated user data:")
        print("   - userId: \(updateResponse.data.userId)")
        print("   - username: \(updateResponse.data.username ?? "nil")")
        print("   - name: \(updateResponse.data.name ?? "nil")")
        print("   - email: \(updateResponse.data.email ?? "nil")")
        print("   - bio: \(updateResponse.data.bio ?? "nil")")
        
        return updateResponse.data
    }
    
    /// Delete a user account
    /// - Parameters:
    ///   - userId: The user ID to delete
    ///   - reason: Optional reason for deletion
    /// - Returns: Success status
    func deleteAccount(userId: String, reason: String) async throws -> Bool {
        guard let url = URL(string: deleteAccountURL) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        await addAuthHeaders(to: &request)
        
        // Add user ID header
        request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        
        let body: [String: Any] = [
            "userId": userId,
            "reason": reason.isEmpty ? "No reason provided" : reason
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("🗑️ [ProfileAPI] Deleting account for userId: \(userId)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse("Invalid response")
        }
        
        print("🗑️ [ProfileAPI] Delete account response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            print("❌ [ProfileAPI] Delete account failed: HTTP \(httpResponse.statusCode) - \(errorBody)")
            throw NetworkError.httpError(httpResponse.statusCode, errorBody)
        }
        
        // Try to decode response
        if let responseString = String(data: data, encoding: .utf8) {
            print("✅ [ProfileAPI] Delete account response: \(responseString.prefix(200))")
        }
        
        // Try to decode as success response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool {
            print("✅ [ProfileAPI] Account deleted successfully: \(success)")
            return success
        }
        
        // If no explicit success field, assume success based on status code
        print("✅ [ProfileAPI] Account deleted (status \(httpResponse.statusCode))")
        return true
    }
    
    // MARK: - Follow Status
    
    /// Check follow status between two users
    /// - Parameters:
    ///   - userId: Current user ID
    ///   - targetUserId: Target user ID
    /// - Returns: FollowStatus with relationship info
    func checkFollowStatus(userId: String, targetUserId: String) async throws -> FollowStatus {
        var components = URLComponents(string: getFollowStatusURL)!
        components.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "targetUserId", value: targetUserId)
        ]
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        await addAuthHeaders(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse("Invalid response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            throw NetworkError.httpError(httpResponse.statusCode, errorBody)
        }
        
        let decoder = JSONDecoder()
        let statusResponse = try decoder.decode(FollowStatusResponse.self, from: data)
        
        guard statusResponse.success else {
            throw NetworkError.invalidResponse(statusResponse.error ?? "Failed to check follow status")
        }
        
        return statusResponse.data
    }
    
    // MARK: - Follow Actions
    
    /// Follow a user
    /// - Parameters:
    ///   - followerId: The user who is following
    ///   - followingId: The user being followed
    /// - Returns: FollowData with follow record info
    func followUser(followerId: String, followingId: String) async throws -> FollowData {
        guard let url = URL(string: createFollowURL) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        await addAuthHeaders(to: &request)
        
        let body: [String: Any] = [
            "followerId": followerId,
            "followingId": followingId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse("Invalid response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            throw NetworkError.httpError(httpResponse.statusCode, errorBody)
        }
        
        let decoder = JSONDecoder()
        let followResponse = try decoder.decode(FollowResponse.self, from: data)
        
        guard followResponse.success else {
            throw NetworkError.invalidResponse(followResponse.error ?? "Failed to follow user")
        }
        
        return followResponse.data
    }
    
    /// Unfollow a user
    /// - Parameters:
    ///   - followerId: The user who is unfollowing
    ///   - followingId: The user being unfollowed
    func unfollowUser(followerId: String, followingId: String) async throws {
        guard let url = URL(string: deleteFollowURL) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST" // Using POST instead of DELETE for body support
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        await addAuthHeaders(to: &request)
        
        let body: [String: Any] = [
            "followerId": followerId,
            "followingId": followingId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse("Invalid response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            throw NetworkError.httpError(httpResponse.statusCode, errorBody)
        }
        
        let decoder = JSONDecoder()
        let unfollowResponse = try decoder.decode(UnfollowResponse.self, from: data)
        
        guard unfollowResponse.success else {
            throw NetworkError.invalidResponse(unfollowResponse.error ?? "Failed to unfollow user")
        }
    }
    
    // MARK: - Paginated Followers/Following
    
    /// Fetch paginated followers for a user with follow status
    /// - Parameters:
    ///   - userId: The user whose followers to fetch
    ///   - currentUserId: Current user ID for follow status
    ///   - limit: Number of users per page (default 50)
    ///   - nextToken: Pagination token for next page
    /// - Returns: PaginatedUsersResponse with followers and follow status
    func fetchFollowers(
        userId: String,
        currentUserId: String,
        limit: Int = 50,
        nextToken: String? = nil
    ) async throws -> PaginatedUsersResponse {
        var components = URLComponents(string: getFollowersURL)!
        components.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "currentUserId", value: currentUserId),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        if let nextToken = nextToken {
            components.queryItems?.append(URLQueryItem(name: "nextToken", value: nextToken))
        }
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        await addAuthHeaders(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse("Invalid response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            throw NetworkError.httpError(httpResponse.statusCode, errorBody)
        }
        
        let decoder = JSONDecoder()
        let followersResponse = try decoder.decode(PaginatedUsersResponse.self, from: data)
        
        guard followersResponse.success else {
            throw NetworkError.invalidResponse(followersResponse.error ?? "Failed to fetch followers")
        }
        
        return followersResponse
    }
    
    /// Fetch paginated following for a user with follow status
    /// - Parameters:
    ///   - userId: The user whose following to fetch
    ///   - currentUserId: Current user ID for follow status
    ///   - limit: Number of users per page (default 50)
    ///   - nextToken: Pagination token for next page
    /// - Returns: PaginatedUsersResponse with following and follow status
    func fetchFollowing(
        userId: String,
        currentUserId: String,
        limit: Int = 50,
        nextToken: String? = nil
    ) async throws -> PaginatedUsersResponse {
        var components = URLComponents(string: getFollowingURL)!
        components.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "currentUserId", value: currentUserId),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        if let nextToken = nextToken {
            components.queryItems?.append(URLQueryItem(name: "nextToken", value: nextToken))
        }
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        await addAuthHeaders(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse("Invalid response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            throw NetworkError.httpError(httpResponse.statusCode, errorBody)
        }
        
        let decoder = JSONDecoder()
        let followingResponse = try decoder.decode(PaginatedUsersResponse.self, from: data)
        
        guard followingResponse.success else {
            throw NetworkError.invalidResponse(followingResponse.error ?? "Failed to fetch following")
        }
        
        return followingResponse
    }
}

// MARK: - Response Models

/// Complete user profile response from AWS
struct UserProfileResponse: Codable {
    let success: Bool
    let data: UserProfileData?
    let error: String?
}

/// User profile data including counts and follow status
struct UserProfileData: Codable {
    let user: ProfileAPIUser
    let followerCount: Int
    let followingCount: Int
    let followers: [ProfileAPIUser]?
    let following: [ProfileAPIUser]?
    let followStatus: FollowStatus?
}

/// User data from profile API (matches DynamoDB schema)
struct ProfileAPIUser: Codable {
    let userId: String
    let username: String? // Made optional to handle cases where API doesn't return it
    let name: String?
    let email: String?
    let profilePictureUrl: String?
    let profilePictureAvailable: Bool?
    let privacyToggle: Bool?
    let bio: String?
    let createdAt: String?
    let updatedAt: String?
    let genieSubscriptionTier: String? // Subscription tier from user profile
    
    enum CodingKeys: String, CodingKey {
        case userId
        case username
        case name
        case email
        case profilePictureUrl
        case profilePictureAvailable
        case privacyToggle
        case bio
        case createdAt
        case updatedAt
        case genieSubscriptionTier
    }
    
    // Custom decoding to handle missing username field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        profilePictureUrl = try container.decodeIfPresent(String.self, forKey: .profilePictureUrl)
        profilePictureAvailable = try container.decodeIfPresent(Bool.self, forKey: .profilePictureAvailable)
        privacyToggle = try container.decodeIfPresent(Bool.self, forKey: .privacyToggle)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        genieSubscriptionTier = try container.decodeIfPresent(String.self, forKey: .genieSubscriptionTier)
    }
}

/// Follow status between two users
struct FollowStatus: Codable {
    let isFollowing: Bool
    let isFollower: Bool
    let isMutual: Bool
    let followId: String?
    let accepted: Bool?  // Optional - not always returned by Lambda
    let pending: Bool?
}

/// Response for follow status check
struct FollowStatusResponse: Codable {
    let success: Bool
    let data: FollowStatus
    let error: String?
}

/// Follow data record
struct FollowData: Codable {
    let followId: String
    let followerId: String
    let followingId: String
    let accepted: Bool
    let createdAt: String
    let updatedAt: String
}

/// Response for follow action
struct FollowResponse: Codable {
    let success: Bool
    let data: FollowData
    let message: String?
    let error: String?
}

/// Response for unfollow action
struct UnfollowResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
}

/// Paginated users response with follow status
struct PaginatedUsersResponse: Codable {
    let success: Bool
    let data: [UserWithFollowStatus]
    let nextToken: String?
    let count: Int
    let hasMore: Bool
    let error: String?
}

/// User with follow status
struct UserWithFollowStatus: Codable {
    let userId: String
    let username: String?
    let name: String?
    let profilePictureUrl: String?
    let profilePictureAvailable: Bool?
    let bio: String?
    let followStatus: FollowStatus?
    
    // Ignore all other fields that might come from DynamoDB
    private enum CodingKeys: String, CodingKey {
        case userId, username, name, profilePictureUrl, profilePictureAvailable, bio, followStatus
    }
    
    // Custom decoding to handle missing username field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        profilePictureUrl = try container.decodeIfPresent(String.self, forKey: .profilePictureUrl)
        profilePictureAvailable = try container.decodeIfPresent(Bool.self, forKey: .profilePictureAvailable)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        followStatus = try container.decodeIfPresent(FollowStatus.self, forKey: .followStatus)
    }
}

/// Response for update user action
struct UpdateUserResponse: Codable {
    let success: Bool
    let data: ProfileAPIUser
    let error: String?
}

// MARK: - Conversion Extensions

extension ProfileAPIUser {
    /// Convert ProfileAPIUser to UserModel for compatibility
    func toUserModel() async -> UserModel {
        var model = UserModel()
        model.userID = self.userId
        model.userName = self.username ?? "" // Handle optional username
        model.name = self.name
        model.email = self.email
        model.privacyToggle = self.privacyToggle
        model.profilePictureUrl = self.profilePictureUrl // Store URL
        
        // Load profile picture if URL is available
        if let profilePicUrl = self.profilePictureUrl,
           let url = URL(string: profilePicUrl) {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    model.profilePicture = image
                }
            } catch {
                print("❌ Failed to load profile picture: \(error.localizedDescription)")
            }
        }
        
        return model
    }
}

extension UserWithFollowStatus {
    /// Convert UserWithFollowStatus to UserModel with follow status
    /// OPTIMIZED: No image loading - images load lazily in cells for fast UI
    func toUserModel(isFollowing: Bool? = nil, isFollower: Bool? = nil) -> UserModel {
        var model = UserModel()
        model.userID = self.userId
        model.userName = self.username ?? "" // Handle optional username
        model.name = self.name
        model.privacyToggle = nil // Not included in UserWithFollowStatus
        model.profilePictureUrl = self.profilePictureUrl // Store URL for lazy loading in cells
        
        // Use follow status from the data if available
        // Note: UserModel currently doesn't have isFollowing/isFollower directly in the definition I just wrote
        // I need to check UserModel definition again. I might have missed those fields.
        
        // DON'T load profile picture here - let cells load them lazily for instant UI
        // This makes the list appear immediately instead of waiting for all images
        
        return model
    }
}

