//
//  FeedViewModel_v2.swift
//  Do
//
//  World-class feed with hybrid algorithm, smart caching, and ranking
//

import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
class FeedViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?
    @Published var hasMorePages = true
    @Published var feedType: FeedType = .hybrid
    @Published var userInteractions: [String: String] = [:] // postId -> reactionType
    
    // MARK: - Feed Configuration
    private var followingRatio: Double = 0.7 // 70% following, 30% FYP
    private let initialLoadCount = 20
    private let paginationCount = 10
    private let prefetchThreshold = 5
    
    // MARK: - Private Properties
    private var followingLastKey: String?
    private var forYouLastKey: String?
    private var currentUserId: String?
    private var cancellables = Set<AnyCancellable>()
    
    // Services
    private let cacheManager = FeedCacheManager.shared
    private let followManager = FollowGraphManager.shared
    
    // Caching
    private var postCache: [String: Post] = [:]
    private var followingPosts: [Post] = []
    private var forYouPosts: [Post] = []
    
    // MARK: - Feed Types
    enum FeedType {
        case following  // Posts from users you follow
        case forYou     // Personalized recommendations
        case hybrid     // Mixed feed (best approach)
    }
    
    // MARK: - Initialization
    init() {
        self.currentUserId = UserIDHelper.shared.getCurrentUserID(silent: true)
        loadCachedData()
    }
    
    // MARK: - Public Methods
    
    /// Initial feed load with smart strategy
    func loadFeed() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        guard let userId = currentUserId else {
            error = "User not logged in"
            return
        }
        
        do {
            // Step 1: Determine feed strategy based on following count
            let followingCount = await followManager.getFollowingCount(userId: userId)
            determineFeedStrategy(followingCount: followingCount)
            
            // Step 2: Load appropriate feed
            switch feedType {
            case .following:
                try await loadFollowingFeed(userId: userId, initial: true)
            case .forYou:
                try await loadForYouFeed(userId: userId, initial: true)
            case .hybrid:
                try await loadHybridFeed(userId: userId, initial: true)
            }
            
            // Step 3: Load user interactions for all posts
            await loadUserInteractions(userId: userId)
            
            // Step 4: Cache the results
            cacheManager.savePosts(posts)
            
            print("✅ [FeedVM] Loaded \(posts.count) posts (\(feedType))")
            
            // Step 5: If we're near the end and have more pages, trigger pagination
            if hasMorePages && posts.count <= initialLoadCount {
                print("🔄 [FeedVM] Initial load returned \(posts.count) posts, triggering pagination to fill feed")
                Task {
                    await loadMore()
                }
            }
            
        } catch {
            self.error = "Failed to load feed: \(error.localizedDescription)"
            print("❌ [FeedVM] Error: \(error)")
        }
    }
    
    /// Load more posts (pagination)
    func loadMore() async {
        guard !isLoadingMore, !isLoading, hasMorePages else {
            print("⏸️ [FeedVM] Load more blocked - isLoadingMore: \(isLoadingMore), isLoading: \(isLoading), hasMorePages: \(hasMorePages)")
            return
        }
        
        print("📄 [FeedVM] Loading more posts... (current count: \(posts.count))")
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        guard let userId = currentUserId else {
            print("⚠️ [FeedVM] No user ID for pagination")
            return
        }
        
        do {
            let beforeCount = posts.count
            switch feedType {
            case .following:
                try await loadFollowingFeed(userId: userId, initial: false)
            case .forYou:
                try await loadForYouFeed(userId: userId, initial: false)
            case .hybrid:
                try await loadHybridFeed(userId: userId, initial: false)
            }
            
            let afterCount = posts.count
            print("✅ [FeedVM] Loaded more: \(afterCount - beforeCount) new posts (total: \(afterCount)), hasMorePages: \(hasMorePages)")
            
            // Load interactions for new posts
            await loadUserInteractions(userId: userId)
            
        } catch {
            print("❌ [FeedVM] Load more error: \(error)")
        }
    }
    
    /// Refresh feed (pull-to-refresh)
    func refresh() async {
        // Reset pagination
        followingLastKey = nil
        forYouLastKey = nil
        posts = []
        followingPosts = []
        forYouPosts = []
        
        // Clear cache to force fresh load
        cacheManager.clearCache()
        
        await loadFeed()
    }
    
    /// Update interaction for a post (optimistic UI update)
    func updateInteraction(postId: String, reactionType: String?) {
        userInteractions[postId] = reactionType
        
        // Update post in array
        if let index = posts.firstIndex(where: { $0.objectId == postId }) {
            // Update local counts (optimistic UI)
            // updateReaction already handles count updates correctly
            posts[index].updateReaction(type: reactionType)
        }
        
        // Persist to cache
        cacheManager.saveInteractions(userInteractions)
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
    
    /// Handle interaction toggle (create or delete)
    func handleInteraction(postId: String, reactionType: String?) async {
        guard let userId = currentUserId else {
            print("⚠️ [FeedVM] Cannot handle interaction - no user ID")
            return
        }
        
        // Get current interaction
        let currentReaction = userInteractions[postId]
        
        // Normalize reaction type
        let normalizedType = normalizeReactionType(reactionType)
        
        // Check if this is a toggle (same reaction = remove, different = switch)
        let isTogglingOff = normalizedType == normalizeReactionType(currentReaction)
        let finalReactionType = isTogglingOff ? nil : normalizedType
        
        // Optimistic UI update
        updateInteraction(postId: postId, reactionType: finalReactionType)
        
        // Save to API
        do {
            if let reactionType = finalReactionType {
                // Create or update interaction (backend should replace existing)
                let _ = try await InteractionAPIService.shared.createInteraction(
                    userId: userId,
                    postId: postId,
                    reactionType: reactionType
                )
                print("✅ [FeedVM] Created/updated interaction: \(reactionType) for post \(postId)")
            } else {
                // Delete interaction
                try await InteractionAPIService.shared.deleteInteraction(
                    userId: userId,
                    postId: postId
                )
                print("✅ [FeedVM] Deleted interaction for post \(postId)")
            }
        } catch {
            print("❌ [FeedVM] Error handling interaction: \(error)")
            // Rollback optimistic update
            updateInteraction(postId: postId, reactionType: currentReaction)
        }
    }
    
    /// Get interaction for a specific post
    func getInteraction(for postId: String) -> String? {
        return userInteractions[postId]
    }
    
    /// Check if should prefetch more posts
    func shouldPrefetch(currentIndex: Int) -> Bool {
        let shouldLoad = currentIndex >= posts.count - prefetchThreshold && hasMorePages && !isLoadingMore && !isLoading
        if shouldLoad {
            print("🔄 [FeedVM] Should prefetch triggered at index \(currentIndex) (total: \(posts.count), threshold: \(prefetchThreshold))")
        }
        return shouldLoad
    }
    
    // MARK: - Private Methods
    
    /// Determine feed strategy based on following count
    private func determineFeedStrategy(followingCount: Int) {
        if followingCount == 0 {
            // New user - show For You only
            feedType = .forYou
            followingRatio = 0.0
        } else if followingCount < 6 {
            // Growing user - mostly For You
            feedType = .hybrid
            followingRatio = 0.3
        } else if followingCount < 21 {
            // Active user - balanced
            feedType = .hybrid
            followingRatio = 0.5
        } else {
            // Established user - mostly following
            feedType = .hybrid
            followingRatio = 0.7
        }
        
        print("📊 [FeedVM] Strategy: \(feedType), following: \(followingCount), ratio: \(followingRatio)")
    }
    
    /// Load following feed
    private func loadFollowingFeed(userId: String, initial: Bool) async throws {
        print("📱 [FeedVM] Loading following feed for user: \(userId)")
        
        let feedAPIService = FeedAPIService.shared
        let response = try await feedAPIService.fetchFeedPosts(
            userId: userId,
            limit: 20,
            lastKey: initial ? nil : followingLastKey
        )
        
        // Posts decode directly from API - no conversion needed
        let newPosts = response.data
        
        if initial {
            posts = newPosts
        } else {
            posts.append(contentsOf: newPosts)
        }
        
        followingLastKey = response.lastEvaluatedKey
        hasMorePages = response.lastEvaluatedKey != nil
    }
    
    /// Load For You feed
    private func loadForYouFeed(userId: String, initial: Bool) async throws {
        print("📱 [FeedVM] Loading For You feed for user: \(userId)")
        
        let feedAPIService = FeedAPIService.shared
        let response = try await feedAPIService.fetchForYouPosts(
            userId: userId,
            limit: 20,
            lastKey: initial ? nil : forYouLastKey
        )
        
        // Posts decode directly from API - no conversion needed
        let newPosts = response.data
        
        if initial {
            posts = newPosts
        } else {
            posts.append(contentsOf: newPosts)
        }
        
        forYouLastKey = response.lastEvaluatedKey
        hasMorePages = response.lastEvaluatedKey != nil
    }
    
    /// Load hybrid feed (following + For You mixed)
    private func loadHybridFeed(userId: String, initial: Bool) async throws {
        // Fetch both feeds in parallel
        async let followingTask = fetchFollowingBatch(userId: userId, initial: initial)
        async let forYouTask = fetchForYouBatch(userId: userId, initial: initial)
        
        let (followingBatch, forYouBatch) = try await (followingTask, forYouTask)
        
        if initial {
            followingPosts = followingBatch
            forYouPosts = forYouBatch
        } else {
            // Only append if we got new posts
            if !followingBatch.isEmpty {
                followingPosts.append(contentsOf: followingBatch)
            }
            if !forYouBatch.isEmpty {
                forYouPosts.append(contentsOf: forYouBatch)
            }
        }
        
        // Mix the feeds based on ratio
        let mixedPosts = mixFeeds(
            following: followingPosts,
            forYou: forYouPosts,
            ratio: followingRatio
        )
        
        if initial {
            posts = mixedPosts
        } else {
            // Append only new posts that aren't already in the list
            let existingIds = Set(posts.compactMap { $0.objectId })
            let newPosts = mixedPosts.filter { post in
                guard let id = post.objectId else { return false }
                return !existingIds.contains(id)
            }
            if !newPosts.isEmpty {
                posts.append(contentsOf: newPosts)
                print("📊 [FeedVM] Added \(newPosts.count) new posts from hybrid feed (total: \(posts.count))")
            } else {
                print("⚠️ [FeedVM] No new posts after mixing (all duplicates)")
            }
        }
        
        // Update hasMorePages - we have more if either feed has more
        hasMorePages = followingLastKey != nil || forYouLastKey != nil
        print("📊 [FeedVM] Pagination state - followingLastKey: \(followingLastKey != nil ? "exists" : "nil"), forYouLastKey: \(forYouLastKey != nil ? "exists" : "nil"), hasMorePages: \(hasMorePages)")
    }
    
    /// Fetch following batch
    private func fetchFollowingBatch(userId: String, initial: Bool) async throws -> [Post] {
        let feedAPIService = FeedAPIService.shared
        let response = try await feedAPIService.fetchFeedPosts(
            userId: userId,
            limit: 10,
            lastKey: initial ? nil : followingLastKey
        )
        
        followingLastKey = response.lastEvaluatedKey
        return response.data
    }
    
    /// Fetch For You batch
    private func fetchForYouBatch(userId: String, initial: Bool) async throws -> [Post] {
        let feedAPIService = FeedAPIService.shared
        let response = try await feedAPIService.fetchForYouPosts(
            userId: userId,
            limit: 10,
            lastKey: initial ? nil : forYouLastKey
        )
        
        forYouLastKey = response.lastEvaluatedKey
        return response.data
    }
    
    /// Mix following and For You feeds
    private func mixFeeds(following: [Post], forYou: [Post], ratio: Double) -> [Post] {
        var mixed: [Post] = []
        var followingIndex = 0
        var forYouIndex = 0
        
        let totalCount = following.count + forYou.count
        let followingTarget = Int(Double(totalCount) * ratio)
        
        // Interleave posts
        while followingIndex < following.count || forYouIndex < forYou.count {
            // Add following posts
            if followingIndex < following.count && mixed.count < followingTarget {
                mixed.append(following[followingIndex])
                followingIndex += 1
                
                // Add another following post to maintain ratio
                if followingIndex < following.count && ratio > 0.5 {
                    mixed.append(following[followingIndex])
                    followingIndex += 1
                }
            }
            
            // Add For You post (every 3rd position)
            if forYouIndex < forYou.count {
                mixed.append(forYou[forYouIndex])
                forYouIndex += 1
            }
        }
        
        return mixed
    }
    
    
    /// Load user's interactions for all posts
    private func loadUserInteractions(userId: String) async {
        let postIds = posts.compactMap { $0.objectId }
        guard !postIds.isEmpty else { return }
        
        // TODO: Implement batch interaction fetch from AWS using InteractionAPIService
        // For now, parse from post data
        for post in posts {
            if let postId = post.objectId,
               let interactions = post.postInteractions {
                // Find user's interaction
                if let userInteraction = interactions.first(where: { 
                    $0.userId == userId 
                }) {
                    userInteractions[postId] = userInteraction.interactionType.rawValue
                }
            }
        }
        
        // Cache interactions
        cacheManager.saveInteractions(userInteractions)
        
        print("✅ [FeedVM] Loaded \(userInteractions.count) user interactions")
    }
    
    /// Load cached data from disk
    private func loadCachedData() {
        // Load cached posts
        if let cached = cacheManager.loadPosts() {
            self.posts = cached
            print("📦 [FeedVM] Loaded \(cached.count) cached posts")
        }
        
        // Load cached interactions
        if let interactions = cacheManager.loadInteractions() {
            self.userInteractions = interactions
            print("📦 [FeedVM] Loaded \(interactions.count) cached interactions")
        }
    }
}

// MARK: - Feed Error
enum FeedError: Error {
    case fetchFailed(String)
    case invalidResponse
    case unauthorized
}
