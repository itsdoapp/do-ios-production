import Foundation

/// Helper class for getting current user ID
/// Simplified for SwiftUI - uses UserDefaults
class UserIDHelper {
    static let shared = UserIDHelper()
    
    private init() {}
    
    /// Get current user ID from UserDefaults
    /// - Returns: User ID string, or nil if no user is authenticated
    func getCurrentUserID(silent: Bool = false) -> String? {
        // 1. Try UserDefaults - cognito_user_id (primary)
        if let userId = UserDefaults.standard.string(forKey: "cognito_user_id"), !userId.isEmpty {
            return userId
        }
        
        // 2. Try alternate key
        if let userId = UserDefaults.standard.string(forKey: "userId"), !userId.isEmpty {
            return userId
        }
        
        // 3. Try user_id key
        if let userId = UserDefaults.standard.string(forKey: "user_id"), !userId.isEmpty {
            return userId
        }
        
        // Only print error if not silent
        if !silent {
            print("❌ No user ID found - user needs to sign in")
        }
        return nil
    }
    
    /// Check if user is authenticated
    func isAuthenticated() -> Bool {
        return getCurrentUserID() != nil
    }
    
    /// Get username from UserDefaults
    func getCurrentUsername() -> String? {
        if let username = UserDefaults.standard.string(forKey: "username"), !username.isEmpty {
            return username
        }
        
        return nil
    }
}

