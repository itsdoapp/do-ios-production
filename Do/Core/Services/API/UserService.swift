//
//  UserService.swift
//  Do
//

import Foundation

class UserService {
    static let shared = UserService()
    private let apiClient = APIClient.shared
    
    private init() {}
    
    // MARK: - Create User
    
    struct CreateUserRequest: Encodable {
        let userId: String
        let username: String
        let email: String
        let name: String?
    }
    
    func createUser(userId: String, username: String, email: String, name: String?) async throws -> User {
        let createUserUrl = "https://4u7zzp7sbvgoidv5nrdgdrjrka0ozvcw.lambda-url.us-east-1.on.aws/"
        
        guard let url = URL(string: createUserUrl) else {
            throw APIError.invalidURL
        }
        
        let request = CreateUserRequest(
            userId: userId,
            username: username,
            email: email,
            name: name
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Cognito authentication token
        if let idToken = AWSCognitoAuth.shared.getIdToken() {
            urlRequest.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            print("🔐 [UserService] Added Authorization header for user creation")
        } else {
            print("⚠️ [UserService] No ID token available for user creation - request may fail with 403")
        }
        
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let createResponse = try decoder.decode(CreateUserResponse.self, from: data)
        
        guard createResponse.success else {
            // If creation failed, throw error with status code
            throw APIError.serverError(400)
        }
        
        return createResponse.user
    }
    
    struct CreateUserResponse: Decodable {
        let success: Bool
        let user: User
        let message: String?
        let error: String?
    }
    
    // MARK: - Get User
    
    func getUser(userId: String) async throws -> User {
        return try await apiClient.request(
            endpoint: "/users/\(userId)",
            method: .get
        )
    }
    
    func getCurrentUser() async throws -> User {
        guard let userId = KeychainManager.shared.get(Constants.Keychain.userId) else {
            throw APIError.unauthorized
        }
        return try await getUser(userId: userId)
    }
    
    // MARK: - Update User
    
    struct UserUpdate: Encodable {
        let updates: [String: AnyCodable]
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: DynamicCodingKeys.self)
            for (key, value) in updates {
                try container.encode(value, forKey: DynamicCodingKeys(stringValue: key)!)
            }
        }
        
        struct DynamicCodingKeys: CodingKey {
            var stringValue: String
            var intValue: Int?
            
            init?(stringValue: String) {
                self.stringValue = stringValue
            }
            
            init?(intValue: Int) {
                return nil
            }
        }
    }
    
    func updateUser(userId: String, updates: [String: AnyCodable]) async throws -> User {
        let updateBody = UserUpdate(updates: updates)
        return try await apiClient.request(
            endpoint: "/users/\(userId)",
            method: .put,
            body: updateBody
        )
    }
    
    // MARK: - Search Users
    
    func searchUsers(query: String, limit: Int = 20) async throws -> [User] {
        struct SearchResponse: Codable {
            let users: [User]
        }
        
        let response: SearchResponse = try await apiClient.request(
            endpoint: "/users/search?q=\(query)&limit=\(limit)",
            method: .get
        )
        
        return response.users
    }
    
    // MARK: - Follow/Unfollow
    
    func followUser(userId: String) async throws {
        try await apiClient.requestNoResponse(
            endpoint: "/users/follow",
            method: .post,
            body: ["userId": userId]
        )
    }
    
    func unfollowUser(userId: String) async throws {
        try await apiClient.requestNoResponse(
            endpoint: "/users/follow",
            method: .delete,
            body: ["userId": userId]
        )
    }
    
    func getFollowers(userId: String, limit: Int = 50) async throws -> [User] {
        struct FollowersResponse: Codable {
            let followers: [User]
        }
        
        let response: FollowersResponse = try await apiClient.request(
            endpoint: "/users/\(userId)/followers?limit=\(limit)",
            method: .get
        )
        
        return response.followers
    }
    
    func getFollowing(userId: String, limit: Int = 50) async throws -> [User] {
        struct FollowingResponse: Codable {
            let following: [User]
        }
        
        let response: FollowingResponse = try await apiClient.request(
            endpoint: "/users/\(userId)/following?limit=\(limit)",
            method: .get
        )
        
        return response.following
    }
    
    func getFollowStatus(userId: String) async throws -> Bool {
        struct FollowStatusResponse: Codable {
            let isFollowing: Bool
        }
        
        let response: FollowStatusResponse = try await apiClient.request(
            endpoint: "/users/\(userId)/follow-status",
            method: .get
        )
        
        return response.isFollowing
    }
}
