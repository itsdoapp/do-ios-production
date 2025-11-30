//
//  PostParser.swift
//  Do
//
//  Parse Post data from AWS API responses
//

import Foundation
import UIKit

extension Post {
    /// Parse Post from AWS API JSON
    static func from(json: [String: Any]) -> Post? {
        guard let postId = json["postId"] as? String else {
            return nil
        }
        
        var post = Post()
        post.objectId = postId
        post.postType = json["postType"] as? String
        post.postCaption = json["caption"] as? String
        post.dateLabelString = formatDate(json["createdAt"] as? String)
        
        // Media URLs
        post.mediaUrl = json["mediaUrl"] as? String
        post.mediaUrlThumb = json["mediaUrlThumb"] as? String
        post.mediaUrlMedium = json["mediaUrlMedium"] as? String
        post.mediaUrlLarge = json["mediaUrlLarge"] as? String
        post.mediaUrlOriginal = json["mediaUrlOriginal"] as? String
        
        // Interaction counts - get from API or calculate from interactions
        let apiHeartCount = json["heartCount"] as? Int ?? 0
        let apiStarCount = json["starCount"] as? Int ?? 0
        let apiGoatCount = json["goatCount"] as? Int ?? 0
        
        post.hearts = apiHeartCount
        post.stars = apiStarCount
        post.goats = apiGoatCount
        post.interactionCount = json["interactionCount"] as? Int ?? 0
        post.commentCount = json["commentCount"] as? Int ?? 0
        
        // Workout/Activity data
        post.workoutId = json["workoutId"] as? String
        post.activityId = json["activityId"] as? String
        post.activityType = json["activityType"] as? String
        post.workoutType = json["workoutType"] as? String
        
        // Route/Location data
        post.routeDataUrl = json["routeDataUrl"] as? String
        post.routeDataS3Key = json["routeDataS3Key"] as? String
        post.routePolyline = json["routePolyline"] as? String
        post.mapPreviewUrl = json["mapPreviewUrl"] as? String
        
        // Attachment data (workout stats, etc.)
        if let attachmentData = json["attachment"] as? [String: Any] {
            post.attachment = attachmentData
        } else if let activityData = json["activityData"] as? String {
            // Parse JSON string to dictionary
            if let data = activityData.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                post.attachment = dict
            }
        }
        
        // Privacy
        post.visibility = json["visibility"] as? String
        
        // User data
        if let userData = json["user"] as? [String: Any] {
            var user = UserModel()
            user.userID = userData["userId"] as? String
            user.userName = userData["username"] as? String
            user.name = userData["name"] as? String
            user.email = userData["email"] as? String
            user.profilePictureUrl = userData["profilePictureUrl"] as? String
            user.followerCount = userData["followerCount"] as? Int
            user.followingCount = userData["followingCount"] as? Int
            post.createdBy = user
        }
        
        // Interactions array
        if let interactionsArray = json["interactions"] as? [[String: Any]] {
            post.postInteractions = interactionsArray.compactMap { Interaction.from(json: $0) }
            
            // Calculate counts from interactions if API didn't provide them or they're 0
            // This ensures counts are always accurate even if Lambda doesn't return them
            if let interactions = post.postInteractions, (apiHeartCount == 0 && apiStarCount == 0 && apiGoatCount == 0) {
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
                
                // Use calculated counts if API counts are 0
                if apiHeartCount == 0 && calculatedHearts > 0 {
                    post.hearts = calculatedHearts
                }
                if apiStarCount == 0 && calculatedStars > 0 {
                    post.stars = calculatedStars
                }
                if apiGoatCount == 0 && calculatedGoats > 0 {
                    post.goats = calculatedGoats
                }
                
                #if DEBUG
                if calculatedHearts > 0 || calculatedStars > 0 || calculatedGoats > 0 {
                    print("📊 [PostParser] Calculated counts from interactions - hearts: \(calculatedHearts), stars: \(calculatedStars), goats: \(calculatedGoats) for postId: \(postId)")
                }
                #endif
            }
        }
        
        return post
    }
    
    /// Format ISO date string to relative time
    private static func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "Just now" }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return "Just now"
            }
            return formatRelativeTime(date)
        }
        
        return formatRelativeTime(date)
    }
    
    private static func formatRelativeTime(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let weeks = Int(interval / 604800)
            return "\(weeks)w ago"
        }
    }
}

extension Interaction {
    /// Parse Interaction from AWS API JSON
    static func from(json: [String: Any]) -> Interaction? {
        guard let interactionId = json["interactionId"] as? String,
              let postId = json["postId"] as? String,
              let userId = json["userId"] as? String,
              let reactionTypeString = json["reactionType"] as? String else {
            return nil
        }
        
        // Map string to InteractionType
        let reactionType: InteractionType
        switch reactionTypeString.lowercased() {
        case "heart":
            reactionType = .heart
        case "star":
            reactionType = .star
        case "goat":
            reactionType = .goat
        case "party":
            reactionType = .party
        case "clap":
            reactionType = .clap
        case "exploding", "explode":
            reactionType = .exploding
        case "like":
            reactionType = .like
        default:
            reactionType = .heart
        }
        
        let createdAt: Date
        if let dateString = json["createdAt"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            createdAt = formatter.date(from: dateString) ?? Date()
        } else {
            createdAt = Date()
        }
        
        return Interaction(
            id: interactionId,
            postId: postId,
            userId: userId,
            username: json["username"] as? String,
            userProfileImageUrl: json["userProfileImageUrl"] as? String,
            interactionType: reactionType,
            createdAt: createdAt,
            notificationStatus: json["notificationStatus"] as? Bool ?? false
        )
    }
}
