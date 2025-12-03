//
//  HealthKitWorkoutManager.swift
//  Do Watch App
//
//  HealthKit workout manager for watchOS with real-time metrics collection
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

#if os(watchOS)
import Foundation
import HealthKit
import Combine

class HealthKitWorkoutManager: NSObject, ObservableObject {
    static let shared = HealthKitWorkoutManager()
    
    @Published var currentMetrics = WorkoutMetrics()
    
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var metricsTimer: Timer?
    private var workoutStartDate: Date?
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Workout Management
    
    /// Start workout with WorkoutType (convenience method)
    func startWorkout(type: WorkoutType, isIndoor: Bool = false) {
        // Meditation is always indoor (no GPS needed)
        let indoor = type == .meditation ? true : isIndoor
        startWorkout(type: type.toHKWorkoutActivityType(), isIndoor: indoor)
    }
    
    /// Start workout with HKWorkoutActivityType
    func startWorkout(type: HKWorkoutActivityType, isIndoor: Bool = false) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("⚠️ HealthKit not available")
            return
        }
        
        // Request authorization before starting workout (including heart rate)
        requestAuthorizationIfNeeded { [weak self] authorized in
            guard let self = self, authorized else {
                print("⚠️ HealthKit authorization not granted, cannot start workout")
                return
            }
            
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = type
            configuration.locationType = isIndoor ? .indoor : .outdoor
            
            do {
                self.workoutSession = try HKWorkoutSession(healthStore: self.healthStore, configuration: configuration)
                self.workoutBuilder = self.workoutSession?.associatedWorkoutBuilder()
                
                self.workoutSession?.delegate = self
                self.workoutStartDate = Date()
                
                self.workoutSession?.startActivity(with: self.workoutStartDate!)
                self.workoutBuilder?.beginCollection(withStart: self.workoutStartDate!) { [weak self] success, error in
                    if let error = error {
                        print("❌ Error starting workout collection: \(error.localizedDescription)")
                    } else {
                        print("✅ Started HealthKit workout collection")
                        self?.startMetricsTimer()
                    }
                }
            } catch {
                print("❌ Error creating workout session: \(error.localizedDescription)")
            }
        }
    }
    
    /// Request HealthKit authorization if needed (including heart rate)
    private func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        // Define all required types
        let workoutType = HKObjectType.workoutType()
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        
        // Check authorization status for all required types, especially heart rate
        let workoutStatus = healthStore.authorizationStatus(for: workoutType)
        let heartRateStatus = healthStore.authorizationStatus(for: heartRateType)
        
        // Only return true if ALL critical types are authorized
        // Heart rate is critical for workout tracking, so we must verify it's authorized
        if workoutStatus == .sharingAuthorized && heartRateStatus == .sharingAuthorized {
            // Check other types as well to ensure comprehensive authorization
            let activeEnergyStatus = healthStore.authorizationStatus(for: activeEnergyType)
            let distanceStatus = healthStore.authorizationStatus(for: distanceType)
            
            // If all critical types are authorized, we're good
            if activeEnergyStatus == .sharingAuthorized && distanceStatus == .sharingAuthorized {
                print("✅ HealthKit already authorized for all required types (including heart rate)")
                completion(true)
                return
            }
        }
        
        // Request authorization with heart rate included
        let typesToRead: Set<HKObjectType> = [
            workoutType,
            heartRateType,
            activeEnergyType,
            distanceType,
            stepCountType
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            workoutType,
            heartRateType,
            activeEnergyType,
            distanceType
        ]
        
        print("📋 Requesting HealthKit authorization for all required types (including heart rate)")
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            if let error = error {
                print("❌ HealthKit authorization error: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ HealthKit authorization granted (including heart rate)")
                completion(success)
            }
        }
    }
    
    func pauseWorkout() {
        workoutSession?.pause()
        metricsTimer?.invalidate()
        print("⏸ Workout paused")
    }
    
    func resumeWorkout() {
        workoutSession?.resume()
        startMetricsTimer()
        print("▶️ Workout resumed")
    }
    
    func endWorkout() {
        guard let builder = workoutBuilder, let startDate = workoutStartDate else { return }
        
        let endDate = Date()
        builder.endCollection(withEnd: endDate) { [weak self] success, error in
            if let error = error {
                print("❌ Error ending workout collection: \(error.localizedDescription)")
            } else {
                builder.finishWorkout { workout, error in
                    if let error = error {
                        print("❌ Error finishing workout: \(error.localizedDescription)")
                    } else {
                        print("✅ Workout finished and saved to HealthKit")
                    }
                    self?.cleanup()
                }
            }
        }
    }
    
    func cancelWorkout() {
        guard let builder = workoutBuilder else { return }
        builder.endCollection(withEnd: Date()) { [weak self] success, error in
            self?.cleanup()
        }
    }
    
    private func cleanup() {
        metricsTimer?.invalidate()
        metricsTimer = nil
        workoutSession?.end()
        workoutSession = nil
        workoutBuilder = nil
        workoutStartDate = nil
        currentMetrics = WorkoutMetrics()
    }
    
    // MARK: - Metrics Collection
    
    private func startMetricsTimer() {
        metricsTimer?.invalidate()
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }
    
    private func updateMetrics() {
        guard let builder = workoutBuilder, let startDate = workoutStartDate else { return }
        
        var metrics = WorkoutMetrics()
        metrics.elapsedTime = Date().timeIntervalSince(startDate)
        
        // Get distance (skip for meditation/mindAndBody workouts)
        if builder.workoutConfiguration.activityType != .mindAndBody {
            if let distanceType = getDistanceType(for: builder.workoutConfiguration.activityType),
               let distanceStat = builder.statistics(for: distanceType) {
                metrics.distance = distanceStat.sumQuantity()?.doubleValue(for: .meter()) ?? 0
            }
        }
        
        // Get heart rate
        if let heartRateStat = builder.statistics(for: HKQuantityType.quantityType(forIdentifier: .heartRate)!) {
            metrics.heartRate = heartRateStat.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())) ?? 0
        }
        
        // Get active energy (calories)
        if let energyStat = builder.statistics(for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!) {
            metrics.calories = energyStat.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        }
        
        // Calculate pace
        if metrics.distance > 0 && metrics.elapsedTime > 0 {
            metrics.pace = metrics.elapsedTime / metrics.distance
        }
        
        // Get cadence (steps per minute) - skip for meditation
        if builder.workoutConfiguration.activityType != .mindAndBody {
            if let stepCountStat = builder.statistics(for: HKQuantityType.quantityType(forIdentifier: .stepCount)!) {
                let steps = stepCountStat.sumQuantity()?.doubleValue(for: .count()) ?? 0
                if metrics.elapsedTime > 0 {
                    metrics.cadence = (steps / metrics.elapsedTime) * 60.0
                }
            }
            
            // Get elevation gain (for hiking)
            if let elevationStat = builder.statistics(for: HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!) {
                // Convert flights to meters (approximate: 1 flight = 3 meters)
                let flights = elevationStat.sumQuantity()?.doubleValue(for: .count()) ?? 0
                metrics.elevationGain = flights * 3.0
            }
        }
        
        DispatchQueue.main.async {
            self.currentMetrics = metrics
        }
    }
    
    func getCurrentMetrics() -> WorkoutMetrics? {
        return currentMetrics
    }
    
    func updateHeartRateZone(heartRate: Double) {
        // This can be used to update heart rate zones if needed
        // Implementation depends on HeartRateZoneService integration
    }
    
    // MARK: - Helper Methods
    
    private func getDistanceType(for activityType: HKWorkoutActivityType) -> HKQuantityType? {
        switch activityType {
        case .cycling:
            return HKQuantityType.quantityType(forIdentifier: .distanceCycling)
        case .swimming:
            return HKQuantityType.quantityType(forIdentifier: .distanceSwimming)
        case .mindAndBody:
            // Meditation doesn't track distance
            return nil
        default:
            return HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension HealthKitWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("📱 Workout session state changed: \(fromState.rawValue) -> \(toState.rawValue)")
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("❌ Workout session error: \(error.localizedDescription)")
    }
}
#endif
