import Foundation

// MARK: - Interaction Model
/// Represents a user interaction with a post (like, heart, star, goat, etc.)
public struct Interaction: Codable, Identifiable, Equatable, Hashable {
    public let id: String
    public let postId: String
    public let userId: String
    public let username: String?
    public let userProfileImageUrl: String?
    public let interactionType: InteractionType
    public let createdAt: Date
    public let notificationStatus: Bool
    
    enum CodingKeys: String, CodingKey {
        case id = "interactionId"
        case postId
        case userId
        case username
        case userProfileImageUrl
        case interactionType
        case createdAt
        case notificationStatus
    }
    
    public init(
        id: String,
        postId: String,
        userId: String,
        username: String? = nil,
        userProfileImageUrl: String? = nil,
        interactionType: InteractionType,
        createdAt: Date = Date(),
        notificationStatus: Bool = false
    ) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.username = username
        self.userProfileImageUrl = userProfileImageUrl
        self.interactionType = interactionType
        self.createdAt = createdAt
        self.notificationStatus = notificationStatus
    }
    
    public static func == (lhs: Interaction, rhs: Interaction) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Interaction Type
public enum InteractionType: String, Codable, CaseIterable {
    case heart = "heart"
    case star = "star"
    case goat = "goat"
    case party = "party"
    case clap = "clap"
    case exploding = "exploding"
    case like = "like"
    case comment = "comment"
    case share = "share"
    
    public var displayName: String {
        switch self {
        case .heart: return "Heart"
        case .star: return "Star"
        case .goat: return "GOAT"
        case .party: return "Party"
        case .clap: return "Clap"
        case .exploding: return "Exploding"
        case .like: return "Like"
        case .comment: return "Comment"
        case .share: return "Share"
        }
    }
    
    public var iconName: String {
        switch self {
        case .heart: return "fullheart_40"
        case .star: return "fullstar_40"
        case .goat: return "fullgoat_40"
        case .party: return "PartyFaceEmoji"
        case .clap: return "ClappingEmoji"
        case .exploding: return "ExplodingFaceEmoji"
        case .like: return "heart.fill"
        case .comment: return "message.fill"
        case .share: return "square.and.arrow.up"
        }
    }
}

// MARK: - Interaction Summary
/// Summary of all interactions for a post
public struct InteractionSummary: Codable, Equatable {
    public let totalCount: Int
    public let heartCount: Int
    public let starCount: Int
    public let goatCount: Int
    public let partyCount: Int
    public let clapCount: Int
    public let explodingCount: Int
    public let likeCount: Int
    public let commentCount: Int
    public let shareCount: Int
    
    /// User's own interaction with this post (if any)
    public let userInteraction: InteractionType?
    
    public init(
        totalCount: Int = 0,
        heartCount: Int = 0,
        starCount: Int = 0,
        goatCount: Int = 0,
        partyCount: Int = 0,
        clapCount: Int = 0,
        explodingCount: Int = 0,
        likeCount: Int = 0,
        commentCount: Int = 0,
        shareCount: Int = 0,
        userInteraction: InteractionType? = nil
    ) {
        self.totalCount = totalCount
        self.heartCount = heartCount
        self.starCount = starCount
        self.goatCount = goatCount
        self.partyCount = partyCount
        self.clapCount = clapCount
        self.explodingCount = explodingCount
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.shareCount = shareCount
        self.userInteraction = userInteraction
    }
    
    /// Initialize from an array of interactions
    public init(from interactions: [Interaction], currentUserId: String? = nil) {
        var heartCount = 0
        var starCount = 0
        var goatCount = 0
        var partyCount = 0
        var clapCount = 0
        var explodingCount = 0
        var likeCount = 0
        var commentCount = 0
        var shareCount = 0
        var userInteraction: InteractionType?
        
        for interaction in interactions {
            // Check if this is the current user's interaction
            if let userId = currentUserId, interaction.userId == userId {
                userInteraction = interaction.interactionType
            }
            
            // Count by type
            switch interaction.interactionType {
            case .heart: heartCount += 1
            case .star: starCount += 1
            case .goat: goatCount += 1
            case .party: partyCount += 1
            case .clap: clapCount += 1
            case .exploding: explodingCount += 1
            case .like: likeCount += 1
            case .comment: commentCount += 1
            case .share: shareCount += 1
            }
        }
        
        self.totalCount = interactions.count
        self.heartCount = heartCount
        self.starCount = starCount
        self.goatCount = goatCount
        self.partyCount = partyCount
        self.clapCount = clapCount
        self.explodingCount = explodingCount
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.shareCount = shareCount
        self.userInteraction = userInteraction
    }
    
    /// Get count for a specific interaction type
    public func count(for type: InteractionType) -> Int {
        switch type {
        case .heart: return heartCount
        case .star: return starCount
        case .goat: return goatCount
        case .party: return partyCount
        case .clap: return clapCount
        case .exploding: return explodingCount
        case .like: return likeCount
        case .comment: return commentCount
        case .share: return shareCount
        }
    }
    
    /// Get breakdown of reaction types (excluding comments/shares)
    public var reactionBreakdown: [(type: InteractionType, count: Int)] {
        let reactions: [(InteractionType, Int)] = [
            (.heart, heartCount),
            (.star, starCount),
            (.goat, goatCount),
            (.party, partyCount),
            (.clap, clapCount),
            (.exploding, explodingCount)
        ]
        return reactions.filter { $0.1 > 0 }
    }
    
    /// Total reaction count (excluding comments and shares)
    public var totalReactionCount: Int {
        return heartCount + starCount + goatCount + partyCount + clapCount + explodingCount
    }
}
