//
//  DeviceCoordinationEngine.swift
//  Do Watch App
//
//  Determines primary device for each metric
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

class DeviceCoordinationEngine {
    static let shared = DeviceCoordinationEngine()
    
    private init() {}
    
    // MARK: - Primary Device Determination
    
    func determinePrimaryDevice(for metric: MetricType, workoutType: WorkoutType, isIndoor: Bool) -> MetricsSource {
        switch metric {
        case .distance:
            // Phone is primary for GPS-based metrics when outdoors
            return isIndoor ? .watch : .phone
            
        case .pace:
            // Phone is primary for pace (calculated from GPS distance)
            return isIndoor ? .watch : .phone
            
        case .heartRate:
            // Watch is primary for heart rate (more accurate sensors)
            return .watch
            
        case .cadence:
            // Watch is primary for cadence (step/strike detection)
            return .watch
            
        case .calories:
            // Use watch if available, otherwise phone
            return .watch
            
        case .elevation:
            // Phone is primary for elevation (GPS-based)
            return isIndoor ? .watch : .phone
            
        case .speed:
            // Phone is primary for speed (GPS-based)
            return isIndoor ? .watch : .phone
        }
    }
    
    // MARK: - Fallback Logic
    
    func getFallbackDevice(for metric: MetricType, primaryDevice: MetricsSource) -> MetricsSource {
        switch primaryDevice {
        case .phone:
            return .watch
        case .watch:
            return .phone
        default:
            return .phone
        }
    }
    
    // MARK: - Quality Scoring
    
    func scoreDeviceQuality(device: MetricsSource, for metric: MetricType, workoutType: WorkoutType) -> Double {
        let primary = determinePrimaryDevice(for: metric, workoutType: workoutType, isIndoor: false)
        
        if device == primary {
            return 1.0
        } else {
            return 0.7 // Fallback devices get lower score
        }
    }
    
    // MARK: - Best Data Source Selection
    
    func selectBestDataSource(for metric: MetricType, 
                             workoutType: WorkoutType,
                             isIndoor: Bool,
                             availableSources: [MetricsSource]) -> MetricsSource? {
        let primary = determinePrimaryDevice(for: metric, workoutType: workoutType, isIndoor: isIndoor)
        
        // If primary is available, use it
        if availableSources.contains(primary) {
            return primary
        }
        
        // Otherwise, use fallback
        let fallback = getFallbackDevice(for: metric, primaryDevice: primary)
        if availableSources.contains(fallback) {
            return fallback
        }
        
        // Return first available source
        return availableSources.first
    }
}



