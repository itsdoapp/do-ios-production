//
//  WatchWorkoutCoordinator.swift
//  Do Watch App
//
//  Coordinates workout state between watch and phone
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import Combine

class WatchWorkoutCoordinator: ObservableObject {
    static let shared = WatchWorkoutCoordinator()
    
    @Published var activeWorkout: WatchWorkoutSession?
    @Published var isHandoffInProgress = false
    @Published var handoffDirection: HandoffDirection?
    
    // Device coordination flags - track which device is primary for each metric
    var isWatchPrimaryForDistance = true  // Default: watch is primary until phone says otherwise
    var isWatchPrimaryForPace = true
    var isWatchPrimaryForHeartRate = true  // Watch is always better for HR
    var isWatchPrimaryForCalories = true
    var isWatchPrimaryForCadence = true
    var isWatchPrimaryForElevation = false  // Phone GPS is better for elevation
    
    private var cancellables = Set<AnyCancellable>()
    private let connectivityManager = WatchConnectivityManager.shared
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutHandoffRequest"))
            .sink { [weak self] notification in
                self?.handleHandoffRequest(notification.userInfo)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Workout Management
    
    func startWorkout(type: WorkoutType) {
        guard activeWorkout == nil else {
            print("⚠️ [WatchWorkoutCoordinator] Workout already active")
            return
        }
        
        let session = WatchWorkoutSession(
            workoutType: type,
            state: .starting,
            deviceSource: .watch
        )
        
        activeWorkout = session
        
        // Notify phone
        connectivityManager.sendMessage([
            "type": "workoutStateChange",
            "workoutType": type.rawValue,
            "state": WorkoutState.starting.rawValue,
            "workoutId": session.id
        ])
        
        // Special handling for gym workouts
        if type == .gym {
            connectivityManager.sendMessage([
                "type": "gymWorkoutStart",
                "workoutId": session.id,
                "timestamp": Date().timeIntervalSince1970
            ])
        }
    }
    
    func pauseWorkout() {
        guard var workout = activeWorkout, workout.state == .running else { return }
        
        workout.state = .paused
        workout.lastUpdateDate = Date()
        activeWorkout = workout
        
        connectivityManager.sendMessage([
            "type": "workoutStateChange",
            "workoutType": workout.workoutType.rawValue,
            "state": WorkoutState.paused.rawValue,
            "workoutId": workout.id
        ])
    }
    
    func resumeWorkout() {
        guard var workout = activeWorkout, workout.state == .paused else { return }
        
        workout.state = .running
        workout.lastUpdateDate = Date()
        activeWorkout = workout
        
        connectivityManager.sendMessage([
            "type": "workoutStateChange",
            "workoutType": workout.workoutType.rawValue,
            "state": WorkoutState.running.rawValue,
            "workoutId": workout.id
        ])
    }
    
    func stopWorkout() {
        guard var workout = activeWorkout else { return }
        
        workout.state = .stopping
        workout.lastUpdateDate = Date()
        activeWorkout = workout
        
        connectivityManager.sendMessage([
            "type": "workoutStateChange",
            "workoutType": workout.workoutType.rawValue,
            "state": WorkoutState.stopping.rawValue,
            "workoutId": workout.id
        ])
        
        // Complete the workout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            workout.state = .completed
            workout.lastUpdateDate = Date()
            self.activeWorkout = nil
        }
    }
    
    func updateMetrics(_ metrics: WorkoutMetrics) {
        guard var workout = activeWorkout else { return }
        
        workout.metrics = metrics
        workout.lastUpdateDate = Date()
        activeWorkout = workout
        
        // Only send metrics that watch is primary for (aligned with phone's coordination system)
        var metricsToSend: [String: Any] = [:]
        
        // Always send elapsed time (both devices need it)
        metricsToSend["elapsedTime"] = metrics.elapsedTime
        
        // Only send metrics watch is primary for
        if isWatchPrimaryForDistance {
            metricsToSend["distance"] = metrics.distance
        }
        if isWatchPrimaryForPace {
            metricsToSend["pace"] = metrics.pace
        }
        if isWatchPrimaryForHeartRate {
            metricsToSend["heartRate"] = metrics.heartRate
        }
        if isWatchPrimaryForCalories {
            metricsToSend["calories"] = metrics.calories
        }
        if isWatchPrimaryForCadence, let cadence = metrics.cadence {
            metricsToSend["cadence"] = cadence
        }
        if isWatchPrimaryForElevation, let elevation = metrics.elevationGain {
            metricsToSend["elevationGain"] = elevation
        }
        
        // Include coordination flags so phone knows which metrics to use
        let message: [String: Any] = [
            "type": "workoutMetrics",
            "workoutType": workout.workoutType.rawValue,
            "metrics": metricsToSend,
            "isWatchPrimaryForDistance": isWatchPrimaryForDistance,
            "isWatchPrimaryForPace": isWatchPrimaryForPace,
            "isWatchPrimaryForHeartRate": isWatchPrimaryForHeartRate,
            "isWatchPrimaryForCalories": isWatchPrimaryForCalories,
            "isWatchPrimaryForCadence": isWatchPrimaryForCadence,
            "isWatchPrimaryForElevation": isWatchPrimaryForElevation,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        connectivityManager.sendMessage(message)
    }
    
    // Update coordination flags from phone messages
    func updateCoordinationFlags(from phoneMessage: [String: Any]) {
        if let isPrimaryForDistance = phoneMessage["isPrimaryForDistance"] as? Bool {
            isWatchPrimaryForDistance = !isPrimaryForDistance  // If phone is primary, watch is not
        }
        if let isPrimaryForPace = phoneMessage["isPrimaryForPace"] as? Bool {
            isWatchPrimaryForPace = !isPrimaryForPace
        }
        if let isPrimaryForHeartRate = phoneMessage["isPrimaryForHeartRate"] as? Bool {
            isWatchPrimaryForHeartRate = !isPrimaryForHeartRate
        }
        if let isPrimaryForCalories = phoneMessage["isPrimaryForCalories"] as? Bool {
            isWatchPrimaryForCalories = !isPrimaryForCalories
        }
        if let isPrimaryForCadence = phoneMessage["isPrimaryForCadence"] as? Bool {
            isWatchPrimaryForCadence = !isPrimaryForCadence
        }
        
        // Heart rate: Watch is always better, but respect phone's flag for coordination
        // Elevation: Phone GPS is always better
        isWatchPrimaryForElevation = false
        
        print("⌚️ [WatchWorkoutCoordinator] Updated coordination flags - Distance: \(isWatchPrimaryForDistance), Pace: \(isWatchPrimaryForPace), HR: \(isWatchPrimaryForHeartRate)")
    }
    
    // MARK: - Handoff
    
    func initiateHandoffToPhone(completion: @escaping (Bool) -> Void) {
        guard let workout = activeWorkout else {
            completion(false)
            return
        }
        
        isHandoffInProgress = true
        handoffDirection = .watchToPhone
        
        let handoffMessage = WorkoutHandoffMessage(
            direction: .watchToPhone,
            workoutType: workout.workoutType,
            workoutId: workout.id,
            metrics: workout.metrics,
            state: workout.state,
            startDate: workout.startDate
        )
        
        connectivityManager.sendMessage(handoffMessage.toDictionary()) { response in
            DispatchQueue.main.async {
                self.isHandoffInProgress = false
                let accepted = response["accepted"] as? Bool ?? false
                if accepted {
                    // Clear active workout on watch
                    self.activeWorkout = nil
                }
                completion(accepted)
            }
        } errorHandler: { error in
            DispatchQueue.main.async {
                self.isHandoffInProgress = false
                print("❌ [WatchWorkoutCoordinator] Handoff failed: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    func handleHandoffFromPhone(_ message: [String: Any]) {
        guard let handoffMessage = WorkoutHandoffMessage.fromDictionary(message) else {
            print("❌ [WatchWorkoutCoordinator] Invalid handoff message")
            return
        }
        
        // Check for conflicts
        if let existingWorkout = activeWorkout {
            // Conflict - both devices have active workouts
            handleHandoffConflict(phoneWorkout: handoffMessage, watchWorkout: existingWorkout)
            return
        }
        
        // Accept handoff
        let session = WatchWorkoutSession(
            id: handoffMessage.workoutId,
            workoutType: handoffMessage.workoutType,
            state: handoffMessage.state,
            metrics: handoffMessage.metrics,
            startDate: handoffMessage.startDate,
            deviceSource: .phone
        )
        
        activeWorkout = session
        
        // Confirm handoff acceptance
        connectivityManager.sendMessage([
            "type": "handoffResponse",
            "accepted": true,
            "workoutId": session.id
        ])
    }
    
    private func handleHandoffRequest(_ userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo as? [String: Any] else { return }
        handleHandoffFromPhone(userInfo)
    }
    
    private func handleHandoffConflict(phoneWorkout: WorkoutHandoffMessage, watchWorkout: WatchWorkoutSession) {
        // Default: accept phone workout (phone is usually more accurate for GPS)
        let session = WatchWorkoutSession(
            id: phoneWorkout.workoutId,
            workoutType: phoneWorkout.workoutType,
            state: phoneWorkout.state,
            metrics: phoneWorkout.metrics,
            startDate: phoneWorkout.startDate,
            deviceSource: .phone
        )
        
        activeWorkout = session
        
        connectivityManager.sendMessage([
            "type": "handoffResponse",
            "accepted": true,
            "workoutId": session.id,
            "conflictResolved": true
        ])
    }
}

