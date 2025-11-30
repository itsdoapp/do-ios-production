//
//  FitbitHealthKitBridge.swift
//  Do
//
//  Bridge Fitbit data via HealthKit
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import HealthKit

class FitbitHealthKitBridge {
    static let shared = FitbitHealthKitBridge()
    
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    func syncFitbitDataToHealthKit(metrics: WorkoutMetrics) {
        if metrics.heartRate > 0 {
            writeHeartRate(metrics.heartRate)
        }
        
        if metrics.distance > 0 {
            writeDistance(metrics.distance)
        }
        
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
                print("❌ [FitbitHealthKitBridge] Error saving heart rate: \(error.localizedDescription)")
            }
        }
    }
    
    private func writeDistance(_ meters: Double) {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return }
        
        let quantity = HKQuantity(unit: HKUnit.meter(), doubleValue: meters)
        let sample = HKQuantitySample(type: distanceType, quantity: quantity, start: Date(), end: Date())
        
        healthStore.save(sample) { success, error in
            if let error = error {
                print("❌ [FitbitHealthKitBridge] Error saving distance: \(error.localizedDescription)")
            }
        }
    }
    
    private func writeCalories(_ kcal: Double) {
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        let quantity = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: kcal)
        let sample = HKQuantitySample(type: caloriesType, quantity: quantity, start: Date(), end: Date())
        
        healthStore.save(sample) { success, error in
            if let error = error {
                print("❌ [FitbitHealthKitBridge] Error saving calories: \(error.localizedDescription)")
            }
        }
    }
}

