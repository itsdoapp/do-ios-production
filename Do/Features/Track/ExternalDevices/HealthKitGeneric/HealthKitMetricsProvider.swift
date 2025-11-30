//
//  HealthKitMetricsProvider.swift
//  Do
//
//  Generic HealthKit metrics provider
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import HealthKit

class HealthKitMetricsProvider {
    static let shared = HealthKitMetricsProvider()
    
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    func fetchWorkoutMetrics(workoutStartDate: Date, completion: @escaping (WorkoutMetrics?) -> Void) {
        var metrics = WorkoutMetrics()
        let group = DispatchGroup()
        
        // Fetch heart rate
        group.enter()
        fetchHeartRate(startDate: workoutStartDate) { heartRate in
            metrics.heartRate = heartRate ?? 0
            group.leave()
        }
        
        // Fetch distance
        group.enter()
        fetchDistance(startDate: workoutStartDate) { distance in
            metrics.distance = distance ?? 0
            group.leave()
        }
        
        // Fetch calories
        group.enter()
        fetchCalories(startDate: workoutStartDate) { calories in
            metrics.calories = calories ?? 0
            group.leave()
        }
        
        // Calculate elapsed time
        metrics.elapsedTime = Date().timeIntervalSince(workoutStartDate)
        
        // Calculate pace
        group.notify(queue: .main) {
            if metrics.distance > 0 && metrics.elapsedTime > 0 {
                metrics.pace = metrics.elapsedTime / metrics.distance
            }
            completion(metrics)
        }
    }
    
    private func fetchHeartRate(startDate: Date, completion: @escaping (Double?) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: .mostRecent) { query, statistics, error in
            guard let statistics = statistics, let quantity = statistics.mostRecentQuantity() else {
                completion(nil)
                return
            }
            
            let heartRate = quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
            completion(heartRate)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchDistance(startDate: Date, completion: @escaping (Double?) -> Void) {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { query, statistics, error in
            guard let statistics = statistics, let sum = statistics.sumQuantity() else {
                completion(nil)
                return
            }
            
            let distance = sum.doubleValue(for: HKUnit.meter())
            completion(distance)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchCalories(startDate: Date, completion: @escaping (Double?) -> Void) {
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: caloriesType, quantitySamplePredicate: predicate, options: .cumulativeSum) { query, statistics, error in
            guard let statistics = statistics, let sum = statistics.sumQuantity() else {
                completion(nil)
                return
            }
            
            let calories = sum.doubleValue(for: HKUnit.kilocalorie())
            completion(calories)
        }
        
        healthStore.execute(query)
    }
}

