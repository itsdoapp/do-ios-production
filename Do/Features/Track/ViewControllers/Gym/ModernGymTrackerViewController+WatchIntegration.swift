//
//  ModernGymTrackerViewController+WatchIntegration.swift
//  Do
//
//  Watch integration for gym tracking
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import WatchConnectivity
import Combine

extension ModernGymTrackerViewController: WCSessionDelegate {
    
    // MARK: - Watch Integration Setup
    
    func setupWatchIntegration() {
        guard WCSession.isSupported() else { return }
        
        let session = WCSession.default
        session.delegate = self
        session.activate()
        
        // Subscribe to gym tracker updates
        gymTracker.$isTracking
            .sink { [weak self] isTracking in
                if isTracking {
                    self?.syncWorkoutToWatch()
                }
            }
            .store(in: &cancellables)
        
        gymTracker.$completedSets
            .sink { [weak self] _ in
                self?.syncSetsToWatch()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Watch Sync Methods
    
    func syncWorkoutToWatch() {
        guard let session = gymTracker.currentSession else { return }
        
        let workoutData: [String: Any] = [
            "type": "gymWorkoutState",
            "sessionId": session.id,
            "sessionName": session.name ?? "",
            "isTracking": gymTracker.isTracking,
            "elapsedTime": gymTracker.elapsedTime,
            "totalCalories": gymTracker.totalCalories,
            "totalVolume": gymTracker.totalVolume,
            "totalReps": gymTracker.totalReps,
            "heartRate": gymTracker.heartRate,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        guard WCSession.isSupported() else { return }
        let wcSession = WCSession.default
        
        if wcSession.isReachable {
            wcSession.sendMessage(workoutData, replyHandler: { reply in
                // Handle reply if needed
                print("✅ [ModernGymTracker] Watch acknowledged workout state update")
            }, errorHandler: { error in
                print("❌ [ModernGymTracker] Error syncing to watch: \(error.localizedDescription)")
                // Fallback to application context on error
                do {
                    try wcSession.updateApplicationContext(workoutData)
                } catch {
                    print("❌ [ModernGymTracker] Error updating context: \(error.localizedDescription)")
                }
            })
        } else {
            do {
                try wcSession.updateApplicationContext(workoutData)
            } catch {
                print("❌ [ModernGymTracker] Error updating context: \(error.localizedDescription)")
            }
        }
    }
    
    func syncSetsToWatch() {
        let setsData: [String: Any] = [
            "type": "gymSetsUpdate",
            "completedSets": gymTracker.completedSets.map { $0.toDictionary() },
            "totalVolume": gymTracker.totalVolume,
            "totalReps": gymTracker.totalReps,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        guard WCSession.isSupported() else { return }
        let wcSession = WCSession.default
        
        if wcSession.isReachable {
            wcSession.sendMessage(setsData, replyHandler: { reply in
                // Handle reply if needed
                print("✅ [ModernGymTracker] Watch acknowledged sets update")
            }, errorHandler: { error in
                print("❌ [ModernGymTracker] Error sending sets to watch: \(error.localizedDescription)")
                // Fallback to application context on error
                do {
                    try wcSession.updateApplicationContext(setsData)
                } catch {
                    print("❌ [ModernGymTracker] Error syncing sets via context: \(error.localizedDescription)")
                }
            })
        } else {
            do {
                try wcSession.updateApplicationContext(setsData)
            } catch {
                print("❌ [ModernGymTracker] Error syncing sets: \(error.localizedDescription)")
            }
        }
    }
    
    func initiateHandoffToWatch(completion: @escaping (Bool) -> Void) {
        gymTracker.initiateHandoffToWatch(completion: completion)
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ [ModernGymTracker] Watch session activation failed: \(error.localizedDescription)")
        } else {
            print("✅ [ModernGymTracker] Watch session activated")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ [ModernGymTracker] Watch session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let type = message["type"] as? String {
            switch type {
            case "gymWorkoutHandoff":
                gymTracker.handleHandoffFromWatch(message)
            case "gymSetCompleted":
                handleSetFromWatch(message)
            case "gymWorkoutStart", "gymWorkoutPause", "gymWorkoutStop":
                handleWorkoutControlFromWatch(message)
            default:
                break
            }
        }
    }
    
    private func handleSetFromWatch(_ message: [String: Any]) {
        if let reps = message["reps"] as? Int,
           let weight = message["weight"] as? Double {
            
            let movementId = message["movementId"] as? String
            let duration = message["duration"] as? TimeInterval
            
            // Find the movement in current session
            var foundMovement: movement?
            if let movementId = movementId, movementId != "openTraining" {
                foundMovement = gymTracker.currentSession?.movementsInSession?.first(where: { $0.id == movementId })
            } else {
                // Open training - use current movement or create a generic one
                foundMovement = gymTracker.currentMovement ?? {
                    var openMovement = movement()
                    openMovement.id = "openTraining"
                    openMovement.movement1Name = "Open Training"
                    return openMovement
                }()
            }
            
            guard let movement = foundMovement else { return }
            
            var set = set()
            set.id = UUID().uuidString
            set.reps = reps
            set.weight = weight
            set.completed = true
            if let duration = duration {
                set.duration = Int(duration)
            }
            
            gymTracker.completeSet(movement: movement, set: set, weight: weight, reps: reps, duration: duration)
            
            // Update current movement if needed
            if gymTracker.currentMovement?.id != movement.id {
                gymTracker.updateCurrentMovement(movement)
            }
        }
    }
    
    private func handleWorkoutControlFromWatch(_ message: [String: Any]) {
        if let type = message["type"] as? String {
            switch type {
            case "gymWorkoutStart":
                // Watch started workout - join it
                if let sessionName = message["sessionName"] as? String {
                    var session = workoutSession()
                    session.name = sessionName
                    gymTracker.startWorkout(session: session)
                }
            case "gymWorkoutPause":
                gymTracker.pauseWorkout()
            case "gymWorkoutStop":
                gymTracker.stopWorkout()
            default:
                break
            }
        }
    }
}

