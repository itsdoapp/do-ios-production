//
//  FeedAPIService.swift
//  Do.
//
//  AWS Migration - Feed API Service
//  Handles all feed-related API calls to AWS Lambda functions
//

import Foundation
import UIKit

/// Service for fetching feed posts, stories, and social data from AWS
class FeedAPIService {
    static let shared = FeedAPIService()
    
    // MARK: - Configuration
    private let forYouFeedURL: String = "https://sv2ufd4we7nq6gx3wsbaz6upde0sjeay.lambda-url.us-east-1.on.aws/"
    private let followingFeedURL: String = "https://h2dyvhbkpdk35nm7py4i5r4v5a0pjxys.lambda-url.us-east-1.on.aws/"
    private let createPostURL: String = "https://kw72ntz5qh3n72mygfvyf6olwe0jbmxs.lambda-url.us-east-1.on.aws/"
    private let userPostsURL: String = "https://wlgisqyvbaz7qysm36mnbpdje40bnrmk.lambda-url.us-east-1.on.aws/"
    private let generateDeepLinkURL: String = "https://bravfrj7zpd7txwopgwggzmbu40xnbqw.lambda-url.us-east-1.on.aws/"
    private let deletePostURL: String = "https://tjilaukuoklivjpydwedxerir40tcjdq.lambda-url.us-east-1.on.aws/"
    private let hidePostURL: String = "https://molc6s6clluocc4zwgawot2y3i0fsxaw.lambda-url.us-east-1.on.aws/"
    private let archivePostURL: String = "https://si3whdyhtdlnifsz3hemcijsge0xgtoy.lambda-url.us-east-1.on.aws/"
    private let reportPostURL: String = "https://eubskipl7qy3euw5eshc5rac4m0hmxee.lambda-url.us-east-1.on.aws/"
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Posts API
    
    /// Fetch main feed posts from following users
    /// - Parameters:
    ///   - userId: Current user ID
    ///   - limit: Number of posts to fetch (default: 20)
    ///   - lastKey: Pagination key for next page
    /// - Returns: Array of Post objects
    func fetchFeedPosts(userId: String, limit: Int = 20, lastKey: String? = nil) async throws -> FeedResponse {
        var components = URLComponents(string: followingFeedURL)!
        components.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "visibility", value: "public"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let lastKey = lastKey {
            components.queryItems?.append(URLQueryItem(name: "lastKey", value: lastKey))
        }
        
        let request = try createRequest(url: components.url!)
        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let bodySnippet = String(data: data.prefix(500), encoding: .utf8) ?? "<non-utf8 body>"
            print("❌ [FeedAPI] fetchFeedPosts HTTP \(http.statusCode). Body: \(bodySnippet)")
        }

        try validateResponse(response)
        
        // Lambda returns direct response, not wrapped in APIResponse
        let decoder = JSONDecoder()
        let feedResponse = try decoder.decode(FeedResponse.self, from: data)
        
        return feedResponse
    }
    
    /// Fetch "For You" posts (personalized recommendations with ranking)
    /// Uses engagement, recency, and social signals to rank posts
    /// - Parameters:
    ///   - userId: Current user ID
    ///   - limit: Number of posts to fetch
    ///   - lastKey: Pagination key from previous response (optional)
    /// - Returns: Ranked feed response with scoring metadata and pagination token
    func fetchForYouPosts(userId: String, limit: Int = 20, lastKey: String? = nil) async throws -> ForYouFeedResponse {
        var components = URLComponents(string: forYouFeedURL)!
        components.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        if let lastKey = lastKey {
            components.queryItems?.append(URLQueryItem(name: "lastKey", value: lastKey))
        }
        
        let request = try createRequest(url: components.url!)
        let requestStartTime = Date()
        let (data, response) = try await session.data(for: request)
        let networkTime = Date().timeIntervalSince(requestStartTime)
        
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let bodySnippet = String(data: data.prefix(500), encoding: .utf8) ?? "<non-utf8 body>"
            print("❌ [FeedAPI] fetchForYouPosts HTTP \(http.statusCode). Body: \(bodySnippet)")
        }

        try validateResponse(response)
        
        let decoder = JSONDecoder()
        let feedResponse = try decoder.decode(ForYouFeedResponse.self, from: data)
        
        // Log performance metrics if available
        if let performanceMs = feedResponse.metadata?.performanceMs {
            let networkMs = Int(networkTime * 1000)
            let lambdaMs = performanceMs
            let totalMs = networkMs
            
            print("⏱ [FeedAPI] Network: \(networkMs)ms, Lambda: \(lambdaMs)ms, Total: \(totalMs)ms")
            
            // Warn if Lambda execution is slow (>2s)
            if lambdaMs > 2000 {
                print("⚠️ [FeedAPI] Lambda execution slow: \(lambdaMs)ms (expected <2000ms)")
            }
            
            // Warn if network latency is high (>1s)
            if networkMs > 1000 {
                print("⚠️ [FeedAPI] High network latency: \(networkMs)ms (likely cold start)")
            }
        }
        
        return feedResponse
    }
    
    /// Fetch chronological feed from users you follow
    /// - Parameters:
    ///   - userId: Current user ID
    ///   - limit: Number of posts to fetch
    /// - Returns: Feed response
    func fetchFollowingFeed(userId: String, limit: Int = 20) async throws -> FeedResponse {
        var components = URLComponents(string: followingFeedURL)!
        components.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        let request = try createRequest(url: components.url!)
        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let bodySnippet = String(data: data.prefix(500), encoding: .utf8) ?? "<non-utf8 body>"
            print("❌ [FeedAPI] fetchFollowingFeed HTTP \(http.statusCode). Body: \(bodySnippet)")
        }

        try validateResponse(response)
        
        let decoder = JSONDecoder()
        let feedResponse = try decoder.decode(FeedResponse.self, from: data)
        
        return feedResponse
    }
    
    // MARK: - User Profile Posts API
    
    /// Fetch posts for a specific user's profile
    /// - Parameters:
    ///   - userId: The user ID whose posts to fetch
    ///   - limit: Number of posts to fetch (default: 30 for initial load)
    ///   - lastKey: Pagination key from previous response (optional)
    /// - Returns: Tuple of (posts array, nextPageKey for pagination)
    func fetchUserPosts(userId: String, limit: Int = 30, lastKey: String? = nil) async throws -> (posts: [Post], nextKey: String?) {
        var components = URLComponents(string: userPostsURL)!
        components.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        // Lambda expects 'nextToken' parameter name, not 'lastKey'
        if let lastKey = lastKey {
            // CRITICAL: Don't URL encode base64 tokens - URLQueryItem handles encoding automatically
            // Base64 tokens contain characters like =, +, / which are valid in base64 but get encoded by URLQueryItem
            // If we double-encode, Lambda won't be able to decode it
            // URLQueryItem will automatically encode special characters, so pass raw token
            components.queryItems?.append(URLQueryItem(name: "nextToken", value: lastKey))
            print("📄 [fetchUserPosts] Sending nextToken for pagination: \(lastKey.prefix(20))... (length: \(lastKey.count))")
            print("📄 [fetchUserPosts] Token (raw): \(lastKey)")
        } else {
            print("📄 [fetchUserPosts] Initial request (no pagination token)")
        }
        
        // Log full URL for debugging (excluding sensitive data)
        if let url = components.url {
            let urlString = url.absoluteString
            // Mask the actual token value in logs
            if let tokenRange = urlString.range(of: "nextToken=") {
                let beforeToken = String(urlString[..<tokenRange.upperBound])
                print("📄 [fetchUserPosts] Request URL: \(beforeToken)[TOKEN]")
            } else {
                print("📄 [fetchUserPosts] Request URL: \(urlString)")
            }
        }
        
        let request = try createRequest(url: components.url!)
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response)
        
        // Log raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            let truncatedResponse = responseString.prefix(500)
            print("📄 [fetchUserPosts] Raw response preview: \(truncatedResponse)...")
        }
        
        let decoder = JSONDecoder()
        let userPostsResponse = try decoder.decode(UserPostsResponse.self, from: data)
        
        guard userPostsResponse.success else {
            print("❌ [fetchUserPosts] API returned success=false, error: \(userPostsResponse.error ?? "unknown")")
            throw NetworkError.invalidResponse(userPostsResponse.error ?? "Failed to fetch user posts")
        }
        
        print("📄 [fetchUserPosts] Decoded response - success: \(userPostsResponse.success), count: \(userPostsResponse.count), hasNextKey: \(userPostsResponse.nextKey != nil)")
        
        // Posts decode directly from API - no conversion needed
        let convertedPosts = userPostsResponse.data
        
        // Extract next page key if available from response
        let nextKey: String? = userPostsResponse.nextKey
        
        print("📄 [fetchUserPosts] Fetched \(convertedPosts.count) posts, nextKey: \(nextKey?.prefix(50) ?? "nil")")
        if let nextKey = nextKey {
            print("📄 [fetchUserPosts] Full nextKey length: \(nextKey.count) characters")
        }
        
        // Log first and last post IDs for debugging
        if !convertedPosts.isEmpty {
            let firstPostId = convertedPosts.first?.objectId ?? "nil"
            let lastPostId = convertedPosts.last?.objectId ?? "nil"
            print("📄 [fetchUserPosts] First post ID: \(firstPostId), Last post ID: \(lastPostId)")
        }
        
        return (convertedPosts, nextKey)
    }
    
    /// Fetch posts for the current user's own profile (convenience method)
    /// - Parameters:
    ///   - currentUserId: The current user's ID
    ///   - limit: Number of posts to fetch (default: 30)
    ///   - lastKey: Pagination key from previous response (optional)
    /// - Returns: Tuple of (posts array, nextPageKey for pagination)
    func fetchMyPosts(currentUserId: String, limit: Int = 30, lastKey: String? = nil) async throws -> (posts: [Post], nextKey: String?) {
        return try await fetchUserPosts(userId: currentUserId, limit: limit, lastKey: lastKey)
    }
    
    // MARK: - Create Post
    
    /// Create a new social post from workout share
    /// - Parameters:
    ///   - userId: User ID creating the post
    ///   - caption: Post caption/description
    ///   - postType: Type of post (workoutClassic, swimWorkoutClassic, etc)
    ///   - image: Post image to upload
    ///   - attachment: Structured post data (workout metrics, etc)
    ///   - visibility: Post visibility (public, friends, private)
    ///   - location: Optional location data
    ///   - linkedActivityId: Optional link to activity
    ///   - completion: Completion handler with result
    func createPost(
        userId: String,
        caption: String,
        postType: String,
        image: UIImage,
        attachment: [String: Any],
        visibility: String = "public",
        location: [String: Any]? = nil,
        linkedActivityId: String? = nil,
        completion: @escaping (Result<CreatePostResponse, Error>) -> Void
    ) {
        // Validate URL is configured
        guard createPostURL != "PLACEHOLDER_AFTER_DEPLOYMENT",
              let url = URL(string: createPostURL) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication
        if let token = KeychainManager.shared.get(Constants.Keychain.idToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Convert image to base64 (JPEG compression to reduce size)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NetworkError.invalidResponse("Failed to convert image")))
            return
        }
        let base64Image = imageData.base64EncodedString()
        
        // Build request body
        var body: [String: Any] = [
            "userId": userId,
            "caption": caption,
            "postType": postType,
            "mediaFile": base64Image,
            "attachment": attachment,
            "visibility": visibility
        ]
        
        if let location = location {
            body["location"] = location
        }
        
        if let activityId = linkedActivityId {
            body["linkedActivityId"] = activityId
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("📤 Creating post: \(postType) for user \(userId)")
        
        // Execute request
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Post creation error: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("❌ No data received from createPost")
                completion(.failure(NetworkError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let createResponse = try decoder.decode(CreatePostResponse.self, from: data)
                
                if createResponse.success {
                    print("✅ Post created successfully: \(createResponse.postId ?? "unknown")")
                    completion(.success(createResponse))
                } else {
                    let errorMsg = createResponse.message ?? "Failed to create post"
                    print("❌ Post creation failed: \(errorMsg)")
                    completion(.failure(NetworkError.invalidResponse(errorMsg)))
                }
            } catch {
                print("❌ Failed to decode createPost response: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Delete Post
    
    /// Delete a post from the backend
    /// - Parameters:
    ///   - postId: The post ID to delete
    ///   - userId: The user ID who owns the post (for authorization)
    /// - Returns: Success status
    func deletePost(postId: String, userId: String) async throws -> Bool {
        guard let url = URL(string: deletePostURL) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST" // Some APIs use POST for delete with body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication
        if let token = KeychainManager.shared.get(Constants.Keychain.idToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add user ID header
        request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        
        let body: [String: Any] = [
            "postId": postId,
            "userId": userId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("🗑️ [FeedAPI] Deleting post: \(postId) for user: \(userId)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse("Invalid response")
        }
        
        print("🗑️ [FeedAPI] Delete response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            print("❌ [FeedAPI] Delete post failed: HTTP \(httpResponse.statusCode) - \(errorBody)")
            throw NetworkError.httpError(httpResponse.statusCode, errorBody)
        }
        
        // Try to decode response
        if let responseString = String(data: data, encoding: .utf8) {
            print("✅ [FeedAPI] Delete response: \(responseString.prefix(200))")
        }
        
        // Try to decode as success response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool {
            print("✅ [FeedAPI] Post deleted successfully: \(success)")
            return success
        }
        
        // If no explicit success field, assume success based on status code
        print("✅ [FeedAPI] Post deleted (status \(httpResponse.statusCode))")
        return true
    }
    
    // MARK: - Hide Post
    
    /// Hide a post from the feed (removes it from view but doesn't delete)
    /// - Parameters:
    ///   - postId: The post ID to hide
    ///   - userId: The user ID who is hiding the post
    /// - Returns: Success status
    func hidePost(postId: String, userId: String) async throws -> Bool {
        guard let url = URL(string: hidePostURL) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication
        if let token = KeychainManager.shared.get(Constants.Keychain.idToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add user ID header
        request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        
        let body: [String: Any] = [
            "postId": postId,
            "userId": userId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("👁️ [FeedAPI] Hiding post: \(postId) for user: \(userId)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse("Invalid response")
        }
        
        print("👁️ [FeedAPI] Hide response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            print("❌ [FeedAPI] Hide post failed: HTTP \(httpResponse.statusCode) - \(errorBody)")
            throw NetworkError.httpError(httpResponse.statusCode, errorBody)
        }
        
        // Try to decode response
        if let responseString = String(data: data, encoding: .utf8) {
            print("✅ [FeedAPI] Hide response: \(responseString.prefix(200))")
        }
        
        // Try to decode as success response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool {
            print("✅ [FeedAPI] Post hidden successfully: \(success)")
            return success
        }
        
        // If no explicit success field, assume success based on status code
        print("✅ [FeedAPI] Post hidden (status \(httpResponse.statusCode))")
        return true
    }
    
    // MARK: - Archive Post
    
    /// Archive a post (removes it from feed but keeps it in user's archive)
    /// - Parameters:
    ///   - postId: The post ID to archive
    ///   - userId: The user ID who owns the post
    /// - Returns: Success status
    func archivePost(postId: String, userId: String) async throws -> Bool {
        guard let url = URL(string: archivePostURL) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication
        if let token = KeychainManager.shared.get(Constants.Keychain.idToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add user ID header
        request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        
        let body: [String: Any] = [
            "postId": postId,
            "userId": userId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("📦 [FeedAPI] Archiving post: \(postId) for user: \(userId)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse("Invalid response")
        }
        
        print("📦 [FeedAPI] Archive response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            print("❌ [FeedAPI] Archive post failed: HTTP \(httpResponse.statusCode) - \(errorBody)")
            throw NetworkError.httpError(httpResponse.statusCode, errorBody)
        }
        
        // Try to decode response
        if let responseString = String(data: data, encoding: .utf8) {
            print("✅ [FeedAPI] Archive response: \(responseString.prefix(200))")
        }
        
        // Try to decode as success response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool {
            print("✅ [FeedAPI] Post archived successfully: \(success)")
            return success
        }
        
        // If no explicit success field, assume success based on status code
        print("✅ [FeedAPI] Post archived (status \(httpResponse.statusCode))")
        return true
    }
    
    // MARK: - Report Post
    
    /// Report a post for inappropriate content
    /// - Parameters:
    ///   - postId: The post ID to report
    ///   - userId: The user ID who is reporting the post
    ///   - reason: Optional reason for reporting
    /// - Returns: Success status
    func reportPost(postId: String, userId: String, reason: String? = nil) async throws -> Bool {
        guard let url = URL(string: reportPostURL) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication
        if let token = KeychainManager.shared.get(Constants.Keychain.idToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add user ID header
        request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        
        var body: [String: Any] = [
            "postId": postId,
            "userId": userId
        ]
        
        if let reason = reason, !reason.isEmpty {
            body["reason"] = reason
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("🚨 [FeedAPI] Reporting post: \(postId) for user: \(userId), reason: \(reason ?? "No reason provided")")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse("Invalid response")
        }
        
        print("🚨 [FeedAPI] Report response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            print("❌ [FeedAPI] Report post failed: HTTP \(httpResponse.statusCode) - \(errorBody)")
            throw NetworkError.httpError(httpResponse.statusCode, errorBody)
        }
        
        // Try to decode response
        if let responseString = String(data: data, encoding: .utf8) {
            print("✅ [FeedAPI] Report response: \(responseString.prefix(200))")
        }
        
        // Try to decode as success response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool {
            print("✅ [FeedAPI] Post reported successfully: \(success)")
            return success
        }
        
        // If no explicit success field, assume success based on status code
        print("✅ [FeedAPI] Post reported (status \(httpResponse.statusCode))")
        return true
    }
    
    // MARK: - Helper Methods
    
    private func createRequest(url: URL, method: String = "GET") throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add AWS Cognito authentication token
        if let token = KeychainManager.shared.get(Constants.Keychain.idToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse("Invalid response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode, nil)
        }
    }

    
    // MARK: - Deep Link Generation
    
    /// Generate a signed deep link for a post
    /// Creates a secure, time-limited deep link that can be verified on the backend
    /// - Parameters:
    ///   - postId: Post ID to generate link for
    ///   - userId: Current user ID (optional, for analytics)
    /// - Returns: Signed deep link URL
    func generateSignedDeepLink(postId: String, userId: String? = nil) async throws -> String {
        // Validate URL is configured
        guard generateDeepLinkURL != "https://YOUR_DEEP_LINK_LAMBDA_URL.lambda-url.us-east-1.on.aws/",
              let url = URL(string: generateDeepLinkURL) else {
            // Fallback to direct deep link if Lambda not deployed
            return "https://itsdoapp.com/post?id=\(postId)"
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "postId", value: postId)
        ]
        
        if let userId = userId {
            components.queryItems?.append(URLQueryItem(name: "userId", value: userId))
        }
        
        var request = try createRequest(url: components.url!)
        
        // Add user ID to headers if available
        if let userId = userId ?? UserIDHelper.shared.getCurrentUserID() {
            request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        }
        
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response)
        
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse<DeepLinkResponse>.self, from: data)
        
        guard apiResponse.success, let deepLinkData = apiResponse.data else {
            // Fallback to direct deep link on error
            return "https://itsdoapp.com/post?id=\(postId)"
        }
        
        return deepLinkData.deepLink
    }
}

// MARK: - Deep Link Response

struct DeepLinkResponse: Codable {
    let deepLink: String
    let postId: String
    let expiresAt: String
    
    enum CodingKeys: String, CodingKey {
        case deepLink
        case postId
        case expiresAt
    }
}

// MARK: - Feed Response Models (matches AWS API exactly)

struct FeedResponse: Codable {
    let success: Bool
    let data: [Post]
    let count: Int
    let lastEvaluatedKey: String?
    
    enum CodingKeys: String, CodingKey {
        case success, data, count, lastEvaluatedKey
    }
}

struct ForYouFeedResponse: Codable {
    let success: Bool
    let data: [Post]
    let count: Int
    let metadata: FeedMetadata?
    let lastEvaluatedKey: String?
    
    enum CodingKeys: String, CodingKey {
        case success, data, count, metadata, lastEvaluatedKey
    }
}

struct FeedMetadata: Codable {
    let candidatesEvaluated: Int?
    let userFollowingCount: Int?
    let algorithm: String?
    let performanceMs: Int?
    let hasMore: Bool?
}

// MARK: - Generic API Response

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: String?
    let message: String?
}

// MARK: - User Posts Response
struct UserPostsResponse: Codable {
    let success: Bool
    let data: [Post]
    let count: Int
    let error: String?
    let nextKey: String? // Pagination key for next page (maps from nextToken in JSON)
    
    enum CodingKeys: String, CodingKey {
        case success
        case data
        case count
        case error
        case nextKey = "nextToken" // API returns nextToken, map to nextKey
    }
}

// MARK: - Create Post Response
struct CreatePostResponse: Codable {
    let success: Bool
    let postId: String?
    let mediaUrl: String?
    let message: String?
    let createdAt: String?
}
