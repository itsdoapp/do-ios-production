//
//  MetricsHandoffService.swift
//  Do Watch App
//
//  Metrics handoff service
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

class MetricsHandoffService {
    static let shared = MetricsHandoffService()
    
    private let connectivityManager = WatchConnectivityManager.shared
    
    private init() {}
    
    // MARK: - Metrics Transfer
    
    func transferMetricsToPhone(metrics: WorkoutMetrics, workoutId: String, workoutType: WorkoutType) {
        let message: [String: Any] = [
            "type": "metricsHandoff",
            "workoutId": workoutId,
            "workoutType": workoutType.rawValue,
            "metrics": metrics.toDictionary(),
            "timestamp": Date().timeIntervalSince1970
        ]
        
        connectivityManager.sendMessage(message)
    }
    
    func receiveMetricsFromPhone(_ metricsDict: [String: Any]) -> WorkoutMetrics? {
        guard let metrics = WorkoutMetrics.fromDictionary(metricsDict) else {
            return nil
        }
        
        // Update local workout if active
        if var workout = WatchWorkoutCoordinator.shared.activeWorkout {
            workout.metrics = metrics
            workout.lastUpdateDate = Date()
            WatchWorkoutCoordinator.shared.activeWorkout = workout
        }
        
        return metrics
    }
    
    // MARK: - Metrics Merging
    
    func mergeMetrics(phoneMetrics: WorkoutMetrics, watchMetrics: WorkoutMetrics, workoutType: WorkoutType) -> WorkoutMetrics {
        var merged = WorkoutMetrics()
        
        // Distance: Use phone for GPS-based workouts (more accurate)
        if workoutType == .running || workoutType == .biking || workoutType == .hiking || workoutType == .walking {
            merged.distance = phoneMetrics.distance > 0 ? phoneMetrics.distance : watchMetrics.distance
        } else {
            merged.distance = watchMetrics.distance > 0 ? watchMetrics.distance : phoneMetrics.distance
        }
        
        // Elapsed time: Use the longer one (more accurate)
        merged.elapsedTime = max(phoneMetrics.elapsedTime, watchMetrics.elapsedTime)
        
        // Heart rate: Prefer watch (usually more accurate)
        merged.heartRate = watchMetrics.heartRate > 0 ? watchMetrics.heartRate : phoneMetrics.heartRate
        
        // Pace: Calculate from distance and time, or use phone if available
        if merged.distance > 0 && merged.elapsedTime > 0 {
            merged.pace = merged.elapsedTime / merged.distance
        } else {
            merged.pace = phoneMetrics.pace > 0 ? phoneMetrics.pace : watchMetrics.pace
        }
        
        // Calories: Average or use higher value
        if phoneMetrics.calories > 0 && watchMetrics.calories > 0 {
            merged.calories = (phoneMetrics.calories + watchMetrics.calories) / 2.0
        } else {
            merged.calories = max(phoneMetrics.calories, watchMetrics.calories)
        }
        
        // Cadence: Prefer watch
        merged.cadence = watchMetrics.cadence ?? phoneMetrics.cadence
        
        // Elevation: Use phone (GPS-based)
        merged.elevationGain = phoneMetrics.elevationGain ?? watchMetrics.elevationGain
        
        // Average pace: Calculate or use phone
        if merged.distance > 0 && merged.elapsedTime > 0 {
            merged.averagePace = merged.elapsedTime / merged.distance
        } else {
            merged.averagePace = phoneMetrics.averagePace ?? watchMetrics.averagePace
        }
        
        // Current speed: Use phone for GPS-based
        merged.currentSpeed = phoneMetrics.currentSpeed ?? watchMetrics.currentSpeed
        
        return merged
    }
    
    // MARK: - Continuity Preservation
    
    func preserveWorkoutContinuity(previousMetrics: WorkoutMetrics, newMetrics: WorkoutMetrics) -> WorkoutMetrics {
        var continuous = newMetrics
        
        // Ensure elapsed time is continuous (never decreases)
        if newMetrics.elapsedTime < previousMetrics.elapsedTime {
            continuous.elapsedTime = previousMetrics.elapsedTime
        }
        
        // Ensure distance is continuous (never decreases)
        if newMetrics.distance < previousMetrics.distance {
            continuous.distance = previousMetrics.distance
        }
        
        // Ensure calories are continuous (never decreases)
        if newMetrics.calories < previousMetrics.calories {
            continuous.calories = previousMetrics.calories
        }
        
        return continuous
    }
}

