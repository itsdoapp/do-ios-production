//
//  Post.swift
//  Do
//
//  Post data model for SwiftUI (matches Do. PostModel)
//

import Foundation
import UIKit

public struct Post: Codable, Equatable, Hashable, Identifiable {
    public var id: String { objectId ?? UUID().uuidString }
    
    public static func == (lhs: Post, rhs: Post) -> Bool {
        return lhs.objectId == rhs.objectId
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(objectId)
    }
    
    // Core properties (from AWS API)
    var objectId: String? // Maps from postId
    var createdBy: UserModel?
    var postCaption: String? // Maps from caption
    var dateLabelString: String? // Computed from createdAt
    
    // Computed property to get formatted timestamp, with fallback
    var formattedTimestamp: String {
        // If dateLabelString exists and is valid, use it
        if let dateString = dateLabelString, dateString != "Just now", !dateString.isEmpty {
            return dateString
        }
        
        // Try to parse createdAt if dateLabelString is missing or invalid
        if let createdAtString = createdAt, !createdAtString.isEmpty {
            #if DEBUG
            print("🕐 [Post] Parsing createdAt: \(createdAtString)")
            #endif
            
            // Try ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: createdAtString) {
                let result = date.timeAgoSinceDateForPost()
                #if DEBUG
                print("🕐 [Post] Parsed date successfully: \(result)")
                #endif
                return result
            }
            
            // Try ISO8601 without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: createdAtString) {
                let result = date.timeAgoSinceDateForPost()
                #if DEBUG
                print("🕐 [Post] Parsed date successfully (no fractional): \(result)")
                #endif
                return result
            }
            
            // Try standard date formatter as fallback
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            if let date = dateFormatter.date(from: createdAtString) {
                let result = date.timeAgoSinceDateForPost()
                #if DEBUG
                print("🕐 [Post] Parsed date successfully (standard format): \(result)")
                #endif
                return result
            }
            
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if let date = dateFormatter.date(from: createdAtString) {
                let result = date.timeAgoSinceDateForPost()
                #if DEBUG
                print("🕐 [Post] Parsed date successfully (standard format no ms): \(result)")
                #endif
                return result
            }
            
            #if DEBUG
            print("⚠️ [Post] Failed to parse createdAt: \(createdAtString)")
            #endif
        } else {
            #if DEBUG
            print("⚠️ [Post] createdAt is nil or empty for postId: \(objectId ?? "unknown")")
            #endif
        }
        
        return "Just now"
    }
    var media: UIImage? // Not from API - loaded separately
    
    // Media URLs for different sizes
    var mediaUrl: String?
    var mediaUrlThumb: String?
    var mediaUrlMedium: String?
    var mediaUrlLarge: String?
    var mediaUrlOriginal: String?
    
    // Media dimensions
    var mediaWidth: CGFloat?
    var mediaHeight: CGFloat?
    
    // Interactions
    var whoGoated: [UserModel]?
    var whoHearted: [UserModel]?
    var whoStarred: [UserModel]?
    var starFlag: Bool?
    var heartFlag: Bool?
    var goatFlag: Bool?
    var interactionFlag: Bool?
    var reactionCount: Int?
    var goats: Int // Maps from goatCount
    var hearts: Int // Maps from heartCount
    var stars: Int // Maps from starCount
    var postType: String?
    var postInteractions: [Interaction]?
    var showInteractionCount: Bool?
    var attachment: [String: Any]? // From activitySnapshot or workoutSnapshot
    var interactionCount: Int?
    var commentCount: Int?
    
    // Workout/Activity references
    var workoutId: String?
    var workoutType: String? // "session" | "plan" | "movement"
    var activityId: String?
    var activityType: String? // "run" | "bike" | "hike" | "swim" | "walk"
    
    // Route/Location data (for locationActivity posts)
    var routeDataUrl: String? // S3 URL for full route data
    var routeDataS3Key: String? // S3 key for route data
    var routePolyline: String? // Encoded polyline for quick preview
    var mapPreviewUrl: String? // Static map image URL
    
    // Privacy settings
    var visibility: String? // "public", "followers", "private"
    
    // AWS API fields (for decoding)
    private let postId: String?
     let userId: String?
    private let caption: String?
    public let createdAt: String?
    private let updatedAt: String?
    private let goatCount: Int?
    private let heartCount: Int?
    private let starCount: Int?
    private let activitySnapshotRaw: String?
    private let workoutSnapshotRaw: String?
    private let user: PostUser?
    private let interactions: [PostInteraction]?
    
    enum CodingKeys: String, CodingKey {
        case postId, userId, postType, caption
        case mediaUrl, mediaUrlThumb, mediaUrlMedium, mediaUrlLarge, mediaUrlOriginal
        case interactionCount, goatCount, heartCount, starCount, commentCount
        case visibility, createdAt, updatedAt
        case user, interactions
        case activityId, activityType, workoutId, workoutType
        case activitySnapshotRaw = "activitySnapshot"
        case workoutSnapshotRaw = "workoutSnapshot"
        case routeDataUrl, routeDataS3Key, routePolyline, mapPreviewUrl
    }
    
    // Custom decoder to map AWS API to Post structure
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode AWS fields
        postId = try container.decodeIfPresent(String.self, forKey: .postId)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        postType = try container.decodeIfPresent(String.self, forKey: .postType)
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
        
        mediaUrl = try container.decodeIfPresent(String.self, forKey: .mediaUrl)
        mediaUrlThumb = try container.decodeIfPresent(String.self, forKey: .mediaUrlThumb)
        mediaUrlMedium = try container.decodeIfPresent(String.self, forKey: .mediaUrlMedium)
        mediaUrlLarge = try container.decodeIfPresent(String.self, forKey: .mediaUrlLarge)
        mediaUrlOriginal = try container.decodeIfPresent(String.self, forKey: .mediaUrlOriginal)
        
        interactionCount = try container.decodeIfPresent(Int.self, forKey: .interactionCount)
        goatCount = try container.decodeIfPresent(Int.self, forKey: .goatCount)
        heartCount = try container.decodeIfPresent(Int.self, forKey: .heartCount)
        starCount = try container.decodeIfPresent(Int.self, forKey: .starCount)
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount)
        
        visibility = try container.decodeIfPresent(String.self, forKey: .visibility)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        
        activityId = try container.decodeIfPresent(String.self, forKey: .activityId)
        activityType = try container.decodeIfPresent(String.self, forKey: .activityType)
        workoutId = try container.decodeIfPresent(String.self, forKey: .workoutId)
        workoutType = try container.decodeIfPresent(String.self, forKey: .workoutType)
        
        activitySnapshotRaw = try container.decodeIfPresent(String.self, forKey: .activitySnapshotRaw)
        workoutSnapshotRaw = try container.decodeIfPresent(String.self, forKey: .workoutSnapshotRaw)
        
        // Route/Location data
        routeDataUrl = try container.decodeIfPresent(String.self, forKey: .routeDataUrl)
        routeDataS3Key = try container.decodeIfPresent(String.self, forKey: .routeDataS3Key)
        routePolyline = try container.decodeIfPresent(String.self, forKey: .routePolyline)
        mapPreviewUrl = try container.decodeIfPresent(String.self, forKey: .mapPreviewUrl)
        
        user = try container.decodeIfPresent(PostUser.self, forKey: .user)
        interactions = try container.decodeIfPresent([PostInteraction].self, forKey: .interactions)
        
        // Map to Post structure
        objectId = postId
        postCaption = caption
        
        // Map counts
        goats = goatCount ?? 0
        hearts = heartCount ?? 0
        stars = starCount ?? 0
        
        // Parse attachment from snapshots
        if let snapshot = activitySnapshotRaw,
           let data = snapshot.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            attachment = json
            
            // Extract route data from attachment if not already set
            if routeDataUrl == nil, let url = json["routeDataUrl"] as? String {
                routeDataUrl = url
            }
            if routeDataS3Key == nil, let key = json["routeDataS3Key"] as? String {
                routeDataS3Key = key
            }
            if routePolyline == nil, let polyline = json["routePolyline"] as? String {
                routePolyline = polyline
            }
            if mapPreviewUrl == nil, let preview = json["mapPreviewUrl"] as? String {
                mapPreviewUrl = preview
            }
        } else if let snapshot = workoutSnapshotRaw,
                  let data = snapshot.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            attachment = json
            
            // Extract route data from attachment if not already set
            if routeDataUrl == nil, let url = json["routeDataUrl"] as? String {
                routeDataUrl = url
            }
            if routeDataS3Key == nil, let key = json["routeDataS3Key"] as? String {
                routeDataS3Key = key
            }
            if routePolyline == nil, let polyline = json["routePolyline"] as? String {
                routePolyline = polyline
            }
            if mapPreviewUrl == nil, let preview = json["mapPreviewUrl"] as? String {
                mapPreviewUrl = preview
            }
        }
        
        // Convert user
        if let postUser = user {
            var userModel = UserModel()
            userModel.userID = postUser.userId
            userModel.userName = postUser.username
            userModel.name = postUser.name
            userModel.profilePictureUrl =
                postUser.profilePictureUrl ??
                postUser.profilePictureUrlLarge ??
                postUser.profilePictureUrlMedium ??
                postUser.profilePictureUrlThumb
            userModel.followerCount = postUser.followerCount
            userModel.followingCount = postUser.followingCount
            createdBy = userModel
        } else {
            // User info not in API response - will be attached later if needed (e.g., in ProfileViewModel)
            // This is expected when fetching posts for a specific user (user info not duplicated in each post)
            // No warning needed - user info will be attached in ProfileViewModel if needed
        }
        
        // Parse date
        if let dateString = createdAt {
           
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let date = formatter.date(from: dateString) {
                dateLabelString = date.timeAgoSinceDateForPost()
                
            } else {
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) {
                    dateLabelString = date.timeAgoSinceDateForPost()
                   
                } else {
                    dateLabelString = "Just now"
                    #if DEBUG
                    print("⚠️ [Post Decoder] Failed to parse createdAt, setting to 'Just now'")
                    #endif
                }
            }
        } else {
            #if DEBUG
            print("⚠️ [Post Decoder] createdAt is nil for postId: \(postId ?? "unknown")")
            #endif
            dateLabelString = "Just now"
        }
        
        // Convert interactions
        if let postInteractions = interactions {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            self.postInteractions = postInteractions.compactMap { postInteraction in
                guard let interactionType = InteractionType(rawValue: postInteraction.reactionType) else {
                    return nil
                }
                
                let date: Date
                if let parsedDate = formatter.date(from: postInteraction.createdAt) {
                    date = parsedDate
                } else {
                    formatter.formatOptions = [.withInternetDateTime]
                    date = formatter.date(from: postInteraction.createdAt) ?? Date()
                }
                
                return Interaction(
                    id: postInteraction.interactionId,
                    postId: postInteraction.postId,
                    userId: postInteraction.userId,
                    username: user?.username,
                    userProfileImageUrl: user?.profilePictureUrl,
                    interactionType: interactionType,
                    createdAt: date,
                    notificationStatus: false
                )
            }
            
            // Calculate counts from interactions if API didn't provide them or they're 0
            // This ensures counts are always accurate even if Lambda doesn't return them
            if let interactions = self.postInteractions, (goatCount == nil || goatCount == 0 || heartCount == nil || heartCount == 0 || starCount == nil || starCount == 0) {
                var calculatedHearts = 0
                var calculatedStars = 0
                var calculatedGoats = 0
                
                for interaction in interactions {
                    switch interaction.interactionType {
                    case .heart:
                        calculatedHearts += 1
                    case .star:
                        calculatedStars += 1
                    case .goat:
                        calculatedGoats += 1
                    default:
                        break
                    }
                }
                
                // Use calculated counts if API counts are missing or 0
                if heartCount == nil || heartCount == 0 {
                    hearts = calculatedHearts
                }
                if starCount == nil || starCount == 0 {
                    stars = calculatedStars
                }
                if goatCount == nil || goatCount == 0 {
                    goats = calculatedGoats
                }
                
                #if DEBUG
                if calculatedHearts > 0 || calculatedStars > 0 || calculatedGoats > 0 {
                    print("📊 [Post] Calculated counts from interactions - hearts: \(calculatedHearts), stars: \(calculatedStars), goats: \(calculatedGoats)")
                }
                #endif
            }
        }
        
        // Initialize other properties
        media = nil
        mediaWidth = nil
        mediaHeight = nil
        whoGoated = nil
        whoHearted = nil
        whoStarred = nil
        starFlag = nil
        heartFlag = nil
        goatFlag = nil
        interactionFlag = nil
        reactionCount = nil
        showInteractionCount = nil
        // routeDataUrl, routeDataS3Key, routePolyline, mapPreviewUrl are already set above
    }
    
    // Custom encoder (for caching, etc.)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(objectId, forKey: .postId)
        try container.encodeIfPresent(createdBy?.userID, forKey: .userId)
        try container.encodeIfPresent(postType, forKey: .postType)
        try container.encodeIfPresent(postCaption, forKey: .caption)
        try container.encodeIfPresent(mediaUrl, forKey: .mediaUrl)
        try container.encodeIfPresent(mediaUrlThumb, forKey: .mediaUrlThumb)
        try container.encodeIfPresent(mediaUrlMedium, forKey: .mediaUrlMedium)
        try container.encodeIfPresent(mediaUrlLarge, forKey: .mediaUrlLarge)
        try container.encodeIfPresent(mediaUrlOriginal, forKey: .mediaUrlOriginal)
        try container.encodeIfPresent(interactionCount, forKey: .interactionCount)
        try container.encodeIfPresent(goats, forKey: .goatCount)
        try container.encodeIfPresent(hearts, forKey: .heartCount)
        try container.encodeIfPresent(stars, forKey: .starCount)
        try container.encodeIfPresent(commentCount, forKey: .commentCount)
        try container.encodeIfPresent(visibility, forKey: .visibility)
        try container.encodeIfPresent(activityId, forKey: .activityId)
        try container.encodeIfPresent(activityType, forKey: .activityType)
        try container.encodeIfPresent(workoutId, forKey: .workoutId)
        try container.encodeIfPresent(workoutType, forKey: .workoutType)
        try container.encodeIfPresent(routeDataUrl, forKey: .routeDataUrl)
        try container.encodeIfPresent(routeDataS3Key, forKey: .routeDataS3Key)
        try container.encodeIfPresent(routePolyline, forKey: .routePolyline)
        try container.encodeIfPresent(mapPreviewUrl, forKey: .mapPreviewUrl)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        
        // Preserve snapshot payloads for classic & location cells
        if let rawWorkoutSnapshot = workoutSnapshotRaw, rawWorkoutSnapshot.isEmpty == false {
            try container.encode(rawWorkoutSnapshot, forKey: .workoutSnapshotRaw)
        }
        
        if let rawActivitySnapshot = activitySnapshotRaw, rawActivitySnapshot.isEmpty == false {
            try container.encode(rawActivitySnapshot, forKey: .activitySnapshotRaw)
        }
        
        if workoutSnapshotRaw == nil, activitySnapshotRaw == nil,
           let attachmentSnapshot = serializedAttachmentSnapshot(), attachmentSnapshot.isEmpty == false {
            let isWorkoutPost = (postType?.lowercased().contains("workout") ?? false)
            if isWorkoutPost {
                try container.encode(attachmentSnapshot, forKey: .workoutSnapshotRaw)
            } else {
                try container.encode(attachmentSnapshot, forKey: .activitySnapshotRaw)
            }
        }
        
        if let createdBy = createdBy,
           let userId = createdBy.userID {
            let cacheUser = PostUser(
                userId: userId,
                username: createdBy.userName ?? "",
                name: createdBy.name,
                email: createdBy.email,
                profilePictureUrl: createdBy.profilePictureUrl,
                profilePictureUrlThumb: createdBy.profilePictureUrl,
                profilePictureUrlMedium: createdBy.profilePictureUrl,
                profilePictureUrlLarge: createdBy.profilePictureUrl,
                followerCount: createdBy.followerCount,
                followingCount: createdBy.followingCount,
                isVerified: nil
            )
            try container.encode(cacheUser, forKey: .user)
        }
    }
    
    private func serializedAttachmentSnapshot() -> String? {
        guard let attachment = attachment,
              JSONSerialization.isValidJSONObject(attachment),
              let data = try? JSONSerialization.data(withJSONObject: attachment, options: []),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }
    
    // Empty initializer for manual creation
    public init() {
        objectId = nil
        createdBy = nil
        postCaption = nil
        dateLabelString = nil
        media = nil
        mediaUrl = nil
        mediaUrlThumb = nil
        mediaUrlMedium = nil
        mediaUrlLarge = nil
        mediaUrlOriginal = nil
        mediaWidth = nil
        mediaHeight = nil
        whoGoated = nil
        whoHearted = nil
        whoStarred = nil
        starFlag = nil
        heartFlag = nil
        goatFlag = nil
        interactionFlag = nil
        reactionCount = nil
        goats = 0
        hearts = 0
        stars = 0
        postType = nil
        postInteractions = nil
        showInteractionCount = nil
        attachment = nil
        interactionCount = nil
        commentCount = nil
        workoutId = nil
        workoutType = nil
        activityId = nil
        activityType = nil
        routeDataUrl = nil
        routeDataS3Key = nil
        routePolyline = nil
        mapPreviewUrl = nil
        visibility = nil
        postId = nil
        userId = nil
        caption = nil
        createdAt = nil
        updatedAt = nil
        goatCount = nil
        heartCount = nil
        starCount = nil
        activitySnapshotRaw = nil
        workoutSnapshotRaw = nil
        user = nil
        interactions = nil
    }
    
    /// Recalculate interaction counts from postInteractions array
    /// This ensures counts are accurate even if API doesn't provide them
    mutating func recalculateInteractionCounts() {
        guard let interactions = postInteractions else {
            // If no interactions array, keep existing counts
            return
        }
        
        var calculatedHearts = 0
        var calculatedStars = 0
        var calculatedGoats = 0
        
        for interaction in interactions {
            switch interaction.interactionType {
            case .heart:
                calculatedHearts += 1
            case .star:
                calculatedStars += 1
            case .goat:
                calculatedGoats += 1
            default:
                break
            }
        }
        
        // Update counts
        hearts = calculatedHearts
        stars = calculatedStars
        goats = calculatedGoats
        
        #if DEBUG
        if calculatedHearts > 0 || calculatedStars > 0 || calculatedGoats > 0 {
            print("📊 [Post] Recalculated counts - hearts: \(calculatedHearts), stars: \(calculatedStars), goats: \(calculatedGoats) for postId: \(objectId ?? "unknown")")
        }
        #endif
    }
    
    // Update reaction (for optimistic UI)
    mutating func updateReaction(type: String?) {
        // Track previous reaction state
        let hadHeart = self.heartFlag == true
        let hadStar = self.starFlag == true
        let hadGoat = self.goatFlag == true
        
        // Determine new reaction type
        let newReactionType: String? = {
            if let type = type {
                switch type {
                case "heart", "fullheart_40": return "heart"
                case "star", "fullstar_40": return "star"
                case "goat", "fullgoat_40": return "goat"
                case "party", "PartyFaceEmoji": return "party"
                case "clap", "ClappingEmoji": return "clap"
                case "exploding", "ExplodingFaceEmoji", "explode": return "exploding"
                default: return nil
                }
            }
            return nil
        }()
        
        // Update flags
        if let newType = newReactionType {
            switch newType {
            case "heart":
                self.heartFlag = true
                self.starFlag = false
                self.goatFlag = false
            case "star":
                self.starFlag = true
                self.heartFlag = false
                self.goatFlag = false
            case "goat":
                self.goatFlag = true
                self.heartFlag = false
                self.starFlag = false
            default:
                // For party, clap, exploding - we don't have flags for these yet
                // But clear the other flags
                self.heartFlag = false
                self.starFlag = false
                self.goatFlag = false
            }
        } else {
            // Removed reaction
            self.heartFlag = false
            self.starFlag = false
            self.goatFlag = false
        }
        
        // Update counts based on what changed
        // If user had a heart and is removing it or switching
        if hadHeart && (newReactionType != "heart" || newReactionType == nil) {
            self.hearts = max(0, self.hearts - 1)
        }
        // If user had a star and is removing it or switching
        if hadStar && (newReactionType != "star" || newReactionType == nil) {
            self.stars = max(0, self.stars - 1)
        }
        // If user had a goat and is removing it or switching
        if hadGoat && (newReactionType != "goat" || newReactionType == nil) {
            self.goats = max(0, self.goats - 1)
        }
        
        // If user is adding a new reaction (and didn't have it before)
        if let newType = newReactionType {
            switch newType {
            case "heart":
                if !hadHeart {
                    self.hearts += 1
                }
            case "star":
                if !hadStar {
                    self.stars += 1
                }
            case "goat":
                if !hadGoat {
                    self.goats += 1
                }
            default:
                // For party, clap, exploding - counts would need to be added to Post model
                break
            }
        }
    }
}

// MARK: - Date Helper Extension

extension Date {
    func timeAgoSinceDateForPost() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.second, .minute, .hour, .day, .weekOfYear, .month, .year], from: self, to: now)
        
        // If more than a week (including months and years), show the actual date
        if let year = components.year, year > 0 {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: self)
        } else if let month = components.month, month > 0 {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: self)
        } else if let week = components.weekOfYear, week > 0 {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: self)
        } else if let day = components.day, day > 0 {
            return "\(day)d ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Helper Types for Decoding

private struct PostUser: Codable {
    let userId: String
    let username: String
    let name: String?
    let email: String?
    let profilePictureUrl: String?
    let profilePictureUrlThumb: String?
    let profilePictureUrlMedium: String?
    let profilePictureUrlLarge: String?
    let followerCount: Int?
    let followingCount: Int?
    let isVerified: Bool?
}

private struct PostInteraction: Codable {
    let interactionId: String
    let postId: String
    let userId: String
    let reactionType: String
    let createdAt: String
}

