//
//  FitbitMetricsProvider.swift
//  Do
//
//  Provides Fitbit-specific metrics
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

class FitbitMetricsProvider {
    static let shared = FitbitMetricsProvider()
    
    private let api = FitbitAPI.shared
    
    private init() {}
    
    func getAllMetrics() async throws -> WorkoutMetrics {
        return try await api.getCurrentWorkoutMetrics()
    }
}

