//
//  MetricsCoordinator.swift
//  Do
//
//  Coordinates metrics between phone and watch for bike tracking
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import WatchConnectivity

// MARK: - MetricType Enum
// MetricType enum - shared between iOS and Watch
public enum MetricType: String, Codable {
    case distance
    case pace
    case heartRate
    case cadence
    case calories
    case elevation
    case speed
}

class MetricsCoordinator {
    weak var bikeEngine: BikeTrackingEngine?
    weak var walkEngine: WalkTrackingEngine?
    weak var runEngine: RunTrackingEngine?
    weak var hikeEngine: HikeTrackingEngine?
    private var watchAvailable: Bool = false
    private var watchReachable: Bool = false
    
    init(bikeEngine: BikeTrackingEngine) {
        self.bikeEngine = bikeEngine
    }
    
    init(walkEngine: WalkTrackingEngine) {
        self.walkEngine = walkEngine
    }
    
    init(runEngine: RunTrackingEngine) {
        self.runEngine = runEngine
    }
    
    init(hikeEngine: HikeTrackingEngine) {
        self.hikeEngine = hikeEngine
    }
    
    /// Update watch connection status
    func updateWatchStatus(isAvailable: Bool, isReachable: Bool) {
        watchAvailable = isAvailable
        watchReachable = isReachable
        
        // Notify bike engine of status change if needed
        // This can be used to adjust primary device settings
        print("📱 [MetricsCoordinator] Watch status updated - Available: \(isAvailable), Reachable: \(isReachable)")
    }
    
    /// Determine if watch should be primary for a specific metric
    func shouldUseWatchFor(metric: MetricType, isIndoor: Bool) -> Bool {
        guard watchAvailable && watchReachable else {
            return false
        }
        
        switch metric {
        case .heartRate:
            return true // Watch is always better for heart rate
        case .cadence:
            return true // Watch can track cadence better
        case .calories:
            return true // Watch has better calorie estimation
        case .distance:
            return isIndoor // Watch is better for indoor (no GPS)
        case .pace:
            return isIndoor // Watch is better for indoor pace
        case .elevation:
            return false // Phone GPS is better for elevation
        case .speed:
            return isIndoor // Watch is better for indoor speed
        }
    }
    
    /// Process metrics received from watch with best value selection
    func processWatchMetrics(metrics: [String: Any]) {
        // Handle bike engine
        if let bikeEngine = bikeEngine {
            // Heart Rate: Always prefer watch (more accurate sensor)
            if let watchHeartRate = metrics["heartRate"] as? Double, watchHeartRate > 0 {
                bikeEngine.heartRate = watchHeartRate
                print("📱 [MetricsCoordinator] Updated heart rate from watch: \(watchHeartRate) BPM")
            }
            
            // Cadence: Prefer watch if available
            if let watchCadence = metrics["cadence"] as? Double, watchCadence > 0 {
                bikeEngine.cadence = watchCadence
                print("📱 [MetricsCoordinator] Updated cadence from watch: \(watchCadence)")
            }
            
            // Distance: Use the higher value (more accurate - accounts for GPS drift)
            if let watchDistance = metrics["distance"] as? Double, watchDistance > 0 {
                let phoneDistance = bikeEngine.distance.value
                if watchDistance > phoneDistance {
                    bikeEngine.distance = Measurement(value: watchDistance, unit: UnitLength.meters)
                    print("📱 [MetricsCoordinator] Updated distance from watch: \(watchDistance)m (was \(phoneDistance)m)")
                } else {
                    print("📱 [MetricsCoordinator] Keeping phone distance: \(phoneDistance)m (watch: \(watchDistance)m)")
                }
            }
            
            // Calories: Use the higher value (more conservative estimate)
            if let watchCalories = metrics["calories"] as? Double, watchCalories > 0 {
                let phoneCalories = bikeEngine.calories
                let bestCalories = max(phoneCalories, watchCalories)
                if bestCalories != phoneCalories {
                    bikeEngine.calories = bestCalories
                    print("📱 [MetricsCoordinator] Updated calories to best value: \(bestCalories) (watch: \(watchCalories), phone: \(phoneCalories))")
                }
            }
            
            // Elapsed Time: Use the longer value (more accurate)
            if let watchElapsedTime = metrics["elapsedTime"] as? TimeInterval, watchElapsedTime > 0 {
                if watchElapsedTime > bikeEngine.elapsedTime {
                    bikeEngine.elapsedTime = watchElapsedTime
                    print("📱 [MetricsCoordinator] Updated elapsed time from watch: \(watchElapsedTime)s")
                }
            }
            
            // Pace: Recalculate from best distance/time if we updated distance
            // (Pace will be recalculated by the engine based on updated distance)
        }
        
        // Handle walk engine
        if let walkEngine = walkEngine {
            // Heart Rate: Always prefer watch (more accurate sensor)
            if let watchHeartRate = metrics["heartRate"] as? Double, watchHeartRate > 0 {
                walkEngine.heartRate = watchHeartRate
                print("📱 [MetricsCoordinator] Updated heart rate from watch: \(watchHeartRate) BPM")
            }
            
            // Distance: Use the higher value (more accurate - accounts for GPS drift)
            if let watchDistance = metrics["distance"] as? Double, watchDistance > 0 {
                let phoneDistance = walkEngine.distance.value
                // For outdoor walks, compare and use better value
                // If phone is primary for distance (has good GPS), still compare to ensure we use best
                if watchDistance > phoneDistance {
                    walkEngine.distance = Measurement(value: watchDistance, unit: UnitLength.meters)
                    print("📱 [MetricsCoordinator] Updated distance from watch: \(watchDistance)m (was \(phoneDistance)m)")
                } else {
                    print("📱 [MetricsCoordinator] Keeping phone distance: \(phoneDistance)m (watch: \(watchDistance)m)")
                }
            }
            
            // Calories: Use the higher value (more conservative estimate)
            if let watchCalories = metrics["calories"] as? Double, watchCalories > 0 {
                let phoneCalories = walkEngine.calories
                let bestCalories = max(phoneCalories, watchCalories)
                if bestCalories != phoneCalories {
                    walkEngine.calories = bestCalories
                    print("📱 [MetricsCoordinator] Updated calories to best value: \(bestCalories) (watch: \(watchCalories), phone: \(phoneCalories))")
                }
            }
            
            // Cadence: Prefer watch if available
            if let watchCadence = metrics["cadence"] as? Double, watchCadence > 0 {
                walkEngine.cadence = watchCadence
                print("📱 [MetricsCoordinator] Updated cadence from watch: \(watchCadence)")
            }
            
            // Elapsed Time: Use the longer value (more accurate)
            if let watchElapsedTime = metrics["elapsedTime"] as? TimeInterval, watchElapsedTime > 0 {
                if watchElapsedTime > walkEngine.elapsedTime {
                    walkEngine.elapsedTime = watchElapsedTime
                    print("📱 [MetricsCoordinator] Updated elapsed time from watch: \(watchElapsedTime)s")
                }
            }
            
            // Elevation: Use phone GPS if available, otherwise watch
            if let watchElevation = metrics["elevationGain"] as? Double, watchElevation > 0 {
                let phoneElevation = walkEngine.elevationGain.value
                // Prefer phone GPS elevation, but use watch if phone doesn't have it
                if phoneElevation == 0 || watchElevation > phoneElevation {
                    walkEngine.elevationGain = Measurement(value: watchElevation, unit: UnitLength.meters)
                    print("📱 [MetricsCoordinator] Updated elevation from watch: \(watchElevation)m")
                }
            }
        }
        
        // Handle run engine
        if let runEngine = runEngine {
            // Heart Rate: Always prefer watch
            if let watchHeartRate = metrics["heartRate"] as? Double, watchHeartRate > 0 {
                runEngine.heartRate = watchHeartRate
                print("📱 [MetricsCoordinator] Updated heart rate from watch: \(watchHeartRate) BPM")
            }
            
            // Distance: Use the higher value
            if let watchDistance = metrics["distance"] as? Double, watchDistance > 0 {
                let phoneDistance = runEngine.distance.value
                if watchDistance > phoneDistance {
                    runEngine.distance = Measurement(value: watchDistance, unit: UnitLength.meters)
                    print("📱 [MetricsCoordinator] Updated distance from watch: \(watchDistance)m (was \(phoneDistance)m)")
                }
            }
            
            // Calories: Use the higher value
            if let watchCalories = metrics["calories"] as? Double, watchCalories > 0 {
                runEngine.calories = max(runEngine.calories, watchCalories)
            }
            
            // Cadence: Prefer watch
            if let watchCadence = metrics["cadence"] as? Double, watchCadence > 0 {
                runEngine.cadence = watchCadence
            }
            
            // Elapsed Time: Use the longer value
            if let watchElapsedTime = metrics["elapsedTime"] as? TimeInterval, watchElapsedTime > 0 {
                if watchElapsedTime > runEngine.elapsedTime {
                    runEngine.elapsedTime = watchElapsedTime
                }
            }
        }
        
        // Handle hike engine
        if let hikeEngine = hikeEngine {
            // Heart Rate: Always prefer watch
            if let watchHeartRate = metrics["heartRate"] as? Double, watchHeartRate > 0 {
                hikeEngine.heartRate = watchHeartRate
            }
            
            // Distance: Use the higher value
            if let watchDistance = metrics["distance"] as? Double, watchDistance > 0 {
                let phoneDistance = hikeEngine.distance.value
                if watchDistance > phoneDistance {
                    hikeEngine.distance = Measurement(value: watchDistance, unit: UnitLength.meters)
                }
            }
            
            // Calories: Use the higher value
            if let watchCalories = metrics["calories"] as? Double, watchCalories > 0 {
                hikeEngine.calories = max(hikeEngine.calories, watchCalories)
            }
            
            // Elapsed Time: Use the longer value
            if let watchElapsedTime = metrics["elapsedTime"] as? TimeInterval, watchElapsedTime > 0 {
                if watchElapsedTime > hikeEngine.elapsedTime {
                    hikeEngine.elapsedTime = watchElapsedTime
                }
            }
        }
        
        print("📱 [MetricsCoordinator] Processed watch metrics with best value selection")
    }
    
    /// Update metrics policy based on current conditions
    func updateMetricsPolicy(indoorMode: Bool, hasGoodGPS: Bool, watchReachable: Bool) {
        // This method can be used to adjust primary device settings based on conditions
        // For now, it just logs the policy update
        print("📱 [MetricsCoordinator] Policy updated - Indoor: \(indoorMode), Good GPS: \(hasGoodGPS), Watch Reachable: \(watchReachable)")
    }
    
    /// Update policy (alias for updateMetricsPolicy with different parameter names)
    func updatePolicy(isIndoor: Bool, hasGoodGPS: Bool, isWatchTracking: Bool) {
        updateMetricsPolicy(indoorMode: isIndoor, hasGoodGPS: hasGoodGPS, watchReachable: isWatchTracking)
    }
    
    /// Get current watch status
    var isWatchAvailable: Bool {
        return watchAvailable
    }
    
    var isWatchReachable: Bool {
        return watchReachable
    }
    
    /// Prepare metrics for sync to watch
    func prepareMetricsForSync() -> [String: Any] {
        var metrics: [String: Any] = [:]
        
        // Handle bike engine
        if let bikeEngine = bikeEngine {
            metrics["distance"] = bikeEngine.distance.value
            metrics["elapsedTime"] = bikeEngine.elapsedTime
            metrics["pace"] = bikeEngine.pace.value
            metrics["calories"] = bikeEngine.calories
            metrics["heartRate"] = bikeEngine.heartRate
            if bikeEngine.cadence > 0 {
                metrics["cadence"] = bikeEngine.cadence
            }
            if bikeEngine.elevationGain.value > 0 {
                metrics["elevationGain"] = bikeEngine.elevationGain.value
            }
        }
        
        // Handle walk engine
        if let walkEngine = walkEngine {
            metrics["distance"] = walkEngine.distance.value
            metrics["elapsedTime"] = walkEngine.elapsedTime
            metrics["pace"] = walkEngine.pace.value
            metrics["calories"] = walkEngine.calories
            metrics["heartRate"] = walkEngine.heartRate
        }
        
        // Handle run engine
        if let runEngine = runEngine {
            metrics["distance"] = runEngine.distance.value
            metrics["elapsedTime"] = runEngine.elapsedTime
            metrics["pace"] = runEngine.pace.value
            metrics["calories"] = runEngine.calories
            metrics["heartRate"] = runEngine.heartRate
            if runEngine.cadence > 0 {
                metrics["cadence"] = runEngine.cadence
            }
            if runEngine.elevationGain.value > 0 {
                metrics["elevationGain"] = runEngine.elevationGain.value
            }
        }
        
        // Handle hike engine
        if let hikeEngine = hikeEngine {
            metrics["distance"] = hikeEngine.distance.value
            metrics["elapsedTime"] = hikeEngine.elapsedTime
            metrics["pace"] = hikeEngine.pace.value
            metrics["calories"] = hikeEngine.calories
            metrics["heartRate"] = hikeEngine.heartRate
            if hikeEngine.elevationGain.value > 0 {
                metrics["elevationGain"] = hikeEngine.elevationGain.value
            }
        }
        
        return metrics
    }
    
    /// Sync metrics to watch immediately
    func syncNow() {
        // Prepare metrics from the active engine
        let metrics = prepareMetricsForSync()
        
        // Send to watch if available and reachable
        guard watchAvailable && watchReachable else {
            print("📱 [MetricsCoordinator] Cannot sync - Watch not available or not reachable")
            return
        }
        
        // Send metrics via WatchConnectivity
        guard WCSession.default.activationState == .activated else {
            print("📱 [MetricsCoordinator] Cannot sync - WCSession not activated")
            return
        }
        
        let session = WCSession.default
        guard session.isReachable else {
            // Use application context as fallback
            do {
                try session.updateApplicationContext(["metrics": metrics])
                print("📱 [MetricsCoordinator] Synced metrics via application context")
            } catch {
                print("❌ [MetricsCoordinator] Error syncing metrics: \(error.localizedDescription)")
            }
            return
        }
        
        // Send via direct message
        session.sendMessage(["type": "metricsUpdate", "metrics": metrics], replyHandler: nil) { error in
            print("❌ [MetricsCoordinator] Error sending metrics: \(error.localizedDescription)")
        }
        print("📱 [MetricsCoordinator] Synced metrics to watch")
    }
}

