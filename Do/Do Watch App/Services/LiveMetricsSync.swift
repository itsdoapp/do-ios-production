//
//  LiveMetricsSync.swift
//  Do Watch App
//
//  Real-time metrics sync service
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import Combine

class LiveMetricsSync: ObservableObject {
    static let shared = LiveMetricsSync()
    
    @Published var lastSyncTime: Date?
    @Published var syncInterval: TimeInterval = 2.0
    @Published var isSyncing = false
    
    private var syncTimer: Timer?
    private let connectivityManager = WatchConnectivityManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupObservers()
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
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.syncMetrics()
        }
    }
    
    func stopLiveSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        isSyncing = false
    }
    
    // MARK: - Metrics Synchronization
    
    private func syncMetrics() {
        guard let workout = WatchWorkoutCoordinator.shared.activeWorkout,
              workout.state.isActive else {
            return
        }
        
        isSyncing = true
        
        // Optimize payload size
        let optimizedMetrics = optimizeMetricsPayload(workout.metrics)
        
        let message: [String: Any] = [
            "type": "liveMetrics",
            "workoutId": workout.id,
            "workoutType": workout.workoutType.rawValue,
            "metrics": optimizedMetrics,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Test logging
        TrackingTestLogger.shared.logSyncEvent(category: workout.workoutType.rawValue.uppercased(), direction: "watchToPhone", data: message)
        
        connectivityManager.sendMessage(message) { [weak self] _ in
            DispatchQueue.main.async {
                self?.lastSyncTime = Date()
                self?.isSyncing = false
            }
        } errorHandler: { [weak self] error in
            DispatchQueue.main.async {
                self?.isSyncing = false
                print("❌ [LiveMetricsSync] Sync error: \(error.localizedDescription)")
                TrackingTestLogger.shared.logError(category: workout.workoutType.rawValue.uppercased(), message: "Sync error", error: error)
                // Handle network interruption
                self?.handleNetworkInterruption()
            }
        }
    }
    
    // MARK: - Payload Optimization
    
    private func optimizeMetricsPayload(_ metrics: WorkoutMetrics) -> [String: Any] {
        // Only send changed values or essential metrics to reduce payload size
        var payload: [String: Any] = [:]
        
        // Always include essential metrics
        payload["distance"] = round(metrics.distance * 100) / 100 // Round to 2 decimals
        payload["elapsedTime"] = round(metrics.elapsedTime * 10) / 10 // Round to 1 decimal
        payload["heartRate"] = round(metrics.heartRate)
        payload["pace"] = round(metrics.pace * 100) / 100
        payload["calories"] = round(metrics.calories)
        
        // Include optional metrics only if they have values
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
        if let workout = WatchWorkoutCoordinator.shared.activeWorkout {
            storeMetricsLocally(workout.metrics, workoutId: workout.id)
        }
        
        // Try to reconnect and sync stored metrics
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if self.connectivityManager.isReachable {
                self.syncStoredMetrics()
            }
        }
    }
    
    private func storeMetricsLocally(_ metrics: WorkoutMetrics, workoutId: String) {
        let userDefaults = UserDefaults.standard
        let key = "pendingMetrics_\(workoutId)"
        userDefaults.set(metrics.toDictionary(), forKey: key)
    }
    
    private func syncStoredMetrics() {
        let userDefaults = UserDefaults.standard
        let keys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("pendingMetrics_") }
        
        for key in keys {
            if let metricsDict = userDefaults.dictionary(forKey: key) as? [String: Any],
               let metrics = WorkoutMetrics.fromDictionary(metricsDict) {
                let workoutId = String(key.dropFirst("pendingMetrics_".count))
                
                if let workout = WatchWorkoutCoordinator.shared.activeWorkout,
                   workout.id == workoutId {
                    // Sync stored metrics
                    let message: [String: Any] = [
                        "type": "storedMetrics",
                        "workoutId": workoutId,
                        "metrics": metrics.toDictionary()
                    ]
                    connectivityManager.sendMessage(message)
                    
                    // Remove from storage
                    userDefaults.removeObject(forKey: key)
                }
            }
        }
    }
    
    // MARK: - Incoming Metrics Handling
    
    private func handleIncomingMetrics(_ metricsDict: [String: Any]) {
        guard let metrics = WorkoutMetrics.fromDictionary(metricsDict),
              var workout = WatchWorkoutCoordinator.shared.activeWorkout else {
            return
        }
        
        // Test logging
        TrackingTestLogger.shared.logSyncEvent(category: workout.workoutType.rawValue.uppercased(), direction: "phoneToWatch", data: metricsDict)
        
        // Merge with existing metrics
        workout.metrics = MetricsHandoffService.shared.mergeMetrics(
            phoneMetrics: metrics,
            watchMetrics: workout.metrics,
            workoutType: workout.workoutType
        )
        workout.lastUpdateDate = Date()
        
        WatchWorkoutCoordinator.shared.activeWorkout = workout
    }
}

