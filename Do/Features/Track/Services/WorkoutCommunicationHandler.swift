//
//  WorkoutCommunicationHandler.swift
//  Do
//
//  Handles communication between workout tracking engines and watch
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import WatchConnectivity

protocol WorkoutCommunicationHandlerDelegate: AnyObject {
    func workoutCommunicationHandler(_ handler: WorkoutCommunicationHandler, didReceiveMessage message: [String: Any])
    func workoutCommunicationHandler(_ handler: WorkoutCommunicationHandler, didUpdateConnectionStatus isConnected: Bool)
}

class WorkoutCommunicationHandler: NSObject {
    static let shared = WorkoutCommunicationHandler()
    
    weak var delegate: WorkoutCommunicationHandlerDelegate?
    
    private var session: WCSession?
    private var isPhoneTracking: Bool = false
    
    // Primary device flags
    var isPrimaryForDistance: Bool = true
    var isPrimaryForPace: Bool = true
    var isPrimaryForHeartRate: Bool = false
    var isPrimaryForCalories: Bool = true
    var isPrimaryForCadence: Bool = false
    
    // Tracking status flags
    var isDashboardMode: Bool = false
    var isWatchTracking: Bool = false
    
    private override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("⚠️ [WorkoutCommunicationHandler] WatchConnectivity not supported")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    func sendTrackingStatus(isPhoneTracking: Bool) {
        self.isPhoneTracking = isPhoneTracking
        
        guard let session = session, session.isWatchAppInstalled else { return }
        
        let message: [String: Any] = [
            "type": "trackingStatus",
            "isPhoneTracking": isPhoneTracking,
            "isPrimaryForDistance": isPrimaryForDistance,
            "isPrimaryForPace": isPrimaryForPace,
            "isPrimaryForHeartRate": isPrimaryForHeartRate,
            "isPrimaryForCalories": isPrimaryForCalories,
            "isPrimaryForCadence": isPrimaryForCadence
        ]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: { error in
                print("❌ [WorkoutCommunicationHandler] Error sending status: \(error.localizedDescription)")
            })
        } else {
            do {
                try session.updateApplicationContext(message)
            } catch {
                print("❌ [WorkoutCommunicationHandler] Error updating context: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WorkoutCommunicationHandler: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ [WorkoutCommunicationHandler] Session activation failed: \(error.localizedDescription)")
        } else {
            print("✅ [WorkoutCommunicationHandler] Session activated")
            delegate?.workoutCommunicationHandler(self, didUpdateConnectionStatus: session.isReachable)
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ [WorkoutCommunicationHandler] Session became inactive")
        delegate?.workoutCommunicationHandler(self, didUpdateConnectionStatus: false)
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        delegate?.workoutCommunicationHandler(self, didReceiveMessage: message)
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        delegate?.workoutCommunicationHandler(self, didReceiveMessage: applicationContext)
    }
}

