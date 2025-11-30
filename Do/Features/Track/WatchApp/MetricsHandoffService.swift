//
//  MetricsHandoffService.swift
//  Do
//
//  Metrics handoff service (iOS side)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import WatchConnectivity

class MetricsHandoffService {
    static let shared = MetricsHandoffService()
    
    private var session: WCSession?
    
    private init() {
        if WCSession.isSupported() {
            session = WCSession.default
        }
    }
    
    // MARK: - Metrics Transfer
    
    func transferMetricsToWatch(metrics: WorkoutMetrics, workoutId: String, workoutType: WorkoutType) {
        guard let session = session, session.isWatchAppInstalled else { return }
        
        let message: [String: Any] = [
            "type": "metricsHandoff",
            "workoutId": workoutId,
            "workoutType": workoutType.rawValue,
            "metrics": metrics.toDictionary(),
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("❌ [MetricsHandoffService] Error: \(error.localizedDescription)")
            }
        } else {
            do {
                try session.updateApplicationContext(message)
            } catch {
                print("❌ [MetricsHandoffService] Failed to update context: \(error.localizedDescription)")
            }
        }
    }
    
    func receiveMetricsFromWatch(_ metricsDict: [String: Any]) -> WorkoutMetrics? {
        return WorkoutMetrics.fromDictionary(metricsDict)
    }
    
    // MARK: - Metrics Merging
    
    func mergeMetrics(phoneMetrics: WorkoutMetrics, watchMetrics: WorkoutMetrics, workoutType: WorkoutType) -> WorkoutMetrics {
        var merged = WorkoutMetrics()
        
        // Distance: Use phone for GPS-based workouts
        if workoutType == .running || workoutType == .biking || workoutType == .hiking || workoutType == .walking {
            merged.distance = phoneMetrics.distance > 0 ? phoneMetrics.distance : watchMetrics.distance
        } else {
            merged.distance = watchMetrics.distance > 0 ? watchMetrics.distance : phoneMetrics.distance
        }
        
        // Elapsed time: Use the longer one
        merged.elapsedTime = max(phoneMetrics.elapsedTime, watchMetrics.elapsedTime)
        
        // Heart rate: Prefer watch
        merged.heartRate = watchMetrics.heartRate > 0 ? watchMetrics.heartRate : phoneMetrics.heartRate
        
        // Pace: Calculate or use phone
        if merged.distance > 0 && merged.elapsedTime > 0 {
            merged.pace = merged.elapsedTime / merged.distance
        } else {
            merged.pace = phoneMetrics.pace > 0 ? phoneMetrics.pace : watchMetrics.pace
        }
        
        // Calories: Average or use higher
        if phoneMetrics.calories > 0 && watchMetrics.calories > 0 {
            merged.calories = (phoneMetrics.calories + watchMetrics.calories) / 2.0
        } else {
            merged.calories = max(phoneMetrics.calories, watchMetrics.calories)
        }
        
        // Cadence: Prefer watch
        merged.cadence = watchMetrics.cadence ?? phoneMetrics.cadence
        
        // Elevation: Use phone
        merged.elevationGain = phoneMetrics.elevationGain ?? watchMetrics.elevationGain
        
        // Average pace: Calculate
        if merged.distance > 0 && merged.elapsedTime > 0 {
            merged.averagePace = merged.elapsedTime / merged.distance
        } else {
            merged.averagePace = phoneMetrics.averagePace ?? watchMetrics.averagePace
        }
        
        // Current speed: Use phone
        merged.currentSpeed = phoneMetrics.currentSpeed ?? watchMetrics.currentSpeed
        
        return merged
    }
    
    // MARK: - Continuity Preservation
    
    func preserveWorkoutContinuity(previousMetrics: WorkoutMetrics, newMetrics: WorkoutMetrics) -> WorkoutMetrics {
        var continuous = newMetrics
        
        if newMetrics.elapsedTime < previousMetrics.elapsedTime {
            continuous.elapsedTime = previousMetrics.elapsedTime
        }
        
        if newMetrics.distance < previousMetrics.distance {
            continuous.distance = previousMetrics.distance
        }
        
        if newMetrics.calories < previousMetrics.calories {
            continuous.calories = previousMetrics.calories
        }
        
        return continuous
    }
}

