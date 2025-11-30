//
//  WorkoutStateSync.swift
//  Do Watch App
//
//  State synchronization service
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import Combine

class WorkoutStateSync: ObservableObject {
    static let shared = WorkoutStateSync()
    
    @Published var lastSyncTime: Date?
    @Published var syncStatus: SyncStatus = .idle
    
    private let connectivityManager = WatchConnectivityManager.shared
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case failed
    }
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutStateChanged"))
            .sink { [weak self] _ in
                self?.syncState()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - State Synchronization
    
    func syncState() {
        guard let workout = WatchWorkoutCoordinator.shared.activeWorkout else {
            return
        }
        
        syncStatus = .syncing
        
        let stateMessage: [String: Any] = [
            "type": "workoutStateSync",
            "workoutId": workout.id,
            "workoutType": workout.workoutType.rawValue,
            "state": workout.state.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        connectivityManager.sendMessage(stateMessage) { [weak self] response in
            DispatchQueue.main.async {
                self?.syncStatus = .success
                self?.lastSyncTime = Date()
            }
        } errorHandler: { [weak self] error in
            DispatchQueue.main.async {
                self?.syncStatus = .failed
                print("❌ [WorkoutStateSync] Sync failed: \(error.localizedDescription)")
            }
        }
    }
    
    func startPeriodicSync(interval: TimeInterval = 5.0) {
        stopPeriodicSync()
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.syncState()
        }
    }
    
    func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - State Recovery
    
    func recoverStateAfterConnectionLoss() {
        // Request current state from phone
        connectivityManager.requestActiveWorkout { workoutData in
            if let workoutData = workoutData,
               let session = WatchWorkoutSession.fromDictionary(workoutData) {
                DispatchQueue.main.async {
                    WatchWorkoutCoordinator.shared.activeWorkout = session
                    print("✅ [WorkoutStateSync] Recovered workout state from phone")
                }
            }
        }
    }
    
    // MARK: - Conflict Resolution
    
    /// Resolves conflicts between phone and watch workout states
    /// - Parameters:
    ///   - phoneState: The workout state from the iPhone
    ///   - watchState: The workout state from the Apple Watch
    /// - Returns: The resolved workout state based on conflict resolution strategy
    func resolveStateConflict(phoneState: WorkoutState, watchState: WorkoutState) -> WorkoutState {
        // If states match, no conflict
        if phoneState == watchState {
            return phoneState
        }
        
        // Terminal states take precedence (stopped, completed)
        // If either device says the workout is done, it's done
        if phoneState == .stopped || phoneState == .completed {
            return phoneState
        }
        if watchState == .stopped || watchState == .completed {
            return watchState
        }
        
        // Stopping state takes precedence (workout is ending)
        if phoneState == .stopping {
            return phoneState
        }
        if watchState == .stopping {
            return watchState
        }
        
        // Active states (running, paused) take precedence over idle/starting
        // If one device says it's running and the other says idle, trust the active one
        if phoneState.isActive && !watchState.isActive {
            return phoneState
        }
        if watchState.isActive && !phoneState.isActive {
            return watchState
        }
        
        // If both are active but different (running vs paused)
        // Prefer "running" over "paused" (more recent activity)
        if phoneState == .running && watchState == .paused {
            return phoneState // Running is more current
        }
        if watchState == .running && phoneState == .paused {
            return watchState // Running is more current
        }
        
        // Starting state: prefer the one that's not starting (more advanced state)
        if phoneState == .starting && watchState != .starting {
            return watchState
        }
        if watchState == .starting && phoneState != .starting {
            return phoneState
        }
        
        // Default: phone state takes precedence for GPS-based workouts
        // Phone typically has better GPS accuracy for outdoor activities
        // and is the primary device for most users
        return phoneState
    }
}

