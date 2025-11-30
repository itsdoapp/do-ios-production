//
//  ElevationTracker.swift
//  Do
//
//  Tracks elevation gain and loss during workouts
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import CoreLocation

class ElevationTracker {
    private var totalElevationGain: Double = 0.0 // in meters
    private var totalElevationLoss: Double = 0.0 // in meters
    private var lastAltitude: Double?
    private let minimumElevationChange: Double = 1.0 // meters - filter out noise
    
    init() {
        reset()
    }
    
    func reset() {
        totalElevationGain = 0.0
        totalElevationLoss = 0.0
        lastAltitude = nil
    }
    
    /// Update elevation tracking with a new location
    func updateElevation(newLocation: CLLocation) {
        // Only track if vertical accuracy is reasonable
        guard newLocation.verticalAccuracy > 0 && newLocation.verticalAccuracy < 50 else {
            return
        }
        
        let currentAltitude = newLocation.altitude
        
        // If we have a previous altitude, calculate the change
        if let previousAltitude = lastAltitude {
            let elevationChange = currentAltitude - previousAltitude
            
            // Only count significant changes to filter out GPS noise
            if abs(elevationChange) >= minimumElevationChange {
                if elevationChange > 0 {
                    totalElevationGain += elevationChange
                } else {
                    totalElevationLoss += abs(elevationChange)
                }
            }
        }
        
        lastAltitude = currentAltitude
    }
    
    /// Get total elevation gain as a Measurement
    func getElevationGain() -> Measurement<UnitLength> {
        return Measurement(value: totalElevationGain, unit: UnitLength.meters)
    }
    
    /// Get total elevation loss as a Measurement
    func getElevationLoss() -> Measurement<UnitLength> {
        return Measurement(value: totalElevationLoss, unit: UnitLength.meters)
    }
    
    /// Get raw elevation gain value in meters
    var elevationGainValue: Double {
        return totalElevationGain
    }
    
    /// Get raw elevation loss value in meters
    var elevationLossValue: Double {
        return totalElevationLoss
    }
}




