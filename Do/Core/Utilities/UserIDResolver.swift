//
//  UserIDResolver.swift
//  Do
//
//  Resilient user ID resolution that handles both Parse IDs and Cognito IDs
//

import Foundation

/// Utility for resolving user IDs that works with both Parse (legacy) and Cognito (new) user IDs
/// This ensures backward compatibility and handles migration scenarios
class UserIDResolver {
    static let shared = UserIDResolver()
    
    private init() {}
    
    /// Get the best user ID to use for API calls
    /// Returns Parse user ID if available (for legacy data), otherwise Cognito user ID
    /// - Returns: User ID string, or nil if not available
    func getBestUserIdForAPI() -> String? {
        // Priority 1: Parse user ID from JWT token (for legacy data compatibility)
        if let parseUserId = AWSCognitoAuth.shared.getParseUserId(), !parseUserId.isEmpty {
            print("🆔 [UserIDResolver] Using Parse user ID: \(parseUserId)")
            return parseUserId
        }
        
        // Priority 2: Cognito user ID from CurrentUserService
        if let cognitoUserId = CurrentUserService.shared.userID, !cognitoUserId.isEmpty {
            print("🆔 [UserIDResolver] Using Cognito user ID: \(cognitoUserId)")
            return cognitoUserId
        }
        
        // Priority 3: Cognito user ID from UserDefaults
        if let cognitoUserId = UserDefaults.standard.string(forKey: "cognito_user_id"), !cognitoUserId.isEmpty {
            print("🆔 [UserIDResolver] Using Cognito user ID from UserDefaults: \(cognitoUserId)")
            return cognitoUserId
        }
        
        print("🆔 [UserIDResolver] ⚠️ No user ID found")
        return nil
    }
    
    /// Get all available user IDs (both Parse and Cognito)
    /// Useful for fallback scenarios where we need to try multiple IDs
    /// - Returns: Tuple with (parseUserId, cognitoUserId)
    func getAllUserIds() -> (parseUserId: String?, cognitoUserId: String?) {
        let parseUserId = AWSCognitoAuth.shared.getParseUserId()
        let cognitoUserId = CurrentUserService.shared.userID ?? UserDefaults.standard.string(forKey: "cognito_user_id")
        
        return (parseUserId, cognitoUserId)
    }
    
    /// Check if a given user ID matches the current user
    /// Handles both Parse and Cognito ID comparisons
    /// - Parameter userId: The user ID to check
    /// - Returns: True if the ID matches the current user
    func isCurrentUser(userId: String?) -> Bool {
        guard let userId = userId, !userId.isEmpty else { return false }
        
        let (parseUserId, cognitoUserId) = getAllUserIds()
        
        // Check Parse ID match
        if let currentParseId = parseUserId, currentParseId == userId {
            return true
        }
        
        // Check Cognito ID match
        if let currentCognitoId = cognitoUserId, currentCognitoId == userId {
            return true
        }
        
        return false
    }
    
    /// Get user IDs for fetching data (tries Parse first, then Cognito)
    /// This is the recommended method for API calls that need to work with legacy data
    /// - Parameter userModel: Optional UserModel to extract IDs from
    /// - Returns: Array of user IDs to try (in order of preference)
    func getUserIdsForDataFetch(userModel: UserModel? = nil) -> [String] {
        var ids: [String] = []
        
        // If userModel provided, extract IDs from it
        if let user = userModel {
            // Try Parse ID from user model (if it exists in a custom field)
            // For now, we'll rely on the userID which might be either
            
            // Add the user's ID (could be Parse or Cognito)
            if let userId = user.userID, !userId.isEmpty {
                ids.append(userId)
            }
        }
        
        // Always add current user's Parse ID first (for legacy data)
        if let parseUserId = AWSCognitoAuth.shared.getParseUserId(), !parseUserId.isEmpty {
            if !ids.contains(parseUserId) {
                ids.insert(parseUserId, at: 0) // Insert at beginning for priority
            }
        }
        
        // Add current user's Cognito ID as fallback
        if let cognitoUserId = CurrentUserService.shared.userID ?? UserDefaults.standard.string(forKey: "cognito_user_id"),
           !cognitoUserId.isEmpty {
            if !ids.contains(cognitoUserId) {
                ids.append(cognitoUserId)
            }
        }
        
        print("🆔 [UserIDResolver] User IDs for data fetch: \(ids)")
        return ids
    }
    
    /// Determine if a user ID looks like a Parse ID or Cognito ID
    /// Parse IDs are typically short (8-12 chars), Cognito IDs are UUIDs (36 chars with dashes)
    /// - Parameter userId: The user ID to check
    /// - Returns: True if it looks like a Parse ID
    func isParseUserId(_ userId: String) -> Bool {
        // Parse IDs are typically short alphanumeric strings (8-15 chars)
        // Cognito IDs are UUIDs (36 chars with dashes: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
        if userId.count < 20 && !userId.contains("-") {
            return true
        }
        return false
    }
    
    /// Get the appropriate user ID for a specific user model
    /// Tries to determine if we should use Parse or Cognito ID based on the user model
    /// - Parameter user: The UserModel to get ID for
    /// - Returns: Best user ID to use, or nil
    func getUserIdForUser(_ user: UserModel) -> String? {
        // If user has a userID, use it
        if let userId = user.userID, !userId.isEmpty {
            return userId
        }
        
        // Fallback to username (though this is less reliable)
        if let username = user.userName, !username.isEmpty {
            return username
        }
        
        return nil
    }
}


