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
                case "gymSetsUpdate":
                    // Handle sets update from phone
                    NotificationCenter.default.post(
                        name: NSNotification.Name("GymSetsUpdate"),
                        object: nil,
                        userInfo: message
                    )
                case "gymMetrics":
                    // Handle real-time metrics update from phone
                    NotificationCenter.default.post(
                        name: NSNotification.Name("GymMetricsUpdate"),
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
                case "trackingStatus":
                    // Handle tracking status from phone - check for active workout
                    self.handleTrackingStatus(applicationContext)
                case "workoutUpdate":
                    // Handle workout update messages (includes coordination flags)
                    self.handleWorkoutUpdate(applicationContext)
                case "authTokens":
                    NotificationCenter.default.post(
                        name: NSNotification.Name("WatchAuthStateChanged"),
                        object: nil,
                        userInfo: applicationContext
                    )
                default:
                    // Check if this is an active workout even without a recognized type
                    if let hasActiveWorkout = applicationContext["hasActiveWorkout"] as? Bool,
                       hasActiveWorkout,
                       let workoutActive = applicationContext["workoutActive"] as? Bool,
                       workoutActive {
                        print("⌚️ [WatchConnectivityManager] Detected active workout in application context")
                        self.handleTrackingStatus(applicationContext)
                    }
                    break
                }
            } else {
                // No type specified - check for active workout indicators
                if let hasActiveWorkout = applicationContext["hasActiveWorkout"] as? Bool,
                   hasActiveWorkout,
                   let workoutActive = applicationContext["workoutActive"] as? Bool,
                   workoutActive {
                    print("⌚️ [WatchConnectivityManager] Detected active workout in application context (no type)")
                    self.handleTrackingStatus(applicationContext)
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
    
    private func handleTrackingStatus(_ message: [String: Any]) {
        // Handle tracking status from phone - check for active workout
        let hasActiveWorkout = (message["hasActiveWorkout"] as? Bool) ?? (message["workoutActive"] as? Bool) ?? false
        
        if hasActiveWorkout {
            print("⌚️ [WatchConnectivityManager] Active phone workout detected in tracking status")
            
            // Extract workout data
            var workoutData: [String: Any] = [:]
            workoutData["workoutActive"] = true
            workoutData["hasActiveWorkout"] = true
            
            // Extract workout type
            if let workoutType = message["workoutType"] as? String {
                workoutData["workoutType"] = workoutType
            } else if let runType = message["runType"] as? String {
                // Convert runType to workoutType
                workoutData["workoutType"] = "running"
                workoutData["runType"] = runType
            }
            
            // Extract state
            if let state = message["state"] as? String {
                workoutData["state"] = state
            } else if let runState = message["runState"] as? String {
                // Convert runState to state
                let state = (runState == "running") ? "inProgress" : (runState == "paused" ? "paused" : "notStarted")
                workoutData["state"] = state
                workoutData["runState"] = runState
            }
            
            // Extract metrics
            if let metrics = message["metrics"] as? [String: Any] {
                workoutData["metrics"] = metrics
            } else {
                // Build metrics from individual fields
                var metrics: [String: Any] = [:]
                if let distance = message["distance"] as? Double {
                    metrics["distance"] = distance
                }
                if let elapsedTime = message["elapsedTime"] as? TimeInterval {
                    metrics["elapsedTime"] = elapsedTime
                }
                if let pace = message["pace"] as? Double {
                    metrics["pace"] = pace
                }
                if let heartRate = message["heartRate"] as? Double {
                    metrics["heartRate"] = heartRate
                }
                if let calories = message["calories"] as? Double {
                    metrics["calories"] = calories
                }
                if let cadence = message["cadence"] as? Double {
                    metrics["cadence"] = cadence
                }
                if !metrics.isEmpty {
                    workoutData["metrics"] = metrics
                }
            }
            
            // Extract workout ID
            if let id = message["id"] as? String {
                workoutData["id"] = id
            } else if let workoutId = message["workoutId"] as? String {
                workoutData["id"] = workoutId
            }
            
            // Extract other useful info
            if let isIndoor = message["isIndoor"] as? Bool {
                workoutData["isIndoor"] = isIndoor
            } else if let isIndoorMode = message["isIndoorMode"] as? Bool {
                workoutData["isIndoor"] = isIndoorMode
            }
            
            // Post notification for WorkoutListView to handle
            NotificationCenter.default.post(
                name: NSNotification.Name("PhoneWorkoutUpdate"),
                object: nil,
                userInfo: workoutData
            )
            print("⌚️ [WatchConnectivityManager] Posted PhoneWorkoutUpdate notification with workout data")
        } else {
            // No active workout - clear it
            NotificationCenter.default.post(
                name: NSNotification.Name("PhoneWorkoutUpdate"),
                object: nil,
                userInfo: ["workoutActive": false, "hasActiveWorkout": false]
            )
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
        
        // Also check if this is an active workout update and notify
        let hasActiveWorkout = (message["hasActiveWorkout"] as? Bool) ?? (message["workoutActive"] as? Bool) ?? false
        if hasActiveWorkout {
            handleTrackingStatus(message)
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

