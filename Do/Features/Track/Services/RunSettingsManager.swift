//
//  RunSettingsManager.swift
//  Do
//
//  Manager for run/workout settings
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import Combine

/// Announcement frequency options
enum AnnouncementFrequency: String, Codable {
    case off = "off"
    case kilometer = "kilometer"
    case mile = "mile"
    case twoKilometers = "twoKilometers"
    case fiveMinutes = "fiveMinutes"
    case tenMinutes = "tenMinutes"
}

/// Run settings structure
struct RunSettings: Codable {
    var announceIntervals: Bool = true
    var playAudioCues: Bool = true
    var autoLockScreen: Bool = false
    var announcementFrequency: AnnouncementFrequency = .kilometer
    var screenAlwaysOn: Bool = true
    var showHeatMap: Bool = true
    var trackElevation: Bool = true
    var recordHeartRate: Bool = true
    var vibrateOnMilestones: Bool = true
}

/// Manager for run/workout settings
class RunSettingsManager: ObservableObject {
    static let shared = RunSettingsManager()
    
    @Published var currentSettings: RunSettings
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "runSettings"
    
    private init() {
        // Load settings from UserDefaults or use defaults
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(RunSettings.self, from: data) {
            currentSettings = decoded
        } else {
            currentSettings = RunSettings()
        }
    }
    
    /// Update and save settings
    func updateSettings(_ settings: RunSettings) {
        currentSettings = settings
        saveSettings()
    }
    
  
}



