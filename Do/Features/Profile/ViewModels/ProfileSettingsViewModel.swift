//
//  ProfileSettingsViewModel.swift
//  Do.
//
//  Created by Mikiyas Tadesse on 8/19/25.
//

import SwiftUI
import NotificationBannerSwift
import UIKit

enum SubscriptionPlan {
    case monthly
    case annual
}

@MainActor
class ProfileSettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var name: String = ""
    @Published var username: String = ""
    @Published var bio: String = ""
    @Published var email: String = ""
    @Published var profileImage: UIImage?
    @Published var isPrivateAccount: Bool = false
    @Published var isPremium: Bool = false
    @Published var isLoading: Bool = false
    @Published var subscriptionTier: String = "free"
    @Published var monthlyAllowance: Int = 0
    @Published var tokensRemaining: Int = 0
    
    // MARK: - Private Properties
    private var user: UserModel
    private var originalEmail: String = ""
    
    // MARK: - Initialization
    init(userModel: UserModel) {
        self.user = userModel
        // Initialize with existing user data immediately for instant display
        initializeFromUserModel(userModel)
        // Then refresh from API in background
        loadUserData()
    }
    
    // MARK: - Private Methods
    private func initializeFromUserModel(_ userModel: UserModel) {
        // Populate fields from the passed user model immediately
        self.name = userModel.name ?? ""
        self.username = userModel.userName ?? ""
        self.bio = userModel.bio ?? ""
        self.email = userModel.email ?? ""
        self.originalEmail = self.email
        self.isPrivateAccount = userModel.privacyToggle ?? false
        
        // Load profile image if available
        if let profileImage = userModel.profilePicture {
            self.profileImage = profileImage
        } else if let profilePicUrl = userModel.profilePictureUrl, !profilePicUrl.isEmpty {
            // Load image asynchronously if URL is available
            Task {
                let image = await OptimizedMediaService.shared.loadImage(from: profilePicUrl)
                await MainActor.run {
                    self.profileImage = image
                    // Explicitly trigger UI update for image
                    self.objectWillChange.send()
                }
            }
        }
    }
    
    // MARK: - Public Methods
    func loadUserData() {
        guard let userId = user.userID else {
            print("⚠️ [ProfileSettings] No userID available, cannot load profile data")
            return
        }
        
        print("🔄 [ProfileSettings] Loading user data for userId: \(userId)")
        isLoading = true
        
        Task {
            do {
                let profileResponse = try await ProfileAPIService.shared.fetchUserProfile(
                    userId: userId,
                    currentUserId: userId,
                    includeFollowers: false,
                    includeFollowing: false
                )
                
                guard let userData = profileResponse.data?.user else {
                    throw NSError(domain: "ProfileError", code: -1, userInfo: [NSLocalizedDescriptionKey: "User data not found"])
                }
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    
                    // Update with fresh data from API
                    self.name = userData.name ?? ""
                    self.username = userData.username ?? "" // Handle optional username
                    self.bio = userData.bio ?? ""
                    self.email = userData.email ?? ""
                    self.originalEmail = self.email
                    self.isPrivateAccount = userData.privacyToggle ?? false
                    
                    // Update local user model
                    self.user.name = userData.name
                    self.user.userName = userData.username ?? "" // Handle optional username
                    self.user.bio = userData.bio
                    self.user.email = userData.email
                    self.user.privacyToggle = userData.privacyToggle
                    self.user.profilePictureUrl = userData.profilePictureUrl
                    
                    // Load profile image if URL is available
                    if let profilePicUrl = userData.profilePictureUrl {
                        Task {
                            let image = await OptimizedMediaService.shared.loadImage(from: profilePicUrl)
                            await MainActor.run {
                                self.profileImage = image
                                // Explicitly trigger UI update for image
                                self.objectWillChange.send()
                            }
                        }
                    }
                    
                    // Load subscription status from AWS
                    Task {
                        await self.loadSubscriptionStatus()
                    }
                    
                    self.isLoading = false
                    // Explicitly trigger UI update
                    self.objectWillChange.send()
                    print("✅ [ProfileSettings] Successfully loaded user data")
                }
            } catch {
                print("❌ [ProfileSettings] Error fetching user data from AWS: \(error)")
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.isLoading = false
                    // Only show error if we don't have initial data
                    if self.name.isEmpty && self.username.isEmpty {
                        self.showError("Failed to load user data")
                    } else {
                        print("⚠️ [ProfileSettings] Using cached/initial data due to API error")
                    }
                }
            }
        }
    }
    
    func saveChanges() {
        guard let userId = user.userID else { return }
        isLoading = true
        
        // Validate email if changed
        if email != originalEmail {
            guard isValidEmail(email) else {
                showError("Please enter a valid email address")
                isLoading = false
                return
            }
        }
        
        Task {
            do {
                // Build update fields
                var fields: [String: Any] = [
                    "name": name,
                    "username": username.lowercased(),
                    "bio": bio,
                    "email": email,
                    "privacyToggle": isPrivateAccount
                ]
                
                // Update AWS DynamoDB
                let updatedUser = try await ProfileAPIService.shared.updateUserProfile(
                    userId: userId,
                    fields: fields
                )
                
                // Update local user model
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    
                    self.user.name = updatedUser.name
                    self.user.userName = updatedUser.username ?? "" // Handle optional username
                    self.user.bio = updatedUser.bio
                    self.user.email = updatedUser.email
                    self.user.privacyToggle = updatedUser.privacyToggle
                    
                    // Reload subscription status after save
                    Task {
                        await self.loadSubscriptionStatus()
                    }
                    
                    self.isLoading = false
                    self.showSuccess("Profile updated successfully")
                }
            } catch {
                print("❌ Error saving user data to AWS: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.showError("Failed to save changes")
                }
            }
        }
    }
    
    func changeProfilePicture() {
        // Implement image picker functionality
        // This will be handled by the hosting controller
    }
    
    func subscribeToPlan(_ plan: SubscriptionPlan) {
        // TODO: Implement AWS-based subscription management
        // For now, show a message that subscription is coming soon
        showError("Subscription management coming soon")
        
        /* Remove when AWS subscription API is ready
        ADC l let userId = user.userID else { return }
        isLoading = true
        
        Task {
            do {
                let fields: [String: Any] = [
                    "isPremium": true,
                    "subscriptionPlan": plan == .monthly ? "monthly" : "annual",
                    "subscriptionDate": ISO8601DateFormatter().string(from: Date())
                ]
                
                let updatedUser = try await ProfileAPIService.shared.updateUserProfile(
                    userId: userId,
                    fields: fields
                )
                
                await MainActor.run {
                    self.isPremium = true
                    self.isLoading = false
                    self.showSuccess("Successfully upgraded to premium!")
                }
            } catch {
                print("❌ Error upgrading to premium: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.showError("Failed to process subscription")
                }
            }
        }
        */
    }
    
    func logOut() {
        // Sign out from Cognito
        AWSCognitoAuth.shared.signOut()
        
        // Clear any cached data
        UserDefaults.standard.removeObject(forKey: "cognito_id_token")
        UserDefaults.standard.removeObject(forKey: "cognito_access_token")
        UserDefaults.standard.removeObject(forKey: "cognito_refresh_token")
        UserDefaults.standard.removeObject(forKey: "cognito_user_id")
        UserDefaults.standard.synchronize()
        
        // Navigation will be handled by the hosting controller
    }
    
    func deleteAccount(reason: String) {
        // TODO: Implement AWS-based account deletion
        // For now, show error message
        showError("Account deletion not yet implemented in AWS")
        
        /* Remove when AWS delete API is ready
        await l let userId = user.userID else { return }
        isLoading = true
        
        Task {
            do {
                // TODO: Call AWS delete user Lambda
                // For now, just sign out
                AWSCognitoAuth.shared.signOut()
                
                await MainActor.run {
                    self.isLoading = false
                    self.showSuccess("Account deleted successfully")
                    // Navigation will be handled by the hosting controller
                }
            } catch {
                print("❌ Error deleting account: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.showError("Failed to delete account")
                }
            }
        }
        */
    }
    
    // MARK: - Private Methods
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func showError(_ message: String) {
        let banner = NotificationBanner(title: message, style: .danger)
        banner.show(bannerPosition: .top)
    }
    
    func loadSubscriptionStatus() async {
        do {
            let response = try await GenieAPIService.shared.getTokenBalance()
            
            await MainActor.run {
                self.tokensRemaining = response.balance
                
                // Always check subscription object - backend should always return it
                if let subscription = response.subscription {
                    let tier = subscription.tier.lowercased()
                    
                    // Only update if tier is valid and not empty
                    // This prevents overwriting with "free" if subscription object exists but tier is missing
                    if !tier.isEmpty && tier != "free" {
                        self.subscriptionTier = tier
                        self.monthlyAllowance = subscription.monthlyAllowance
                        
                        // User is premium if they have any paid tier (athlete, champion, legend)
                        let isPaidTier = tier == "athlete" || tier == "champion" || tier == "legend"
                        self.isPremium = isPaidTier
                        
                        print("✅ [Profile] Loaded subscription: tier=\(tier), allowance=\(subscription.monthlyAllowance), status=\(subscription.status ?? "nil"), premium=\(self.isPremium)")
                        print("✅ [Profile] Tokens remaining: \(self.tokensRemaining)")
                        // Explicitly trigger UI update
                        self.objectWillChange.send()
                    } else if tier == "free" {
                        // Explicitly free tier
                        self.subscriptionTier = "free"
                        self.monthlyAllowance = subscription.monthlyAllowance
                        self.isPremium = false
                        print("ℹ️ [Profile] Free tier subscription")
                        // Explicitly trigger UI update
                        self.objectWillChange.send()
                    } else {
                        // Tier is missing or invalid - don't overwrite existing value
                        // This prevents the race condition where tier gets reset to "free"
                        print("⚠️ [Profile] Subscription object exists but tier is invalid: '\(tier)', keeping current tier: \(self.subscriptionTier)")
                        // Still update other fields if available
                        if subscription.monthlyAllowance > 0 {
                            self.monthlyAllowance = subscription.monthlyAllowance
                        }
                    }
                } else {
                    // No subscription object - only set to free if we don't already have a tier
                    // This prevents overwriting a valid tier that was loaded earlier
                    if self.subscriptionTier == "free" || self.subscriptionTier.isEmpty {
                        self.subscriptionTier = "free"
                        self.monthlyAllowance = 0
                        self.isPremium = false
                        print("ℹ️ [Profile] No subscription found - free tier")
                        // Explicitly trigger UI update
                        self.objectWillChange.send()
                    } else {
                        print("⚠️ [Profile] No subscription object but tier already set to \(self.subscriptionTier), keeping it")
                    }
                }
            }
        } catch {
            print("❌ [Profile] Error loading subscription: \(error)")
            // Only set to free on error if we don't already have a valid tier
            await MainActor.run {
                if self.subscriptionTier == "free" || self.subscriptionTier.isEmpty {
                    self.subscriptionTier = "free"
                    self.monthlyAllowance = 0
                    self.isPremium = false
                } else {
                    print("⚠️ [Profile] Error loading subscription but keeping existing tier: \(self.subscriptionTier)")
                }
            }
        }
    }
    
    private func showSuccess(_ message: String) {
        let banner = NotificationBanner(title: message, style: .success)
        banner.show(bannerPosition: .top)
    }
}
