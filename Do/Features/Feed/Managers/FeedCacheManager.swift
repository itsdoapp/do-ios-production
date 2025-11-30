//
//  FeedCacheManager.swift
//  Do
//
//  Manages feed caching with memory + disk layers
//

import Foundation
import UIKit

class FeedCacheManager {
    static let shared = FeedCacheManager()
    
    // MARK: - Configuration
    private let maxMemoryCacheSize = 50 // posts
    private let maxDiskCacheSize = 200 // posts
    private let cacheExpirationHours = 24
    
    // MARK: - Cache Keys
    private let postsKey = "feed_posts_cache"
    private let interactionsKey = "feed_interactions_cache"
    private let timestampKey = "feed_cache_timestamp"
    private let versionKey = "feed_cache_version"
    private let cacheVersion = 4
    
    // MARK: - Memory Cache
    private var memoryCache: [String: Post] = [:]
    private var memoryCacheOrder: [String] = [] // LRU tracking
    
    // MARK: - UserDefaults
    private let defaults = UserDefaults.standard
    
    private init() {
        migrateCacheIfNeeded()
        // Clean expired cache on init
        cleanExpiredCache()
    }
    
    // MARK: - Post Caching
    
    /// Save posts to cache (memory + disk)
    func savePosts(_ posts: [Post]) {
        // Update memory cache
        for post in posts {
            guard let id = post.objectId else { continue }
            
            // Add to memory cache
            memoryCache[id] = post
            
            // Update LRU order
            if let index = memoryCacheOrder.firstIndex(of: id) {
                memoryCacheOrder.remove(at: index)
            }
            memoryCacheOrder.append(id)
            
            // Trim if needed
            if memoryCacheOrder.count > maxMemoryCacheSize {
                let oldestId = memoryCacheOrder.removeFirst()
                memoryCache.removeValue(forKey: oldestId)
            }
        }
        
        // Save to disk (limited to maxDiskCacheSize)
        let postsToSave = Array(posts.prefix(maxDiskCacheSize))
        saveToDisk(posts: postsToSave)
    }
    
    /// Load posts from cache
    func loadPosts() -> [Post]? {
        // Check if cache is expired
        if isCacheExpired() {
            clearCache()
            return nil
        }
        
        // Try to load from disk
        return loadFromDisk()
    }
    
    /// Get single post from cache
    func getPost(id: String) -> Post? {
        // Check memory first (fast)
        if let post = memoryCache[id] {
            // Update LRU
            if let index = memoryCacheOrder.firstIndex(of: id) {
                memoryCacheOrder.remove(at: index)
                memoryCacheOrder.append(id)
            }
            return post
        }
        
        // Check disk (slower)
        if let posts = loadFromDisk() {
            return posts.first { $0.objectId == id }
        }
        
        return nil
    }
    
    // MARK: - Interaction Caching
    
    /// Save interactions to cache
    func saveInteractions(_ interactions: [String: String]) {
        if let data = try? JSONEncoder().encode(interactions) {
            defaults.set(data, forKey: interactionsKey)
        }
    }
    
    /// Load interactions from cache
    func loadInteractions() -> [String: String]? {
        guard let data = defaults.data(forKey: interactionsKey),
              let interactions = try? JSONDecoder().decode([String: String].self, from: data) else {
            return nil
        }
        return interactions
    }
    
    // MARK: - Cache Management
    
    /// Clear all cache
    func clearCache() {
        memoryCache.removeAll()
        memoryCacheOrder.removeAll()
        defaults.removeObject(forKey: postsKey)
        defaults.removeObject(forKey: interactionsKey)
        defaults.removeObject(forKey: timestampKey)
        defaults.set(cacheVersion, forKey: versionKey)
        print("🗑 [Cache] Cleared all cache")
    }
    
    /// Check if cache is expired
    private func isCacheExpired() -> Bool {
        guard let timestamp = defaults.object(forKey: timestampKey) as? Date else {
            return true
        }
        
        let hoursSinceCache = Date().timeIntervalSince(timestamp) / 3600
        return hoursSinceCache > Double(cacheExpirationHours)
    }
    
    /// Clean expired cache
    private func cleanExpiredCache() {
        if isCacheExpired() {
            print("🕒 [Cache] Cache expired, clearing...")
            clearCache()
        }
    }
    
    /// Handle cache migrations when persistence schema changes
    private func migrateCacheIfNeeded() {
        let storedVersion = defaults.integer(forKey: versionKey)
        guard storedVersion < cacheVersion else { return }
        
        print("🆕 [Cache] Migrating feed cache (v\(storedVersion) -> v\(cacheVersion))")
        clearCache()
        defaults.set(cacheVersion, forKey: versionKey)
    }
    
    // MARK: - Disk Persistence
    
    /// Save posts to disk
    private func saveToDisk(posts: [Post]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(posts)
            defaults.set(data, forKey: postsKey)
            defaults.set(Date(), forKey: timestampKey)
            print("💾 [Cache] Saved \(posts.count) posts to disk")
        } catch {
            print("⚠️ [Cache] Failed to encode posts for disk cache: \(error)")
        }
    }
    
    /// Load posts from disk
    private func loadFromDisk() -> [Post]? {
        guard let data = defaults.data(forKey: postsKey) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let posts = try decoder.decode([Post].self, from: data)
            print("📦 [Cache] Loaded \(posts.count) posts from disk")
            return posts
        } catch {
            print("⚠️ [Cache] Failed to decode posts from disk cache: \(error)")
            return nil
        }
    }
}
