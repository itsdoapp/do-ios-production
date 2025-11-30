//
//  WorkoutCacheManager.swift
//  Do
//
//  Simple cache manager for workout data (movements, sessions, plans)
//

import Foundation

class WorkoutCacheManager {
    static let shared = WorkoutCacheManager()
    
    private var movementsCache: [String: [AWSWorkoutService.WorkoutItem]] = [:]
    private var sessionsCache: [String: [AWSWorkoutService.WorkoutItem]] = [:]
    private var plansCache: [String: [AWSWorkoutService.WorkoutItem]] = [:]
    
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    private var cacheTimestamps: [String: Date] = [:]
    
    private init() {}
    
    // MARK: - Movements Cache
    
    func getCachedMovements(userId: String) -> [AWSWorkoutService.WorkoutItem]? {
        let key = "movements_\(userId)"
        guard let timestamp = cacheTimestamps[key],
              Date().timeIntervalSince(timestamp) < cacheExpirationInterval,
              let cached = movementsCache[userId] else {
            return nil
        }
        return cached
    }
    
    func cacheMovements(_ items: [AWSWorkoutService.WorkoutItem], userId: String) {
        movementsCache[userId] = items
        cacheTimestamps["movements_\(userId)"] = Date()
        print("📦 [WorkoutCache] Cached \(items.count) movements for userId: \(userId)")
    }
    
    // MARK: - Sessions Cache
    
    func getCachedSessions(userId: String) -> [AWSWorkoutService.WorkoutItem]? {
        let key = "sessions_\(userId)"
        guard let timestamp = cacheTimestamps[key],
              Date().timeIntervalSince(timestamp) < cacheExpirationInterval,
              let cached = sessionsCache[userId] else {
            return nil
        }
        return cached
    }
    
    func cacheSessions(_ items: [AWSWorkoutService.WorkoutItem], userId: String) {
        sessionsCache[userId] = items
        cacheTimestamps["sessions_\(userId)"] = Date()
        print("📦 [WorkoutCache] Cached \(items.count) sessions for userId: \(userId)")
    }
    
    // MARK: - Plans Cache
    
    func getCachedPlans(userId: String) -> [AWSWorkoutService.WorkoutItem]? {
        let key = "plans_\(userId)"
        guard let timestamp = cacheTimestamps[key],
              Date().timeIntervalSince(timestamp) < cacheExpirationInterval,
              let cached = plansCache[userId] else {
            return nil
        }
        return cached
    }
    
    func cachePlans(_ items: [AWSWorkoutService.WorkoutItem], userId: String) {
        plansCache[userId] = items
        cacheTimestamps["plans_\(userId)"] = Date()
        print("📦 [WorkoutCache] Cached \(items.count) plans for userId: \(userId)")
    }
    
    // MARK: - Cache Management
    
    func clearCache(for userId: String) {
        movementsCache.removeValue(forKey: userId)
        sessionsCache.removeValue(forKey: userId)
        plansCache.removeValue(forKey: userId)
        cacheTimestamps.removeValue(forKey: "movements_\(userId)")
        cacheTimestamps.removeValue(forKey: "sessions_\(userId)")
        cacheTimestamps.removeValue(forKey: "plans_\(userId)")
        print("📦 [WorkoutCache] Cleared cache for userId: \(userId)")
    }
    
    func clearAllCache() {
        movementsCache.removeAll()
        sessionsCache.removeAll()
        plansCache.removeAll()
        cacheTimestamps.removeAll()
        print("📦 [WorkoutCache] Cleared all cache")
    }
}

