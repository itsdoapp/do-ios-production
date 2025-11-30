//
//  AppleWatchMetricsProvider.swift
//  Do
//
//  Provides metrics from Apple Watch
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import WatchConnectivity

class AppleWatchMetricsProvider {
    static let shared = AppleWatchMetricsProvider()
    
    private let connectionManager = AppleWatchConnectionManager.shared
    
    private init() {}
    
    func requestMetrics(completion: @escaping (WorkoutMetrics?) -> Void) {
        guard connectionManager.isReachable else {
            completion(nil)
            return
        }
        
        connectionManager.sendMessage(["request": "workoutMetrics"]) { response in
            if let metrics = WorkoutMetrics.fromDictionary(response) {
                completion(metrics)
            } else {
                completion(nil)
            }
        }
    }
    
    func subscribeToMetrics(updateHandler: @escaping (WorkoutMetrics) -> Void) {
        // Implementation would set up a subscription to watch metrics
        // For now, use periodic requests
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.requestMetrics { metrics in
                if let metrics = metrics {
                    updateHandler(metrics)
                }
            }
        }
    }
}

