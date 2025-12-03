//
//  WatchConnectivityManager.swift
//  Do Watch App
//
//  Enhanced connectivity manager for handoff and communication
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    private var session: WCSession?
    @Published var isReachable = false
    @Published var isActivated = false
    @Published var receivedMessages: [String: Any] = [:]
    
    private override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        guard WCSession.isSupported() else {
            print("⚠️ [WatchConnectivityManager] WatchConnectivity not supported")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    // MARK: - Message Sending
    
    func sendMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil, errorHandler: ((Error) -> Void)? = nil) {
        guard let session = session, session.isReachable else {
            // Fallback to application context
            updateApplicationContext(message, errorHandler: errorHandler)
            return
        }
        
        session.sendMessage(message, replyHandler: replyHandler ?? { _ in }, errorHandler: errorHandler ?? { error in
            print("❌ [WatchConnectivityManager] Error sending message: \(error.localizedDescription)")
        })
    }
    
    func updateApplicationContext(_ context: [String: Any], errorHandler: ((Error) -> Void)? = nil) {
        guard let session = session else { return }
        
        do {
            try session.updateApplicationContext(context)
            print("✅ [WatchConnectivityManager] Updated application context")
        } catch {
            print("❌ [WatchConnectivityManager] Failed to update application context: \(error.localizedDescription)")
            errorHandler?(error)
        }
    }
    
    // MARK: - Workout Handoff
    
    func initiateHandoffToPhone(workoutType: String, metrics: [String: Any], completion: @escaping (Bool) -> Void) {
        let handoffMessage: [String: Any] = [
            "type": "workoutHandoff",
            "direction": "watchToPhone",
            "workoutType": workoutType,
            "metrics": metrics,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessage(handoffMessage) { response in
            let accepted = response["accepted"] as? Bool ?? false
            completion(accepted)
        } errorHandler: { error in
            print("❌ [WatchConnectivityManager] Handoff failed: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    func requestActiveWorkout(completion: @escaping ([String: Any]?) -> Void) {
        sendMessage(["request": "activeWorkout"]) { response in
            if let workoutData = response["workout"] as? [String: Any] {
                completion(workoutData)
            } else {
                completion(nil)
            }
        } errorHandler: { _ in
            completion(nil)
        }
    }
    
    // MARK: - Metrics Sync
    
    func sendMetrics(_ metrics: [String: Any], workoutType: String) {
        let message: [String: Any] = [
            "type": "workoutMetrics",
            "workoutType": workoutType,
            "metrics": metrics,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessage(message)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("❌ [WatchConnectivityManager] Session activation failed: \(error.localizedDescription)")
                self.isActivated = false
            } else {
                print("✅ [WatchConnectivityManager] Session activated with state: \(activationState.rawValue)")
                self.isActivated = true
                self.isReachable = session.isReachable
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("📡 [WatchConnectivityManager] Reachability changed: \(session.isReachable)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            print("📨 [WatchConnectivityManager] Received message: \(message.keys.joined(separator: ", "))")
            self.receivedMessages = message
            
            // Handle different message types
            if let type = message["type"] as? String {
                switch type {
                case "workoutHandoff":
                    self.handleWorkoutHandoff(message)
                case "workoutMetrics":
                    self.handleWorkoutMetrics(message)
                case "workoutUpdate":
                    // Phone is sending workout update with coordination flags
                    self.handleWorkoutUpdate(message)
                case "gymWorkoutState", "gymWorkoutStart", "gymWorkoutPause", "gymWorkoutStop":
                    self.handleGymWorkoutMessage(message)
                case "gymSetCompleted":
                    NotificationCenter.default.post(
                        name: NSNotification.Name("GymSetCompleted"),
                        object: nil,
                        userInfo: message
                    )
                case "authTokens":
                    NotificationCenter.default.post(
                        name: NSNotification.Name("WatchAuthStateChanged"),
                        object: nil,
                        userInfo: message
                    )
                default:
                    break
                }
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            print("📨 [WatchConnectivityManager] Received message with reply handler")
            
            if let request = message["request"] as? String {
                switch request {
                case "activeWorkout":
                    // Check if we have an active workout
                    if let activeWorkout = WatchWorkoutCoordinator.shared.activeWorkout {
                        replyHandler([
                            "hasActiveWorkout": true,
                            "workout": activeWorkout.toDictionary()
                        ])
                    } else {
                        replyHandler(["hasActiveWorkout": false])
                    }
                default:
                    replyHandler(["error": "Unknown request"])
                }
            } else {
                replyHandler([:])
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            print("📦 [WatchConnectivityManager] Received application context: \(applicationContext.keys.joined(separator: ", "))")
            
            if let type = applicationContext["type"] as? String {
                switch type {
                case "workoutHandoff":
                    self.handleWorkoutHandoff(applicationContext)
                case "workoutMetrics":
                    self.handleWorkoutMetrics(applicationContext)
                case "authTokens":
                    NotificationCenter.default.post(
                        name: NSNotification.Name("WatchAuthStateChanged"),
                        object: nil,
                        userInfo: applicationContext
                    )
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Message Handlers
    
    private func handleWorkoutHandoff(_ message: [String: Any]) {
        if let direction = message["direction"] as? String, direction == "phoneToWatch" {
            // Phone wants to handoff to watch
            NotificationCenter.default.post(
                name: NSNotification.Name("WorkoutHandoffRequest"),
                object: nil,
                userInfo: message
            )
        }
    }
    
    private func handleWorkoutMetrics(_ message: [String: Any]) {
        if let metrics = message["metrics"] as? [String: Any] {
            // Merge with watch metrics using best value logic
            let coordinationFlags = [
                "isPrimaryForDistance": message["isPrimaryForDistance"] as? Bool ?? false,
                "isPrimaryForPace": message["isPrimaryForPace"] as? Bool ?? false,
                "isPrimaryForHeartRate": message["isPrimaryForHeartRate"] as? Bool ?? false,
                "isPrimaryForCalories": message["isPrimaryForCalories"] as? Bool ?? false,
                "isPrimaryForCadence": message["isPrimaryForCadence"] as? Bool ?? false
            ]
            
            if let mergedMetrics = MetricsHandoffService.shared.receiveMetricsFromPhone(metrics, coordinationFlags: coordinationFlags) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("WorkoutMetricsUpdate"),
                    object: nil,
                    userInfo: mergedMetrics.toDictionary()
                )
            }
        }
    }
    
    private func handleWorkoutUpdate(_ message: [String: Any]) {
        // Handle workoutUpdate messages from phone (includes coordination flags)
        if let metrics = message["metrics"] as? [String: Any] {
            // Extract coordination flags from message
            let coordinationFlags: [String: Any] = [
                "isPrimaryForDistance": message["isPrimaryForDistance"] as? Bool ?? false,
                "isPrimaryForPace": message["isPrimaryForPace"] as? Bool ?? false,
                "isPrimaryForHeartRate": message["isPrimaryForHeartRate"] as? Bool ?? false,
                "isPrimaryForCalories": message["isPrimaryForCalories"] as? Bool ?? false,
                "isPrimaryForCadence": message["isPrimaryForCadence"] as? Bool ?? false
            ]
            
            // Merge phone metrics with watch metrics using best value logic
            if let mergedMetrics = MetricsHandoffService.shared.receiveMetricsFromPhone(metrics, coordinationFlags: coordinationFlags) {
                // Update watch workout with merged metrics
                if var workout = WatchWorkoutCoordinator.shared.activeWorkout {
                    workout.metrics = mergedMetrics
                    workout.lastUpdateDate = Date()
                    WatchWorkoutCoordinator.shared.activeWorkout = workout
                }
                
                // Notify views of updated metrics
                NotificationCenter.default.post(
                    name: NSNotification.Name("WorkoutMetricsUpdate"),
                    object: nil,
                    userInfo: mergedMetrics.toDictionary()
                )
            }
        }
    }
    
    private func handleGymWorkoutMessage(_ message: [String: Any]) {
        NotificationCenter.default.post(
            name: NSNotification.Name("GymWorkoutStateChanged"),
            object: nil,
            userInfo: message
        )
    }
}

