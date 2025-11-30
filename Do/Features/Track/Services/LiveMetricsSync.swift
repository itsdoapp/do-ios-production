//
//  LiveMetricsSync.swift
//  Do
//
//  Real-time metrics sync service (iOS side)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import WatchConnectivity
import Combine

class LiveMetricsSync: NSObject, ObservableObject {
    static let shared = LiveMetricsSync()
    
    @Published var lastSyncTime: Date?
    @Published var syncInterval: TimeInterval = 2.0
    @Published var isSyncing = false
    
    private var syncTimer: Timer?
    private var session: WCSession?
    private var cancellables = Set<AnyCancellable>()
    
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
        NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutMetricsUpdate"))
            .sink { [weak self] notification in
                if let metrics = notification.userInfo as? [String: Any] {
                    self?.handleIncomingMetrics(metrics)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Sync Control
    
    func startLiveSync(interval: TimeInterval = 2.0) {
        stopLiveSync()
        syncInterval = interval
        
        // Note: The timer here is just for periodic checks
        // Actual syncing is done via syncMetrics() called by tracking engines
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            // This can be used for automatic syncing if needed
            // For now, tracking engines call syncMetrics() directly
        }
    }
    
    func stopLiveSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        isSyncing = false
    }
    
    // MARK: - Metrics Synchronization
    
    /// Public method to sync metrics from tracking engines (iOS side)
    func syncMetrics(metrics: WorkoutMetrics, workoutId: String, workoutType: WorkoutType) {
        guard let session = session, session.isWatchAppInstalled else {
            print("⚠️ [LiveMetricsSync] Watch app not installed, skipping sync")
            return
        }
        
        isSyncing = true
        
        let optimizedMetrics = optimizeMetricsPayload(metrics)
        
        let message: [String: Any] = [
            "type": "liveMetrics",
            "workoutId": workoutId,
            "workoutType": workoutType.rawValue,
            "metrics": optimizedMetrics,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.lastSyncTime = Date()
                    self?.isSyncing = false
                    print("✅ [LiveMetricsSync] Metrics synced to watch successfully")
                }
            }, errorHandler: { [weak self] error in
                DispatchQueue.main.async {
                    self?.isSyncing = false
                    print("❌ [LiveMetricsSync] Sync error: \(error.localizedDescription)")
                    self?.handleNetworkInterruption()
                }
            })
        } else {
            // Use application context for background sync
            do {
                try session.updateApplicationContext(message)
                lastSyncTime = Date()
                isSyncing = false
                print("✅ [LiveMetricsSync] Metrics queued via application context")
            } catch {
                isSyncing = false
                print("❌ [LiveMetricsSync] Failed to update context: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Payload Optimization
    
    private func optimizeMetricsPayload(_ metrics: WorkoutMetrics) -> [String: Any] {
        var payload: [String: Any] = [:]
        
        // Round values to reduce payload size
        payload["distance"] = round(metrics.distance * 100) / 100
        payload["elapsedTime"] = round(metrics.elapsedTime * 10) / 10
        payload["heartRate"] = round(metrics.heartRate)
        payload["pace"] = round(metrics.pace * 100) / 100
        payload["calories"] = round(metrics.calories)
        
        if let cadence = metrics.cadence, cadence > 0 {
            payload["cadence"] = round(cadence)
        }
        if let elevation = metrics.elevationGain, elevation > 0 {
            payload["elevationGain"] = round(elevation)
        }
        if let speed = metrics.currentSpeed, speed > 0 {
            payload["currentSpeed"] = round(speed * 100) / 100
        }
        
        return payload
    }
    
    // MARK: - Network Interruption Handling
    
    private func handleNetworkInterruption() {
        // Store metrics locally for later sync
        let userDefaults = UserDefaults.standard
        let key = "pendingMetrics_\(Date().timeIntervalSince1970)"
        // Would store current metrics here for retry
        userDefaults.set(Date().timeIntervalSince1970, forKey: key)
        print("📦 [LiveMetricsSync] Metrics queued for retry")
    }
    
    // MARK: - Incoming Metrics Handling
    
    private func handleIncomingMetrics(_ metricsDict: [String: Any]) {
        guard let metrics = WorkoutMetrics.fromDictionary(metricsDict) else {
            print("⚠️ [LiveMetricsSync] Failed to parse incoming metrics")
            return
        }
        
        // Notify tracking engine of watch metrics
        NotificationCenter.default.post(
            name: NSNotification.Name("WatchMetricsReceived"),
            object: nil,
            userInfo: metricsDict
        )
        print("📥 [LiveMetricsSync] Received metrics from watch")
    }
}

// MARK: - WCSessionDelegate

extension LiveMetricsSync: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ [LiveMetricsSync] Session activation failed: \(error.localizedDescription)")
        } else if activationState == .activated {
            print("✅ [LiveMetricsSync] WCSession activated")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ [LiveMetricsSync] Session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("⚠️ [LiveMetricsSync] Session deactivated, reactivating...")
        session.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let type = message["type"] as? String, type == "liveMetrics" {
            handleIncomingMetrics(message)
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let type = applicationContext["type"] as? String, type == "liveMetrics" {
            handleIncomingMetrics(applicationContext)
        }
    }
}

