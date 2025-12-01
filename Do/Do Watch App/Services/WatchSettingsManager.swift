//
//  WatchSettingsManager.swift
//  Do Watch App
//
//  Manages user preferences and settings on the watch
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import Combine
import WatchConnectivity

class WatchSettingsManager: ObservableObject {
    static let shared = WatchSettingsManager()
    
    @Published var useMetric: Bool {
        didSet {
            UserDefaults.standard.set(useMetric, forKey: "useMetric")
            // Only sync back if it changed locally and we are the source of truth
            // To avoid loops, we might need a flag, but for now simple deduping on receiver is okay.
            sendUnitPreferencesToPhone(useMetric: useMetric)
        }
    }
    
    @Published var voiceCuesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(voiceCuesEnabled, forKey: "voiceCuesEnabled")
        }
    }
    
    private init() {
        // Default to locale-based if not set in UserDefaults
        let isUSLocale = Locale.current.identifier.contains("US")
        let defaultMetric = !isUSLocale
        
        self.useMetric = UserDefaults.standard.object(forKey: "useMetric") as? Bool ?? defaultMetric
        self.voiceCuesEnabled = UserDefaults.standard.object(forKey: "voiceCuesEnabled") as? Bool ?? true
    }
    
    func updateUnitPreferences(useMetric: Bool) {
        DispatchQueue.main.async {
            // Check if value is actually different to avoid unnecessary writes/loops
            if self.useMetric != useMetric {
                self.useMetric = useMetric
                print("⚙️ [WatchSettingsManager] Updated unit preference from phone: \(useMetric ? "Metric" : "Imperial")")
            }
        }
    }
    
    func updateVoiceCues(enabled: Bool) {
        DispatchQueue.main.async {
            self.voiceCuesEnabled = enabled
        }
    }
    
    private func sendUnitPreferencesToPhone(useMetric: Bool) {
        guard WCSession.default.activationState == .activated else { return }
        
        let message: [String: Any] = [
            "type": "unitPreferences",
            "useMetric": useMetric,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("❌ [WatchSettingsManager] Error sending prefs to phone: \(error.localizedDescription)")
            }
        } else {
            do {
                try WCSession.default.updateApplicationContext(message)
            } catch {
                print("❌ [WatchSettingsManager] Error updating context: \(error.localizedDescription)")
            }
        }
    }
}
