import Foundation
import UIKit
import Combine

/// Service for managing the current user session
/// Provides access to the current user's data throughout the app
class CurrentUserService: ObservableObject {
    static let shared = CurrentUserService()
    
    private init() {}
    
    /// Current user model - published so views can react to changes
    @Published var user: UserModel = UserModel()
    
    /// Convenience property for user ID
    var userID: String? {
        return user.userID
    }
    
    /// Convenience property for username
    var userName: String? {
        return user.userName
    }
    
    /// Update the current user
    func updateUser(_ newUser: UserModel) {
        print("👤 [CurrentUserService] Updating user: \(newUser.userID ?? "nil"), \(newUser.userName ?? "nil")")
        self.user = newUser
        // Post notification for views that need to react
        NotificationCenter.default.post(name: NSNotification.Name("CurrentUserUpdated"), object: nil)
    }
    
    /// Clear the current user (for logout)
    func clearUser() {
        print("👤 [CurrentUserService] Clearing user")
        self.user = UserModel()
    }
    
    /// Flag to trigger profile refresh (e.g. after posting)
    var shouldRefreshCurrentUserProfile: Bool = false
    
    /// Build a lightweight payload for watch/phone communication
    func userSyncPayload() -> [String: Any]? {
        let currentUser = user
        let hasId = !(currentUser.userID ?? "").isEmpty
        let hasUsername = !(currentUser.userName ?? "").isEmpty
        
        guard hasId || hasUsername else {
            return nil
        }
        
        var payload: [String: Any] = [:]
        if let id = currentUser.userID { payload["userId"] = id }
        if let username = currentUser.userName { payload["userName"] = username }
        if let name = currentUser.name { payload["name"] = name }
        if let email = currentUser.email { payload["email"] = email }
        if let profileUrl = currentUser.profilePictureUrl { payload["profilePictureUrl"] = profileUrl }
        return payload
    }
}


