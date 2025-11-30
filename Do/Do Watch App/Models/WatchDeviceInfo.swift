//
//  WatchDeviceInfo.swift
//  Do Watch App
//
//  Device capability detection
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import HealthKit
import CoreLocation

struct WatchDeviceInfo {
    let deviceType: DeviceType
    let capabilities: DeviceCapabilities
    let isAvailable: Bool
    let connectionStatus: ConnectionStatus
    
    enum DeviceType: String, Codable {
        case appleWatch = "appleWatch"
        case ouraRing = "ouraRing"
        case garmin = "garmin"
        case fitbit = "fitbit"
        case healthKitGeneric = "healthKitGeneric"
        case phone = "phone"
    }
    
    enum ConnectionStatus: String, Codable {
        case connected = "connected"
        case disconnected = "disconnected"
        case connecting = "connecting"
        case unavailable = "unavailable"
    }
    
    struct DeviceCapabilities: Codable {
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
    
    static func detectAppleWatchCapabilities() -> DeviceCapabilities {
        return DeviceCapabilities(
            supportsGPS: CLLocationManager.locationServicesEnabled(),
            supportsHeartRate: HKHealthStore.isHealthDataAvailable(),
            supportsCadence: true, // Apple Watch supports cadence
            supportsElevation: CLLocationManager.locationServicesEnabled(),
            supportsCalories: HKHealthStore.isHealthDataAvailable(),
            supportsDistance: true,
            supportsPace: true
        )
    }
    
    static func createAppleWatchInfo() -> WatchDeviceInfo {
        return WatchDeviceInfo(
            deviceType: .appleWatch,
            capabilities: detectAppleWatchCapabilities(),
            isAvailable: HKHealthStore.isHealthDataAvailable() && CLLocationManager.locationServicesEnabled(),
            connectionStatus: .connected
        )
    }
}

