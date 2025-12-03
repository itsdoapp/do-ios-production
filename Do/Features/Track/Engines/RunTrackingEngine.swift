//
//  RunTrackingEngine.swift
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



// Heart rate notification name extension
extension Notification.Name {
    static let heartRateUpdate = Notification.Name("com.do.heartRate.update")
    // Add activity state change notifications
    static let activityDidStart = Notification.Name("ActivityDidStart")
    static let activityDidEnd = Notification.Name("ActivityDidEnd")
    static let didChangeRunState = Notification.Name("RunStateDidChange")
    static let didUpdateRunState = Notification.Name("RunStateDidUpdate")
    static let didUpdateRunMetrics = Notification.Name("DidUpdateRunMetrics")
    // Use the same notification names as ModernLocationManager to ensure compatibility
    static let locationErrorOccurred = Notification.Name("locationErrorOccurred")
    static let locationPermissionDenied = Notification.Name("locationPermissionDenied")
    static let runSettingsDidChange = Notification.Name("runSettingsDidChange")

    static let locationDidUpdate = Notification.Name("locationDidUpdate")
}



// Custom unit extensions for length
extension UnitLength {
    // These are already defined in Foundation, but are added here for clarity and to ensure they're accessible
    static let kilometers = UnitLength.kilometers
    static let meters = UnitLength.meters
    static let miles = UnitLength.miles
    static let feet = UnitLength.feet
}

// Constants for caching
private struct RunCacheKeys {
    static let recentPaces = "recentRunPaces"  // For pace recommendations
    static let emergencyBackup = "emergencyRunBackup"  // For interrupted/lost connection runs
    static let maxRecentPaces = 10  // Keep last 10 runs for recommendations
}


class RunTrackingEngine: NSObject, ObservableObject, WCSessionDelegate, WorkoutEngineProtocol {
    // MARK: - Singleton Instance
    static let shared = RunTrackingEngine()
    
    // MARK: - Delegate Protocol
    
    /// Protocol for receiving state updates from the RunTrackingEngine
    protocol RunTrackingEngineDelegate: AnyObject {
        /// Called when the tracking engine's state is updated
        func runTrackingEngineDidUpdateState(_ engine: RunTrackingEngine)
    }
    
    // MARK: - Published Properties
    
    /// Delegate to receive updates about the run tracking engine state
    weak var delegate: RunTrackingEngineDelegate?
    
    // Run state and type
    internal var workoutId = UUID()
    
    // Flag to track if the watch has acknowledged our join
    public var watchHasAcknowledgedJoin = false
    
    @Published var runState: RunState = .notStarted {
        didSet {
            // Update metrics every time the state changes
            updateFormattedValues()
            
            // Log state changes
            print("📱 Updated runState: \(oldValue) => \(runState)")
            
            // Post notification for state change
            NotificationCenter.default.post(name: .didUpdateRunState, object: nil)
        }
    }
    @Published var runType: RunType = .outdoorRun {
        didSet {
            updateRunType(runType)
        }
    }
    @Published var targetDistance: Measurement<UnitLength>?
    
    // Flag to indicate whether we're joining an existing workout (from watch)
    public var isJoiningExistingWorkout: Bool = false
    
    
    // Tracking metrics
    @Published var distance: Measurement<UnitLength> = Measurement(value: 0, unit: UnitLength.meters)
    @Published var elapsedTime: TimeInterval = 0
    @Published var pace: Measurement<UnitSpeed> = Measurement(value: 0, unit: UnitSpeed.minutesPerKilometer) {
        didSet {
            // Validate pace value when it's set from anywhere
            if pace.value <= 0 {
                // Keep it at 0 for "no pace" situations
            } else {
                let validatedValue = validatePaceValue(pace.value)
                if validatedValue != pace.value {
                    pace = Measurement(value: validatedValue, unit: pace.unit)
                }
            }
        }
    }
    @Published var currentPace = Measurement(value: 0, unit: UnitSpeed.minutesPerKilometer)
    private var smoothedPace: Measurement<UnitSpeed>?
    private var lastPaceUpdate: TimeInterval = 0
    @Published var calories: Double = 0
    @Published var heartRate: Double = 0
    @Published var elevationGain: Measurement<UnitLength> = Measurement(value: 0, unit: UnitLength.meters)
    @Published var elevationLoss: Measurement<UnitLength> = Measurement(value: 0, unit: UnitLength.meters)
    
    // Advanced metrics
    @Published var cadence: Double = 0 // Steps per minute
    @Published var strideLength: Measurement<UnitLength> = Measurement(value: 0, unit: UnitLength.meters)
    @Published var verticalOscillation: Measurement<UnitLength> = Measurement(value: 0, unit: UnitLength.centimeters)
    @Published var groundContactTime: TimeInterval = 0
    @Published var heartRateZone: HeartRateZoneType = .none
    @Published var performanceIndex: Double = 0
    @Published var environmentalConditions: EnvironmentalConditions = EnvironmentalConditions()
    @Published var paceHistory: [Double] = [] // Track pace changes for consistency analysis
    @Published var splitTimes: [SplitTime] = []
    
    // Pace smoothing for UI display
    private var recentPaceValues: [Double] = [] // Stores recent pace values in seconds/km
    private let maxPaceHistoryCount = 5 // Number of values to keep for smoothing
    private var treadmillDataPoints: [TreadmillDataPoint]? = nil

    
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
    @Published var distanceUnit: String = "km" // Store the distance unit (km or mi)
    
    // AI coaching and feedback
    @Published var coachFeedback: String?
    @Published var formFeedback: FormFeedback?
    @Published var runningEfficiency: Double = 0 // 0-100% scale
    @Published var aiAnalysisResults: AIAnalysisResults = AIAnalysisResults()
    
    // UI state
    @Published var isScreenLocked: Bool = false
    @Published var locationList: [LocationData] = []
    @Published var routeAnnotations: [RouteAnnotation] = []
    @Published var useMetric: Bool = false // Default to imperial (miles)
    @Published var recentPersonalRecords: [PersonalRecord] = []
    private var isHandlingRemoteStateChange = false
    
    // Weather and environment
    // MARK: - Weather Data Structures
    
    /// Weather data for run tracking
    struct WeatherData: Identifiable {
        var id = UUID()
        let temperature: Double // in Celsius
        let condition: String
        let windSpeed: Double // in m/s
        let humidity: Double // in percentage
        let icon: String // SF Symbol name
        var airQuality: Int? = nil // Air Quality Index (0-500 scale)
        var feelsLike: Double? = nil // Feels like temperature
        var uvIndex: Double? = nil // UV Index
        
        var formattedTemperature: String {
            return String(format: "%.1f°C", temperature)
        }
        
        var formattedWindSpeed: String {
            return String(format: "%.1f m/s", windSpeed)
        }
        
        var formattedHumidity: String {
            return String(format: "%.0f%%", humidity)
        }
        
        var weatherCondition: WeatherCondition {
            return WeatherCondition.determineCondition(from: condition)
        }
    }
    
    /// Weather conditions that can be used to describe current weather
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
    
    // Group run properties
    @Published var isGroupRun: Bool = false
    @Published var groupRunType: GroupRunType?
    @Published var groupRunParticipants: [GroupRunParticipant] = []
    @Published var isHostingGroupRun: Bool = false
    @Published var groupRunInvitation: GroupRunInvitation?
    @Published var groupRunId: String? // Add this property to store the group run identifier
    
    // Device coordination properties
    @Published var isWatchTracking: Bool = false
    public var isPrimaryForDistance: Bool = true // Phone is typically primary for distance
    public var isPrimaryForHeartRate: Bool = false // Watch is typically primary for heart rate
    @Published var isPrimaryForPace = false
    @Published var isPrimaryForCadence = false
    @Published var isPrimaryForCalories = false
    public var hasGoodLocationData = false
    
    // Audio guidance 
    @Published var navigationAudioMuted: Bool = false
    
    // Auto-tracking and external update control
    private var autoTrackingEnabled: Bool = true
    private var isAutoTrackingEnabled: Bool { autoTrackingEnabled }
    private var allowExternalHeartRateUpdates: Bool = true
    private var currentHeartRate: Double = 0
    public var isIndoorMode: Bool = false // Add this property
    
    // Additional metrics
    private var currentCadence: Double = 0
    private var userWeight: Double = 70.0 // Default weight in kg
    private var maxHeartRate: Double = 190.0 // Default max heart rate
    private var heartRateBuffer: [Double] = []
    private(set) var avgHeartRate: Double = 0
    private var age: Int = 30 // Default age
    
    // Add new published properties for dashboard mode
    @Published var isDashboardMode: Bool = false
    @Published var dashboardModeReason: String = ""
    
    // WCSession properties
    private var session: WCSession?
    private var trackingStatusTimer: Timer?  // Timer for regular tracking status updates
    private var lastWorkoutUpdateTime = Date(timeIntervalSince1970: 0) // Initialize to distant past
    private var isForcedUpdate = false // Flag to allow bypassing the rate limit
    
    // Add this property near the other property declarations at the top of the class
    var metricsCoordinator: MetricsCoordinator?
    
    // MARK: - Private Properties
    
    // Core managers
    private let locationManager = ModernLocationManager.shared
    private let healthStore = HKHealthStore()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let workoutManager = RunningWorkoutManager.shared
    private let weatherService = WeatherService.shared
    
    // Timers and tracking
    private var timer: Timer?
    private var startDate: Date?
    private var pauseDate: Date?
    private var totalPausedTime: TimeInterval = 0 // Track accumulated pause duration like the watch
    public var currentUser: String?
    private var cancellables = Set<AnyCancellable>()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var elevationTracker = ElevationTracker() // Reuse from original code
    private var lastAnnouncement: Date?
    private var nextCoachingTipIndex = 0
    private var parseObject: String?
    private var silentAudioPlayer: AVAudioPlayer? // For background audio
    
    // Advanced tracking
    private var motionManager = CMMotionManager()
    private var lastStepTimestamp: Date?
    private var stepCount: Int = 0
    private var lastSplitDistance: Double = 0
    private var lastSplitTime: TimeInterval = 0
    private var paceAnalysisWindow: [Double] = [] // Last 30 seconds of pace
    private var heartRateReadings: [Double] = []
    private var weatherTimer: Timer?
    private var lastLocationForWeather: CLLocation?
    // Add these properties to the class
    private var lastLoggedHeartRate: Double = 0
    private var lastHeartRateLogTime = Date(timeIntervalSince1970: 0)
    
    // Settings
    private var enableVoiceCoaching: Bool = true
    private var enableAICoaching: Bool = true
    private var autoLockScreen: Bool = false
    private var announcementFrequency: Double = 1.0
    private var screenAlwaysOn: Bool = true
    private var showHeatMap: Bool = true
    private var trackElevation: Bool = true
    private var recordHeartRate: Bool = true
    private var preferredVoiceType: UserPreferences.VoiceType = .female
    private var preferredVoice: AVSpeechSynthesisVoice?
    private var enableHapticFeedback: Bool = true
    
    // Pace calculation and smoothing
    private var paceSmoothing: [Double] = [] // For smoothing pace calculations 
    private var maxPaceSamples: Int = 5 // Number of samples to average
    private var lastPaceUpdateTime: TimeInterval = 0 // Change to TimeInterval for consistency
    private let paceUpdateThrottleInterval: TimeInterval = 2.0 // seconds between updates
    private var paceUpdateThreshold: TimeInterval = 3.0 // Increase threshold to 3 seconds
    
    // Add this property with the other class properties
    private var receivedWatchStatusUpdate: Bool = false
    
    // MARK: - Computed Properties
    
    var isRunning: Bool { runState == .running }
    var isPaused: Bool { runState == .paused }
    
    // Unified run log - handles both indoor and outdoor
    private var runLog = RunLog()

    // Computed property to get the current run log
    var currentRunLog: RunLog {
        return runLog
    }
    
    // MARK: - Pace Formatting Helper
private func formatPaceFromSeconds(_ seconds: Double) -> String {
    guard seconds > 0 else { return "-'--\"" }
    
    // Convert based on user's unit preference
    if useMetric {
        // For metric: minutes:seconds per kilometer (display seconds/km directly)
        let minutes = Int(seconds / 60)
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d'%02d\"", minutes, secs)
    } else {
        // For imperial: minutes:seconds per mile (convert from seconds/km to seconds/mile)
        let secondsPerMile = seconds * 1.60934 // Convert km to mile
        let minutes = Int(secondsPerMile / 60)
        let secs = Int(secondsPerMile.truncatingRemainder(dividingBy: 60))
        return String(format: "%d'%02d\"", minutes, secs)
    }
}
// MARK: - Model Types
// Shared types are now defined in Models/TrackingModels.swift:
// - SplitTime
// - FormFeedback
// - AIAnalysisResults
// - EnvironmentalConditions
// - PersonalRecord
// - HeartRateZone
// - LocationData
// - RouteAnnotation
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        // Use shared WCSession instead of creating new one
        if WCSession.isSupported() {
            self.session = WCSession.default
            print("📲 WCSession configured in RunTrackingEngine")
        }
        
        // Add observers for app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        // Add observer for user preference changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreferenceChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        
        // Add observer for run settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRunSettingsChange),
            name: .runSettingsDidChange,
            object: nil
        )
        
        // Defer heavy initialization to avoid blocking startup
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Initialize managers and setup
            self.setupSubscriptions()
            self.setupMetricsFormatters()
            
            // Get user settings
            self.loadSettings()
            
            // Check if there's an active workout in the RunningWorkoutManager
            if self.workoutManager.isWorkoutActive {
                self.syncWithWorkoutManager()
            }
            
            // Set up motion manager for cadence tracking
            self.setupMotionTracking()
            
            // Initialize the metrics coordinator
            self.metricsCoordinator = MetricsCoordinator(runEngine: self)
        }
        
        // Setup location error handling
        setupLocationErrorHandling()
    }
    
    @objc private func handlePreferenceChange() {
        
        // Use dispatch_once pattern to ensure safe singleton access
           DispatchQueue.main.async { [weak self] in
               guard let self = self else { return }
               
               // Access on main thread after initialization is complete
               // Check if the metric preference has changed
               let newUseMetric = UserPreferences.shared.useMetricSystem
               
               if newUseMetric != useMetric {
                   print("📝 Unit preference changed from \(useMetric ? "metric" : "imperial") to \(newUseMetric ? "metric" : "imperial")")
                   
                   // Update the local property
                   self.useMetric = newUseMetric
                   
                   // Force update all formatted values to use the new unit
                   updateFormattedValues()
                   
                   // Also update any UI that depends on the formatter
                   objectWillChange.send()
                   
                   // Send the updated preference to the watch
                   updateApplicationContext()
               }
           }
       
    }
    
    @objc private func handleRunSettingsChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Reload settings from RunSettingsManager
            self.loadSettings()
            
            // Apply screen settings immediately
            if self.screenAlwaysOn {
                UIApplication.shared.isIdleTimerDisabled = true
            } else {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            
            // Update voice settings - store the preferred voice for use in utterances
            if let bestVoice = self.preferredVoiceType.bestAvailableVoice {
                self.preferredVoice = bestVoice
                print("🔊 Updated voice to: \(bestVoice.identifier) (\(bestVoice.name))")
            }
            
            // Force UI update
            self.objectWillChange.send()
            
            print("📱 Run settings updated and applied")
        }
    }
    
    // Add this method to RunTrackingEngine
    private func updateHeartRateMetrics(_ newHeartRate: Double) {
        // Update current heart rate
        self.heartRate = newHeartRate
        
        // Skip further processing if heart rate is invalid
        guard newHeartRate > 0 else { return }
        
        // Update max heart rate if needed
        if newHeartRate > maxHeartRate {
            maxHeartRate = newHeartRate
        }
        
        // Add to heart rate buffer for average calculation
        heartRateBuffer.append(newHeartRate)
        
        // Keep buffer size manageable (last 60 readings)
        if heartRateBuffer.count > 60 {
            heartRateBuffer.removeFirst()
        }
        
        // Calculate average heart rate
        if !heartRateBuffer.isEmpty {
            avgHeartRate = heartRateBuffer.reduce(0, +) / Double(heartRateBuffer.count)
        }
    }

        /// Updates the current run state
        ///
        /// - Parameter newState: The new run state
        func updateRunState(_ newState: RunState) {
            let oldState = runState
            runState = newState
            
            // Send forced workout update on state change
            sendWorkoutUpdate(forced: true)
            
            // Notify observers about the state change
            notifyObservers()
            
            // If the run has just started, start updating metrics
            if oldState != .running && newState == .running {
                startUpdatingMetrics()
            }
            
            // If the run has just been paused or stopped, cancel timer
            if oldState == .running && (newState == .paused || newState == .notStarted || newState == .completed) {
                stopUpdatingMetrics()
            }
        }
    /// Notifies observers about changes in the run state or metrics
    private func notifyObservers() {
        // Post notification for UI updates
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("RunStateDidChange"),
                object: self
            )
            
            // Also send objectWillChange for SwiftUI views
            self.objectWillChange.send()
        }
        
        // Update formatted values
        updateFormattedValues()
    }

    /// Starts updating metrics regularly
    private func startUpdatingMetrics() {
        // Start the main timer for tracking elapsed time
        startTimer()
        
        // Start location updates if this is an outdoor run
        if !isIndoorMode {
            ModernLocationManager.shared.startUpdatingLocation()
        }
        
        // Note: Heart rate is collected by the watch and synced via coordination
        // The phone does not collect heart rate directly
    
        // Update the application context
        updateApplicationContext()
    }

    /// Stops updating metrics
    private func stopUpdatingMetrics() {
        // Stop the timer
        stopTimer()
        
        // Stop location updates if needed
        if !isIndoorMode && !isWatchTracking {
            ModernLocationManager.shared.stopUpdatingLocation()
        }
        
        // Note: Heart rate collection is handled by the watch
        
        // Update the application context
        updateApplicationContext()
    }
    // Register for location error notifications in init method or setup
    private func setupLocationErrorHandling() {
        // Register for location error notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocationError),
            name: .locationErrorOccurred,
            object: ModernLocationManager.shared
        )
        
        // Register for location permission denied notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocationPermissionDenied),
            name: .locationPermissionDenied,
            object: ModernLocationManager.shared
        )
        
        // Register for successful location updates to track system health
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocationUpdate),
            name: .locationDidUpdate,
            object: ModernLocationManager.shared
        )
    }
    
    // Handle location errors
    @objc private func handleLocationError(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Only update health if we're actually running
            guard self.runState == .running else { return }
            
            // Get the error details if available
            let error = notification.userInfo?["error"] as? Error
            
            // Handle specific errors
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    // User denied location access - this is a permanent issue
                    print("📍 Location access denied - switching to watch only mode")
                    self.locationSystemHealthy = false
                    self.hasGoodLocationData = false
                    self.isPrimaryForDistance = false
                    self.isPrimaryForPace = false
                    
                    // Show user-friendly message if needed
                    if self.isIndoorMode == false {
                        // Only warn if we're in outdoor mode
                        NotificationCenter.default.post(
                            name: .locationPermissionDenied,
                            object: nil
                        )
                    }
                    
                case .locationUnknown:
                    // Temporary location issue - mark as unhealthy but don't show alert
                    self.locationSystemHealthy = false
                    self.hasGoodLocationData = false
                    
                default:
                    // Generic location error - treat as unhealthy
                    self.locationSystemHealthy = false
                    self.hasGoodLocationData = false
                }
            } else {
                // Generic error handling
                self.locationSystemHealthy = false
                self.hasGoodLocationData = false
            }
            
            // Update tracking state to reflect new health status
            self.updateTrackingState()
        }
    }
    
    // Handle location permission denied
    @objc private func handleLocationPermissionDenied(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Mark location system as permanently unhealthy
            self.locationSystemHealthy = false
            self.hasGoodLocationData = false
            
            // Force device roles to use watch for distance/pace
            self.isPrimaryForDistance = false
            self.isPrimaryForPace = false
            
            print("📍 Location permission denied - switching to watch for distance tracking")
            
            // Update tracking state to reflect new health status
            self.updateTrackingState()
            
            // Only show a user alert if this is an outdoor workout
            if !self.isIndoorMode && self.runState == .running {
                // This is an outdoor run with location denied - might need user attention
                print("⚠️ Location permission denied during outdoor run - critical issue")
            }
        }
    }
    
    // Handle location updates (to track system health)
    @objc private func handleLocationUpdate(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Only process if location system was previously unhealthy
            if !self.locationSystemHealthy {
                // Get the location from the notification
                if let location = notification.userInfo?["location"] as? CLLocation,
                   location.horizontalAccuracy <= 20 {
                    // Location system is healthy again
                    self.locationSystemHealthy = true
                    self.hasGoodLocationData = true
                    
                    // Update tracking state
                    self.updateTrackingState()
                }
            }
        }
    }
    
    // Application lifecycle methods
    @objc private func applicationDidBecomeActive() {
        print("📲 App became active - starting tracking status updates")
        if WCSession.default.activationState == .activated {
            startRegularTrackingStatusUpdates()
        }
        
        // CRITICAL FIX: Force time recalculation when returning from background
        if runState == .running || runState == .paused {
            print("📲 🕒 App became active during workout - recalculating elapsed time to prevent time loss")
            
            // Force immediate time recalculation if we have a start date
            if let startDate = startDate {
                let oldElapsedTime = elapsedTime
                let pauseDuration = calculatePauseDuration()
                let newElapsedTime = Date().timeIntervalSince(startDate) - pauseDuration
                
                print("📲 🕒 Time recalculation: old=\(oldElapsedTime)s, new=\(newElapsedTime)s, diff=\(newElapsedTime - oldElapsedTime)s")
                
                elapsedTime = newElapsedTime
                updateFormattedValues()
                
                // Restart timer if we're running (timer may have been suspended in background)
                if runState == .running {
                    startTimer()
                }
                
                // Force UI update
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .didUpdateRunMetrics,
                        object: nil,
                        userInfo: ["elapsedTime": self.elapsedTime]
                    )
                }
            }
        }
    }
    
    @objc private func applicationWillResignActive() {
        print("📲 App will resign active - stopping tracking status updates")
        stopRegularTrackingStatusUpdates()
        
        // CRITICAL FIX: Store current time state before going to background
        if runState == .running || runState == .paused {
            let currentElapsedTime = elapsedTime
            print("📲 🕒 App going to background during workout - current elapsed time: \(currentElapsedTime)s")
            
            // Force one final time calculation before suspending
            if let startDate = startDate {
                let pauseDuration = calculatePauseDuration()
                let calculatedElapsedTime = Date().timeIntervalSince(startDate) - pauseDuration
                
                if abs(calculatedElapsedTime - currentElapsedTime) > 1.0 {
                    print("📲 🕒 Time discrepancy before background: stored=\(currentElapsedTime)s, calculated=\(calculatedElapsedTime)s")
                    elapsedTime = calculatedElapsedTime
                }
            }
        }
    }
    
    deinit {
        // Remove observers
        NotificationCenter.default.removeObserver(self)
        
        // Stop timer
        stopRegularTrackingStatusUpdates()
    }
    
    private func setupSubscriptions() {
        // Update formatted values when raw metrics change
        setupMetricsFormatters()
        
        // Listen for location updates
        locationManager.$location
            .compactMap { $0 }
            // Add receive(on:) to ensure publisher updates happen on main thread
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                guard let self = self, self.isRunning else { return }
                
                // Now safe to update @Published properties directly since we're on main thread
                // Always process the location for distance tracking
                self.processLocationUpdate(location)
                
                // Check if we should update weather (every 15 minutes or 1km)
                self.checkForWeatherUpdate(location)
                
                // But throttle pace updates to reduce flickering
                let currentTime = Date().timeIntervalSince1970
                if currentTime - self.lastPaceUpdateTime >= self.paceUpdateThrottleInterval {
                    self.updateRunMetrics(withLocation: location)
                    self.lastPaceUpdateTime = currentTime
                }
            }
            .store(in: &cancellables)
            
        // Listen for heart rate updates from HealthKit
        NotificationCenter.default.publisher(for: Notification.Name.heartRateUpdate)
            // Add receive(on:) to ensure publisher updates happen on main thread
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let heartRate = notification.userInfo?["heartRate"] as? Double {
                    self?.updateHeartRate(heartRate)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupMotionTracking() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.1
            
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
                guard let self = self, self.isRunning, let data = data else { return }
                
                // Use accelerometer data to detect steps and calculate cadence
                self.processAccelerometerData(data)
            }
        }
    }
    
    private func setupMetricsFormatters() {
        // Distance formatter
        $distance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] measurement in
                guard let self = self else { return }
                
                let formatter = MeasurementFormatter()
                let numberFormatter = NumberFormatter()
                numberFormatter.maximumFractionDigits = 2
                formatter.numberFormatter = numberFormatter
                
                // Convert to preferred unit
                let displayMeasurement = self.useMetric 
                    ? measurement.converted(to: UnitLength.kilometers)
                    : measurement.converted(to: UnitLength.miles)
                
                self.formattedDistance = numberFormatter.string(from: NSNumber(value: displayMeasurement.value)) ?? "0.00"
            }
            .store(in: &cancellables)
        
        // Time formatter
        $elapsedTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] seconds in
                self?.formattedTime = self?.formatTime(Int(seconds)) ?? "00:00:00"
            }
            .store(in: &cancellables)
        
        // Pace formatter
        $pace
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pace in
                guard let self = self else { return }
                
                // Calculate pace with smoothing to prevent jumpy values
                // CRITICAL FIX: All UI updates need to happen on main thread
                // This closure is already guaranteed to be on main thread because we use .receive(on: DispatchQueue.main)
                // So we're safe to directly update formattedPace and other properties
                
                if elapsedTime > 0 && distance.value > 0 {
                    // Calculate current pace (seconds per kilometer)
                    let currentPaceInSecondsPerKm = (elapsedTime / (distance.value / 1000.0))
                    
                    // Only smooth if the pace is reasonable (between 2:00/km and 20:00/km)
                    if currentPaceInSecondsPerKm >= 120 && currentPaceInSecondsPerKm <= 1200 {
                        // Thread-safe array operations
                        self.recentPaceValues.append(currentPaceInSecondsPerKm)
                        
                        // Keep only the most recent values
                        if self.recentPaceValues.count > self.maxPaceHistoryCount {
                            self.recentPaceValues.removeFirst()
                        }
                        
                        // Calculate smoothed pace (average of recent values)
                        let smoothedPaceInSecondsPerKm = self.recentPaceValues.reduce(0, +) / Double(self.recentPaceValues.count)
                        
                        // IMPORTANT: Always use our standardized formatter with unit preference awareness
                        // This prevents inconsistent unit display
                        self.formattedPace = self.formatPaceFromSeconds(smoothedPaceInSecondsPerKm)
                    } else {
                        // Pace is outside reasonable range, show without smoothing
                        self.formattedPace = self.formatPaceFromSeconds(currentPaceInSecondsPerKm)
                    }
                } else {
                    self.formattedPace = "-'--\""
                }
            }
            .store(in: &cancellables)
        
        // Calories formatter
        $calories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] calories in
                let formatter = NumberFormatter()
                formatter.maximumFractionDigits = 0
                self?.formattedCalories = formatter.string(from: NSNumber(value: calories)) ?? "0"
            }
            .store(in: &cancellables)
        
        // Heart rate formatter
        $heartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] heartRate in
                if heartRate > 0 {
                    self?.formattedHeartRate = "\(Int(heartRate))"
                } else {
                    self?.formattedHeartRate = "--"
                }
            }
            .store(in: &cancellables)
        
        // Elevation formatter
        $elevationGain
            .receive(on: DispatchQueue.main)
            .sink { [weak self] elevation in
                guard let self = self else { return }
                
                let elevation = self.useMetric
                    ? elevation
                    : elevation.converted(to: UnitLength.feet)
                
                let formatter = NumberFormatter()
                formatter.maximumFractionDigits = 0
                
                self.formattedElevationGain = "\(formatter.string(from: NSNumber(value: elevation.value)) ?? "0") \(self.useMetric ? "m" : "ft")"
            }
            .store(in: &cancellables)
        
        $elevationLoss
            .receive(on: DispatchQueue.main)
            .sink { [weak self] elevation in
                guard let self = self else { return }
                
                let elevation = self.useMetric
                    ? elevation
                    : elevation.converted(to: UnitLength.feet)
                
                let formatter = NumberFormatter()
                formatter.maximumFractionDigits = 0
                
                self.formattedElevationLoss = "\(formatter.string(from: NSNumber(value: elevation.value)) ?? "0") \(self.useMetric ? "m" : "ft")"
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Watch Connectivity
    
    private func setupWatchConnectivity() {
        // Check if WatchConnectivity is supported
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("📱 WCSession activated in RunTrackingEngine")
        }
    }
    
    // MARK: - WCSession Delegate Methods
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            print("📱 WCSession activated")
            
            // Update MetricsCoordinator with watch status
            metricsCoordinator?.updateWatchStatus(
                isAvailable: session.isPaired && session.isWatchAppInstalled,
                isReachable: session.isReachable
            )
            
            // Send initial status update
            sendTrackingStatusUpdate()
        } else if let error = error {
            print("📱 WCSession activation failed: \(error.localizedDescription)")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        // Handle on main thread to avoid threading issues
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let reachable = session.isReachable
            print("📱⌚️ Watch reachability changed: \(reachable)")
            
            // Update watch health status
            self.watchSystemHealthy = reachable
        
        // Update MetricsCoordinator with watch status
            self.metricsCoordinator?.updateWatchStatus(
            isAvailable: session.isPaired && session.isWatchAppInstalled,
            isReachable: session.isReachable
        )
        
            // Update tracking state based on new health info
            self.updateTrackingState()
            
            // Send status update when watch becomes reachable
            if session.isReachable {
                self.sendTrackingStatusUpdate()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        // Check message type for Join-related and SyncWorkout cases
        let messageType = message["type"] as? String ?? ""
        let isJoinedWorkout = isJoiningExistingWorkout
        
        // Don't intercept requestActiveRunningWorkout - let it pass through to RunningWorkoutManager
        if messageType == "requestActiveRunningWorkout" {
            print("📱 RunTrackingEngine: Handling requestActiveRunningWorkout directly")
            handleActiveWorkoutRequest(replyHandler: replyHandler)
            return
        }
        

        
        // Handle syncWorkoutData specifically for already-joined workouts
        if messageType == "syncWorkoutData" && (runState == .running || runState == .paused) {
            // Send enhanced response for syncWorkoutData
            let response: [String: Any] = [
                "status": "received",
                "timestamp": Date().timeIntervalSince1970,
                "isPhoneTracking": true,
                "hasGoodLocationData": hasGoodLocationData,
                "isPrimaryForHeartRate": isPrimaryForHeartRate,
                "isPrimaryForDistance": isPrimaryForDistance,
                "isPrimaryForPace": isPrimaryForPace,
                "joinAcknowledged": true  // Send acknowledgment that we've joined
            ]
            
            // Mark that we've acknowledged the join
            watchHasAcknowledgedJoin = true
            
            // Reply with enhanced response immediately
            replyHandler(response)
            
            // Process the actual message on the main thread to avoid UI freezes
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.processWatchMessage(message)
            }
            return
        }
        
        // Handle heartbeat messages
        if messageType == "heartbeat" {
            // Extract timestamp to calculate lag
            let timestamp = message["timestamp"] as? Double ?? 0
            let now = Date().timeIntervalSince1970
            let lag = now - timestamp
            
            // Only log in debug mode to reduce console spam
            #if DEBUG
            print("📱 Received heartbeat from watch (lag: \(String(format: "%.2f", lag))s)")
            #endif
            
            // Reply with acknowledgment immediately
            replyHandler([
                "status": "success", 
                "timestamp": now,
                "phoneState": runState.rawValue,
                "joinAcknowledged": isJoinedWorkout // Include join status in heartbeat responses too
            ])
            return
        }
        
        // For all other messages, send a basic acknowledgment
        let immediateAck: [String: Any] = [
            "status": "received",
            "timestamp": Date().timeIntervalSince1970,
            "joinAcknowledged": isJoinedWorkout // Include join status in all responses
        ]
        
        // Reply with acknowledgment immediately
        replyHandler(immediateAck)
        
        // Process the actual message on the main thread to avoid UI freezes
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.processWatchMessage(message)
        }
    }
    
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
        
        // Rate limit processing of watch messages to reduce CPU usage
        // Only apply rate limiting for non-critical messages during an ongoing workout
        let now = Date()
        let messageType = message["type"] as? String ?? ""
        
        print("📱 Message type: '\(messageType)'")
        print("📱 Current run state: \(runState.rawValue)")
        print("📱 Is indoor mode: \(isIndoorMode)")
        
        // Apply rate limiting for syncWorkoutData messages during an ongoing workout
        if messageType == "syncWorkoutData" &&
           self.runState != .notStarted &&
           !isForcedUpdate &&
           now.timeIntervalSince(lastWorkoutUpdateTime) < 0.3 {
            // Skip this update - we'll get another one soon enough
            print("📱 Skipping syncWorkoutData due to rate limiting")
            return
        }
        
        // Reset forced update flag if it was set
        if isForcedUpdate {
            isForcedUpdate = false
        }
        
        // Update last process time for rate limiting
        lastWorkoutUpdateTime = now
        
        // Track the response from watch to see if it acknowledges our join
        if let status = message["status"] as? String, status == "joinAcknowledged" {
            print("📱 Watch has acknowledged our join request!")
            watchHasAcknowledgedJoin = true
            return
        }
        
        // Log message type
        if let type = message["type"] as? String {
            // Reduce verbosity once the watch has acknowledged our join
            let isJoinAcknowledged = watchHasAcknowledgedJoin
            
            if !isJoinAcknowledged {
                print("📱 Processing message from watch with type: \(type)")
            }
            
            // Handle syncWorkoutData specifically for ongoing workouts
            if type == "syncWorkoutData" && (runState == .running || runState == .paused) {
                // Only print detailed logs if the watch hasn't acknowledged join yet
                if !isJoinAcknowledged {
                    print("📱 Processing syncWorkoutData for ongoing workout")
                }
                
                // Debug: Log primary settings
                print("📱 Primary settings: Distance=\(isPrimaryForDistance), Pace=\(isPrimaryForPace), HR=\(isPrimaryForHeartRate), Cadence=\(isPrimaryForCadence)")
                
                // Heart rate is always received from watch (watch is primary for heart rate)
                if let watchHeartRate = message["heartRate"] as? Double, watchHeartRate > 0 {
                    print("📱 Updating heart rate from watch: \(watchHeartRate) bpm")
                    
                    // Use updateHeartRate method to ensure all metrics are updated and coordinated
                    DispatchQueue.main.async {
                        // Update heart rate using the standard method which handles:
                        // - Heart rate metrics (average, max)
                        // - Heart rate zone
                        // - Formatted values
                        // - Sync with workout manager and watch
                        // - UI notifications
                        self.updateHeartRate(watchHeartRate)
                        
                        // Log the update
                        print("❤️ Heart rate updated from watch: \(Int(watchHeartRate)) bpm")
                    }
                }
                // Only process if we're not primary for these metrics
                if !isPrimaryForCadence || !isPrimaryForDistance {
                    print("📱 Processing syncWorkoutData metrics from watch")
                    
                    
                    
                    if !isPrimaryForCadence {
                        if let watchCadence = message["cadence"] as? Double, watchCadence > 0 {
                            print("📱 Updating cadence from watch: \(watchCadence)")
                            self.cadence = watchCadence
                        }
                    }
                    
                    if !isPrimaryForDistance {
                        if let watchDistance = message["distance"] as? Double, watchDistance > 0 {
                            print("📱 Watch distance: \(watchDistance)m, Current distance: \(self.distance.value)m")
                            // Only update if watch distance is greater
                            if watchDistance > self.distance.value {
                                print("📱 Updating distance from watch: \(watchDistance)m")
                                self.distance = Measurement(value: watchDistance, unit: UnitLength.meters)
                            }
                        }
                    }
                    
                    // Update formatted values
                    updateFormattedValues()
                    
                    // Notify observers of updated metrics
                    NotificationCenter.default.post(name: .didUpdateRunMetrics, object: nil)
                    print("📱 Posted didUpdateRunMetrics notification")
                    
                    // Post notification for successful watch communication
                    NotificationCenter.default.post(name: NSNotification.Name("SuccessfulWatchCommunication"), object: nil)
                } else {
                    print("📱 Skipping syncWorkoutData - phone is primary for all metrics")
                }
                
                // Record successful communication
                return
            }
            
            // Handle distance request from watch
            if type == "requestCurrentDistance" {
                print("📱 Received distance request from watch")
                
                // Send current distance back to watch
                let response: [String: Any] = [
                    "responseType": "distanceResponse",
                    "distance": distance.value,
                    "timestamp": Date().timeIntervalSince1970
                ]
                
                if WCSession.default.isReachable {
                    WCSession.default.sendMessage(response, replyHandler: nil, errorHandler: { error in
                        print("📱 Error sending distance to watch: \(error.localizedDescription)")
                    })
                } else {
                    print("📱 Watch not reachable to send distance data")
                }
                return
            }
            

            
            // Handle indoor run state change commands
            if type == "indoorRunStateChange" {
                print("📱 🎯 RECEIVED INDOOR RUN STATE CHANGE COMMAND FROM WATCH!")
                print("📱 🎯 Full message: \(message)")
                
                if let command = message["command"] as? String {
                    print("📱 🎯 Indoor run state change command: \(command)")
                    print("📱 🎯 Current run state: \(runState.rawValue)")
                    
                    // Set flag to prevent sending messages back to watch
                    isHandlingRemoteStateChange = true
                    defer { isHandlingRemoteStateChange = false }
                    
                    // Post notification to TreadmillRunViewController to handle indoor-specific logic
                    let notificationUserInfo: [String: Any] = [
                        "command": command,
                        "message": message
                    ]
                    
                    NotificationCenter.default.post(
                        name: NSNotification.Name("IndoorRunStateChangeReceived"),
                        object: nil,
                        userInfo: notificationUserInfo
                    )
                    
                    print("📱 🎯 Posted IndoorRunStateChangeReceived notification to TreadmillRunViewController")
                    
                    // Also update the engine state directly for consistency
                    switch command {
                    case "paused":
                        if runState == .running {
                            print("📱 🎯 Pausing run from watch command")
                            // Call the proper pauseRun method which handles all the logic correctly
                            // The isHandlingRemoteStateChange flag will prevent sending updates back to watch
                            pauseRun()
                        } else {
                            print("📱 🎯 Ignoring pause command - not currently running (state: \(runState.rawValue))")
                        }
                    case "inProgress":
                        if runState == .paused {
                            print("📱 🎯 Resuming run from watch command")
                            // Call the proper resumeRun method which handles all the logic correctly
                            // The isHandlingRemoteStateChange flag will prevent sending updates back to watch
                            resumeRun()
                        } else {
                            print("📱 🎯 Ignoring resume command - not currently paused (state: \(runState.rawValue))")
                        }
                    case "completed":
                        if runState == .running || runState == .paused {
                            print("📱 🎯 Ending run from watch command")
                            // Call the proper endRun method which handles all the logic correctly
                            // The isHandlingRemoteStateChange flag will prevent sending updates back to watch
                            endRun()
                            
                        } else {
                            print("📱 🎯 Ignoring end command - not currently active (state: \(runState.rawValue))")
                        }
                    default:
                        print("📱 🎯 Unknown indoor run state change command: \(command)")
                    }
                } else {
                    print("📱 🎯 Indoor run state change message missing command")
                    print("📱 🎯 Available keys: \(message.keys)")
                }
                return
            } else if isIndoorMode {
                print("📱 🎯 Indoor mode active but message type is '\(type)', not 'indoorRunStateChange'")
            }
            // Handle outdoor run state change commands
            if type == "outdoorRunStateChange" {
                print("📱 🎯 RECEIVED OUTDOOR RUN STATE CHANGE COMMAND FROM WATCH!")
                print("📱 🎯 Full message: \(message)")
                
                if let command = message["command"] as? String {
                    print("📱 🎯 Outdoor run state change command: \(command)")
                    print("📱 🎯 Current run state: \(runState.rawValue)")
                    
                    // Set flag to prevent sending messages back to watch
                    isHandlingRemoteStateChange = true
                    defer { isHandlingRemoteStateChange = false }
                    
                    // Post notification to OutdoorRunViewController to handle outdoor-specific logic
                    let notificationUserInfo: [String: Any] = [
                        "command": command,
                        "message": message
                    ]
                    
                    NotificationCenter.default.post(
                        name: NSNotification.Name("OutdoorRunStateChangeReceived"),
                        object: nil,
                        userInfo: notificationUserInfo
                    )
                    
                    print("📱 🎯 Posted OutdoorRunStateChangeReceived notification to OutdoorRunViewController")
                    
                    // Also update the engine state directly for consistency
                    switch command {
                    case "paused":
                        if runState == .running {
                            print("📱 🎯 Pausing outdoor run from watch command")
                            // Call the proper pauseRun method which handles all the logic correctly
                            // The isHandlingRemoteStateChange flag will prevent sending updates back to watch
                            pauseRun()
                        } else {
                            print("📱 🎯 Ignoring pause command - not currently running (state: \(runState.rawValue))")
                        }
                    case "inProgress":
                        if runState == .paused {
                            print("📱 🎯 Resuming outdoor run from watch command")
                            // Call the proper resumeRun method which handles all the logic correctly
                            // The isHandlingRemoteStateChange flag will prevent sending updates back to watch
                            resumeRun()
                        } else {
                            print("📱 🎯 Ignoring resume command - not currently paused (state: \(runState.rawValue))")
                        }
                    case "completed":
                        if runState == .running || runState == .paused {
                            print("📱 🎯 Ending outdoor run from watch command")
                            // Call the proper endRun method which handles all the logic correctly
                            // The isHandlingRemoteStateChange flag will prevent sending updates back to watch
                            endRun()
                        } else {
                            print("📱 🎯 Ignoring end command - not currently active (state: \(runState.rawValue))")
                        }
                    default:
                        print("📱 🎯 Unknown outdoor run state change command: \(command)")
                    }
                } else {
                    print("📱 🎯 Outdoor run state change message missing command")
                    print("📱 🎯 Available keys: \(message.keys)")
                }
                return
            } else if !isIndoorMode {
                print("📱 🎯 Outdoor mode active but message type is '\(type)', not 'outdoorRunStateChange'")
            }
            
        } else if let requestType = message["requestType"] as? String {
            print("📱 Processing request from watch: \(requestType)")
        
        // Handle active workout request with old format
            if requestType == "activeWorkoutRequest" {
                // Just update context with current state
                updateApplicationContext()
            return
            }
        } else {
            print("📱 Processing message from watch: \(message)")
        }
        
        // Handle incoming metrics from watch
        if let metrics = message["metrics"] as? [String: Any] {
            // Process metrics using coordinator
            metricsCoordinator?.processWatchMetrics(metrics: metrics)
            
            // Update application context to sync back our state
            updateApplicationContext()
            return
        }
        // Handle requestDatabaseSave flag from watch completion messages
        if let requestDatabaseSave = message["requestDatabaseSave"] as? Int, requestDatabaseSave == 1 {
            print("📱 Watch is requesting database save - saving run to Parse")
            
            // Save the run to Parse
            saveRun()
            
            // Send confirmation back to watch
            if WCSession.default.isReachable {
                let confirmation: [String: Any] = [
                    "type": "databaseSaveConfirmation",
                    "status": "saved",
                    "timestamp": Date().timeIntervalSince1970
                ]
                
                WCSession.default.sendMessage(confirmation, replyHandler: nil, errorHandler: { error in
                    print("📱 Error sending database save confirmation to watch: \(error.localizedDescription)")
                })
            }
            
            return
        }
        // Default action - ensure application context is updated
        updateApplicationContext()
        
        print("📱 === END PROCESSING WATCH MESSAGE DEBUG ===")
    }
    
    // New method to handle treadmill updates on main thread
    private func handleTreadmillUpdateOnMainThread(_ message: [String: Any]) {
        // This is just a wrapper to ensure this happens on main thread
        handleTreadmillUpdate(message, replyHandler: { _ in })
    }
    
    // New method to handle watch active workout on main thread
    private func handleWatchActiveWorkoutOnMainThread(_ message: [String: Any]) {
        // This is just a wrapper to ensure this happens on main thread
        handleWatchActiveWorkout(message, replyHandler: { _ in })
    }
    
    // MARK: - WCSession Delegate Methods
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("📱 Received application context from watch: \(applicationContext)")
        
        // Extract watch tracking status if available
        if let isWatchTracking = applicationContext["isWatchTracking"] as? Bool {
            self.isWatchTracking = isWatchTracking
            
            // Update metrics coordinator with new watch tracking status
            metricsCoordinator?.updatePolicy(
                isIndoor: isIndoorMode,
                hasGoodGPS: hasGoodLocationData,
                isWatchTracking: isWatchTracking
            )
        }
    }
    
    // Handle request for active workout data
    public func handleActiveWorkoutRequest(replyHandler: @escaping ([String: Any]) -> Void) {
        print("📱 Processing active workout request...")
        
        // Check if we have an active workout
        if runState == .running || runState == .paused {
            print("📱 Found active workout, sending data to watch")
            
            let workoutData: [String: Any] = [
                "hasActiveWorkout": true,
                "id": workoutId.uuidString,
                "workoutType": "running",
                "state": runState == .running ? "inProgress" : (runState == .paused ? "paused" : "notStarted"),
                "runState": runState.rawValue,
                "elapsedTime": elapsedTime,
                "distance": distance.value,
                "pace": pace.value,
                "calories": calories,
                "heartRate": heartRate,
                "isIndoorMode": isIndoorMode
            ]
            
            replyHandler(workoutData)
        } else {
            print("📱 No active workout found")
            
            let response: [String: Any] = [
                "hasActiveWorkout": false,
                "state": "notStarted",
                "runState": "notStarted"
            ]
            
            replyHandler(response)
        }
    }
    
    // New helper method to create workout response
    private func createActiveWorkoutResponse() -> [String: Any] {
        // Check if workout is active (specifically in inProgress or paused state)
        let hasActiveWorkout = (runState == .running || runState == .paused)
        
        print("📱 Run state: \(runState.rawValue), hasActiveWorkout: \(hasActiveWorkout)")
        
        // If no active workout, send a simple response
        if !hasActiveWorkout {
            return [
                "success": true,
                "hasActiveWorkout": false,
                "workoutActive": false,
                "useImperialUnits": !useMetric,
                "timestamp": Date().timeIntervalSince1970
            ]
        }
        
        // We have an active workout - prepare a complete response with all necessary data
        // Generate a consistent ID based on start time and run type
        let startTimeComponent = String(format: "%.0f", startDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970)
        let runTypeComponent = runType.rawValue
        let workoutId = "\(runTypeComponent)-\(startTimeComponent)"
        
        // Create metrics for both nested and top-level use
        let metrics: [String: Any] = [
            "distance": distance.value,
            "elapsedTime": elapsedTime,
            "duration": elapsedTime,
            "pace": pace.value,
            "calories": calories,
            "heartRate": heartRate,
            "cadence": cadence
        ]
            
        // Create a comprehensive workout data payload
        let workoutData: [String: Any] = [
            "type": "workoutUpdate",
            "hasActiveWorkout": true,
            "workoutActive": true,
            "id": workoutId,
            "runState": runState.rawValue,
            "state": runState == .running ? "inProgress" : runState.rawValue,
            "workoutType": "run",
            "runType": runType.rawValue,
            "metrics": metrics,
            "distance": distance.value,
            "elapsedTime": elapsedTime,
            "pace": pace.value,
            "calories": calories,
            "heartRate": heartRate,
            "cadence": cadence,
            "isIndoor": isIndoorMode,
            "isDashboardMode": isDashboardMode,
            "isWatchTracking": isWatchTracking,
            "timestamp": Date().timeIntervalSince1970,
            "useImperialUnits": !useMetric,
            "isPrimaryForDistance": isPrimaryForDistance,
            "isPrimaryForPace": isPrimaryForPace,
            "isPrimaryForHeartRate": isPrimaryForHeartRate,
            "isPrimaryForCalories": isPrimaryForCalories,
            "isPrimaryForCadence": isPrimaryForCadence,
            "hasGoodLocationData": hasGoodLocationData
        ]
        
        // Create final response with both nested and top-level properties
        // to ensure compatibility with different watch components
        let response: [String: Any] = [
            "success": true,
            "hasActiveWorkout": true,
            "workoutActive": true,
            "workoutData": workoutData,
            // Include top-level properties as well for components that expect them
            "id": workoutId,
            "runState": runState.rawValue,
            "state": runState == .running ? "inProgress" : runState.rawValue,
            "workoutType": "run",
            "runType": runType.rawValue,
            "elapsedTime": elapsedTime,
            "distance": distance.value,
            "pace": pace.value,
            "calories": calories,
            "heartRate": heartRate,
            "cadence": cadence,
            "metrics": metrics,
            "timestamp": Date().timeIntervalSince1970,
            "useImperialUnits": !useMetric,
            "isIndoor": isIndoorMode,
            "isDashboardMode": isDashboardMode,
            "isWatchTracking": isWatchTracking,
            "isPrimaryForDistance": isPrimaryForDistance,
            "isPrimaryForPace": isPrimaryForPace,
            "isPrimaryForHeartRate": isPrimaryForHeartRate,
            "isPrimaryForCalories": isPrimaryForCalories,
            "isPrimaryForCadence": isPrimaryForCadence,
            "hasGoodLocationData": hasGoodLocationData
        ]
        
        print("📱 Created active workout data for watch (ID \(workoutId)): state=\(workoutData["state"] as! String), distance=\(distance.value)m")
        
        return response
    }
    
    // Properties to track workout sync frequency
    private var lastWorkoutSyncTime: TimeInterval = 0
    private var identicalSyncCount: Int = 0
    private var lastSyncSignature: String = ""
    
    // Handle workout data sync from watch
    private func handleWorkoutDataSync(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // CRITICAL FIX: Process incoming watch data on main thread to avoid UI freezes
        // and "Publishing changes from background threads" errors
        
        // Create a simple response immediately to prevent watch from waiting
        let simpleResponse: [String: Any] = [
            "status": "acknowledged", 
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Send immediate acknowledgment to unblock the watch
        replyHandler(simpleResponse)
        
        // Process the rest of the data on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.processWatchSyncData(message)
        }
    }
    
    // New method to process the watch data on the main thread
    private func processWatchSyncData(_ message: [String: Any]) {
        let now = Date().timeIntervalSince1970
        
        // Track identical messages to prevent sync loops
        let messageSignature = message.description.prefix(100).description
        
        if messageSignature == lastSyncSignature && now - lastWorkoutSyncTime < 5.0 {
            identicalSyncCount += 1
            if identicalSyncCount > 3 {
                // Break potential sync loops
                print("⚠️ Breaking potential sync loop - identical messages", identicalSyncCount)
                return
            }
        } else {
            identicalSyncCount = 0
            lastSyncSignature = messageSignature
        }
        lastWorkoutSyncTime = now
        
        // Extract watch active status
        if let watchIsTracking = message["isWatchTracking"] as? Bool {
            receivedWatchStatusUpdate = true
            isWatchTracking = watchIsTracking
        }
        
        // Check for unit preference from watch
        if let useImperialUnits = message["useImperialUnits"] as? Bool {
            // Update our unit preference to match watch
            useMetric = !useImperialUnits
            print("📱 Received unit preference from watch: imperial=\(useImperialUnits), setting metric=\(useMetric)")
        }
        
        // Extract metrics from Watch
        let watchDistance = message["distance"] as? Double ?? 0
        let watchTime = message["elapsedTime"] as? TimeInterval ?? 0
        let watchPace = message["pace"] as? Double ?? 0
        let watchHeartRate = message["heartRate"] as? Double ?? 0
        let watchCalories = message["calories"] as? Double ?? 0
        let watchCadence = message["cadence"] as? Double ?? 0
        // Around line 1750, add:
        let watchVerticalOscillation = message["verticalOscillation"] as? Double ?? 0
        let watchGroundContactTime = message["groundContactTime"] as? Double ?? 0
        let watchPrimaryForDistance = message["isPrimaryForDistance"] as? Bool ?? false
        let watchPrimaryForPace = message["isPrimaryForPace"] as? Bool ?? false
        let watchPrimaryForHeartRate = message["isPrimaryForHeartRate"] as? Bool ?? true
        let watchPrimaryForCalories = message["isPrimaryForCalories"] as? Bool ?? false
        let watchPrimaryForCadence = message["isPrimaryForCadence"] as? Bool ?? true
        
        // Update our primacy flags based on run type and watch status
        if isIndoorMode {
            // For indoor runs, watch is generally primary for most metrics
            isPrimaryForDistance = false
            isPrimaryForPace = false
            isPrimaryForHeartRate = false
            isPrimaryForCalories = false
            isPrimaryForCadence = false
            
            // Enable dashboard mode for indoor runs
            isDashboardMode = true
            
            print("📱 Indoor run: Watch is primary for metrics, phone in dashboard mode")
        } else {
            // For outdoor runs, phone is typically primary for distance/pace due to GPS
            // but watch is better for heart rate and cadence
            isPrimaryForDistance = hasGoodLocationData
            isPrimaryForPace = hasGoodLocationData
            isPrimaryForHeartRate = false // Watch always better for HR
            isPrimaryForCalories = false // Watch typically better for calories
            isPrimaryForCadence = false // Watch better for cadence
            
            isDashboardMode = false
            
            print("📱 Outdoor run: Phone primary for distance/pace, watch for HR/cadence")
        }
        
        // Handle metrics updates based on primacy
        if !isPrimaryForDistance && watchDistance > 0 {
            print("📊 Updated distance from watch: \(watchDistance)m")
            distance = Measurement(value: watchDistance, unit: UnitLength.meters)
        }
        
        // if !isPrimaryForPace && watchPace > 0 {
        //     print("📊 Updated pace from watch: \(watchPace)s/km")
        //         pace = Measurement(value: watchPace, unit: UnitSpeed.minutesPerKilometer)
        // }
        
        // Heart rate is always received from watch (watch is primary for heart rate)
        if watchHeartRate > 0 {
            print("📊 Updated heart rate from watch: \(watchHeartRate) bpm")
            // Use updateHeartRate method to ensure all metrics are updated and coordinated
            updateHeartRate(watchHeartRate)
        }
            
        if !isPrimaryForCalories && watchCalories > 0 {
            print("📊 Updated calories from watch: \(watchCalories)")
                calories = watchCalories
            }
        
        if !isPrimaryForCadence && watchCadence > 0 {
            print("📊 Updated cadence from watch: \(watchCadence)")
            cadence = watchCadence
        }
        
        // Around line 1808, add:
        if watchVerticalOscillation > 0 {
            print("📊 Updated vertical oscillation from watch: \(watchVerticalOscillation)cm")
            verticalOscillation = Measurement(value: watchVerticalOscillation, unit: UnitLength.centimeters)
        }

        if watchGroundContactTime > 0 {
            print("📊 Updated ground contact time from watch: \(watchGroundContactTime)s")
            groundContactTime = watchGroundContactTime
        }
        
        // Always accept time updates from watch if it's tracking
        if isWatchTracking && watchTime > 0 && (isIndoorMode || runState == .paused) {
            print("📊 Updated elapsed time from watch: \(watchTime)s")
            elapsedTime = watchTime
            }
            
            // Update formatted values after receiving updates
            updateFormattedValues()
        
        // Update application context asynchronously
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateApplicationContext()
        }
    }
    
    // Update application context with current workout state
    private var lastApplicationContextUpdateTime: TimeInterval = 0
    private let minApplicationContextUpdateInterval: TimeInterval = 1.0 // Minimum 1 second between updates
    
    // CRITICAL FIX: Tracks consecutive communication failures
    private var watchCommFailureCount = 0
    private let maxWatchCommFailures = 3 // After this many failures, we'll switch to an alternative approach
    private var lastWatchConnectivityCheck: TimeInterval = 0
    private let watchConnectivityCheckInterval: TimeInterval = 5.0 // Check connectivity every 5 seconds max
    
    public func updateApplicationContext() {
        // CRITICAL FIX: Don't send updates to watch when handling remote state changes
        // This prevents infinite loops where watch pauses -> phone processes -> phone sends update -> watch resumes
        if isHandlingRemoteStateChange {
            print("📱 🎯 Skipping updateApplicationContext - handling remote state change")
            return
        }
        
        // CRITICAL FIX: Ensure we're on the main thread when updating WCSession
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.updateApplicationContext()
            }
            return
        }
        
        let session = WCSession.default
        let currentTime = Date().timeIntervalSince1970
        
        // CRITICAL FIX: Throttle application context updates to prevent UI freezing
        // Only allow updates once per second maximum
        if currentTime - lastApplicationContextUpdateTime < minApplicationContextUpdateInterval {
            return // Skip this update to prevent overloading the communication channel
        }
        lastApplicationContextUpdateTime = currentTime
        
        // CRITICAL FIX: Check and track watch connectivity to recover from lost connections
        // Only check connectivity periodically to avoid excessive overhead
        if currentTime - lastWatchConnectivityCheck > watchConnectivityCheckInterval {
            lastWatchConnectivityCheck = currentTime
            let isReachable = session.activationState == .activated && session.isPaired && 
                               session.isWatchAppInstalled && session.isReachable
            
            if !isReachable {
                print("⚠️ Watch connectivity issue detected: activationState=\(session.activationState.rawValue), " + 
                      "isPaired=\(session.isPaired), isWatchAppInstalled=\(session.isWatchAppInstalled), " + 
                      "isReachable=\(session.isReachable)")
            } else {
                // Reset failure count when reachable again
                if watchCommFailureCount > 0 {
                    print("✅ Watch connectivity restored after \(watchCommFailureCount) failures")
                    watchCommFailureCount = 0
                }
            }
        }
        
        // Early return if basic connectivity requirements aren't met
        // We'll still keep tracking on the phone, just won't try to communicate
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else {
            // Don't count these as failures since they're expected configuration states
            return
        }
        
        // Calculate pace as SPEED (meters/second) for watch communication
        // Both phone and watch internally store pace as speed, then convert for display
        let speedInMetersPerSecond: Double
        
        if distance.value > 0 && elapsedTime > 0 {
            // Calculate speed in m/s (distance divided by time)
            speedInMetersPerSecond = distance.value / elapsedTime
            
            // Log the calculated pace value for debugging (in both m/s and min/mile or min/km)
            let paceInSecondsPerKm = speedInMetersPerSecond > 0 ? 1000.0 / speedInMetersPerSecond : 0
            let paceInSecondsPerMile = paceInSecondsPerKm * 1.60934
            let paceMinutes = Int(paceInSecondsPerMile / 60)
            let paceSeconds = Int(paceInSecondsPerMile.truncatingRemainder(dividingBy: 60))
            print("🔄 Phone sending pace: \(speedInMetersPerSecond) m/s = \(paceMinutes)'\(String(format: "%02d", paceSeconds))\" per \(useMetric ? "km" : "mile")")
        } else {
            speedInMetersPerSecond = pace.value
        }
        
        // Ensure speed value is reasonable (not too slow or too fast)
        // 0.5 m/s = ~33:20 min/mile (very slow walk)
        // 6.0 m/s = ~2:47 min/mile (very fast run)
        let validSpeedValue = max(min(speedInMetersPerSecond, 6.0), 0.5)
        
        // Generate a consistent workout ID
        let startTimeComponent = String(format: "%.0f", Date().timeIntervalSince1970)
        let runTypeComponent = runType.rawValue
        let localWorkoutId = "\(runTypeComponent)-\(startTimeComponent)"
        
        // Set primacy based on run type
        let isOutdoorRun = !isIndoorMode
        let watchIsPrimary = isIndoorMode || !hasGoodLocationData || isWatchTracking
        
        // Determine primary device for each metric based on run type
        if isIndoorMode && !isPrimaryForDistance {
            // For indoor runs, defer to watch for all metrics
            isPrimaryForDistance = false
            isPrimaryForPace = false
            isPrimaryForHeartRate = false
            isPrimaryForCalories = false
            isPrimaryForCadence = false
            isDashboardMode = true
        } else if isOutdoorRun && hasGoodLocationData {
            // For outdoor runs with good GPS, phone is primary for distance/pace
            isPrimaryForDistance = true
            isPrimaryForPace = true
            isPrimaryForHeartRate = false // Watch always better for HR
            isPrimaryForCalories = hasGoodLocationData // Only if we have good GPS data
            isPrimaryForCadence = false // Watch better for cadence
            isDashboardMode = false
        }
        
        // Create context data with all metrics and primacy information
        var contextData: [String: Any] = [
            "type": "workoutUpdate",
            "runState": runState.rawValue,
            "state": runState == .running ? "inProgress" : runState.rawValue,
            "id": self.workoutId.uuidString, // Use instance variable, not local variable
            "workoutType": "run",
            "elapsedTime": Double(elapsedTime), // Ensure it's Double
            "distance": Double(distance.value), // Ensure it's Double
            "calories": Double(calories), // Ensure it's Double
            "heartRate": Double(heartRate), // Ensure it's Double
            "cadence": Double(cadence), // Ensure it's Double
            "runType": runType.rawValue, // String
            "isIndoor": Bool(isIndoorMode), // Ensure it's Bool
            "isDashboardMode": Bool(isDashboardMode), // Ensure it's Bool
            "isWatchTracking": Bool(isWatchTracking), // Ensure it's Bool
            "timestamp": Double(Date().timeIntervalSince1970), // Double
            "useImperialUnits": Bool(!useMetric), // Ensure it's Bool
            "isPrimaryForDistance": Bool(isPrimaryForDistance), // Ensure it's Bool
            "isPrimaryForPace": Bool(isPrimaryForPace), // Ensure it's Bool
            "isPrimaryForHeartRate": Bool(isPrimaryForHeartRate), // Ensure it's Bool
            "isPrimaryForCalories": Bool(isPrimaryForCalories), // Ensure it's Bool
            "isPrimaryForCadence": Bool(isPrimaryForCadence) // Ensure it's Bool
        ]
        
        // Add group run details if needed
        if isGroupRun {
            contextData["isGroupRun"] = true
            contextData["isHosting"] = isHostingGroupRun
            
            if let groupId = groupRunId {
                contextData["groupRunId"] = groupId
            }
        }
        // In the updateApplicationContext method, add:
        if verticalOscillation.value > 0 {
            contextData["verticalOscillation"] = verticalOscillation.value
        }

        if groundContactTime > 0 {
            contextData["groundContactTime"] = groundContactTime
        }
        // Log what we're sending
  
        print("📱 Primary status: distance=\(isPrimaryForDistance), pace=\(isPrimaryForPace), HR=\(isPrimaryForHeartRate), indoor=\(isIndoorMode)")
        
        // CRITICAL FIX: Use main thread for WCSession calls to prevent "Publishing changes from background threads" errors
        // IMPORTANT: updateApplicationContext works even when watch is not reachable
        // It will be delivered when the watch app becomes available
        // Only skip if session is not activated at all
        guard session.activationState == .activated else {
            print("⚠️ Watch session not activated (state: \(session.activationState.rawValue)) - skipping update")
            return
        }
        
        // Log reachability status but don't block updates
        if !session.isReachable {
            print("ℹ️ Watch not reachable - using updateApplicationContext (will deliver when watch app opens)")
        }
        
        // Create a weak reference to self to avoid retain cycles
        weak var weakSelf = self
        
        // Set up a timeout in case the operation takes too long
        let timeoutWorkItem = DispatchWorkItem {
            // This will execute if the timeout is reached
            if let strongSelf = weakSelf {
                strongSelf.watchCommFailureCount += 1
                print("⚠️ Watch communication timed out (failure #\(strongSelf.watchCommFailureCount))")
            }
        }
        
        // Schedule the timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: timeoutWorkItem)
        
        // Always perform the actual WCSession call on the main thread
        // This is already happening since we checked Thread.isMainThread at the start
        do {
            try WCSession.default.updateApplicationContext(contextData)
            
            // Cancel the timeout since we succeeded
            timeoutWorkItem.cancel()
            
            // Reset failure counter if we had previous failures
            if watchCommFailureCount > 0 {
                print("✅ Watch communication restored after \(watchCommFailureCount) failures")
                watchCommFailureCount = 0
            }
        } catch {
            // Handle errors immediately
            timeoutWorkItem.cancel()
            watchCommFailureCount += 1
            print("⚠️ Error updating application context (failure #\(watchCommFailureCount)): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Initial setup to prepare the run tracker
    func setup() {
        // Request permissions before starting (location and HealthKit including heart rate)
        requestPermissions()
        
        // Apply current run settings
        loadSettings()
        
        // Apply screen settings
        if screenAlwaysOn {
            UIApplication.shared.isIdleTimerDisabled = true
        } else {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        
        // Initialize metrics for this run session
        cadence = 0
        elapsedTime = 0
        elevationGain = Measurement(value: 0, unit: UnitLength.meters)
        elevationLoss = Measurement(value: 0, unit: UnitLength.meters)
        
        // Reset collections
        locationList = []
        routeAnnotations = []
        paceHistory = []
        heartRateReadings = []
        
        // Set the start time
        startDate = Date()
        pauseDate = nil
        totalPausedTime = 0 // Reset accumulated pause duration for new run
        
        // Set the run state to running
        runState = .running
        
        // Start the timer
        startTimer()
        
        // Request location updates for outdoor runs (will be handled by ModernLocationManager)
        if !isIndoorMode {
            locationManager.startTracking()
        }
        
        // Send updates to observers
        NotificationCenter.default.post(name: .didChangeRunState, object: nil, userInfo: ["state": runState.rawValue])
        NotificationCenter.default.post(name: .activityDidStart, object: self)
        
        // Generate a new workout ID
        workoutId = UUID()
        
        // Send initial update to watch
        updateApplicationContext()
        
        // Trigger haptic feedback for run start
        triggerNotificationFeedback(.success)
        
        print("📱 Run setup complete - Settings applied: Voice: \(enableVoiceCoaching), AI: \(enableAICoaching), Screen: \(screenAlwaysOn)")
    }
    
    /// Set the current user for data storage
    func setCurrentUser(_ user: String?) {
        self.currentUser = user
    }
    
    /// Set up background capabilities for location tracking
    func setupBackgroundCapabilities() {
        locationManager.startUpdatingLocation()
        setupAudioSessionForBackground()
    }
    
    /// Configure the audio session to help maintain background operation
    private func setupAudioSessionForBackground() {
        // Check if we already have a configured audio session
        if audioSessionConfigured {
            return
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Configure audio session with simpler settings that work reliably
            try audioSession.setCategory(.playback, 
                                         mode: .default, 
                                         options: [.mixWithOthers])
            
            // Set preferred number of channels to 2 for stereo output
            try audioSession.setPreferredOutputNumberOfChannels(2)
            
            // Activate the audio session
            try audioSession.setActive(true)
            
            // Mark as configured so we don't try to set it up again
            audioSessionConfigured = true
            
            print("✅ Audio session configured for stereo playback")
            
            // Setup audio session interruption notification
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAudioSessionInterruption),
                name: AVAudioSession.interruptionNotification,
                object: audioSession
            )
            
            // Start the silent audio playback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.playSilentAudioIfNeeded()
            }
        } catch {
            print("❌ Failed to configure audio session: \(error.localizedDescription)")
            
            // Try a fallback approach if the first attempt fails
            do {
                // Simplest possible approach with stereo
                try audioSession.setCategory(.playback)
                try audioSession.setPreferredOutputNumberOfChannels(2)
                try audioSession.setActive(true)
                audioSessionConfigured = true
                
                print("✅ Audio session configured with fallback settings (stereo)")
            } catch {
                print("❌ Failed to configure audio session with fallback: \(error.localizedDescription)")
                // Silent final fail
            }
        }
    }
    
    /// Start a new run
    public func startRun() {
        print("Starting run of type: \(runType.rawValue)")
        
        // Check for recoverable state first
        if !isJoiningExistingWorkout && checkForRecovery() {
            let alert = UIAlertController(
                title: "Resume Previous Run?",
                message: "Would you like to continue your previous run that was interrupted?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Resume", style: .default) { [weak self] _ in
                self?.recoverFromCache()
            })
            
            alert.addAction(UIAlertAction(title: "Start New", style: .cancel) { [weak self] _ in
                self?.startNewRun()
            })
            
            // Present the alert on the top view controller
            if let topVC = UIApplication.shared.keyWindow?.rootViewController {
                topVC.present(alert, animated: true)
            }
            return
        }
        
        startNewRun()
    }
    
    private func startNewRun() {
        // 🔧 CRITICAL FIX: Initialize parseObject for database save
   
        // 🔧 FIX: Only reset metrics if NOT joining an existing workout
        if !isJoiningExistingWorkout {
            // Make sure metrics are reset to starting values for NEW runs
            distance = Measurement(value: 0, unit: UnitLength.meters)
            pace = Measurement(value: 0, unit: UnitSpeed.minutesPerKilometer)
            calories = 0
            cadence = 0
            elapsedTime = 0
            elevationGain = Measurement(value: 0, unit: UnitLength.meters)
            elevationLoss = Measurement(value: 0, unit: UnitLength.meters)
            
            // Reset collections
            locationList = []
            routeAnnotations = []
            paceHistory = []
            heartRateReadings = []
            
            // Set start time
            startDate = Date()
            pauseDate = nil
            totalPausedTime = 0 // Reset accumulated pause duration for new run
            
            print("📱 Started NEW run - metrics reset to 0")
        } else {
            // When joining existing workout, preserve current metrics but ensure proper state
            print("📱 Joining existing workout - preserving distance: \(distance.value)m, elapsedTime: \(elapsedTime)s")
            
            // Only reset pause-related timers for joined workouts
            pauseDate = nil
            // Don't reset totalPausedTime as it may be part of the existing workout
            
            // Don't reset collections as they may contain existing data
            // Don't reset startDate as it should be set from the watch workout
        }
        
        // Update state
        runState = .running
        
        // Update formatted values
        updateFormattedValues()
        
        // Start timer
        startTimer()
        
        // Request location updates if needed for outdoor runs
        if !isIndoorMode {
            // Start location updates for outdoor run
            locationManager.startUpdatingLocation()
            hasGoodLocationData = false
        }
        
        // Register with background manager
        WorkoutBackgroundManager.shared.registerWorkout(type: "run", engine: self)
        
        // Start lock screen display
        LockScreenManager.shared.startWorkout(type: "run")
        updateLockScreen()
        
        // Send immediate update to watch
        sendWorkoutUpdate()
        
        // Also send tracking status update
        sendTrackingStatusUpdate()
        
        // Notify observers
        NotificationCenter.default.post(name: .activityDidStart, object: self)
        NotificationCenter.default.post(name: .didChangeRunState, object: nil, userInfo: ["state": runState.rawValue])
        
        // Generate a new workout ID when starting a run
        workoutId = UUID()
    }
    
    private func updateLockScreen() {
        let metrics = WorkoutMetrics(
            distance: useMetric ? distance.value / 1609.34 : distance.value / 1609.34, // Convert to miles
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            calories: calories,
            elevationGain: elevationGain.value
        )
        LockScreenManager.shared.updateLockScreen(metrics: metrics)
    }
    
    // MARK: - State Recovery
    
    func checkForRecovery() -> Bool {
        guard let cache = WorkoutBackgroundManager.shared.loadStateCache(),
              cache.type == "run",
              let recoveryState = RunState(rawValue: cache.state),
              recoveryState.isActive else {
            return false
        }
        return true
    }
    
    func recoverFromCache() -> Bool {
        guard let cache = WorkoutBackgroundManager.shared.loadStateCache(),
              cache.type == "run",
              let recoveryState = RunState(rawValue: cache.state),
              recoveryState.isActive else {
            return false
        }
        
        // Restore state and metrics
        runState = recoveryState
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
                distance: 0, // Distance will be recalculated
                timestamp: Date(timeIntervalSince1970: locData["timestamp"] ?? Date().timeIntervalSince1970),
                heartRate: nil,
                cadence: nil
            )
        }
        
        // Clear the cache after successful recovery
        WorkoutBackgroundManager.shared.clearStateCache()
        
        // Resume if we were in progress
        if runState == .running {
            startTimer()
            WorkoutBackgroundManager.shared.registerWorkout(type: "run", engine: self)
        }
        
        return true
    }
    
    /// Start a new run with specified run type
    public func startRun(runType: RunType) {
        // Set the run type first
        self.runType = runType
        
        // Call the main startRun method
        startRun()
    }
    
    private func activateNavigationIfRouteExists() {
        let routePlanner = RoutePlanner.shared
        
        // Only activate if we have a route with waypoints
        if !routePlanner.routePolyline.isEmpty {
            // Set navigation to active and announce first direction
            routePlanner.navigationActive = true
            routePlanner.nextDirectionIndex = 0
            
            // Announce first direction if available and not muted
            if !routePlanner.navigationDirections.isEmpty && !navigationAudioMuted {
                let firstDirection = "Route guidance activated. " + routePlanner.navigationDirections[0]
                
                // Use an utterance for the announcement
                let utterance = AVSpeechUtterance(string: firstDirection)
                utterance.rate = 0.5
                utterance.volume = 1.0
                
                let synthesizer = AVSpeechSynthesizer()
                synthesizer.speak(utterance)
                
                // Also set as coach feedback
                coachFeedback = firstDirection
            } else {
                // **FIXED: Create basic navigation directions if they don't exist**
                generateBasicNavigationDirections()
            }
        }
    }

    // **NEW: Add this simple helper method to RunTrackingEngine**
    private func generateBasicNavigationDirections() {
        let routePlanner = RoutePlanner.shared
        
        guard !routePlanner.routePolyline.isEmpty else {
            print("🗺️ No route available for navigation directions")
            return
        }
        
        let totalDistance = calculateRouteDistance(routePlanner.routePolyline)
        let distanceText = formatDistanceForAnnouncement(totalDistance)
        
        var directions: [String] = []
        directions.append("Follow the planned route for \(distanceText)")
        
        if routePlanner.routePolyline.count > 20 {
            directions.append("Continue following the route, you're making good progress")
            directions.append("You're approaching the end of your route")
        }
        
        directions.append("You have reached the end of your route")
        
        routePlanner.navigationDirections = directions
        routePlanner.nextDirectionIndex = 0
        
        // Announce first direction if not muted
        if !navigationAudioMuted && !directions.isEmpty {
            let firstDirection = "Route guidance activated. " + directions[0]
            
            let utterance = AVSpeechUtterance(string: firstDirection)
            utterance.rate = 0.5
            utterance.volume = 1.0
            
            let synthesizer = AVSpeechSynthesizer()
            synthesizer.speak(utterance)
            
            coachFeedback = firstDirection
        }
        
        print("🗺️ Generated \(directions.count) basic navigation directions")
    }

    // Helper methods for RunTrackingEngine
    private func calculateRouteDistance(_ coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count > 1 else { return 0 }
        
        var totalDistance: Double = 0
        for i in 1..<coordinates.count {
            let prev = CLLocation(latitude: coordinates[i-1].latitude, longitude: coordinates[i-1].longitude)
            let curr = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            totalDistance += prev.distance(from: curr)
        }
        
        return totalDistance
    }

    // MARK: - Formatting Helpers
    
    /// Format duration (TimeInterval in seconds) to HH:MM:SS or MM:SS string
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    /// Format distance (in meters) to string with appropriate unit
    private func formatDistance(_ meters: Double) -> String {
        // Use metric system preference
        let useMetric = UserPreferences.shared.useMetricSystem
        
        if useMetric {
            let km = meters / 1000.0
            return String(format: "%.2f km", km)
        } else {
            let miles = meters / 1609.34
            return String(format: "%.2f mi", miles)
        }
    }
    
    private func formatDistanceForAnnouncement(_ distance: Double) -> String {
        let useMetric = UserDefaults.standard.bool(forKey: "useMetricUnits")
        
        if useMetric {
            if distance >= 1000 {
                return String(format: "%.1f kilometers", distance / 1000)
            } else {
                return String(format: "%.0f meters", distance)
            }
        } else {
            let miles = distance * 0.000621371
            if miles >= 1 {
                return String(format: "%.1f miles", miles)
            } else {
                let feet = distance * 3.28084
                return String(format: "%.0f feet", feet)
            }
        }
    }
    
    
    // Establish initial device coordination roles
    func establishDeviceCoordination() {
        guard runState != .notStarted else { return }
        
        let isIndoor = runType == .treadmillRun
        let wasWatchTracking = isWatchTracking // Remember if watch was tracking before
        
        if isIndoor {
            // For indoor treadmill runs, watch takes precedence for all metrics
            isDashboardMode = true
            isWatchTracking = true
            
            // Set watch as primary for all metrics
            isPrimaryForDistance = false
            isPrimaryForPace = false
            isPrimaryForHeartRate = false
            isPrimaryForCalories = false
            isPrimaryForCadence = false
            
            print("📱 Indoor run: Phone acting as dashboard for treadmill run")
            print("⌚️ Watch will be primary for all tracking metrics")
        } else {
            // For outdoor runs, determine based on GPS quality
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
                    print("📱 Outdoor run (joined from watch) with good GPS: Phone now primary for distance/pace")
                    print("⌚️ Watch primary for heart rate and cadence")
                    
                    // Re-evaluate GPS quality after a few seconds to ensure it's stable
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                        guard let self = self, self.runState.isActive else { return }
                        // Re-check GPS quality and update coordination if needed
                        if self.hasGoodLocationData && !self.isPrimaryForDistance {
                            print("📱 GPS stabilized - re-establishing device coordination")
                            self.establishDeviceCoordination()
                        }
                    }
                } else {
                    print("📱 Outdoor run with good GPS: Phone primary for distance/pace")
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
                    print("📱 Outdoor run (joined from watch) with poor GPS: Watch remains primary for metrics")
                } else {
                    print("📱 Outdoor run with poor GPS: Deferring to watch for metrics")
                }
                
                // Re-evaluate GPS quality after a few seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    guard let self = self, self.runState.isActive else { return }
                    // If GPS improves, re-establish coordination
                    if self.hasGoodLocationData && self.isWatchTracking {
                        print("📱 GPS improved - re-establishing device coordination")
                        self.establishDeviceCoordination()
                    }
                }
            }
        }
        
        // Update metrics coordinator policy
        metricsCoordinator?.updatePolicy(
            isIndoor: isIndoor,
            hasGoodGPS: hasGoodLocationData,
            isWatchTracking: isWatchTracking
        )
        
        // Update application context to let watch know current state
        updateApplicationContext()
        
        // Send immediate update to watch
        sendTrackingStatusUpdate()
    }
    
    /// Pause the current run
    public func pauseRun() {
        // Only pause if running
        guard runState == .running else { return }
        
        print("📱 ⏸️ PAUSE DEBUG: Starting pause process")
        print("📱 ⏸️ PAUSE DEBUG: Current elapsedTime: \(elapsedTime)")
        print("📱 ⏸️ PAUSE DEBUG: Current startDate: \(startDate?.description ?? "nil")")
        print("📱 ⏸️ PAUSE DEBUG: Current totalPausedTime: \(totalPausedTime)")
        
        // Update state
        runState = .paused
        
        // Store pause time
        pauseDate = Date()
        print("📱 ⏸️ PAUSE DEBUG: Set pauseDate to: \(pauseDate?.description ?? "nil")")
        
        // Send appropriate command based on workout type - ONLY if not handling remote state change
        if !isHandlingRemoteStateChange {
            if isIndoorMode {
                sendIndoorRunStateChangeToWatch(newState: "paused")
            } else {
                sendOutdoorRunStateChangeToWatch(newState: "paused")
            }
        } else {
            print("📱 ⏸️ PAUSE DEBUG: Skipping state change message - handling remote command")
        }
        
        // Suspend timer
        timer?.invalidate()
        timer = nil
        
        // Stop location updates to save battery when paused
        if !isIndoorMode {
            locationManager.stopUpdatingLocation()
        }
        
        // Update lock screen
        updateLockScreen()
        
        // Notify observers through notification center
        NotificationCenter.default.post(name: .didChangeRunState, object: nil, userInfo: ["state": runState.rawValue])
        
        // Trigger haptic feedback for pause
        triggerHapticFeedback(.medium)
        
        print("📱 ⏸️ PAUSE DEBUG: Pause completed at \(elapsedTime) seconds, distance: \(distance.value) meters")
    }

    /// Resume a paused run
    public func resumeRun() {
        // Only resume if paused
        guard runState == .paused else { return }
        
        print("📱 🔄 RESUME DEBUG: Starting resume process")
        print("📱 🔄 RESUME DEBUG: Current elapsedTime: \(elapsedTime)")
        print("📱 🔄 RESUME DEBUG: Current startDate: \(startDate?.description ?? "nil")")
        print("📱 🔄 RESUME DEBUG: Current pauseDate: \(pauseDate?.description ?? "nil")")
        print("📱 🔄 RESUME DEBUG: Current totalPausedTime: \(totalPausedTime)")
        
        // Update state
        runState = .running
        
        // Calculate and accumulate pause duration (like the watch does)
        if let pauseDate = pauseDate {
            let pausedTime = Date().timeIntervalSince(pauseDate)
            totalPausedTime += pausedTime
            print("📱 🔄 RESUME DEBUG: Added \(pausedTime)s to totalPausedTime, now: \(totalPausedTime)s")
            
            // Clear pause date
            self.pauseDate = nil
        }
        
        // Send appropriate command based on workout type
        if !isHandlingRemoteStateChange {
            if isIndoorMode {
                sendIndoorRunStateChangeToWatch(newState: "inProgress")
            } else {
                sendOutdoorRunStateChangeToWatch(newState: "inProgress")
            }
        } else {
            print("📱 🔄 RESUME DEBUG: Skipping state change message - handling remote command")
        }
        
        // DO NOT adjust startDate - keep it unchanged like the watch does
        print("📱 🔄 RESUME DEBUG: Keeping startDate unchanged: \(startDate?.description ?? "nil")")
        
        // Restart timer
        startTimer()
        
        // Resume location updates if needed
        if !isIndoorMode {
            locationManager.startUpdatingLocation()
        }
        
        // Update lock screen
        updateLockScreen()
        
        // Notify observers through notification center
        NotificationCenter.default.post(name: .didChangeRunState, object: nil, userInfo: ["state": runState.rawValue])
        
        // Trigger haptic feedback for resume
        triggerHapticFeedback(.medium)
        
        print("📱 🔄 RESUME DEBUG: Resume completed, elapsed time: \(elapsedTime) seconds, totalPausedTime: \(totalPausedTime)s")
    }
    
    /// Check if timer is running and start it if needed
    /// Returns true if the timer was started, false if it was already running
    /// End the current run
    public func endRun() {
        // Only end if running or paused
        guard runState == .running || runState == .paused else { return }
        
        // Update state
        runState = .completed
        
        // Stop timer and location updates
        timer?.invalidate()
        timer = nil
        locationManager.stopUpdatingLocation()
        
        // Unregister from background manager
        WorkoutBackgroundManager.shared.unregisterWorkout(type: "run")
        
        // Stop lock screen display
        LockScreenManager.shared.stopWorkout()
        
        // Calculate final metrics
        calculateFinalMetrics()
        
        // Stop audio and end background task
        silentAudioPlayer?.stop()
        endBackgroundTask()
        
        // Restore screen settings
        UIApplication.shared.isIdleTimerDisabled = false
        
        // CRITICAL: Send explicit end command to watch BEFORE saving
        sendWorkoutEndCommandToWatch()
        
        // Save run data
        saveRun()
        
        // Sync final state with watch
        sendWorkoutUpdate(forced: true)
        
        // Notify observers
        NotificationCenter.default.post(name: .activityDidEnd, object: self)
        
        // Trigger haptic feedback for run completion
        triggerNotificationFeedback(.success)
        
        // Stop smart handoff monitoring
        SmartHandoffCoordinator.shared.stopMonitoring()
        
        print("📱 Run ended - Settings restored")
    }
    
    private func sendWorkoutEndCommandToWatch() {
        guard WCSession.default.activationState == .activated else {
            print("📱 Cannot send end command to watch - WCSession not activated")
            return
        }
        
        let endCommand: [String: Any] = [
            "type": isIndoorMode ? "indoorRunStateChange" : "outdoorRunStateChange",
            "command": "completed",
            "state": "completed",
            "runState": "completed",
            "workoutActive": false,
            "isIndoor": isIndoorMode,
            "timestamp": Date().timeIntervalSince1970,
            "workoutId": workoutId.uuidString,
            "finalMetrics": [
                "distance": Double(distance.value),  // Ensure it's a basic Double
                "elapsedTime": Double(elapsedTime),
                "calories": Double(calories),
                "heartRate": Double(heartRate),
                "verticalOscillation": verticalOscillation.value,
                "groundContactTime": groundContactTime
            ]
        ]
        
        print("📱 🔚 CRITICAL: Sending workout end command to watch with IMMEDIATE priority")
        
        // CRITICAL FIX: Only use direct messaging for workout end - no fallback to application context
        // This ensures immediate processing like pause/resume commands
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(endCommand, replyHandler: { response in
                print("📱 ✅ IMMEDIATE: Watch acknowledged workout end: \(response)")
            }, errorHandler: { error in
                print("📱 ❌ CRITICAL: Failed to send immediate end command: \(error.localizedDescription)")
                // Retry once more with immediate priority instead of falling back to applicationContext
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if WCSession.default.isReachable {
                        WCSession.default.sendMessage(endCommand, replyHandler: { response in
                            print("📱 ✅ RETRY SUCCESS: Watch acknowledged workout end on retry: \(response)")
                        }, errorHandler: { retryError in
                            print("📱 ❌ RETRY FAILED: Could not send end command after retry: \(retryError.localizedDescription)")
                            // Only now use application context as last resort
                            try? WCSession.default.updateApplicationContext(endCommand)
                            print("📱 ⚠️ FALLBACK: End command sent via application context")
                        })
                    }
                }
            })
        } else {
            print("📱 ❌ CRITICAL: Watch not reachable for immediate end command")
            // Wait and retry for immediate communication
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if WCSession.default.isReachable {
                    WCSession.default.sendMessage(endCommand, replyHandler: { response in
                        print("📱 ✅ DELAYED SUCCESS: Watch acknowledged workout end after wait: \(response)")
                    }, errorHandler: { error in
                        print("📱 ❌ DELAYED FAILED: Using applicationContext as final fallback")
                        try? WCSession.default.updateApplicationContext(endCommand)
                    })
                } else {
                    try? WCSession.default.updateApplicationContext(endCommand)
                    print("📱 ⚠️ FINAL FALLBACK: End command sent via application context")
                }
            }
        }
    }
    
    // Calculate final metrics before ending the run
    private func calculateFinalMetrics() {
        // Update pace one last time
        calculatePace()
        
        // Update calories
        updateCaloriesBurned()
        
        // Update formatted values
        updateFormattedValues()
        
        // Generate AI analysis
//        generateRunAnalysis()
    }
    
    /// Update application settings
    func updateSettings(useMetric: Bool, enableVoiceCoaching: Bool, autoLockScreen: Bool, announcementFrequency: Double) {
        self.useMetric = useMetric
        self.enableVoiceCoaching = enableVoiceCoaching
        self.autoLockScreen = autoLockScreen
        self.announcementFrequency = announcementFrequency
        
        // Save settings
        saveSettings()
    }
    
    /// Toggle screen lock state
    func toggleScreenLock() {
        isScreenLocked = !isScreenLocked
    }
    
    // MARK: - Private Methods
    
    private func resetMetrics() {
        distance = Measurement(value: 0, unit: UnitLength.meters)
        elapsedTime = 0
        pace = Measurement(value: 0, unit: UnitSpeed.minutesPerKilometer)
        calories = 0
        heartRate = 0
        elevationGain = Measurement(value: 0, unit: UnitLength.meters)
        elevationLoss = Measurement(value: 0, unit: UnitLength.meters)
        elevationTracker = ElevationTracker()
    }
    
    private func startTimer() {
        // Make sure we don't have an existing timer
        timer?.invalidate()
        timer = nil
        
        print("📱 Starting timer with elapsed time: \(elapsedTime)")
        
        // Create a new timer that fires exactly every 1 second
        timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Only proceed if we're running
            guard self.runState == .running else { return }
            
            // Update time based on start date for best accuracy
            if let startDate = self.startDate {
                // Calculate total elapsed time
                let currentDate = Date()
                let rawElapsed = currentDate.timeIntervalSince(startDate)
                
                // Calculate total pause duration (accumulated + current if paused)
                let pauseDuration = self.calculatePauseDuration()
                
                // Debug logging every 10 seconds to avoid spam
                if Int(rawElapsed) % 10 == 0 {
                    print("📱 ⏱️ TIMER DEBUG: rawElapsed=\(rawElapsed), pauseDuration=\(pauseDuration), totalPausedTime=\(self.totalPausedTime), runState=\(self.runState.rawValue)")
                }
                
                // Set the elapsed time (on main thread for thread safety)
                DispatchQueue.main.async {
                    let oldElapsedTime = self.elapsedTime
                    
                    // Calculate actual elapsed time by subtracting pause duration (like the watch does)
                    self.elapsedTime = rawElapsed - pauseDuration
                    
                    // Debug significant changes in elapsed time
                    if abs(self.elapsedTime - oldElapsedTime) > 2.0 {
                        print("📱 ⏱️ TIMER DEBUG: Significant time change - old: \(oldElapsedTime), new: \(self.elapsedTime), rawElapsed: \(rawElapsed), pauseDuration: \(pauseDuration)")
                    }
                    
                    // Update formatted values
                    self.updateFormattedValues()
                    
                    // Update metrics periodically
                    self.updateRunMetrics()
                    
                    // Send updates to watch every 3 seconds to avoid overwhelming communication
                    if Int(self.elapsedTime) % 3 == 0 {
                        // Only send if we have a significant state (running or paused)
                        if self.runState == .running || self.runState == .paused {
                            self.sendWorkoutUpdate()
                        }
                        
                        // Update split times
                        self.updateSplitTimes()
                    }
                    
                    // Notify UI of the update
                    NotificationCenter.default.post(
                        name: .didUpdateRunMetrics, 
                        object: nil,
                        userInfo: ["elapsedTime": self.elapsedTime]
                    )
                }
            } else {
                // Fallback for if startDate is nil (shouldn't happen)
                DispatchQueue.main.async {
                    self.elapsedTime += 1.0
                    self.updateFormattedValues()
                    
                    // Notify UI of the update
                    NotificationCenter.default.post(name: .didUpdateRunMetrics, object: nil)
                }
            }
        }
        
        // Add to both RunLoop modes to ensure timer reliability
        RunLoop.main.add(timer!, forMode: .default)
        RunLoop.main.add(timer!, forMode: .tracking)
        print("📱 Timer started successfully")
    }

    private func updateRunMetrics() {
        // Calculate pace based on current distance and elapsed time
        if distance.value > 10 && elapsedTime > 5 {
            let paceSecondsPerKm = elapsedTime / (distance.value / 1000.0)
            
            // Only update if pace is reasonable (between 3-30 min/km)
            if paceSecondsPerKm > 180 && paceSecondsPerKm < 1800 {
                // Convert to user's preferred unit
                let paceValue = useMetric ? paceSecondsPerKm : paceSecondsPerKm * 1.60934
                // Use the correct unit based on user preference
                pace = Measurement(value: paceValue, unit: useMetric ? UnitSpeed.minutesPerKilometer : UnitSpeed.minutesPerMile)
            }
        }
        
        // Update calorie calculation
        updateCaloriesBurned()
        
        // Update formatted values to ensure UI reflects latest metrics
        updateFormattedValues()
        
        // Sync with workout manager and watch
        syncWithWorkoutManager()
        
        // Collect treadmill data points for indoor runs
        if isIndoorMode {
            collectTreadmillDataPoint()
        }
        
        // Notify observers of metrics update
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            NotificationCenter.default.post(name: .didUpdateRunMetrics, object: self)
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Heart Rate Collection
    // Note: The phone does not collect heart rate directly.
    // Heart rate is collected by the watch and synced to the phone via coordination.
    // The phone receives heart rate updates through:
    // 1. Watch communication messages (syncWorkoutData, workoutUpdate)
    // 2. HealthKitGenericDevice if external devices are connected
    
    /// Collect a treadmill data point with current metrics
    private func collectTreadmillDataPoint() {
        // Only collect data points every 15 seconds to avoid too much data
        let currentTime = Date()
        if let lastDataPoint = treadmillDataPoints?.last,
           currentTime.timeIntervalSince(lastDataPoint.timestamp) < 15.0 {
            return
        }
        
        // Initialize treadmill data points array if needed
        if treadmillDataPoints == nil {
            treadmillDataPoints = []
        }
        
        // Calculate speed from pace (convert from seconds per km to km/h)
        let speedKmh = pace.value > 0 ? 3600.0 / pace.value : 0.0
        
        // Create new data point
        let dataPoint = TreadmillDataPoint(
            timestamp: currentTime,
            distance: distance.value,
            heartRate: heartRate,
            cadence: cadence,
            speed: speedKmh,
            pace: pace.value
        )
        
        treadmillDataPoints?.append(dataPoint)
        
        // Keep only last 100 data points to prevent memory issues
        if let count = treadmillDataPoints?.count, count > 100 {
            treadmillDataPoints?.removeFirst()
        }
        
        print("📊 Collected treadmill data point: distance=\(distance.value)m, pace=\(pace.value)s/km, HR=\(heartRate)bpm, cadence=\(cadence)spm")
    }
    
    private func updateElapsedTime() {
        guard let startDate = startDate else { return }
        
        // Calculate elapsed time since start
        elapsedTime = Date().timeIntervalSince(startDate)
        
        // Calculate pace based on current distance and elapsed time
        if distance.value > 10 && elapsedTime > 5 {
            // Calculate pace in seconds per kilometer
            let paceSecondsPerKm = elapsedTime / (distance.value / 1000.0)
            
            // Only update if pace is reasonable (between 3-30 min/km)
            if paceSecondsPerKm > 180 && paceSecondsPerKm < 1800 {
                if useMetric {
                    // Store pace in min/km for metric
                    pace = Measurement(value: paceSecondsPerKm, unit: UnitSpeed.minutesPerKilometer)
                } else {
                    // Convert to min/mile for imperial
                    let distanceInMiles = distance.value / 1609.34 // Convert meters to miles
                    let paceSecondsPerMile = elapsedTime / distanceInMiles
                    pace = Measurement(value: paceSecondsPerMile, unit: UnitSpeed.minutesPerMile)
                }
            }
        }
        
        // Calculate calories burned
        updateCaloriesBurned()
        
        // Check if it's time for a coaching announcement
        checkForAnnouncements()
        
        // Sync with watch every 5 seconds
        if Int(elapsedTime) % 5 == 0 {
            sendWorkoutUpdate()
        }
    }
    
    public func processLocationUpdate(_ location: CLLocation) {
        // Skip if not running
        guard isRunning else { return }
        
        // Skip location updates for indoor/treadmill runs
        guard !isIndoorMode else { 
            print("📱 🏃‍♂️ Skipping location update - indoor mode active")
            return 
        }
        
        // Check for data quality
        // Check for data quality
        let howRecent = location.timestamp.timeIntervalSinceNow
        guard location.horizontalAccuracy < 20 && abs(howRecent) < 10 else { return }

        // Mark that we have good location data since we passed the accuracy check
        hasGoodLocationData = true
        // Calculate distance delta
        let delta: Double
        if let lastLocation = locationList.last {
            delta = lastLocation.distance(from: LocationData(from: location))
        } else {
            delta = 0
        }
        
        // Create LocationData with current heart rate and cadence
        let locationData = LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            course: location.course,
            speed: location.speed,
            distance: delta, // Use calculated distance delta
            timestamp: location.timestamp,
            heartRate: heartRate,
            cadence: cadence
        )
        
        // IMPORTANT: Make a copy of the location for thread-safe operations
        // We'll use this in the main thread for calculations
        let locationCopy = location
        
        // Handle all published property updates on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update distance measurement on main thread
            if delta > 0 {
                self.distance = self.distance + Measurement(value: delta, unit: UnitLength.meters)
            }
            
            // Update elevation tracker
            self.elevationTracker.updateElevation(newLocation: locationCopy)
            
            // Update elevation properties
            self.elevationGain = self.elevationTracker.getElevationGain()
            self.elevationLoss = self.elevationTracker.getElevationLoss()
            
            // Update location list (published property)
            if self.locationList.isEmpty {
                // If empty, create new list
                self.locationList = [locationData]
            } else if let lastItem = self.locationList.last,
                      lastItem.timestamp != locationData.timestamp ||
                      lastItem.latitude != locationData.latitude ||
                      lastItem.longitude != locationData.longitude {
                // Add if truly a new point (different from last)
                self.locationList.append(locationData)
            }
            
            // Estimate cadence if not provided by watch and phone is primary for cadence
            if self.cadence <= 0 && isPrimaryForCadence {
                // Estimate cadence based on pace (always stored in seconds/km)
                let paceSeconds = self.pace.value
                if paceSeconds > 0 {
                    let paceMinPerKm = paceSeconds / 60
                    
                    // Cadence model: higher cadence for faster pace
                    let estimatedCadence = max(140, min(190, 200 - (paceMinPerKm * 10)))
                    
                    // Apply smoothing
                    if self.cadence <= 0 {
                        self.cadence = estimatedCadence
                    } else {
                        self.cadence = self.cadence * 0.7 + estimatedCadence * 0.3
                    }
                    
                    // Update formatted cadence
                    if self.cadence > 0 {
                        self.formattedCadence = String(format: "%.0f spm", self.cadence)
                    }
                }
            }
            
            // Check for split distances
            self.checkForSplitTime()
            
            // Update pace consistency on every location update
            self.updatePaceConsistency()
            
            // Update route on map
            self.updateRouteAnnotations()
            
            // Sync with RunningWorkoutManager
            self.syncWithWorkoutManager()
        }
    }
    
    private func updateRouteAnnotations() {
        guard !locationList.isEmpty else { return }
        
        var annotations: [RouteAnnotation] = []
        
        // Add start annotation
        if let startLocation = locationList.first {
            annotations.append(RouteAnnotation(
                coordinate: startLocation.coordinate,
                type: .start,
                title: "Start"
            ))
        }
        
        // Add current location annotation
        if let currentLocation = locationList.last {
            annotations.append(RouteAnnotation(
                coordinate: currentLocation.coordinate,
                type: .currentLocation,
                title: nil
            ))
        }
        
        // For longer runs, add distance markers
        if distance.value > 1000 { // More than 1km
            let distanceUnit = useMetric ? 1000.0 : 1609.34 // 1km or 1mi in meters
            let totalKms = Int(distance.value / distanceUnit)
            
            // Find locations closest to each km/mile mark
            if totalKms > 0 {  // Check to ensure we have at least 1 km/mile
                for i in 1...totalKms {
                    let targetDistance = Double(i) * distanceUnit
                    
                    // Find location closest to this distance
                    var runningDistance = 0.0
                    var markerLocation: LocationData?
                    
                    for j in 1..<locationList.count {
                        let prevLoc = locationList[j-1]
                        let currLoc = locationList[j]
                        let segmentDistance = prevLoc.distance(from: currLoc)
                        
                        if runningDistance + segmentDistance > targetDistance {
                            // Interpolate to find exact position
                            let remainingDistance = targetDistance - runningDistance
                            let fraction = remainingDistance / segmentDistance
                            
                            // Linear interpolation between points
                            let lat = prevLoc.latitude + fraction * (currLoc.latitude - prevLoc.latitude)
                            let lon = prevLoc.longitude + fraction * (currLoc.longitude - prevLoc.longitude)
                            
                            // Create a temporary LocationData for this point
                            markerLocation = LocationData(
                                latitude: lat,
                                longitude: lon,
                                altitude: 0,
                                horizontalAccuracy: 0,
                                verticalAccuracy: 0,
                                course: 0,
                                speed: 0,
                                distance: 0,
                                timestamp: Date(),
                                heartRate: nil,
                                cadence: nil
                            )
                            break
                        }
                        
                        runningDistance += segmentDistance
                    }
                    
                    if let location = markerLocation {
                        annotations.append(RouteAnnotation(
                            coordinate: location.coordinate,
                            type: .waypoint,
                            title: "\(i) \(useMetric ? "km" : "mi")"
                        ))
                    }
                }
            }
        }
        
        self.routeAnnotations = annotations
    }
    
    private func updateCaloriesBurned() {
        // Calculate calories burned using the most accurate method available
        // We'll use a combination of factors to get the most accurate estimate
        
        // 1. Calculate MET (Metabolic Equivalent of Task) based on pace
        let met: Double
        
        // Convert pace to km/h for MET calculation
        let paceValue = pace.value
        let speedKmH = paceValue > 0 ? 60 / paceValue : 0
        if speedKmH < 4 {
            met = 4.0  // Walking
        } else if speedKmH < 8 {
            met = 6.0  // Jogging
        } else if speedKmH < 12 {
            met = 8.0  // Running
        } else {
            met = 10.0 // Fast running
        }
        
        // 2. Calculate calories using the formula: Calories = MET × Weight × Duration (hours)
        let durationHours = elapsedTime / 3600.0
        let baseCalories = met * userWeight * durationHours
        
        // 3. Adjust calories based on available data
        var adjustedCalories = baseCalories
        
        // If we have heart rate data, use it to refine the estimate
        if heartRate > 0 {
            // Calculate calories based on heart rate
            // Using a simplified formula: Calories = (Heart Rate - Resting HR) × Duration × 0.1
            let restingHR: Double = 60.0 // Default resting heart rate
            let hrCalories = (heartRate - restingHR) * durationHours * 0.1
            
            // Use the average of both methods for better accuracy
            adjustedCalories = (baseCalories + hrCalories) / 2
        }
        
        // 4. Apply elevation adjustments
        if elevationGain.value > 0 {
            // Add calories for elevation gain (approximately 1 calorie per 10 meters of elevation gain)
            let elevationCalories = elevationGain.value / 10.0
            adjustedCalories += elevationCalories
        }
        
        // 5. Apply cadence adjustment if available
        if cadence > 0 {
            // Higher cadence generally means more efficient running
            // Adjust calories down slightly for higher cadences (>170)
            if cadence > 170 {
                adjustedCalories *= 0.95
            }
        }
        
        // 6. Ensure calories are reasonable
        // Minimum calories per hour should be around 300 for running
        let minimumCaloriesPerHour: Double = 300.0
        let minimumCalories = minimumCaloriesPerHour * durationHours
        
        // Maximum calories per hour should be around 1000 for running
        let maximumCaloriesPerHour: Double = 1000.0
        let maximumCalories = maximumCaloriesPerHour * durationHours
        
        // Clamp the calories to reasonable values
        calories = min(max(adjustedCalories, minimumCalories), maximumCalories)
        
        // Update formatted calories
        formattedCalories = String(format: "%.0f", calories)
    }
    
    // MARK: - Helper Methods
    
    /// Converts RunType enum to database format (snake_case)
    /// This ensures consistency with the production database which expects:
    /// - "outdoor_run" instead of "outdoorRun"
    /// - "treadmill_run" instead of "treadmillRun"
    /// - etc.
    private func runTypeToDatabaseFormat(_ runType: RunType) -> String {
        switch runType {
        case .outdoorRun:
            return "outdoor_run"
        case .treadmillRun:
            return "treadmill_run"
        case .trailRun:
            return "trail_run"
        case .intervalTraining:
            return "interval_training"
        case .recoveryRun:
            return "recovery_run"
        case .lapRun:
            return "lap_run"
        @unknown default:
            // Fallback: convert camelCase to snake_case for any unknown cases
            let rawValue = runType.rawValue
            return rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1_$2", options: .regularExpression).lowercased()
        }
    }
    
    private func saveRun() {
    // Check if this is an indoor run
    if isIndoorMode {
        // Save as IndoorRunLog
        saveIndoorRun()
    } else {
        // Save as outdoor RunLog
        saveOutdoorRun()
    }
}

    // Store treadmill image data for saving
    private var treadmillImageData: TreadmillImageData?
    
    func setTreadmillImageData(_ data: TreadmillImageData) {
        treadmillImageData = data
        // Update metrics from extracted data if confidence is high
        if data.confidence > 0.7 {
            distance = Measurement(value: data.distanceInMeters(), unit: .meters)
            elapsedTime = data.duration
            if let extractedCalories = data.calories {
                calories = extractedCalories
            }
            updateFormattedValues()
        }
    }
    
    private func saveIndoorRun() {
        // Update cached average pace with this run's data
        updateCachedPaceWithCurrentRun()
        
        // Check idempotency for indoor runs
        if let lastSavedId = UserDefaults.standard.string(forKey: "lastSavedIndoorRunId"),
           lastSavedId == runLog.id {
            print("⚠️ Indoor run already saved, skipping duplicate save")
            return
        }
        
        // Get user ID from Cognito
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            print("📱 💾 INDOOR SAVE: ❌ No current user")
            return
        }
    
    // Use treadmill image data if available and confidence is high, otherwise use current values
    var finalDistance = distance
    var finalDuration = elapsedTime
    var finalCalories = calories
    
    if let imageData = treadmillImageData, imageData.confidence > 0.7 {
        // Prefer extracted data if confidence is high
        finalDistance = Measurement(value: imageData.distanceInMeters(), unit: .meters)
        finalDuration = imageData.duration
        if let extractedCalories = imageData.calories {
            finalCalories = extractedCalories
        }
        print("📱 Using treadmill image extracted data (confidence: \(imageData.confidence))")
    }
    
    // Use current formatted values (already updated by updateFormattedValues())
    let formattedTime = self.formattedTime
    let formattedPace = self.formattedPace
    
    // Format distance as string (like original)
    let distanceInMiles = finalDistance.converted(to: .miles)
    let numFormatter = NumberFormatter()
    numFormatter.maximumFractionDigits = 2
    let distValue = numFormatter.string(from: NSNumber(value: distanceInMiles.value)) ?? "0.00"
    
    // Format calories as rounded number (like original)
    let roundedCalories = round(finalCalories)
    
    // Calculate average pace in mph if we have valid distance and time
    var averagePaceMph: Double = 0.0
    if finalDistance.value > 0 && finalDuration > 0 {
        // Calculate average pace in seconds per mile
        let distanceInMiles = finalDistance.value / 1609.34 // Convert meters to miles
        let averagePaceSecondsPerMile = finalDuration / distanceInMiles
        
        // Only calculate if pace is reasonable (between 4:00 and 20:00 min/mile)
        if averagePaceSecondsPerMile >= 240 && averagePaceSecondsPerMile <= 1200 {
            // Convert from min/mile to mph: mph = 60 / pace_min_per_mile
            averagePaceMph = 60.0 / (averagePaceSecondsPerMile / 60.0)
        }
    }
    
    // Ensure we have treadmill data points - create them if not available
    if treadmillDataPoints == nil || treadmillDataPoints?.isEmpty == true {
        // Create treadmill data points from current workout data
        var dataPoints: [TreadmillDataPoint] = []
        
        // Add starting point
        if let startDate = startDate {
            let startPoint = TreadmillDataPoint(
                timestamp: startDate,
                distance: 0.0,
                heartRate: heartRate > 0 ? heartRate : 0,
                cadence: cadence > 0 ? cadence : 0,
                speed: 0.0,
                pace: 0.0
            )
            dataPoints.append(startPoint)
        }
        
        // Add midpoint if we have elapsed time
        if elapsedTime > 30 {
            let midpointTime = (startDate?.addingTimeInterval(elapsedTime / 2)) ?? Date()
            let midPoint = TreadmillDataPoint(
                timestamp: midpointTime,
                distance: distance.value / 2,
                heartRate: heartRate,
                cadence: cadence,
                speed: pace.value > 0 ? (3600.0 / pace.value) : 0, // Convert to speed
                pace: pace.value
            )
            dataPoints.append(midPoint)
        }
        
        // Add current/final point
        let currentPoint = TreadmillDataPoint(
            timestamp: Date(),
            distance: distance.value,
            heartRate: heartRate,
            cadence: cadence,
            speed: pace.value > 0 ? (3600.0 / pace.value) : 0, // Convert to speed
            pace: pace.value
        )
        dataPoints.append(currentPoint)
        
        treadmillDataPoints = dataPoints
    }
    
    // Prepare treadmill data points for activityData
    var treadmillDataArray: [[String: Any]] = []
    if let dataPoints = treadmillDataPoints {
        treadmillDataArray = dataPoints.map { $0.toDictionary() }
        print("📊 Saving \(treadmillDataArray.count) treadmill data points")
    }
    
    // Populate RunLog for display
    runLog.duration = formattedTime
    runLog.distance = distValue
    runLog.avgPace = formattedPace
    runLog.caloriesBurned = roundedCalories
    runLog.type = "indoor"
    runLog.runType = runType.rawValue
    runLog.createdBy = UserIDHelper.shared.getCurrentUserID() // Set Cognito user ID
    
    // Prepare activity data with indoor run specifics
    let activityData: [String: Any] = [
        "runType": "treadmill_run",
        "formattedPace": formattedPace,
        "formattedDistance": distValue,
        "formattedTime": formattedTime,
        "averagePaceMph": averagePaceMph,
        "treadmillDataPoints": treadmillDataArray
    ]
    
    // Save to AWS using ActivityService
    ActivityService.shared.saveRun(
        userId: userId,
        duration: finalDuration,
        distance: finalDistance.value, // Distance in meters
        calories: roundedCalories,
        avgHeartRate: avgHeartRate > 0 ? avgHeartRate : nil,
        maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil,
        elevationGain: nil, // Indoor runs have no elevation
        elevationLoss: nil,
        routePoints: [], // Indoor runs have no GPS route
        activityData: activityData,
        startLocation: nil,
        endLocation: nil,
        isPublic: true,
        caption: nil
    ) { [weak self] result in
        guard let self = self else { return }
        
        switch result {
        case .success(let response):
            print("📱 💾 INDOOR SAVE: ✅ Indoor run saved to AWS successfully")
            print("📊 Saved with distance: \(distValue)")
            print("📊 Saved with averagePaceMph: \(averagePaceMph) mph")
            print("📊 Saved with calories: \(roundedCalories)")
            if !treadmillDataArray.isEmpty {
                print("📊 Saved with \(treadmillDataArray.count) treadmill data points")
            }
            
            if let activityId = response.data?.activityId {
                self.runLog.id = activityId
                // Mark as saved to prevent duplicate saves
                UserDefaults.standard.set(activityId, forKey: "lastSavedIndoorRunId")
                UserDefaults.standard.synchronize()
                print("📊 Activity ID: \(activityId)")
            }
            
            // Notify user of successful save
            DispatchQueue.main.async {
                self.showSaveSuccessNotification()
            }
            
            // Save to HealthKit
            self.saveToHealthKit()
            
            // Update RunHistoryService cache after successful save
            RunHistoryService.shared.refreshAfterSave { error in
                if let error = error {
                    print("⚠️ [RunTrackingEngine] Failed to refresh cache after save: \(error.localizedDescription)")
                } else {
                    print("✅ [RunTrackingEngine] Cache updated after indoor run save")
                }
            }
            
        case .failure(let error):
            print("📱 💾 INDOOR SAVE: ❌ Error saving indoor run to AWS: \(error.localizedDescription)")
            
            // Notify user of save error on main thread
            DispatchQueue.main.async {
                self.showSaveErrorNotification(error: error)
            }
            
            // Try again after delay with exponential backoff
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
                self.saveRun()
            }
        }
    }
    
    print("📱 💾 INDOOR SAVE: ✅ Indoor run save request sent to AWS")
}

    private func saveOutdoorRun() {
        // Update cached average pace with this run's data
        updateCachedPaceWithCurrentRun()
        
        // Make sure we have data to save
        guard !locationList.isEmpty else { 
            print("📱 💾 OUTDOOR SAVE: ❌ Cannot save - missing location data")
            print("📱 💾 OUTDOOR SAVE: ❌ locationList.isEmpty: \(locationList.isEmpty)")
            return 
        }
        
        guard let parseObject = parseObject else {
            print("📱 💾 OUTDOOR SAVE: ❌ Cannot save - parseObject is nil")
            return
        }
    
    // Format values to match original schema (use current formatted values)
    let formattedTime = self.formattedTime
    let formattedPace = self.formattedPace
    
    // Format distance as string (like original)
    let distanceInMiles = distance.converted(to: .miles)
    let numFormatter = NumberFormatter()
    numFormatter.maximumFractionDigits = 2
    let distValue = numFormatter.string(from: NSNumber(value: distanceInMiles.value)) ?? "0.00"
    
    // Format elevation as string (like original)
    let elevationFt = elevationGain.converted(to: .feet)
    let elevationFtFormatter = NumberFormatter()
    elevationFtFormatter.maximumFractionDigits = 0
    let elevationGainString = elevationFtFormatter.string(from: NSNumber(value: elevationFt.value)) ?? "0"
    
    let elevationLossFt = elevationLoss.converted(to: .feet)
    let elevationLossString = elevationFtFormatter.string(from: NSNumber(value: elevationLossFt.value)) ?? "0"
    
    // Format calories as rounded number (like original)
    let roundedCalories = round(calories)
    
    // Create coordinate array for the route (replaces PFGeoPoint)
    let coordinateArray = locationList.map { ["latitude": $0.latitude, "longitude": $0.longitude] }
    
    // Prepare location data array to match original format
    var locationDataArray: [[String: Any]] = []
    
    for location in locationList {
        let locationData: [String: Any] = [
            "latitude": location.latitude,
            "longitude": location.longitude,
            "altitude": location.altitude,
            "horizontalAccuracy": location.horizontalAccuracy,
            "verticalAccuracy": location.verticalAccuracy,
            "speed": location.speed,
            "course": location.course,
            "timestamp": location.timestamp,
            "heartRate": location.heartRate ?? 0,
            "cadence": location.cadence ?? 0
        ]
        locationDataArray.append(locationData)
    }
    
    // Parse removed - data saved directly to AWS via ActivityService
    
    // Populate RunLog for display
    runLog.duration = formattedTime
    runLog.distance = distValue
    runLog.avgPace = formattedPace
    runLog.type = "outdoor"
    runLog.runType = runType.rawValue
    runLog.locationData = locationDataArray
    runLog.caloriesBurned = roundedCalories
    runLog.elevationGain = elevationGainString
    runLog.elevationLoss = elevationLossString
    runLog.coordinateArray = locationList.map { ["latitude": $0.latitude, "longitude": $0.longitude] }
    runLog.createdBy = UserIDHelper.shared.getCurrentUserID() // Set Cognito user ID
    
    // Save to AWS using ActivityService
    guard let userId = UserIDHelper.shared.getCurrentUserID() else {
        print("📱 💾 OUTDOOR SAVE: ❌ No current user")
        return
    }
    
    // Check idempotency - prevent duplicate saves
    if let lastSavedId = UserDefaults.standard.string(forKey: "lastSavedRunId"),
       lastSavedId == runLog.id {
        print("⚠️ Run already saved, skipping duplicate save")
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
            "course": location.course,
            "heartRate": location.heartRate ?? 0,
            "cadence": location.cadence ?? 0
        ]
    }
    
    // Prepare start and end locations
    let startLoc: [String: Any]? = locationList.first.map {
        ["lat": $0.latitude, "lon": $0.longitude, "name": "Start"]
    }
    let endLoc: [String: Any]? = locationList.last.map {
        ["lat": $0.latitude, "lon": $0.longitude, "name": "End"]
    }
    
    // Prepare activity data
    let activityData: [String: Any] = [
        "runType": runTypeToDatabaseFormat(runType),
        "formattedPace": formattedPace,
        "formattedDistance": distValue,
        "formattedTime": formattedTime
    ]
    
    // Save to AWS
    ActivityService.shared.saveRun(
        userId: userId,
        duration: elapsedTime,
        distance: distance.value, // Distance in meters
        calories: roundedCalories,
        avgHeartRate: avgHeartRate > 0 ? avgHeartRate : nil,
        maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil,
        elevationGain: elevationGain.value, // In meters
        elevationLoss: elevationLoss.value, // In meters
        routePoints: routePoints,
        activityData: activityData,
        startLocation: startLoc,
        endLocation: endLoc,
        isPublic: true,
        caption: nil
    ) { [weak self] result in
        guard let self = self else { return }
        
        switch result {
        case .success(let response):
            print("📱 💾 OUTDOOR SAVE: ✅ Run saved to AWS successfully")
            print("📊 Saved with Distance: \(distValue)")
            print("📊 Saved with calories: \(roundedCalories)")
            print("📊 Saved with \(self.locationList.count) location data points")
            
            if let activityId = response.data?.activityId {
                self.runLog.id = activityId
                // Mark as saved to prevent duplicate saves
                UserDefaults.standard.set(activityId, forKey: "lastSavedRunId")
                UserDefaults.standard.synchronize()
                print("📊 Activity ID: \(activityId)")
            }
            
            // Notify user of successful save
            DispatchQueue.main.async {
                self.showSaveSuccessNotification()
            }
            
            // Save to HealthKit
            self.saveToHealthKit()
            
            // Update RunHistoryService cache after successful save
            RunHistoryService.shared.refreshAfterSave { error in
                if let error = error {
                    print("⚠️ [RunTrackingEngine] Failed to refresh cache after save: \(error.localizedDescription)")
                } else {
                    print("✅ [RunTrackingEngine] Cache updated after run save")
                }
            }
            
        case .failure(let error):
            print("📱 💾 OUTDOOR SAVE: ❌ Error saving run to AWS: \(error.localizedDescription)")
            
            // Notify user of save error on main thread
            DispatchQueue.main.async {
                self.showSaveErrorNotification(error: error)
            }
            
            // Try again after delay with exponential backoff
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
                self.saveRun()
            }
        }
    }
    
    print("📱 💾 OUTDOOR SAVE: ✅ Run save request sent to AWS")
}
    
    private func saveToHealthKit() {
        guard let startDate = startDate, HKHealthStore.isHealthDataAvailable() else { return }
        
        // Define workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        
        // Determine if outdoor or indoor
        configuration.locationType = .outdoor
        
        // Get end date
        let endDate = Date()
        let workoutDuration = endDate.timeIntervalSince(startDate)
        
        // Create workout
        let workout = HKWorkout(
            activityType: .running,
            start: startDate,
            end: endDate,
            duration: workoutDuration,
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
            totalDistance: HKQuantity(unit: .meter(), doubleValue: distance.value),
            metadata: [
                HKMetadataKeyIndoorWorkout: false
            ]
        )
        
        // Request authorization and save
        healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()], read: []) { [weak self] (success, error) in
            guard success else {
                print("HealthKit authorization denied")
                return
            }
            
            self?.healthStore.save(workout) { (success, error) in
                if let error = error {
                    print("Error saving workout: \(error.localizedDescription)")
                } else {
                    print("Workout saved successfully to HealthKit")
                }
            }
        }
    }
    
    // Add these properties with the other class properties
    private var audioSessionConfigured = false
    private var renewalTimer: Timer?
    
    // Start a background task to allow tracking in the background
    private func startBackgroundTask() {
        // If there's already a background task running, end it first
        if backgroundTask != .invalid {
            return  // Don't create a new task if one is already active
        }
        
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "RunTracking") {
            // This block is called when the background task is about to expire
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = .invalid
        }
        
        // Set up audio session for background
        setupAudioSessionForBackground()
        
        // Play silent audio file if needed to help keep app running in background
        playSilentAudioIfNeeded()
        
        // Cancel previous renewal timer if it exists
        renewalTimer?.invalidate()
        
        // Set a timer to periodically renew the background task to prevent warnings
        // This will create a new background task every 25 seconds
        renewalTimer = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.runState == .running || self.runState == .paused {
                // Only renew if we're still tracking
                self.endBackgroundTask()
                // Wait a short time before starting a new task to avoid overlapping tasks
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if self.backgroundTask == .invalid {
                        self.startBackgroundTask()
                    }
                }
            } else {
                // If we're no longer tracking, stop the renewal timer
                timer.invalidate()
                self.endBackgroundTask()
            }
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            
            // Reset audio session status when the background task ends
            if runState != .running && runState != .paused {
                audioSessionConfigured = false
            }
        }
    }
    
    // Play silent audio to help keep app running in background
    private func playSilentAudioIfNeeded() {
        // If we already have an audio player running, don't start another
        if let player = silentAudioPlayer, player.isPlaying {
            return
        }
        
        // First try the simplest approach - create a pure sine wave
        if !createSimpleSineWavePlayer() {
            createAudioEnginePlayer()
        }
    }
    
    // Simplest possible method - generate a sine wave directly
    private func createSimpleSineWavePlayer() -> Bool {
        // Create a very simple in-memory audio file
        let sampleRate = 8000
        let sampleCount = 8000 // 1 second of audio
        
        // Always use stereo format (2 channels) for consistent channel count
        let channelCount: UInt16 = 2
        
        // Generate a simple tone - create a sine wave with very low amplitude
        var sineWaveData = Data(capacity: sampleCount * Int(channelCount) * 2) // 2 bytes per Int16 sample * 2 channels
        
        for i in 0..<sampleCount {
            let value = Int16(sin(Float(i) / Float(sampleRate) * Float.pi * 2.0 * 440.0) * 4.0)
            
            // Add the sample to both left and right channels
            var leftSample = value
            var rightSample = value
            
            sineWaveData.append(Data(bytes: &leftSample, count: 2))
            sineWaveData.append(Data(bytes: &rightSample, count: 2))
        }
        
        // Create a minimal WAV header
        var header = Data(capacity: 44)
        
        // "RIFF" chunk
        header.append("RIFF".data(using: .ascii)!)
        let fileSize = UInt32(sineWaveData.count + 36)
        header.append(UInt32(fileSize).littleEndianData)
        header.append("WAVE".data(using: .ascii)!)
        
        // "fmt " subchunk
        header.append("fmt ".data(using: .ascii)!)
        header.append(UInt32(16).littleEndianData) // subchunk size
        header.append(UInt16(1).littleEndianData) // PCM format
        header.append(channelCount.littleEndianData) // 2 channels (stereo)
        header.append(UInt32(sampleRate).littleEndianData) // sample rate
        header.append(UInt32(sampleRate * Int(channelCount) * 2).littleEndianData) // byte rate (sample rate * channels * bytes per sample)
        header.append(UInt16(channelCount * 2).littleEndianData) // block align (channels * bytes per sample)
        header.append(UInt16(16).littleEndianData) // bits per sample
        
        // "data" subchunk
        header.append("data".data(using: .ascii)!)
        header.append(UInt32(sineWaveData.count).littleEndianData)
        
        // Combine header and audio data
        var wavData = header
        wavData.append(sineWaveData)
        
        // Write to temp file and create player
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("silent.wav")
        do {
            try wavData.write(to: tempURL)
            silentAudioPlayer = try AVAudioPlayer(contentsOf: tempURL)
            silentAudioPlayer?.numberOfLoops = -1
            silentAudioPlayer?.volume = 0.01
            silentAudioPlayer?.play()
            print("✅ Created stereo sine wave player with \(channelCount) channels")
            return true
        } catch {
            print("❌ Failed to create sine wave player: \(error.localizedDescription)")
            return false
        }
    }
    
    // Use AVAudioEngine as a fallback
    private func createAudioEnginePlayer() {
        // This is a static property to keep the engine from being deallocated
        struct AudioEngineContainer {
            static var engine: AVAudioEngine?
            static var playerNode: AVAudioPlayerNode?
        }
        
        do {
            // Create the audio engine
            let engine = AVAudioEngine()
            let playerNode = AVAudioPlayerNode()
            
            // Configure the engine
            engine.attach(playerNode)
            
            // Always use stereo format (2 channels) for consistent channel count
            let channelCount: UInt32 = 2
            let sampleRate: Double = 8000
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount)!
            
            // Connect player to mixer with the specified format
            engine.connect(playerNode, to: engine.mainMixerNode, format: format)
            
            // Create a buffer with matching stereo format
            let buffer = createStereoSineBuffer(sampleRate: sampleRate, duration: 1.0, channelCount: channelCount)
            
            // Schedule the buffer to loop indefinitely
            playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
            
            // Start the engine and player
            try engine.start()
            playerNode.volume = 0.01
            playerNode.play()
            
            // Store references to prevent deallocation
            AudioEngineContainer.engine = engine
            AudioEngineContainer.playerNode = playerNode
        } catch {
            // Silent failure
            print("❌ Failed to create audio engine player: \(error.localizedDescription)")
        }
    }
    
    // Create a stereo sine buffer for the audio engine
    private func createStereoSineBuffer(sampleRate: Double, duration: Double, channelCount: UInt32) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        // Fill buffer with a very quiet tone for all channels
        for channel in 0..<Int(channelCount) {
            // Get the channel data pointer
            let channelData = buffer.floatChannelData![channel]
            
            // Fill with sine wave
            for i in 0..<Int(frameCount) {
                // Generate a sine wave with very small amplitude
                channelData[i] = Float(sin(2.0 * Double.pi * 440.0 * Double(i) / sampleRate) * 0.01)
            }
        }
        
        return buffer
    }
    
    private func requestPermissions() {
        // Request location permissions
        let locationStatus = locationManager.authorizationStatus
        if locationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if locationStatus == .authorizedWhenInUse {
            // Request "Always" authorization for background tracking
            locationManager.requestAlwaysAuthorization()
        }
        
        // Request HealthKit permissions - ensure heart rate is included
        if HKHealthStore.isHealthDataAvailable() {
            let typesToShare: Set<HKSampleType> = [
                HKObjectType.workoutType(),
                HKQuantityType.quantityType(forIdentifier: .heartRate)!,
                HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
                HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
            ]
            
            let typesToRead: Set<HKObjectType> = [
                HKObjectType.workoutType(),
                HKObjectType.quantityType(forIdentifier: .heartRate)!,
                HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
                HKObjectType.quantityType(forIdentifier: .bodyMass)!
            ]
            
            healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
                if let error = error {
                    print("❌ HealthKit authorization error: \(error.localizedDescription)")
                } else if success {
                    print("✅ HealthKit authorization granted (including heart rate)")
                }
            }
        }
    }
    
    private func fetchUserWeight() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        
        let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] (_, samples, error) in
            guard let self = self, let samples = samples as? [HKQuantitySample], let weightSample = samples.first else {
                print("No weight data available")
                return
            }
            
            let weightInKilograms = weightSample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            self.userWeight = weightInKilograms
            print("User weight: \(weightInKilograms) kg")
        }
        
        healthStore.execute(query)
    }
    
    private func checkForAnnouncements() {
        guard enableVoiceCoaching, isRunning else { return }
        
        let now = Date()
        
        // Check if it's time for an announcement based on frequency setting
        if let lastAnnouncement = lastAnnouncement {
            let timeSinceLastAnnouncement = now.timeIntervalSince(lastAnnouncement)
            
            // Determine if we should announce based on frequency type
            var shouldAnnounce = false
            var announcementMessage = ""
            
            // Check distance-based announcements
            if announcementFrequency > 0 && announcementFrequency <= 2000 { // Distance-based (meters)
                let distanceCovered = distance.value
                let lastAnnouncementDistance = (distanceCovered / announcementFrequency).rounded(.down) * announcementFrequency
                let nextAnnouncementDistance = lastAnnouncementDistance + announcementFrequency
                
                if distanceCovered >= nextAnnouncementDistance && timeSinceLastAnnouncement >= 20 {
                    shouldAnnounce = true
                    
                    // Format distance announcement
                    let distanceText = useMetric 
                        ? String(format: "%.1f kilometers", distanceCovered / 1000)
                        : String(format: "%.1f miles", distanceCovered / 1609.34)
                    
                    let paceText = formattedPace
                    announcementMessage = "You've covered \(distanceText) at a pace of \(paceText) per \(useMetric ? "kilometer" : "mile"). Keep it up!"
                }
            }
            // Check time-based announcements
            else if announcementFrequency > 2000 { // Time-based (seconds)
                let timeInterval = announcementFrequency
                if timeSinceLastAnnouncement >= timeInterval {
                    shouldAnnounce = true
                    
                    // Format time announcement
                    let timeText = formatTime(Int(elapsedTime))
                    let distanceText = useMetric 
                        ? String(format: "%.1f kilometers", distance.value / 1000)
                        : String(format: "%.1f miles", distance.value / 1609.34)
                    
                    announcementMessage = "Time: \(timeText), Distance: \(distanceText)"
                }
            }
            
            if shouldAnnounce {
                announceMessage(announcementMessage)
                // Trigger haptic feedback for voice announcements
                triggerHapticFeedback(.soft)
                self.lastAnnouncement = now
            }
        } else {
            // First announcement - do it after at least 100 meters or 1 minute
            if distance.value > 100 || elapsedTime > 60 {
                announceMessage("Run tracking has started. Good luck!")
                lastAnnouncement = now
            }
        }
        
        // Provide coaching tips if AI coaching is enabled
        if enableAICoaching {
            let minutesSinceStart = elapsedTime / 60
            if minutesSinceStart > 0 && Int(minutesSinceStart) % 5 == 0 && Int(elapsedTime) % 60 == 0 {
                provideCoachingTip()
            }
        }
    }
    
    private func provideCoachingTip() {
        let tips = runType.coachingTips
        
        if !tips.isEmpty {
            // Cycle through tips
            let tip = tips[nextCoachingTipIndex % tips.count]
            coachFeedback = tip
            
            // Announce tip if voice coaching is enabled
            if enableVoiceCoaching {
                announceMessage(tip)
                // Trigger haptic feedback for coaching tips
                triggerHapticFeedback(.medium)
            }
            
            // Move to next tip
            nextCoachingTipIndex += 1
        }
    }
    
    private func announceMessage(_ message: String) {
        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.1
        utterance.volume = 1.0
        
        // Use stored preferred voice
        if let preferredVoice = preferredVoice {
            utterance.voice = preferredVoice
        }
        
        speechSynthesizer.speak(utterance)
    }
    
    // MARK: - Haptic Feedback
    
    private func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard enableHapticFeedback else { return }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    private func triggerNotificationFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard enableHapticFeedback else { return }
        
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.prepare()
        notificationFeedback.notificationOccurred(type)
    }
    
    private func triggerSelectionFeedback() {
        guard enableHapticFeedback else { return }
        
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.prepare()
        selectionFeedback.selectionChanged()
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    private func loadSettings() {
        // Load user preferences
        let userPreferences = UserPreferences.shared
        useMetric = userPreferences.useMetricSystem
        
        // Load run settings
        let runSettings = RunSettingsManager.shared.currentSettings
        
        // Apply run settings
        enableVoiceCoaching = runSettings.announceIntervals
        enableAICoaching = runSettings.playAudioCues
        autoLockScreen = runSettings.autoLockScreen
        
        // Convert announcement frequency to seconds
        switch runSettings.announcementFrequency {
        case .off:
            announcementFrequency = 0
        case .kilometer:
            announcementFrequency = 1000 // 1 km in meters
        case .mile:
            announcementFrequency = 1609.34 // 1 mile in meters
        case .twoKilometers:
            announcementFrequency = 2000 // 2 km in meters
        case .fiveMinutes:
            announcementFrequency = 300 // 5 minutes in seconds
        case .tenMinutes:
            announcementFrequency = 600 // 10 minutes in seconds
        }
        
        // Apply display settings
        screenAlwaysOn = runSettings.screenAlwaysOn
        showHeatMap = runSettings.showHeatMap
        trackElevation = runSettings.trackElevation
        recordHeartRate = runSettings.recordHeartRate
        
        // Apply voice preferences
        preferredVoiceType = userPreferences.preferredVoiceType
        preferredVoice = preferredVoiceType.bestAvailableVoice
        
        // Enable haptic feedback by default (can be controlled by run settings later)
        enableHapticFeedback = runSettings.vibrateOnMilestones
        
        print("📱 Loaded settings - Metric: \(useMetric), Voice: \(enableVoiceCoaching), AI: \(enableAICoaching), AutoLock: \(autoLockScreen), Haptic: \(enableHapticFeedback)")
        
        // Test haptic feedback on settings load
        if enableHapticFeedback {
            triggerSelectionFeedback()
        }
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        
        defaults.set(useMetric, forKey: "useMetricSystem")
        defaults.set(enableVoiceCoaching, forKey: "enableVoiceCoaching")
        defaults.set(enableAICoaching, forKey: "enableAICoaching")
        defaults.set(autoLockScreen, forKey: "autoLockScreen")
        defaults.set(announcementFrequency, forKey: "announcementFrequency")
    }
    
    private func syncWithWorkoutManager() {
        // Sync with RunningWorkoutManager
        workoutManager.updateWorkoutMetrics(
            elapsedTime: elapsedTime,
            distance: distance.value,
            pace: pace.value,
            calories: calories,
            heartRate: heartRate
        )
        
        // Now also sync with the Watch app
        syncWithWatch()
        
        // If it's a group run, send metrics update
        if isGroupRun {
            updateGroupRunMetrics()
        }
    }
    
    // MARK: - Advanced Metric Collection
    
    private func processAccelerometerData(_ data: CMAccelerometerData) {
        // Enhanced step detection algorithm based on vertical acceleration
        let acceleration = sqrt(pow(data.acceleration.x, 2) + 
                               pow(data.acceleration.y, 2) + 
                               pow(data.acceleration.z, 2))
        
        // Detect step with improved threshold and filtering
        let stepThreshold = 1.3 // Adjust if needed for sensitivity
        
        if acceleration > stepThreshold {
            let currentTime = Date()
            
            if let lastStepTime = lastStepTimestamp {
                let timeSinceLastStep = currentTime.timeIntervalSince(lastStepTime)
                
                // Improved bounce filtering - time between actual footfalls (not just jostles)
                if timeSinceLastStep > 0.2 && timeSinceLastStep < 1.5 {
                    stepCount += 1
                    lastStepTimestamp = currentTime
                    
                    // Calculate cadence only after we have enough steps for accuracy
                    if elapsedTime > 10 && stepCount > 10 {
                        // Calculate running cadence (steps per minute)
                        // Use a time window approach for better accuracy
                        let stepsPerSecond = Double(stepCount) / elapsedTime
                        let rawCadence = stepsPerSecond * 60.0
                        
                        // Apply smoothing to cadence to prevent jumpy values
                        // If this is the first calculation, use raw value
                        if cadence == 0 {
                            cadence = rawCadence
                        } else {
                            // Otherwise use weighted average (80% previous, 20% new)
                            cadence = (cadence * 0.8) + (rawCadence * 0.2)
                        }
                        
                        // Update formatted cadence
                        if self.cadence > 0 {
                            self.formattedCadence = String(format: "%.0f spm", self.cadence)
                        }
                    }
                }
            } else {
                // First step detected
                lastStepTimestamp = currentTime
            }
        }
    }
    
    // MARK: - Heart Rate Management
    
    /// Updates heart rate with an integer value
    public func updateHeartRate(heartRate: Int) {
        updateHeartRate(Double(heartRate))
    }
    
    public func updateHeartRate(_ heartRate: Double) {
           // CRITICAL FIX: Stop processing heart rate updates when run is completed
        guard runState != .completed else {
            print("❤️ Ignoring heart rate update - run is completed")
            return
        }
        
        // Ensure we're on the main thread for all SwiftUI property updates
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.updateHeartRate(heartRate)
            }
            return
        }
        
        // Heart rate always comes from watch (watch is primary for heart rate)
        // Always accept heart rate updates from watch coordination
        // All of these property updates must happen on the main thread to avoid publishing errors
        self.currentHeartRate = heartRate
        self.heartRate = heartRate
        self.formattedHeartRate = String(format: "%.0f", heartRate)
        
        // Store heart rate in the array of readings
        if heartRateReadings.count >= 60 {
            heartRateReadings.removeFirst()
        }
        heartRateReadings.append(heartRate)
        
        // Update heart rate metrics (average, max, etc.)
        updateHeartRateMetrics(heartRate)
        
        // Update heart rate zone
        updateHeartRateZone()
        
        // Update calories if heart rate affects calculation
        updateCaloriesBurned()
        
        // Update formatted values to ensure UI reflects latest metrics
        updateFormattedValues()
        
        // Sync with workout manager and watch
        syncWithWorkoutManager()
        
        // Only log meaningful heart rate changes or periodic updates
        let now = Date()
        let timeSinceLastLog = now.timeIntervalSince(lastHeartRateLogTime)
        let heartRateChanged = abs(heartRate - lastLoggedHeartRate) >= 5
        
        if heartRateChanged || timeSinceLastLog >= 10.0 {
            print("❤️ Heart rate updated: \(Int(heartRate)) bpm")
            lastLoggedHeartRate = heartRate
            lastHeartRateLogTime = now
        }
        
        // Notify observers of heart rate update
        NotificationCenter.default.post(
            name: .heartRateUpdate,
            object: self,
            userInfo: ["heartRate": heartRate]
        )
        
        // Notify UI of metrics update
        NotificationCenter.default.post(name: .didUpdateRunMetrics, object: self)
        objectWillChange.send()
            
            // Update calories if heart rate affects calculation
            updateCaloriesBurned()
            
     
            
            if heartRateChanged || timeSinceLastLog >= 10.0 {
                print("❤️ Heart rate updated: \(Int(heartRate)) bpm")
                lastLoggedHeartRate = heartRate
                lastHeartRateLogTime = now
            }
            
            // Notify observers that heart rate has been updated
            NotificationCenter.default.post(name: .heartRateUpdate, object: self, userInfo: ["heartRate": heartRate])
        }
    
    
    // MARK: - External Metric Updates
    public func updateDistance(distance: Double) {
        // Only update if auto tracking is disabled
        if !autoTrackingEnabled {
            self.distance = Measurement(value: distance, unit: UnitLength.meters)
            self.formattedDistance = String(format: "%.2f", distance)
            
            // Update pace and calories based on new distance
            if elapsedTime > 0 && distance > 0 {
                let timeInMinutes = elapsedTime / 60.0
                
                // Calculate pace (minutes per km)
                // Calculate pace in seconds per km or per mile (time per distance)
                var paceInSeconds: Double = 0
                if useMetric {
                    paceInSeconds = elapsedTime / (distance / 1000.0)
                } else {
                    paceInSeconds = elapsedTime / (distance / 1609.34)
                }
                if paceInSeconds.isFinite && paceInSeconds > 0 {
                    let minutes = Int(paceInSeconds / 60)
                    let seconds = Int(paceInSeconds.truncatingRemainder(dividingBy: 60))
                    self.formattedPace = String(format: "%d'%02d\"", minutes, seconds)
                } else {
                    self.formattedPace = "-'--\""
                }

                
                // Recalculate calories
                // Simple MET-based calculation (rough estimate)
                let metValue = 7.0 // Average MET value for running
                let caloriesValue = (metValue * 3.5 * userWeight * timeInMinutes) / 200
                self.calories = caloriesValue
                self.formattedCalories = String(format: "%.0f", caloriesValue)
            }
            
            // Update overall run metrics
            updateRunMetrics()
        }
    }
    
    public func updateCalories(calories: Double) {
        // Only update if auto tracking is disabled
        if !autoTrackingEnabled {
            self.calories = calories
            self.formattedCalories = String(format: "%.0f", calories)
        }
    }
    
    public func updateCadenceDirectly(cadence: Double) {
        // Only update if auto tracking is disabled
        if !autoTrackingEnabled {
            self.currentCadence = cadence
            self.cadence = cadence
            self.formattedCadence = String(format: "%.0f", cadence)
        }
    }
    
    // MARK: - Watch Data Integration
    
    /// Updates the distance directly from external source (e.g., watch)
    func updateDistance(_ newDistance: Double) {
        // Only update if we're not in auto-tracking mode to avoid conflicts
        guard !isAutoTrackingEnabled else { return }
        
        // Update the distance
        distance.value = newDistance
        
        // Format the distance value
        updateDistanceFormat()
        
        // Update pace based on new distance
        updatePace()
        
        // Update calories based on the new distance
        updateCaloriesBurned()
        
        // Update overall run metrics
        updateRunMetrics()
    }
    
    /// Updates calories directly from external source (e.g., watch)
    func updateCalories(_ calories: Double) {
        // Only update if we're not calculating calories internally or if the watch is the primary source
        guard !autoTrackingEnabled || !isPrimaryForCalories else { 
            print("🔥 CALORIES UPDATE BLOCKED - autoTracking: \(autoTrackingEnabled), isPrimaryForCalories: \(isPrimaryForCalories)")
            return 
        }
        
        print("🔥 CALORIES UPDATE ACCEPTED - Old: \(self.calories)cal, New: \(calories)cal, isPrimaryForCalories: \(isPrimaryForCalories)")
        self.calories = calories
        self.formattedCalories = String(format: "%.0f", calories)
        
        // Since we updated calories, make sure UI is updated too
        updateFormattedValues()
    }
    
    /// Updates cadence directly from external source (e.g., watch)
    func updateCadenceDirectly(_ newCadence: Double) {
        // Only update if we're not calculating cadence from motion
        guard !isAutoTrackingEnabled else { return }
        
        cadence = newCadence
        formattedCadence = String(format: "%.0f", cadence)
    }
    
    private func updateHeartRateZone() {
        // Ensure we're on the main thread when updating published properties
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.updateHeartRateZone()
            }
            return
        }
        
        // Calculate heart rate zones based on max heart rate
        let percentage = heartRate / maxHeartRate
        
        switch percentage {
        case 0..<0.5:
            heartRateZone = .none
        case 0.5..<0.6:
            heartRateZone = .recovery
        case 0.6..<0.7:
            heartRateZone = .easy
        case 0.7..<0.8:
            heartRateZone = .aerobic
        case 0.8..<0.9:
            heartRateZone = .threshold
        case 0.9...:
            heartRateZone = .anaerobic
        default:
            heartRateZone = .none
        }
    }
    
    private func checkForSplitTime() {
        // Calculate split times (for each km or mile)
        // Default to miles unless metric system is specifically enabled
        let distanceUnit: Double = useMetric ? 1000.0 : 1609.34 // 1 km or 1 mile in meters
        let currentDistance = distance.value
        
        // Check if we've completed another km/mile
        let splitNumber = Int(currentDistance / distanceUnit)
        let previousSplitNumber = Int(lastSplitDistance / distanceUnit)
        
        if splitNumber > previousSplitNumber {
            // Calculate this split
            // Convert split distance to meters
            let splitDistanceInMeters = Double(splitNumber) * distanceUnit
            let splitTime = elapsedTime - lastSplitTime
            
            // Calculate pace for this split in seconds per meter
            // pace = time (seconds) / distance (meters)
            let paceInSecondsPerMeter = splitTime / splitDistanceInMeters
            
            // Add to splits array
            let newSplit = SplitTime(
                distance: splitDistanceInMeters,
                time: splitTime,
                pace: paceInSecondsPerMeter
            )
            splitTimes.append(newSplit)
            
            // Update for next split
            lastSplitTime = elapsedTime
            lastSplitDistance = Double(splitNumber) * distanceUnit
            
            // Trigger haptic feedback for milestone achievement
            triggerHapticFeedback(.light)
            
            print("📱 🎯 Milestone achieved: \(splitNumber) \(useMetric ? "km" : "mile") in \(formatTime(Int(splitTime)))")
        }
    }
    
    private func updatePaceConsistency() {
        // Only update if there's a valid pace
        if pace.value > 0 {
            // Add to pace history for consistency tracking
            paceHistory.append(pace.value)
            
            // Keep the history to a reasonable size
            if paceHistory.count > 30 {
                paceHistory.removeFirst()
            }
            
            // Calculate consistency once we have enough data
            if paceHistory.count >= 10 {
                // Calculate average pace
                let average = paceHistory.reduce(0, +) / Double(paceHistory.count)
                
                // Calculate average deviation from the mean
                let deviations = paceHistory.map { abs($0 - average) }
                let avgDeviation = deviations.reduce(0, +) / Double(deviations.count)
                
                // Convert to a 0-100 scale (lower deviation = higher score)
                // Typical deviation values range from 5-30 seconds
                let maxDeviation = average * 0.3 // 30% of average pace as max deviation
                let consistencyScore = 100 - min(100, (avgDeviation / maxDeviation) * 100)
                
                // CRITICAL FIX: Update UI properties on main thread to avoid SwiftUI errors
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // Update the consistency score
                    self.aiAnalysisResults.paceConsistency = consistencyScore
                    
                    // Print for debugging
                    print("📊 Pace consistency updated: \(consistencyScore)% (avg deviation: \(avgDeviation)s)")
                }
            } else {
                // Not enough data yet
                print("📊 Building pace history: \(paceHistory.count)/30 data points")
            }
        }
    }
    
    // Fetch weather data
    private func checkForWeatherUpdate(_ location: CLLocation) {
        guard let lastCheck = lastLocationForWeather else {
            // First time, get weather
            fetchWeatherFor(location)
            lastLocationForWeather = location
            return
        }
        
        // Check if we should update (every 1km or 15 minutes)
        let distanceFromLastCheck = location.distance(from: lastCheck)
        let timeInterval = lastLocationForWeather?.timestamp.timeIntervalSinceNow.magnitude ?? 0
        
        if distanceFromLastCheck > 1000 || timeInterval > 900 { // 1km or 15 minutes
            fetchWeatherFor(location)
            lastLocationForWeather = location
        }
    }
    
    private func fetchWeatherFor(_ location: CLLocation) {
        // Use the WeatherService we updated with Met.no API
        Task {
            let weatherResult = await weatherService.fetchWeather(for: location)
            
            if let metNoWeather = weatherResult.0, weatherResult.1 == nil {
                // Convert from our shared WeatherData to the RunTrackingEngine's internal WeatherData
                let runTrackerWeather = WeatherData(
                    temperature: metNoWeather.temperature,
                    condition: metNoWeather.condition.rawValue, // Convert enum to string
                    windSpeed: metNoWeather.windSpeed,
                    humidity: metNoWeather.humidity,
                    icon: metNoWeather.condition.icon // Use the icon from our enum
                )
                
                // Update UI on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.currentWeather = runTrackerWeather
                    
                    // Update environmental conditions
                    self.environmentalConditions.temperature = runTrackerWeather.temperature
                    self.environmentalConditions.humidity = runTrackerWeather.humidity
                    self.environmentalConditions.windSpeed = runTrackerWeather.windSpeed
                    self.environmentalConditions.weatherCondition = runTrackerWeather.condition
                    self.environmentalConditions.elevation = location.altitude
                    
                    // Provide weather-based coaching if significant
                    if let temperature = self.environmentalConditions.temperature, temperature > 28 && self.elapsedTime > 600 {
                        self.coachFeedback = "It's getting hot. Remember to stay hydrated and adjust your pace accordingly."
                    } else if let windSpeed = self.environmentalConditions.windSpeed, windSpeed > 8 {
                        self.coachFeedback = "You're running against a strong wind. Shorten your stride and lean forward slightly."
                    }
                }
            } else if let error = weatherResult.1 {
                print("Error fetching weather from Met.no: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateAIFormAnalysis() {
        // This would typically use ML algorithms to analyze form
        // For demonstration, we'll provide meaningful form analysis based on metrics
        
        var formIssues: [String] = []
        var formStrengths: [String] = []
        var suggestions: [String] = []
        
        // Analyze cadence (optimal around 170-180 steps per minute)
        // Proper cadence helps reduce injury and improves efficiency
        if cadence < 150 {
            formIssues.append("Very low cadence")
            suggestions.append("Try to increase your cadence to 170-180 steps per minute for better efficiency")
            suggestions.append("Consider using a metronome app to practice at higher cadence")
            formFeedback = FormFeedback(
                cadenceFeedback: "Your cadence is very low. You're likely overstriding, which increases impact forces.",
                overallAssessment: "Your running form needs significant adjustment",
                improvementSuggestions: suggestions
            )
        } else if cadence >= 150 && cadence < 165 {
            formIssues.append("Low cadence")
            suggestions.append("Gradually increase your cadence by 5-10% over the next few weeks")
            suggestions.append("Focus on taking quicker, lighter steps rather than longer strides")
            formFeedback = FormFeedback(
                cadenceFeedback: "Your cadence is a bit low. Aim for shorter, quicker steps.",
                overallAssessment: "Your running form could benefit from some adjustments",
                improvementSuggestions: suggestions
            )
        } else if cadence > 190 && cadence <= 210 {
            formIssues.append("High cadence")
            suggestions.append("Your cadence is higher than typical. This may be fine if you're comfortable.")
            suggestions.append("Consider if you're taking steps that are too short for optimal efficiency")
            formFeedback = FormFeedback(
                cadenceFeedback: "Your cadence is high. This may be your natural rhythm, but ensure you're not taking excessively short steps.",
                overallAssessment: "Your form is generally good but could be fine-tuned",
                improvementSuggestions: suggestions
            )
        } else if cadence > 210 {
            formIssues.append("Extremely high cadence")
            suggestions.append("Your cadence is unusually high - try to lengthen your stride slightly")
            suggestions.append("Focus on pushing off more powerfully with each step")
            formFeedback = FormFeedback(
                cadenceFeedback: "Your cadence is very high. You might be taking inefficiently short steps.",
                overallAssessment: "Your running form needs adjustment for better efficiency",
                improvementSuggestions: suggestions
            )
        } else {
            // Optimal cadence range (165-190)
            formStrengths.append("Optimal cadence")
            formFeedback = FormFeedback(
                cadenceFeedback: "Great cadence! You're in the optimal range for efficiency and injury prevention.",
                overallAssessment: "Your running form shows good rhythm and timing",
                improvementSuggestions: ["Maintain this excellent cadence", "Focus on other aspects of form like posture and arm swing"]
            )
        }
        
        // Analyze stride length
        if strideLength.value > 0 {
            let strideInMeters = strideLength.value
            
            // Calculate optimal stride length based on height - rough approximation
            // Assume average height as default (170cm / 5'7")
            let estimatedHeight = 170.0 
            let optimalStride = estimatedHeight / 100.0 * 1.2 // Roughly 1.2x height in cm -> meters
            
            if strideInMeters < (optimalStride * 0.8) {
                formIssues.append("Short stride length")
                formFeedback?.strideLengthFeedback = "Your stride length is shorter than optimal. This may be fine with higher cadence, but could limit your speed."
            } else if strideInMeters > (optimalStride * 1.2) {
                formIssues.append("Excessive stride length")
                formFeedback?.strideLengthFeedback = "Your stride appears too long, which can increase impact forces and injury risk. Try shorter, quicker steps."
            } else {
                formStrengths.append("Good stride length")
                formFeedback?.strideLengthFeedback = "Your stride length is in a good range for your estimated height and pace."
            }
        }
        
        // Calculate overall form efficiency (0-100%)
        // Weight cadence more heavily as it's more important for injury prevention
        let cadenceScore = computeCadenceScore(cadence)
        let heartRateScore = heartRateZone == .anaerobic ? 60.0 : 100.0 // Penalize if in anaerobic zone for too long
        let strideLengthScore = computeStrideLengthScore(strideLength.value)
        
        // Break down the complex expression into simpler parts
        let cadenceComponent = cadenceScore * 0.5
        let heartRateComponent = heartRateScore * 0.3
        let strideComponent = strideLengthScore * 0.2
        
        // Calculate efficiency by adding components
        let efficiency = cadenceComponent + heartRateComponent + strideComponent
        runningEfficiency = efficiency
        
        // Update AI analysis results
        aiAnalysisResults.formEfficiency = efficiency
        aiAnalysisResults.strengths = formStrengths
        aiAnalysisResults.weaknesses = formIssues
        
        // Calculate fatigue level based on heart rate drift and pace changes
        if heartRateReadings.count > 30 {
            let initialHR = heartRateReadings.prefix(10).reduce(0, +) / 10
            let currentHR = heartRateReadings.suffix(10).reduce(0, +) / 10
            let hrDrift = (currentHR - initialHR) / initialHR * 100
            
            // Higher drift indicates more fatigue
            aiAnalysisResults.fatigueLevel = min(100, max(0, hrDrift * 5))
            
            // Provide recovery recommendation based on fatigue
            let baseFactor = 0.33 // Base recovery factor (1/3 of workout time)
            let fatigueFactor = 1.0 + ((aiAnalysisResults.fatigueLevel ?? 0.0) / 100.0) // Add up to 100% more based on fatigue
            aiAnalysisResults.predictedRecoveryTime = elapsedTime * baseFactor * fatigueFactor
            aiAnalysisResults.recommendedRecoveryTime = elapsedTime * baseFactor * fatigueFactor
        }
    }
    
    // Helper function to compute cadence score (0-100)
    private func computeCadenceScore(_ cadence: Double) -> Double {
        if cadence <= 0 {
            return 0
        } else if cadence < 150 {
            // Very low cadence: score scales from 0-50
            return min(50, cadence / 3.0)
        } else if cadence < 165 {
            // Low cadence: score scales from 50-75
            return 50 + ((cadence - 150) / 15.0) * 25
        } else if cadence <= 190 {
            // Optimal cadence: score scales from 75-100
            // Peak score of 100 at around 178 steps/min
            let distanceFromOptimal = abs(cadence - 178)
            let maxDeviation = 13.0 // 178±13 = range of 165-190
            return 100 - (distanceFromOptimal / maxDeviation) * 25
        } else if cadence <= 210 {
            // High cadence: score scales from 75-50
            return 75 - ((cadence - 190) / 20.0) * 25
        } else {
            // Very high cadence: score scales from 50-0
            return max(0, 50 - ((cadence - 210) / 30.0) * 50)
        }
    }
    
    // Helper function to compute stride length score (0-100)
    private func computeStrideLengthScore(_ strideLength: Double) -> Double {
        if strideLength <= 0 {
            return 0 // No stride data available
        }
        
        // Estimate optimal stride range based on average height
        let estimatedHeight = 170.0 // cm
        let optimalStride = estimatedHeight / 100.0 * 1.2 // Convert to meters
        
        // Calculate deviation from optimal
        let deviation = abs(strideLength - optimalStride) / optimalStride
        
        // Score based on deviation
        if deviation <= 0.1 {
            // Within 10% of optimal - excellent
            return 90 + (1.0 - deviation / 0.1) * 10
        } else if deviation <= 0.2 {
            // Within 20% of optimal - good
            return 70 + (0.2 - deviation) / 0.1 * 20
        } else if deviation <= 0.4 {
            // Within 40% of optimal - fair
            return 30 + (0.4 - deviation) / 0.2 * 40
        } else {
            // More than 40% from optimal - poor
            return max(0, 30 - (deviation - 0.4) / 0.6 * 30)
        }
    }
    
    // MARK: - Public API
    
    /// Get current heart rate zone color
    func heartRateZoneColor() -> UIColor {
        return heartRateZone.color
    }
    
    /// Get pace consistency data for charts
    func getPaceConsistencyData() -> [Double] {
        // If no pace data, return empty array
        if paceHistory.isEmpty {
            return []
        }
        
        // For better visualization, limit to the most recent 30 data points
        let maxPoints = 30
        let recentData = paceHistory.count > maxPoints ? Array(paceHistory.suffix(maxPoints)) : paceHistory
        
        // Convert from seconds/km to minutes/km for readability
        return recentData.map { $0 / 60.0 }
    }
    
    
    /// Request fresh AI coaching feedback
    func requestCoachingFeedback() {
        updateAIFormAnalysis()
        provideCoachingTip()
    }
    
    // MARK: - Group Run Methods
    
    /// Initialize a new group run as the host
    func startGroupRun(type: GroupRunType, participants: [UserModel], scheduledStart: Date? = nil, targetDistance: Double? = nil, message: String? = nil) {
        guard let currentUserId = UserIDHelper.shared.getCurrentUserID() else { return }
        let currentUser = CurrentUserService.shared.user
        
        // Set up group run properties
        isGroupRun = true
        isHostingGroupRun = true
        groupRunType = type
        groupRunId = UUID().uuidString // Generate a new unique ID for this group run
        
        // Convert UserModel participants to GroupRunParticipants
        var runParticipants: [GroupRunParticipant] = []
        
        // Add the current user as host with "active" status
        let host = GroupRunParticipant(
            userId: currentUserId,
            userName: currentUser.userName ?? "",
            displayName: currentUser.name ?? "",
            profileImageURL: nil,
            status: .active,
            stats: GroupRunStats()
        )
        runParticipants.append(host)
        
        // Add invited participants
        for participant in participants {
            let runParticipant = GroupRunParticipant(
                userId: participant.userID ?? "",
                userName: participant.userName ?? "",
                displayName: participant.name ?? "",
                profileImageURL: nil,
                status: .invited,
                stats: nil
            )
            runParticipants.append(runParticipant)
        }
        
        // Update participants list
        groupRunParticipants = runParticipants
        
        // Create and send invitations
        sendGroupRunInvitations(type: type, scheduledStart: scheduledStart, distance: targetDistance, message: message)
        
        // Configure run settings based on group run type
        configureGroupRunSettings(type: type, targetDistance: targetDistance)
    }
    
    
    /// Join an existing group run from an invitation
    func joinGroupRun(invitation: GroupRunInvitation) {
        guard let currentUser = UserIDHelper.shared.getCurrentUserID() else { return }
        
        // Set up group run properties
        isGroupRun = true
        isHostingGroupRun = false
        groupRunType = invitation.runType
        groupRunInvitation = invitation
        groupRunId = invitation.id.uuidString // Set the group run ID from the invitation
        
        // Update participant status
        updateParticipantStatus(status: .accepted)
        
        // Configure run settings based on group run type
        if let distance = invitation.distance {
            configureGroupRunSettings(type: invitation.runType, targetDistance: distance * 1000) // Convert km to meters
        } else {
            configureGroupRunSettings(type: invitation.runType, targetDistance: nil)
        }
        
        // Notify the host that we've joined
        sendParticipantStatusUpdate(.accepted)
    }
    
    /// Send invitations to all participants
    public func sendGroupRunInvitations(type: GroupRunType, scheduledStart: Date? = nil, distance: Double? = nil, message: String? = nil) {
       
    }
    
    /// Configure run settings for specific group run types
    private func configureGroupRunSettings(type: GroupRunType, targetDistance: Double?) {
        switch type {
        case .race:
            // For races, use outdoor run type
            updateRunType(.outdoorRun)
            
            // Set target distance if provided
            if let targetDistance = targetDistance {
                self.targetDistance = Measurement(value: targetDistance, unit: .meters)
            }
            
        case .groupRun:
            // For group runs, use outdoor run type
            updateRunType(.outdoorRun)
            
            // Group runs don't typically have a target distance
            self.targetDistance = nil
            
        case .trainingSession:
            // For training sessions, use interval training
            updateRunType(.intervalTraining)
            
            // Training sessions may have a target distance
            if let targetDistance = targetDistance {
                self.targetDistance = Measurement(value: targetDistance, unit: .meters)
            }
        }
    }
    
    /// Update status of current user as a participant
    func updateParticipantStatus(status: ParticipantStatus) {
        guard let currentUser = UserIDHelper.shared.getCurrentUserID() else { return }
        
        // Update local state
        for i in 0..<groupRunParticipants.count {
            if groupRunParticipants[i].userId == currentUser {
                groupRunParticipants[i].status = status
                break
            }
        }
        
        // Send status update to host/participants
        sendParticipantStatusUpdate(status)
    }
    
    /// Send status update to host/participants
    private func sendParticipantStatusUpdate(_ status: ParticipantStatus) {
        guard let currentUserId = UserIDHelper.shared.getCurrentUserID(),
              let invitationId = groupRunInvitation?.id.uuidString else { return }
        
        // Prepare status update data
        var statusUpdate: [String: Any] = [:]
        statusUpdate["invitationId"] = invitationId
        statusUpdate["userId"] = currentUserId
        statusUpdate["userName"] = UserIDHelper.shared.getCurrentUsername() ?? ""
        statusUpdate["status"] = status.rawValue
        
        // Add stats if available and status is active/completed
        if status == .active || status == .completed {
            statusUpdate["distance"] = distance.value
            statusUpdate["duration"] = elapsedTime
            statusUpdate["pace"] = pace.value
            statusUpdate["heartRate"] = heartRate
        }
        
        // TODO: Implement AWS-based status update system
        // For now, just log the status update locally
        print("📱 Group run status update:")
        print("   User: \(currentUserId)")
        print("   Invitation ID: \(invitationId)")
        print("   Status: \(status.rawValue)")
        if status == .active || status == .completed {
            print("   Distance: \(distance.value)m")
            print("   Duration: \(elapsedTime)s")
            print("   Pace: \(pace.value)s/km")
            print("   Heart Rate: \(heartRate)bpm")
        }
    }
    
    /// Send invitation push notifications to participants
    private func sendInvitationPushNotifications(invitation: GroupRunInvitation) {
       
    }
    
    /// Update group run with latest metrics from all participants
    func updateGroupRunMetrics() {
        guard isGroupRun else { return }
        
        // If hosting, broadcast our metrics to participants
        if isHostingGroupRun {
            broadcastRunMetricsToParticipants()
        } else {
            // If participating, send metrics to host
            sendMetricsToHost()
        }
    }
    
    /// Broadcast metrics to all participants if we're the host
    private func broadcastRunMetricsToParticipants() {
        guard isHostingGroupRun, let invitationId = groupRunInvitation?.id.uuidString else { return }
        
        // Prepare metrics data
        let metricsData: [String: Any] = [
            "invitationId": invitationId,
            "hostDistance": distance.value,
            "hostDuration": elapsedTime,
            "hostPace": pace.value,
            "hostHeartRate": heartRate,
            "timestamp": Date()
        ]
        
        // In a real app, this would send the data to participants via Parse Live Query
        // or another real-time communication channel
        print("Broadcasting metrics to participants: \(metricsData)")
    }
    
    /// Send metrics to host if we're a participant
    private func sendMetricsToHost() {
        guard !isHostingGroupRun,
              let invitationId = groupRunInvitation?.id.uuidString,
              let currentUserId = UserIDHelper.shared.getCurrentUserID() else { return }
        
        // Prepare metrics data
        var metricsData: [String: Any] = [:]
        metricsData["invitationId"] = invitationId
        metricsData["userId"] = currentUserId
        metricsData["userName"] = UserIDHelper.shared.getCurrentUsername() ?? ""
        metricsData["distance"] = distance.value
        metricsData["duration"] = elapsedTime
        metricsData["pace"] = pace.value
        metricsData["heartRate"] = heartRate
        metricsData["timestamp"] = Date().timeIntervalSince1970
        
        // TODO: Implement AWS-based group run metrics sync
        // For now, just log the metrics
        print("Sending metrics to host: \(metricsData)")
    }
    
    // MARK: - Additional Watch Communication
    
    private func syncWithWatch() {
        guard WCSession.isSupported() else { return }
        
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        
        // Don't send updates back to the watch when we're processing a remote state change
        if isHandlingRemoteStateChange {
            print("📱 Skipping syncWithWatch - handling remote state change")
            return
        }
        
        // Only send updates every 2 seconds to reduce communication overhead
        let currentTime = Date().timeIntervalSince1970
        if currentTime - lastWatchSyncTime < 2.0 { return }
        lastWatchSyncTime = currentTime
        
        // Prepare metrics that the phone is primary for
        let metricsToSend: [String: Any] = [
            "distance": isPrimaryForDistance ? distance.value : 0,
            "elapsedTime": elapsedTime,
            "pace": isPrimaryForPace ? pace.value : 0,
            "calories": isPrimaryForCalories ? calories : 0,
            "heartRate": isPrimaryForHeartRate ? heartRate : 0,
            "cadence": isPrimaryForCadence ? cadence : 0
        ]
        
        let updateData: [String: Any] = [
            "type": "workoutUpdate",
            "runState": runState.rawValue,
            "metrics": metricsToSend,
            "isPrimaryForDistance": isPrimaryForDistance,
            "isPrimaryForPace": isPrimaryForPace,
            "isPrimaryForHeartRate": isPrimaryForHeartRate,
            "isPrimaryForCalories": isPrimaryForCalories,
            "isPrimaryForCadence": isPrimaryForCadence,
            "runType": runType.rawValue,
            "isIndoor": isIndoorMode,
            "isDashboardMode": isDashboardMode,
            "isWatchTracking": isWatchTracking,
            "hasGoodLocationData": hasGoodLocationData,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Log what we're sending to help with debugging
        print("📱 Syncing with watch: state=\(runState.rawValue), isPrimaryForDistance=\(isPrimaryForDistance), isIndoor=\(isIndoorMode)")
        
        session.sendMessage(updateData, replyHandler: { response in
            if let status = response["status"] as? String, status == "success" {
                // Watch received the update
                print("📱 Watch confirmed workout update received")
            }
            
            // Process any metrics from the watch in the response
            if let watchMetrics = response["metrics"] as? [String: Any] {
                // Use the metrics coordinator to process watch data
                self.metricsCoordinator?.processWatchMetrics(metrics: watchMetrics)
            }
        }, errorHandler: { error in
            print("📱 Error sending workout update to watch: \(error.localizedDescription)")
        })
        
        // Note: Removed updateApplicationContext() call here to prevent conflicts during remote state changes
        // The main updateApplicationContext() method already has protection for isHandlingRemoteStateChange
    }
    
    // MARK: - Additional Private Properties
    
    private var lastWatchSyncTime: TimeInterval = 0
    
    // Add this method for calculating smoothed pace
    private func calculateSmoothedPace() -> Double {
        // Calculate the raw pace using the standard formula (time / distance)
        let rawPaceSecondsPerKm: Double
        
        if distance.value > 0 && elapsedTime > 0 {
            // Calculate pace in seconds per kilometer
            rawPaceSecondsPerKm = elapsedTime / (distance.value / 1000)
        } else {
            return 0 // Cannot calculate without distance and time
        }
        
        // Use a simpler smoothing approach that's more similar to what the watch uses
        // This ensures better consistency between devices
        
        // If we have recent enough locations and meaningful recent movement
        if locationList.count >= 5 {
            // Take the 5 most recent locations (reduced from 10 for more immediate feedback)
            let recentLocations = Array(locationList.suffix(5))
            
            // Calculate recent distance and time
            var recentDistance: Double = 0
            if recentLocations.count > 1 {
                for i in 1..<recentLocations.count {
                    recentDistance += recentLocations[i-1].distance(from: recentLocations[i])
                }
            }
            
            let recentTimeInterval = recentLocations.last!.timestamp.timeIntervalSince(recentLocations.first!.timestamp)
            
            // If we have meaningful data from recent locations, calculate recent pace
            if recentDistance > 10 && recentTimeInterval > 2 {
                // Recent pace in seconds per kilometer
                let recentPaceSecondsPerKm = (recentTimeInterval / (recentDistance / 1000))
                
                // More weight to recent pace (80% recent, 20% overall) for faster response
                // This makes the phone's pace more responsive, similar to the watch
                let weightedPace = (recentPaceSecondsPerKm * 0.8) + (rawPaceSecondsPerKm * 0.2)
                
                // Add to smoothing array (but don't add outliers)
                if weightedPace < rawPaceSecondsPerKm * 3 && weightedPace > rawPaceSecondsPerKm * 0.33 {
                    paceSmoothing.append(weightedPace)
                } else {
                    // If pace seems unrealistic, use raw pace instead
                    paceSmoothing.append(rawPaceSecondsPerKm)
                }
            } else {
                // Fall back to overall pace if recent pace calculation isn't reliable
                paceSmoothing.append(rawPaceSecondsPerKm)
            }
        } else {
            // Not enough locations yet, use overall pace
            paceSmoothing.append(rawPaceSecondsPerKm)
        }
        
        // Keep a smaller window for more responsive changes
        let maxSamples = min(5, maxPaceSamples) // Use at most 5 samples for faster response
        if paceSmoothing.count > maxSamples {
            paceSmoothing.removeFirst(paceSmoothing.count - maxSamples)
        }
        
        // Calculate smoothed pace from samples
        let smoothedPaceSecondsPerKm = paceSmoothing.reduce(0, +) / Double(paceSmoothing.count)
        
        return smoothedPaceSecondsPerKm
    }
    
    // Update the updateRunMetrics method to use smoothed pace
    private func updateRunMetrics(withLocation location: CLLocation? = nil) {
        let currentTime = Date().timeIntervalSince1970
        
        // Update metrics from location if provided
        if let location = location {
            // Location-based metrics update logic remains the same
            // ...existing code...
        }
        
        // Update pace with timing restrictions to avoid glitchy appearance
        if currentTime - lastPaceUpdateTime >= paceUpdateThreshold {
            // Calculate smoothed pace in seconds per kilometer
            let smoothedPaceSecondsPerKm = calculateSmoothedPace()
            
            // Only update if pace has changed enough to be noticeable
            // We need to compare against our current pace value in meters per second
            // Convert the new seconds/km pace to m/s for comparison
            let currentPaceInMps = pace.value
            let newPaceInMps = smoothedPaceSecondsPerKm > 0 ? 1000.0 / smoothedPaceSecondsPerKm : 0
            
            if currentPaceInMps == 0 || abs(newPaceInMps - currentPaceInMps) > 0.1 {  // 0.1 m/s is about 3.6 sec/km at typical running speeds
                // Store as meters per second in the pace measurement
                pace = Measurement(value: newPaceInMps, unit: UnitSpeed.metersPerSecond)
                lastPaceUpdateTime = currentTime
                
                // Print for debugging
                print("📊 Pace updated: \(smoothedPaceSecondsPerKm) seconds/km (converted to \(newPaceInMps) m/s)")
            }
        }
    }
    
    private func updateDistanceFormat() {
        let distanceValue = distance.value
        
        if useMetric {
            if distanceValue < 1000 {
                // Display in meters if less than 1 km
                formattedDistance = String(format: "%.0f", distanceValue) + " m"
            } else {
                // Display in kilometers with 2 decimal places
                let kilometers = distanceValue / 1000.0
                formattedDistance = String(format: "%.2f", kilometers) + " km"
            }
        } else {
            // Imperial - convert to miles
            let miles = distanceValue / 1609.34
            
            if miles < 0.1 {
                // Display in feet if less than 0.1 miles
                let feet = distanceValue * 3.28084
                formattedDistance = String(format: "%.0f", feet) + " ft"
            } else {
                // Display in miles with 2 decimal places
                formattedDistance = String(format: "%.2f", miles) + " mi"
            }
        }
    }
    
    // MARK: - Heart Rate Methods
    
    /// Get the maximum heart rate based on user age
    func getMaxHeartRate() -> Double {
        // Use the common formula: 220 - age
        maxHeartRate = 220.0 - Double(age)
        return maxHeartRate
    }
    
    // MARK: - Unit Conversion Utilities
    
    /// Convert distance from meters to display units (km or miles)
    func convertDistanceToDisplayUnits(_ distanceInMeters: Double) -> Double {
        return useMetric ? distanceInMeters / 1000.0 : distanceInMeters / 1609.34
    }
    
    /// Convert distance from display units (km or miles) to meters
    func convertDisplayUnitsToMeters(_ distance: Double) -> Double {
        return useMetric ? distance * 1000.0 : distance * 1609.34
    }
    
    /// Convert elevation from meters to display units (m or ft)
    func convertElevationToDisplayUnits(_ elevationInMeters: Double) -> Double {
        return useMetric ? elevationInMeters : elevationInMeters * 3.28084
    }
    
    /// Get the current display unit string for distance
    func getDistanceUnitString() -> String {
        return useMetric ? "km" : "mi"
    }
    
    /// Get the current display unit string for elevation
    func getElevationUnitString() -> String {
        return useMetric ? "m" : "ft"
    }
    
    /// Get the current display unit string for pace
    func getPaceUnitString() -> String {
        return useMetric ? "min/km" : "min/mi"
    }
    
    /// Update pace calculation based on recent locations
    private func updatePace() {
        // This method is now deprecated - we use updateRunMetrics with improved calculateSmoothedPace instead
        // Just call updateRunMetrics directly which has proper throttling and smoothing
        updateRunMetrics()
    }
    
    // MARK: - Formatting Methods
    
    /// Format pace value to display string
    private func formatPace(_ paceInMinutesPerKm: Double) -> String {
        let minutes = Int(paceInMinutesPerKm)
        let seconds = Int((paceInMinutesPerKm - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Update the run type and configure tracking accordingly
    func updateRunType(_ newType: RunType) {
        // Only update if the type has changed
        guard runType != newType else { return }
        
        runType = newType
        isIndoorMode = (newType == .treadmillRun)
        
        // Configure tracking based on run type
        if isIndoorMode {
            // Stop location updates for indoor runs
            locationManager.stopUpdatingLocation()
            // Clear any existing location data
            locationList.removeAll()
            hasGoodLocationData = false
            isPrimaryForDistance = false
            isPrimaryForPace = false
        } else {
            // Start location updates for outdoor runs
            locationManager.startUpdatingLocation()
        }
        
        // Update application context to reflect changes
        let session = WCSession.default
        print("[WatchComm] updateApplicationContext: activationState=\(session.activationState.rawValue), isPaired=\(session.isPaired), isWatchAppInstalled=\(session.isWatchAppInstalled), isReachable=\(session.isReachable)")
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else {
            print("[WatchComm] Not updating application context: activationState=\(session.activationState.rawValue), isPaired=\(session.isPaired), isWatchAppInstalled=\(session.isWatchAppInstalled)")
            return
        }
        
        updateApplicationContext()
    }
    
    // Add properties for tracking status update throttling
    private var lastStatusUpdateTime: TimeInterval = 0
    private var lastStatusContent: String = ""
    private var consecutiveIdenticalUpdates: Int = 0
    
    // Send tracking status update to the watch
    private func sendTrackingStatusUpdate() {
        // Don't send updates back to watch when we're processing a state change from the watch
        if isHandlingRemoteStateChange {
            print("📱 🎯 Skipping sendTrackingStatusUpdate - handling remote state change from watch")
            return
        }
        
        // Check if we should try to reset the circuit breaker
        checkAndResetCircuitBreaker()
        
        // Skip update if circuit breaker is open
        if watchCircuitBreakerOpen {
            return
        }
        
        // Rest of the original method remains the same
        // Throttle updates to prevent excessive communication
        let now = Date().timeIntervalSince1970
        if now - lastStatusUpdateTime < 3.0 {
            // Skip if we've sent an update in the last 3 seconds
            return
        }
        lastStatusUpdateTime = now
        
        // Move watch communication to background queue to prevent blocking the main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let session = WCSession.default
            print("[WatchComm] sendTrackingStatusUpdate: activationState=\(session.activationState.rawValue), isPaired=\(session.isPaired), isWatchAppInstalled=\(session.isWatchAppInstalled), isReachable=\(session.isReachable)")
            guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else {
                print("[WatchComm] Not sending update: activationState=\(session.activationState.rawValue), isPaired=\(session.isPaired), isWatchAppInstalled=\(session.isWatchAppInstalled)")
                return
            }
            
            // NEW: Skip if watch not reachable and increment error count
            if !session.isReachable {
                self.handleWatchCommunicationError(NSError(domain: "com.do.runtracking", code: 1, userInfo: [NSLocalizedDescriptionKey: "Watch not reachable"]))
                return
            }
            
            // Safely capture current values from the main thread to use in the background
            let currentDistance = self.distance.value
            let currentElapsedTime = self.elapsedTime
            let currentPace = self.pace.value
            let currentCalories = self.calories
            let currentHeartRate = self.heartRate
            let currentCadence = self.cadence
            let currentRunState = self.runState
            let currentRunType = self.runType
            let currentIsIndoorMode = self.isIndoorMode
            let currentHasGoodLocationData = self.hasGoodLocationData
            let currentIsDashboardMode = self.isDashboardMode
            let currentIsWatchTracking = self.isWatchTracking
            let currentUseMetric = self.useMetric
            let currentIsPrimaryForDistance = self.isPrimaryForDistance
            let currentIsPrimaryForPace = self.isPrimaryForPace
            let currentIsPrimaryForHeartRate = self.isPrimaryForHeartRate
            let currentIsPrimaryForCalories = self.isPrimaryForCalories
            let currentIsPrimaryForCadence = self.isPrimaryForCadence
            
            // Prepare metrics for the watch
            let metrics: [String: Any] = [
                "distance": currentDistance,
                "pace": currentPace,
                "elapsedTime": currentElapsedTime,
                "calories": currentCalories,
                "heartRate": currentHeartRate,
                "cadence": currentCadence,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            // Prepare message with workout state and metrics
            let message: [String: Any] = [
                "type": "trackingStatus",
                "workoutType": currentRunType.rawValue,
                "state": currentRunState.rawValue,
                "runState": currentRunState.rawValue,
                "metrics": metrics,
                "workoutActive": currentRunState == .running || currentRunState == .paused,
                "hasActiveWorkout": currentRunState == .running || currentRunState == .paused,
                "isIndoor": currentIsIndoorMode,
                "isDashboardMode": currentIsDashboardMode,
                "isWatchTracking": currentIsWatchTracking,
                "useImperialUnits": !currentUseMetric,
                "isPrimaryForDistance": currentIsPrimaryForDistance,
                "isPrimaryForPace": currentIsPrimaryForPace,
                "isPrimaryForHeartRate": currentIsPrimaryForHeartRate,
                "isPrimaryForCalories": currentIsPrimaryForCalories,
                "isPrimaryForCadence": currentIsPrimaryForCadence,
                "hasGoodLocationData": currentHasGoodLocationData
            ]
            
            // Send with timeout and error handling
            if session.isReachable {
                session.sendMessage(message, replyHandler: { response in
                    // Reset error counter on successful communication
                    DispatchQueue.main.async {
                        self.watchCommErrorCount = 0
                        
                        if self.watchCircuitBreakerOpen {
                            print("🔄 Watch communication circuit breaker CLOSED: Resuming normal operation")
                            self.watchCircuitBreakerOpen = false
                            
                            // Re-evaluate primary data sources now that watch is available
                            self.evaluatePrimarySource()
                        }
                        
                        // Process response
                        if let watchIsTracking = response["isWatchTracking"] as? Bool {
                            self.isWatchTracking = watchIsTracking
                        }
                    }
                }, errorHandler: { error in
                    // Handle error
                    DispatchQueue.main.async {
                        self.handleWatchCommunicationError(error)
                    }
                })
            } else {
                // Use updateApplicationContext for when the watch becomes available
                do {
                    try session.updateApplicationContext(message)
                    print("📱 Updated application context with tracking status")
                } catch {
                    // Handle error
                    DispatchQueue.main.async {
                        self.handleWatchCommunicationError(error)
                    }
                }
            }
            
            // Update metrics coordinator on the main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.metricsCoordinator?.updateWatchStatus(
                    isAvailable: session.activationState == .activated && 
                               session.isPaired && 
                               session.isWatchAppInstalled,
                    isReachable: session.isReachable && !self.watchCircuitBreakerOpen
                )
                
                // Only update metricsCoordinator from within the async block to avoid main thread work
                self.metricsCoordinator?.syncNow()
            }
        }
    }
    
    // Start regular tracking status updates to the watch
    private func startRegularTrackingStatusUpdates() {
        // Only start regular updates if a workout is active or in paused state
        if runState == .running || runState == .paused {
            print("📲 Starting regular tracking status updates to watch")
            
            // Cancel any existing timer
            stopRegularTrackingStatusUpdates()
            
            // Create a new timer that fires every 15 seconds (increased from 10 to reduce frequency)
            let timer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                // Only send updates if workout is still active
                if self.runState == .running || self.runState == .paused {
                    self.sendTrackingStatusUpdate()
                } else {
                    // Automatically stop regular updates if workout is no longer active
                    self.stopRegularTrackingStatusUpdates()
                }
            }
            
            // Keep a reference to the timer
            self.trackingStatusTimer = timer
        } else {
            // No active workout, send a single status update and don't start a timer
            print("📲 Sending one-time status update to watch (no active workout)")
            sendTrackingStatusUpdate()
        }
    }
    
    // Stop regular tracking status updates
    private func stopRegularTrackingStatusUpdates() {
        trackingStatusTimer?.invalidate()
        trackingStatusTimer = nil
    }
    
    // WCSession communication
    // This property is needed for self-reference in some methods
    private var runTracker: RunTrackingEngine? {
        return self
    }
    
    // MARK: - Public Methods for Treadmill Manual Updates
    

    
    /// Update all formatted values based on current raw values and unit preferences
    /// - Note: This method updates @Published properties which must happen on the main thread
    func updateFormattedValues() {
        // CRITICAL FIX: Ensure we're on the main thread when updating @Published properties
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.updateFormattedValues()
            }
            return
        }
        // Format distance based on user preference
        if useMetric {
            // Convert to kilometers for display
            let distanceKm = distance.value / 1000
            formattedDistance = String(format: "%.2f", distanceKm)
            distanceUnit = "km"
        } else {
            // Convert to miles for display
            let distanceMiles = distance.value / 1609.34
            formattedDistance = String(format: "%.2f", distanceMiles)
            distanceUnit = "mi"
        }
        
        // Format time
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            formattedTime = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            formattedTime = String(format: "%02d:%02d", minutes, seconds)
        }
        
        // Format pace - calculate from distance and elapsed time for accuracy
        if distance.value > 10 && elapsedTime > 5 {
            // Calculate pace in seconds per km
            let paceSecondsPerKm = elapsedTime / (distance.value / 1000.0)
            
            // Only format if pace is reasonable (between 2:00 and 20:00 min/km)
            if paceSecondsPerKm >= 120 && paceSecondsPerKm <= 1200 {
                if useMetric {
                    // Format as min/km
                    let paceMinutes = Int(paceSecondsPerKm / 60)
                    let paceSeconds = Int(paceSecondsPerKm.truncatingRemainder(dividingBy: 60))
                    formattedPace = String(format: "%d'%02d\"", paceMinutes, paceSeconds)
                } else {
                    // Convert to seconds per mile for imperial
                    let paceSecondsPerMile = paceSecondsPerKm * 1.60934
                    let paceMinutes = Int(paceSecondsPerMile / 60)
                    let paceSeconds = Int(paceSecondsPerMile.truncatingRemainder(dividingBy: 60))
                    formattedPace = String(format: "%d'%02d\"", paceMinutes, paceSeconds)
                }
            } else {
                formattedPace = "-'--\""
            }
        } else {
            formattedPace = "-'--\""
        }
        
        // Format other values...
        formattedCalories = String(format: "%.0f", calories)
        formattedHeartRate = heartRate > 0 ? String(format: "%.0f", heartRate) : "--"
        
        // Format elevation gain/loss
        if useMetric {
            formattedElevationGain = String(format: "%.0f m", elevationGain.value)
            formattedElevationLoss = String(format: "%.0f m", elevationLoss.value)
        } else {
            // Convert to feet
            let gainFeet = elevationGain.value * 3.28084
            let lossFeet = elevationLoss.value * 3.28084
            formattedElevationGain = String(format: "%.0f ft", gainFeet)
            formattedElevationLoss = String(format: "%.0f ft", lossFeet)
        }
        
        // Format cadence
        formattedCadence = cadence > 0 ? String(format: "%.0f spm", cadence) : "-- spm"
        
        // Format stride length
        if useMetric {
            formattedStrideLength = strideLength.value > 0 ? String(format: "%.2f m", strideLength.value) : "-- m"
        } else {
            let strideFeet = strideLength.value * 3.28084
            formattedStrideLength = strideLength.value > 0 ? String(format: "%.2f ft", strideFeet) : "-- ft"
        }
        
        // Update runLog with current metrics
        updateRunLogWithCurrentMetrics()
    }
    
    // MARK: - Public API
    
    /// Update distance and recalculate pace - can be called for manual treadmill updates
    func updateDistanceAndCalculatePace(_ newDistanceInMeters: Double) {
        // Update distance
        distance = Measurement(value: newDistanceInMeters, unit: UnitLength.meters)
        
        // Calculate pace based on new distance and elapsed time
        calculatePace()
    }
    
    /// Send unit preferences to watch
    func syncUnitPreferencesToWatch() {
        guard WCSession.default.activationState == .activated && WCSession.default.isReachable else {
            return
        }
        
        // Send unit preferences to watch
        let message: [String: Any] = [
            "type": "unitPreferences",
            "useMetric": useMetric
        ]
        
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Error sending unit preferences to watch: \(error.localizedDescription)")
        }
    }
    
    // Add these required WCSessionDelegate methods

    // This method is required for WCSessionDelegate
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("Watch session became inactive")
    }

    // This method is required for WCSessionDelegate
    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate the session after it deactivates
        print("Watch session deactivated")
        WCSession.default.activate()
    }
    
    // Required for WCSessionDelegate on iOS
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        print("Received user info from watch: \(userInfo.keys)")
        // Process the user info dictionary as needed
        DispatchQueue.main.async {
            self.handleWatchUserInfo(userInfo)
        }
    }
    
    // Handle user info received from watch
    private func handleWatchUserInfo(_ userInfo: [String: Any]) {
        // Extract data from user info dictionary
        if let type = userInfo["type"] as? String {
            switch type {
            case "heartRate":
                if let heartRate = userInfo["value"] as? Double {
                    self.heartRate = heartRate
                    updateHeartRateMetrics(heartRate)
                }
            case "metrics":
                // Handle metrics updates
                if let metrics = userInfo["data"] as? [String: Any] {
                    if let distance = metrics["distance"] as? Double {
                        updateDistanceFromWatch(distance)
                    }
                    if let heartRate = metrics["heartRate"] as? Double {
                        self.heartRate = heartRate
                        updateHeartRateMetrics(heartRate)
                    }
                }
            default:
                print("Unhandled user info type: \(type)")
            }
        }
    }
    
    // Save run data to AWS backend
    private func saveRunData() {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            print("⚠️ Warning: No current user found for saving run data")
            return
        }
        
        print("📤 Saving run data to AWS...")
        
        // Prepare route points from location list
        let routePoints = locationList.map { location -> [String: Any] in
            return [
                "latitude": location.latitude,
                "longitude": location.longitude,
                "altitude": location.altitude,
                "timestamp": ISO8601DateFormatter().string(from: location.timestamp),
                "speed": location.speed,
                "course": location.course,
                "horizontalAccuracy": location.horizontalAccuracy,
                "verticalAccuracy": location.verticalAccuracy,
                "heartRate": location.heartRate as Any,
                "cadence": location.cadence as Any
            ]
        }
        
        // Prepare activity data with additional metrics
        var activityData: [String: Any] = [
            "runType": runType.rawValue,
            "isIndoor": isIndoorMode,
            "cadence": cadence,
            "averagePace": pace.value,
            "formattedPace": formattedPace,
            "formattedDistance": formattedDistance,
            "formattedTime": formattedTime
        ]
        
        // Add heart rate data if available
        if heartRate > 0 {
            activityData["heartRate"] = heartRate
        }
        
        // Add elevation data if available
        if elevationGain.value > 0 {
            activityData["elevationGain"] = elevationGain.value
        }
        if elevationLoss.value > 0 {
            activityData["elevationLoss"] = elevationLoss.value
        }
        
        // Prepare start and end locations
        var startLocation: [String: Any]? = nil
        var endLocation: [String: Any]? = nil
        
        if let firstLocation = locationList.first {
            startLocation = [
                "latitude": firstLocation.latitude,
                "longitude": firstLocation.longitude,
                "altitude": firstLocation.altitude,
                "timestamp": ISO8601DateFormatter().string(from: firstLocation.timestamp)
            ]
        }
        
        if let lastLocation = locationList.last {
            endLocation = [
                "latitude": lastLocation.latitude,
                "longitude": lastLocation.longitude,
                "altitude": lastLocation.altitude,
                "timestamp": ISO8601DateFormatter().string(from: lastLocation.timestamp)
            ]
        }
        
        // Calculate average heart rate if we have heart rate readings
        let avgHeartRate: Double? = heartRateReadings.isEmpty ? nil : heartRateReadings.reduce(0, +) / Double(heartRateReadings.count)
        let maxHeartRate: Double? = heartRateReadings.isEmpty ? nil : heartRateReadings.max()
        
        // Save to AWS using ActivityService
        ActivityService.shared.saveRun(
            userId: userId,
            duration: elapsedTime,
            distance: distance.value,
            calories: calories,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            elevationGain: elevationGain.value > 0 ? elevationGain.value : nil,
            elevationLoss: elevationLoss.value > 0 ? elevationLoss.value : nil,
            routePoints: routePoints,
            activityData: activityData,
            startLocation: startLocation,
            endLocation: endLocation,
            isPublic: true,
            caption: nil
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let response):
                print("✅ Run data saved to AWS successfully")
                if let activityId = response.data?.activityId {
                    print("📊 Activity ID: \(activityId)")
                    // Store activity ID for reference
                    UserDefaults.standard.set(activityId, forKey: "lastSavedRunDataId")
                }
            case .failure(let error):
                print("❌ Error saving run data to AWS: \(error.localizedDescription)")
            }
        }
    }
    
    // Add a method to stop the timer
    private func stopTimer() {
        // Invalidate and nil out the timer
        timer?.invalidate()
        timer = nil
        print("Timer stopped")
    }
    
    // Add to the list of published properties:
    @Published var isAutoCenter: Bool = true // Automatically center map on user location
    
    // MARK: - Helper Methods
    
    func generateRunLog() -> RunLog? {
        // Make sure we have data to return
        guard !locationList.isEmpty else {
            print("Cannot generate RunLog: no location data available")
            return nil
        }
        
        // Set the run type and type in the log
        runLog.runType = runType.rawValue
        runLog.type = isIndoorMode ? "indoor" : "outdoor"
        runLog.createdBy = UserIDHelper.shared.getCurrentUserID() // Set Cognito user ID
        
        // Return the current run log with latest data
        return runLog
    }
    
    func getFormattedSplitTimes() -> [(distance: String, time: String, pace: String)] {
        return splitTimes.map { split in
            // Convert distance from meters to display units
            let distanceInDisplayUnits: Double
            if useMetric {
                distanceInDisplayUnits = split.distance / 1000.0 // Convert to km
            } else {
                distanceInDisplayUnits = split.distance / 1609.34 // Convert to miles
            }
            let distanceString = useMetric ? 
                String(format: "%.2f km", distanceInDisplayUnits) : 
                String(format: "%.2f mi", distanceInDisplayUnits)
            
            let timeString = formatTime(Int(split.time))
            
            // Format pace (split.pace is in seconds per meter)
            // Convert to seconds per km or seconds per mile
            let paceInDisplayUnits: Double
            if useMetric {
                paceInDisplayUnits = split.pace * 1000.0 // seconds per km
            } else {
                paceInDisplayUnits = split.pace * 1609.34 // seconds per mile
            }
            
            let minutes = Int(paceInDisplayUnits / 60)
            let seconds = Int(paceInDisplayUnits.truncatingRemainder(dividingBy: 60))
            let paceString = String(format: "%d'%02d\"", minutes, seconds)
            
            return (distanceString, timeString, paceString)
        }
    }
    
    // MARK: - Pace Calculation
    
    /// Calculates pace based on distance and elapsed time
    private func calculatePace() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.calculatePace()
            }
            return
        }
        
        // Calculate pace only if we have meaningful distance and time
        if distance.value > 10 && elapsedTime > 5 {
            let paceSecondsPerKm = elapsedTime / (distance.value / 1000.0)
            
            // Only update if pace is reasonable (between 3-30 min/km)
            if paceSecondsPerKm > 180 && paceSecondsPerKm < 1800 {
                let newPace = Measurement(value: paceSecondsPerKm, unit: UnitSpeed.minutesPerKilometer)
                
                // Apply smoothing
                if let currentSmoothedPace = smoothedPace {
                    // Use 30% new value, 70% old value for smoothing
                    let smoothedValue = currentSmoothedPace.value * 0.7 + paceSecondsPerKm * 0.3
                    smoothedPace = Measurement(value: smoothedValue, unit: UnitSpeed.minutesPerKilometer)
                } else {
                    smoothedPace = newPace
                }
                
                // Only update UI if enough time has passed (prevent flickering)
                let now = Date().timeIntervalSince1970
                if now - lastPaceUpdate >= 1.0 {
                    pace = smoothedPace ?? newPace
                    lastPaceUpdate = now
                    
                    // Update formatted values on main thread
                    updateFormattedValues()
                }
            }
        }
    }
    
    /// Calculate the current pace in seconds per kilometer
    private func calculateCurrentPace() -> Double {
        // Only calculate if we have valid distance and elapsed time
        guard elapsedTime > 0 && distance.value > 10 else {
            return 0
        }
        
        // Standard formula: seconds per kilometer
        let paceInSecondsPerKm = elapsedTime / (distance.value / 1000)
        
        // Validate pace is within reasonable bounds (between 2:00 and 15:00 min/km)
        if paceInSecondsPerKm < 120 {
            return 120 // 2:00 min/km is a very fast pace
        } else if paceInSecondsPerKm > 900 {
            return 900 // 15:00 min/km is a very slow pace
        }
        
        return paceInSecondsPerKm
    }
    
    
    /// Updates distance from watch and recalculates pace if phone GPS is not available
    func updateDistanceFromWatch(_ newDistanceInMeters: Double) {
        // Only update if we're not using phone GPS
        guard !isAutoTrackingEnabled else { return }
        
        // Update distance
        distance = Measurement(value: newDistanceInMeters, unit: UnitLength.meters)
        
        // Calculate pace based on new distance and elapsed time
        calculatePace()
    }
    
    // Add this method to RunTrackingEngine
    private func updateRunLogWithCurrentMetrics() {
        let distanceValue = useMetric
            ? distance.converted(to: UnitLength.kilometers).value
            : distance.converted(to: UnitLength.miles).value
        
        runLog.duration = formattedTime
        runLog.distance = String(format: "%.2f", distanceValue)
        runLog.avgPace = formattedPace
        runLog.caloriesBurned = calories
        runLog.createdAt = startDate
        runLog.createdBy = UserIDHelper.shared.getCurrentUserID()
        runLog.runType = runType.rawValue
        
        // Update location data if available
        if !locationList.isEmpty {
            runLog.locationData = locationList.map { location in
                [
                    "latitude": location.latitude,
                    "longitude": location.longitude,
                    "altitude": location.altitude,
                    "timestamp": location.timestamp,
                    "heartRate": location.heartRate ?? 0,
                    "cadence": location.cadence ?? 0
                ]
            }
            runLog.coordinateArray = locationList.map {
                ["lat": $0.latitude, "lon": $0.longitude]
            }
        }
    }
    
    // Add this helper method to RunTrackingEngine
    private func validatePaceValue(_ paceValue: Double) -> Double {
        // Ensure pace is within reasonable bounds (between 2:00 and 30:00 min/km)
        if paceValue <= 0 {
            return 0 // Invalid pace
        } else if paceValue < 120 {
            return 120 // 2:00 min/km is a very fast pace
        } else if paceValue > 1800 {
            return 1800 // 30:00 min/km is a very slow pace
        }
        return paceValue
    }
    /// For improved reliability and performance, this now uses only updateApplicationContext
    func sendWorkoutUpdate(forced: Bool = false) {
        // Don't send updates back to watch when we're processing a state change from the watch
        if isHandlingRemoteStateChange && !forced {
            print("📱 🎯 Skipping sendWorkoutUpdate - handling remote state change from watch")
            return
        }
        
        // Check if we can send a message
        guard WCSession.default.activationState == .activated else {
            print("📱 Cannot send workout update - WCSession not activated")
            return
        }
        
        // Handle completed state - send final data and clear application context
        if runState == .completed {
            let finalWorkoutData: [String: Any] = [
                "type": "workoutUpdate",
                "id": workoutId.uuidString,
                "workoutType": "run",
                "runType": isIndoorMode ? "treadmillRun" : "outdoorRun",
                "state": "completed",
                "runState": "completed",
                "elapsedTime": elapsedTime,
                "isIndoor": isIndoorMode,
                "timestamp": Date().timeIntervalSince1970,
                "workoutActive": false,
                "hasActiveWorkout": false,
                "forcedStateChange": true,
                "finalMetrics": [
                    "distance": distance.value,
                    "duration": elapsedTime,
                    "calories": calories,
                    "heartRate": heartRate,
                    "pace": pace.value,
                    "verticalOscillation": verticalOscillation.value,
                    "groundContactTime": groundContactTime
                ]
            ]
            
            print("📱 🔚 Sending final workout state to watch")
            
            // CRITICAL FIX: Always update application context for completed workouts
            // This ensures ActiveWorkoutChecker on watch sees the completed state
            print("📱 🔚 CRITICAL: Updating application context to clear active workout")
            try? WCSession.default.updateApplicationContext(finalWorkoutData)
            
            // Also send direct message if possible for immediate processing
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(finalWorkoutData, replyHandler: { response in
                    print("📱 ✅ Watch confirmed final workout state: \(response)")
                }, errorHandler: { error in
                    print("📱 ❌ Error sending final state message to watch: \(error.localizedDescription)")
                    // Application context was already updated above
                })
            }
            return
        }
        
        // Apply rate limiting for normal updates (but not for forced updates)
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastWorkoutUpdateTime)
        if timeSinceLastUpdate < 1.0 && !forced && !isForcedUpdate && runState != .completed {
            print("📱 Skipping update - too soon since last update")
            return
        }
        
        // During auto-join, we should send metrics even if they're zero
        let isAutoJoin = isJoiningExistingWorkout && !watchHasAcknowledgedJoin
        
        // Check if metrics are properly initialized before sending
        let hasValidMetrics = elapsedTime > 0 || distance.value > 0 || runState == .running || isAutoJoin
        
        if !hasValidMetrics && runState == .notStarted && !isAutoJoin {
            print("📱 Skipping workout update - metrics not yet initialized")
            return
        }
        
        // Create the workout data dictionary
        var workoutData: [String: Any] = [
            "type": "workoutUpdate",
            "id": workoutId.uuidString,
            "workoutType": "run",
            "runType": isIndoorMode ? "treadmillRun" : "outdoorRun",
            "state": runState.rawValue,
            "runState": runState.rawValue,
            "elapsedTime": elapsedTime,
            "isIndoor": isIndoorMode,
            "timestamp": Date().timeIntervalSince1970,
            "workoutActive": runState == .running || runState == .paused,
            "hasActiveWorkout": runState != .notStarted,
            "isDashboardMode": isDashboardMode,
            "isWatchTracking": isWatchTracking,
            "hasGoodLocationData": hasGoodLocationData,
            "useImperialUnits": !useMetric
        ]
        
        // Add metrics based on authority and validity
        if !WorkoutCommunicationHandler.shared.isPrimaryForDistance {
            workoutData["distance"] = distance.value
        } else if isAutoJoin && distance.value > 0 {
            workoutData["distance"] = distance.value
        }

        if !WorkoutCommunicationHandler.shared.isPrimaryForPace {
            workoutData["pace"] = pace.value
        } else if isAutoJoin && pace.value > 0 {
            workoutData["pace"] = pace.value
        }

        if !WorkoutCommunicationHandler.shared.isPrimaryForHeartRate {
            workoutData["heartRate"] = heartRate
        } else if isAutoJoin && heartRate > 0 {
            workoutData["heartRate"] = heartRate
        }

        if !WorkoutCommunicationHandler.shared.isPrimaryForCalories {
            workoutData["calories"] = calories
        } else if isAutoJoin && calories > 0 {
            workoutData["calories"] = calories
        }

        if !WorkoutCommunicationHandler.shared.isPrimaryForCadence {
            workoutData["cadence"] = cadence
        } else if isAutoJoin && cadence > 0 {
            workoutData["cadence"] = cadence
        }
        
        // Add authority flags
        workoutData["isPrimaryForDistance"] = !WorkoutCommunicationHandler.shared.isPrimaryForDistance
        workoutData["isPrimaryForPace"] = !WorkoutCommunicationHandler.shared.isPrimaryForPace
        workoutData["isPrimaryForHeartRate"] = !WorkoutCommunicationHandler.shared.isPrimaryForHeartRate
        workoutData["isPrimaryForCalories"] = !WorkoutCommunicationHandler.shared.isPrimaryForCalories
        workoutData["isPrimaryForCadence"] = !WorkoutCommunicationHandler.shared.isPrimaryForCadence
        
        // Add pause information if paused
            if runState == .paused {
                if let pauseStartTime = self.pauseDate {
                    workoutData["pauseStartTime"] = pauseStartTime.timeIntervalSince1970
                }
                workoutData["pauseDuration"] = self.totalPausedTime
            }
        print("📱 Sending workout update to watch: state=\(runState.rawValue), time=\(elapsedTime)s, distance=\(distance.value)m")
        
        // For normal updates, use application context to avoid overwhelming the connection
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try WCSession.default.updateApplicationContext(workoutData)
                
                // Update timestamps and flags
                self.lastWorkoutUpdateTime = now
                self.isForcedUpdate = false
                
            } catch {
                print("⚠️ Error updating application context: \(error.localizedDescription)")
            }
        }
    }
    
    /// Updates cadence from external source (e.g., watch)
    public func updateCadence(_ cadence: Double) {
        // Only update if we're not calculating cadence internally or if watch is providing the data
        guard !autoTrackingEnabled || !isPrimaryForCadence else { 
            print("🦶 CADENCE UPDATE BLOCKED - autoTracking: \(autoTrackingEnabled), isPrimary: \(isPrimaryForCadence), received: \(cadence)spm")
            return 
        }
        
        print("🦶 CADENCE UPDATE ACCEPTED - Old: \(self.cadence)spm, New: \(cadence)spm, isPrimary: \(isPrimaryForCadence)")
        
        self.cadence = cadence
        self.formattedCadence = cadence > 0 ? String(format: "%.0f spm", cadence) : "-- spm"
        
        // Update other metrics that might be affected by cadence
        if cadence > 0 {
            // Update stride length if we have distance
            if distance.value > 0 && elapsedTime > 0 {
                // Estimate stride length based on cadence and pace
                // steps per minute ÷ 2 = strides per minute
                // distance (meters) ÷ (strides/minute × minutes) = meters per stride
                let stridesPerMinute = cadence / 2
                let minutes = elapsedTime / 60
                if stridesPerMinute > 0 && minutes > 0 {
                    let estimatedStrides = stridesPerMinute * minutes
                    let strideLength = estimatedStrides > 0 ? distance.value / estimatedStrides : 0
                    self.strideLength = Measurement(value: strideLength, unit: UnitLength.meters)
                }
            }
            
            // Since we updated cadence, make sure UI is updated too
            updateFormattedValues()
        }
    }
    
    /// Handle audio session interruptions such as phone calls
    @objc func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt else {
            return
        }
        
        let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        
        if type == .began {
            // Audio session was interrupted - e.g., phone call came in
            print("📱 Audio session interrupted")
        } else if type == .ended {
            // Audio session interruption ended - e.g., phone call ended
            print("📱 Audio session interruption ended")
            
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                
                // If we should resume, try to restart our audio
                if options.contains(.shouldResume) {
                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                        print("📱 Audio session resumed")
                        
                        // Restart silent audio playback
                        playSilentAudioIfNeeded()
                    } catch {
                        print("📱 Error resuming audio session: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    
    // Add this method below:

    private func notifyTrackingStateDidChange() {
        // Post notification for UI updates
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("TrackingStateDidChange"),
                object: self
            )
        }
        
        // Update formatted values
        updateFormattedValues()
    }

    private func handleTreadmillUpdate(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        print("📱 Received treadmill update from watch")
        
        // Check if this is a treadmill run and we're in a state to accept updates
        guard runType == .treadmillRun && runState != .notStarted && runState != .completed else {
            print("📱 Ignoring treadmill update - not in treadmill mode or not active")
            replyHandler(["status": "ignored", "reason": "Not in treadmill mode or not active"])
            return
        }
        
        // Extract data from message
        let watchDistance = message["distance"] as? Double ?? 0
        let watchElapsedTime = message["elapsedTime"] as? TimeInterval ?? 0
        let watchPace = message["pace"] as? Double ?? 0
        let watchHeartRate = message["heartRate"] as? Double ?? 0
        let watchCalories = message["calories"] as? Double ?? 0
        let watchCadence = message["cadence"] as? Double ?? 0
        
        print("🏃‍♂️ Treadmill data from watch: distance=\(watchDistance)m, pace=\(watchPace)s/km, HR=\(watchHeartRate)bpm")
        
        // Update our tracking with the watch data
        // For treadmill runs, the watch is primary
        distance = Measurement(value: watchDistance, unit: UnitLength.meters)
        elapsedTime = watchElapsedTime
        
        // Pace should be in seconds per kilometer or seconds per mile based on user preference
        if useMetric {
            pace = Measurement(value: watchPace, unit: UnitSpeed.minutesPerKilometer)
        } else {
            // Convert from seconds/km to seconds/mile if using imperial
            let paceInSecondsPerMile = watchPace * 1.60934
            pace = Measurement(value: paceInSecondsPerMile, unit: UnitSpeed.minutesPerMile)
        }
        
        heartRate = watchHeartRate
        calories = watchCalories
        cadence = watchCadence
        
        // Update application context and notify delegates
        updateApplicationContext()
        notifyTrackingStateDidChange()
        
        // Acknowledge receipt
        replyHandler(["status": "success"])
    }

    private func sendTrackingStatusResponse(replyHandler: @escaping ([String: Any]) -> Void) {
        print("📱 Sending tracking status to watch")
        
        let response: [String: Any] = [
            "status": "success",
            "isPhoneTracking": !isWatchTracking,
            "isDashboardMode": isDashboardMode,
            "isPrimaryForDistance": isPrimaryForDistance,
            "isPrimaryForPace": isPrimaryForPace,
            "isPrimaryForHeartRate": isPrimaryForHeartRate,
            "isPrimaryForCalories": isPrimaryForCalories,
            "isPrimaryForCadence": isPrimaryForCadence,
            "hasGoodLocationData": hasGoodLocationData,
            "primarySources": [
                "distance": isPrimaryForDistance ? "phone" : "watch",
                "pace": isPrimaryForPace ? "phone" : "watch",
                "heartRate": isPrimaryForHeartRate ? "phone" : "watch",
                "calories": isPrimaryForCalories ? "phone" : "watch",
                "cadence": isPrimaryForCadence ? "phone" : "watch"
            ],
            "isIndoor": runType == .treadmillRun
        ]
        
        replyHandler(response)
    }
    
    // MARK: - Run Saving Methods
    
    /// Incrementally saves the current run state without finalizing the run.
    /// Used for checkpointing run state during app transitions or potential interruptions.
    /// Note: Incremental saves now use UserDefaults only (no Parse dependency)
    func saveIncremental() {
        // Only save if there's an active run
        guard runState == .running || runState == .paused else { return }
        
        print("📱 Saving incremental run state...")
        
        // Save incremental state to UserDefaults only
        // Final save will go to AWS when run is completed
        saveStateToUserDefaults()
        
        // Note: parseObject incremental saves to Parse are deprecated
        // All final saves now go directly to AWS
    }
    
    private func saveStateToUserDefaults() {
        let defaults = UserDefaults.standard
        
        // Save basic run state data
        defaults.set(workoutId.uuidString, forKey: "RunTracker.workoutId")
        defaults.set(runState.rawValue, forKey: "RunTracker.runState")
        defaults.set(runType.rawValue, forKey: "RunTracker.runType")
        defaults.set(elapsedTime, forKey: "RunTracker.elapsedTime")
        defaults.set(distance.value, forKey: "RunTracker.distance")
        defaults.set(pace.value, forKey: "RunTracker.pace")
        defaults.set(calories, forKey: "RunTracker.calories")
        defaults.set(Date().timeIntervalSince1970, forKey: "RunTracker.lastSaved")
        
        // Synchronize to ensure data is saved immediately
        defaults.synchronize()
    }

    /// Restores the run state from an incremental save.
    /// Used when recovering from app termination or interruptions.
    func restoreIncrementalState() -> Bool {
        let defaults = UserDefaults.standard
        
        // Check if we have saved state data and it's recent enough (within last 30 minutes)
        guard let lastSavedTime = defaults.object(forKey: "RunTracker.lastSaved") as? TimeInterval else {
            print("No saved run state found")
            return false
        }
        
        let currentTime = Date().timeIntervalSince1970
        let timeSinceLastSave = currentTime - lastSavedTime
        
        // Only restore if the save was within the last 30 minutes (1800 seconds)
        guard timeSinceLastSave < 1800 else {
            print("Saved run state is too old (\(Int(timeSinceLastSave/60)) minutes), discarding")
            clearSavedState()
            return false
        }
        
        // Get the saved workout ID
        guard let savedWorkoutIdString = defaults.string(forKey: "RunTracker.workoutId"),
              let savedWorkoutId = UUID(uuidString: savedWorkoutIdString) else {
            print("Invalid or missing workout ID in saved state")
            return false
        }
        
        // Restore workout ID
        workoutId = savedWorkoutId
        
        // Restore run state
        if let rawRunState = defaults.string(forKey: "RunTracker.runState"),
           let restoredRunState = RunState(rawValue: rawRunState) {
            runState = restoredRunState
        }
        
        // Restore run type
        if let rawRunType = defaults.string(forKey: "RunTracker.runType"),
           let restoredRunType = RunType(rawValue: rawRunType) {
            runType = restoredRunType
        }
        
        // Restore metrics
        elapsedTime = defaults.double(forKey: "RunTracker.elapsedTime")
        distance = Measurement(value: defaults.double(forKey: "RunTracker.distance"), unit: UnitLength.meters)
        pace = Measurement(value: defaults.double(forKey: "RunTracker.pace"), unit: UnitSpeed.minutesPerKilometer)
        calories = defaults.double(forKey: "RunTracker.calories")
        
        // CRITICAL FIX: Set start date accounting for pause duration
        // The elapsedTime represents actual running time, but we need to account for pauses
        // to calculate the correct startDate
        let totalTimeIncludingPauses = elapsedTime + totalPausedTime
        startDate = Date().addingTimeInterval(-totalTimeIncludingPauses)
        
        print("📱 🔄 JOIN DEBUG: Calculated startDate accounting for pauses")
        print("📱 🔄 JOIN DEBUG: elapsedTime: \(elapsedTime)s, totalPausedTime: \(totalPausedTime)s")
        print("📱 🔄 JOIN DEBUG: totalTimeIncludingPauses: \(totalTimeIncludingPauses)s")
        print("📱 🔄 JOIN DEBUG: startDate: \(startDate?.description ?? "nil")")
        
        // Update formatted values
        updateFormattedValues()
        
        print("Restored run in progress: \(formattedDistance) \(distanceUnit) in \(formattedTime)")
        
      
        
        // Notify observers that we've restored state
        NotificationCenter.default.post(name: .didChangeRunState, object: self)
        
        return true
    }

    private func clearSavedState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "RunTracker.workoutId")
        defaults.removeObject(forKey: "RunTracker.runState")
        defaults.removeObject(forKey: "RunTracker.runType")
        defaults.removeObject(forKey: "RunTracker.elapsedTime")
        defaults.removeObject(forKey: "RunTracker.distance")
        defaults.removeObject(forKey: "RunTracker.pace")
        defaults.removeObject(forKey: "RunTracker.calories")
        defaults.removeObject(forKey: "RunTracker.lastSaved")
        defaults.synchronize()
    }

    



    // Add new properties for handling watch communication errors
    private var watchCommErrorCount = 0
    private let maxWatchCommErrors = 3
    private var watchCircuitBreakerOpen = false
    private var lastCircuitBreakerReset = Date(timeIntervalSince1970: 0)
    private let circuitBreakerResetInterval: TimeInterval = 30.0 // Try reconnecting every 30 seconds

    // Add this method for automatic watch connection recovery
    public func handleWatchCommunicationError(_ error: Error) {
        // Increment error counter
        watchCommErrorCount += 1
        
        print("⚠️ Watch communication error #\(watchCommErrorCount): \(error.localizedDescription)")
        
        // If we've reached the error threshold, switch to circuit breaker mode
        if watchCommErrorCount >= maxWatchCommErrors && !watchCircuitBreakerOpen {
            watchCircuitBreakerOpen = true
            lastCircuitBreakerReset = Date()
            
            print("🔄 Watch communication circuit breaker OPENED: Switching to phone-only tracking")
            
            // Switch to phone-only tracking
            DispatchQueue.main.async {
                self.isPrimaryForDistance = true
                self.isPrimaryForPace = true
                self.isPrimaryForHeartRate = true
                self.isPrimaryForCalories = true
                self.isPrimaryForCadence = true
                
                // Update the metrics coordinator
                self.metricsCoordinator?.updateMetricsPolicy(
                    indoorMode: self.isIndoorMode,
                    hasGoodGPS: self.hasGoodLocationData,
                    watchReachable: false
                )
                
                // Update the delegate
                self.delegate?.runTrackingEngineDidUpdateState(self)
                
                // Notify that metrics have been updated
                NotificationCenter.default.post(name: .didUpdateRunMetrics, object: nil)
            }
        }
    }

    // Add this helper method to check and reset the circuit breaker
    private func checkAndResetCircuitBreaker() {
        if watchCircuitBreakerOpen && Date().timeIntervalSince(lastCircuitBreakerReset) > circuitBreakerResetInterval {
            // Try to reset the circuit breaker after the interval
            print("🔄 Attempting to reset watch communication circuit breaker")
            watchCircuitBreakerOpen = false
            watchCommErrorCount = 0
            lastCircuitBreakerReset = Date()
            
            // Check if watch is reachable
            if WCSession.default.activationState == .activated && 
               WCSession.default.isPaired && 
               WCSession.default.isWatchAppInstalled && 
               WCSession.default.isReachable {
                
                print("✅ Watch is reachable again - resuming normal operation")
                
                // Re-evaluate primary data sources
                evaluatePrimarySource()
            }
        }
    }
    
    /// Evaluates which device (phone or watch) should be the primary source for different metrics
    /// based on current conditions, device availability, and data quality
    public func evaluatePrimarySource() {
        // Determine if watch is available
        let isWatchAvailable = WCSession.default.activationState == .activated && 
                               WCSession.default.isPaired && 
                               WCSession.default.isWatchAppInstalled &&
                               !watchCircuitBreakerOpen
        
        let isWatchDirectlyReachable = isWatchAvailable && WCSession.default.isReachable
        
        // Set primary sources based on conditions
        if isIndoorMode {
            // Indoor mode logic
            print("📱 Indoor mode: Phone primary for distance/pace, watch for HR/cadence")
            isPrimaryForDistance = true
            isPrimaryForPace = true
            isPrimaryForHeartRate = isWatchAvailable // Watch is better for HR if available
            isPrimaryForCadence = isWatchAvailable // Watch is better for cadence if available
            isPrimaryForCalories = true
        } else {
            // Outdoor mode logic
            print("📱 Outdoor mode: Evaluating primary sources")
            
            // Phone is primary for distance/pace if GPS is good or watch is unavailable
            isPrimaryForDistance = !isWatchDirectlyReachable || hasGoodLocationData
            isPrimaryForPace = !isWatchDirectlyReachable || hasGoodLocationData
            
            // Watch is primary for heart rate and cadence if available
            isPrimaryForHeartRate = isWatchAvailable
            isPrimaryForCadence = isWatchAvailable
            
            // Calories calculation depends on heart rate data source
            isPrimaryForCalories = !isPrimaryForHeartRate
        }
        
        // Log the choices
        print("📱 Primary source evaluation results:")
        print("   - Distance: \(isPrimaryForDistance ? "Phone" : "Watch")")
        print("   - Pace: \(isPrimaryForPace ? "Phone" : "Watch")")
        print("   - Heart Rate: \(isPrimaryForHeartRate ? "Watch" : "Phone")")
        print("   - Cadence: \(isPrimaryForCadence ? "Watch" : "Phone")")
        print("   - Calories: \(isPrimaryForCalories ? "Phone" : "Watch")")
        
        // Update metrics coordinator policy
        metricsCoordinator?.updateMetricsPolicy(
            indoorMode: isIndoorMode,
            hasGoodGPS: hasGoodLocationData,
            watchReachable: isWatchDirectlyReachable
        )
    }

    // Add these properties near other tracking properties
    private var locationSystemHealthy = true  // Track if location system is providing good data
    private var watchSystemHealthy = true     // Track if watch connectivity is stable
    private var locationFailureCount = 0      // Count consecutive location failures
    private var lastLocationHealthUpdate: TimeInterval = 0  // Track when we last updated health status

    // Add this method to perform a graceful update of tracking state based on system health
    private func updateTrackingState() {
        // Ensure we're on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.updateTrackingState()
            }
            return
        }
        
        // Determine the best tracking mode based on health of components
        let shouldUsePhoneForLocation = locationSystemHealthy && hasGoodLocationData
        
        // Update primacy flags
        isPrimaryForDistance = shouldUsePhoneForLocation
        isPrimaryForPace = shouldUsePhoneForLocation
        
        // For heart rate, always prefer watch when available
        isPrimaryForHeartRate = !watchSystemHealthy
        
        // Update metrics coordinator with current system health
        metricsCoordinator?.updateMetricsPolicy(
            indoorMode: isIndoorMode,
            hasGoodGPS: locationSystemHealthy,
            watchReachable: watchSystemHealthy
        )
        
        // Log current state for debugging (only if changed)
        let now = Date().timeIntervalSince1970
        if now - lastLocationHealthUpdate > 5.0 {
            print("📊 System health: Location=\(locationSystemHealthy), Watch=\(watchSystemHealthy)")
            print("📊 Primary sources: Distance=\(isPrimaryForDistance ? "phone" : "watch"), " +
                  "Pace=\(isPrimaryForPace ? "phone" : "watch"), " +
                  "HR=\(isPrimaryForHeartRate ? "phone" : "watch")")
            lastLocationHealthUpdate = now
        }
        
        // Always inform watch of current state
        updateApplicationContext()
    }

    // Add this method to send immediate state change commands for outdoor runs
    private func sendOutdoorRunStateChangeToWatch(newState: String) {
        print("📱 === OUTDOOR RUN STATE CHANGE DEBUG ===")
        print("📱 Attempting to send state change: \(newState)")
        
        let session = WCSession.default
        guard WCSession.isSupported() && session.activationState == .activated && session.isPaired else {
            print("📱 ❌ Cannot send state change - WCSession not ready")
            return
        }
        
        // Don't send messages if we're handling a remote state change to prevent loops
        guard !isHandlingRemoteStateChange else {
            print("📱 ⚠️ Skipping outdoor state change message - handling remote state change")
            return
        }
        
        // Create a state change command message
        let stateChangeCommand: [String: Any] = [
            "type": "outdoorRunStateChange",
            "command": newState,
            "isIndoor": false,
            "timestamp": Date().timeIntervalSince1970,
            "workoutId": workoutId.uuidString
        ]
        
        print("📱 Message payload: \(stateChangeCommand)")
        
        if session.isReachable {
            print("📱 ✅ Watch is reachable - sending immediate message")
            session.sendMessage(stateChangeCommand, replyHandler: { response in
                print("📱 ✅ Watch acknowledged outdoor run state change")
            }, errorHandler: { error in
                print("📱 ❌ Failed to send outdoor run state change: \(error.localizedDescription)")
                // Fallback to application context
                try? session.updateApplicationContext(stateChangeCommand)
            })
        } else {
            print("📱 ⚠️ Watch not reachable - using application context")
            try? session.updateApplicationContext(stateChangeCommand)
        }
        
        print("📱 === END OUTDOOR RUN STATE CHANGE DEBUG ===")
    }
    
    // MARK: - Indoor Run State Change Communication
    private func sendIndoorRunStateChangeToWatch(newState: String) {
        print("📱 === INDOOR RUN STATE CHANGE DEBUG ===")
        print("📱 Attempting to send state change: \(newState)")
        
        // Check WCSession activation state
        let session = WCSession.default
        print("📱 WCSession.isSupported: \(WCSession.isSupported())")
        print("📱 WCSession.activationState: \(session.activationState.rawValue)")
        print("📱 WCSession.isReachable: \(session.isReachable)")
        print("📱 WCSession.isPaired: \(session.isPaired)")
        
        guard WCSession.isSupported() else {
            print("📱 ❌ WCSession not supported on this device")
            return
        }
        
        guard session.activationState == .activated else {
            print("📱 ❌ WCSession not activated (state: \(session.activationState.rawValue))")
            return
        }
        
        guard session.isPaired else {
            print("📱 ❌ Watch not paired")
            return
        }
        
        // Don't send messages if we're handling a remote state change to prevent loops
        guard !isHandlingRemoteStateChange else {
            print("📱 ⚠️ Skipping state change message - handling remote state change")
            return
        }
        
        // Create a state change command message
        let stateChangeCommand: [String: Any] = [
            "type": "indoorRunStateChange",
            "command": newState,
            "isIndoor": true,
            "timestamp": Date().timeIntervalSince1970,
            "workoutId": workoutId.uuidString
        ]
        
        print("📱 Message payload: \(stateChangeCommand)")
        
        // Try different sending strategies
        if session.isReachable {
            print("📱 ✅ Watch is reachable - sending message with reply handler")
            
            session.sendMessage(stateChangeCommand, replyHandler: { response in
                print("📱 ✅ Watch acknowledged indoor run state change")
                print("📱 ✅ Watch reply: \(response)")
            }, errorHandler: { error in
                print("📱 ❌ Failed to send indoor run state change: \(error.localizedDescription)")
                print("📱 ❌ Error code: \(error._code)")
                print("📱 ❌ Error domain: \(error._domain)")
                
                // Try sending via application context as fallback
                DispatchQueue.main.async {
                    self.sendStateChangeViaApplicationContext(stateChangeCommand)
                }
            })
        } else {
            print("📱 ⚠️ Watch not reachable - trying application context")
            sendStateChangeViaApplicationContext(stateChangeCommand)
        }
        
        print("📱 === END INDOOR RUN STATE CHANGE DEBUG ===")
    }

    // Fallback method to send state change via application context
    private func sendStateChangeViaApplicationContext(_ stateChangeCommand: [String: Any]) {
        print("📱 Attempting to send state change via application context")
        
        do {
            try WCSession.default.updateApplicationContext(stateChangeCommand)
            print("📱 ✅ State change sent via application context")
        } catch {
            print("📱 ❌ Failed to send state change via application context: \(error.localizedDescription)")
        }
    }



    // Single importWorkoutFromWatch method that uses rawData
   public func importWorkoutFromWatch(
    runType: RunType,
    isIndoorMode: Bool,
    distance: Measurement<UnitLength>,
    elapsedTime: TimeInterval,
    heartRate: Double,
    calories: Double,
    cadence: Double,
    rawData: [String: Any],
    startDate: Date? = nil 
) {
    // Update run type and indoor mode flag
    self.runType = runType
    self.isIndoorMode = isIndoorMode

     // Set the actual startDate if provided, otherwise calculate it
    if let actualStartDate = startDate {
        print("📱 Using actual startDate from watch: \(actualStartDate)")
        self.startDate = actualStartDate
    } else {
        // Fallback to calculated startDate for backward compatibility
        let pauseDuration = rawData["pauseDuration"] as? TimeInterval ?? 0
        let totalTimeIncludingPauses = elapsedTime + pauseDuration
        self.startDate = Date().addingTimeInterval(-totalTimeIncludingPauses)
        print("📱 Calculated startDate from elapsed time: \(self.startDate!)")
    }
    
    // Extract location data from rawData if available
    var locationDataArray: [LocationData] = []
    
    // Immediately update runLog with imported data
       updateRunLogWithCurrentMetrics()
    
    if !isIndoorMode,
       let hasLocationHistory = rawData["hasLocationHistory"] as? Bool,
       hasLocationHistory,
       let locationHistory = rawData["locationHistory"] as? [[String: Any]] {
        
        // Process location history for outdoor runs
        for locationPoint in locationHistory {
            guard let latitude = locationPoint["latitude"] as? Double,
                  let longitude = locationPoint["longitude"] as? Double,
                  let altitude = locationPoint["altitude"] as? Double,
                  let timestamp = locationPoint["timestamp"] as? TimeInterval,
                  let horizontalAccuracy = locationPoint["horizontalAccuracy"] as? Double,
                  let verticalAccuracy = locationPoint["verticalAccuracy"] as? Double,
                  let speed = locationPoint["speed"] as? Double,
                  let course = locationPoint["course"] as? Double else {
                continue
            }
            
            // Extract heart rate and cadence if available
            let locationHeartRate = locationPoint["heartRate"] as? Double
            let locationCadence = locationPoint["cadence"] as? Double
            
            // Create LocationData object
            let locationData = LocationData(
                latitude: latitude,
                longitude: longitude,
                altitude: altitude,
                horizontalAccuracy: horizontalAccuracy,
                verticalAccuracy: verticalAccuracy,
                course: course,
                speed: speed,
                distance: 0, // Distance will be calculated incrementally
                timestamp: Date(timeIntervalSince1970: timestamp),
                heartRate: locationHeartRate,
                cadence: locationCadence
            )
            
            locationDataArray.append(locationData)
        }
    } else if isIndoorMode,
              let treadmillDataPoints = rawData["treadmillDataPoints"] as? [[String: Any]] {
        
        // Process treadmill data points for indoor runs
        var dataPoints: [TreadmillDataPoint] = []
        
        for point in treadmillDataPoints {
            guard let timestamp = point["timestamp"] as? TimeInterval,
                  let distance = point["distance"] as? Double,
                  let heartRate = point["heartRate"] as? Double,
                  let cadence = point["cadence"] as? Double,
                  let speed = point["speed"] as? Double,
                  let pace = point["pace"] as? Double else {
                continue
            }
            
            let incline = point["incline"] as? Double
            
            let dataPoint = TreadmillDataPoint(
                timestamp: Date(timeIntervalSince1970: timestamp),
                distance: distance,
                heartRate: heartRate,
                cadence: cadence,
                speed: speed,
                pace: pace
            )
            
            dataPoints.append(dataPoint)
        }
        
        // Store treadmill data points for later use when saving to Parse
        self.treadmillDataPoints = dataPoints
    }
    
    // Update basic metrics
    self.distance = distance
    self.elapsedTime = elapsedTime
    self.heartRate = heartRate
    self.calories = calories
    self.cadence = cadence
    
    // If we have location data, update the location list
    if !locationDataArray.isEmpty {
        self.locationList = locationDataArray
    }
    
    // Update tracking roles based on the data we received
    let hasGoodLocationData = !locationDataArray.isEmpty && locationDataArray.first?.horizontalAccuracy ?? 100 < 20
    
    metricsCoordinator?.updatePolicy(
        isIndoor: isIndoorMode,
        hasGoodGPS: hasGoodLocationData,
        isWatchTracking: true
    )
    
    // Calculate pace based on the imported data
    calculatePace()
    
    // Update formatted values
    updateFormattedValues()
}

    // MARK: - Run History Request Handler
    
    /// Handle run history request from watch for pace zone calculation
    private func handleRunHistoryRequest(limit: Int, replyHandler: @escaping ([String: Any]) -> Void) {
        print("📱 🚀 STARTING RUN HISTORY REQUEST HANDLER")
        print("📱 📊 Request limit: \(limit)")
        print("📱 🔍 Checking for cached data...")
        
        // Check if we have cached average pace - if so, send immediately
        if let cachedAverage = getCachedAveragePace() {
            print("📱 ✅ FOUND CACHED AVERAGE PACE!")
            print("📱 📊 Cached pace: \(cachedAverage.pace) seconds/km")
            print("📱 📊 Run count: \(cachedAverage.runCount)")
            print("📱 📊 Last update: \(cachedAverage.lastUpdate)")
            
            let response: [String: Any] = [
                "status": "success",
                "cachedAverage": cachedAverage.pace,
                "runCount": cachedAverage.runCount,
                "lastUpdate": cachedAverage.lastUpdate.timeIntervalSince1970,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            print("📱 🚀 SENDING CACHED RESPONSE TO WATCH")
            print("📱 📦 Response: \(response)")
            replyHandler(response)
            return
        }
        
        print("📱 ❌ No cached average pace found")
        
        // Check if we have cached run logs (both outdoor and indoor)
        print("📱 🔍 Checking cached run logs...")
        print("📱 📊 Outdoor runs cached: \([].count)")
        print("📱 📊 Indoor runs cached: \([].count)")
        
        if ![].isEmpty || ![].isEmpty {
            print("📱 ✅ FOUND CACHED RUN LOGS - Using for pace zone calculation")
            sendCombinedRunHistoryToWatch(outdoorRuns: [], indoorRuns: [], limit: limit, replyHandler: replyHandler)
            return
        }
        
        // If we have partial cached data, respond immediately with what we have
        // This prevents the watch from waiting for both database calls
        if ![].isEmpty {
            print("📱 ✅ FOUND CACHED OUTDOOR RUNS ONLY - Using for pace zone calculation")
            sendCombinedRunHistoryToWatch(outdoorRuns: [], indoorRuns: [], limit: limit, replyHandler: replyHandler)
            return
        }
        
        if ![].isEmpty {
            print("📱 ✅ FOUND CACHED INDOOR RUNS ONLY - Using for pace zone calculation")
            sendCombinedRunHistoryToWatch(outdoorRuns: [], indoorRuns: [], limit: limit, replyHandler: replyHandler)
            return
        }
        
        // Fetch both outdoor and indoor run history from server
        print("📱 ❌ NO CACHED RUN LOGS FOUND")
        print("📱 🌐 FETCHING FRESH RUN HISTORY FROM DATABASE...")
        print("📱 🔄 Starting parallel fetch: outdoor + indoor runs")
        let group = DispatchGroup()
        var outdoorRuns: [RunLog] = []
        var indoorRuns: [IndoorRunLog] = []
        var fetchErrors: [Error] = []
        
        // Fetch outdoor runs from AWS
        group.enter()
        print("📱 🔄 Starting outdoor runs fetch from AWS...")
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            group.leave()
            fetchErrors.append(NSError(domain: "RunTrackingEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user ID available"]))
            return
        }
        
        ActivityService.shared.getRuns(
            userId: userId,
            limit: 100,
            nextToken: nil,
            includeRouteUrls: false
        ) { result in
            defer { group.leave() }
            
            switch result {
            case .success(let response):
                guard let data = response.data else {
                    print("📱 ❌ No data in response")
                    outdoorRuns = []
                    return
                }
                
                print("📱 📊 Raw logs count: \(data.activities.count)")
                var runningLogs = [RunLog]()
                for (index, activity) in data.activities.enumerated() {
                    // Parse activityData JSON string if available
                    let parsedActivityData = activity.parsedActivityData
                    
                    var runLog = RunLog()
                    runLog.id = activity.id
                    runLog.createdBy = activity.userId
                    runLog.avgPace = parsedActivityData?["averagePace"] as? String
                    runLog.duration = self.formatDuration(activity.duration)
                    runLog.distance = self.formatDistance(activity.distance)
                    
                    // Parse createdAt from ISO8601 string to Date
                    let dateFormatter = ISO8601DateFormatter()
                    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = dateFormatter.date(from: activity.createdAt) {
                        runLog.createdAt = date
                    } else {
                        dateFormatter.formatOptions = [.withInternetDateTime]
                        runLog.createdAt = dateFormatter.date(from: activity.createdAt)
                    }
                    
                    runLog.caloriesBurned = activity.calories
                    runLog.runType = parsedActivityData?["runType"] as? String ?? activity.runType
                    runLog.avgHeartRate = activity.avgHeartRate
                    runLog.maxHeartRate = activity.maxHeartRate
                    runningLogs.append(runLog)
                    
                    if index < 3 {
                        print("📱 🏃 Run \(index + 1): pace=\(runLog.avgPace ?? "nil"), distance=\(runLog.distance ?? "nil"), duration=\(runLog.duration ?? "nil")")
                    }
                }
                outdoorRuns = runningLogs
                print("📱 ✅ SUCCESSFULLY FETCHED \(outdoorRuns.count) OUTDOOR RUNS")
                
            case .failure(let error):
                print("📱 ❌ ERROR FETCHING OUTDOOR RUNS: \(error.localizedDescription)")
                fetchErrors.append(error)
                outdoorRuns = []
            }
        }
        
        // Fetch indoor runs from AWS (filtered by runType = "treadmill_run")
        group.enter()
        print("📱 🔄 Starting indoor runs fetch from AWS...")
        ActivityService.shared.getRuns(
            userId: userId,
            limit: 100,
            nextToken: nil,
            includeRouteUrls: false
        ) { result in
            defer { group.leave() }
            
            switch result {
            case .success(let response):
                guard let data = response.data else {
                    print("📱 ❌ No data in response")
                    indoorRuns = []
                    return
                }
                
                print("📱 📊 Raw indoor logs count: \(data.activities.count)")
                // Filter for treadmill runs and convert to IndoorRunLog
                let treadmillLogs = data.activities.compactMap { activity -> IndoorRunLog? in
                    // Parse activityData JSON string if available
                    let parsedActivityData = activity.parsedActivityData
                    
                    // Only process treadmill runs
                    let runType = parsedActivityData?["runType"] as? String ?? activity.runType
                    guard let runType = runType, runType == "treadmill_run" else { return nil }
                    
                    // Convert AWSActivity to IndoorRunLog format
                    var json: [String: Any] = [:]
                    json["id"] = activity.id
                    json["createdBy"] = activity.userId
                    json["duration"] = self.formatDuration(activity.duration)
                    json["distance"] = self.formatDistance(activity.distance)
                    json["averagePace"] = parsedActivityData?["averagePace"] as? String
                    json["createdAt"] = activity.createdAt
                    json["caloriesBurned"] = activity.calories
                    json["runType"] = runType
                    json["treadmillDataPoints"] = parsedActivityData?["treadmillDataPoints"] as? [[String: Any]]
                    
                    return IndoorRunLog.fromJSON(json: json)
                }
                indoorRuns = treadmillLogs
                print("📱 ✅ SUCCESSFULLY FETCHED \(indoorRuns.count) INDOOR RUNS")
                
                for (index, run) in indoorRuns.prefix(3).enumerated() {
                    print("📱 🏃‍♂️ Indoor run \(index + 1): pace=\(run.avgPace ?? "nil"), distance=\(run.distance ?? "nil"), duration=\(run.duration ?? "nil")")
                }
                
            case .failure(let error):
                print("📱 ❌ ERROR FETCHING INDOOR RUNS: \(error.localizedDescription)")
                fetchErrors.append(error)
                indoorRuns = []
            }
        }
        
        // Wait for both requests to complete
        group.notify(queue: .main) { [weak self] in
            print("📱 🔄 BOTH DATABASE REQUESTS COMPLETED")
            
            guard let self = self else {
                print("📱 ❌ RunTrackingEngine deallocated during database fetch")
                replyHandler(["status": "error", "message": "RunTrackingEngine deallocated"])
                return
            }
            
            print("📱 📊 FINAL RESULTS:")
            print("📱 📊 - Outdoor runs: \(outdoorRuns.count)")
            print("📱 📊 - Indoor runs: \(indoorRuns.count)")
            print("📱 📊 - Fetch errors: \(fetchErrors.count)")
            
            // If we have errors but no data, return error
            if !fetchErrors.isEmpty && outdoorRuns.isEmpty && indoorRuns.isEmpty {
                let errorMessage = fetchErrors.first?.localizedDescription ?? "Unknown error"
                print("📱 ❌ NO DATA FETCHED AND ERRORS OCCURRED - Returning error")
                replyHandler(["status": "error", "message": errorMessage])
                return
            }
            
            if outdoorRuns.isEmpty && indoorRuns.isEmpty {
                print("📱 ⚠️ NO RUN DATA FOUND - User might be new")
            }
            
            print("📱 🚀 SENDING COMBINED RESULTS TO WATCH")
            
            // Send combined results to watch
            self.sendCombinedRunHistoryToWatch(outdoorRuns: outdoorRuns, indoorRuns: indoorRuns, limit: limit, replyHandler: replyHandler)
        }
    }
    
    /// Send combined run history data (outdoor + indoor) to watch in the expected format
    private func sendCombinedRunHistoryToWatch(outdoorRuns: [RunLog], indoorRuns: [IndoorRunLog], limit: Int, replyHandler: @escaping ([String: Any]) -> Void) {
        print("📱 🔄 PROCESSING COMBINED RUN HISTORY FOR WATCH")
        print("📱 📊 Input: \(outdoorRuns.count) outdoor + \(indoorRuns.count) indoor runs")
        print("📱 📊 Limit: \(limit)")
        
        var runLogData: [[String: Any]] = []
        
        // Convert outdoor RunLog objects to dictionaries
        for runLog in outdoorRuns {
            var logData: [String: Any] = [:]
            
            // Add basic run information
            if let id = runLog.id {
                logData["id"] = id
            }
            if let duration = runLog.duration {
                logData["duration"] = duration
            }
            if let distance = runLog.distance {
                logData["distance"] = distance
            }
            if let avgPace = runLog.avgPace {
                logData["avgPace"] = avgPace
            }
            if let createdAt = runLog.createdAt {
                logData["createdAt"] = createdAt.timeIntervalSince1970
            }
            if let calories = runLog.caloriesBurned {
                logData["calories"] = calories
            }
            if let runType = runLog.runType {
                logData["runType"] = runType
            } else {
                logData["runType"] = "outdoor"
            }
            
            // Add heart rate data if available
            if let avgHeartRate = runLog.avgHeartRate {
                logData["avgHeartRate"] = avgHeartRate
            }
            if let maxHeartRate = runLog.maxHeartRate {
                logData["maxHeartRate"] = maxHeartRate
            }
            
            runLogData.append(logData)
        }
        
        // Convert indoor IndoorRunLog objects to dictionaries
        for indoorRun in indoorRuns {
            var logData: [String: Any] = [:]
            
            // Add basic run information
            if let id = indoorRun.id {
                logData["id"] = id
            }
            if let duration = indoorRun.duration {
                logData["duration"] = duration
            }
            if let distance = indoorRun.distance {
                logData["distance"] = distance
            }
            if let avgPace = indoorRun.avgPace {
                logData["avgPace"] = avgPace
            }
            if let createdAt = indoorRun.createdAt {
                logData["createdAt"] = createdAt.timeIntervalSince1970
            }
            if let calories = indoorRun.caloriesBurned {
                logData["calories"] = calories
            }
            if let runType = indoorRun.runType {
                logData["runType"] = runType
            } else {
                logData["runType"] = "indoor"
            }
            
            // Add heart rate data if available
            if let avgHeartRate = indoorRun.avgHeartRate {
                logData["avgHeartRate"] = avgHeartRate
            }
            if let maxHeartRate = indoorRun.maxHeartRate {
                logData["maxHeartRate"] = maxHeartRate
            }
            
            runLogData.append(logData)
        }
        
        // Sort by creation date (most recent first) and limit results
        let sortedData = runLogData.sorted { (first, second) in
            let firstDate = first["createdAt"] as? TimeInterval ?? 0
            let secondDate = second["createdAt"] as? TimeInterval ?? 0
            return firstDate > secondDate
        }
        
        let limitedLogs = Array(sortedData.prefix(limit))
        
        let response: [String: Any] = [
            "status": "success",
            "runLogs": limitedLogs,
            "count": limitedLogs.count,
            "outdoorCount": outdoorRuns.count,
            "indoorCount": indoorRuns.count,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        print("📱 📊 FINAL PROCESSING RESULTS:")
        print("📱 📊 - Total logs processed: \(runLogData.count)")
        print("📱 📊 - Limited logs: \(limitedLogs.count)")
        print("📱 📊 - Response status: \(response["status"] ?? "unknown")")
        
        print("📱 🚀 SENDING FINAL RESPONSE TO WATCH")
        print("📱 📦 Response keys: \(response.keys.joined(separator: ", "))")
        replyHandler(response)
        
        // Cache the calculated average pace for future quick responses
        if !limitedLogs.isEmpty {
            print("📱 💾 Caching average pace from \(limitedLogs.count) logs")
            cacheAveragePaceFromRunLogs(limitedLogs)
        } else {
            print("📱 ⚠️ No logs to cache average pace from")
        }
    }
    
    // MARK: - Average Pace Caching
    
    /// Structure to hold cached average pace data
    private struct CachedAveragePace {
        let pace: Double
        let runCount: Int
        let lastUpdate: Date
    }
    
    /// Get cached average pace from UserDefaults
    private func getCachedAveragePace() -> CachedAveragePace? {
        let pace = UserDefaults.standard.double(forKey: "cachedAveragePace")
        let runCount = UserDefaults.standard.integer(forKey: "cachedRunCount")
        let lastUpdate = UserDefaults.standard.object(forKey: "cachedPaceLastUpdate") as? Date ?? Date.distantPast
        
        // Return nil if no valid cache
        guard pace > 0 && runCount > 0 else { return nil }
        
        // Return nil if cache is older than 30 days
        if Date().timeIntervalSince(lastUpdate) > 30 * 24 * 60 * 60 {
            return nil
        }
        
        return CachedAveragePace(pace: pace, runCount: runCount, lastUpdate: lastUpdate)
    }
    
    /// Cache average pace calculated from run logs
    private func cacheAveragePaceFromRunLogs(_ runLogs: [[String: Any]]) {
        var validPaces: [Double] = []
        
        for runLog in runLogs {
            // Try to get pace from avgPace field
            if let avgPaceString = runLog["avgPace"] as? String,
               let paceSeconds = parsePaceString(avgPaceString) {
                validPaces.append(paceSeconds)
            }
            // Also try to calculate from duration and distance
            else if let durationString = runLog["duration"] as? String,
                     let distanceString = runLog["distance"] as? String,
                     let duration = parseDurationString(durationString),
                     let distance = parseDistanceString(distanceString),
                     distance > 0 {
                let paceSecondsPerKm = (duration / distance) * 1000
                if paceSecondsPerKm > 180 && paceSecondsPerKm < 1800 { // Reasonable pace range
                    validPaces.append(paceSecondsPerKm)
                }
            }
        }
        
        if !validPaces.isEmpty {
            let averagePace = validPaces.reduce(0, +) / Double(validPaces.count)
            
            UserDefaults.standard.set(averagePace, forKey: "cachedAveragePace")
            UserDefaults.standard.set(validPaces.count, forKey: "cachedRunCount")
            UserDefaults.standard.set(Date(), forKey: "cachedPaceLastUpdate")
            
            print("📱 Cached average pace: \(averagePace) from \(validPaces.count) runs")
        }
    }
    
    /// Update cached average pace with new run data
    private func updateCachedAveragePace(newPace: Double) {
        let currentAverage = UserDefaults.standard.double(forKey: "cachedAveragePace")
        let currentCount = UserDefaults.standard.integer(forKey: "cachedRunCount")
        
        // Calculate new average: (old_avg * old_count + new_pace) / (old_count + 1)
        let newAverage = (currentAverage * Double(currentCount) + newPace) / Double(currentCount + 1)
        let newCount = currentCount + 1
        
        // Save updated values
        UserDefaults.standard.set(newAverage, forKey: "cachedAveragePace")
        UserDefaults.standard.set(newCount, forKey: "cachedRunCount")
        UserDefaults.standard.set(Date(), forKey: "cachedPaceLastUpdate")
        
        print("📱 Updated cached average pace: \(newAverage) from \(newCount) runs")
    }
    
    /// Helper function to parse pace string (MM:SS format) to seconds per km
    private func parsePaceString(_ paceString: String) -> Double? {
        let components = paceString.components(separatedBy: ":")
        guard components.count == 2,
              let minutes = Double(components[0]),
              let seconds = Double(components[1]) else {
            return nil
        }
        
        let totalSeconds = (minutes * 60) + seconds
        return totalSeconds > 0 ? totalSeconds : nil
    }
    
    /// Helper function to parse duration string to seconds
    private func parseDurationString(_ durationString: String) -> Double? {
        let components = durationString.components(separatedBy: ":")
        guard components.count >= 2 else { return nil }
        
        var totalSeconds: Double = 0
        if components.count == 3 {
            // HH:MM:SS format
            if let hours = Double(components[0]),
               let minutes = Double(components[1]),
               let seconds = Double(components[2]) {
                totalSeconds = (hours * 3600) + (minutes * 60) + seconds
            }
        } else {
            // MM:SS format
            if let minutes = Double(components[0]),
               let seconds = Double(components[1]) {
                totalSeconds = (minutes * 60) + seconds
            }
        }
        
        return totalSeconds > 0 ? totalSeconds : nil
    }
    
    /// Helper function to parse distance string to numeric value
    private func parseDistanceString(_ distanceString: String) -> Double? {
        // Remove any non-numeric characters except decimal point
        let cleanedString = distanceString.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        return Double(cleanedString)
    }
    
    /// Update cached average pace with current run's data
    private func updateCachedPaceWithCurrentRun() {
        // Calculate pace for current run
        guard distance.value > 0 && elapsedTime > 0 else {
            print("📱 Cannot update cached pace - invalid distance or time")
            return
        }
        
        // Calculate pace in seconds per km
        let distanceInKm = distance.value / 1000.0
        let paceSecondsPerKm = elapsedTime / distanceInKm
        
        // Only update if pace is reasonable (between 3-30 min/km)
        guard paceSecondsPerKm > 180 && paceSecondsPerKm < 1800 else {
            print("📱 Cannot update cached pace - unreasonable pace: \(paceSecondsPerKm) s/km")
            return
        }
        
        // Update cached average pace
        updateCachedAveragePace(newPace: paceSecondsPerKm)
        
        print("📱 Updated cached average pace with current run: \(paceSecondsPerKm) s/km")
    }
    
    // Update the handleWatchActiveWorkout method to use the new import method
    private func handleWatchActiveWorkout(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    // Process on main thread to avoid threading issues
    DispatchQueue.main.async { [weak self] in
        guard let self = self else {
            replyHandler(["status": "error", "message": "RunTrackingEngine deallocated"])
            return
        }
        
        // Extract basic workout information
        let workoutId = message["id"] as? String ?? UUID().uuidString
        let workoutState = message["state"] as? String ?? "unknown"
        let isIndoorMode = message["isIndoor"] as? Bool ?? false
        let elapsedTime = message["elapsedTime"] as? TimeInterval ?? 0
        let watchDistance = message["distance"] as? Double ?? 0
        let runType = message["runType"] as? String ?? ""
        
        // Check if this is an indoor/treadmill run
        let isTreadmillRun = (runType == "treadmillRun" || isIndoorMode)
        
       
        
        // CHANGE: Modified guard clause to also accept "completed" state
        // Check if this is an active workout
        let workoutActive = workoutState != "notStarted" && workoutState != "unknown"
        let isValidState = workoutState == "inProgress" || workoutState == "paused" || workoutState == "completed"
        
        guard workoutActive && isValidState else {
            print("📱 Watch workout not active or in valid state, ignoring")
            replyHandler(["status": "error", "message": "Not an active workout"])
            return
        }
        
        // If it's an indoor run, automatically enable dashboard mode
        if isTreadmillRun && workoutActive {
            self.isDashboardMode = true
            print("📱 Automatically enabling dashboard mode for indoor run from watch")
        }
        
        // CHANGE: Add handling for completed state
        // Handle completed state from watch
        if workoutState == "completed" {
            // Check if we should end the run on the phone
            let forcedStateChange = message["forcedStateChange"] as? Bool ?? false
            
            if forcedStateChange && (self.runState == .running || self.runState == .paused) {
                print("📱 Watch has ended workout, ending run on phone")
                
                // Update indoor mode flag to match the watch
                self.isIndoorMode = isIndoorMode
                
                // Import the final workout data from the watch before ending
                let runType: RunType = isIndoorMode ? .treadmillRun : .outdoorRun
                
                // Create distance measurement
                let distanceMeasurement = Measurement(value: watchDistance, unit: UnitLength.meters)
                
                // Extract additional data from the message
                let heartRate = message["heartRate"] as? Double ?? 0
                let calories = message["calories"] as? Double ?? 0
                let cadence = message["cadence"] as? Double ?? 0
                
                // Import the workout data
                self.importWorkoutFromWatch(
                    runType: runType,
                    isIndoorMode: isIndoorMode,
                    distance: distanceMeasurement,
                    elapsedTime: elapsedTime,
                    heartRate: heartRate,
                    calories: calories,
                    cadence: cadence,
                    rawData: message
                )
                
                // End the run, which will save to Parse
                self.endRun()
                
                // Send success response with database save confirmation
                replyHandler([
                    "status": "success", 
                    "message": "Run ended and saved", 
                    "phoneState": "completed",
                    "databaseSaved": true,
                    "timestamp": Date().timeIntervalSince1970
                ])
                return
            }
        }
        
        // Rest of the method remains unchanged...
        
        // Send response
        replyHandler(["status": "success", "phoneState": self.runState.rawValue])
    }
}

    // MARK: - Watch Communication Methods
    
    // Special handler for ActiveWorkoutChecker requests
    public func handleActiveRunningWorkoutRequest(replyHandler: @escaping ([String: Any]) -> Void) {
        // Send an immediate acknowledgment to prevent the watch from waiting
        let immediateAck: [String: Any] = [
            "status": "received",
            "timestamp": Date().timeIntervalSince1970,
            "hasActiveWorkout": (runState == .running || runState == .paused),
            "useImperialUnits": !useMetric
        ]
        
        // Reply immediately to unblock the watch
        replyHandler(immediateAck)
        
        // Update application context on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateApplicationContext()
        }
    }

    // Public method to check and restart the timer if needed
    public func ensureTimerIsRunning() -> Bool {
        if timer == nil && (runState == .running || runState == .paused) {
            print("📱 Restarting timer that was unexpectedly nil")
            startTimer()
            return true
        }
        return timer != nil
    }
    
    // Calculate total pause duration for the run
    private func calculatePauseDuration() -> TimeInterval {
        var totalDuration = totalPausedTime
        
        // If we're currently paused, add the current pause duration
        if runState == .paused, let pauseDate = self.pauseDate {
            totalDuration += Date().timeIntervalSince(pauseDate)
        }
        
        return totalDuration
    }
    
    // Update split times based on current distance
    private func updateSplitTimes() {
        // Call the existing method that checks for new split times
        checkForSplitTime()
    }

    // Add one-time method to catch up phone distance with watch distance
    public func catchUpDistanceWithWatch() {
        // Only needed when the watch is considered primary for distance
        guard !isPrimaryForDistance else {
            print("📱 No distance catch-up needed - phone is primary for distance")
            return
        }
        
        print("📱 Requesting current distance from watch for one-time catch-up")
        
        // Check if watch is reachable
        guard WCSession.default.activationState == .activated && WCSession.default.isReachable else {
            print("📱 Watch not reachable for distance catch-up")
            return
        }
        
        // Send a request to the watch asking for current distance
        let message: [String: Any] = [
            "type": "requestCurrentDistance",
            "requestId": UUID().uuidString,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.sendMessage(message, replyHandler: { [weak self] response in
            guard let self = self else { return }
            
            if let watchDistance = response["distance"] as? Double, watchDistance > 0 {
                print("📱 Received catch-up distance from watch: \(watchDistance)m")
                
                // Update distance only if watch distance is greater
                if watchDistance > self.distance.value {
                    print("📱 Setting distance to match watch: \(watchDistance)m (was \(self.distance.value)m)")
                    DispatchQueue.main.async {
                        self.distance = Measurement(value: watchDistance, unit: UnitLength.meters)
                        self.updateFormattedValues()
                    }
                } else {
                    print("📱 Watch distance (\(watchDistance)m) not greater than phone distance (\(self.distance.value)m) - no update needed")
                }
            } else {
                print("📱 No valid distance received from watch for catch-up")
            }
        }, errorHandler: { error in
            print("📱 Error requesting distance from watch: \(error.localizedDescription)")
        })
    }
    
    // Handle messages without reply handler
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Process the message on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let type = message["responseType"] as? String, type == "distanceResponse" {
                // This is a response to our distance catch-up request
                if let watchDistance = message["distance"] as? Double, watchDistance > 0 {
                    print("📱 Received distance response from watch: \(watchDistance)m")
                    
                    // Only update if watch distance is greater
                    if watchDistance > self.distance.value {
                        print("📱 Updating distance to match watch: \(watchDistance)m (was \(self.distance.value)m)")
                        self.distance = Measurement(value: watchDistance, unit: UnitLength.meters)
                        self.updateFormattedValues()
                    } else {
                        print("📱 Watch distance (\(watchDistance)m) not greater than phone distance (\(self.distance.value)m) - no update needed")
                    }
                }
                return
            }
            
            // Process other messages
            self.processWatchMessage(message)
        }
    }
    
    // Add this new method for importing workouts from the watch
    
    // MARK: - User Notification Methods
    
    private func showSaveErrorNotification(error: Error) {
        // Create an alert to notify the user of the save error
        let alert = UIAlertController(
            title: "Workout Save Failed",
            message: "Your workout couldn't be saved to the cloud. We'll keep trying automatically. Error: \(error.localizedDescription)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        alert.addAction(UIAlertAction(title: "Retry Now", style: .default) { [weak self] _ in
            self?.saveRun()
        })
        
        // Present the alert from the top-most view controller
        if let topViewController = UIApplication.shared.windows.first?.rootViewController {
            var presentingVC = topViewController
            while let presentedVC = presentingVC.presentedViewController {
                presentingVC = presentedVC
            }
            presentingVC.present(alert, animated: true)
        }
    }
    
    private func showSaveSuccessNotification() {
        // Show a brief success message
        print("📱 💾 ✅ Workout saved successfully to cloud")
        
        // You could also show a toast notification here if you have a toast library
        // For now, just log the success - the user will see it in the workout summary
    }
}


// MARK: - RunState Enum

enum RunState: String {
    case notStarted = "notStarted"
    case running = "inProgress"
    case paused = "paused"
    case completed = "completed"
    
    var isActive: Bool {
        return self == .running || self == .paused
    }

    // Convert to RunningWorkoutState
    var toWorkoutState: RunningWorkoutState {
        switch self {
        case .notStarted: return .notStarted
        case .running: return .inProgress
        case .paused: return .paused
        case .completed: return .completed
        }
    }
}

// Extension to convert numeric types to little-endian data
extension UInt16 {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt16>.size)
    }
}

extension UInt32 {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }
}

// MARK: - Watch Handoff and Multi-Device Support

extension RunTrackingEngine {
    
    // MARK: - Handoff Support
    
    /// Initiate handoff to watch
    func initiateHandoffToWatch(completion: @escaping (Bool) -> Void) {
        guard runState != .notStarted else {
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
            workoutType: .running,
            workoutId: workoutId.uuidString,
            metrics: metrics,
            state: convertRunStateToWorkoutState(runState),
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
                    // Stop tracking on phone
                    self.endRun()
                }
                completion(accepted)
            }, errorHandler: { error in
                print("❌ [RunTrackingEngine] Handoff failed: \(error.localizedDescription)")
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
        
        // Check for conflicts
        if runState != .notStarted {
            // Conflict - both devices tracking
            handleHandoffConflict(phoneState: convertRunStateToWorkoutState(runState),
                                watchWorkout: handoffMessage)
            return
        }
        
        // Accept handoff and join workout
        isJoiningExistingWorkout = true
        workoutId = UUID(uuidString: handoffMessage.workoutId) ?? UUID()
        startDate = handoffMessage.startDate
        
        // Update metrics
        distance = Measurement(value: handoffMessage.metrics.distance, unit: UnitLength.meters)
        elapsedTime = handoffMessage.metrics.elapsedTime
        heartRate = handoffMessage.metrics.heartRate
        
        // Convert pace from seconds per meter to the appropriate UnitSpeed
        // handoffMessage.metrics.pace is in seconds per meter
        // We need to convert to minutes per km or minutes per mile based on useMetric
        let paceInSecondsPerMeter = handoffMessage.metrics.pace
        if useMetric {
            // Convert to minutes per kilometer: (seconds/meter) * (1000 meters/km) / (60 seconds/min)
            let paceInMinutesPerKm = paceInSecondsPerMeter * 1000.0 / 60.0
            pace = Measurement(value: paceInMinutesPerKm, unit: UnitSpeed.minutesPerKilometer)
        } else {
            // Convert to minutes per mile: (seconds/meter) * (1609.34 meters/mi) / (60 seconds/min)
            let paceInMinutesPerMile = paceInSecondsPerMeter * 1609.34 / 60.0
            pace = Measurement(value: paceInMinutesPerMile, unit: UnitSpeed.minutesPerMile)
        }
        
        calories = handoffMessage.metrics.calories
        cadence = handoffMessage.metrics.cadence ?? 0
        
        // Update state
        runState = convertWorkoutStateToRunState(handoffMessage.state)
        
        // Confirm handoff
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            print("⚠️ [RunTrackingEngine] Cannot send handoff response - WCSession not available")
            return
        }
        
        session.sendMessage([
            "type": "handoffResponse",
            "accepted": true,
            "workoutId": workoutId.uuidString
        ], replyHandler: { response in
            print("✅ [RunTrackingEngine] Handoff response sent successfully")
        }, errorHandler: { error in
            print("❌ [RunTrackingEngine] Error sending handoff response: \(error.localizedDescription)")
        })
    }
    
    private func handleHandoffConflict(phoneState: WorkoutState, watchWorkout: WorkoutHandoffMessage) {
        // Default: accept watch workout (watch is usually more accurate for heart rate)
        // But keep phone GPS data
        isJoiningExistingWorkout = true
        workoutId = UUID(uuidString: watchWorkout.workoutId) ?? UUID()
        startDate = watchWorkout.startDate
        
        // Merge metrics - use watch for HR/cadence, phone for distance/pace
        heartRate = watchWorkout.metrics.heartRate
        cadence = watchWorkout.metrics.cadence ?? cadence
        calories = max(calories, watchWorkout.metrics.calories)
        
        // Keep phone's distance and pace (GPS is more accurate)
        elapsedTime = max(elapsedTime, watchWorkout.metrics.elapsedTime)
        
        runState = convertWorkoutStateToRunState(watchWorkout.state)
    }
    
    // MARK: - Multi-Device Support
    
    /// Integrate with external device manager
    func integrateWithExternalDevices() {
        let deviceManager = ExternalDeviceManager.shared
        let aggregator = MultiDeviceDataAggregator.shared
        
        // Subscribe to aggregated metrics
        aggregator.$aggregatedMetrics
            .sink { [weak self] metrics in
                self?.updateMetricsFromExternalDevices(metrics)
            }
            .store(in: &cancellables)
    }
    
    private func updateMetricsFromExternalDevices(_ metrics: WorkoutMetrics) {
        let coordinationEngine = DeviceCoordinationEngine.shared
        let isIndoor = isIndoorMode
        
        // Update metrics based on device coordination
        if let source = coordinationEngine.selectBestDataSource(
            for: .heartRate,
            workoutType: .running,
            isIndoor: isIndoor,
            availableSources: [.watch, .oura, .garmin, .fitbit]
        ), source == .watch || source == .oura || source == .garmin || source == .fitbit {
            if metrics.heartRate > 0 {
                heartRate = metrics.heartRate
            }
        }
        
        if let source = coordinationEngine.selectBestDataSource(
            for: .cadence,
            workoutType: .running,
            isIndoor: isIndoor,
            availableSources: [.watch, .garmin]
        ), source == .watch || source == .garmin {
            if let cadence = metrics.cadence, cadence > 0 {
                self.cadence = cadence
            }
        }
        
        if let source = coordinationEngine.selectBestDataSource(
            for: .calories,
            workoutType: .running,
            isIndoor: isIndoor,
            availableSources: [.watch, .oura, .garmin, .fitbit]
        ), source == .watch || source == .oura || source == .garmin || source == .fitbit {
            if metrics.calories > 0 {
                calories = max(calories, metrics.calories)
            }
        }
    }
    
    // MARK: - Live Metrics Sync
    
    /// Start live metrics synchronization
    func startLiveMetricsSync() {
        LiveMetricsSync.shared.startLiveSync()
        
        // Set up periodic sync
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.syncCurrentMetrics()
        }
    }
    
    /// Stop live metrics synchronization
    func stopLiveMetricsSync() {
        LiveMetricsSync.shared.stopLiveSync()
    }
    
    private func syncCurrentMetrics() {
        guard runState != .notStarted else { return }
        
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
            workoutType: .running
        )
    }
    
    // MARK: - State Conversion Helpers
    
    private func convertRunStateToWorkoutState(_ runState: RunState) -> WorkoutState {
        switch runState {
        case .notStarted: return .idle
        case .running: return .running
        case .paused: return .paused
        case .completed: return .completed
        }
    }
    
    private func convertWorkoutStateToRunState(_ workoutState: WorkoutState) -> RunState {
        switch workoutState {
        case .idle: return .notStarted
        case .starting: return .notStarted // Map starting to notStarted (closest match)
        case .running: return .running
        case .paused: return .paused
        case .stopping: return .paused // Map stopping to paused (closest match)
        case .stopped: return .notStarted // Map stopped to notStarted (closest match)
        case .completed: return .completed
        }
    }
    
    // MARK: - Enhanced Watch Sync
    
    /// Enhanced sync with watch including handoff support
    func enhancedSyncWithWatch() {
        // Use existing syncWithWatch for basic sync
        syncWithWatch()
        
        // Also sync state
        WorkoutStateSync.shared.syncState(
            workoutId: workoutId.uuidString,
            workoutType: .running,
            state: convertRunStateToWorkoutState(runState)
        )
    }
    
    // MARK: - Handoff Data Provider
    
    func getHandoffData() -> [String: Any]? {
        guard runState != .notStarted else { return nil }
        
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
            workoutType: .running,
            workoutId: workoutId.uuidString,
            metrics: metrics,
            state: convertRunStateToWorkoutState(runState),
            startDate: startDate ?? Date()
        )
        
        return handoffMessage.toDictionary()
    }
}








