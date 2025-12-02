//
//  GymTrackingEngine.swift
//  Do
//
//  Gym workout tracking engine with watch support
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import HealthKit
import Combine
import WatchConnectivity

// Note: workoutSession, movement, and set are defined in Do/Common/Models/WorkoutModels.swift
// Note: GymWorkoutMetrics is defined in Do/Do Watch App/Models/GymWorkoutMetrics.swift
// These should be accessible if the files are in the same target

class GymTrackingEngine: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = GymTrackingEngine()
    
    // MARK: - Published Properties
    
    @Published var isTracking = false
    @Published var currentSession: workoutSession?
    @Published var currentMovement: movement?
    @Published var currentSetIndex: Int = 0
    @Published var completedSets: [set] = []
    @Published var workoutStartTime: Date?
    @Published var elapsedTime: TimeInterval = 0
    @Published var totalCalories: Double = 0
    @Published var heartRate: Double = 0
    @Published var totalVolume: Double = 0 // Total weight lifted
    @Published var totalReps: Int = 0
    
    // MARK: - Private Properties
    
    private var timer: Timer?
    private var session: WCSession?
    private var cancellables = Set<AnyCancellable>()
    private var lastWatchSyncTime: TimeInterval = 0
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    // MARK: - Workout Management
    
    func startWorkout(session: workoutSession) {
        guard !isTracking else {
            print("⚠️ [GymTrackingEngine] Already tracking a workout")
            return
        }
        
        // Test logging
        TrackingTestLogger.shared.logTestStart(category: "GYM", scenario: "Phone Only")
        
        self.currentSession = session
        self.workoutStartTime = Date()
        self.isTracking = true
        self.elapsedTime = 0
        self.totalCalories = 0
        self.totalVolume = 0
        self.totalReps = 0
        self.completedSets = []
        
        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
        }
        
        // Test logging - coordination
        TrackingTestLogger.shared.logCoordination(category: "GYM", metric: "heartRate", primaryDevice: "watch", reason: "Watch has better HR sensors")
        TrackingTestLogger.shared.logCoordination(category: "GYM", metric: "calories", primaryDevice: "watch", reason: "Watch better for calorie estimation")
        
        // Sync to watch
        syncWorkoutStateToWatch()
        
        // Start live sync
        startLiveMetricsSync()
        
        // Start smart handoff monitoring
        SmartHandoffCoordinator.shared.startMonitoring(workoutType: .gym)
        
        // Test logging
        TrackingTestLogger.shared.logStateChange(category: "GYM", oldState: "notStarted", newState: "tracking")
        
        print("🏋️ [GymTrackingEngine] Started workout: \(session.name ?? "Unknown")")
    }
    
    func stopWorkout() {
        guard isTracking else { return }
        
        timer?.invalidate()
        timer = nil
        
        isTracking = false
        
        // Sync final state to watch
        syncWorkoutStateToWatch()
        
        // Stop live sync
        stopLiveMetricsSync()
        
        // Stop smart handoff monitoring
        SmartHandoffCoordinator.shared.stopMonitoring()
        
        // Test logging
        TrackingTestLogger.shared.logStateChange(category: "GYM", oldState: "tracking", newState: "stopped")
        TrackingTestLogger.shared.logTestEnd(category: "GYM")
        
        print("🏋️ [GymTrackingEngine] Stopped workout")
    }
    
    func pauseWorkout() {
        timer?.invalidate()
        timer = nil
        syncWorkoutStateToWatch()
    }
    
    func resumeWorkout() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
        }
        syncWorkoutStateToWatch()
    }
    
    // MARK: - Set Management
    
    func completeSet(movement: movement, set: set, weight: Double?, reps: Int?, duration: TimeInterval?) {
        var completedSet = set
        completedSet.completed = true
        completedSet.weight = weight
        completedSet.reps = reps
        if let duration = duration {
            completedSet.duration = Int(duration)
        }
        
        completedSets.append(completedSet)
        
        // Update totals
        if let weight = weight, let reps = reps {
            totalVolume += weight * Double(reps)
            totalReps += reps
        }
        
        // Test logging
        TrackingTestLogger.shared.logMetricUpdate(device: "PHONE", category: "GYM", metric: "totalVolume", value: totalVolume)
        TrackingTestLogger.shared.logMetricUpdate(device: "PHONE", category: "GYM", metric: "totalReps", value: totalReps)
        
        // Sync to watch
        syncSetCompletionToWatch(movement: movement, set: completedSet)
        
        print("🏋️ [GymTrackingEngine] Completed set: \(reps ?? 0) reps @ \(weight ?? 0)lbs")
    }
    
    func updateCurrentMovement(_ movement: movement) {
        currentMovement = movement
        currentSetIndex = 0
        syncCurrentMovementToWatch(movement)
    }
    
    // MARK: - Timer Updates
    
    private func updateElapsedTime() {
        guard let startTime = workoutStartTime else { return }
        elapsedTime = Date().timeIntervalSince(startTime)
    }
    
    // MARK: - Watch Connectivity
    
    private func syncWorkoutStateToWatch() {
        guard let session = session,
              session.isWatchAppInstalled,
              session.activationState == .activated else {
            return
        }
        
        let state: [String: Any] = [
            "type": "gymWorkoutState",
            "isTracking": isTracking,
            "sessionId": currentSession?.id ?? "",
            "sessionName": currentSession?.name ?? "",
            "elapsedTime": elapsedTime,
            "totalCalories": totalCalories,
            "totalVolume": totalVolume,
            "totalReps": totalReps,
            "heartRate": heartRate,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if session.isReachable {
            session.sendMessage(state, replyHandler: nil) { error in
                print("❌ [GymTrackingEngine] Error syncing state: \(error.localizedDescription)")
            }
        } else {
            do {
                try session.updateApplicationContext(state)
            } catch {
                print("❌ [GymTrackingEngine] Error updating context: \(error.localizedDescription)")
            }
        }
    }
    
    private func syncSetCompletionToWatch(movement: movement, set: set) {
        guard let session = session, session.isWatchAppInstalled else { return }
        
        let setData: [String: Any] = [
            "type": "gymSetCompleted",
            "movementId": movement.id,
            "movementName": movement.movement1Name ?? "",
            "setId": set.id,
            "reps": set.reps ?? 0,
            "weight": set.weight ?? 0,
            "duration": set.duration ?? 0,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if session.isReachable {
            session.sendMessage(setData, replyHandler: nil) { error in
                print("❌ [GymTrackingEngine] Error syncing set: \(error.localizedDescription)")
            }
        } else {
            do {
                try session.updateApplicationContext(setData)
            } catch {
                print("❌ [GymTrackingEngine] Error syncing set: \(error.localizedDescription)")
            }
        }
    }
    
    private func syncCurrentMovementToWatch(_ movement: movement) {
        guard let session = session, session.isWatchAppInstalled else { return }
        
        let movementData: [String: Any] = [
            "type": "gymCurrentMovement",
            "movementId": movement.id,
            "movementName": movement.movement1Name ?? "",
            "isTimed": movement.isTimed,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if session.isReachable {
            session.sendMessage(movementData, replyHandler: nil) { error in
                print("❌ [GymTrackingEngine] Error syncing movement: \(error.localizedDescription)")
            }
        } else {
            do {
                try session.updateApplicationContext(movementData)
            } catch {
                print("❌ [GymTrackingEngine] Error syncing movement: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Live Metrics Sync
    
    private func startLiveMetricsSync() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.syncMetricsToWatch()
        }
    }
    
    private func stopLiveMetricsSync() {
        // Timer will be invalidated when workout stops
    }
    
    private func syncMetricsToWatch() {
        guard let session = session,
              session.isWatchAppInstalled,
              isTracking else {
            return
        }
        
        let currentTime = Date().timeIntervalSince1970
        if currentTime - lastWatchSyncTime < 2.0 { return }
        lastWatchSyncTime = currentTime
        
        let metrics: [String: Any] = [
            "type": "gymMetrics",
            "elapsedTime": elapsedTime,
            "totalCalories": totalCalories,
            "totalVolume": totalVolume,
            "totalReps": totalReps,
            "heartRate": heartRate,
            "timestamp": currentTime
        ]
        
        if session.isReachable {
            session.sendMessage(metrics, replyHandler: nil) { error in
                print("❌ [GymTrackingEngine] Error syncing metrics: \(error.localizedDescription)")
            }
        } else {
            do {
                try session.updateApplicationContext(metrics)
            } catch {
                print("❌ [GymTrackingEngine] Error syncing metrics: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Handoff Data Provider
    
    func getHandoffData() -> [String: Any]? {
        guard isTracking, let session = currentSession else { return nil }
        
        let metrics = GymWorkoutMetrics(
            elapsedTime: elapsedTime,
            totalCalories: totalCalories,
            totalVolume: totalVolume,
            totalReps: totalReps,
            totalSets: completedSets.count,
            heartRate: heartRate,
            movementsCompleted: 0,
            currentMovement: currentMovement?.movement1Name,
            currentSet: currentSetIndex
        )
        
        return [
            "type": "gymWorkoutHandoff",
            "direction": "phoneToWatch",
            "sessionId": session.id ?? "",
            "sessionName": session.name ?? "",
            "elapsedTime": elapsedTime,
            "totalCalories": totalCalories,
            "totalVolume": totalVolume,
            "totalReps": totalReps,
            "completedSets": completedSets.map { $0.toDictionary() },
            "startTime": workoutStartTime?.timeIntervalSince1970 ?? 0,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
    
    // MARK: - Handoff Support
    
    func initiateHandoffToWatch(completion: @escaping (Bool) -> Void) {
        guard isTracking, let session = session, session.isWatchAppInstalled else {
            completion(false)
            return
        }
        
        let handoffData: [String: Any] = [
            "type": "gymWorkoutHandoff",
            "direction": "phoneToWatch",
            "sessionId": currentSession?.id ?? "",
            "sessionName": currentSession?.name ?? "",
            "elapsedTime": elapsedTime,
            "totalCalories": totalCalories,
            "totalVolume": totalVolume,
            "totalReps": totalReps,
            "completedSets": completedSets.map { $0.toDictionary() },
            "startTime": workoutStartTime?.timeIntervalSince1970 ?? 0,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if session.isReachable {
            session.sendMessage(handoffData, replyHandler: { response in
                let accepted = response["accepted"] as? Bool ?? false
                if accepted {
                    self.stopWorkout()
                }
                completion(accepted)
            }, errorHandler: { error in
                print("❌ [GymTrackingEngine] Handoff failed: \(error.localizedDescription)")
                completion(false)
            })
        } else {
            do {
                try session.updateApplicationContext(handoffData)
                completion(true)
            } catch {
                completion(false)
            }
        }
    }
    
    func handleHandoffFromWatch(_ message: [String: Any]) {
        guard let sessionId = message["sessionId"] as? String else { return }
        
        // Restore workout state from watch
        if let elapsedTime = message["elapsedTime"] as? TimeInterval {
            self.elapsedTime = elapsedTime
        }
        if let totalCalories = message["totalCalories"] as? Double {
            self.totalCalories = totalCalories
        }
        if let totalVolume = message["totalVolume"] as? Double {
            self.totalVolume = totalVolume
        }
        if let totalReps = message["totalReps"] as? Int {
            self.totalReps = totalReps
        }
        if let startTimeInterval = message["startTime"] as? TimeInterval {
            self.workoutStartTime = Date(timeIntervalSince1970: startTimeInterval)
        }
        if let completedSetsData = message["completedSets"] as? [[String: Any]] {
            self.completedSets = completedSetsData.compactMap { set.fromDictionary($0) }
        }
        
        // Resume tracking
        isTracking = true
        resumeWorkout()
        
        print("🏋️ [GymTrackingEngine] Handoff from watch accepted")
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ [GymTrackingEngine] Session activation failed: \(error.localizedDescription)")
        } else {
            print("✅ [GymTrackingEngine] Session activated")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ [GymTrackingEngine] Session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let type = message["type"] as? String {
            switch type {
            case "gymWorkoutHandoff":
                handleHandoffFromWatch(message)
            case "gymSetCompleted":
                handleSetFromWatch(message)
            case "gymMetrics":
                handleMetricsFromWatch(message)
            default:
                break
            }
        }
    }
    
    private func handleSetFromWatch(_ message: [String: Any]) {
        // Handle set completion from watch
        if let movementId = message["movementId"] as? String,
           let setId = message["setId"] as? String,
           let reps = message["reps"] as? Int,
           let weight = message["weight"] as? Double {
            
            var set = set()
            set.id = setId
            set.reps = reps
            set.weight = weight
            set.completed = true
            
            completedSets.append(set)
            
            totalVolume += weight * Double(reps)
            totalReps += reps
            
            print("🏋️ [GymTrackingEngine] Received set from watch: \(reps) reps @ \(weight)lbs")
        }
    }
    
    private func handleMetricsFromWatch(_ message: [String: Any]) {
        if let heartRate = message["heartRate"] as? Double {
            self.heartRate = heartRate
        }
        if let calories = message["calories"] as? Double {
            self.totalCalories = max(self.totalCalories, calories)
        }
    }
}

// MARK: - Set Dictionary Extension

extension set {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "completed": completed
        ]
        
        if let reps = reps {
            dict["reps"] = reps
        }
        if let weight = weight {
            dict["weight"] = weight
        }
        if let duration = duration {
            dict["duration"] = duration
        }
        if let restPeriod = restPeriod {
            dict["restPeriod"] = restPeriod
        }
        if let notes = notes {
            dict["notes"] = notes
        }
        
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> set? {
        guard let id = dict["id"] as? String else { return nil }
        
        var set = set()
        set.id = id
        set.completed = dict["completed"] as? Bool ?? false
        set.reps = dict["reps"] as? Int
        set.weight = dict["weight"] as? Double
        set.duration = dict["duration"] as? Int
        set.restPeriod = dict["restPeriod"] as? Int
        set.notes = dict["notes"] as? String
        
        return set
    }
}

