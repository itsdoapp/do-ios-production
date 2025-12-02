//
//  HealthKitWorkoutManager.swift
//  Do Watch App
//
//  Manages HealthKit workout sessions
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import HealthKit
import WatchKit

class HealthKitWorkoutManager: NSObject, ObservableObject {
    static let shared = HealthKitWorkoutManager()
    
    private let healthStore = HKHealthStore()
    private var currentSession: HKWorkoutSession?
    private var currentBuilder: HKLiveWorkoutBuilder?
    
    // Published metrics for UI updates
    @Published var currentMetrics: WorkoutMetrics?
    
    // watchOS 9.0+ Services
    private let heartRateZoneService = HeartRateZoneService.shared
    private let advancedMetricsService = AdvancedWorkoutMetricsService.shared
    private var metricsUpdateTimer: Timer?
    private var basicMetricsTimer: Timer?
    
    private override init() {
        super.init()
    }
    
    func startWorkout(type: WorkoutType, isIndoor: Bool = false) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("⚠️ [HealthKitWorkoutManager] HealthKit not available")
            return
        }
        
        let hkWorkoutType: HKWorkoutActivityType
        switch type {
        case .running: hkWorkoutType = .running
        case .walking: hkWorkoutType = .walking
        case .biking: hkWorkoutType = .cycling
        case .hiking: hkWorkoutType = .hiking
        case .swimming: hkWorkoutType = .swimming
        case .gym: hkWorkoutType = .traditionalStrengthTraining
        case .sports: hkWorkoutType = .other // Use .other for general sports
        case .meditation: hkWorkoutType = .mindAndBody
        }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = hkWorkoutType
        // Set location type based on indoor/outdoor mode
        // For gym workouts, always use indoor. For others, use the provided parameter.
        if type == .gym {
            configuration.locationType = .indoor
        } else {
            configuration.locationType = isIndoor ? .indoor : .outdoor
        }
        
        print("🏃 [HealthKitWorkoutManager] Starting \(type.rawValue) workout (\(isIndoor ? "indoor" : "outdoor"))")
        
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            
            session.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            currentSession = session
            currentBuilder = builder
            
            // Start advanced metrics collection (watchOS 9.0+)
            Task { @MainActor in
                advancedMetricsService.startCollecting(with: builder)
            }
            
            // Reset heart rate zone tracking
            Task { @MainActor in
                heartRateZoneService.resetZoneTracking()
            }
            
            let startDate = Date()
            session.startActivity(with: startDate)
            builder.beginCollection(withStart: startDate) { [weak self] success, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let error = error {
                        print("❌ [HealthKitWorkoutManager] Error starting workout: \(error.localizedDescription)")
                        TrackingTestLogger.shared.logError(category: type.rawValue.uppercased(), message: "Error starting workout", error: error)
                    } else {
                        print("✅ [HealthKitWorkoutManager] Workout started successfully")
                        
                        // Test logging
                        TrackingTestLogger.shared.logInfo(category: type.rawValue.uppercased(), message: "HealthKit workout started successfully")
                        
                        // Start metrics update timer (watchOS 9.0+)
                        self.startMetricsUpdates()
                    }
                }
            }
        } catch {
            print("❌ [HealthKitWorkoutManager] Failed to create workout session: \(error.localizedDescription)")
        }
    }
    
    func pauseWorkout() {
        currentSession?.pause()
    }
    
    func resumeWorkout() {
        currentSession?.resume()
    }
    
    func endWorkout() {
        guard let session = currentSession, let builder = currentBuilder else { return }
        
        // Test logging - determine workout type from active workout
        if let workout = WatchWorkoutCoordinator.shared.activeWorkout {
            TrackingTestLogger.shared.logInfo(category: workout.workoutType.rawValue.uppercased(), message: "Ending HealthKit workout")
        }
        
        // Stop metrics updates immediately
        stopMetricsUpdates()
        Task { @MainActor in
            advancedMetricsService.stopCollecting()
        }
        
        // Clear references before async operations to prevent new workouts
        let sessionToEnd = session
        let builderToFinish = builder
        currentSession = nil
        currentBuilder = nil
        
        let endDate = Date()
        sessionToEnd.end()
        builderToFinish.endCollection(withEnd: endDate) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [HealthKitWorkoutManager] Error ending collection: \(error.localizedDescription)")
                    if let workout = WatchWorkoutCoordinator.shared.activeWorkout {
                        TrackingTestLogger.shared.logError(category: workout.workoutType.rawValue.uppercased(), message: "Error ending collection", error: error)
                    }
                }
                
                builderToFinish.finishWorkout { workout, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ [HealthKitWorkoutManager] Error finishing workout: \(error.localizedDescription)")
                            if let activeWorkout = WatchWorkoutCoordinator.shared.activeWorkout {
                                TrackingTestLogger.shared.logError(category: activeWorkout.workoutType.rawValue.uppercased(), message: "Error finishing workout", error: error)
                            }
                        } else {
                            print("✅ [HealthKitWorkoutManager] Workout finished and saved to HealthKit")
                            if let activeWorkout = WatchWorkoutCoordinator.shared.activeWorkout {
                                TrackingTestLogger.shared.logInfo(category: activeWorkout.workoutType.rawValue.uppercased(), message: "Workout finished and saved to HealthKit")
                            }
                        }
                    }
                }
            }
        }
    }
    
    func cancelWorkout() {
        guard let session = currentSession, let builder = currentBuilder else { return }
        
        // Stop metrics updates immediately
        stopMetricsUpdates()
        Task { @MainActor in
            advancedMetricsService.stopCollecting()
        }
        
        // Clear references before async operations to prevent new workouts
        let sessionToCancel = session
        let builderToCancel = builder
        currentSession = nil
        currentBuilder = nil
        
        let endDate = Date()
        sessionToCancel.end()
        builderToCancel.endCollection(withEnd: endDate) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [HealthKitWorkoutManager] Error ending collection: \(error.localizedDescription)")
                }
                // Don't finish workout on cancel - just discard it
                print("⚠️ [HealthKitWorkoutManager] Workout cancelled, not saving to HealthKit")
            }
        }
    }
    
    // MARK: - watchOS 9.0+ Metrics Updates
    
    private func startMetricsUpdates() {
        // Stop any existing timers first
        stopMetricsUpdates()
        
        // Update basic metrics every second from HealthKit
        basicMetricsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                // Update current metrics from HealthKit
                if let metrics = self.getCurrentMetrics() {
                    self.currentMetrics = metrics
                    
                    // Test logging - log metrics periodically (every 5 seconds to avoid spam)
                    let currentTime = Date().timeIntervalSince1970
                    let lastLogKey = "lastHealthKitMetricLog"
                    let lastLogTime = UserDefaults.standard.double(forKey: lastLogKey)
                    
                    if currentTime - lastLogTime >= 5.0 {
                        if let workout = WatchWorkoutCoordinator.shared.activeWorkout {
                            TrackingTestLogger.shared.logMetricUpdate(device: "WATCH", category: workout.workoutType.rawValue.uppercased(), metric: "distance", value: metrics.distance, source: "HealthKit")
                            TrackingTestLogger.shared.logMetricUpdate(device: "WATCH", category: workout.workoutType.rawValue.uppercased(), metric: "heartRate", value: metrics.heartRate, source: "HealthKit")
                            TrackingTestLogger.shared.logMetricUpdate(device: "WATCH", category: workout.workoutType.rawValue.uppercased(), metric: "calories", value: metrics.calories, source: "HealthKit")
                            if let cadence = metrics.cadence {
                                TrackingTestLogger.shared.logMetricUpdate(device: "WATCH", category: workout.workoutType.rawValue.uppercased(), metric: "cadence", value: cadence, source: "HealthKit")
                            }
                        }
                        UserDefaults.standard.set(currentTime, forKey: lastLogKey)
                    }
                }
            }
        }
        if let timer = basicMetricsTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        // Update advanced metrics every 5 seconds
        metricsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.advancedMetricsService.updateAllMetrics()
            }
        }
        
        // Ensure timer is added to main run loop
        if let timer = metricsUpdateTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopMetricsUpdates() {
        basicMetricsTimer?.invalidate()
        basicMetricsTimer = nil
        metricsUpdateTimer?.invalidate()
        metricsUpdateTimer = nil
    }
    
    /// Update heart rate zone based on current heart rate
    func updateHeartRateZone(heartRate: Double) {
        Task { @MainActor in
            heartRateZoneService.updateZone(for: heartRate, duration: 1.0)
        }
    }
    
    /// Get current heart rate zone
    func getCurrentHeartRateZone() async -> HeartRateZone? {
        await MainActor.run {
            heartRateZoneService.currentZone
        }
    }
    
    /// Get zone summary
    func getZoneSummary() async -> (totalTime: TimeInterval, zones: [HeartRateZone: TimeInterval]) {
        await MainActor.run {
            heartRateZoneService.getZoneSummary()
        }
    }
    
    /// Get advanced metrics
    func getAdvancedMetrics() async -> AdvancedRunningMetrics {
        await MainActor.run {
            advancedMetricsService.currentMetrics
        }
    }
    
    // MARK: - Live Metrics from HealthKit
    
    /// Get current workout metrics from HealthKit builder
    func getCurrentMetrics() -> WorkoutMetrics? {
        guard let builder = currentBuilder else { return nil }
        
        var metrics = WorkoutMetrics()
        
        // Get distance - try different distance types based on workout
        var distanceFound = false
        
        // Try walking/running distance first
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
           let stats = builder.statistics(for: distanceType),
           let sum = stats.sumQuantity() {
            metrics.distance = sum.doubleValue(for: HKUnit.meter())
            distanceFound = true
        }
        
        // If not found, try cycling distance
        if !distanceFound,
           let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceCycling),
           let stats = builder.statistics(for: distanceType),
           let sum = stats.sumQuantity() {
            metrics.distance = sum.doubleValue(for: HKUnit.meter())
            distanceFound = true
        }
        
        // If still not found, try swimming distance
        if !distanceFound,
           let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceSwimming),
           let stats = builder.statistics(for: distanceType),
           let sum = stats.sumQuantity() {
            metrics.distance = sum.doubleValue(for: HKUnit.meter())
        }
        
        // Get heart rate (most recent)
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
           let stats = builder.statistics(for: hrType),
           let mostRecent = stats.mostRecentQuantity() {
            metrics.heartRate = mostRecent.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
        }
        
        // Get active energy (calories)
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           let stats = builder.statistics(for: energyType),
           let sum = stats.sumQuantity() {
            metrics.calories = sum.doubleValue(for: HKUnit.kilocalorie())
        }
        
        // Calculate elapsed time from workout start
        if let startDate = builder.startDate {
            metrics.elapsedTime = Date().timeIntervalSince(startDate)
        }
        
        // Calculate pace (seconds per meter)
        if metrics.distance > 0 && metrics.elapsedTime > 0 {
            metrics.pace = metrics.elapsedTime / metrics.distance
        }
        
        // Get cadence (steps per minute for running/walking)
        if let cadenceType = HKQuantityType.quantityType(forIdentifier: .stepCount),
           let stats = builder.statistics(for: cadenceType) {
            // Calculate cadence from step count and elapsed time
            if let sum = stats.sumQuantity(), metrics.elapsedTime > 0 {
                let steps = sum.doubleValue(for: HKUnit.count())
                metrics.cadence = (steps / metrics.elapsedTime) * 60.0 // steps per minute
            }
        }
        
        return metrics
    }
}

extension HealthKitWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("🏃 [HealthKitWorkoutManager] State changed: \(fromState.rawValue) -> \(toState.rawValue)")
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("❌ [HealthKitWorkoutManager] Workout session failed: \(error.localizedDescription)")
    }
}

