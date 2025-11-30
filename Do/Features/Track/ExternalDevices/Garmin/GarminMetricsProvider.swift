//
//  GarminMetricsProvider.swift
//  Do
//
//  Provides Garmin-specific metrics
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

class GarminMetricsProvider {
    static let shared = GarminMetricsProvider()
    
    private let api = GarminConnectAPI.shared
    
    private init() {}
    
    func getAllMetrics() async throws -> WorkoutMetrics {
        return try await api.getCurrentWorkoutMetrics()
    }
}

