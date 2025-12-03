//
//  HikeTrackingEngine.swift
//  Do.
//
//  Created by Mikiyas Meseret on 3/12/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import CoreLocation
import HealthKit
// Parse removed - using AWS only
import Combine
import AVFoundation
import WatchConnectivity
import UIKit
import CoreMotion
import SwiftUI
import WeatherKit
import MapKit
import SceneKit
import Dispatch

// Notification names for hiking
extension Notification.Name {
    static let didChangeHikeState = Notification.Name("HikeStateDidChange")
    static let didUpdateHikeState = Notification.Name("HikeStateDidUpdate")
    static let didUpdateHikeMetrics = Notification.Name("DidUpdateHikeMetrics")
}

// Constants for caching
private struct HikeCacheKeys {
    static let recentPaces = "recentHikePaces"
    static let emergencyBackup = "emergencyHikeBackup"
    static let maxRecentPaces = 10
}

// HikeSplitTime - separate type for hiking to avoid conflict with TrackingModels.SplitTime
// This uses Measurement types which are more appropriate for hiking metrics
struct HikeSplitTime: Identifiable {
    var id = UUID()
    var distance: Measurement<UnitLength>
    var time: TimeInterval
    var pace: Measurement<UnitSpeed>
}

class HikeTrackingEngine: NSObject, ObservableObject, WCSessionDelegate, WorkoutEngineProtocol {
    static let shared = HikeTrackingEngine()
    
    // MARK: - Delegate Protocol
    protocol HikeTrackingEngineDelegate: AnyObject {
        func hikeTrackingEngineDidUpdateState(_ engine: HikeTrackingEngine)
    }
    weak var delegate: HikeTrackingEngineDelegate?
    
    internal var workoutId = UUID()
    public var watchHasAcknowledgedJoin = false
    
    @Published var hikeState: HikeState = .notStarted {
        didSet {
            updateFormattedValues()
            print("📱 Updated hikeState: \(oldValue) => \(hikeState)")
            NotificationCenter.default.post(name: .didUpdateHikeState, object: nil)
        }
    }
    @Published var hikeType: HikeType = .trail {
        didSet {
            updateHikeType(hikeType)
        }
    }
    @Published var targetDistance: Measurement<UnitLength>?
    public var isJoiningExistingWorkout: Bool = false
    
    // Tracking metrics
    @Published var distance: Measurement<UnitLength> = Measurement(value: 0, unit: UnitLength.meters)
    @Published var elapsedTime: TimeInterval = 0
    @Published var pace: Measurement<UnitSpeed> = Measurement(value: 0, unit: UnitSpeed.minutesPerKilometer)
    @Published var currentPace = Measurement(value: 0, unit: UnitSpeed.minutesPerKilometer)
    private var smoothedPace: Measurement<UnitSpeed>?
    private var lastPaceUpdate: TimeInterval = 0
    @Published var calories: Double = 0
    @Published var heartRate: Double = 0
    @Published var elevationGain: Measurement<UnitLength> = Measurement(value: 0, unit: UnitLength.meters)
    @Published var elevationLoss: Measurement<UnitLength> = Measurement(value: 0, unit: UnitLength.meters)
    @Published var cadence: Double = 0
    @Published var strideLength: Measurement<UnitLength> = Measurement(value: 0, unit: UnitLength.meters)
    @Published var verticalOscillation: Measurement<UnitLength> = Measurement(value: 0, unit: UnitLength.centimeters)
    @Published var groundContactTime: TimeInterval = 0
    @Published var heartRateZone: HeartRateZoneType = .none
    @Published var performanceIndex: Double = 0
    @Published var environmentalConditions: EnvironmentalConditions = EnvironmentalConditions()
    @Published var paceHistory: [Double] = []
    @Published var splitTimes: [HikeSplitTime] = []
    private var recentPaceValues: [Double] = []
    private let maxPaceHistoryCount = 5
    
    // Formatted display values
    @Published var formattedDistance: String = "0.00"
    @Published var formattedTime: String = "00:00:00"
    @Published var formattedPace: String = "-'--\""
    @Published var formattedCalories: String = "0"
    @Published var formattedHeartRate: String = "--"
    @Published var formattedElevationGain: String = "0 ft"
    @Published var formattedElevationLoss: String = "0 ft"
    @Published var formattedCadence: String = "-- spm"
    @Published var formattedStrideLength: String = "-- m"
    @Published var distanceUnit: String = "km"
    @Published var coachFeedback: String?
    @Published var formFeedback: FormFeedback?
    @Published var hikingEfficiency: Double = 0
    @Published var aiAnalysisResults: AIAnalysisResults = AIAnalysisResults()
    @Published var isScreenLocked: Bool = false
    @Published var locationList: [LocationData] = []
    @Published var routeAnnotations: [RouteAnnotation] = []
    @Published var useMetric: Bool = false
    @Published var isWatchTracking: Bool = false
    @Published var isIndoorMode: Bool = false
    @Published var hasGoodLocationData: Bool = true
    @Published var isAutoCenter: Bool = true
    @Published var navigationAudioMuted: Bool = false
    
    // Device coordination properties
    @Published var isPrimaryForDistance: Bool = true
    @Published var isPrimaryForPace: Bool = true
    @Published var isPrimaryForHeartRate: Bool = false // Watch is always primary for HR
    @Published var isPrimaryForCalories: Bool = true
    @Published var isPrimaryForCadence: Bool = false // Watch is better for cadence
    @Published var isDashboardMode: Bool = false
    @Published var recentPersonalRecords: [PersonalRecord] = []
    private var isHandlingRemoteStateChange = false
    // Track actual workout start time for replies and persistence
    private var startDate: Date?
    private var cancellables = Set<AnyCancellable>()
    
    // Weather and environment
    struct WeatherData: Identifiable {
        var id = UUID()
        let temperature: Double
        let condition: String
        let windSpeed: Double
        let humidity: Double
        let icon: String
        var airQuality: Int? = nil
        var feelsLike: Double? = nil
        var uvIndex: Double? = nil
        var formattedTemperature: String { String(format: "%.1f°C", temperature) }
        var formattedWindSpeed: String { String(format: "%.1f m/s", windSpeed) }
        var formattedHumidity: String { String(format: "%.0f%%", humidity) }
        var weatherCondition: WeatherCondition { WeatherCondition.determineCondition(from: condition) }
    }
    enum WeatherCondition: String {
        case clear = "Clear"
        case cloudy = "Cloudy"
        case partlyCloudy = "Partly Cloudy"
        case rainy = "Rainy"
        case snowy = "Snowy"
        case stormy = "Stormy"
        case foggy = "Foggy"
        case windy = "Windy"
        case unknown = "Unknown"
        var displayName: String { rawValue }
        var icon: String {
            switch self {
            case .clear: return "sun.max.fill"
            case .cloudy: return "cloud.fill"
            case .partlyCloudy: return "cloud.sun.fill"
            case .rainy: return "cloud.rain.fill"
            case .snowy: return "cloud.snow.fill"
            case .stormy: return "cloud.bolt.fill"
            case .foggy: return "cloud.fog.fill"
            case .windy: return "wind"
            case .unknown: return "exclamationmark.triangle"
            }
        }
        static func determineCondition(from description: String) -> WeatherCondition {
            let lowercaseDesc = description.lowercased()
            if lowercaseDesc.contains("clear") || lowercaseDesc.contains("sunny") {
                return .clear
            } else if lowercaseDesc.contains("cloud") {
                if lowercaseDesc.contains("partly") || lowercaseDesc.contains("scattered") {
                    return .partlyCloudy
                } else {
                    return .cloudy
                }
            } else if lowercaseDesc.contains("rain") || lowercaseDesc.contains("drizzle") || lowercaseDesc.contains("shower") {
                return .rainy
            } else if lowercaseDesc.contains("snow") || lowercaseDesc.contains("sleet") || lowercaseDesc.contains("hail") {
                return .snowy
            } else if lowercaseDesc.contains("thunder") || lowercaseDesc.contains("storm") || lowercaseDesc.contains("lightning") {
                return .stormy
            } else if lowercaseDesc.contains("fog") || lowercaseDesc.contains("mist") || lowercaseDesc.contains("haze") {
                return .foggy
            } else if lowercaseDesc.contains("wind") || lowercaseDesc.contains("gust") {
                return .windy
            } else {
                return .unknown
            }
        }
    }
    @Published var currentWeather: WeatherData?
    public var currentUser: String?

    // MARK: - Import existing workout from watch (for Join flow)
    public func importWorkoutFromWatch(
        isIndoorMode: Bool,
        distance: Measurement<UnitLength>,
        elapsedTime: TimeInterval,
        heartRate: Double,
        calories: Double,
        cadence: Double,
        rawData: [String: Any],
        startDate: Date? = nil
    ) {
        // Mark joining state so downstream UI logic can adapt
        self.isJoiningExistingWorkout = true
        self.isWatchTracking = true
        self.isIndoorMode = isIndoorMode

        // Apply provided start date, else best-effort compute from elapsed + pauseDuration
        if let actualStart = startDate {
            self.startDate = actualStart
        } else {
            let pauseDuration = rawData["pauseDuration"] as? TimeInterval ?? 0
            let total = elapsedTime + pauseDuration
            self.startDate = Date().addingTimeInterval(-total)
        }

        // Metrics
        self.distance = distance
        self.elapsedTime = elapsedTime
        self.heartRate = heartRate
        self.calories = calories
        self.cadence = cadence

        // Update formatted values and notify observers
        updateFormattedValues()
        objectWillChange.send()
    }

    func setCurrentUser(_ user: String?) {
        self.currentUser = user
    }

    func setupBackgroundCapabilities() {
        ModernLocationManager.shared.startUpdatingLocation()
    }

    private func updateHikeType(_ type: HikeType) {
        // Handle hike type changes if needed
        print("Hike type changed to: \(type.rawValue)")
    }

    private func updateFormattedValues() {
        // Update all formatted string values for display
        // (You can implement formatting logic here as needed)
    }

    // MARK: - Basic state control (parity with Run engine entry points)
    func resume() {
        if hikeState == .notStarted || hikeState == .ready || hikeState == .paused {
            // If this is the first transition into inProgress, set startDate
            if startDate == nil { startDate = Date() }
            hikeState = .inProgress
            WorkoutBackgroundManager.shared.registerWorkout(type: "hike", engine: self)
            if hikeState == .notStarted {
                LockScreenManager.shared.startWorkout(type: "hike")
                
                // Start smart handoff monitoring when hike actually starts
                SmartHandoffCoordinator.shared.startMonitoring(workoutType: .hiking)
            }
            updateLockScreen()
            
            // Establish device coordination when hike starts
            establishDeviceCoordination()
            
            // Notify watch of resume
            let ts = Date().timeIntervalSince1970
            sendMessageToWatch(["type": "hikeResume", "timestamp": ts])
            sendMessageToWatch(["type": "resumeWorkout", "workoutType": "hike", "timestamp": ts])
        }
    }

    func pause() {
        if hikeState == .inProgress {
            hikeState = .paused
            updateLockScreen()
            // Notify watch of pause
            let ts = Date().timeIntervalSince1970
            sendMessageToWatch(["type": "hikePause", "timestamp": ts])
            sendMessageToWatch(["type": "pauseWorkout", "workoutType": "hike", "timestamp": ts])
        }
    }

    func stop() {
        if hikeState.isActive {
            hikeState = .completed
            
            // Save hike data to AWS
            saveHikeToParse()
            
            // Clear start date after completion
            // (Keep it until after any persistence if needed)
            WorkoutBackgroundManager.shared.unregisterWorkout(type: "hike")
            LockScreenManager.shared.stopWorkout()
            startDate = nil
            // Notify watch of end
            let ts = Date().timeIntervalSince1970
            sendMessageToWatch(["type": "hikeStop", "timestamp": ts])
            sendMessageToWatch(["type": "endWorkout", "workoutType": "hike", "timestamp": ts])
            
            // Stop smart handoff monitoring
            SmartHandoffCoordinator.shared.stopMonitoring()
        }
    }
    
    private func updateLockScreen() {
        let metrics = WorkoutMetrics(
            distance: useMetric ? distance.value / 1609.34 : distance.value / 1609.34, // Convert to miles
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            pace: pace.value,
            calories: calories,
            elevationGain: elevationGain.value
        )
        LockScreenManager.shared.updateLockScreen(metrics: metrics)
    }
    
    // MARK: - State Recovery
    
    func checkForRecovery() -> Bool {
        guard let cache = WorkoutBackgroundManager.shared.loadStateCache(),
              cache.type == "hike",
              let recoveryState = HikeState(rawValue: cache.state),
              recoveryState.isActive else {
            return false
        }
        return true
    }
    
    func recoverFromCache() -> Bool {
        guard let cache = WorkoutBackgroundManager.shared.loadStateCache(),
              cache.type == "hike",
              let recoveryState = HikeState(rawValue: cache.state),
              recoveryState.isActive else {
            return false
        }
        
        // Restore state and metrics
        hikeState = recoveryState
        distance = Measurement(value: cache.distance, unit: .meters)
        elapsedTime = cache.duration
        
        // Restore locations
        locationList = cache.locations.map { locData in
            LocationData(
                latitude: locData["lat"] ?? 0,
                longitude: locData["lon"] ?? 0,
                altitude: locData["alt"] ?? 0,
                horizontalAccuracy: 0,
                verticalAccuracy: 0,
                course: locData["course"] ?? 0,
                speed: locData["speed"] ?? 0,
                distance: 0 // Will be recalculated on next location update
            )
        }
        
        // Clear the cache after successful recovery
        WorkoutBackgroundManager.shared.clearStateCache()
        
        // Resume if we were in progress
        if hikeState == .inProgress {
            WorkoutBackgroundManager.shared.registerWorkout(type: "hike", engine: self)
        }
        
        return true
    }

    // MARK: - Controller compatibility API (mirror run engine names used in controllers)
    func startRun(hikeType: HikeType) {
        // Map shared RunType to our hike type if needed; keep for watch comms parity
        self.hikeType = hikeType
        self.hikeState = .inProgress
        
        // Establish device coordination when hike starts
        establishDeviceCoordination()
    }
    func pauseRun() { pause() }
    func resumeRun() { resume() }
    func endRun() { stop() }

    // Incremental state helpers used by controllers
    func restoreIncrementalState() -> Bool { return false }
    func saveIncremental() {}
    func ensureTimerIsRunning() -> Bool { return false }

    // Watch sync helpers expected by controllers
    func catchUpDistanceWithWatch() {}
    func evaluatePrimarySource() {}
    func handleWatchCommunicationError(_ error: Error? = nil) {
        if let error { print("HikeTrackingEngine watch comms error: \(error.localizedDescription)") }
    }

    // Metrics update helpers expected by controllers
    func updateDistanceFromWatch(_ meters: Double) {
        distance = Measurement(value: meters, unit: .meters)
    }
    func updateCalories(_ kcal: Double) { calories = kcal }
    func updateHeartRate(_ bpm: Double) { heartRate = bpm }
    func updateCadence(_ spm: Double) { cadence = spm }

    // Location processing - LocationData is now defined in TrackingModels.swift
    func processLocationUpdate(_ location: CLLocation) {
        // Calculate distance from previous location if available
        if !locationList.isEmpty {
            let lastLocation = CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: locationList.last!.latitude,
                    longitude: locationList.last!.longitude
                ),
                altitude: locationList.last!.altitude,
                horizontalAccuracy: locationList.last!.horizontalAccuracy,
                verticalAccuracy: locationList.last!.verticalAccuracy,
                course: locationList.last!.course,
                speed: locationList.last!.speed,
                timestamp: locationList.last!.timestamp
            )
            
            let newDistance = location.distance(from: lastLocation)
            
            // Only add distance if accuracy is good and speed is reasonable
            if location.horizontalAccuracy <= 20 && location.speed >= 0 {
                let currentValue = distance.value
                distance = Measurement(value: currentValue + newDistance, unit: .meters)
                
                // Update elevation if accuracy is good
                if location.verticalAccuracy <= 10 {
                    let elevationDelta = location.altitude - lastLocation.altitude
                    if elevationDelta > 0 {
                        elevationGain = Measurement(value: elevationGain.value + elevationDelta, unit: .meters)
                    } else {
                        elevationLoss = Measurement(value: elevationLoss.value - elevationDelta, unit: .meters)
                    }
                }
                
                // Calculate pace if we have enough data
                if elapsedTime > 0 {
                    let speedInMetersPerSecond = distance.value / elapsedTime
                    if speedInMetersPerSecond > 0 {
                        let paceInMinutesPerKm = 1000.0 / (speedInMetersPerSecond * 60.0)
                        pace = Measurement(value: paceInMinutesPerKm, unit: .minutesPerKilometer)
                    }
                }
                
                updateFormattedValues()
            }
        }
        
        locationList.append(LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            course: location.course,
            speed: location.speed,
            distance: distance.value
        ))
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .didUpdateHikeMetrics, object: nil)
    }

    // Log generation stub
    func generateHikeLog() -> HikeLog? { return nil }
    
    // Unit helpers expected by UI
    func getElevationUnitString() -> String { return useMetric ? "m" : "ft" }
    func getPaceUnitString() -> String { return useMetric ? "min/km" : "min/mi" }
}

// MARK: - HikeState Enum

enum HikeState: String, CaseIterable {
    case notStarted = "Not Started"
    case preparing = "Preparing"
    case ready = "Ready"
    case inProgress = "In Progress"
    case paused = "Paused"
    case completed = "Completed"
    case stopped = "Stopped"
    case error = "Error"
    var isActive: Bool { self == .inProgress || self == .paused }
    var canStart: Bool { self == .ready || self == .paused }
    var canPause: Bool { self == .inProgress }
    var canResume: Bool { self == .paused }
    var canStop: Bool { self == .inProgress || self == .paused }
}

// Compatibility shims so controllers can use `.running`/`.paused` naming
extension HikeState {
    static var running: HikeState { .inProgress }
}

// MARK: - HikeType Enum

enum HikeType: String, CaseIterable {
    case trail, mountain, urban, nature, other
}

// Shared types are now defined in Models/TrackingModels.swift:
// - LocationData
// - RouteAnnotation
// - PersonalRecord
// - FormFeedback
// - AIAnalysisResults
// - EnvironmentalConditions
// - HeartRateZone
// - SplitTime

// Add required WCSessionDelegate method
// Add this method to the existing WCSessionDelegate extension
extension HikeTrackingEngine {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("Watch session activation error: \(error.localizedDescription)")
        } else {
            print("Watch session activated with state: \(activationState.rawValue)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("Watch session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("Watch session deactivated")
        WCSession.default.activate()
    }
    
    // Build a detailed active workout response (hike) for the watch
    private func createActiveHikeWorkoutResponse() -> [String: Any] {
        let isActive = hikeState.isActive
        let startTime: TimeInterval
        if let sd = startDate {
            startTime = sd.timeIntervalSince1970
        } else {
            startTime = Date().addingTimeInterval(-elapsedTime).timeIntervalSince1970
        }
        var base: [String: Any] = [
            "type": "activeHikeWorkoutResponse",
            "workoutType": "hike",
            "timestamp": Date().timeIntervalSince1970,
            "hasActiveWorkout": isActive,
            "state": hikeState.rawValue,
            "hikeState": hikeState.rawValue,
            "isIndoor": isIndoorMode,
            "hikeType": hikeType.rawValue,
            "useImperialUnits": !useMetric,
            "workoutId": workoutId.uuidString
        ]
        let metrics: [String: Any] = [
            "distance": distance.value,
            "elapsedTime": elapsedTime,
            "heartRate": heartRate,
            "calories": calories,
            "cadence": cadence,
            "elevationGain": elevationGain.value,
            "elevationLoss": elevationLoss.value,
            "pace": pace.value,
            "startTime": startTime
        ]
        base["metrics"] = metrics
        // Mirror top-level metrics for robustness
        base["distance"] = distance.value
        base["elapsedTime"] = elapsedTime
        base["heartRate"] = heartRate
        base["calories"] = calories
        base["cadence"] = cadence
        base["elevationGain"] = elevationGain.value
        base["elevationLoss"] = elevationLoss.value
        base["pace"] = pace.value
        base["startTime"] = startTime
        return base
    }
    
    // Add the missing method for handling watch messages
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // Check message type for Join-related and SyncWorkout cases
        let messageType = message["type"] as? String ?? ""
        let isJoinedWorkout = isJoiningExistingWorkout

        // Fast path: reply with full active workout info for hiking
        if messageType == "requestActiveHikeWorkout" ||
           (messageType == "requestActiveWorkout" && (message["workoutType"] as? String)?.lowercased() == "hike") {
            let response = createActiveHikeWorkoutResponse()
            replyHandler(response)
            return
        }

        // Special-case: heartbeat -> reply with quick status
        if messageType == "heartbeat" {
            let now = Date().timeIntervalSince1970
            replyHandler([
                "status": "success",
                "timestamp": now,
                "phoneState": hikeState.rawValue,
                "joinAcknowledged": isJoinedWorkout
            ])
            return
        }

        // For all other messages, send a basic acknowledgment
        replyHandler([
            "status": "received",
            "timestamp": Date().timeIntervalSince1970,
            "joinAcknowledged": isJoinedWorkout
        ])

        // Process the actual message on the main thread to avoid UI freezes
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.processWatchMessage(message)
        }
    }
    
    // Add the missing method for handling application context
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        print("📱 Received application context from watch: \(applicationContext)")
        
        // Extract watch tracking status if available
        if let isWatchTracking = applicationContext["isWatchTracking"] as? Bool {
            self.isWatchTracking = isWatchTracking
            
            // Update metrics coordinator with new watch tracking status if available
            // Note: Hiking engine might not have metricsCoordinator, so we'll handle this differently
            print("📱 Watch tracking status updated: \(isWatchTracking)")
        }
        
        // Handle outdoorHikeStateChange specifically
        if let type = applicationContext["type"] as? String, type == "outdoorHikeStateChange" {
            print("�� Processing outdoorHikeStateChange from application context")
            // Handle state change logic here
            // You can add specific logic for hiking state changes
        }
    }
    
    // Add method to process watch messages
    public func processWatchMessage(_ message: [String: Any]) {
        // Ensure UI updates happen on main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.processWatchMessage(message)
            }
            return
        }
        
        // Enhanced debug logging for all incoming messages
        print("📱 === PROCESSING WATCH MESSAGE DEBUG ===")
        print("📱 Full message: \(message)")
        
        // Handle specific message types
        let messageType = message["type"] as? String ?? ""
        
        switch messageType {
        case "outdoorHikeStateChange":
            print("📱 Processing outdoorHikeStateChange message")
            if let newState = message["state"] as? String,
               let hikeState = HikeState(rawValue: newState) {
                self.hikeState = hikeState
            }
        
        // Compatibility with copied walking payloads from watch
        case "walkStateChange":
            if let newState = (message["walkState"] as? String) ?? (message["state"] as? String),
               let mapped = HikeState(rawValue: newState) {
                self.hikeState = mapped
            }
            if let metrics = message["metrics"] as? [String: Any] {
                // Always accept heart rate from watch
                if let heartRate = metrics["heartRate"] as? Double, heartRate > 0 {
                    self.heartRate = heartRate
                }
                // Only accept other metrics if watch is primary
                if !isPrimaryForDistance, let distance = metrics["distance"] as? Double, distance > 0 {
                    self.distance = Measurement(value: distance, unit: .meters)
                }
                if let elapsedTime = metrics["elapsedTime"] as? TimeInterval { self.elapsedTime = elapsedTime }
                if !isPrimaryForCalories, let calories = metrics["calories"] as? Double, calories > 0 {
                    self.calories = calories
                }
                if !isPrimaryForCadence, let cadence = metrics["cadence"] as? Double, cadence > 0 {
                    self.cadence = cadence
                }
                if let paceVal = metrics["pace"] as? Double { self.pace = Measurement(value: paceVal, unit: .minutesPerKilometer) }
            }
            self.updateFormattedValues()
            NotificationCenter.default.post(name: .didUpdateHikeMetrics, object: nil)

        case "syncWalkingWorkoutData":
            if let metrics = message["metrics"] as? [String: Any] {
                // Always accept heart rate from watch
                if let heartRate = metrics["heartRate"] as? Double, heartRate > 0 {
                    self.heartRate = heartRate
                }
                // Only accept other metrics if watch is primary
                if !isPrimaryForDistance, let distance = metrics["distance"] as? Double, distance > 0 {
                    self.distance = Measurement(value: distance, unit: .meters)
                }
                if let elapsedTime = metrics["elapsedTime"] as? TimeInterval { self.elapsedTime = elapsedTime }
                if !isPrimaryForCalories, let calories = metrics["calories"] as? Double, calories > 0 {
                    self.calories = calories
                }
                if !isPrimaryForCadence, let cadence = metrics["cadence"] as? Double, cadence > 0 {
                    self.cadence = cadence
                }
                if let paceVal = metrics["pace"] as? Double { self.pace = Measurement(value: paceVal, unit: .minutesPerKilometer) }
            } else {
                // Some heart-only updates may place heartRate at top level - always accept
                if let hr = message["heartRate"] as? Double, hr > 0 {
                    self.heartRate = hr
                }
            }
            self.updateFormattedValues()
            NotificationCenter.default.post(name: .didUpdateHikeMetrics, object: nil)

        case "syncWorkoutData":
            print("📱 Processing syncWorkoutData message")
            if let metrics = message["metrics"] as? [String: Any] {
                // Always accept heart rate from watch (watch is always primary for HR)
                if let heartRate = metrics["heartRate"] as? Double, heartRate > 0 {
                    print("📱 Updating heart rate from watch: \(heartRate)")
                    self.heartRate = heartRate
                }
                
                // Only accept other metrics if watch is primary for them
                if !isPrimaryForDistance, let distance = metrics["distance"] as? Double, distance > 0 {
                    self.distance = Measurement(value: distance, unit: .meters)
                }
                if let elapsedTime = metrics["elapsedTime"] as? TimeInterval {
                    self.elapsedTime = elapsedTime
                }
                if !isPrimaryForCalories, let calories = metrics["calories"] as? Double, calories > 0 {
                    self.calories = calories
                }
                if !isPrimaryForCadence, let cadence = metrics["cadence"] as? Double, cadence > 0 {
                    self.cadence = cadence
                }
                if let elevationGain = metrics["elevationGain"] as? Double {
                    self.elevationGain = Measurement(value: elevationGain, unit: .meters)
                }
                if let elevationLoss = metrics["elevationLoss"] as? Double {
                    self.elevationLoss = Measurement(value: elevationLoss, unit: .meters)
                }
                
                // Update formatted values after receiving new metrics
                self.updateFormattedValues()
                NotificationCenter.default.post(name: .didUpdateHikeMetrics, object: nil)
            }
            
        case "requestActiveHikeWorkout":
            print("📱 Processing requestActiveHikeWorkout message")
            if hikeState.isActive {
                // Send current workout state to watch
                self.syncWithWatch()
            }
            
        default:
            print("📱 Unhandled message type: \(messageType)")
        }
    }
    
    // Add method to sync with watch
    private func syncWithWatch() {
        guard WCSession.isSupported() else { return }
        
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        
        // Don't send updates back to the watch when we're processing a remote state change
        if isHandlingRemoteStateChange {
            print("📱 Skipping syncWithWatch - handling remote state change")
            return
        }
        
        // Prepare metrics to send - only send metrics that phone is primary for
        let metricsToSend: [String: Any] = [
            "distance": isPrimaryForDistance ? distance.value : 0,
            "elapsedTime": elapsedTime,  // Always send elapsed time
            "heartRate": isPrimaryForHeartRate ? heartRate : 0,
            "calories": isPrimaryForCalories ? calories : 0,
            "cadence": isPrimaryForCadence ? cadence : 0,
            "elevationGain": elevationGain.value,  // Always send elevation (phone GPS is better)
            "elevationLoss": elevationLoss.value,  // Always send elevation
            "pace": isPrimaryForPace ? pace.value : 0
        ]
        
        let updateData: [String: Any] = [
            "type": "hikeWorkoutUpdate",
            "hikeState": hikeState.rawValue,
            "metrics": metricsToSend,
            "hikeType": hikeType.rawValue,
            "isIndoor": isIndoorMode,
            "isWatchTracking": isWatchTracking,
            "hasGoodLocationData": hasGoodLocationData,
            "isPrimaryForDistance": isPrimaryForDistance,
            "isPrimaryForPace": isPrimaryForPace,
            "isPrimaryForHeartRate": isPrimaryForHeartRate,
            "isPrimaryForCalories": isPrimaryForCalories,
            "isPrimaryForCadence": isPrimaryForCadence,
            "isDashboardMode": isDashboardMode,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Send update to watch
        session.sendMessage(updateData, replyHandler: nil) { error in
            print("📱 Error syncing with watch: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Watch Messaging Helper
    private func sendMessageToWatch(_ message: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled,
              session.isReachable else { return }
        session.sendMessage(message, replyHandler: nil) { error in
            print("📱 Watch message error: \(error.localizedDescription)")
        }
    }
    
    // Add method to update application context
    func updateApplicationContext() {
        guard WCSession.isSupported() else { return }
        
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        
        let context: [String: Any] = [
            "type": "hikeWorkoutState",
            "hikeState": hikeState.rawValue,
            "hikeType": hikeType.rawValue,
            "isIndoor": isIndoorMode,
            "isWatchTracking": isWatchTracking,
            "hasGoodLocationData": hasGoodLocationData,
            "isPrimaryForDistance": isPrimaryForDistance,
            "isPrimaryForPace": isPrimaryForPace,
            "isPrimaryForHeartRate": isPrimaryForHeartRate,
            "isPrimaryForCalories": isPrimaryForCalories,
            "isPrimaryForCadence": isPrimaryForCadence,
            "isDashboardMode": isDashboardMode,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        do {
            try session.updateApplicationContext(context)
        } catch {
            print("📱 Error updating application context: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Device Coordination
    
    // Establish initial device coordination roles
    func establishDeviceCoordination() {
        guard hikeState != .notStarted && hikeState != .completed else { return }
        
        // Hiking is typically outdoor, but check for indoor mode
        let wasWatchTracking = isWatchTracking // Remember if watch was tracking before
        
        if isIndoorMode {
            // For indoor hikes, watch takes precedence for all metrics
            isDashboardMode = true
            isWatchTracking = true
            
            // Set watch as primary for all metrics
            isPrimaryForDistance = false
            isPrimaryForPace = false
            isPrimaryForHeartRate = false
            isPrimaryForCalories = false
            isPrimaryForCadence = false
            
            print("📱 Indoor hike: Phone acting as dashboard")
            print("⌚️ Watch will be primary for all tracking metrics")
        } else {
            // For outdoor hikes, determine based on GPS quality
            isDashboardMode = false
            
            // If watch was tracking (e.g., we're joining a workout started on watch),
            // we still want to check if phone has good GPS and can take over
            let watchStartedWorkout = wasWatchTracking || isJoiningExistingWorkout
            
            // Check if we have good GPS data
            if hasGoodLocationData {
                // Phone is primary for GPS-based metrics (even if watch started the workout)
                // Phone GPS is more accurate for outdoor distance/pace
                isPrimaryForDistance = true
                isPrimaryForPace = true
                isPrimaryForHeartRate = false // Watch still better for HR
                isPrimaryForCalories = true   // Phone can calculate calories with distance
                isPrimaryForCadence = false   // Watch better for cadence
                
                // If watch started the workout, we're now coordinating (not just dashboard)
                if watchStartedWorkout {
                    isWatchTracking = false // Phone is now tracking GPS-based metrics
                    print("📱 Outdoor hike (joined from watch) with good GPS: Phone now primary for distance/pace")
                    print("⌚️ Watch primary for heart rate and cadence")
                    
                    // Re-evaluate GPS quality after a few seconds to ensure it's stable
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                        guard let self = self, self.hikeState.isActive else { return }
                        // Re-check GPS quality and update coordination if it has degraded
                        if !self.hasGoodLocationData && self.isPrimaryForDistance {
                            print("📱 GPS quality degraded - re-establishing device coordination")
                            self.establishDeviceCoordination()
                        }
                    }
                } else {
                    print("📱 Outdoor hike with good GPS: Phone primary for distance/pace")
                    print("⌚️ Watch primary for heart rate and cadence")
                }
            } else {
                // Poor GPS quality, let watch take more metrics
                isPrimaryForDistance = false
                isPrimaryForPace = false
                isPrimaryForHeartRate = false
                isPrimaryForCalories = false
                isPrimaryForCadence = false
                isWatchTracking = true
                
                if watchStartedWorkout {
                    print("📱 Outdoor hike (joined from watch) with poor GPS: Watch remains primary for metrics")
                } else {
                    print("📱 Outdoor hike with poor GPS: Deferring to watch for metrics")
                }
                
                // Re-evaluate GPS quality after a few seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    guard let self = self, self.hikeState.isActive else { return }
                    // If GPS improves, re-establish coordination
                    if self.hasGoodLocationData && self.isWatchTracking {
                        print("📱 GPS improved - re-establishing device coordination")
                        self.establishDeviceCoordination()
                    }
                }
            }
        }
        
        // Update application context to let watch know current state
        updateApplicationContext()
        
        // Send immediate update to watch
        syncWithWatch()
    }
    
    // MARK: - AWS Save Methods
    
    /// Save the completed hike to AWS
    func saveHikeToParse() {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            print("📱 💾 HIKE SAVE: ❌ Cannot save - no current user")
            return
        }
        
        // Convert locationList to route points format
        let routePoints: [[String: Any]] = locationList.map { location in
            [
                "timestamp": ISO8601DateFormatter().string(from: location.timestamp),
                "latitude": location.latitude,
                "longitude": location.longitude,
                "altitude": location.altitude,
                "horizontalAccuracy": location.horizontalAccuracy,
                "verticalAccuracy": location.verticalAccuracy,
                "speed": location.speed,
                "course": location.course
            ]
        }
        
        // Calculate elapsed time
        let elapsedTime = (startDate ?? Date()).timeIntervalSinceNow * -1
        
        // Save to AWS
        ActivityService.shared.saveHike(
            userId: userId,
            duration: elapsedTime,
            distance: distance.value, // Distance in meters
            calories: calories,
            elevationGain: elevationGain.value, // In meters
            elevationLoss: elevationLoss.value, // In meters
            routePoints: routePoints,
            activityData: ["hikeType": hikeType.rawValue],
            startLocation: locationList.first.map { ["lat": $0.latitude, "lon": $0.longitude] },
            endLocation: locationList.last.map { ["lat": $0.latitude, "lon": $0.longitude] },
            isPublic: true,
            caption: nil
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let response):
                print("📱 💾 HIKE SAVE: ✅ Hike saved to AWS successfully")
                print("📊 Activity ID: \(response.data?.activityId ?? "unknown")")
                
            case .failure(let error):
                print("📱 💾 HIKE SAVE: ❌ Error saving hike to AWS: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Watch Handoff and Multi-Device Support

extension HikeTrackingEngine {
    
    /// Initiate handoff to watch
    func initiateHandoffToWatch(completion: @escaping (Bool) -> Void) {
        guard hikeState != .notStarted else {
            completion(false)
            return
        }
        
        let metrics = WorkoutMetrics(
            distance: distance.value,
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            pace: pace.value,
            calories: calories,
            cadence: cadence,
            elevationGain: elevationGain.value
        )
        
        let handoffMessage = WorkoutHandoffMessage(
            direction: .phoneToWatch,
            workoutType: .hiking,
            workoutId: workoutId.uuidString,
            metrics: metrics,
            state: convertHikeStateToWorkoutState(hikeState),
            startDate: startDate ?? Date()
        )
        
        guard let session = WCSession.default as? WCSession,
              session.isWatchAppInstalled else {
            completion(false)
            return
        }
        
        if session.isReachable {
            session.sendMessage(handoffMessage.toDictionary(), replyHandler: { response in
                let accepted = response["accepted"] as? Bool ?? false
                if accepted {
                    self.stop()
                }
                completion(accepted)
            }, errorHandler: { error in
                print("❌ [HikeTrackingEngine] Handoff failed: \(error.localizedDescription)")
                completion(false)
            })
        } else {
            do {
                try session.updateApplicationContext(handoffMessage.toDictionary())
                completion(true)
            } catch {
                completion(false)
            }
        }
    }
    
    /// Handle handoff from watch
    func handleHandoffFromWatch(_ message: [String: Any]) {
        guard let handoffMessage = WorkoutHandoffMessage.fromDictionary(message) else {
            return
        }
        
        if hikeState != .notStarted {
            handleHandoffConflict(phoneState: convertHikeStateToWorkoutState(hikeState),
                                watchWorkout: handoffMessage)
            return
        }
        
        isJoiningExistingWorkout = true
        workoutId = UUID(uuidString: handoffMessage.workoutId) ?? UUID()
        startDate = handoffMessage.startDate
        
        distance = Measurement(value: handoffMessage.metrics.distance, unit: UnitLength.meters)
        elapsedTime = handoffMessage.metrics.elapsedTime
        heartRate = handoffMessage.metrics.heartRate
        pace = Measurement(value: handoffMessage.metrics.pace, unit: UnitSpeed.metersPerSecond)
        calories = handoffMessage.metrics.calories
        cadence = handoffMessage.metrics.cadence ?? 0
        
        hikeState = convertWorkoutStateToHikeState(handoffMessage.state)
        
        if let session = WCSession.default as? WCSession, session.isReachable {
            session.sendMessage([
                "type": "handoffResponse",
                "accepted": true,
                "workoutId": workoutId.uuidString
            ], replyHandler: { _ in }, errorHandler: { error in
                print("❌ [HikeTrackingEngine] Error sending handoff response: \(error.localizedDescription)")
            })
        }
    }
    
    private func handleHandoffConflict(phoneState: WorkoutState, watchWorkout: WorkoutHandoffMessage) {
        isJoiningExistingWorkout = true
        workoutId = UUID(uuidString: watchWorkout.workoutId) ?? UUID()
        startDate = watchWorkout.startDate
        
        heartRate = watchWorkout.metrics.heartRate
        cadence = watchWorkout.metrics.cadence ?? cadence
        calories = max(calories, watchWorkout.metrics.calories)
        elapsedTime = max(elapsedTime, watchWorkout.metrics.elapsedTime)
        
        hikeState = convertWorkoutStateToHikeState(watchWorkout.state)
    }
    
    // MARK: - Multi-Device Support
    
    func integrateWithExternalDevices() {
        let aggregator = MultiDeviceDataAggregator.shared
        
        aggregator.$aggregatedMetrics
            .sink { [weak self] metrics in
                self?.updateMetricsFromExternalDevices(metrics)
            }
            .store(in: &cancellables)
    }
    
    private func updateMetricsFromExternalDevices(_ metrics: WorkoutMetrics) {
        let coordinationEngine = DeviceCoordinationEngine.shared
        let isIndoor = false // Hiking is always outdoor
        
        if let source = coordinationEngine.selectBestDataSource(
            for: .heartRate,
            workoutType: .hiking,
            isIndoor: isIndoor,
            availableSources: [.watch, .oura, .garmin, .fitbit]
        ), source == .watch || source == .oura || source == .garmin || source == .fitbit {
            if metrics.heartRate > 0 {
                heartRate = metrics.heartRate
            }
        }
    }
    
    // MARK: - Live Metrics Sync
    
    func startLiveMetricsSync() {
        LiveMetricsSync.shared.startLiveSync()
        
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.syncCurrentMetrics()
        }
    }
    
    func stopLiveMetricsSync() {
        LiveMetricsSync.shared.stopLiveSync()
    }
    
    private func syncCurrentMetrics() {
        guard hikeState != .notStarted else { return }
        
        let metrics = WorkoutMetrics(
            distance: distance.value,
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            pace: pace.value,
            calories: calories,
            cadence: cadence,
            elevationGain: elevationGain.value
        )
        
        LiveMetricsSync.shared.syncMetrics(
            metrics: metrics,
            workoutId: workoutId.uuidString,
            workoutType: .hiking
        )
    }
    
    // MARK: - State Conversion Helpers
    
    private func convertHikeStateToWorkoutState(_ hikeState: HikeState) -> WorkoutState {
        switch hikeState {
        case .notStarted: return .idle
        case .preparing, .ready: return .starting
        case .inProgress: return .running
        case .paused: return .paused
        case .completed: return .completed
        case .stopped: return .stopped
        case .error: return .stopped
        }
    }
    
    private func convertWorkoutStateToHikeState(_ workoutState: WorkoutState) -> HikeState {
        switch workoutState {
        case .idle: return .notStarted
        case .starting: return .ready
        case .running: return .inProgress
        case .paused: return .paused
        case .stopping: return .stopped
        case .stopped: return .stopped
        case .completed: return .completed
        }
    }
    
    // MARK: - Enhanced Watch Sync
    
    func enhancedSyncWithWatch() {
        syncWithWatch()
        
        WorkoutStateSync.shared.syncState(
            workoutId: workoutId.uuidString,
            workoutType: .hiking,
            state: convertHikeStateToWorkoutState(hikeState)
        )
    }
    
    // MARK: - Handoff Data Provider
    
    func getHandoffData() -> [String: Any]? {
        guard hikeState != .notStarted else { return nil }
        
        let metrics = WorkoutMetrics(
            distance: distance.value,
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            pace: pace.value,
            calories: calories,
            cadence: cadence,
            elevationGain: elevationGain.value
        )
        
        let handoffMessage = WorkoutHandoffMessage(
            direction: .phoneToWatch,
            workoutType: .hiking,
            workoutId: workoutId.uuidString,
            metrics: metrics,
            state: convertHikeStateToWorkoutState(hikeState),
            startDate: startDate ?? Date()
        )
        
        return handoffMessage.toDictionary()
    }
}
