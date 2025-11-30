//
//  DeviceSettingsManager.swift
//  Do
//
//  Device enable/disable controls and settings
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import Combine

class DeviceSettingsManager: ObservableObject {
    static let shared = DeviceSettingsManager()
    
    @Published var deviceSettings: [String: DeviceSettings] = [:]
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "fitnessDeviceSettings"
    
    private init() {
        loadSettings()
    }
    
    // MARK: - Settings Management
    
    func getSettings(for deviceId: String) -> DeviceSettings {
        if let settings = deviceSettings[deviceId] {
            return settings
        }
        
        // Create default settings
        let defaultSettings = DeviceSettings(deviceId: deviceId)
        deviceSettings[deviceId] = defaultSettings
        return defaultSettings
    }
    
    func updateSettings(_ settings: DeviceSettings) {
        deviceSettings[settings.deviceId] = settings
        saveSettings()
    }
    
    func enableDevice(_ deviceId: String) {
        var settings = getSettings(for: deviceId)
        settings.isEnabled = true
        updateSettings(settings)
        ExternalDeviceManager.shared.enableDevice(deviceId)
    }
    
    func disableDevice(_ deviceId: String) {
        var settings = getSettings(for: deviceId)
        settings.isEnabled = false
        updateSettings(settings)
        ExternalDeviceManager.shared.disableDevice(deviceId)
    }
    
    // MARK: - Persistence
    
    private func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode([String: DeviceSettings].self, from: data) {
            deviceSettings = decoded
        }
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(deviceSettings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
    }
}

struct DeviceSettings: Codable {
    var deviceId: String
    var isEnabled: Bool
    var priority: Int // Higher number = higher priority
    var autoConnect: Bool
    var preferredForMetrics: [MetricType: Bool] // Which metrics to prefer this device for
    
    init(deviceId: String, isEnabled: Bool = true, priority: Int = 0, autoConnect: Bool = true, preferredForMetrics: [MetricType: Bool] = [:]) {
        self.deviceId = deviceId
        self.isEnabled = isEnabled
        self.priority = priority
        self.autoConnect = autoConnect
        self.preferredForMetrics = preferredForMetrics
    }
}

