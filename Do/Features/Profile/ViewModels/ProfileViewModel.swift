//
//  ProfileViewModel.swift
//  Do.
//
//  Created by Mikiyas Tadesse on 8/19/25.
//

import SwiftUI
import NotificationBannerSwift
import UIKit

@MainActor
class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var name: String = ""
    @Published var username: String = ""
    @Published var profileImage: UIImage?
    @Published var followerCount: Int = 0
    @Published var followingCount: Int = 0
    @Published var postsCount: Int = 0
    @Published var isFollowing: Bool = false
    @Published var followRequestPending: Bool = false
    // CRITICAL: isCurrentUserProfile is immutable after init to prevent incorrect updates
    let isCurrentUserProfile: Bool
    @Published var isLoading: Bool = false
    @Published var isLoadingProfile: Bool = false // Separate loading state for profile data
    @Published var isLoadingPosts: Bool = false // Separate loading state for posts
    @Published var posts: [Post] = []
    @Published var thoughts: [Post] = []
    
    // Background loading state tracking
    public var isLoadingInBackground: Bool = false
    private var backgroundLoadingTask: Task<Void, Never>?
    
    // Notification observer token for CurrentUserUpdated
    private var currentUserUpdatedObserver: NSObjectProtocol?
    
    // MARK: - Pagination
    private var postsNextKey: String?
    private var thoughtsNextKey: String?
    @Published var hasMorePosts: Bool = false
    @Published var isLoadingMorePosts: Bool = false
    
    // CRITICAL: Track pagination state to prevent infinite loops
    private var seenNextKeys: Set<String> = []
    private var paginationAttempts: Int = 0
    private let maxPaginationAttempts: Int = 50 // Safety limit
    private var seenPostIds: Set<String> = [] // Track loaded post IDs to prevent duplicates
    
    // MARK: - Private Properties
    @Published var user: UserModel
    private var followers: [UserModel] = []
    private var following: [UserModel] = []
    public var hasBeenLoaded = false
    public var hasFetchedPosts = false
    
    // CRITICAL: Store the profile user ID and username that never change
    // This is the user we're viewing, regardless of any updates
    private let profileUserId: String
    private let profileUsername: String?
    
    // MARK: - Smart Caching
    private static var profileCache: [String: CachedProfile] = [:]
    private static var postsCache: [String: CachedPosts] = [:]
    
    // Method to update current user cache when new post is created
    static func updateCurrentUserCache(newPost: Post) {
        guard let currentUserId = AWSCognitoAuth.shared.getCurrentUserId() ?? CurrentUserService.shared.userID else { return }
        
        if var cached = postsCache[currentUserId] {
            if newPost.postType == "postThoughts" {
                cached = CachedPosts(
                    posts: cached.posts,
                    thoughts: [newPost] + cached.thoughts,
                    timestamp: Date(),
                    isCurrentUser: true
                )
            } else {
                cached = CachedPosts(
                    posts: [newPost] + cached.posts,
                    thoughts: cached.thoughts,
                    timestamp: Date(),
                    isCurrentUser: true
                )
            }
            postsCache[currentUserId] = cached
            print("📦 Updated current user cache with new post")
        }
    }
    
    // Method to clear cache for specific user (useful for refreshing)
    static func clearCacheForUser(_ userId: String) {
        profileCache.removeValue(forKey: userId)
        postsCache.removeValue(forKey: userId)
        print("🗑️ Cleared cache for user: \(userId)")
    }
    
    // Method to get cached profile (for AuthService)
    static func getCachedProfile(for userId: String) -> CachedProfile? {
        return profileCache[userId]
    }
    
    // Method to cache profile (for AuthService)
    static func cacheProfile(user: UserModel, followerCount: Int, followingCount: Int, isCurrentUser: Bool) {
        let cacheKey = user.userID ?? user.userName ?? ""
        profileCache[cacheKey] = CachedProfile(
            profile: user,
            followerCount: followerCount,
            followingCount: followingCount,
            timestamp: Date(),
            isCurrentUser: isCurrentUser
        )
        print("📦 [ProfileVM] Cached profile for userId: \(cacheKey) (current user: \(isCurrentUser))")
    }
    
    struct CachedProfile {
        let profile: UserModel
        let followerCount: Int
        let followingCount: Int
        let timestamp: Date
        let isCurrentUser: Bool
        
        var isExpired: Bool {
            if isCurrentUser {
                return false // Never expire current user profile
            }
            return Date().timeIntervalSince(timestamp) > 3600 // 1 hour for other profiles
        }
    }
    
    private struct CachedPosts {
        let posts: [Post]
        let thoughts: [Post]
        let timestamp: Date
        let isCurrentUser: Bool
        
        var isExpired: Bool {
            if isCurrentUser {
                return false // Never expire current user posts
            }
            return Date().timeIntervalSince(timestamp) > 3600 // 1 hour for other users
        }
    }
    
    // MARK: - Computed share gating
    var isProfilePublic: Bool { !(user.privacyToggle ?? false) }
    var canSharePosts: Bool { isCurrentUserProfile || isFollowing || isProfilePublic }
    
    // MARK: - Initialization
    init(user: UserModel) {
        // CRITICAL: Initialize all stored properties first, in order
        self.user = user
        
        // Store the profile user ID and username IMMEDIATELY - these never change
        let userId = user.userID ?? user.userName ?? ""
        let username = user.userName
        self.profileUserId = userId
        self.profileUsername = username
        
        // CRITICAL: Determine if this is current user's profile based on profileUserId
        // This is set once and never changes, preventing incorrect updates
        // Use UserIDResolver to properly handle both Parse and Cognito IDs
        let idMatches = UserIDResolver.shared.isCurrentUser(userId: userId)
        let usernameMatches: Bool = {
            if let u = username, let c = CurrentUserService.shared.userName { return u == c }
            return false
        }()
        self.isCurrentUserProfile = idMatches || usernameMatches
        
        let (parseUserId, cognitoUserId) = UserIDResolver.shared.getAllUserIds()
        print("🔒 [ProfileVM] Initializing with profileUserId: \(self.profileUserId), profileUsername: \(self.profileUsername ?? "nil")")
        print("🔒 [ProfileVM] isCurrentUserProfile set to \(self.isCurrentUserProfile) based on profileUserId: \(self.profileUserId)")
        print("🔒 [ProfileVM] Input user.userID: \(user.userID ?? "nil"), user.userName: \(user.userName ?? "nil")")
        print("🔒 [ProfileVM] Current user IDs - Parse: \(parseUserId ?? "nil"), Cognito: \(cognitoUserId ?? "nil"), Username: \(CurrentUserService.shared.userName ?? "nil")")
        print("🔒 [ProfileVM] isCurrentUserProfile: \(self.isCurrentUserProfile), profileUserId: \(self.profileUserId)")
        
        // OPTIMISTIC UI: Initialize immediately from user object or CurrentUserService for instant display
        // CRITICAL: Use profileUserId for cache key to ensure consistency
        let cacheKey = profileUserId
        
        // Try cache first
        if let cached = Self.profileCache[cacheKey], !cached.isExpired {
            print("📦 Initializing from cache for instant display")
            self.name = cached.profile.name ?? ""
            self.username = cached.profile.userName ?? ""
            self.profileImage = cached.profile.profilePicture
            self.followerCount = cached.followerCount
            self.followingCount = cached.followingCount
            // Update user model with cached data including bio
            self.user.bio = cached.profile.bio
            self.user.name = cached.profile.name
            self.user.userName = cached.profile.userName
            self.user.email = cached.profile.email
            self.hasBeenLoaded = true
            
            // Load posts from cache if available
            if let cachedPosts = Self.postsCache[cacheKey], !cachedPosts.isExpired {
                self.posts = cachedPosts.posts
                self.thoughts = cachedPosts.thoughts
                self.postsCount = cachedPosts.posts.count + cachedPosts.thoughts.count
                self.hasFetchedPosts = true
            }
        } else if isCurrentUserProfile {
            // For current user, use CurrentUserService for instant display
            print("📦 Initializing current user from CurrentUserService for instant display")
            self.name = CurrentUserService.shared.user.name ?? ""
            self.username = CurrentUserService.shared.user.userName ?? ""
            self.profileImage = CurrentUserService.shared.user.profilePicture
            // Update user model with CurrentUserService data including bio
            self.user.bio = CurrentUserService.shared.user.bio
            self.user.name = CurrentUserService.shared.user.name
            self.user.userName = CurrentUserService.shared.user.userName
            self.user.email = CurrentUserService.shared.user.email
            // Note: follower/following counts will be updated from API
            
            // Listen for CurrentUserUpdated notifications to refresh when user data changes
            self.currentUserUpdatedObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("CurrentUserUpdated"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self = self, self.isCurrentUserProfile else { return }
                print("🔄 [ProfileVM] Received CurrentUserUpdated notification - updating user model")
                let updatedUser = CurrentUserService.shared.user
                
                // CRITICAL: Update ALL user model properties
                self.user = updatedUser
                
                // Update published properties to trigger UI refresh
                self.name = updatedUser.name ?? ""
                self.username = updatedUser.userName ?? ""
                
                print("🔄 [ProfileVM] Updated from notification - name: \(self.name), username: \(self.username), bio: \(updatedUser.bio ?? "nil")")
                
                // Since user is now @Published, SwiftUI will automatically detect the change
                // No need to manually trigger objectWillChange
            }
        } else {
            // For other users, initialize from provided user object
            print("📦 Initializing from user object for instant display")
            self.name = user.name ?? ""
            self.username = user.userName ?? ""
            self.profileImage = user.profilePicture
        }
    }

    // MARK: - Backfill Interactions
    private func backfillMissingInteractionCounts() async {
        // No need to backfill as FeedAPIService already provides interactionCount
        print("✅ Interaction counts are included in API responses - no backfill needed")
    }
    
    // Expose loaded state to consumers
    var isLoaded: Bool { hasBeenLoaded }
    var postsAreLoaded: Bool { hasFetchedPosts }
    
    // Update the view model with a new user and reload data
    func updateUser(_ user: UserModel) {
        let oldUser = self.user
        let incomingUserId = user.userID ?? user.userName ?? ""
        
        // CRITICAL: If viewing another user's profile, NEVER update with different user's data
        if !isCurrentUserProfile {
            // We're viewing another user's profile - only update if it's the same user
            if incomingUserId != profileUserId {
                print("🚫 [ProfileVM] BLOCKED updateUser - trying to update other user's profile with different user data")
                print("   - profileUserId: \(profileUserId)")
                print("   - incomingUserId: \(incomingUserId)")
                print("   - This would show wrong user's data - BLOCKED")
                return
            }
            // Same user, safe to update
            print("✅ [ProfileVM] Updating other user's profile with same user data: \(profileUserId)")
        }
        
        // For current user profile, check if this is still the current user
        if isCurrentUserProfile {
            let isStillCurrentUser = UserIDResolver.shared.isCurrentUser(userId: user.userID) || 
                                    (user.userName == CurrentUserService.shared.userName)
            if !isStillCurrentUser {
                print("⚠️ [ProfileVM] Current user profile being updated with different user - this shouldn't happen")
                // Don't update if it's a different user
                return
            }
        }
        
        // CRITICAL: Always update the user model and published properties
        // This ensures bio, name, and username are visible immediately
        self.user = user
        
        // CRITICAL: Always update published properties immediately
        // This ensures name, username, and bio are visible when coming back from settings
        let newName = user.name ?? ""
        let newUsername = user.userName ?? ""
        
        // Always update - don't check if changed, just update to ensure consistency
        self.name = newName
        self.username = newUsername
        
        print("🔄 [ProfileVM] updateUser - Updated properties:")
        print("   - name: '\(newName)' (was: '\(oldUser.name ?? "nil")')")
        print("   - username: '\(newUsername)' (was: '\(oldUser.userName ?? "nil")')")
        print("   - bio: '\(user.bio ?? "nil")' (was: '\(oldUser.bio ?? "nil")')")
        
        print("👤 [ProfileVM] updateUser - isCurrentUserProfile: \(isCurrentUserProfile), targetId: \(user.userID ?? "nil"), bio: \(user.bio ?? "nil"), name: \(user.name ?? "nil"), username: \(user.userName ?? "nil")")
        
        // Only reload if switching to a different user or if data isn't loaded
        let oldKey = oldUser.userID ?? oldUser.userName ?? ""
        let newKey = user.userID ?? user.userName ?? ""
        
        if oldKey != newKey {
            // Switching users - cancel any background loading and reset states
            backgroundLoadingTask?.cancel()
            backgroundLoadingTask = nil
            isLoadingInBackground = false
            hasBeenLoaded = false
            hasFetchedPosts = false
            loadUserDataWithCache()
        } else if !hasBeenLoaded && !isLoadingInBackground {
            // Same user but not loaded yet and not already loading
            loadUserDataWithCache()
        } else {
            // Same user and already loaded - just update the user model to reflect latest changes
            // This is important when coming back from settings
            print("🔄 [ProfileVM] Same user, updating model with latest data (bio: \(user.bio ?? "nil"), name: \(user.name ?? "nil"))")
            
            // Since user is now @Published, SwiftUI will automatically detect the change
            // No need to manually trigger objectWillChange
        }
        // If same user and already loaded or loading in background, keep existing data
    }
    
    // Ensure that profile basics and posts are loaded, without redundant reloads
    func ensureLoaded() async {
        if !hasBeenLoaded {
            loadUserData()
        }
        // If posts have not been fetched yet and we're not currently loading, fetch them
        if !hasFetchedPosts && !isLoading {
            await loadUserPosts()
        }
    }
    
    // MARK: - Public Methods
    private func loadUserDataWithCache() {
        // CRITICAL: Use profileUserId for cache key to ensure consistency
        let cacheKey = profileUserId
        
        // Check cache first (but don't mark as fully loaded if expired - refresh in background)
        if let cached = Self.profileCache[cacheKey], !cached.isExpired {
            print("📦 Using cached profile data for \(user.userName ?? "unknown") (current user: \(cached.isCurrentUser))")
            // Data already initialized in init, just mark as loaded
            self.hasBeenLoaded = true
            
            // Load posts from cache or fetch
            loadPostsWithCache()
            
            // For current user: always refresh in background to ensure we have latest data
            // This ensures current user profile is always up-to-date
            if isCurrentUserProfile {
                print("🔄 Current user profile cached, refreshing in background to get latest data...")
                // Refresh in background without blocking UI
                Task {
                    await loadUserData()
                }
            } else if Date().timeIntervalSince(cached.timestamp) > 1800 { // 30 minutes
                // For other users: refresh if cache is getting old (but not expired)
                Task {
                    await loadUserData()
                }
            }
            return
        }
        
        // Cache miss or expired - always load fresh data
        print("🔄 No valid cache found, loading fresh data...")
        
        // Cache miss or expired, load fresh data
        // But UI already shows optimistic data from init, so this won't block
        loadUserData()
    }
    
    func loadUserData() {
        print("🔄 Starting loadUserData for user: \(user.userName ?? "unknown"), isCurrentUser: \(isCurrentUserProfile), hasBeenLoaded: \(hasBeenLoaded)")
        
        // Check if already loading in background
        if isLoadingInBackground {
            print("🔄 Already loading in background, skipping duplicate call...")
            return
        }
        
        // For other users: skip if already loaded (don't reload unnecessarily)
        if !isCurrentUserProfile && hasBeenLoaded {
            print("⚠️ Data already loaded for other user, skipping...")
            return
        }
        
        // For current user: always allow initial load, even if cached
        // If already loaded from cache, refresh in background without blocking UI
        let shouldLoadInBackground = isCurrentUserProfile && hasBeenLoaded
        
        if shouldLoadInBackground {
            print("🔄 Current user profile cached, refreshing in background...")
            isLoadingInBackground = true
            // Don't set isLoading/isLoadingProfile to avoid showing loading overlay
        } else {
            // Initial load - show loading state
            isLoading = true
            isLoadingProfile = true
            isLoadingInBackground = true
        }

        // If viewing another user's profile, fetch from AWS
        if !isCurrentUserProfile {
            print("➡️ Viewing another user's profile; fetching from AWS")
            print("🔒 [ProfileVM] Using profileUserId: \(profileUserId) for data fetch")
            
            guard !profileUserId.isEmpty else {
                print("❌ No profileUserId found for profile")
                isLoading = false
                isLoadingProfile = false
                isLoadingInBackground = false
                return
            }
            
            // Use the stored profileUserId, not user.userID which might be updated
            let currentUserId = AWSCognitoAuth.shared.getCurrentUserId() ?? CurrentUserService.shared.userID
            
            // Check follow status immediately if we have it from the user model
            if let isFollowingFromModel = user.isFollowing {
                self.isFollowing = isFollowingFromModel
                print("📋 Using follow status from user model: \(isFollowingFromModel)")
            }
            
            Task { @MainActor in
                // Fetch profile and check follow status in PARALLEL
                print("🌐 Fetching profile and checking follow status for profileUserId: \(profileUserId)")
                
                // Start both tasks in parallel
                // CRITICAL: Use profileUserId, not user.userID
                async let profileTask: UserProfileResponse = ProfileAPIService.shared.fetchUserProfile(
                    userId: profileUserId,
                    currentUserId: currentUserId,
                    includeFollowers: false,
                    includeFollowing: false
                )
                
                // Also check follow status explicitly to ensure it's up to date
                async let followStatusTask = checkFollowStatus()
                
                let postsTask = Task { [weak self] in
                    await self?.loadUserPosts()
                }
                
                // Handle profile fetch and follow status check
                do {
                    let profileResponse = try await profileTask
                    await followStatusTask // Wait for follow status check to complete
                    
                    guard let profileData = profileResponse.data else {
                        print("❌ No profile data returned from AWS")
                        self.isLoading = false
                        self.isLoadingProfile = false
                        self.isLoadingInBackground = false
                        self.showErrorBanner(message: "Failed to load profile")
                        return
                    }
                    
                    // Update user data
                    let apiUser = profileData.user
                    self.name = apiUser.name ?? ""
                    self.username = apiUser.username ?? "" // Handle optional username
                    self.followerCount = profileData.followerCount
                    self.followingCount = profileData.followingCount
                    
                    // CRITICAL: Update the user property with fresh data from API
                    self.user.name = apiUser.name
                    self.user.userName = apiUser.username ?? "" // Handle optional username
                    self.user.bio = apiUser.bio
                    self.user.email = apiUser.email
                    self.user.profilePictureUrl = apiUser.profilePictureUrl
                    self.user.privacyToggle = apiUser.privacyToggle
                    self.user.followerCount = profileData.followerCount
                    self.user.followingCount = profileData.followingCount
                    
                    // Load profile picture
                    if let profilePicUrl = apiUser.profilePictureUrl,
                       let url = URL(string: profilePicUrl) {
                        do {
                            let (data, _) = try await URLSession.shared.data(from: url)
                            if let img = UIImage(data: data) {
                                self.profileImage = img
                                self.user.profilePicture = img // Also update user model
                            }
                        } catch {
                            print("❌ Failed to load profile picture: \(error.localizedDescription)")
                        }
                    }
                    
                    // Update follow status from profile response (may be more up-to-date)
                    if let followStatus = profileData.followStatus {
                        self.isFollowing = followStatus.isFollowing && (followStatus.accepted ?? true)
                        self.followRequestPending = followStatus.pending ?? false
                        print("📊 Follow status from profile: following=\(self.isFollowing), pending=\(self.followRequestPending)")
                    }
                    
                    // Log privacy status
                    let isPrivate = apiUser.privacyToggle ?? false
                    print("🔒 Profile privacy: \(isPrivate ? "PRIVATE" : "PUBLIC"), canSharePosts: \(self.canSharePosts)")
                    
                    // Cache the profile data
                    // CRITICAL: Use profileUserId for cache key to ensure consistency
                    let cacheKey = profileUserId
                    Self.profileCache[cacheKey] = CachedProfile(
                        profile: self.user,
                        followerCount: self.followerCount,
                        followingCount: self.followingCount,
                        timestamp: Date(),
                        isCurrentUser: false
                    )
                    
                    self.hasBeenLoaded = true
                    self.isLoadingProfile = false
                    // Don't set isLoading = false here, wait for posts
                    
                    print("✅ Profile loaded from AWS successfully")
                    
                } catch {
                    print("❌ Error loading profile from AWS: \(error.localizedDescription)")
                    self.isLoadingProfile = false
                    // Don't set isLoading = false here, wait for posts
                    self.showErrorBanner(message: "Failed to load profile")
                }
                
                // Wait for posts to complete (they're already loading in parallel)
                // This ensures both operations complete independently
                _ = await postsTask.value
                
                // Both tasks completed, update final loading state
                await MainActor.run {
                    if !self.isLoadingPosts {
                        self.isLoading = false
                        self.isLoadingInBackground = false
                    }
                }
            }
            return
        }

        // Fetch current user's profile from AWS
        print("🌐 Fetching current user profile from AWS")
        
        // Use resilient user ID resolution
        guard let currentUserId = UserIDResolver.shared.getBestUserIdForAPI() else {
            print("❌ No current user ID found")
            isLoading = false
            isLoadingProfile = false
            isLoadingInBackground = false
            showErrorBanner(message: "Failed to load profile")
            return
        }
        
        Task { @MainActor in
            // Fetch profile and posts in PARALLEL using async let
            print("🌐 Fetching profile and posts in parallel for current user with ID: \(currentUserId)")
            
            // Get all user IDs to try (for resilient profile fetching)
            let userIdsToTry = UserIDResolver.shared.getUserIdsForDataFetch()
            
            // Try fetching profile with each user ID
            var profileResponse: UserProfileResponse?
            var profileError: Error?
            var successfulUserId: String?
            
            for userId in userIdsToTry {
                do {
                    print("🌐 [ProfileVM] Trying to fetch profile with user ID: \(userId)")
                    let response = try await ProfileAPIService.shared.fetchUserProfile(
                        userId: userId,
                        currentUserId: userId,
                        includeFollowers: false,
                        includeFollowing: false
                    )
                    profileResponse = response
                    successfulUserId = userId
                    print("✅ [ProfileVM] Successfully fetched profile using user ID: \(userId)")
                    break
                } catch {
                    print("⚠️ [ProfileVM] Error fetching profile with user ID \(userId): \(error.localizedDescription)")
                    profileError = error
                    // Continue to next user ID
                }
            }
            
            guard let profileResponse = profileResponse else {
                print("❌ [ProfileVM] Failed to fetch profile with all user IDs")
                isLoading = false
                isLoadingProfile = false
                isLoadingInBackground = false
                showErrorBanner(message: "Failed to load profile")
                return
            }
            
            // Start posts task in parallel
            let postsTask = Task { [weak self] in
                await self?.loadUserPosts()
            }
            
            // Handle profile fetch
            do {
                
                guard let profileData = profileResponse.data else {
                    print("❌ No profile data returned from AWS")
                    self.isLoading = false
                    self.isLoadingProfile = false
                    self.isLoadingInBackground = false
                    self.showErrorBanner(message: "Failed to load profile")
                    return
                }
                
                // Update user data from AWS
                let apiUser = profileData.user
                self.name = apiUser.name ?? ""
                self.username = apiUser.username ?? "" // Handle optional username
                self.followerCount = profileData.followerCount
                self.followingCount = profileData.followingCount
                
                // CRITICAL: Update the user property with fresh data from API
                self.user.name = apiUser.name
                self.user.userName = apiUser.username ?? "" // Handle optional username
                self.user.bio = apiUser.bio
                self.user.email = apiUser.email
                self.user.profilePictureUrl = apiUser.profilePictureUrl
                self.user.privacyToggle = apiUser.privacyToggle
                self.user.followerCount = profileData.followerCount
                self.user.followingCount = profileData.followingCount
                
                // Load profile picture
                if let profilePicUrl = apiUser.profilePictureUrl,
                   let image = await OptimizedMediaService.shared.loadImage(from: profilePicUrl, priority: .high) {
                    self.profileImage = image
                    self.user.profilePicture = image // Also update user model
                }
                
                // Cache the profile data
                // CRITICAL: Use profileUserId for cache key to ensure consistency
                let cacheKey = profileUserId
                Self.profileCache[cacheKey] = CachedProfile(
                    profile: self.user,
                    followerCount: self.followerCount,
                    followingCount: self.followingCount,
                    timestamp: Date(),
                    isCurrentUser: true
                )
                
                self.hasBeenLoaded = true
                self.isLoadingProfile = false
                // Don't set isLoading = false here, wait for posts
                
                print("✅ Current user profile loaded from AWS")
                
            } catch {
                print("❌ Error loading current user profile from AWS: \(error.localizedDescription)")
                self.isLoadingProfile = false
                // Don't set isLoading = false here, wait for posts
                self.showErrorBanner(message: "Failed to load profile")
            }
            
            // Wait for posts to complete (they're already loading in parallel)
            // This ensures both operations complete independently
            _ = await postsTask.value
            
            // Both tasks completed, update final loading state
            await MainActor.run {
                if !self.isLoadingPosts {
                    self.isLoading = false
                    self.isLoadingInBackground = false
                }
            }
        }
    }
    
    // Load profile picture from URL string
    private func loadProfilePicture(from urlString: String) async throws -> UIImage? {
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "ProfileViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid file URL"])
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    }
    
    // MARK: - Post Loading
    private func loadPostsWithCache() {
        // CRITICAL: Use profileUserId for cache key to ensure consistency
        let cacheKey = profileUserId
        
        // Check posts cache
        if let cached = Self.postsCache[cacheKey], !cached.isExpired {
            print("📦 Using cached posts data for \(user.userName ?? "unknown") (current user: \(cached.isCurrentUser))")
            self.posts = cached.posts
            self.thoughts = cached.thoughts
            self.postsCount = cached.posts.count + cached.thoughts.count
            self.hasFetchedPosts = true
            return
        }
        
        // Cache miss, fetch fresh posts
        Task {
            await loadUserPosts()
        }
    }
    
    func loadUserPosts() async {
        // CRITICAL: Use the stored profileUserId that never changes, not user.userID which might be updated
        print("📫 [ProfileVM] Starting loadUserPosts from AWS")
        print("📫 [ProfileVM] profileUserId: \(profileUserId), profileUsername: \(profileUsername ?? "unknown")")
        print("📫 [ProfileVM] isCurrentUserProfile: \(isCurrentUserProfile)")
        print("📫 [ProfileVM] self.user.userID: \(self.user.userID ?? "nil") (may be different from profileUserId)")
        
        // Respect privacy: if profile is private and not own profile and not following, don't fetch posts
        if (user.privacyToggle ?? false) && !isCurrentUserProfile && !isFollowing {
            print("🔒 Profile is private and not following; skipping posts fetch")
            await MainActor.run {
                self.posts = []
                self.thoughts = []
                self.hasFetchedPosts = true
                self.isLoading = false
                self.isLoadingInBackground = false
            }
            return
        }
        
        await MainActor.run {
            self.isLoadingPosts = true
            self.isLoading = true
            self.isLoadingInBackground = true
        }
        
        // CRITICAL: Create a minimal UserModel from profileUserId/profileUsername for ID resolution
        // This ensures we always use the correct user IDs, even if self.user has been updated
        var profileUserModel = UserModel()
        profileUserModel.userID = profileUserId
        profileUserModel.userName = profileUsername
        
        // Get user IDs to try (resilient to both Parse and Cognito IDs)
        let userIdsToTry = UserIDResolver.shared.getUserIdsForDataFetch(userModel: profileUserModel)
        print("📫 [ProfileVM] User IDs to try for posts: \(userIdsToTry), profileUserId: \(profileUserId), isCurrentUser: \(isCurrentUserProfile)")
        
        guard !userIdsToTry.isEmpty else {
            print("❌ Profile user ID not available")
            await MainActor.run {
                self.isLoadingPosts = false
                self.isLoading = false
                self.showErrorBanner(message: "Failed to load posts")
            }
            return
        }
        
        // Reset pagination tracking state when loading fresh
        await MainActor.run {
            self.paginationAttempts = 0
            self.seenNextKeys.removeAll()
            self.seenPostIds.removeAll()
        }
        
        // Try fetching posts with each user ID until we get results
        var fetchedPosts: [Post] = []
        var nextKey: String?
        var lastError: Error?
        var successfulUserId: String? // Track which user ID worked
        
        for userId in userIdsToTry {
            do {
                let result: (posts: [Post], nextKey: String?)
                
                if isCurrentUserProfile {
                    print("👤 [ProfileVM] Fetching MY posts (isCurrentUserProfile=true)")
                    print("👤 [ProfileVM] Using user ID: \(userId) (Parse ID: \(UserIDResolver.shared.isParseUserId(userId)))")
                    result = try await FeedAPIService.shared.fetchMyPosts(currentUserId: userId, limit: 100)
                } else {
                    print("👤 [ProfileVM] Fetching OTHER USER's posts (isCurrentUserProfile=false)")
                    print("👤 [ProfileVM] profileUserId: \(profileUserId), using user ID: \(userId) (Parse ID: \(UserIDResolver.shared.isParseUserId(userId)))")
                    result = try await FeedAPIService.shared.fetchUserPosts(userId: userId, limit: 100)
                }
                
                // If we got posts, use this user ID
                if !result.posts.isEmpty {
                    fetchedPosts = result.posts
                    nextKey = result.nextKey
                    successfulUserId = userId // Track the successful user ID
                    print("✅ [ProfileVM] Successfully fetched \(fetchedPosts.count) posts")
                    print("   - Using user ID: \(userId)")
                    print("   - profileUserId: \(profileUserId)")
                    print("   - isCurrentUserProfile: \(isCurrentUserProfile)")
                    // Verify the posts belong to the correct user
                    if let firstPost = fetchedPosts.first {
                        print("   - First post userId: \(firstPost.userId ?? "nil")")
                        if firstPost.userId != profileUserId && !isCurrentUserProfile {
                            print("⚠️ [ProfileVM] WARNING: Post userId (\(firstPost.userId ?? "nil")) doesn't match profileUserId (\(profileUserId))!")
                        }
                    }
                    break
                } else {
                    // Even if no posts, if the API call succeeded, use this user ID
                    successfulUserId = userId
                    print("⚠️ [ProfileVM] No posts found for user ID: \(userId), but API call succeeded. Will use this ID for pagination.")
                    break
                }
            } catch {
                print("⚠️ [ProfileVM] Error fetching posts with user ID \(userId): \(error.localizedDescription)")
                lastError = error
                // Continue to next user ID
            }
        }
        
        // If we still have no posts but no errors, that's okay (user might not have posts)
        // If we have errors for all IDs, report the last one
        if successfulUserId == nil && lastError != nil {
            print("❌ [ProfileVM] Failed to fetch posts with all user IDs")
            await MainActor.run {
                self.isLoadingPosts = false
                self.isLoading = false
                self.showErrorBanner(message: "Failed to load posts")
            }
            return
        }
        
        // Use the successful user ID (or first available if none worked but no error)
        guard let userId = successfulUserId ?? userIdsToTry.first else {
            print("❌ [ProfileVM] No user ID available for processing posts")
            await MainActor.run {
                self.isLoadingPosts = false
                self.isLoading = false
            }
            return
        }
        
        // Process the fetched posts
        // Capture userId for use throughout this block
        let finalUserId = userId
        do {
            let fetchedPosts = fetchedPosts
            let nextKey = nextKey
            
            
            // DON'T mark initial nextKey as "seen" - it needs to be available for first pagination
            // Only mark nextKeys as "seen" when we're about to use them in loadMorePosts()
            // This prevents blocking the first auto-pagination call
            
            print("✅ Received \(fetchedPosts.count) posts from AWS")
            
            // Separate posts by type IMMEDIATELY (no processing needed)
            var processedPosts: [Post] = []
            var processedThoughts: [Post] = []
            
            // Create UserModel from profile user for createdBy field
            let profileUserModel = UserModel(
                userID: user.userID,
                userName: user.userName,
                name: user.name,
                email: user.email,
                profilePictureUrl: user.profilePictureUrl
            )
            
            for var post in fetchedPosts {
                // Populate createdBy with profile user data (all posts in profile belong to this user)
                if post.createdBy == nil {
                    post.createdBy = profileUserModel
                }
                
                if post.postType == "postThoughts" {
                    processedThoughts.append(post)
                } else {
                    processedPosts.append(post)
                }
            }
            
            // CRITICAL: Check if posts already exist BEFORE updating
            // This prevents resetting posts when loadUserPosts() is called multiple times
            let postsAlreadyExist = await MainActor.run {
                !self.posts.isEmpty || !self.thoughts.isEmpty
            }
            
            if postsAlreadyExist {
                print("⚠️ [ProfileVM] Posts already loaded (\(await MainActor.run { self.posts.count + self.thoughts.count })), skipping reset to prevent infinite loop")
                await MainActor.run {
                    self.isLoadingPosts = false
                    self.isLoading = false
                    self.isLoadingInBackground = false
                    // Mark as fetched so it doesn't reload
                    self.hasFetchedPosts = true
                }
                return // Exit early - don't reset posts or trigger auto-pagination
            }
            
            // Update UI IMMEDIATELY with initial posts (no media yet)
            await MainActor.run {
                // Track initial post IDs
                for post in processedPosts + processedThoughts {
                    if let postId = post.objectId {
                        self.seenPostIds.insert(postId)
                    }
                }
                
                self.posts = processedPosts
                self.thoughts = processedThoughts
                self.postsCount = processedPosts.count + processedThoughts.count
                self.postsNextKey = nextKey
                self.hasMorePosts = nextKey != nil
                self.isLoadingPosts = false
                self.isLoading = false
                print("✅ \(self.postsCount) posts displayed (loading media in background)")
                print("🔍 [ProfileVM] Tracked \(self.seenPostIds.count) post IDs, \(self.seenNextKeys.count) nextKeys")
            }
            
            // Load media for all posts in parallel (in background, don't wait)
            Task.detached(priority: .userInitiated) {
                await processedPosts.loadMediaBatch(maxConcurrent: 10)
                await processedThoughts.loadMediaBatch(maxConcurrent: 5)
                print("✅ All post media loaded in background")
            }
            
            await MainActor.run {
                print("✅ All posts loaded from AWS")
                self.hasFetchedPosts = true
                self.isLoadingInBackground = false
                
                // Cache the posts data with smart expiration
                // CRITICAL: Use profileUserId for cache key to ensure consistency
                let cacheKey = profileUserId
                Self.postsCache[cacheKey] = CachedPosts(
                    posts: processedPosts,
                    thoughts: processedThoughts,
                    timestamp: Date(),
                    isCurrentUser: self.isCurrentUserProfile
                )
                
                // Also cache under current user ID if this is current user (for backward compatibility)
                if self.isCurrentUserProfile, let currentId = AWSCognitoAuth.shared.getCurrentUserId(), currentId != profileUserId {
                    Self.postsCache[currentId] = Self.postsCache[cacheKey]
                }
                print("📦 Posts cached for future use")
            }

            // OPTIMIZED PAGINATION: Load all remaining posts efficiently
            // Strategy: Load in larger batches (100) and continue until no more posts
            let finalPostCount = await MainActor.run { self.posts.count + self.thoughts.count }
            let finalNextKey = await MainActor.run { self.postsNextKey }
            let finalHasMore = await MainActor.run { self.hasMorePosts }
            
            print("📊 [ProfileVM] Initial load complete - Posts: \(finalPostCount), nextKey: \(finalNextKey?.prefix(20) ?? "nil")..., hasMore: \(finalHasMore)")
            
            if let nextKey = nextKey {
                print("🔄 [ProfileVM] More posts available - loading all remaining posts...")
                print("🔄 [ProfileVM] - nextKey: \(nextKey.prefix(50))...")
                print("🔄 [ProfileVM] - nextKey length: \(nextKey.count)")
                print("🔄 [ProfileVM] - Current posts: \(finalPostCount)")
                
                // Load all remaining posts in background efficiently
                // Use larger batches and continue until done
                // Capture userId explicitly for use in the detached task
                let capturedUserId = finalUserId
                let isCurrentUser = isCurrentUserProfile
                Task.detached(priority: .userInitiated) { [weak self, capturedUserId] in
                    guard let self = self else { return }
                    
                    print("🚀 [ProfileVM] Background pagination task STARTED")
                    var currentNextKey: String? = nextKey
                    var totalLoaded = finalPostCount
                    var batchNumber = 1
                    
                    while let key = currentNextKey {
                        let attempts = await MainActor.run { self.paginationAttempts }
                        
                        // Safety: Stop if we've tried too many times
                        if attempts >= self.maxPaginationAttempts {
                            print("⚠️ [ProfileVM] Stopping - max attempts reached (\(attempts))")
                            break
                        }
                        
                        print("📦 [ProfileVM] Loading batch #\(batchNumber) (current total: \(totalLoaded))...")
                        
                        do {
                            let result: (posts: [Post], nextKey: String?)
                            
                            if isCurrentUser {
                                result = try await FeedAPIService.shared.fetchMyPosts(
                                    currentUserId: capturedUserId,
                                    limit: 100,
                                    lastKey: key
                                )
                            } else {
                                result = try await FeedAPIService.shared.fetchUserPosts(
                                    userId: capturedUserId,
                                    limit: 100,
                                    lastKey: key
                                )
                            }
                            
                            let newPosts = result.posts
                            currentNextKey = result.nextKey
                            
                            if newPosts.isEmpty {
                                print("📦 [ProfileVM] Batch #\(batchNumber) returned 0 posts - done")
                                break
                            }
                            
                            // Process and append posts
                            var newPostsList: [Post] = []
                            var newThoughtsList: [Post] = []
                            
                            for post in newPosts {
                                if post.postType == "postThoughts" {
                                    newThoughtsList.append(post)
                                } else {
                                    newPostsList.append(post)
                                }
                            }
                            
                            await MainActor.run {
                                // Filter duplicates
                                let existingIds = Set(self.posts.compactMap { $0.objectId } + self.thoughts.compactMap { $0.objectId })
                                let uniquePosts = newPostsList.filter { post in
                                    guard let id = post.objectId else { return true }
                                    return !existingIds.contains(id)
                                }
                                let uniqueThoughts = newThoughtsList.filter { post in
                                    guard let id = post.objectId else { return true }
                                    return !existingIds.contains(id)
                                }
                                
                                self.posts.append(contentsOf: uniquePosts)
                                self.thoughts.append(contentsOf: uniqueThoughts)
                                self.postsCount = self.posts.count + self.thoughts.count
                                self.postsNextKey = currentNextKey
                                self.hasMorePosts = currentNextKey != nil
                                self.paginationAttempts += 1
                                
                                totalLoaded = self.posts.count + self.thoughts.count
                            }
                            
                            print("✅ [ProfileVM] Batch #\(batchNumber) loaded: \(newPosts.count) posts (total now: \(totalLoaded))")
                            
                            if currentNextKey == nil {
                                print("✅ [ProfileVM] All posts loaded! Total: \(totalLoaded)")
                                await MainActor.run {
                                    self.hasMorePosts = false
                                }
                                break
                            }
                            
                            batchNumber += 1
                            
                            // Small delay between batches to avoid hammering API
                            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                            
                        } catch {
                            print("❌ [ProfileVM] Error loading batch #\(batchNumber): \(error)")
                            break
                        }
                    }
                    
                    print("✅ [ProfileVM] Background pagination COMPLETE - Final total: \(totalLoaded) posts")
                }
            } else {
                print("✅ [ProfileVM] All posts loaded in initial batch (total: \(finalPostCount))")
                await MainActor.run {
                    self.hasMorePosts = false
                }
            }

            // Backfill interaction counts in background
            Task {
                await self.backfillMissingInteractionCounts()
            }
            
        } catch {
            print("❌ Error fetching posts from AWS: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoadingPosts = false
                self.isLoading = false
                self.isLoadingInBackground = false
                self.showErrorBanner(message: "Failed to load posts")
            }
        }
    }
    
    // MARK: - Load More Posts (Pagination)
    func loadMorePosts() async {
        let callTime = Date().timeIntervalSince(AppDelegate.appStartTime)
        print("🔄 [ProfileVM] ========== loadMorePosts() CALLED at +\(String(format: "%.2f", callTime))s ==========")
        
        // Log comprehensive state snapshot
        let initialState = await MainActor.run {
            (hasMore: hasMorePosts,
             isLoadingMore: isLoadingMorePosts,
             isLoadingPosts: isLoadingPosts,
             nextKey: postsNextKey,
             postCount: posts.count + thoughts.count,
             attempts: paginationAttempts,
             seenKeysCount: seenNextKeys.count,
             seenPostIdsCount: seenPostIds.count)
        }
        
        print("📊 [ProfileVM] Initial state snapshot:")
        print("   - hasMorePosts: \(initialState.hasMore)")
        print("   - isLoadingMorePosts: \(initialState.isLoadingMore)")
        print("   - isLoadingPosts: \(initialState.isLoadingPosts)")
        print("   - postsNextKey: \(initialState.nextKey?.prefix(50) ?? "nil")...")
        print("   - Total posts: \(initialState.postCount)")
        print("   - Pagination attempts: \(initialState.attempts)/\(maxPaginationAttempts)")
        print("   - Seen nextKeys: \(initialState.seenKeysCount)")
        print("   - Seen post IDs: \(initialState.seenPostIdsCount)")
        
        // Only load if we have more posts and aren't already loading
        let canLoad = initialState.hasMore && !initialState.isLoadingMore && !initialState.isLoadingPosts
        
        print("🔍 [ProfileVM] Guard check result: canLoad=\(canLoad)")
        if !canLoad {
            print("   - hasMorePosts: \(initialState.hasMore) ❌" + (initialState.hasMore ? "" : " (BLOCKING)"))
            print("   - isLoadingMorePosts: \(initialState.isLoadingMore) ❌" + (initialState.isLoadingMore ? " (BLOCKING)" : ""))
            print("   - isLoadingPosts: \(initialState.isLoadingPosts) ❌" + (initialState.isLoadingPosts ? " (BLOCKING)" : ""))
        }
        
        guard canLoad else {
            print("⏭️ [ProfileVM] Skipping loadMorePosts - guards failed (see details above)")
            return
        }
        
        // CRITICAL: Use profileUserId, not user.userID
        guard !profileUserId.isEmpty else {
            print("❌ [ProfileVM] No profileUserId for pagination")
            return
        }
        let userId = profileUserId
        
        guard let nextKey = initialState.nextKey else {
            print("❌ [ProfileVM] No nextKey for pagination (postsNextKey is nil)")
            await MainActor.run {
                self.hasMorePosts = false
            }
            return
        }
        
        print("✅ [ProfileVM] All guards passed, proceeding with API call")
        
        // CRITICAL: Check if we've already used this nextKey before making API call
        // This prevents infinite loops when API returns same key
        let alreadyUsed = await MainActor.run {
            if self.seenNextKeys.contains(nextKey) {
                print("⚠️ [ProfileVM] nextKey already used before - stopping pagination to prevent loop")
                self.hasMorePosts = false
                self.postsNextKey = nil
                return true
            }
            return false
        }
        
        guard !alreadyUsed else {
            print("⏭️ [ProfileVM] Skipping loadMorePosts - nextKey already used")
            return
        }
        
        // Mark this nextKey as used BEFORE fetching to prevent duplicate requests
        // This is the first time we're actually using this key
        await MainActor.run {
            self.seenNextKeys.insert(nextKey)
            print("🔍 [ProfileVM] Marking nextKey as used (total seen: \(self.seenNextKeys.count))")
        }
        
        print("✅ [ProfileVM] Starting loadMorePosts with nextKey: \(nextKey.prefix(20))...")
        print("🔍 [ProfileVM] Current posts count: \(await MainActor.run { self.posts.count }), thoughts: \(await MainActor.run { self.thoughts.count })")
        print("🔍 [ProfileVM] Seen post IDs count: \(await MainActor.run { self.seenPostIds.count })")
        print("🔍 [ProfileVM] Using profileUserId: \(profileUserId), isCurrentUserProfile: \(isCurrentUserProfile)")
        
        await MainActor.run {
            self.isLoadingMorePosts = true
        }
        
        do {
            let result: (posts: [Post], nextKey: String?)
            
            print("🔍 [ProfileVM] Calling API with lastKey: \(nextKey.prefix(50))...")
            print("🔍 [ProfileVM] Fetching posts for profileUserId: \(profileUserId), isCurrentUser: \(isCurrentUserProfile)")
            
            if isCurrentUserProfile {
                result = try await FeedAPIService.shared.fetchMyPosts(currentUserId: userId, limit: 100, lastKey: nextKey)
            } else {
                result = try await FeedAPIService.shared.fetchUserPosts(userId: userId, limit: 100, lastKey: nextKey)
            }
            
            print("🔍 [ProfileVM] API returned \(result.posts.count) posts, nextKey: \(result.nextKey?.prefix(50) ?? "nil")...")
            
            let fetchedPosts = result.posts
            let newNextKey = result.nextKey
            
            // Create UserModel from profile user for createdBy field
            let profileUserModel = UserModel(
                userID: user.userID,
                userName: user.userName,
                name: user.name,
                email: user.email,
                profilePictureUrl: user.profilePictureUrl
            )
            
            // Separate posts by type
            var newPosts: [Post] = []
            var newThoughts: [Post] = []
            
            for var post in fetchedPosts {
                // Populate createdBy with profile user data (all posts in profile belong to this user)
                if post.createdBy == nil {
                    post.createdBy = profileUserModel
                }
                
                if post.postType == "postThoughts" {
                    newThoughts.append(post)
                } else {
                    newPosts.append(post)
                }
            }
            
            await MainActor.run {
                let oldCount = self.posts.count + self.thoughts.count
                
                // CRITICAL: Filter out duplicate posts by objectId BEFORE appending
                let existingPostIds = Set(self.posts.compactMap { $0.objectId } + self.thoughts.compactMap { $0.objectId })
                
                let uniqueNewPosts = newPosts.filter { post in
                    guard let postId = post.objectId else { return true } // Include posts without IDs
                    return !existingPostIds.contains(postId)
                }
                
                let uniqueNewThoughts = newThoughts.filter { post in
                    guard let postId = post.objectId else { return true }
                    return !existingPostIds.contains(postId)
                }
                
                let duplicateCount = (newPosts.count + newThoughts.count) - (uniqueNewPosts.count + uniqueNewThoughts.count)
                if duplicateCount > 0 {
                    print("⚠️ [ProfileVM] Filtered out \(duplicateCount) duplicate posts (already loaded)")
                }
                
                // Only append unique posts
                self.posts.append(contentsOf: uniqueNewPosts)
                self.thoughts.append(contentsOf: uniqueNewThoughts)
                self.postsCount = self.posts.count + self.thoughts.count
                self.postsNextKey = newNextKey
                self.hasMorePosts = newNextKey != nil
                self.isLoadingMorePosts = false
                
                let newCount = uniqueNewPosts.count + uniqueNewThoughts.count
                print("✅ [ProfileVM] Loaded \(newCount) unique new posts (was: \(oldCount), now: \(self.postsCount))")
                print("✅ [ProfileVM] Posts array: \(self.posts.count) posts, \(self.thoughts.count) thoughts")
                print("✅ [ProfileVM] Updated nextKey: \(newNextKey?.prefix(20) ?? "nil")...")
                
                // Update seen post IDs
                for post in uniqueNewPosts + uniqueNewThoughts {
                    if let postId = post.objectId {
                        self.seenPostIds.insert(postId)
                    }
                }
                
                // Update cache with all loaded posts (accumulative)
                // CRITICAL: Use profileUserId for cache key to ensure consistency
                let cacheKey = profileUserId
                Self.postsCache[cacheKey] = CachedPosts(
                    posts: self.posts,
                    thoughts: self.thoughts,
                    timestamp: Date(),
                    isCurrentUser: self.isCurrentUserProfile
                )
                
                // Also cache under current user ID if this is current user (for backward compatibility)
                if self.isCurrentUserProfile, let currentId = AWSCognitoAuth.shared.getCurrentUserId(), currentId != profileUserId {
                    Self.postsCache[currentId] = Self.postsCache[cacheKey]
                }
            }
            
            // Load media in background
            Task.detached(priority: .userInitiated) {
                await newPosts.loadMediaBatch(maxConcurrent: 10)
                await newThoughts.loadMediaBatch(maxConcurrent: 5)
            }
            
            // AUTOMATIC CONTINUATION: Continue loading if more available
            // CRITICAL: Add comprehensive safety checks to prevent infinite loops
            let finalPostCount = await MainActor.run { self.posts.count + self.thoughts.count }
            print("📊 [ProfileVM] After append - Total posts now: \(finalPostCount)")
            
            if let newNextKey = newNextKey {
                await MainActor.run {
                    self.paginationAttempts += 1
                }
                
                let attempts = await MainActor.run { self.paginationAttempts }
                let seenKeysBefore = await MainActor.run { self.seenNextKeys.count }
                
                print("🔍 [ProfileVM] Continuation check:")
                print("   - New nextKey: \(newNextKey.prefix(50))... (length: \(newNextKey.count))")
                print("   - Pagination attempts: \(attempts)/\(self.maxPaginationAttempts)")
                print("   - Seen keys count: \(seenKeysBefore)")
                
                // Safety check 1: Max pagination attempts reached
                if attempts >= self.maxPaginationAttempts {
                    print("⚠️ [ProfileVM] ❌ Safety check #1 FAILED - max attempts reached (\(attempts)/\(self.maxPaginationAttempts))")
                    await MainActor.run {
                        self.hasMorePosts = false
                        self.postsNextKey = nil
                    }
                    print("⚠️ [ProfileVM] Stopping pagination due to max attempts")
                    return
                } else {
                    print("✅ [ProfileVM] Safety check #1 PASSED - attempts within limit")
                }
                
                // Safety check 2: Only continue if we actually got NEW unique posts
                print("🔍 [ProfileVM] Safety check #2 - Checking for unique new posts...")
                let uniqueNewCount = await MainActor.run {
                    let existingPostIds = Set(self.posts.compactMap { $0.objectId } + self.thoughts.compactMap { $0.objectId })
                    let uniquePosts = newPosts.filter { post in
                        guard let postId = post.objectId else { return true }
                        return !existingPostIds.contains(postId)
                    }
                    let uniqueThoughts = newThoughts.filter { post in
                        guard let postId = post.objectId else { return true }
                        return !existingPostIds.contains(postId)
                    }
                    return (uniquePosts.count + uniqueThoughts.count, existingPostIds.count, newPosts.count + newThoughts.count)
                }
                
                print("   - New posts received: \(uniqueNewCount.2)")
                print("   - Existing post IDs: \(uniqueNewCount.1)")
                print("   - Unique new posts: \(uniqueNewCount.0)")
                
                if uniqueNewCount.0 == 0 {
                    print("⚠️ [ProfileVM] ❌ Safety check #2 FAILED - received 0 unique new posts (all were duplicates)")
                    await MainActor.run {
                        self.hasMorePosts = false
                        self.postsNextKey = nil
                    }
                    print("⚠️ [ProfileVM] Stopping pagination - no unique posts")
                    return
                } else {
                    print("✅ [ProfileVM] Safety check #2 PASSED - got \(uniqueNewCount.0) unique new posts")
                }
                
                // Safety check 3: If nextKey is the same as before, we're in a loop
                print("🔍 [ProfileVM] Safety check #3 - Comparing nextKeys...")
                print("   - Previous nextKey: \(nextKey.prefix(50))...")
                print("   - New nextKey: \(newNextKey.prefix(50))...")
                print("   - Keys are equal: \(newNextKey == nextKey)")
                
                if newNextKey == nextKey {
                    print("⚠️ [ProfileVM] ❌ Safety check #3 FAILED - nextKey unchanged (possible loop)")
                    await MainActor.run {
                        self.hasMorePosts = false
                        self.postsNextKey = nil
                    }
                    print("⚠️ [ProfileVM] Stopping pagination - nextKey unchanged")
                    return
                } else {
                    print("✅ [ProfileVM] Safety check #3 PASSED - nextKey changed")
                }
                
                // Safety check 4: If we've seen this nextKey before, we're in a loop
                print("🔍 [ProfileVM] Safety check #4 - Checking if newNextKey was seen before...")
                let seenKeysBeforeCheck = await MainActor.run { self.seenNextKeys.count }
                print("   - Seen keys count before check: \(seenKeysBeforeCheck)")
                
                let alreadySeen = await MainActor.run {
                    if self.seenNextKeys.contains(newNextKey) {
                        return true
                    }
                    self.seenNextKeys.insert(newNextKey)
                    return false
                }
                
                let seenKeysAfterCheck = await MainActor.run { self.seenNextKeys.count }
                print("   - New nextKey already seen: \(alreadySeen)")
                print("   - Seen keys count after check: \(seenKeysAfterCheck)")
                
                if alreadySeen {
                    print("⚠️ [ProfileVM] ❌ Safety check #4 FAILED - nextKey already seen before (infinite loop detected)")
                    await MainActor.run {
                        self.hasMorePosts = false
                        self.postsNextKey = nil
                    }
                    print("⚠️ [ProfileVM] Stopping pagination - nextKey already seen")
                    return
                } else {
                    print("✅ [ProfileVM] Safety check #4 PASSED - new nextKey not seen before")
                }
                
                print("✅ [ProfileVM] All safety checks passed! Continuing pagination...")
                print("🔄 [ProfileVM] Auto-loading next batch (attempt \(attempts)/\(self.maxPaginationAttempts))...")
                print("🔄 [ProfileVM] Next nextKey: \(newNextKey.prefix(50))...")
                
                // Small delay to prevent hammering the API
                print("🔄 [ProfileVM] Waiting 0.3s before next batch...")
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                
                // Continue loading in background (recursive but safe with guards)
                let continuationTask = Task { [weak self] in
                    print("🚀 [ProfileVM] Continuation task STARTED")
                    await self?.loadMorePosts()
                    print("✅ [ProfileVM] Continuation task COMPLETED")
                }
                print("🔄 [ProfileVM] Continuation task created: \(continuationTask)")
            } else {
                print("✅ [ProfileVM] All posts loaded (no more pages)")
                await MainActor.run {
                    self.hasMorePosts = false
                }
                
                // Final summary
                let finalCount = await MainActor.run { self.posts.count + self.thoughts.count }
                print("📊 [ProfileVM] Pagination complete - Total posts loaded: \(finalCount)")
            }
            
        } catch {
            print("❌ [ProfileVM] Error in loadMorePosts: \(error)")
            
            // Log error details for debugging
            if let urlError = error as? URLError {
                print("❌ [ProfileVM] URL Error: \(urlError.localizedDescription), code: \(urlError.code.rawValue)")
            } else if let decodingError = error as? DecodingError {
                print("❌ [ProfileVM] Decoding Error: \(decodingError.localizedDescription)")
            }
            print("❌ Error loading more posts: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoadingMorePosts = false
                // Don't mark as no more posts on error - allow retry
            }
        }
    }
    
    // Helper method to get all posts (including thoughts)
    var allPosts: [Post] {
        posts + thoughts
    }
    
    // Helper method to get posts by type
    func getPosts(ofType type: String? = nil) -> [Post] {
        if let type = type {
            return allPosts.filter { $0.postType == type }
        }
        return allPosts
    }
    
    // Original fetchPosts() has been replaced by loadUserPosts()
    
    func checkFollowStatus() async {
        print("🔍 Checking follow status from AWS")
        guard !isCurrentUserProfile else {
            print("⚠️ Skipping follow check for own profile")
            return
        }
        
        guard let currentUserId = AWSCognitoAuth.shared.getCurrentUserId() ?? CurrentUserService.shared.userID else {
            print("❌ No current user ID found for follow check")
            return
        }
        
        // CRITICAL: Use profileUserId, not user.userID
        guard !profileUserId.isEmpty else {
            print("❌ No profileUserId found for follow check")
            return
        }
        
        print("👥 Checking if user \(currentUserId) follows \(profileUserId) via AWS")
        do {
            let followStatus = try await ProfileAPIService.shared.checkFollowStatus(
                userId: currentUserId,
                targetUserId: profileUserId
            )
            
            await MainActor.run {
                self.isFollowing = followStatus.isFollowing && (followStatus.accepted ?? true)
                self.followRequestPending = followStatus.pending ?? false
                print("📊 Follow accepted: \(self.isFollowing), pending: \(self.followRequestPending)")
            }
        } catch {
            print("❌ Error checking follow status from AWS: \(error.localizedDescription)")
        }
    }
    
    // Legacy support for completion handler style
    func checkFollowStatus(completion: @escaping (Bool) -> Void) {
        Task {
            await checkFollowStatus()
            await MainActor.run {
                completion(isFollowing)
            }
        }
    }
    
    func fetchFollowCounts() async {
        print("📊 Starting to fetch follow counts")
        // CRITICAL: Use profileUserId, not user.userID
        guard !profileUserId.isEmpty else {
            print("❌ No profileUserId found for fetching follow counts")
            return
        }
        
        print("👤 Fetching counts for profileUserId: \(profileUserId)")
        
        do {
            // Use ProfileAPIService to get follow counts
            guard let currentUserId = AWSCognitoAuth.shared.getCurrentUserId() ?? CurrentUserService.shared.userID else {
                print("❌ No current user ID found")
                return
            }
            
            let profileResponse = try await ProfileAPIService.shared.fetchUserProfile(
                userId: profileUserId,
                currentUserId: currentUserId,
                includeFollowers: false,
                includeFollowing: false
            )
            
            guard let profileData = profileResponse.data else {
                print("❌ No profile data returned")
                return
            }
            
            await MainActor.run {
                self.followerCount = profileData.followerCount
                self.followingCount = profileData.followingCount
                print("✅ Follow counts updated - Followers: \(self.followerCount), Following: \(self.followingCount)")
            }
        } catch {
            print("❌ Error fetching follow counts: \(error)")
            print("❌ Error details: \(error)")
        }
    }
    
    func toggleFollow() async {
        guard !isCurrentUserProfile else { return }
        
        guard let currentUserId = AWSCognitoAuth.shared.getCurrentUserId() ?? CurrentUserService.shared.userID else {
            print("❌ No current user ID found for follow toggle")
            return
        }
        
        // CRITICAL: Use profileUserId, not user.userID
        guard !profileUserId.isEmpty else {
            print("❌ No profileUserId found for follow toggle")
            return
        }
        let targetUserId = profileUserId
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        do {
            if isFollowing {
                // Unfollow action via AWS
                print("🔄 Unfollowing user \(targetUserId) via AWS")
                try await ProfileAPIService.shared.unfollowUser(
                    followerId: currentUserId,
                    followingId: targetUserId
                )
                
                // Update UI
                await MainActor.run {
                    self.isFollowing = false
                    if self.followerCount > 0 {
                        self.followerCount -= 1
                    }
                    let banner = NotificationBanner(title: "Unfollowed @\(self.username)", style: .info)
                    banner.show(bannerPosition: .top)
                }
            } else {
                // Follow action via AWS
                print("🔄 Following user \(targetUserId) via AWS")
                let _ = try await ProfileAPIService.shared.followUser(
                    followerId: currentUserId,
                    followingId: targetUserId
                )
                
                // Update UI
                await MainActor.run {
                    self.isFollowing = true
                    self.followerCount += 1
                    let banner = NotificationBanner(title: "Following @\(self.username)", style: .success)
                    banner.show(bannerPosition: .top)
                }
            }
        } catch {
            print("❌ Error toggling follow via AWS: \(error.localizedDescription)")
            await MainActor.run {
                self.showErrorBanner(message: "Failed to \(self.isFollowing ? "unfollow" : "follow") user")
            }
        }
    }
    
    // Helper function to get image from URL
    private func getImageFromURL(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("Error loading image: \(error.localizedDescription)")
            return nil
        }
    }
    
    func showFollowersList() {
        // Privacy check: if viewing another user's private profile and not following, don't show followers
        if !isCurrentUserProfile && (user.privacyToggle ?? false) && !isFollowing {
            print("🔒 Cannot view followers: profile is private and not following")
            showErrorBanner(message: "This user's followers are private")
            return
        }
        
        // CRITICAL: Create a fresh UserModel with profileUserId/profileUsername to ensure correct data
        // Don't use self.user as it might have been overwritten with current user data
        var profileUser = UserModel()
        profileUser.userID = profileUserId
        profileUser.userName = profileUsername
        // Copy other relevant fields from self.user for display purposes
        profileUser.name = self.user.name
        profileUser.email = self.user.email
        profileUser.profilePictureUrl = self.user.profilePictureUrl
        profileUser.privacyToggle = self.user.privacyToggle
        profileUser.bio = self.user.bio
        
        // ModernUserListViewController now handles its own loading with intelligent pagination
        // Just present the view controller - it will load data efficiently
        let vc = ModernUserListViewController()
        vc.users = [] // Start empty - will load on viewDidLoad
        vc.currentUser = profileUser // Use the profile's user with correct ID
        vc.listType = .followers
        vc.modalPresentationStyle = .overFullScreen
        
        print("👥 [ProfileVM] Showing followers list for profileUserId: \(profileUserId), userName: \(profileUsername ?? "nil")")
        
        let transition = CATransition()
        transition.duration = 0.3
        transition.type = .push
        transition.subtype = .fromRight
        
        // Present safely from the current top-most controller
        self.presentFromTop(vc, transition: transition)
    }
    
    func showFollowingList() {
        // Privacy check: if viewing another user's private profile and not following, don't show following
        if !isCurrentUserProfile && (user.privacyToggle ?? false) && !isFollowing {
            print("🔒 Cannot view following: profile is private and not following")
            showErrorBanner(message: "This user's following list is private")
            return
        }
        
        // CRITICAL: Create a fresh UserModel with profileUserId/profileUsername to ensure correct data
        // Don't use self.user as it might have been overwritten with current user data
        var profileUser = UserModel()
        profileUser.userID = profileUserId
        profileUser.userName = profileUsername
        // Copy other relevant fields from self.user for display purposes
        profileUser.name = self.user.name
        profileUser.email = self.user.email
        profileUser.profilePictureUrl = self.user.profilePictureUrl
        profileUser.privacyToggle = self.user.privacyToggle
        profileUser.bio = self.user.bio
        
        // ModernUserListViewController now handles its own loading with intelligent pagination
        // Just present the view controller - it will load data efficiently
        let vc = ModernUserListViewController()
        vc.users = [] // Start empty - will load on viewDidLoad
        vc.currentUser = profileUser // Use the profile's user with correct ID
        vc.listType = .following
        vc.modalPresentationStyle = .overFullScreen
        
        print("👥 [ProfileVM] Showing following list for profileUserId: \(profileUserId), userName: \(profileUsername ?? "nil")")
        
        let transition = CATransition()
        transition.duration = 0.3
        transition.type = .push
        transition.subtype = .fromRight
        
        // Present safely from the current top-most controller
        self.presentFromTop(vc, transition: transition)
    }
    
    func editProfile() {
        Task { @MainActor in
            // Use CurrentUserService to ensure we have the latest user data
            // This is especially important for the current user's profile
            let userToUse: UserModel
            if isCurrentUserProfile {
                // For current user, always use CurrentUserService for latest data
                userToUse = CurrentUserService.shared.user
                print("📝 [Profile] Opening settings with CurrentUserService user: \(userToUse.userID ?? "nil")")
            } else {
                // For other users, use the profile's user model
                userToUse = self.user
                print("📝 [Profile] Opening settings with profile user: \(userToUse.userID ?? "nil")")
            }
            
            let settingsVC = ProfileSettingsHostingController(user: userToUse)
            settingsVC.modalPresentationStyle = .fullScreen
            
            let transition = CATransition()
            transition.duration = 0.3
            transition.type = .push
            transition.subtype = .fromRight
            
            // Present safely from the current top-most controller
            self.presentFromTop(settingsVC, transition: transition)
        }
    }
    
    // MARK: - Safe Presentation Helper
    private func presentFromTop(_ viewController: UIViewController, transition: CATransition? = nil) {
        // Find an active foreground scene and key window
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        guard let window = scenes.first?.windows.first(where: { $0.isKeyWindow }),
              var top = window.rootViewController else {
            return
        }
        // Walk presented chain
        while let presented = top.presentedViewController { top = presented }
        // Apply transition on window layer if provided
        if let transition = transition { window.layer.add(transition, forKey: kCATransition) }
        top.present(viewController, animated: transition == nil)
    }
    
    /// Normalize reaction type from UI format to API format
    private func normalizeReactionType(_ type: String?) -> String? {
        guard let type = type else { return nil }
        switch type.lowercased() {
        case "heart", "fullheart_40": return "heart"
        case "star", "fullstar_40": return "star"
        case "goat", "fullgoat_40": return "goat"
        case "party", "partyfaceemoji": return "party"
        case "clap", "clappingemoji": return "clap"
        case "exploding", "explodingfaceemoji", "explode": return "exploding"
        default: return type.lowercased()
        }
    }
    
    /// Handle interaction toggle (create or delete) for profile posts
    func handleInteraction(postId: String, reactionType: String?) async {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            print("⚠️ [ProfileVM] Cannot handle interaction - no user ID")
            return
        }
        
        // Find post in posts or thoughts array
        var postIndex: Int?
        var isThought = false
        
        if let index = posts.firstIndex(where: { $0.objectId == postId }) {
            postIndex = index
            isThought = false
        } else if let index = thoughts.firstIndex(where: { $0.objectId == postId }) {
            postIndex = index
            isThought = true
        }
        
        guard let index = postIndex else {
            print("⚠️ [ProfileVM] Post not found: \(postId)")
            return
        }
        
        // Get current interaction state
        let currentPost = isThought ? thoughts[index] : posts[index]
        let currentReaction: String? = {
            if currentPost.heartFlag == true { return "heart" }
            if currentPost.starFlag == true { return "star" }
            if currentPost.goatFlag == true { return "goat" }
            return nil
        }()
        
        // Normalize reaction type
        let normalizedType = normalizeReactionType(reactionType)
        
        // Check if this is a toggle (same reaction = remove, different = switch)
        let isTogglingOff = normalizedType == normalizeReactionType(currentReaction)
        let finalReactionType = isTogglingOff ? nil : normalizedType
        
        // Optimistic UI update
        if isThought {
            // updateReaction already handles count updates correctly
            thoughts[index].updateReaction(type: finalReactionType)
        } else {
            // updateReaction already handles count updates correctly
            posts[index].updateReaction(type: finalReactionType)
        }
        
        // Save to API
        do {
            if let reactionType = finalReactionType {
                // Create or update interaction (backend should replace existing)
                let _ = try await InteractionAPIService.shared.createInteraction(
                    userId: userId,
                    postId: postId,
                    reactionType: reactionType
                )
                print("✅ [ProfileVM] Created/updated interaction: \(reactionType) for post \(postId)")
            } else {
                // Delete interaction
                try await InteractionAPIService.shared.deleteInteraction(
                    userId: userId,
                    postId: postId
                )
                print("✅ [ProfileVM] Deleted interaction for post \(postId)")
            }
        } catch {
            print("❌ [ProfileVM] Error handling interaction: \(error)")
            // Rollback optimistic update
            if isThought {
                thoughts[index].updateReaction(type: currentReaction)
            } else {
                posts[index].updateReaction(type: currentReaction)
            }
        }
    }
    
    /// Delete a post from the user's profile
    func deletePost(postId: String) async {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            print("⚠️ [ProfileVM] Cannot delete post - no user ID")
            showErrorBanner(message: "Failed to delete post")
            return
        }
        
        print("🗑️ [ProfileVM] Deleting post: \(postId)")
        
        do {
            // Delete from backend
            let success = try await FeedAPIService.shared.deletePost(postId: postId, userId: userId)
            
            if success {
                // Remove from local arrays
                await MainActor.run {
                    self.posts.removeAll { $0.objectId == postId }
                    self.thoughts.removeAll { $0.objectId == postId }
                    self.postsCount = self.posts.count + self.thoughts.count
                    
                    // Clear cache to force refresh
                    // CRITICAL: Use profileUserId for cache key to ensure consistency
                    let cacheKey = profileUserId
                    Self.clearCacheForUser(cacheKey)
                    
                    print("✅ [ProfileVM] Post deleted successfully")
                    let banner = NotificationBanner(title: "Post deleted", style: .success)
                    banner.show(bannerPosition: .top)
                }
            } else {
                throw NSError(domain: "ProfileError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Delete failed"])
            }
        } catch {
            print("❌ [ProfileVM] Error deleting post: \(error)")
            await MainActor.run {
                showErrorBanner(message: "Failed to delete post")
            }
        }
    }
    
    /// Hide a post from the profile (removes it from view but doesn't delete)
    func hidePost(postId: String) async {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            print("⚠️ [ProfileVM] Cannot hide post - no user ID")
            showErrorBanner(message: "Failed to hide post")
            return
        }
        
        print("👁️ [ProfileVM] Hiding post: \(postId)")
        
        // Remove from local arrays immediately (optimistic update)
        await MainActor.run {
            self.posts.removeAll { $0.objectId == postId }
            self.thoughts.removeAll { $0.objectId == postId }
            self.postsCount = self.posts.count + self.thoughts.count
            
            // Clear cache to force refresh
            // CRITICAL: Use profileUserId for cache key to ensure consistency
            let cacheKey = profileUserId
            Self.clearCacheForUser(cacheKey)
        }
        
        do {
            // Call API to hide post on backend
            let success = try await FeedAPIService.shared.hidePost(postId: postId, userId: userId)
            if success {
                await MainActor.run {
                    let banner = NotificationBanner(title: "Post hidden", style: .success)
                    banner.show(bannerPosition: .top)
                }
                print("✅ [ProfileVM] Post hidden successfully")
            } else {
                throw NSError(domain: "ProfileError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Hide failed"])
            }
        } catch {
            print("❌ [ProfileVM] Error hiding post: \(error)")
            await MainActor.run {
                showErrorBanner(message: "Failed to hide post")
            }
        }
    }
    
    /// Archive a post (removes it from profile but keeps it in user's archive)
    func archivePost(postId: String) async {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            print("⚠️ [ProfileVM] Cannot archive post - no user ID")
            showErrorBanner(message: "Failed to archive post")
            return
        }
        
        print("📦 [ProfileVM] Archiving post: \(postId)")
        
        // Remove from local arrays immediately (optimistic update)
        await MainActor.run {
            self.posts.removeAll { $0.objectId == postId }
            self.thoughts.removeAll { $0.objectId == postId }
            self.postsCount = self.posts.count + self.thoughts.count
            
            // Clear cache to force refresh
            // CRITICAL: Use profileUserId for cache key to ensure consistency
            let cacheKey = profileUserId
            Self.clearCacheForUser(cacheKey)
        }
        
        do {
            // Call API to archive post on backend
            let success = try await FeedAPIService.shared.archivePost(postId: postId, userId: userId)
            if success {
                await MainActor.run {
                    let banner = NotificationBanner(title: "Post archived", style: .success)
                    banner.show(bannerPosition: .top)
                }
                print("✅ [ProfileVM] Post archived successfully")
            } else {
                throw NSError(domain: "ProfileError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Archive failed"])
            }
        } catch {
            print("❌ [ProfileVM] Error archiving post: \(error)")
            await MainActor.run {
                showErrorBanner(message: "Failed to archive post")
            }
        }
    }
    
    /// Report a post for inappropriate content
    func reportPost(postId: String, reason: String? = nil) async {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            print("⚠️ [ProfileVM] Cannot report post - no user ID")
            showErrorBanner(message: "Failed to report post")
            return
        }
        
        print("🚨 [ProfileVM] Reporting post: \(postId), reason: \(reason ?? "No reason provided")")
        
        // Remove from local arrays immediately (optimistic update)
        await MainActor.run {
            self.posts.removeAll { $0.objectId == postId }
            self.thoughts.removeAll { $0.objectId == postId }
            self.postsCount = self.posts.count + self.thoughts.count
            
            // Clear cache to force refresh
            // CRITICAL: Use profileUserId for cache key to ensure consistency
            let cacheKey = profileUserId
            Self.clearCacheForUser(cacheKey)
        }
        
        do {
            // Call API to report post on backend
            let success = try await FeedAPIService.shared.reportPost(postId: postId, userId: userId, reason: reason)
            if success {
                await MainActor.run {
                    let banner = NotificationBanner(title: "Post reported", style: .success)
                    banner.show(bannerPosition: .top)
                }
                print("✅ [ProfileVM] Post reported successfully")
            } else {
                throw NSError(domain: "ProfileError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Report failed"])
            }
        } catch {
            print("❌ [ProfileVM] Error reporting post: \(error)")
            await MainActor.run {
                showErrorBanner(message: "Failed to report post")
            }
        }
    }
    
    private func showErrorBanner(message: String) {
            let banner = NotificationBanner(title: message, style: .danger)
            banner.show(bannerPosition: .top)
        }
    
    deinit {
        // Remove notification observer when view model is deallocated
        if let observer = currentUserUpdatedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
