//
//  OuraRingDevice.swift
//  Do
//
//  Oura Ring device implementation
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import Combine

class OuraRingDevice: NSObject, FitnessDeviceProtocol {
    let deviceId = "ouraRing"
    let deviceName = "Oura Ring"
    let deviceType: DeviceType = .ouraRing
    
    @Published var isConnected = false
    @Published var currentMetrics: WorkoutMetrics?
    
    var capabilities: DeviceCapabilities {
        return DeviceCapabilities(
            supportsGPS: false,
            supportsHeartRate: true,
            supportsCadence: false,
            supportsElevation: false,
            supportsCalories: true,
            supportsDistance: false,
            supportsPace: false
        )
    }
    
    var connectionStatusPublisher: AnyPublisher<Bool, Never> {
        $isConnected.eraseToAnyPublisher()
    }
    
    var metricsPublisher: AnyPublisher<WorkoutMetrics?, Never> {
        $currentMetrics.eraseToAnyPublisher()
    }
    
    private let api = OuraRingAPI.shared
    private var metricsTimer: Timer?
    
    override init() {
        super.init()
    }
    
    static func isAvailable() -> Bool {
        // Check if Oura API credentials are configured
        return OuraRingAPI.shared.hasCredentials()
    }
    
    // MARK: - FitnessDeviceProtocol
    
    func connect() async throws {
        guard OuraRingAPI.shared.hasCredentials() else {
            throw DeviceError.authenticationRequired
        }
        
        // Authenticate with Oura API
        try await api.authenticate()
        isConnected = true
    }
    
    func disconnect() {
        isConnected = false
        stopMetricsStream()
    }
    
    func isAvailable() -> Bool {
        return OuraRingAPI.shared.hasCredentials()
    }
    
    func startMetricsStream() async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        // Start periodic API requests
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
        case .heartRate, .calories:
            return true
        default:
            return false
        }
    }
    
    func getQualityScore(for metric: MetricType) -> Double {
        switch metric {
        case .heartRate:
            return 0.92 // Oura ring has good heart rate accuracy
        case .calories:
            return 0.88
        default:
            return 0.0
        }
    }
    
    // MARK: - Metrics Fetching
    
    private func fetchMetrics() async {
        do {
            let metrics = try await api.getCurrentMetrics()
            DispatchQueue.main.async {
                self.currentMetrics = metrics
            }
        } catch {
            print("❌ [OuraRingDevice] Error fetching metrics: \(error.localizedDescription)")
        }
    }
}

