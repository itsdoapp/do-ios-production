//
//  UserListCacheManager.swift
//  Do.
//
//  Smart caching system for followers/following lists
//

import Foundation

class UserListCacheManager {
    static let shared = UserListCacheManager()
    
    // MARK: - Configuration
    private let cacheExpirationInterval: TimeInterval = 600 // 10 minutes
    private let staleThreshold: TimeInterval = 300 // 5 minutes - refresh in background if older
    
    // MARK: - Cache Storage
    private struct CachedUserList {
        let users: [UserModel]
        let nextToken: String?
        let hasMore: Bool
        let timestamp: Date
        let userId: String
        let listType: ListType
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > UserListCacheManager.shared.cacheExpirationInterval
        }
        
        var isStale: Bool {
            Date().timeIntervalSince(timestamp) > UserListCacheManager.shared.staleThreshold
        }
    }
    
    enum ListType: String {
        case followers
        case following
    }
    
    private var cache: [String: CachedUserList] = [:]
    
    private init() {}
    
    // MARK: - Cache Operations
    
    /// Get cache key for a user's list
    private func cacheKey(userId: String, listType: ListType) -> String {
        return "\(listType.rawValue)_\(userId)"
    }
    
    /// Get cached users for a user's list
    func getCachedUsers(userId: String, listType: ListType) -> (users: [UserModel], nextToken: String?, hasMore: Bool)? {
        let key = cacheKey(userId: userId, listType: listType)
        guard let cached = cache[key], !cached.isExpired else {
            return nil
        }
        
        print("📦 [UserListCache] Found cached \(listType.rawValue) for userId: \(userId) (\(cached.users.count) users)")
        return (cached.users, cached.nextToken, cached.hasMore)
    }
    
    /// Cache users for a user's list (REPLACES existing cache)
    func cacheUsers(_ users: [UserModel], nextToken: String?, hasMore: Bool, userId: String, listType: ListType) {
        let key = cacheKey(userId: userId, listType: listType)
        print("📦 [UserListCache] cacheUsers called for key: \(key), users: \(users.count) (REPLACING existing cache)")
        let cached = CachedUserList(
            users: users,
            nextToken: nextToken,
            hasMore: hasMore,
            timestamp: Date(),
            userId: userId,
            listType: listType
        )
        cache[key] = cached
        print("📦 [UserListCache] Cached \(users.count) \(listType.rawValue) for userId: \(userId)")
    }
    
    /// Append more users to existing cache (for pagination)
    func appendCachedUsers(_ newUsers: [UserModel], nextToken: String?, hasMore: Bool, userId: String, listType: ListType) {
        let key = cacheKey(userId: userId, listType: listType)
        print("📦 [UserListCache] appendCachedUsers called for key: \(key), newUsers: \(newUsers.count)")
        if let existing = cache[key] {
            print("📦 [UserListCache] Found existing cache with \(existing.users.count) users, appending \(newUsers.count) new users")
            let updatedUsers = existing.users + newUsers
            let updated = CachedUserList(
                users: updatedUsers,
                nextToken: nextToken,
                hasMore: hasMore,
                timestamp: Date(), // Update timestamp
                userId: userId,
                listType: listType
            )
            cache[key] = updated
            print("📦 [UserListCache] Appended \(newUsers.count) users to cache (total: \(updatedUsers.count))")
        } else {
            // No existing cache, create new
            print("📦 [UserListCache] No existing cache found, creating new cache")
            cacheUsers(newUsers, nextToken: nextToken, hasMore: hasMore, userId: userId, listType: listType)
        }
    }
    
    /// Check if cache is stale (should refresh in background)
    func isCacheStale(userId: String, listType: ListType) -> Bool {
        let key = cacheKey(userId: userId, listType: listType)
        guard let cached = cache[key] else { return true }
        return cached.isStale
    }
    
    /// Update follow status for a user in cache
    func updateFollowStatus(userId: String, targetUserId: String, isFollowing: Bool, listType: ListType) {
        let key = cacheKey(userId: userId, listType: listType)
        guard var cached = cache[key] else { return }
        
        // Update the user's follow status in the cached list
        var updatedUsers = cached.users
        if let index = updatedUsers.firstIndex(where: { $0.userID == targetUserId }) {
            updatedUsers[index].isFollowing = isFollowing
            let updated = CachedUserList(
                users: updatedUsers,
                nextToken: cached.nextToken,
                hasMore: cached.hasMore,
                timestamp: cached.timestamp, // Keep original timestamp
                userId: userId,
                listType: listType
            )
            cache[key] = updated
            print("📦 [UserListCache] Updated follow status for user \(targetUserId) in cache")
        }
    }
    
    /// Clear cache for a specific user's list
    func clearCache(userId: String, listType: ListType) {
        let key = cacheKey(userId: userId, listType: listType)
        cache.removeValue(forKey: key)
        print("🗑️ [UserListCache] Cleared cache for \(listType.rawValue) of userId: \(userId)")
    }
    
    /// Clear all cache
    func clearAllCache() {
        cache.removeAll()
        print("🗑️ [UserListCache] Cleared all cache")
    }
    
    /// Clean expired cache entries
    func cleanExpiredCache() {
        let expiredKeys = cache.keys.filter { key in
            guard let cached = cache[key] else { return true }
            return cached.isExpired
        }
        
        for key in expiredKeys {
            cache.removeValue(forKey: key)
        }
        
        if !expiredKeys.isEmpty {
            print("🧹 [UserListCache] Cleaned \(expiredKeys.count) expired cache entries")
        }
    }
}

