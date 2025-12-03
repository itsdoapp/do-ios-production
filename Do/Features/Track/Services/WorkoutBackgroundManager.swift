//
//  WorkoutBackgroundManager.swift
//  Do
//
//  Manages workout state in background for recovery after app termination
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

protocol WorkoutEngineProtocol: AnyObject {
    var workoutId: UUID { get }
}

struct WorkoutStateCache: Codable {
    let type: String // "run", "bike", "hike", "walk"
    let state: String
    let distance: Double
    let duration: TimeInterval
    let locations: [[String: Double]] // Array of location dictionaries
    let timestamp: TimeInterval
}

class WorkoutBackgroundManager {
    static let shared = WorkoutBackgroundManager()
    
    private var registeredWorkouts: [String: WorkoutEngineProtocol] = [:]
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "workoutStateCache"
    
    private init() {}
    
    // MARK: - Workout Registration
    
    func registerWorkout(type: String, engine: WorkoutEngineProtocol) {
        registeredWorkouts[type] = engine
        print("📱 [WorkoutBackgroundManager] Registered workout type: \(type)")
    }
    
    func unregisterWorkout(type: String) {
        registeredWorkouts.removeValue(forKey: type)
        print("📱 [WorkoutBackgroundManager] Unregistered workout type: \(type)")
    }
    
    // MARK: - State Caching
    
    func saveStateCache(type: String, state: String, distance: Double, duration: TimeInterval, locations: [[String: Double]]) {
        let cache = WorkoutStateCache(
            type: type,
            state: state,
            distance: distance,
            duration: duration,
            locations: locations,
            timestamp: Date().timeIntervalSince1970
        )
        
        if let encoded = try? JSONEncoder().encode(cache) {
            userDefaults.set(encoded, forKey: cacheKey)
            print("📱 [WorkoutBackgroundManager] Saved state cache for type: \(type)")
        }
    }
    
    func loadStateCache() -> WorkoutStateCache? {
        guard let data = userDefaults.data(forKey: cacheKey),
              let cache = try? JSONDecoder().decode(WorkoutStateCache.self, from: data) else {
            return nil
        }
        
        print("📱 [WorkoutBackgroundManager] Loaded state cache for type: \(cache.type)")
        return cache
    }
    
    func clearStateCache() {
        userDefaults.removeObject(forKey: cacheKey)
        print("📱 [WorkoutBackgroundManager] Cleared state cache")
    }
    
    // MARK: - Background Task Management
    
    func startBackgroundTask() {
        // This would typically use UIApplication.shared.beginBackgroundTask
        // For now, just log
        print("📱 [WorkoutBackgroundManager] Background task started")
    }
    
    func endBackgroundTask() {
        print("📱 [WorkoutBackgroundManager] Background task ended")
    }
}





