//
//  UserPreferences.swift
//  Do
//
//  User preferences service for Genie compatibility
//

import Foundation
import Combine
import AVFoundation
import WatchConnectivity

class UserPreferences: ObservableObject {
    static let shared = UserPreferences()
    
    enum VoiceType: String, CaseIterable, Codable {
        case female
        case male
        
        var displayName: String {
            switch self {
            case .female: return "Female"
            case .male: return "Male"
            }
        }
        
        /// Returns the best available voice for this type (male or female)
        var bestAvailableVoice: AVSpeechSynthesisVoice? {
            let voices = AVSpeechSynthesisVoice.speechVoices()
            
            // Filter voices by gender preference
            let preferredVoices = voices.filter { voice in
                let identifier = voice.identifier.lowercased()
                let name = voice.name.lowercased()
                
                switch self {
                case .female:
                    // Look for female voices
                    return identifier.contains("female") ||
                           identifier.contains("samantha") ||
                           identifier.contains("karen") ||
                           identifier.contains("kate") ||
                           identifier.contains("susan") ||
                           identifier.contains("victoria") ||
                           name.contains("female") ||
                           name.contains("samantha") ||
                           name.contains("karen") ||
                           name.contains("kate") ||
                           name.contains("susan") ||
                           name.contains("victoria")
                case .male:
                    // Look for male voices
                    return identifier.contains("male") ||
                           identifier.contains("alex") ||
                           identifier.contains("daniel") ||
                           identifier.contains("fred") ||
                           identifier.contains("ralph") ||
                           identifier.contains("tom") ||
                           name.contains("male") ||
                           name.contains("alex") ||
                           name.contains("daniel") ||
                           name.contains("fred") ||
                           name.contains("ralph") ||
                           name.contains("tom")
                }
            }
            
            // Prefer enhanced quality voices
            if let enhanced = preferredVoices.first(where: { $0.quality == .enhanced }) {
                return enhanced
            }
            
            // Fallback to any preferred voice
            if let anyVoice = preferredVoices.first {
                return anyVoice
            }
            
            // Final fallback: use default system voice
            return AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice.speechVoices().first
        }
    }
    
    @Published var useMetricSystem: Bool {
        didSet {
            UserDefaults.standard.set(useMetricSystem, forKey: "useMetricSystem")
            syncToWatch()
            syncToBackend()
        }
    }
    
    @Published var preferredVoiceType: VoiceType {
        didSet {
            UserDefaults.standard.set(preferredVoiceType.rawValue, forKey: "preferredVoiceType")
        }
    }
    
    // Computed property for compatibility with GenieAPIService
    var useImperialUnits: Bool {
        return !useMetricSystem
    }
    
    /// Format distance in meters according to user's unit preference
    /// - Parameter meters: Distance in meters
    /// - Returns: Formatted distance string (e.g., "5.2 km" or "3.2 mi")
    func formatDistance(_ meters: Double) -> String {
        if useMetricSystem {
            if meters >= 1000 {
                return String(format: "%.2f km", meters / 1000.0)
            } else {
                return String(format: "%.0f m", meters)
            }
        } else {
            let miles = meters / 1609.34
            return String(format: "%.2f mi", miles)
        }
    }
    
    /// Format elevation in meters according to user's unit preference
    /// - Parameter elevation: Elevation in meters
    /// - Returns: Formatted elevation string (e.g., "150 m" or "492 ft")
    static func formatElevationWithPreferredUnit(elevation: Double) -> String {
        let useMetric = UserPreferences.shared.useMetricSystem
        if useMetric {
            return String(format: "%.0f m", elevation)
        } else {
            let feet = elevation * 3.28084
            return String(format: "%.0f ft", feet)
        }
    }
    
    /// Format pace in seconds per meter according to user's unit preference
    /// - Parameter secondsPerMeter: Pace in seconds per meter
    /// - Returns: Formatted pace string (e.g., "5:30 /km" or "8:51 /mi")
    func formatPace(_ secondsPerMeter: Double) -> String {
        // Check if pace is valid
        guard secondsPerMeter > 0 && secondsPerMeter.isFinite else {
            return "--"
        }
        
        let useMetric = self.useMetricSystem
        
        // Convert seconds per meter to seconds per km or seconds per mile
        let paceInDisplayUnits: Double
        if useMetric {
            // Convert to seconds per km
            paceInDisplayUnits = secondsPerMeter * 1000.0
        } else {
            // Convert to seconds per mile
            paceInDisplayUnits = secondsPerMeter * 1609.34
        }
        
        // Format as minutes:seconds
        let minutes = Int(paceInDisplayUnits / 60)
        let seconds = Int(paceInDisplayUnits.truncatingRemainder(dividingBy: 60))
        
        let unit = useMetric ? "/km" : "/mi"
        return String(format: "%d:%02d %@", minutes, seconds, unit)
    }
    
    private init() {
        // Load from UserDefaults, default to metric (false = metric, true = imperial)
        // Check locale to determine default
        let isUSLocale = Locale.current.identifier.contains("US")
        self.useMetricSystem = UserDefaults.standard.object(forKey: "useMetricSystem") as? Bool ?? !isUSLocale
        
        if let storedVoice = UserDefaults.standard.string(forKey: "preferredVoiceType"),
           let type = VoiceType(rawValue: storedVoice) {
            self.preferredVoiceType = type
        } else {
            self.preferredVoiceType = .female
        }
    }
    
    // MARK: - Syncing
    
    func updateFromWatch(useMetric: Bool) {
        DispatchQueue.main.async {
            // Avoid loops
            if self.useMetricSystem != useMetric {
                self.useMetricSystem = useMetric
                print("📱 [UserPreferences] Updated from watch: \(useMetric ? "Metric" : "Imperial")")
            }
        }
    }
    
    private func syncToWatch() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        
        let message: [String: Any] = [
            "type": "unitPreferences",
            "useMetric": useMetricSystem
        ]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("❌ [UserPreferences] Error sending to watch: \(error.localizedDescription)")
            }
        } else {
            do {
                try session.updateApplicationContext(message)
            } catch {
                print("❌ [UserPreferences] Error updating context: \(error.localizedDescription)")
            }
        }
    }
    
    private func syncToBackend() {
        // Use UserIDResolver for consistent ID resolution
        guard let userId = UserIDResolver.shared.getBestUserIdForAPI() else {
            print("⚠️ [UserPreferences] No user ID available, skipping backend sync")
            return
        }
        
        Task {
            do {
                print("💾 [UserPreferences] Syncing unit preference to backend: \(useMetricSystem ? "metric" : "imperial")")
                
                // Sync logic to backend
                let fields: [String: Any] = [
                    "units": useMetricSystem ? "metric" : "imperial"
                ]
                
                let _ = try await ProfileAPIService.shared.updateUserProfile(
                    userId: userId,
                    fields: fields
                )
                print("✅ [UserPreferences] Successfully synced unit preference to backend")
            } catch {
                print("❌ [UserPreferences] Failed to sync to backend: \(error)")
            }
        }
    }
}
