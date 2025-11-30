//
//  FitnessDeviceProtocol.swift
//  Do
//
//  Common interface for all device integrations
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import Combine

/// Protocol that all fitness devices must implement
protocol FitnessDeviceProtocol: ObservableObject {
    /// Unique device identifier
    var deviceId: String { get }
    
    /// Device type/name
    var deviceName: String { get }
    
    /// Device type enum
    var deviceType: DeviceType { get }
    
    /// Connection status
    var isConnected: Bool { get }
    
    /// Device capabilities
    var capabilities: DeviceCapabilities { get }
    
    /// Current metrics from device
    var currentMetrics: WorkoutMetrics? { get }
    
    /// Connection status publisher
    var connectionStatusPublisher: AnyPublisher<Bool, Never> { get }
    
    /// Metrics publisher
    var metricsPublisher: AnyPublisher<WorkoutMetrics?, Never> { get }
    
    // MARK: - Connection Management
    
    /// Connect to device
    func connect() async throws
    
    /// Disconnect from device
    func disconnect()
    
    /// Check if device is available
    func isAvailable() -> Bool
    
    // MARK: - Data Streaming
    
    /// Start receiving metrics from device
    func startMetricsStream() async throws
    
    /// Stop receiving metrics from device
    func stopMetricsStream()
    
    // MARK: - Capability Queries
    
    /// Check if device supports a specific metric
    func supportsMetric(_ metric: MetricType) -> Bool
    
    /// Get device quality score (0.0 to 1.0)
    func getQualityScore(for metric: MetricType) -> Double
}

enum DeviceType: String, Codable {
    case appleWatch = "appleWatch"
    case ouraRing = "ouraRing"
    case garmin = "garmin"
    case fitbit = "fitbit"
    case healthKitGeneric = "healthKitGeneric"
    case phone = "phone"
}

struct DeviceCapabilities {
    var supportsGPS: Bool
    var supportsHeartRate: Bool
    var supportsCadence: Bool
    var supportsElevation: Bool
    var supportsCalories: Bool
    var supportsDistance: Bool
    var supportsPace: Bool
    
    init(supportsGPS: Bool = false,
         supportsHeartRate: Bool = false,
         supportsCadence: Bool = false,
         supportsElevation: Bool = false,
         supportsCalories: Bool = false,
         supportsDistance: Bool = false,
         supportsPace: Bool = false) {
        self.supportsGPS = supportsGPS
        self.supportsHeartRate = supportsHeartRate
        self.supportsCadence = supportsCadence
        self.supportsElevation = supportsElevation
        self.supportsCalories = supportsCalories
        self.supportsDistance = supportsDistance
        self.supportsPace = supportsPace
    }
}

