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
        
        print("🔧 [WatchConnectivityManager] Setting up session...")
        session = WCSession.default
        
        // CRITICAL: Set delegate BEFORE checking state or activating
        print("🔧 [WatchConnectivityManager] Setting delegate...")
        session?.delegate = self
        print("🔧 [WatchConnectivityManager] Delegate set: \(session?.delegate != nil)")
        print("🔧 [WatchConnectivityManager] Delegate is self: \(session?.delegate === self)")
        
        let currentState = session?.activationState ?? .notActivated
        print("🔧 [WatchConnectivityManager] Current activation state: \(currentState.rawValue)")
        
        #if targetEnvironment(simulator)
        print("📱 [WatchConnectivityManager] Running on simulator")
        print("📱 [WatchConnectivityManager] isPaired: N/A on watchOS")
        print("📱 [WatchConnectivityManager] isWatchAppInstalled: N/A on watchOS")
        #else
        print("⌚️ [WatchConnectivityManager] Running on real device")
        #endif
        
        if currentState == .notActivated {
            print("🔄 [WatchConnectivityManager] Calling session.activate()...")
            // Activate on main thread to ensure delegate callbacks work
            DispatchQueue.main.async {
                self.session?.activate()
                print("🔄 [WatchConnectivityManager] session.activate() called on main thread, waiting for callback...")
            }
            
            // Set up a timer to check activation state periodically as a fallback
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.checkActivationState()
            }
        } else {
            print("ℹ️ [WatchConnectivityManager] Session already in state: \(currentState.rawValue)")
            if currentState == .activated {
                DispatchQueue.main.async {
                    self.isActivated = true
                    self.isReachable = self.session?.isReachable ?? false
                    print("✅ [WatchConnectivityManager] Session already activated, setting isActivated = true")
                }
            }
        }
    }
    
    private func checkActivationState() {
        guard let session = session else { return }
        let state = session.activationState
        print("🔍 [WatchConnectivityManager] Checking activation state: \(state.rawValue)")
        
        if state == .activated && !isActivated {
            print("✅ [WatchConnectivityManager] Session is activated but isActivated was false, updating...")
            DispatchQueue.main.async {
                self.isActivated = true
                self.isReachable = session.isReachable
                print("✅ [WatchConnectivityManager] Updated isActivated = true, isReachable = \(self.isReachable)")
            }
        } else if state != .activated {
            print("⏳ [WatchConnectivityManager] Still not activated, state: \(state.rawValue)")
            // Check again in 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.checkActivationState()
            }
        }
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
    
    /// Request active workout from phone
    func requestActiveWorkoutFromPhone(completion: @escaping ([String: Any]?) -> Void) {
        let message: [String: Any] = [
            "type": "requestActivePhoneWorkout",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessage(message) { response in
            if let workoutActive = response["workoutActive"] as? Bool, workoutActive {
                // Phone has an active workout
                var workoutData: [String: Any] = [:]
                workoutData["workoutActive"] = true
                workoutData["workoutType"] = response["workoutType"] as? String
                workoutData["state"] = response["state"] ?? response["runState"] ?? response["walkState"]
                workoutData["elapsedTime"] = response["elapsedTime"]
                workoutData["metrics"] = response["metrics"] as? [String: Any]
                workoutData["isWatchTracking"] = response["isWatchTracking"] as? Bool ?? false
                completion(workoutData)
            } else {
                completion(nil)
            }
        } errorHandler: { error in
            print("❌ [WatchConnectivityManager] Error requesting phone workout: \(error.localizedDescription)")
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
        print("🎯 [WatchConnectivityManager] activationDidCompleteWith called!")
        print("🎯 [WatchConnectivityManager] Activation state: \(activationState.rawValue)")
        print("🎯 [WatchConnectivityManager] Error: \(error?.localizedDescription ?? "none")")
        print("🎯 [WatchConnectivityManager] Session isReachable: \(session.isReachable)")
        
        DispatchQueue.main.async {
            if let error = error {
                print("❌ [WatchConnectivityManager] Session activation failed: \(error.localizedDescription)")
                self.isActivated = false
            } else {
                print("✅ [WatchConnectivityManager] Session activated successfully!")
                print("✅ [WatchConnectivityManager] Setting isActivated = true")
                self.isActivated = true
                self.isReachable = session.isReachable
                print("✅ [WatchConnectivityManager] isActivated: \(self.isActivated), isReachable: \(self.isReachable)")
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
                case "unitPreferences":
                    if let useMetric = message["useMetric"] as? Bool {
                        WatchSettingsManager.shared.updateUnitPreferences(useMetric: useMetric)
                    }
                default:
                    break
                }
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            print("📨 [WatchConnectivityManager] Received message with reply handler")
            
            // Handle specific workout type requests (e.g., "requestActiveRunningWorkout")
            if let type = message["type"] as? String {
                if type.hasPrefix("requestActive") && type.hasSuffix("Workout") {
                    // Check if we have an active workout
                    if let activeWorkout = WatchWorkoutCoordinator.shared.activeWorkout {
                        var response = activeWorkout.toDictionary()
                        response["hasActiveWorkout"] = true
                        response["status"] = "received"
                        replyHandler(response)
                    } else {
                        replyHandler([
                            "hasActiveWorkout": false,
                            "status": "received",
                            "type": type
                        ])
                    }
                    return
                }
            }
            
            // Handle generic requests
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
                    // Forward to WatchAuthService (it will handle token storage and notification)
                    WatchAuthService.shared.handleApplicationContext(applicationContext)
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
            NotificationCenter.default.post(
                name: NSNotification.Name("WorkoutMetricsUpdate"),
                object: nil,
                userInfo: metrics
            )
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

