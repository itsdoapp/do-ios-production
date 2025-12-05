//
//  LockScreenManager.swift
//  Do
//
//  Manages lock screen display for workout tracking
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import MediaPlayer
import UIKit

class LockScreenManager {
    static let shared = LockScreenManager()
    
    private var currentWorkoutType: String?
    private var startTime: Date?
    
    private init() {
        setupNowPlayingInfoCenter()
    }
    
    private func setupNowPlayingInfoCenter() {
        // Configure MPNowPlayingInfoCenter for workout display
        // This allows workout metrics to appear on the lock screen
    }
    
    // MARK: - Workout Management
    
    func startWorkout(type: String) {
        currentWorkoutType = type
        startTime = Date()
        
        var nowPlayingInfo: [String: Any] = [:]
        
        // Set workout type as title
        let workoutTitle: String
        switch type {
        case "run": workoutTitle = "Running"
        case "bike": workoutTitle = "Biking"
        case "hike": workoutTitle = "Hiking"
        case "walk": workoutTitle = "Walking"
        case "swim": workoutTitle = "Swimming"
        default: workoutTitle = "Workout"
        }
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = workoutTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Do"
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        print("📱 [LockScreenManager] Started workout: \(workoutTitle)")
    }
    
    func updateLockScreen(metrics: WorkoutMetrics) {
        guard currentWorkoutType != nil else { return }
        
        var nowPlayingInfo: [String: Any] = [:]
        
        // Workout title
        let workoutTitle: String
        switch currentWorkoutType {
        case "run": workoutTitle = "Running"
        case "bike": workoutTitle = "Biking"
        case "hike": workoutTitle = "Hiking"
        case "walk": workoutTitle = "Walking"
        case "swim": workoutTitle = "Swimming"
        default: workoutTitle = "Workout"
        }
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = workoutTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Do"
        
        // Elapsed time
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = metrics.elapsedTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = metrics.elapsedTime // Use elapsed time as duration for now
        
        // Additional metadata (these won't show on lock screen but can be used by control center)
        var additionalInfo: [String] = []
        
        // Distance
        if metrics.distance > 0 {
            let distanceStr = metrics.formattedDistance(useImperial: false)
            additionalInfo.append("Distance: \(distanceStr)")
        }
        
        // Pace
        if metrics.pace > 0 {
            let paceStr = metrics.formattedPace(useImperial: false)
            additionalInfo.append("Pace: \(paceStr)")
        }
        
        // Heart rate
        if metrics.heartRate > 0 {
            additionalInfo.append("HR: \(Int(metrics.heartRate)) bpm")
        }
        
        // Calories
        if metrics.calories > 0 {
            additionalInfo.append("Calories: \(Int(metrics.calories))")
        }
        
        // Combine additional info into album title (visible in some contexts)
        if !additionalInfo.isEmpty {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = additionalInfo.joined(separator: " • ")
        }
        
        // Playback rate (1.0 = active, 0.0 = paused)
        // For workouts, we'll use 1.0 to indicate active
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        print("📱 [LockScreenManager] Updated lock screen with metrics")
    }
    
    func stopWorkout() {
        currentWorkoutType = nil
        startTime = nil
        
        // Clear lock screen info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        
        print("📱 [LockScreenManager] Stopped workout")
    }
    
    // MARK: - Helper Methods
    
    func isWorkoutActive() -> Bool {
        return currentWorkoutType != nil
    }
    
    func getCurrentWorkoutType() -> String? {
        return currentWorkoutType
    }
}








