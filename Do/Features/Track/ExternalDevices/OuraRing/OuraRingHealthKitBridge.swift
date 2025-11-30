//
//  OuraRingHealthKitBridge.swift
//  Do
//
//  Bridge Oura data via HealthKit
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import HealthKit

class OuraRingHealthKitBridge {
    static let shared = OuraRingHealthKitBridge()
    
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    func syncOuraDataToHealthKit(metrics: WorkoutMetrics) {
        // Write heart rate to HealthKit
        if metrics.heartRate > 0 {
            writeHeartRate(metrics.heartRate)
        }
        
        // Write calories to HealthKit
        if metrics.calories > 0 {
            writeCalories(metrics.calories)
        }
    }
    
    private func writeHeartRate(_ bpm: Double) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let quantity = HKQuantity(unit: HKUnit.count().unitDivided(by: HKUnit.minute()), doubleValue: bpm)
        let sample = HKQuantitySample(type: heartRateType, quantity: quantity, start: Date(), end: Date())
        
        healthStore.save(sample) { success, error in
            if let error = error {
                print("❌ [OuraRingHealthKitBridge] Error saving heart rate: \(error.localizedDescription)")
            }
        }
    }
    
    private func writeCalories(_ kcal: Double) {
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        let quantity = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: kcal)
        let sample = HKQuantitySample(type: caloriesType, quantity: quantity, start: Date(), end: Date())
        
        healthStore.save(sample) { success, error in
            if let error = error {
                print("❌ [OuraRingHealthKitBridge] Error saving calories: \(error.localizedDescription)")
            }
        }
    }
}

