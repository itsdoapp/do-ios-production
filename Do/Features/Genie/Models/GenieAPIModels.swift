//
//  GenieAPIModels.swift
//  Do
//
//  Models used by GenieAPIService
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

/// Genie image query request
struct GenieImageQueryRequest: Codable {
    let query: String
    let sessionId: String
    let image: String // base64 encoded
    let timestamp: String? // ISO8601 timestamp from client
    let locale: String? // User's locale/timezone identifier
    let isVoiceInput: Bool? // Flag indicating voice input
    let latitude: Double? // User's location latitude for restaurant searches
    let longitude: Double? // User's location longitude for restaurant searches
    let conversationHistory: [ConversationMessage]? // Previous messages in the conversation
    
    init(query: String, sessionId: String, image: String, timestamp: String? = nil, locale: String? = nil, isVoiceInput: Bool = false, latitude: Double? = nil, longitude: Double? = nil, conversationHistory: [ConversationMessage]? = nil) {
        self.query = query
        self.sessionId = sessionId
        self.image = image
        self.timestamp = timestamp ?? ISO8601DateFormatter().string(from: Date())
        self.locale = locale ?? Locale.current.identifier
        self.isVoiceInput = isVoiceInput
        self.latitude = latitude
        self.longitude = longitude
        self.conversationHistory = conversationHistory
    }
}

/// Genie video query request
struct GenieVideoQueryRequest: Codable {
    let query: String
    let sessionId: String
    let frames: [String] // array of base64 encoded frames
    let timestamp: String? // ISO8601 timestamp from client
    let locale: String? // User's locale/timezone identifier
    let isVoiceInput: Bool? // Flag indicating voice input
    let conversationHistory: [ConversationMessage]? // Previous messages in the conversation
    
    init(query: String, sessionId: String, frames: [String], timestamp: String? = nil, locale: String? = nil, isVoiceInput: Bool = false, conversationHistory: [ConversationMessage]? = nil) {
        self.query = query
        self.sessionId = sessionId
        self.frames = frames
        self.timestamp = timestamp ?? ISO8601DateFormatter().string(from: Date())
        self.locale = locale ?? Locale.current.identifier
        self.isVoiceInput = isVoiceInput
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
    let balanceWarning: BalanceWarning?
    // New optional diagnostics
    let contextUsed: ContextUsedPayload?
    let thinking: [String]?
    // Structured analysis (when available)
    let structuredAnalysis: StructuredAnalysis?
    // Actions for multimodal features (meditation, videos, equipment, etc.)
    let actions: [GenieAction]?
    // Short title for conversation naming (generated from response)
    let title: String?
}

/// Genie action for multimodal features
struct GenieAction: Codable, Identifiable {
    var id: UUID { _id }
    private let _id: UUID
    let type: String
    let data: [String: AnyCodable]
    
    enum CodingKeys: String, CodingKey {
        case type, data
    }
    
    init(type: String, data: [String: AnyCodable]) {
        self._id = UUID()
        self.type = type
        self.data = data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self._id = UUID() // Generate new ID on decode
        self.type = try container.decode(String.self, forKey: .type)
        self.data = try container.decode([String: AnyCodable].self, forKey: .data)
    }
}

/// Structured analysis from Genie
struct StructuredAnalysis: Codable, Equatable {
    let summary: String
    let analysis: AnalysisDetails
    let recommendations: [Recommendation]
    let insights: [String]
    let dataUsed: DataUsed?
    
    struct AnalysisDetails: Codable, Equatable {
        let performance: String
        let patterns: String
        let recovery: String
    }
    
    struct Recommendation: Codable, Equatable {
        let type: String
        let action: String
    }
    
    struct DataUsed: Codable, Equatable {
        let runsAnalyzed: Int
        let dateRange: String
        let totalDistance: String
        
        enum CodingKeys: String, CodingKey {
            case runsAnalyzed = "runs_analyzed"
            case dateRange = "date_range"
            case totalDistance = "total_distance"
        }
    }
}

/// Context used payload
struct ContextUsedPayload: Codable, Equatable {
    let runs: Int?
    let workouts: Int?
    let hasStats: Bool?
}

/// Balance warning
struct BalanceWarning: Codable, Equatable {
    let level: String
    let message: String
    let recommendation: String?
    let suggestedPack: String?
    let suggestedPlan: String?
}

/// Token balance response
struct TokenBalanceResponse: Codable {
    let balance: Int
    let usage: UsageStats?
    let packages: [String: TokenPackage]?
    let subscription: SubscriptionDetails?
}

/// Usage statistics
struct UsageStats: Codable {
    let queriesThisMonth: Int?
    let tokensUsedThisMonth: Int?
    let estimatedCost: Double?
}

/// Subscription details
struct SubscriptionDetails: Codable {
    let tier: String
    let status: String
    let monthlyAllowance: Int
    let tokensUsedThisMonth: Int
    let tokensRemainingThisMonth: Int
    let topUpBalance: Int
    let currentPeriodStart: String?
    let currentPeriodEnd: String?
}

/// Token package
struct TokenPackage: Codable {
    let tokens: Int
    let price: Int
    let name: String
}

/// Payment intent response
struct PaymentIntentResponse: Codable {
    let clientSecret: String
    let package: TokenPackage
}

/// Setup intent response
struct SetupIntentResponse: Codable {
    let clientSecret: String
    let customerId: String
}

/// Subscription response
struct SubscriptionResponse: Codable {
    let subscriptionId: String?
    let clientSecret: String?
    let tier: String?
    let status: String?
    let message: String?
}

/// Cancel subscription response
struct CancelSubscriptionResponse: Codable {
    let success: Bool
    let message: String
    let cancelAtPeriodEnd: Bool?
    let currentPeriodEnd: Int?
}

/// Insufficient tokens response
struct InsufficientTokensResponse: Codable {
    let error: String
    let required: Int
    let balance: Int
    let queryType: String
    let tier: Int
    let upsell: UpsellDetails
}

/// Upsell data
struct UpsellData: Codable, Equatable {
    let error: String
    let required: Int
    let balance: Int
    let queryType: String
    let tier: Int
    let upsell: UpsellDetails
}

/// Upsell details
struct UpsellDetails: Codable, Equatable {
    let hasSubscription: Bool
    let message: String
    let recommendation: String?
    let tokenPacks: [UpsellTokenPack]
    let subscriptions: [UpsellSubscriptionOption]
}

/// Upsell token pack
struct UpsellTokenPack: Codable, Equatable {
    let id: String
    let name: String
    let tokens: Int
    let bonus: Int
    let price: Int
    let popular: Bool
}

/// Upsell subscription option
struct UpsellSubscriptionOption: Codable, Equatable {
    let id: String
    let name: String
    let tokens: Int
    let price: Int
    let perDay: Int
}

/// Meditation library response
struct MeditationLibraryResponse: Codable {
    let success: Bool
    let data: MeditationLibraryData
}

/// Meditation library data
struct MeditationLibraryData: Codable {
    let meditations: [MeditationLibraryItem]
    let featured: [MeditationLibraryItem]?
    let total: Int
}

/// Meditation library item
struct MeditationLibraryItem: Codable {
    let meditationId: String
    let category: String
    let technique: String
    let duration: Int
    let title: String
    let description: String?
    let script: String
    let tags: [String]?
    let difficulty: String?
    let createdAt: String?
    let updatedAt: String?
    let isActive: Bool?
    let featured: Bool?
    let audioUrl: String?
    let thumbnailUrl: String?
}

/// Meditation by ID response
struct MeditationByIdResponse: Codable {
    let success: Bool
    let data: MeditationLibraryItem
}

/// Subscription tier price information from backend
struct SubscriptionTierPrice: Codable {
    let tier: String
    let monthlyPrice: Double
    let annualPrice: Double
    let monthlyPriceId: String
    let annualPriceId: String
}

