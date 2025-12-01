//
//  GenieWatchModels.swift
//  Do Watch App
//
//  Models for interacting with Genie API on Watch
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

/// Conversation message for API requests
struct ConversationMessage: Codable {
    let role: String // "user" or "assistant"
    let text: String // Message content
}

/// Genie query request
struct GenieQueryRequest: Codable {
    let query: String
    let sessionId: String
    let timestamp: String? // ISO8601 timestamp from client
    let locale: String? // User's locale/timezone identifier
    let isVoiceInput: Bool? // Flag indicating voice input
    let latitude: Double? // User's location latitude for restaurant searches
    let longitude: Double? // User's location longitude for restaurant searches
    let conversationHistory: [ConversationMessage]? // Previous messages in the conversation
    
    init(query: String, sessionId: String, timestamp: String? = nil, locale: String? = nil, isVoiceInput: Bool = false, latitude: Double? = nil, longitude: Double? = nil, conversationHistory: [ConversationMessage]? = nil) {
        self.query = query
        self.sessionId = sessionId
        // If timestamp not provided, generate current ISO8601 timestamp
        self.timestamp = timestamp ?? ISO8601DateFormatter().string(from: Date())
        // If locale not provided, use current locale
        self.locale = locale ?? Locale.current.identifier
        self.isVoiceInput = isVoiceInput
        self.latitude = latitude
        self.longitude = longitude
        self.conversationHistory = conversationHistory
    }
}

/// Genie query response
struct GenieQueryResponse: Codable {
    let response: String
    let tokensUsed: Int
    let tokensRemaining: Int
    let tier: Int
    let handler: String?
    let title: String?
}

/// Token balance response
struct TokenBalanceResponse: Codable {
    let balance: Int
}

/// Insufficient tokens response
struct InsufficientTokensResponse: Codable {
    let error: String
    let required: Int
    let balance: Int
}
