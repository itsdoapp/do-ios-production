//
//  AppleWatchDevice.swift
//  Do
//
//  Apple Watch device implementation
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import WatchConnectivity
import HealthKit
import Combine

class AppleWatchDevice: NSObject, FitnessDeviceProtocol {
    let deviceId = "appleWatch"
    let deviceName = "Apple Watch"
    let deviceType: DeviceType = .appleWatch
    
    @Published var isConnected = false
    @Published var currentMetrics: WorkoutMetrics?
    
    var capabilities: DeviceCapabilities {
        return DeviceCapabilities(
            supportsGPS: true,
            supportsHeartRate: true,
            supportsCadence: true,
            supportsElevation: true,
            supportsCalories: true,
            supportsDistance: true,
            supportsPace: true
        )
    }
    
    var connectionStatusPublisher: AnyPublisher<Bool, Never> {
        $isConnected.eraseToAnyPublisher()
    }
    
    var metricsPublisher: AnyPublisher<WorkoutMetrics?, Never> {
        $currentMetrics.eraseToAnyPublisher()
    }
    
    private var session: WCSession?
    private var metricsTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("⚠️ [AppleWatchDevice] WatchConnectivity not supported")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    // MARK: - FitnessDeviceProtocol
    
    func connect() async throws {
        guard let session = session else {
            throw DeviceError.notAvailable
        }
        
        guard session.isWatchAppInstalled else {
            throw DeviceError.notAvailable
        }
        
        guard session.activationState == .activated else {
            throw DeviceError.connectionFailed
        }
        
        isConnected = session.isReachable || session.isWatchAppInstalled
    }
    
    func disconnect() {
        isConnected = false
        stopMetricsStream()
    }
    
    func isAvailable() -> Bool {
        return WCSession.isSupported() && session?.isWatchAppInstalled == true
    }
    
    func startMetricsStream() async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        // Request metrics from watch
        requestMetricsFromWatch()
        
        // Set up periodic requests
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.requestMetricsFromWatch()
        }
    }
    
    func stopMetricsStream() {
        metricsTimer?.invalidate()
        metricsTimer = nil
    }
    
    func supportsMetric(_ metric: MetricType) -> Bool {
        switch metric {
        case .distance, .pace, .heartRate, .cadence, .calories, .elevation, .speed:
            return true
        }
    }
    
    func getQualityScore(for metric: MetricType) -> Double {
        switch metric {
        case .heartRate, .cadence:
            return 0.95 // Very accurate
        case .distance, .pace, .speed:
            return 0.85 // GPS-based, good accuracy
        case .elevation:
            return 0.80 // GPS-based elevation
        case .calories:
            return 0.90 // HealthKit calculations
        }
    }
    
    // MARK: - Metrics Request
    
    private func requestMetricsFromWatch() {
        guard let session = session, session.isReachable else {
            // Fallback to application context
            if let context = session?.receivedApplicationContext as? [String: Any],
               let metrics = parseMetrics(from: context) {
                DispatchQueue.main.async {
                    self.currentMetrics = metrics
                }
            }
            return
        }
        
        session.sendMessage(["request": "workoutMetrics"], replyHandler: { [weak self] response in
            if let metrics = self?.parseMetrics(from: response) {
                DispatchQueue.main.async {
                    self?.currentMetrics = metrics
                }
            }
        }, errorHandler: { error in
            print("❌ [AppleWatchDevice] Error requesting metrics: \(error.localizedDescription)")
        })
    }
    
    private func parseMetrics(from dict: [String: Any]) -> WorkoutMetrics? {
        guard let metricsDict = dict["metrics"] as? [String: Any] else {
            return WorkoutMetrics.fromDictionary(dict)
        }
        return WorkoutMetrics.fromDictionary(metricsDict)
    }
}

// MARK: - WCSessionDelegate

extension AppleWatchDevice: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("❌ [AppleWatchDevice] Session activation failed: \(error.localizedDescription)")
                self.isConnected = false
            } else {
                self.isConnected = session.isWatchAppInstalled && session.activationState == .activated
                if self.isConnected {
                    Task {
                        try? await self.startMetricsStream()
                    }
                }
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable || session.isWatchAppInstalled
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let metrics = parseMetrics(from: message) {
            DispatchQueue.main.async {
                self.currentMetrics = metrics
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let metrics = parseMetrics(from: applicationContext) {
            DispatchQueue.main.async {
                self.currentMetrics = metrics
            }
        }
    }
}

enum DeviceError: Error {
    case notAvailable
    case notConnected
    case connectionFailed
    case authenticationRequired
}

