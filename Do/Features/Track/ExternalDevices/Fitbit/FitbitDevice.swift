//
//  FitbitDevice.swift
//  Do
//
//  Fitbit device implementation
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import Combine

class FitbitDevice: NSObject, FitnessDeviceProtocol {
    let deviceId = "fitbit"
    let deviceName = "Fitbit"
    let deviceType: DeviceType = .fitbit
    
    @Published var isConnected = false
    @Published var currentMetrics: WorkoutMetrics?
    
    var capabilities: DeviceCapabilities {
        return DeviceCapabilities(
            supportsGPS: true, // Some Fitbit models have GPS
            supportsHeartRate: true,
            supportsCadence: true,
            supportsElevation: false,
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
    
    private let api = FitbitAPI.shared
    private var metricsTimer: Timer?
    
    override init() {
        super.init()
    }
    
    static func isAvailable() -> Bool {
        return FitbitAPI.shared.hasCredentials()
    }
    
    // MARK: - FitnessDeviceProtocol
    
    func connect() async throws {
        guard FitbitAPI.shared.hasCredentials() else {
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
        return FitbitAPI.shared.hasCredentials()
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
        switch metric {
        case .distance, .pace, .heartRate, .calories, .cadence, .speed:
            return true
        case .elevation:
            return false
        }
    }
    
    func getQualityScore(for metric: MetricType) -> Double {
        switch metric {
        case .heartRate:
            return 0.88
        case .calories:
            return 0.85
        case .distance, .pace:
            return 0.82 // GPS accuracy varies by model
        case .cadence:
            return 0.80
        case .speed:
            return 0.80
        default:
            return 0.0
        }
    }
    
    private func fetchMetrics() async {
        do {
            let metrics = try await api.getCurrentWorkoutMetrics()
            DispatchQueue.main.async {
                self.currentMetrics = metrics
            }
        } catch {
            print("❌ [FitbitDevice] Error fetching metrics: \(error.localizedDescription)")
        }
    }
}

