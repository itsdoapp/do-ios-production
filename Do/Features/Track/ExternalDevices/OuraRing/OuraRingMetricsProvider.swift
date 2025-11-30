//
//  OuraRingMetricsProvider.swift
//  Do
//
//  Provides Oura-specific metrics
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

class OuraRingMetricsProvider {
    static let shared = OuraRingMetricsProvider()
    
    private let api = OuraRingAPI.shared
    
    private init() {}
    
    func getHeartRate() async throws -> Double {
        let metrics = try await api.getCurrentMetrics()
        return metrics.heartRate
    }
    
    func getCalories() async throws -> Double {
        let metrics = try await api.getCurrentMetrics()
        return metrics.calories
    }
}

