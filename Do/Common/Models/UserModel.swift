import Foundation
import UIKit

/// A clean, AWS-compatible user model that replaces the Parse-dependent userModel
public struct UserModel: Codable, Equatable, Hashable, Identifiable {
    public var id: String { userID ?? UUID().uuidString }
    
    public var userID: String?
    public var userName: String?
    public var name: String?
    public var email: String?
    public var privacyToggle: Bool?
    public var profilePictureUrl: String?
    public var bio: String?
    public var birthday: Date?
    public var followerCount: Int?
    public var followingCount: Int?
    public var profilePictureAvailable: Bool?
    public var phoneNumber: Int?
    public var gender: String?
    public var height: Double?
    public var heightUnit: String?
    public var fitnessGoals: [String]?
    public var weight: Double?
    public var weightUnit: String?
    
    // Genie-specific properties
    public var genieSubscriptionTier: String?
    public var availableGenieFlows: Int?
    public var lastGenieContext: String?
    public var preferredAIModel: String?
    public var recentGenieQueries: [String]?
    
    // Follow status
    public var isFollowing: Bool?
    public var isFollower: Bool?
    
    // Federated identity
    public var authProvider: String?
    public var federatedIdentityId: String?
    public var appleUserIdentifier: String?
    public var googleUserId: String?
    
    // Preferences
    public var timezone: String?
    public var language: String?
    public var activityLevel: String?
    public var preferredActivities: [String]?
    public var units: String?
    public var shareProfile: Bool?
    public var shareActivity: Bool?
    public var onboardingCompleted: Bool?
    
    // Non-Codable properties for UI state
    // We ignore these during JSON encoding/decoding
    public var profilePicture: UIImage?
    
    enum CodingKeys: String, CodingKey {
        case userID, userName, name, email, privacyToggle, profilePictureUrl, bio, birthday
        case followerCount, followingCount, profilePictureAvailable, phoneNumber
        case gender, height, heightUnit, fitnessGoals, weight, weightUnit
        case genieSubscriptionTier, availableGenieFlows, lastGenieContext, preferredAIModel
        case recentGenieQueries
        // isFollowing/isFollower are usually ephemeral/contextual, but can be codable if API returns them
        // Let's include them if API returns them, but they are often separate
        case isFollowing, isFollower
        // Federated identity
        case authProvider, federatedIdentityId, appleUserIdentifier, googleUserId
        // Preferences
        case timezone, language, activityLevel, preferredActivities, units, shareProfile, shareActivity, onboardingCompleted
    }
    
    public init(userID: String? = nil, userName: String? = nil, name: String? = nil, email: String? = nil,
                privacyToggle: Bool? = nil, profilePictureUrl: String? = nil, bio: String? = nil, profilePicture: UIImage? = nil,
                birthday: Date? = nil, followerCount: Int? = nil, followingCount: Int? = nil,
                profilePictureAvailable: Bool? = nil, phoneNumber: Int? = nil, gender: String? = nil,
                height: Double? = nil, heightUnit: String? = nil, fitnessGoals: [String]? = nil,
                weight: Double? = nil, weightUnit: String? = nil, genieSubscriptionTier: String? = nil,
                availableGenieFlows: Int? = nil, lastGenieContext: String? = nil, preferredAIModel: String? = nil,
                recentGenieQueries: [String]? = nil, isFollowing: Bool? = nil, isFollower: Bool? = nil,
                authProvider: String? = nil, federatedIdentityId: String? = nil, appleUserIdentifier: String? = nil,
                googleUserId: String? = nil, timezone: String? = nil, language: String? = nil,
                activityLevel: String? = nil, preferredActivities: [String]? = nil, units: String? = nil,
                shareProfile: Bool? = nil, shareActivity: Bool? = nil, onboardingCompleted: Bool? = nil) {
        self.userID = userID
        self.userName = userName
        self.name = name
        self.email = email
        self.privacyToggle = privacyToggle
        self.profilePictureUrl = profilePictureUrl
        self.profilePicture = profilePicture
        self.birthday = birthday
        self.bio = bio
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.profilePictureAvailable = profilePictureAvailable
        self.phoneNumber = phoneNumber
        self.gender = gender
        self.height = height
        self.heightUnit = heightUnit
        self.fitnessGoals = fitnessGoals
        self.weight = weight
        self.weightUnit = weightUnit
        self.genieSubscriptionTier = genieSubscriptionTier
        self.availableGenieFlows = availableGenieFlows
        self.lastGenieContext = lastGenieContext
        self.preferredAIModel = preferredAIModel
        self.recentGenieQueries = recentGenieQueries
        self.isFollowing = isFollowing
        self.isFollower = isFollower
        self.authProvider = authProvider
        self.federatedIdentityId = federatedIdentityId
        self.appleUserIdentifier = appleUserIdentifier
        self.googleUserId = googleUserId
        self.timezone = timezone
        self.language = language
        self.activityLevel = activityLevel
        self.preferredActivities = preferredActivities
        self.units = units
        self.shareProfile = shareProfile
        self.shareActivity = shareActivity
        self.onboardingCompleted = onboardingCompleted
    }
    
    // Custom encoding to skip UIImage
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(userID, forKey: .userID)
        try container.encodeIfPresent(userName, forKey: .userName)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(privacyToggle, forKey: .privacyToggle)
        try container.encodeIfPresent(profilePictureUrl, forKey: .profilePictureUrl)
        try container.encodeIfPresent(birthday, forKey: .birthday)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(followerCount, forKey: .followerCount)
        try container.encodeIfPresent(followingCount, forKey: .followingCount)
        try container.encodeIfPresent(profilePictureAvailable, forKey: .profilePictureAvailable)
        try container.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
        try container.encodeIfPresent(gender, forKey: .gender)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(heightUnit, forKey: .heightUnit)
        try container.encodeIfPresent(fitnessGoals, forKey: .fitnessGoals)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encodeIfPresent(weightUnit, forKey: .weightUnit)
        try container.encodeIfPresent(genieSubscriptionTier, forKey: .genieSubscriptionTier)
        try container.encodeIfPresent(availableGenieFlows, forKey: .availableGenieFlows)
        try container.encodeIfPresent(lastGenieContext, forKey: .lastGenieContext)
        try container.encodeIfPresent(preferredAIModel, forKey: .preferredAIModel)
        try container.encodeIfPresent(recentGenieQueries, forKey: .recentGenieQueries)
        try container.encodeIfPresent(isFollowing, forKey: .isFollowing)
        try container.encodeIfPresent(isFollower, forKey: .isFollower)
        // Federated identity
        try container.encodeIfPresent(authProvider, forKey: .authProvider)
        try container.encodeIfPresent(federatedIdentityId, forKey: .federatedIdentityId)
        try container.encodeIfPresent(appleUserIdentifier, forKey: .appleUserIdentifier)
        try container.encodeIfPresent(googleUserId, forKey: .googleUserId)
        // Preferences
        try container.encodeIfPresent(timezone, forKey: .timezone)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(activityLevel, forKey: .activityLevel)
        try container.encodeIfPresent(preferredActivities, forKey: .preferredActivities)
        try container.encodeIfPresent(units, forKey: .units)
        try container.encodeIfPresent(shareProfile, forKey: .shareProfile)
        try container.encodeIfPresent(shareActivity, forKey: .shareActivity)
        try container.encodeIfPresent(onboardingCompleted, forKey: .onboardingCompleted)
    }
    
    // Custom decoding to skip UIImage
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decodeIfPresent(String.self, forKey: .userID)
        userName = try container.decodeIfPresent(String.self, forKey: .userName)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        privacyToggle = try container.decodeIfPresent(Bool.self, forKey: .privacyToggle)
        profilePictureUrl = try container.decodeIfPresent(String.self, forKey: .profilePictureUrl)
        birthday = try container.decodeIfPresent(Date.self, forKey: .birthday)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        followerCount = try container.decodeIfPresent(Int.self, forKey: .followerCount)
        followingCount = try container.decodeIfPresent(Int.self, forKey: .followingCount)
        profilePictureAvailable = try container.decodeIfPresent(Bool.self, forKey: .profilePictureAvailable)
        phoneNumber = try container.decodeIfPresent(Int.self, forKey: .phoneNumber)
        gender = try container.decodeIfPresent(String.self, forKey: .gender)
        height = try container.decodeIfPresent(Double.self, forKey: .height)
        heightUnit = try container.decodeIfPresent(String.self, forKey: .heightUnit)
        fitnessGoals = try container.decodeIfPresent([String].self, forKey: .fitnessGoals)
        weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        weightUnit = try container.decodeIfPresent(String.self, forKey: .weightUnit)
        genieSubscriptionTier = try container.decodeIfPresent(String.self, forKey: .genieSubscriptionTier)
        availableGenieFlows = try container.decodeIfPresent(Int.self, forKey: .availableGenieFlows)
        lastGenieContext = try container.decodeIfPresent(String.self, forKey: .lastGenieContext)
        preferredAIModel = try container.decodeIfPresent(String.self, forKey: .preferredAIModel)
        recentGenieQueries = try container.decodeIfPresent([String].self, forKey: .recentGenieQueries)
        isFollowing = try container.decodeIfPresent(Bool.self, forKey: .isFollowing)
        isFollower = try container.decodeIfPresent(Bool.self, forKey: .isFollower)
        // Federated identity
        authProvider = try container.decodeIfPresent(String.self, forKey: .authProvider)
        federatedIdentityId = try container.decodeIfPresent(String.self, forKey: .federatedIdentityId)
        appleUserIdentifier = try container.decodeIfPresent(String.self, forKey: .appleUserIdentifier)
        googleUserId = try container.decodeIfPresent(String.self, forKey: .googleUserId)
        // Preferences
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        activityLevel = try container.decodeIfPresent(String.self, forKey: .activityLevel)
        preferredActivities = try container.decodeIfPresent([String].self, forKey: .preferredActivities)
        units = try container.decodeIfPresent(String.self, forKey: .units)
        shareProfile = try container.decodeIfPresent(Bool.self, forKey: .shareProfile)
        shareActivity = try container.decodeIfPresent(Bool.self, forKey: .shareActivity)
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted)
    }
    
    // Backward compatibility helper
    public var user: Any? { nil } // Stub to satisfy any checks for Parse user
}


