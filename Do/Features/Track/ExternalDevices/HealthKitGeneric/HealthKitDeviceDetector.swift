//
//  HealthKitDeviceDetector.swift
//  Do
//
//  Detects all HealthKit-compatible devices
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import HealthKit

class HealthKitDeviceDetector {
    static let shared = HealthKitDeviceDetector()
    
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    func detectDevices() async -> [String] {
        guard HKHealthStore.isHealthDataAvailable() else {
            return []
        }
        
        var deviceNames: Set<String> = []
        
        // Query for workout samples to detect devices
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForWorkouts(with: .running)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { query, samples, error in
                guard let samples = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }
                
                for workout in samples {
                    if let device = workout.device {
                        if let name = device.name {
                            deviceNames.insert(name)
                        }
                    }
                }
                
                continuation.resume(returning: Array(deviceNames))
            }
            
            healthStore.execute(query)
        }
    }
    
    func getDeviceInfo(for deviceName: String) -> DeviceInfo? {
        // Query HealthKit for device information
        // This is a simplified version - in production, you'd query more details
        return DeviceInfo(name: deviceName, manufacturer: "Unknown", model: "Unknown")
    }
}

struct DeviceInfo {
    let name: String
    let manufacturer: String
    let model: String
}

