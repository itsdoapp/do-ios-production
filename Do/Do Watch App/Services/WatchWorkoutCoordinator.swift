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
        
        let session = WatchWorkoutSession(
            workoutType: type,
            state: .starting,
            deviceSource: .watch
        )
        
        DispatchQueue.main.async {
            self.activeWorkout = session
        }
        
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
        
        workout.state = .paused
        workout.lastUpdateDate = Date()
        DispatchQueue.main.async {
            self.activeWorkout = workout
        }
        
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
        DispatchQueue.main.async {
            self.activeWorkout = workout
        }
        
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
        DispatchQueue.main.async {
            self.activeWorkout = workout
        }
        
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
        DispatchQueue.main.async {
            self.activeWorkout = workout
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

