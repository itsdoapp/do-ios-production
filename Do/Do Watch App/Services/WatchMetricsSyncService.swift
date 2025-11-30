//
//  WatchMetricsSyncService.swift
//  Do Watch App
//
//  Handles live metrics synchronization
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import Combine

class WatchMetricsSyncService: ObservableObject {
    static let shared = WatchMetricsSyncService()
    
    @Published var lastSyncTime: Date?
    @Published var syncEnabled = true
    
    private let connectivityManager = WatchConnectivityManager.shared
    private let liveSync = LiveMetricsSync.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Start live sync when workout starts
        NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutStarted"))
            .sink { [weak self] _ in
                self?.startSync()
            }
            .store(in: &cancellables)
        
        // Stop live sync when workout stops
        NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutStopped"))
            .sink { [weak self] _ in
                self?.stopSync()
            }
            .store(in: &cancellables)
    }
    
    func startSync() {
        guard syncEnabled else { return }
        liveSync.startLiveSync()
    }
    
    func stopSync() {
        liveSync.stopLiveSync()
    }
    
    func syncMetrics(_ metrics: WorkoutMetrics, workoutId: String, workoutType: WorkoutType) {
        guard syncEnabled else { return }
        
        WatchWorkoutCoordinator.shared.updateMetrics(metrics)
        lastSyncTime = Date()
    }
}

