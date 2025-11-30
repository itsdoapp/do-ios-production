//
//  RunningWorkoutManager.swift
//  Do
//
//  Manager for running workouts and HealthKit integration
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import HealthKit
import Combine

class RunningWorkoutManager: ObservableObject {
    static let shared = RunningWorkoutManager()
    
    // MARK: - Properties
    
    private let healthStore = HKHealthStore()
    @Published var isWorkoutActive = false
    @Published var currentWorkout: HKWorkout?
    
    // Note: HKLiveWorkoutBuilder is watchOS-only, not available on iOS
    // We use HKWorkoutBuilder for all iOS versions (available since iOS 10.0)
    private var workoutBuilder: HKWorkoutBuilder?
    private var workoutStartDate: Date?
    
    // MARK: - Initialization
    
    private init() {
        requestHealthKitAuthorization()
    }
    
    // MARK: - HealthKit Authorization
    
    func requestHealthKitAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit is not available on this device")
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            if let error = error {
                print("❌ HealthKit authorization failed: \(error.localizedDescription)")
            } else if success {
                print("✅ HealthKit authorization granted")
            }
        }
    }
    
    // MARK: - Workout Management
    
    func startWorkout(type: HKWorkoutActivityType = .running, locationType: HKWorkoutSessionLocationType = .outdoor) {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = type
        configuration.locationType = locationType
        
        workoutStartDate = Date()
        
        // Note: HKLiveWorkoutBuilder is watchOS-only, not available on iOS
        // We use HKWorkoutBuilder for all iOS versions (available since iOS 10.0)
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: nil)
        workoutBuilder = builder
        
        builder.beginCollection(withStart: Date()) { [weak self] success, error in
            if let error = error {
                print("❌ Error starting workout collection: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    self?.isWorkoutActive = true
                }
            }
        }
        
        print("✅ Workout started")
    }
    
    func pauseWorkout() {
        // Note: HKWorkoutBuilder doesn't have pause/resume methods on iOS
        // Pause/resume functionality would need to be handled at the app level
        print("⏸ Workout paused")
    }
    
    func resumeWorkout() {
        // Note: HKWorkoutBuilder doesn't have pause/resume methods on iOS
        // Pause/resume functionality would need to be handled at the app level
        print("▶️ Workout resumed")
    }
    
    func endWorkout(completion: @escaping (HKWorkout?) -> Void) {
        guard let builder = workoutBuilder else {
            completion(nil)
            return
        }
        
        builder.endCollection(withEnd: Date()) { [weak self] success, error in
            guard let self = self else {
                completion(nil)
                return
            }
            
            if let error = error {
                print("❌ Error ending workout collection: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            builder.finishWorkout { workout, error in
                DispatchQueue.main.async {
                    self.isWorkoutActive = false
                    self.currentWorkout = workout
                    self.workoutBuilder = nil
                }
                
                if let error = error {
                    print("❌ Error finishing workout: \(error.localizedDescription)")
                    completion(nil)
                } else {
                    print("✅ Workout finished and saved to HealthKit")
                    completion(workout)
                }
            }
        }
    }
    
    // MARK: - Workout Data
    
    func updateWorkoutMetrics(elapsedTime: TimeInterval, distance: Double, pace: Double, calories: Double, heartRate: Double) {
        // This can be used to manually update workout metrics if needed
        // HKWorkoutBuilder collects data automatically from HealthKit sources
        // Manual updates can be added here if needed
        print("📊 [RunningWorkoutManager] Metrics updated - Distance: \(distance)m, Time: \(elapsedTime)s, Pace: \(pace), Calories: \(calories), HR: \(heartRate)")
    }
    
    func addWorkoutEvent(type: HKWorkoutEventType, date: Date = Date()) {
        guard let builder = workoutBuilder else { return }
        
        let event = HKWorkoutEvent(type: type, dateInterval: DateInterval(start: date, duration: 0), metadata: nil)
        builder.addWorkoutEvents([event]) { success, error in
            if let error = error {
                print("❌ Error adding workout event: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Query Workouts
    
    func fetchRecentWorkouts(limit: Int = 10, completion: @escaping ([HKWorkout]) -> Void) {
        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: workoutType, predicate: nil, limit: limit, sortDescriptors: [sortDescriptor]) { query, samples, error in
            if let error = error {
                print("❌ Error fetching workouts: \(error.localizedDescription)")
                completion([])
                return
            }
            
            let workouts = samples as? [HKWorkout] ?? []
            completion(workouts)
        }
        
        healthStore.execute(query)
    }
}

