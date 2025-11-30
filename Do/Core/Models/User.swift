//
//  User.swift
//  Do
//

import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: String
    var email: String
    var username: String
    var name: String?
    var birthday: Date?
    var gender: String?
    
    // Profile
    var profilePictureUrl: String?
    var profilePictureAvailable: Bool
    var privacyToggle: Bool
    
    // Social
    var followerCount: Int
    var followingCount: Int
    
    // Genie
    var genieSubscriptionTier: String
    var availableGenieFlows: Int
    var preferredAIModel: String?
    
    // Fitness
    var fitnessGoals: [String]
    var healthMetrics: [String: AnyCodable]
    var workoutSummaries: [AnyCodable]
    
    // Auth
    var cognitoSub: String?
    var authProvider: String
    
    // Timestamps
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "userId"
        case email, username, name, birthday, gender
        case profilePictureUrl, profilePictureAvailable, privacyToggle
        case followerCount, followingCount
        case genieSubscriptionTier, availableGenieFlows, preferredAIModel
        case fitnessGoals, healthMetrics, workoutSummaries
        case cognitoSub, authProvider
        case createdAt, updatedAt
    }
    
    // Custom Equatable implementation (AnyCodable doesn't conform to Equatable)
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id &&
               lhs.email == rhs.email &&
               lhs.username == rhs.username &&
               lhs.name == rhs.name &&
               lhs.birthday == rhs.birthday &&
               lhs.gender == rhs.gender &&
               lhs.profilePictureUrl == rhs.profilePictureUrl &&
               lhs.profilePictureAvailable == rhs.profilePictureAvailable &&
               lhs.privacyToggle == rhs.privacyToggle &&
               lhs.followerCount == rhs.followerCount &&
               lhs.followingCount == rhs.followingCount &&
               lhs.genieSubscriptionTier == rhs.genieSubscriptionTier &&
               lhs.availableGenieFlows == rhs.availableGenieFlows &&
               lhs.preferredAIModel == rhs.preferredAIModel &&
               lhs.fitnessGoals == rhs.fitnessGoals &&
               lhs.cognitoSub == rhs.cognitoSub &&
               lhs.authProvider == rhs.authProvider &&
               lhs.createdAt == rhs.createdAt &&
               lhs.updatedAt == rhs.updatedAt
        // Note: healthMetrics and workoutSummaries are excluded due to AnyCodable
    }
}
