//
//  WorkoutStateSync.swift
//  Do
//
//  State synchronization service (iOS side)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import WatchConnectivity
import Combine

class WorkoutStateSync: NSObject, ObservableObject {
    static let shared = WorkoutStateSync()
    
    @Published var lastSyncTime: Date?
    @Published var syncStatus: SyncStatus = .idle
    
    private var session: WCSession?
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case failed
    }
    
    private override init() {
        super.init()
        setupWatchConnectivity()
        setupObservers()
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    private func setupObservers() {
        NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutStateChanged"))
            .sink { [weak self] _ in
                self?.syncState()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - State Synchronization
    
    func syncState(workoutId: String, workoutType: WorkoutType, state: WorkoutState) {
        guard let session = session, session.isWatchAppInstalled else { return }
        
        syncStatus = .syncing
        
        let stateMessage: [String: Any] = [
            "type": "workoutStateSync",
            "workoutId": workoutId,
            "workoutType": workoutType.rawValue,
            "state": state.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if session.isReachable {
            session.sendMessage(stateMessage, replyHandler: { [weak self] response in
                DispatchQueue.main.async {
                    self?.syncStatus = .success
                    self?.lastSyncTime = Date()
                }
            }, errorHandler: { [weak self] error in
                DispatchQueue.main.async {
                    self?.syncStatus = .failed
                    print("❌ [WorkoutStateSync] Sync failed: \(error.localizedDescription)")
                }
            })
        } else {
            // Use application context
            do {
                try session.updateApplicationContext(stateMessage)
                syncStatus = .success
                lastSyncTime = Date()
            } catch {
                syncStatus = .failed
                print("❌ [WorkoutStateSync] Failed to update context: \(error.localizedDescription)")
            }
        }
    }
    
    private func syncState() {
        // Get current workout state from active tracking engine
        // This would be called by the tracking engine
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
        // Request current state from watch
        guard let session = session, session.isReachable else { return }
        
        session.sendMessage(["request": "activeWorkout"], replyHandler: { response in
            if let hasActiveWorkout = response["hasActiveWorkout"] as? Bool, hasActiveWorkout,
               let workoutData = response["workout"] as? [String: Any] {
                // Handle recovered workout state
                NotificationCenter.default.post(
                    name: NSNotification.Name("WorkoutStateRecovered"),
                    object: nil,
                    userInfo: workoutData
                )
            }
        }, errorHandler: { error in
            print("❌ [WorkoutStateSync] Error recovering state: \(error.localizedDescription)")
        })
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

// MARK: - WCSessionDelegate

extension WorkoutStateSync: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ [WorkoutStateSync] Session activation failed: \(error.localizedDescription)")
        } else {
            print("✅ [WorkoutStateSync] Session activated")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ [WorkoutStateSync] Session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let type = message["type"] as? String, type == "workoutStateSync" {
            // Handle state sync from watch
            if let stateStr = message["state"] as? String,
               let state = WorkoutState(rawValue: stateStr) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("WatchWorkoutStateUpdate"),
                    object: nil,
                    userInfo: ["state": state]
                )
            }
        }
    }
}

