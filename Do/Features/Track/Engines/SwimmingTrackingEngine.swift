//
//  SwimmingTrackingEngine.swift
//  Do
//
//  Extracted from ModernSwimmingTrackerViewController.swift
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import WatchConnectivity
import UIKit
import Combine

// MARK: - Swimming Tracking Engine
class SwimmingTrackingEngine: NSObject, ObservableObject {
    static let shared = SwimmingTrackingEngine()
    
    @Published var isTracking = false
    @Published var currentUser: UserModel?
    // Live metrics
    @Published var laps: Int = 0
    @Published var distanceMeters: Double = 0
    @Published var poolLengthMeters: Double = 25
    @Published var strokeType: String = "freestyle"
    @Published var heartRate: Double = 0
    @Published var elapsedTime: TimeInterval = 0
    @Published var pacePer100mSec: Double = 0
    
    enum SwimState: String { case notStarted, active, paused, ended }
    @Published var state: SwimState = .notStarted
    
    // Device coordination properties
    @Published var isWatchTracking: Bool = false
    @Published var isIndoorMode: Bool = true // Swimming is typically in pool (indoor)
    @Published var hasGoodLocationData: Bool = false // GPS doesn't work underwater
    @Published var isPrimaryForDistance: Bool = false // Watch is primary for swimming metrics
    @Published var isPrimaryForPace: Bool = false
    @Published var isPrimaryForHeartRate: Bool = false // Watch is always primary for HR
    @Published var isPrimaryForCalories: Bool = false
    @Published var isPrimaryForCadence: Bool = false
    @Published var isDashboardMode: Bool = true // Phone acts as dashboard for swimming
    
    internal var workoutId = UUID()
    private var startDate: Date?
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {}
    
    func setCurrentUser() {
        // Use CurrentUserService instead of Parse
        if CurrentUserService.shared.user.userID != nil {
            self.currentUser = CurrentUserService.shared.user
        } else {
            // If user not loaded, try to load from UserIDHelper
            if let userId = UserIDHelper.shared.getCurrentUserID() {
                Task {
                    // Try to fetch user profile from AWS
                    if let userProfile = try? await UserProfileService.shared.fetchUserProfile(userId: userId) {
                        await MainActor.run {
                            self.currentUser = userProfile
                        }
                    } else {
                        // Fallback to CurrentUserService
                        await MainActor.run {
                            self.currentUser = CurrentUserService.shared.user
                        }
                    }
                }
            }
        }
    }
    
    func startTracking() {
        isTracking = true
        state = .active
        // Phone is the dashboard; tracking occurs on watch. Ensure WCSession is active.
        setupWatchSessionIfNeeded()
        
        // Establish device coordination when swim starts
        establishDeviceCoordination()
        
        // Start smart handoff monitoring
        SmartHandoffCoordinator.shared.startMonitoring(workoutType: .swimming)
    }
    
    func pause() { state = .paused }
    func resume() { state = .active }
    
    func endWorkoutAndSave() {
        state = .ended
        isTracking = false
        saveCurrentWorkoutToParse()
        
        // Stop smart handoff monitoring
        SmartHandoffCoordinator.shared.stopMonitoring()
    }
    
    func endSwimming() {
        endWorkoutAndSave()
    }
    
    // MARK: - Formatting helpers
    var formattedPacePer100m: String {
        guard pacePer100mSec > 0 else { return "-" }
        let minutes = Int(pacePer100mSec) / 60
        let seconds = Int(pacePer100mSec) % 60
        return String(format: "%d'%02d\"", minutes, seconds)
    }
    
    var formattedElapsedTime: String {
        let total = Int(elapsedTime)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
    
    // MARK: - AWS Save
    func saveCurrentWorkoutToParse() {
        Task { @MainActor in
            do {
                let _ = try await WorkoutHistoryService().saveSwimmingWorkout(
                    laps: self.laps,
                    distanceMeters: self.distanceMeters,
                    poolLengthMeters: self.poolLengthMeters,
                    durationSec: self.elapsedTime,
                    avgPacePer100Sec: self.pacePer100mSec,
                    stroke: self.strokeType,
                    avgHeartRate: self.heartRate > 0 ? self.heartRate : nil
                )
                print("✅ Swimming workout saved via WorkoutHistoryService")
            } catch {
                print("🛑 Swimming save error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Device Coordination
    
    // Establish initial device coordination roles
    private func establishDeviceCoordination() {
        guard state != .notStarted && state != .ended else { return }
        
        // For swimming, watch is always primary since GPS doesn't work underwater
        // Phone acts as dashboard
        isDashboardMode = true
        isWatchTracking = true
        
        // Set watch as primary for all metrics
        isPrimaryForDistance = false
        isPrimaryForPace = false
        isPrimaryForHeartRate = false
        isPrimaryForCalories = false
        isPrimaryForCadence = false
        
        print("📱 Swimming: Phone acting as dashboard")
        print("⌚️ Watch will be primary for all tracking metrics")
        
        // Update application context to let watch know current state
        updateApplicationContext()
    }
    
    // Update application context
    private func updateApplicationContext() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        
        let context: [String: Any] = [
            "type": "swimWorkoutState",
            "swimState": state.rawValue,
            "isIndoor": isIndoorMode,
            "isWatchTracking": isWatchTracking,
            "isPrimaryForDistance": isPrimaryForDistance,
            "isPrimaryForPace": isPrimaryForPace,
            "isPrimaryForHeartRate": isPrimaryForHeartRate,
            "isPrimaryForCalories": isPrimaryForCalories,
            "isPrimaryForCadence": isPrimaryForCadence,
            "isDashboardMode": isDashboardMode,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        do {
            try session.updateApplicationContext(context)
        } catch {
            print("📱 Error updating application context: \(error.localizedDescription)")
        }
    }
    
    // Setup watch session if needed
    private func setupWatchSessionIfNeeded() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.activationState != .activated {
            session.delegate = self
            session.activate()
        }
    }
}

// MARK: - WCSessionDelegate
extension SwimmingTrackingEngine: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("📱 WCSession activation error: \(error.localizedDescription)")
        } else {
            print("📱 WCSession activated: \(activationState.rawValue)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("📱 WCSession deactivated")
        session.activate()
    }
}

// MARK: - Watch Handoff and Multi-Device Support

extension SwimmingTrackingEngine {
    
    /// Initiate handoff to watch
    func initiateHandoffToWatch(completion: @escaping (Bool) -> Void) {
        guard state != .notStarted else {
            completion(false)
            return
        }
        
        let metrics = WorkoutMetrics(
            distance: distanceMeters,
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            pace: pacePer100mSec,
            calories: 0, // Swimming calories calculated differently
            cadence: 0,
            elevationGain: nil
        )
        
        let handoffMessage = WorkoutHandoffMessage(
            direction: .phoneToWatch,
            workoutType: .swimming,
            workoutId: workoutId.uuidString,
            metrics: metrics,
            state: convertSwimStateToWorkoutState(state),
            startDate: startDate ?? Date()
        )
        
        guard let session = WCSession.default as? WCSession,
              session.isWatchAppInstalled else {
            completion(false)
            return
        }
        
        if session.isReachable {
            session.sendMessage(handoffMessage.toDictionary(), replyHandler: { response in
                let accepted = response["accepted"] as? Bool ?? false
                if accepted {
                    self.endWorkoutAndSave()
                }
                completion(accepted)
            }, errorHandler: { error in
                print("❌ [SwimmingTrackingEngine] Handoff failed: \(error.localizedDescription)")
                completion(false)
            })
        } else {
            do {
                try session.updateApplicationContext(handoffMessage.toDictionary())
                completion(true)
            } catch {
                completion(false)
            }
        }
    }
    
    /// Handle handoff from watch
    func handleHandoffFromWatch(_ message: [String: Any]) {
        guard let handoffMessage = WorkoutHandoffMessage.fromDictionary(message) else {
            return
        }
        
        if state != .notStarted {
            handleHandoffConflict(phoneState: convertSwimStateToWorkoutState(state),
                                watchWorkout: handoffMessage)
            return
        }
        
        workoutId = UUID(uuidString: handoffMessage.workoutId) ?? UUID()
        startDate = handoffMessage.startDate
        
        distanceMeters = handoffMessage.metrics.distance
        elapsedTime = handoffMessage.metrics.elapsedTime
        heartRate = handoffMessage.metrics.heartRate
        pacePer100mSec = handoffMessage.metrics.pace
        
        state = convertWorkoutStateToSwimState(handoffMessage.state)
        
        if let session = WCSession.default as? WCSession, session.isReachable {
            session.sendMessage([
                "type": "handoffResponse",
                "accepted": true,
                "workoutId": workoutId.uuidString
            ], replyHandler: { response in
                print("📱 Watch acknowledged handoff response: \(response)")
            }, errorHandler: { error in
                print("📱 Error sending handoff response: \(error.localizedDescription)")
            })
        }
    }
    
    private func handleHandoffConflict(phoneState: WorkoutState, watchWorkout: WorkoutHandoffMessage) {
        workoutId = UUID(uuidString: watchWorkout.workoutId) ?? UUID()
        startDate = watchWorkout.startDate
        
        heartRate = watchWorkout.metrics.heartRate
        elapsedTime = max(elapsedTime, watchWorkout.metrics.elapsedTime)
        distanceMeters = max(distanceMeters, watchWorkout.metrics.distance)
        
        state = convertWorkoutStateToSwimState(watchWorkout.state)
    }
    
    // MARK: - Multi-Device Support
    
    func integrateWithExternalDevices() {
        let aggregator = MultiDeviceDataAggregator.shared
        
        aggregator.$aggregatedMetrics
            .sink { [weak self] metrics in
                self?.updateMetricsFromExternalDevices(metrics)
            }
            .store(in: &cancellables)
    }
    
    private func updateMetricsFromExternalDevices(_ metrics: WorkoutMetrics) {
        let coordinationEngine = DeviceCoordinationEngine.shared
        
        // For swimming, watch is always primary
        if metrics.heartRate > 0 {
            heartRate = metrics.heartRate
        }
    }
    
    // MARK: - Live Metrics Sync
    
    func startLiveMetricsSync() {
        LiveMetricsSync.shared.startLiveSync()
        
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.syncCurrentMetrics()
        }
    }
    
    func stopLiveMetricsSync() {
        LiveMetricsSync.shared.stopLiveSync()
    }
    
    private func syncCurrentMetrics() {
        guard state != .notStarted else { return }
        
        let metrics = WorkoutMetrics(
            distance: distanceMeters,
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            pace: pacePer100mSec,
            calories: 0,
            cadence: 0,
            elevationGain: nil
        )
        
        LiveMetricsSync.shared.syncMetrics(
            metrics: metrics,
            workoutId: workoutId.uuidString,
            workoutType: .swimming
        )
    }
    
    // MARK: - State Conversion Helpers
    
    private func convertSwimStateToWorkoutState(_ swimState: SwimState) -> WorkoutState {
        switch swimState {
        case .notStarted: return .idle
        case .active: return .running
        case .paused: return .paused
        case .ended: return .stopped
        }
    }
    
    private func convertWorkoutStateToSwimState(_ workoutState: WorkoutState) -> SwimState {
        switch workoutState {
        case .idle: return .notStarted
        case .starting, .running: return .active
        case .paused: return .paused
        case .stopping, .stopped, .completed: return .ended
        }
    }
    
    // MARK: - Enhanced Watch Sync
    
    func enhancedSyncWithWatch() {
        updateApplicationContext()
        
        WorkoutStateSync.shared.syncState(
            workoutId: workoutId.uuidString,
            workoutType: .swimming,
            state: convertSwimStateToWorkoutState(state)
        )
    }
    
    // MARK: - Handoff Data Provider
    
    func getHandoffData() -> [String: Any]? {
        guard state != .notStarted else { return nil }
        
        let metrics = WorkoutMetrics(
            distance: distanceMeters,
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            pace: pacePer100mSec,
            calories: 0,
            cadence: 0,
            elevationGain: nil
        )
        
        let handoffMessage = WorkoutHandoffMessage(
            direction: .phoneToWatch,
            workoutType: .swimming,
            workoutId: workoutId.uuidString,
            metrics: metrics,
            state: convertSwimStateToWorkoutState(state),
            startDate: startDate ?? Date()
        )
        
        return handoffMessage.toDictionary()
    }
}

