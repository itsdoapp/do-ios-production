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
    
    /// Process metrics received from watch
    func processWatchMetrics(metrics: [String: Any]) {
        // Handle bike engine
        if let bikeEngine = bikeEngine {
            // Extract metrics from dictionary
            if let heartRate = metrics["heartRate"] as? Double, heartRate > 0 {
                bikeEngine.heartRate = heartRate
            }
            
            if let cadence = metrics["cadence"] as? Double, cadence > 0 {
                bikeEngine.cadence = cadence
            }
            
            if let distance = metrics["distance"] as? Double, distance > 0 {
                // Only update if watch distance is greater (watch might be more accurate for indoor)
                if distance > bikeEngine.distance.value {
                    bikeEngine.distance = Measurement(value: distance, unit: UnitLength.meters)
                }
            }
            
            if let calories = metrics["calories"] as? Double, calories > 0 {
                bikeEngine.calories = max(bikeEngine.calories, calories)
            }
        }
        
        // Handle walk engine
        if let walkEngine = walkEngine {
            if let heartRate = metrics["heartRate"] as? Double, heartRate > 0 {
                walkEngine.heartRate = heartRate
            }
            
            if let distance = metrics["distance"] as? Double, distance > 0 {
                if distance > walkEngine.distance.value {
                    walkEngine.distance = Measurement(value: distance, unit: UnitLength.meters)
                }
            }
            
            if let calories = metrics["calories"] as? Double, calories > 0 {
                walkEngine.calories = max(walkEngine.calories, calories)
            }
        }
        
        print("📱 [MetricsCoordinator] Processed watch metrics")
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

