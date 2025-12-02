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
    
    func startWorkout(type: WorkoutType, isIndoor: Bool = false, isOpenTraining: Bool = false) {
        guard activeWorkout == nil else {
            print("⚠️ [WatchWorkoutCoordinator] Workout already active")
            return
        }
        
        // Test logging
        let scenario = isIndoor ? "Indoor \(type.rawValue.capitalized)" : "Outdoor \(type.rawValue.capitalized)"
        TrackingTestLogger.shared.logTestStart(category: type.rawValue.uppercased(), scenario: scenario)
        
        let session = WatchWorkoutSession(
            workoutType: type,
            state: .starting,
            deviceSource: .watch
        )
        
        DispatchQueue.main.async {
            self.activeWorkout = session
        }
        
        // Test logging
        TrackingTestLogger.shared.logStateChange(category: type.rawValue.uppercased(), oldState: "notStarted", newState: "starting")
        
        // Notify phone
        var message: [String: Any] = [
            "type": "workoutStateChange",
            "workoutType": type.rawValue,
            "state": WorkoutState.starting.rawValue,
            "workoutId": session.id
        ]
        
        // Add indoor/outdoor info for running
        if type == .running {
            message["isIndoor"] = isIndoor
        }
        
        // Add open training info for gym
        if type == .gym {
            message["isOpenTraining"] = isOpenTraining
        }
        
        // Test logging
        TrackingTestLogger.shared.logSyncEvent(category: type.rawValue.uppercased(), direction: "watchToPhone", data: message)
        
        connectivityManager.sendMessage(message)
        
        // Special handling for gym workouts
        if type == .gym {
            connectivityManager.sendMessage([
                "type": "gymWorkoutStart",
                "workoutId": session.id,
                "isOpenTraining": isOpenTraining,
                "timestamp": Date().timeIntervalSince1970
            ])
        }
    }
    
    func pauseWorkout() {
        guard var workout = activeWorkout, workout.state == .running else { return }
        
        // Test logging
        TrackingTestLogger.shared.logStateChange(category: workout.workoutType.rawValue.uppercased(), oldState: "running", newState: "paused")
        
        workout.state = .paused
        workout.lastUpdateDate = Date()
        DispatchQueue.main.async {
            self.activeWorkout = workout
        }
        
        let message: [String: Any] = [
            "type": "workoutStateChange",
            "workoutType": workout.workoutType.rawValue,
            "state": WorkoutState.paused.rawValue,
            "workoutId": workout.id
        ]
        
        // Test logging
        TrackingTestLogger.shared.logSyncEvent(category: workout.workoutType.rawValue.uppercased(), direction: "watchToPhone", data: message)
        
        connectivityManager.sendMessage(message)
    }
    
    func resumeWorkout() {
        guard var workout = activeWorkout, workout.state == .paused else { return }
        
        // Test logging
        TrackingTestLogger.shared.logStateChange(category: workout.workoutType.rawValue.uppercased(), oldState: "paused", newState: "running")
        
        workout.state = .running
        workout.lastUpdateDate = Date()
        DispatchQueue.main.async {
            self.activeWorkout = workout
        }
        
        let message: [String: Any] = [
            "type": "workoutStateChange",
            "workoutType": workout.workoutType.rawValue,
            "state": WorkoutState.running.rawValue,
            "workoutId": workout.id
        ]
        
        // Test logging
        TrackingTestLogger.shared.logSyncEvent(category: workout.workoutType.rawValue.uppercased(), direction: "watchToPhone", data: message)
        
        connectivityManager.sendMessage(message)
    }
    
    func stopWorkout() {
        guard var workout = activeWorkout else { return }
        
        // Test logging
        TrackingTestLogger.shared.logStateChange(category: workout.workoutType.rawValue.uppercased(), oldState: workout.state.rawValue, newState: "stopping")
        
        workout.state = .stopping
        workout.lastUpdateDate = Date()
        DispatchQueue.main.async {
            self.activeWorkout = workout
        }
        
        let message: [String: Any] = [
            "type": "workoutStateChange",
            "workoutType": workout.workoutType.rawValue,
            "state": WorkoutState.stopping.rawValue,
            "workoutId": workout.id
        ]
        
        // Test logging
        TrackingTestLogger.shared.logSyncEvent(category: workout.workoutType.rawValue.uppercased(), direction: "watchToPhone", data: message)
        
        connectivityManager.sendMessage(message)
        
        // Complete the workout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            workout.state = .completed
            workout.lastUpdateDate = Date()
            self.activeWorkout = nil
            
            // Test logging
            TrackingTestLogger.shared.logTestEnd(category: workout.workoutType.rawValue.uppercased())
        }
    }
    
    func updateMetrics(_ metrics: WorkoutMetrics) {
        guard var workout = activeWorkout else { return }
        
        workout.metrics = metrics
        workout.lastUpdateDate = Date()
        DispatchQueue.main.async {
            self.activeWorkout = workout
        }
        
        // Test logging - log metrics periodically (every 5 seconds to avoid spam)
        let currentTime = Date().timeIntervalSince1970
        let lastLogKey = "lastMetricLog_\(workout.id)"
        let lastLogTime = UserDefaults.standard.double(forKey: lastLogKey)
        
        if currentTime - lastLogTime >= 5.0 {
            TrackingTestLogger.shared.logMetricUpdate(device: "WATCH", category: workout.workoutType.rawValue.uppercased(), metric: "distance", value: metrics.distance)
            TrackingTestLogger.shared.logMetricUpdate(device: "WATCH", category: workout.workoutType.rawValue.uppercased(), metric: "heartRate", value: metrics.heartRate)
            TrackingTestLogger.shared.logMetricUpdate(device: "WATCH", category: workout.workoutType.rawValue.uppercased(), metric: "calories", value: metrics.calories)
            UserDefaults.standard.set(currentTime, forKey: lastLogKey)
        }
        
        // Sync metrics to phone
        connectivityManager.sendMetrics(metrics.toDictionary(), workoutType: workout.workoutType.rawValue)
    }
    
    // MARK: - Handoff
    
    func initiateHandoffToPhone(completion: @escaping (Bool) -> Void) {
        guard let workout = activeWorkout else {
            completion(false)
            return
        }
        
        DispatchQueue.main.async {
            self.isHandoffInProgress = true
            self.handoffDirection = .watchToPhone
        }
        
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
        
        DispatchQueue.main.async {
            self.activeWorkout = session
        }
        
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
        
        DispatchQueue.main.async {
            self.activeWorkout = session
        }
        
        connectivityManager.sendMessage([
            "type": "handoffResponse",
            "accepted": true,
            "workoutId": session.id,
            "conflictResolved": true
        ])
    }
}

