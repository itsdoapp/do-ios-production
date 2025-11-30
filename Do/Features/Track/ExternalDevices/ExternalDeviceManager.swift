//
//  ExternalDeviceManager.swift
//  Do
//
//  Registry and management of all available device modules
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import Combine

class ExternalDeviceManager: ObservableObject {
    static let shared = ExternalDeviceManager()
    
    @Published var availableDevices: [FitnessDeviceProtocol] = []
    @Published var connectedDevices: [FitnessDeviceProtocol] = []
    @Published var enabledDevices: Set<String> = []
    
    private var deviceRegistry: [DeviceType: FitnessDeviceProtocol] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        registerDefaultDevices()
        startDeviceDiscovery()
    }
    
    // MARK: - Device Registration
    
    private func registerDefaultDevices() {
        // Register Apple Watch
        let appleWatch = AppleWatchDevice()
        registerDevice(appleWatch)
        
        // Register HealthKit Generic
        let healthKitGeneric = HealthKitGenericDevice()
        registerDevice(healthKitGeneric)
        
        // Register Oura Ring (if available)
        if OuraRingDevice.isAvailable() {
            let ouraRing = OuraRingDevice()
            registerDevice(ouraRing)
        }
        
        // Register Garmin (if available)
        if GarminDevice.isAvailable() {
            let garmin = GarminDevice()
            registerDevice(garmin)
        }
        
        // Register Fitbit (if available)
        if FitbitDevice.isAvailable() {
            let fitbit = FitbitDevice()
            registerDevice(fitbit)
        }
    }
    
    func registerDevice(_ device: FitnessDeviceProtocol) {
        deviceRegistry[device.deviceType] = device
        availableDevices.append(device)
        
        // Subscribe to connection status
        device.connectionStatusPublisher
            .sink { [weak self] isConnected in
                self?.updateConnectedDevices()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Device Discovery
    
    private func startDeviceDiscovery() {
        // Periodically check for new devices
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.discoverDevices()
        }
    }
    
    private func discoverDevices() {
        // Check for newly available devices
        for device in availableDevices {
            if device.isAvailable() && !device.isConnected && enabledDevices.contains(device.deviceId) {
                Task {
                    try? await device.connect()
                }
            }
        }
    }
    
    // MARK: - Device Management
    
    func enableDevice(_ deviceId: String) {
        enabledDevices.insert(deviceId)
        if let device = availableDevices.first(where: { $0.deviceId == deviceId }) {
            Task {
                try? await device.connect()
            }
        }
    }
    
    func disableDevice(_ deviceId: String) {
        enabledDevices.remove(deviceId)
        if let device = connectedDevices.first(where: { $0.deviceId == deviceId }) {
            device.disconnect()
        }
    }
    
    private func updateConnectedDevices() {
        connectedDevices = availableDevices.filter { $0.isConnected }
    }
    
    // MARK: - Device Capability Detection
    
    func getDeviceForMetric(_ metric: MetricType, workoutType: WorkoutType, isIndoor: Bool) -> FitnessDeviceProtocol? {
        let coordinationEngine = DeviceCoordinationEngine.shared
        let preferredSource = coordinationEngine.determinePrimaryDevice(
            for: metric,
            workoutType: workoutType,
            isIndoor: isIndoor
        )
        
        // Find device matching preferred source
        for device in connectedDevices {
            if device.deviceType.rawValue == preferredSource.rawValue {
                return device
            }
        }
        
        // Fallback to any device that supports the metric
        return connectedDevices.first { $0.supportsMetric(metric) }
    }
    
    // MARK: - Device Priority/Quality Scoring
    
    func getDevicePriority(_ device: FitnessDeviceProtocol, for metric: MetricType) -> Double {
        let baseScore = device.getQualityScore(for: metric)
        
        // Adjust based on connection status
        let connectionBonus = device.isConnected ? 0.1 : -0.3
        
        // Adjust based on whether device is enabled
        let enabledBonus = enabledDevices.contains(device.deviceId) ? 0.1 : -0.2
        
        return min(1.0, max(0.0, baseScore + connectionBonus + enabledBonus))
    }
    
    // MARK: - All Metrics Collection
    
    func getAllMetrics() -> [MetricsWithSource] {
        return connectedDevices.compactMap { device in
            guard let metrics = device.currentMetrics else { return nil }
            return MetricsWithSource(
                metrics: metrics,
                source: MetricsSource(rawValue: device.deviceType.rawValue) ?? .phone,
                accuracy: device.getQualityScore(for: .distance)
            )
        }
    }
}

