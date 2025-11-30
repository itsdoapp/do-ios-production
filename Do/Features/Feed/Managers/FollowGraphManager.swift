//
//  FollowGraphManager.swift
//  Do
//
//  Manages follow relationships with O(1) lookups
//

import Foundation

class FollowGraphManager {
    static let shared = FollowGraphManager()
    
    // MARK: - In-Memory Cache (O(1) lookups)
    private var followingSet: Set<String> = []
    private var followersSet: Set<String> = []
    private var mutualSet: Set<String> = []
    private var followingCount: Int = 0
    private var followersCount: Int = 0
    
    // MARK: - Cache Configuration
    private let cacheKey = "follow_graph_cache"
    private let cacheExpirationHours = 1 // Refresh every hour
    private let defaults = UserDefaults.standard
    
    // MARK: - Cache Timestamp
    private var lastUpdateTime: Date?
    
    private init() {
        loadFromCache()
    }
    
    // MARK: - Public Methods
    
    /// Check if user is following another user (O(1))
    func isFollowing(_ userId: String) -> Bool {
        return followingSet.contains(userId)
    }
    
    /// Check if user is followed by another user (O(1))
    func isFollowedBy(_ userId: String) -> Bool {
        return followersSet.contains(userId)
    }
    
    /// Check if mutual follow (O(1))
    func isMutual(_ userId: String) -> Bool {
        return mutualSet.contains(userId)
    }
    
    /// Get following count
    func getFollowingCount(userId: String) async -> Int {
        // If cache is fresh, return cached count
        if !isCacheExpired() {
            return followingCount
        }
        
        // Otherwise, fetch fresh data
        await updateFollowGraph(userId: userId)
        return followingCount
    }
    
    /// Get followers count
    func getFollowersCount(userId: String) async -> Int {
        if !isCacheExpired() {
            return followersCount
        }
        
        await updateFollowGraph(userId: userId)
        return followersCount
    }
    
    /// Batch check follow status for multiple users (O(n))
    func filterFollowing(_ userIds: [String]) -> Set<String> {
        return Set(userIds).intersection(followingSet)
    }
    
    /// Update follow graph from AWS
    func updateFollowGraph(userId: String) async {
        do {
            // Fetch from ProfileAPIService
            let profile = try await ProfileAPIService.shared.fetchUserProfile(
                userId: userId,
                currentUserId: userId
            )
            
            guard let userData = profile.data else {
                print("❌ [FollowGraph] No profile data")
                return
            }
            
            // Update counts from profile data
            followingCount = userData.followingCount
            followersCount = userData.followerCount
            
            // Fetch detailed follow lists from ProfileAPIService
            do {
                // Fetch following list
                let followingResponse = try await ProfileAPIService.shared.fetchFollowing(
                    userId: userId,
                    currentUserId: userId,
                    limit: 1000
                )
                
                let followingIds = followingResponse.data.compactMap { $0.userId }
                followingSet = Set(followingIds)
                
                // Fetch followers list
                let followersResponse = try await ProfileAPIService.shared.fetchFollowers(
                    userId: userId,
                    currentUserId: userId,
                    limit: 1000
                )
                
                let followerIds = followersResponse.data.compactMap { $0.userId }
                followersSet = Set(followerIds)
                
                // Calculate mutual follows
                mutualSet = followingSet.intersection(followersSet)
            } catch {
                print("❌ [FollowGraph] Failed to fetch follow lists: \(error)")
                // Keep existing cached data
            }
            
            // Update timestamp
            lastUpdateTime = Date()
            
            // Save to cache
            saveToCache()
            
            print("✅ [FollowGraph] Updated: following=\(followingCount), followers=\(followersCount)")
            
        } catch {
            print("❌ [FollowGraph] Update failed: \(error)")
        }
    }
    
    /// Add follow relationship (optimistic update)
    func addFollowing(_ userId: String) {
        followingSet.insert(userId)
        followingCount += 1
        
        // Check if mutual
        if followersSet.contains(userId) {
            mutualSet.insert(userId)
        }
        
        saveToCache()
    }
    
    /// Remove follow relationship (optimistic update)
    func removeFollowing(_ userId: String) {
        followingSet.remove(userId)
        followingCount = max(0, followingCount - 1)
        mutualSet.remove(userId)
        
        saveToCache()
    }
    
    /// Clear cache
    func clearCache() {
        followingSet.removeAll()
        followersSet.removeAll()
        mutualSet.removeAll()
        followingCount = 0
        followersCount = 0
        lastUpdateTime = nil
        
        defaults.removeObject(forKey: cacheKey)
        print("🗑 [FollowGraph] Cache cleared")
    }
    
    // MARK: - Private Methods
    
    /// Check if cache is expired
    private func isCacheExpired() -> Bool {
        guard let lastUpdate = lastUpdateTime else {
            return true
        }
        
        let hoursSinceUpdate = Date().timeIntervalSince(lastUpdate) / 3600
        return hoursSinceUpdate > Double(cacheExpirationHours)
    }
    
    /// Save to cache
    private func saveToCache() {
        let cache: [String: Any] = [
            "following": Array(followingSet),
            "followers": Array(followersSet),
            "mutual": Array(mutualSet),
            "followingCount": followingCount,
            "followersCount": followersCount,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: cache) {
            defaults.set(data, forKey: cacheKey)
        }
    }
    
    /// Load from cache
    private func loadFromCache() {
        guard let data = defaults.data(forKey: cacheKey),
              let cache = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        if let following = cache["following"] as? [String] {
            followingSet = Set(following)
        }
        
        if let followers = cache["followers"] as? [String] {
            followersSet = Set(followers)
        }
        
        if let mutual = cache["mutual"] as? [String] {
            mutualSet = Set(mutual)
        }
        
        followingCount = cache["followingCount"] as? Int ?? 0
        followersCount = cache["followersCount"] as? Int ?? 0
        
        if let timestamp = cache["timestamp"] as? TimeInterval {
            lastUpdateTime = Date(timeIntervalSince1970: timestamp)
        }
        
        print("📦 [FollowGraph] Loaded from cache: following=\(followingCount)")
    }
}
