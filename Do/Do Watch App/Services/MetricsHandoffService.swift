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
    
    func receiveMetricsFromPhone(_ metricsDict: [String: Any], coordinationFlags: [String: Any]? = nil) -> WorkoutMetrics? {
        guard let phoneMetrics = WorkoutMetrics.fromDictionary(metricsDict) else {
            return nil
        }
        
        // Update coordination flags if provided
        if let flags = coordinationFlags {
            WatchWorkoutCoordinator.shared.updateCoordinationFlags(from: flags)
        }
        
        // Merge with watch metrics using best value logic
        guard var workout = WatchWorkoutCoordinator.shared.activeWorkout else {
            return phoneMetrics
        }
        
        let watchMetrics = workout.metrics
        let mergedMetrics = mergeMetrics(
            phoneMetrics: phoneMetrics,
            watchMetrics: watchMetrics,
            workoutType: workout.workoutType
        )
        
        // Update workout with merged metrics
        workout.metrics = mergedMetrics
        workout.lastUpdateDate = Date()
        WatchWorkoutCoordinator.shared.activeWorkout = workout
        
        return mergedMetrics
    }
    
    // MARK: - Metrics Merging (Best Value Logic)
    
    func mergeMetrics(phoneMetrics: WorkoutMetrics, watchMetrics: WorkoutMetrics, workoutType: WorkoutType) -> WorkoutMetrics {
        var merged = WorkoutMetrics()
        
        // Distance: Use the higher value (best value strategy)
        merged.distance = max(phoneMetrics.distance, watchMetrics.distance)
        
        // Elapsed time: Use the longer value (more accurate)
        merged.elapsedTime = max(phoneMetrics.elapsedTime, watchMetrics.elapsedTime)
        
        // Heart rate: Always prefer watch (more accurate sensor)
        merged.heartRate = watchMetrics.heartRate > 0 ? watchMetrics.heartRate : phoneMetrics.heartRate
        
        // Pace: Calculate from best distance/time, or use phone GPS-based if available
        if merged.distance > 0 && merged.elapsedTime > 0 {
            merged.pace = merged.elapsedTime / merged.distance
        } else {
            // Use phone GPS-based pace if available, otherwise watch
            merged.pace = phoneMetrics.pace > 0 ? phoneMetrics.pace : watchMetrics.pace
        }
        
        // Calories: Use the higher value (more conservative estimate)
        merged.calories = max(phoneMetrics.calories, watchMetrics.calories)
        
        // Cadence: Prefer watch if available, otherwise phone
        merged.cadence = watchMetrics.cadence ?? phoneMetrics.cadence
        
        // Elevation: Prefer phone GPS, fall back to watch
        merged.elevationGain = phoneMetrics.elevationGain ?? watchMetrics.elevationGain
        
        // Average pace: Calculate from best distance/time
        if merged.distance > 0 && merged.elapsedTime > 0 {
            merged.averagePace = merged.elapsedTime / merged.distance
        } else {
            merged.averagePace = phoneMetrics.averagePace ?? watchMetrics.averagePace
        }
        
        // Current speed: Prefer phone GPS-based, fall back to watch
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

