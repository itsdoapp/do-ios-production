//
//  DeviceCoordinationEngine.swift
//  Do
//
//  Determines primary device for each metric (iOS side)
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
            return isIndoor ? .watch : .phone
            
        case .pace:
            return isIndoor ? .watch : .phone
            
        case .heartRate:
            return .watch
            
        case .cadence:
            return .watch
            
        case .calories:
            return .watch
            
        case .elevation:
            return isIndoor ? .watch : .phone
            
        case .speed:
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
            return 0.7
        }
    }
    
    // MARK: - Best Data Source Selection
    
    func selectBestDataSource(for metric: MetricType,
                             workoutType: WorkoutType,
                             isIndoor: Bool,
                             availableSources: [MetricsSource]) -> MetricsSource? {
        let primary = determinePrimaryDevice(for: metric, workoutType: workoutType, isIndoor: isIndoor)
        
        if availableSources.contains(primary) {
            return primary
        }
        
        let fallback = getFallbackDevice(for: metric, primaryDevice: primary)
        if availableSources.contains(fallback) {
            return fallback
        }
        
        return availableSources.first
    }
    
    // MARK: - Device Priority for Workout Type
    
    func getDevicePriority(for workoutType: WorkoutType, isIndoor: Bool) -> [MetricsSource] {
        if isIndoor {
            return [.watch, .healthKit, .phone]
        } else {
            return [.phone, .watch, .healthKit]
        }
    }
}

