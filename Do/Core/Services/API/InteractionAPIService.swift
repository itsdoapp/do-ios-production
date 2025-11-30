//
//  InteractionAPIService.swift
//  Do.
//
//  Handles all interaction-related API calls to AWS Lambda
//

import Foundation

class InteractionAPIService {
    static let shared = InteractionAPIService()
    
    // MARK: - Configuration
    private let batchGetURL = "https://vqklyqsiejg3tyihn52wsc7avi0zwkkf.lambda-url.us-east-1.on.aws/"
    private let createURL = "https://mjvibsi42uekzu2yf3god3j2n40hmcef.lambda-url.us-east-1.on.aws/"
    private let deleteURL = "https://qunibjtohdrirrf3wdx4cjjj7i0uaadt.lambda-url.us-east-1.on.aws/"
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Batch Get Interactions
    
    /// Fetch user's interactions for multiple posts
    func batchGetInteractions(userId: String, postIds: [String]) async throws -> [String: InteractionData] {
        guard let url = URL(string: batchGetURL) else {
            throw InteractionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "userId": userId,
            "postIds": postIds
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw InteractionError.requestFailed
        }
        
        let result = try JSONDecoder().decode(BatchInteractionsResponse.self, from: data)
        
        guard result.success else {
            throw InteractionError.apiError(result.error ?? "Unknown error")
        }
        
        return result.interactions
    }
    
    // MARK: - Create Interaction
    
    /// Create or update an interaction
    func createInteraction(userId: String, postId: String, reactionType: String) async throws -> InteractionData {
        guard let url = URL(string: createURL) else {
            throw InteractionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "userId": userId,
            "postId": postId,
            "reactionType": reactionType
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw InteractionError.requestFailed
        }
        
        let result = try JSONDecoder().decode(CreateInteractionResponse.self, from: data)
        
        guard result.success else {
            throw InteractionError.apiError(result.error ?? "Unknown error")
        }
        
        return result.interaction
    }
    
    // MARK: - Delete Interaction
    
    /// Delete an interaction
    func deleteInteraction(userId: String, postId: String) async throws {
        guard let url = URL(string: deleteURL) else {
            throw InteractionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "userId": userId,
            "postId": postId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw InteractionError.requestFailed
        }
        
        let result = try JSONDecoder().decode(DeleteInteractionResponse.self, from: data)
        
        guard result.success else {
            throw InteractionError.apiError(result.error ?? "Unknown error")
        }
    }
}

// MARK: - Response Models

struct BatchInteractionsResponse: Codable {
    let success: Bool
    let interactions: [String: InteractionData]
    let count: Int
    let error: String?
}

struct CreateInteractionResponse: Codable {
    let success: Bool
    let interaction: InteractionData
    let error: String?
}

struct DeleteInteractionResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
}

struct InteractionData: Codable {
    let interactionId: String
    let reactionType: String
    let createdAt: String
}

// MARK: - Errors

enum InteractionError: Error {
    case invalidURL
    case requestFailed
    case apiError(String)
}
