//
//  GenieConversationStoreService.swift
//  Do
//
//  AWS-backed storage service for Genie conversations and messages
//

import Foundation

/// AWS-backed storage service for Genie conversations and messages (replaces Parse)
final class GenieConversationStoreService {
    static let shared = GenieConversationStoreService()
    
    // Lambda Function URLs for Genie conversations
    private let listConversationsURL = "https://sdofux4kntgotbl2jmwxkcpfn40lojst.lambda-url.us-east-1.on.aws/"
    private let createConversationURL = "https://5djzquyjlhqeim7wnahmlcmsfi0jzyss.lambda-url.us-east-1.on.aws/"
    private let getConversationURL = "https://ckig36orcffsl46os4oq5nsa6m0lgtbp.lambda-url.us-east-1.on.aws/"
    private let deleteConversationURL = "https://oduhjur364zu6hzrrrygmvpnru0llvur.lambda-url.us-east-1.on.aws/"
    private let fetchMessagesURL = "https://mifvmlmgfr5sahatylpfhpyrv40lkidv.lambda-url.us-east-1.on.aws/"
    private let appendMessageURL = "https://knijtzmlctgjjxhlmp5iiqxuka0brnuh.lambda-url.us-east-1.on.aws/"
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Authentication Helper
    
    /// Add Cognito JWT token to request headers (optional for NONE auth endpoints)
    /// Note: Lambda Function URLs with AuthType: NONE don't require auth, but we include it for logging/tracking
    private func addAuthHeaders(to request: inout URLRequest) {
        // Make auth header optional - don't fail if token is missing
        // This prevents 403 errors when token isn't available
        if let idToken = AWSCognitoAuth.shared.getIdToken(), !idToken.isEmpty {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
    }
    
    // MARK: - Conversations
    
    /// Create a new Genie conversation
    func createConversation(title: String, ownerId: String) async throws -> GenieConversationData {
        // Check if URL is still a placeholder
        if createConversationURL.contains("placeholder") {
            print("⚠️ [ConversationStore] Endpoint not deployed yet - using placeholder URL")
            throw GenieConversationError.serverError("Endpoint not deployed")
        }
        
        guard let url = URL(string: createConversationURL) else {
            throw GenieConversationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(to: &request)
        
        let body: [String: Any] = [
            "title": title,
            "ownerId": ownerId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieConversationError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error"] as? String {
                throw GenieConversationError.serverError(errorMessage)
            }
            throw GenieConversationError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        let conversation = try JSONDecoder().decode(GenieConversationData.self, from: data)
        return conversation
    }
    
    /// List all conversations for a user
    func listConversations(ownerId: String, limit: Int = 50) async throws -> [GenieConversationData] {
        // Check if URL is still a placeholder
        if listConversationsURL.contains("placeholder") {
            print("⚠️ [ConversationStore] Endpoint not deployed yet - using placeholder URL")
            return [] // Return empty array instead of error to prevent UI hangs
        }
        
        guard let url = URL(string: listConversationsURL) else {
            throw GenieConversationError.invalidURL
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "ownerId", value: ownerId),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        guard let finalURL = components.url else {
            throw GenieConversationError.invalidURL
        }
        
        // Debug logging
        print("🔍 [ConversationStore] Fetching conversations for ownerId: \(ownerId)")
        print("🔍 [ConversationStore] URL: \(finalURL.absoluteString)")
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        addAuthHeaders(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieConversationError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            print("❌ [ConversationStore] HTTP \(httpResponse.statusCode) error: \(errorBody)")
            throw GenieConversationError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        let responseObj = try JSONDecoder().decode(GenieConversationListResponse.self, from: data)
        return responseObj.conversations
    }
    
    /// Get a single conversation by ID
    func getConversation(id: String) async throws -> GenieConversationData? {
        guard let url = URL(string: getConversationURL) else {
            throw GenieConversationError.invalidURL
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "conversationId", value: id)
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        addAuthHeaders(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieConversationError.invalidResponse
        }
        
        if httpResponse.statusCode == 404 {
            return nil
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GenieConversationError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        let conversation = try JSONDecoder().decode(GenieConversationData.self, from: data)
        return conversation
    }
    
    /// Delete a conversation
    func deleteConversation(id: String) async throws {
        guard let url = URL(string: deleteConversationURL) else {
            throw GenieConversationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addAuthHeaders(to: &request)
        
        let body: [String: Any] = [
            "conversationId": id
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieConversationError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            throw GenieConversationError.serverError("HTTP \(httpResponse.statusCode)")
        }
    }
    
    // MARK: - Messages
    
    /// Fetch messages for a conversation
    func fetchMessages(for conversationId: String, limit: Int = 100) async throws -> [GenieChatMessageData] {
        guard let url = URL(string: fetchMessagesURL) else {
            throw GenieConversationError.invalidURL
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "conversationId", value: conversationId),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        addAuthHeaders(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieConversationError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GenieConversationError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        let responseObj = try JSONDecoder().decode(GenieMessageListResponse.self, from: data)
        return responseObj.messages
    }
    
    /// Append a message to a conversation
    @discardableResult
    func appendMessage(
        to conversationId: String,
        role: String,
        text: String,
        usageJSON: String? = nil,
        model: String? = nil
    ) async throws -> GenieChatMessageData {
        guard let url = URL(string: appendMessageURL) else {
            throw GenieConversationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(to: &request)
        
        var body: [String: Any] = [
            "conversationId": conversationId,
            "role": role,
            "text": text
        ]
        if let usageJSON = usageJSON {
            body["usageJSON"] = usageJSON
        }
        if let model = model {
            body["model"] = model
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieConversationError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error"] as? String {
                throw GenieConversationError.serverError(errorMessage)
            }
            throw GenieConversationError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        let message = try JSONDecoder().decode(GenieChatMessageData.self, from: data)
        return message
    }
}

// MARK: - Data Models

struct GenieConversationData: Codable {
    let conversationId: String
    let ownerId: String
    let title: String
    let lastMessageAt: String // ISO8601
    let createdAt: String
    let updatedAt: String
}

struct GenieChatMessageData: Codable {
    let messageId: String
    let conversationId: String
    let role: String // "user" | "assistant" | "system"
    let text: String
    let usageJSON: String?
    let createdAt: String
}

struct GenieConversationListResponse: Codable {
    let conversations: [GenieConversationData]
}

struct GenieMessageListResponse: Codable {
    let messages: [GenieChatMessageData]
}

enum GenieConversationError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return message
        }
    }
}


