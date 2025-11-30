//
//  GarminDevice.swift
//  Do
//
//  Garmin device implementation
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import Combine

class GarminDevice: NSObject, FitnessDeviceProtocol {
    let deviceId = "garmin"
    let deviceName = "Garmin"
    let deviceType: DeviceType = .garmin
    
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
    
    private let api = GarminConnectAPI.shared
    private var metricsTimer: Timer?
    
    override init() {
        super.init()
    }
    
    static func isAvailable() -> Bool {
        return GarminConnectAPI.shared.hasCredentials()
    }
    
    // MARK: - FitnessDeviceProtocol
    
    func connect() async throws {
        guard GarminConnectAPI.shared.hasCredentials() else {
            throw DeviceError.authenticationRequired
        }
        
        try await api.authenticate()
        isConnected = true
    }
    
    func disconnect() {
        isConnected = false
        stopMetricsStream()
    }
    
    func isAvailable() -> Bool {
        return GarminConnectAPI.shared.hasCredentials()
    }
    
    func startMetricsStream() async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchMetrics()
            }
        }
    }
    
    func stopMetricsStream() {
        metricsTimer?.invalidate()
        metricsTimer = nil
    }
    
    func supportsMetric(_ metric: MetricType) -> Bool {
        return true // Garmin devices support all metrics
    }
    
    func getQualityScore(for metric: MetricType) -> Double {
        switch metric {
        case .distance, .pace, .speed, .elevation:
            return 0.95 // Excellent GPS accuracy
        case .heartRate:
            return 0.90
        case .cadence:
            return 0.92
        case .calories:
            return 0.88
        }
    }
    
    private func fetchMetrics() async {
        do {
            let metrics = try await api.getCurrentWorkoutMetrics()
            DispatchQueue.main.async {
                self.currentMetrics = metrics
            }
        } catch {
            print("❌ [GarminDevice] Error fetching metrics: \(error.localizedDescription)")
        }
    }
}

