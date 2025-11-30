//
//  SmartHandoffCoordinator.swift
//  Do
//
//  Intelligent handoff coordination that automatically manages device transitions
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import WatchConnectivity
import UIKit
import Combine

/// Smart handoff coordinator that automatically manages workout handoffs
/// based on device availability, data quality, and user behavior
class SmartHandoffCoordinator: NSObject, ObservableObject {
    static let shared = SmartHandoffCoordinator()
    
    @Published var isMonitoring = false
    @Published var lastHandoffTime: Date?
    @Published var currentPrimaryDevice: DeviceType = .phone // DeviceType from FitnessDeviceProtocol
    
    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimer: Timer?
    private var wcSession: WCSession?
    
    // Handoff conditions
    private var phoneBatteryLevel: Float = 1.0
    private var watchBatteryLevel: Float = 1.0
    private var phoneIsActive = true
    private var watchIsActive = false
    private var phoneHasGoodGPS = true
    private var watchHasGoodGPS = false
    private var phoneHasHeartRate = false
    private var watchHasHeartRate = true
    private var isPhoneInBackground = false
    
    // Handoff thresholds
    private let batteryThreshold: Float = 0.20 // Handoff if device battery < 20%
    private let gpsQualityThreshold: Double = 10.0 // meters accuracy
    private let handoffCooldown: TimeInterval = 30.0 // seconds between handoffs
    
    private override init() {
        super.init()
        setupWatchConnectivity()
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        
        wcSession = WCSession.default
        wcSession?.delegate = self
        wcSession?.activate()
    }
    
    private func setupObservers() {
        // Monitor app state changes
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.phoneWillResignActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.phoneDidBecomeActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.phoneDidEnterBackground()
            }
            .store(in: &cancellables)
        
        // Monitor watch connectivity
        NotificationCenter.default.publisher(for: NSNotification.Name("WatchConnectivityStateChanged"))
            .sink { [weak self] notification in
                if let isReachable = notification.userInfo?["isReachable"] as? Bool {
                    self?.watchIsActive = isReachable
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Monitoring
    
    func startMonitoring(workoutType: WorkoutType) {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        currentPrimaryDevice = .phone // Start with phone as primary
        
        // Start periodic monitoring
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.evaluateHandoffConditions(workoutType: workoutType)
        }
        
        print("🤖 [SmartHandoff] Started monitoring for \(workoutType.rawValue)")
    }
    
    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        print("🤖 [SmartHandoff] Stopped monitoring")
    }
    
    // MARK: - Handoff Evaluation
    
    private func evaluateHandoffConditions(workoutType: WorkoutType) {
        guard isMonitoring else { return }
        
        // Check cooldown period
        if let lastHandoff = lastHandoffTime,
           Date().timeIntervalSince(lastHandoff) < handoffCooldown {
            return
        }
        
        // Get current device capabilities
        updateDeviceCapabilities()
        
        // Evaluate handoff conditions
        let shouldHandoffToWatch = evaluateHandoffToWatch(workoutType: workoutType)
        let shouldHandoffToPhone = evaluateHandoffToPhone(workoutType: workoutType)
        
        if shouldHandoffToWatch && currentPrimaryDevice == .phone {
            initiateHandoffToWatch(workoutType: workoutType)
        } else if shouldHandoffToPhone && currentPrimaryDevice == .appleWatch {
            initiateHandoffToPhone(workoutType: workoutType)
        }
    }
    
    private func evaluateHandoffToWatch(workoutType: WorkoutType) -> Bool {
        // Condition 1: Phone goes to background
        if isPhoneInBackground && watchIsActive {
            print("🤖 [SmartHandoff] Phone in background, watch active → handoff to watch")
            return true
        }
        
        // Condition 2: Phone battery low, watch battery good
        if phoneBatteryLevel < batteryThreshold && watchBatteryLevel > batteryThreshold {
            print("🤖 [SmartHandoff] Phone battery low (\(Int(phoneBatteryLevel * 100))%), watch good → handoff to watch")
            return true
        }
        
        // Condition 3: For indoor workouts, watch is better for heart rate
        if workoutType == .gym || workoutType == .swimming {
            if watchHasHeartRate && !phoneHasHeartRate {
                print("🤖 [SmartHandoff] Indoor workout, watch has HR → handoff to watch")
                return true
            }
        }
        
        // Condition 4: Phone GPS poor, watch has better sensors
        if !phoneHasGoodGPS && watchHasHeartRate {
            print("🤖 [SmartHandoff] Phone GPS poor, watch has sensors → handoff to watch")
            return true
        }
        
        return false
    }
    
    private func evaluateHandoffToPhone(workoutType: WorkoutType) -> Bool {
        // Condition 1: Phone becomes active again
        if !isPhoneInBackground && phoneIsActive && currentPrimaryDevice == .appleWatch {
            print("🤖 [SmartHandoff] Phone active again → handoff to phone")
            return true
        }
        
        // Condition 2: Watch battery low, phone battery good
        if watchBatteryLevel < batteryThreshold && phoneBatteryLevel > batteryThreshold {
            print("🤖 [SmartHandoff] Watch battery low (\(Int(watchBatteryLevel * 100))%), phone good → handoff to phone")
            return true
        }
        
        // Condition 3: For outdoor workouts, phone GPS is better
        if workoutType == .running || workoutType == .biking || workoutType == .hiking || workoutType == .walking {
            if phoneHasGoodGPS && !watchHasGoodGPS {
                print("🤖 [SmartHandoff] Outdoor workout, phone GPS better → handoff to phone")
                return true
            }
        }
        
        // Condition 4: Watch becomes unreachable
        if !watchIsActive && currentPrimaryDevice == .appleWatch {
            print("🤖 [SmartHandoff] Watch unreachable → handoff to phone")
            return true
        }
        
        return false
    }
    
    // MARK: - Device Capability Updates
    
    private func updateDeviceCapabilities() {
        // Update phone battery
        UIDevice.current.isBatteryMonitoringEnabled = true
        phoneBatteryLevel = UIDevice.current.batteryLevel
        
        // Update phone active state
        phoneIsActive = UIApplication.shared.applicationState == .active
        
        // Request watch capabilities
        requestWatchCapabilities()
    }
    
    private func requestWatchCapabilities() {
        guard let session = wcSession,
              session.isReachable else {
            watchIsActive = false
            return
        }
        
        let message: [String: Any] = [
            "type": "requestCapabilities",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: { [weak self] response in
            if let battery = response["batteryLevel"] as? Float {
                self?.watchBatteryLevel = battery
            }
            if let hasHR = response["hasHeartRate"] as? Bool {
                self?.watchHasHeartRate = hasHR
            }
            if let hasGPS = response["hasGPS"] as? Bool {
                self?.watchHasGoodGPS = hasGPS
            }
            self?.watchIsActive = true
        }, errorHandler: { [weak self] error in
            print("❌ [SmartHandoff] Error requesting watch capabilities: \(error.localizedDescription)")
            self?.watchIsActive = false
        })
    }
    
    // MARK: - Handoff Execution
    
    private func initiateHandoffToWatch(workoutType: WorkoutType) {
        guard let session = wcSession,
              session.isWatchAppInstalled,
              session.isReachable else {
            print("⚠️ [SmartHandoff] Cannot handoff to watch - not available")
            return
        }
        
        print("🤖 [SmartHandoff] Initiating automatic handoff to watch for \(workoutType.rawValue)")
        
        // Get current workout state from appropriate engine
        let handoffData = getCurrentWorkoutState(workoutType: workoutType)
        
        guard var handoffData = handoffData else {
            print("⚠️ [SmartHandoff] No active workout to handoff")
            return
        }
        
        handoffData["type"] = "smartHandoff"
        handoffData["direction"] = "phoneToWatch"
        handoffData["reason"] = determineHandoffReason(toWatch: true)
        
        session.sendMessage(handoffData, replyHandler: { [weak self] response in
            if let accepted = response["accepted"] as? Bool, accepted {
                self?.currentPrimaryDevice = .appleWatch // Using DeviceType from FitnessDeviceProtocol
                self?.lastHandoffTime = Date()
                print("✅ [SmartHandoff] Handoff to watch accepted")
                
                // Notify the tracking engine
                NotificationCenter.default.post(
                    name: NSNotification.Name("WorkoutHandoffToWatch"),
                    object: nil,
                    userInfo: ["workoutType": workoutType.rawValue]
                )
            }
        }, errorHandler: { error in
            print("❌ [SmartHandoff] Handoff to watch failed: \(error.localizedDescription)")
        })
    }
    
    private func initiateHandoffToPhone(workoutType: WorkoutType) {
        guard let session = wcSession,
              session.isWatchAppInstalled else {
            return
        }
        
        print("🤖 [SmartHandoff] Initiating automatic handoff to phone for \(workoutType.rawValue)")
        
        // Request workout state from watch
        let message: [String: Any] = [
            "type": "requestHandoffToPhone",
            "workoutType": workoutType.rawValue,
            "reason": determineHandoffReason(toWatch: false),
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: { [weak self] response in
                if let handoffData = response["handoffData"] as? [String: Any] {
                    self?.handleHandoffFromWatch(handoffData: handoffData, workoutType: workoutType)
                }
            }, errorHandler: { error in
                print("❌ [SmartHandoff] Handoff to phone failed: \(error.localizedDescription)")
            })
        } else {
            // Use application context
            do {
                try session.updateApplicationContext(message)
            } catch {
                print("❌ [SmartHandoff] Error updating context: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleHandoffFromWatch(handoffData: [String: Any], workoutType: WorkoutType) {
        currentPrimaryDevice = .phone
        lastHandoffTime = Date()
        
        print("✅ [SmartHandoff] Handoff to phone accepted")
        
        // Notify the tracking engine
        NotificationCenter.default.post(
            name: NSNotification.Name("WorkoutHandoffToPhone"),
            object: nil,
            userInfo: [
                "workoutType": workoutType.rawValue,
                "handoffData": handoffData
            ]
        )
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentWorkoutState(workoutType: WorkoutType) -> [String: Any]? {
        switch workoutType {
        case .running:
            return RunTrackingEngine.shared.getHandoffData()
        case .biking:
            return BikeTrackingEngine.shared.getHandoffData()
        case .hiking:
            return HikeTrackingEngine.shared.getHandoffData()
        case .walking:
            return WalkTrackingEngine.shared.getHandoffData()
        case .swimming:
            return SwimmingTrackingEngine.shared.getHandoffData()
        case .sports:
            return SportsTrackingEngine.shared.getHandoffData()
        case .gym:
            return GymTrackingEngine.shared.getHandoffData()
        }
    }
    
    private func determineHandoffReason(toWatch: Bool) -> String {
        if toWatch {
            if isPhoneInBackground {
                return "phone_in_background"
            } else if phoneBatteryLevel < batteryThreshold {
                return "phone_battery_low"
            } else if !phoneHasGoodGPS {
                return "phone_gps_poor"
            } else {
                return "watch_better_sensors"
            }
        } else {
            if !isPhoneInBackground && phoneIsActive {
                return "phone_active"
            } else if watchBatteryLevel < batteryThreshold {
                return "watch_battery_low"
            } else if phoneHasGoodGPS {
                return "phone_gps_better"
            } else {
                return "watch_unreachable"
            }
        }
    }
    
    // MARK: - App State Handlers
    
    private func phoneWillResignActive() {
        phoneIsActive = false
        print("🤖 [SmartHandoff] Phone will resign active")
    }
    
    private func phoneDidBecomeActive() {
        phoneIsActive = true
        isPhoneInBackground = false
        print("🤖 [SmartHandoff] Phone became active")
    }
    
    private func phoneDidEnterBackground() {
        isPhoneInBackground = true
        phoneIsActive = false
        print("🤖 [SmartHandoff] Phone entered background")
    }
}

// MARK: - Device Type

// DeviceType is defined in Features/Track/ExternalDevices/FitnessDeviceProtocol.swift
// Using that definition instead of a duplicate here

// MARK: - WCSessionDelegate

extension SmartHandoffCoordinator: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ [SmartHandoff] Session activation failed: \(error.localizedDescription)")
        } else {
            print("✅ [SmartHandoff] Session activated")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        watchIsActive = false
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let type = message["type"] as? String {
            switch type {
            case "requestHandoffToPhone":
                // Watch is requesting handoff to phone
                if let workoutTypeString = message["workoutType"] as? String,
                   let workoutType = WorkoutType(rawValue: workoutTypeString) {
                    handleWatchRequestedHandoff(workoutType: workoutType)
                }
            case "capabilitiesUpdate":
                // Watch sent capability update
                if let battery = message["batteryLevel"] as? Float {
                    watchBatteryLevel = battery
                }
                if let hasHR = message["hasHeartRate"] as? Bool {
                    watchHasHeartRate = hasHR
                }
                if let hasGPS = message["hasGPS"] as? Bool {
                    watchHasGoodGPS = hasGPS
                }
            default:
                break
            }
        }
    }
    
    private func handleWatchRequestedHandoff(workoutType: WorkoutType) {
        // Watch wants to handoff to phone - evaluate if we should accept
        if evaluateHandoffToPhone(workoutType: workoutType) {
            initiateHandoffToPhone(workoutType: workoutType)
        }
    }
}

