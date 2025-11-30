//
//  WalkTrackingEngine.swift
//  Do.
//
//  Created by Mikiyas Meseret on 4/5/25.
//

import Foundation
import CoreLocation
import HealthKit
import Combine
import AVFoundation
import WatchConnectivity
import UIKit

extension Notification.Name {
    static let didUpdateWalkState = Notification.Name("WalkStateDidUpdate")
    static let didUpdateWalkMetrics = Notification.Name("DidUpdateWalkMetrics")
}

enum WalkState: String, CaseIterable {
    case notStarted = "Not Started"
    case preparing = "Preparing"
    case ready = "Ready"
    case inProgress = "In Progress"
    case paused = "Paused"
    case completed = "Completed"
    case stopped = "Stopped"
    case error = "Error"
    var isActive: Bool { self == .inProgress || self == .paused }
}

// Compatibility shims so controllers can use `.running`/`.paused` naming
extension WalkState {
    static var running: WalkState { .inProgress }
}

enum WalkingEngineType: String, CaseIterable {
    case outdoorWalk
    case treadmillWalk
    case trailWalk
    case recoveryWalk
    case powerWalk
    case casualWalk
}

class WalkTrackingEngine: NSObject, ObservableObject, WCSessionDelegate, WorkoutEngineProtocol {
    static let shared = WalkTrackingEngine()
    public var workoutId = UUID()

    // MARK: - State
    @Published var state: WalkState = .notStarted {
        didSet { NotificationCenter.default.post(name: .didUpdateWalkState, object: nil) }
    }
    @Published var walkingType: WalkingEngineType = .outdoorWalk
    // Compatibility with controllers that use RunType for walking
    @Published var walkType: WalkingType = .outdoorWalk

    // MARK: - Metrics
    @Published var distance: Measurement<UnitLength> = .init(value: 0, unit: .meters)
    @Published var elapsedTime: TimeInterval = 0
    @Published var pace: Measurement<UnitSpeed> = .init(value: 0, unit: .minutesPerKilometer)
    @Published var calories: Double = 0
    @Published var heartRate: Double = 0
    @Published var elevationGain: Measurement<UnitLength> = .init(value: 0, unit: .meters)
    @Published var cadence: Double = 0
    @Published var steps: Int = 0
    @Published var startTime: Date = Date()

    // MARK: - Formatted
    @Published var formattedDistance: String = "0.00"
    @Published var formattedTime: String = "00:00:00"
    @Published var formattedPace: String = "-'--\""
    @Published var formattedSteps: String = "0"
    @Published var useMetric: Bool = true
    // Controller flags expected by UI logic
    @Published var isAutoCenter: Bool = true
    @Published var isPrimaryForDistance: Bool = true
    @Published var isPrimaryForPace: Bool = true
    @Published var isPrimaryForHeartRate: Bool = false // Watch is always primary for HR
    @Published var isPrimaryForCalories: Bool = true
    @Published var isPrimaryForCadence: Bool = false // Watch is better for cadence
    @Published var isIndoorMode: Bool = false
    @Published var isWatchTracking: Bool = false
    @Published var hasGoodLocationData: Bool = true
    @Published var isDashboardMode: Bool = false

    // MARK: - Route/Location
    @Published var locationList: [CLLocation] = []
    private let locationManager = ModernLocationManager.shared

    // MARK: - HealthKit
    private let healthStore = HKHealthStore()
    private var stepQuery: HKObserverQuery?
    private var stepAnchor: HKQueryAnchor?
    private var workoutStartSteps: Int = 0
    
    // MARK: - Misc
    private var timer: Timer?
    public var currentUser: String? // User ID string instead of PFUser
    @Published var isScreenLocked: Bool = false
    @Published var coachFeedback: String?
    @Published var isJoiningExistingWorkout: Bool = false
    @Published var navigationAudioMuted: Bool = false
    
    // Watch communication properties
    private var lastWatchSyncTime: TimeInterval = 0
    private var isHandlingRemoteStateChange: Bool = false
    private var watchCommErrorCount: Int = 0
    private var watchConnectivityCheckInterval: TimeInterval = 5.0
    private var lastWatchConnectivityCheck: TimeInterval = 0

    // MARK: - Setup
    private func useImperialUnits() -> Bool {
        // Single source of truth: UserDefaults key used elsewhere in app
        // true => metric; false => imperial
        let useMetricDefaults = UserDefaults.standard.bool(forKey: "useMetricUnits")
        return !useMetricDefaults
    }
    func setCurrentUser(_ user: Any?) {
        // Accept String (user ID) or extract from PFUser-like objects
        if let userId = user as? String {
            self.currentUser = userId
        } else {
            // Try to extract objectId from PFUser-like objects
            // Use reflection to safely extract objectId if it exists
            if let userObject = user {
                let mirror = Mirror(reflecting: userObject)
                if let objectId = mirror.children.first(where: { $0.label == "objectId" })?.value as? String {
                    self.currentUser = objectId
                    return
                }
            }
            // Fallback to UserIDHelper (uses Cognito, then other sources)
            self.currentUser = UserIDHelper.shared.getCurrentUserID()
        }
    }

    func setupBackgroundCapabilities() {
        ModernLocationManager.shared.startUpdatingLocation()
    }

    // MARK: - Control
    func start() {
        guard state == .notStarted || state == .ready else { return }
        state = .inProgress
        startTime = Date()
        startTiming()
        startStepCounting()
        WorkoutBackgroundManager.shared.registerWorkout(type: "walk", engine: self)
        LockScreenManager.shared.startWorkout(type: "walk")
        updateLockScreen()
        
        // Establish device coordination when walk starts
        establishDeviceCoordination()
        
        // Notify watch of local start via application context
        updateApplicationContext()
        
        // Start smart handoff monitoring
        SmartHandoffCoordinator.shared.startMonitoring(workoutType: .walking)
    }

    func pause() {
        guard state == .inProgress else { return }
        state = .paused
        timer?.invalidate()
        updateLockScreen()
        // Push status and instruct watch to pause
        updateApplicationContext()
        sendControlToWatch(type: "pauseWalkingWorkout")
    }

    func resume() {
        guard state == .paused else { return }
        state = .inProgress
        startTiming()
        updateLockScreen()
        
        // Re-establish device coordination when resuming
        establishDeviceCoordination()
        
        // Push status and instruct watch to resume
        updateApplicationContext()
        sendControlToWatch(type: "resumeWalkingWorkout")
    }

    func stop() {
        guard state.isActive else { return }
        state = .completed
        timer?.invalidate()
        stopStepCounting()
        WorkoutBackgroundManager.shared.unregisterWorkout(type: "walk")
        LockScreenManager.shared.stopWorkout()
        // Push status and instruct watch to end
        updateApplicationContext()
        sendControlToWatch(type: "endWalkingWorkout")
        
        // Stop smart handoff monitoring
        SmartHandoffCoordinator.shared.stopMonitoring()
    }
    
    func endWalk() {
        stop()
    }
    
    private func updateLockScreen() {
        // Get user preference
        useMetric = UserDefaults.standard.bool(forKey: "useMetricUnits")
        
        // Convert distance to user's preferred unit
        let distanceValue = useMetric ? 
            distance.converted(to: .kilometers).value : 
            distance.converted(to: .miles).value
            
        let metrics = WorkoutMetrics(
            distance: distanceValue,
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            pace: useMetric ? 
                pace.converted(to: .minutesPerKilometer).value : 
                pace.converted(to: .minutesPerMile).value,
            calories: calories,
            elevationGain: elevationGain.value
        )
        LockScreenManager.shared.updateLockScreen(metrics: metrics)
    }
    
    // MARK: - State Recovery
    
    func checkForRecovery() -> Bool {
        guard let cache = WorkoutBackgroundManager.shared.loadStateCache(),
              cache.type == "walk",
              let recoveryState = WalkState(rawValue: cache.state),
              recoveryState.isActive else {
            return false
        }
        return true
    }
    
    func recoverFromCache() -> Bool {
        guard let cache = WorkoutBackgroundManager.shared.loadStateCache(),
              cache.type == "walk",
              let recoveryState = WalkState(rawValue: cache.state),
              recoveryState.isActive else {
            return false
        }
        
        // Restore state and metrics
        state = recoveryState
        distance = Measurement(value: cache.distance, unit: .meters)
        elapsedTime = cache.duration
        
        // Restore locations
        locationList = cache.locations.map { locData in
            CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: locData["lat"] ?? 0,
                    longitude: locData["lon"] ?? 0
                ),
                altitude: locData["alt"] ?? 0,
                horizontalAccuracy: 0,
                verticalAccuracy: 0,
                course: locData["course"] ?? 0,
                speed: locData["speed"] ?? 0,
                timestamp: Date(timeIntervalSince1970: locData["timestamp"] ?? 0)
            )
        }
        
        // Clear the cache after successful recovery
        WorkoutBackgroundManager.shared.clearStateCache()
        
        // Resume if we were in progress
        if state == .inProgress {
            startTiming()
            WorkoutBackgroundManager.shared.registerWorkout(type: "walk", engine: self)
        }
        
        return true
    }

    // MARK: - Controller compatibility API
    func startRun(walkType: WalkingType) {
        self.walkType = walkType
        startTime = Date()
        start()
    }

    func pauseRun() {
        pause()
    }

    func resumeRun() {
        resume()
    }

    func endRun() {
        stop()
    }

    // Incremental state helpers used by controllers
    func restoreIncrementalState() -> Bool { return false }
    func saveIncremental() {}
    func ensureTimerIsRunning() -> Bool {
        if timer == nil && state == .inProgress {
            startTiming(); return true
        }
        return false
    }

    // Watch sync helpers expected by controllers
    func catchUpDistanceWithWatch() {}
    func evaluatePrimarySource() {}
    func handleWatchCommunicationError(_ error: Error? = nil) {
        watchCommErrorCount += 1
        print("📱 Watch communication error (\(watchCommErrorCount)): \(error?.localizedDescription ?? "unknown error")")
        
        // After 3 consecutive errors, assume watch is unreachable
        if watchCommErrorCount >= 3 {
            isWatchTracking = false
            evaluatePrimarySource()
        }
    }
    

    // Metrics update helpers expected by controllers
    func updateDistanceFromWatch(_ meters: Double) {
        distance = Measurement(value: meters, unit: .meters)
        updateFormattedValues()
    }
    func updateCalories(_ kcal: Double) { calories = kcal }
    func updateHeartRate(_ bpm: Double) { heartRate = bpm }
    func updateCadence(_ spm: Double) { cadence = spm }

    // Process location updates and calculate distance
    func processLocationUpdate(_ location: CLLocation) {
        // Calculate distance from previous location if available
        if let lastLocation = locationList.last {
            let newDistance = location.distance(from: lastLocation)
            // Only add distance if accuracy is good and speed is reasonable
            if location.horizontalAccuracy <= 20 && location.speed >= 0 {
                let currentValue = distance.value
                distance = Measurement(value: currentValue + newDistance, unit: .meters)
                updateFormattedValues()
                
                // Calculate pace if we have enough data
                if elapsedTime > 0 {
                    let speedInMetersPerSecond = distance.value / elapsedTime
                    if speedInMetersPerSecond > 0 {
                        let paceInMinutesPerKm = 1000.0 / (speedInMetersPerSecond * 60.0)
                        pace = Measurement(value: paceInMinutesPerKm, unit: .minutesPerKilometer)
                    }
                }
            }
        }
        
        locationList.append(location)
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .didUpdateWalkMetrics, object: nil)
    }

    // MARK: - WalkLog Generation
    
    func generateWalkLog() -> WalkLog? {
        guard state == .completed || state == .stopped else {
            print("⚠️ Cannot generate walk log - walk not completed")
            return nil
        }
        
        var walkLog = WalkLog()
        
        // Format values to match original schema
        let timeStr = formattedTime
        let paceStr = formattedPace
        
        // Format distance based on user preference
        let useMetric = UserDefaults.standard.bool(forKey: "useMetricUnits")
        let distanceFormatter = NumberFormatter()
        distanceFormatter.maximumFractionDigits = 2
        
        let distValue: String
        if useMetric {
            let distanceInKm = distance.converted(to: .kilometers)
            distValue = distanceFormatter.string(from: NSNumber(value: distanceInKm.value)) ?? "0.00"
            walkLog.distance = "\(distValue) km"
        } else {
            let distanceInMiles = distance.converted(to: .miles)
            distValue = distanceFormatter.string(from: NSNumber(value: distanceInMiles.value)) ?? "0.00"
            walkLog.distance = "\(distValue) mi"
        }
        
        // Format elevation
        let elevationFormatter = NumberFormatter()
        elevationFormatter.maximumFractionDigits = 0
        
        let elevationValue: String
        if useMetric {
            let elevationMeters = elevationGain.converted(to: .meters)
            elevationValue = elevationFormatter.string(from: NSNumber(value: elevationMeters.value)) ?? "0"
            walkLog.elevationGain = "\(elevationValue) m"
        } else {
            let elevationFt = elevationGain.converted(to: .feet)
            elevationValue = elevationFormatter.string(from: NSNumber(value: elevationFt.value)) ?? "0"
            walkLog.elevationGain = "\(elevationValue) ft"
        }
        
        // Populate walk log
        walkLog.id = workoutId.uuidString
        walkLog.duration = timeStr
        walkLog.avgPace = paceStr
        walkLog.caloriesBurned = round(calories)
        walkLog.elevationGain = elevationValue
        walkLog.createdAt = startTime
        // Note: createdBy is kept for backward compatibility but AWS uses userId in saveWalkToAWS
        
        // Format createdAt date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        walkLog.createdAtFormatted = dateFormatter.string(from: startTime)
        
        // Coordinate array is kept for backward compatibility but route data is stored in S3 via AWS
        // Route data is now stored in S3, coordinateArray is deprecated but kept for legacy compatibility
        walkLog.coordinateArray = nil // Route data stored in S3 via AWS, not Parse
        
        // Prepare location data array
        var locationDataArray: [[String: Any]] = []
        for location in locationList {
            var locData: [String: Any] = [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "altitude": location.altitude,
                "horizontalAccuracy": location.horizontalAccuracy,
                "verticalAccuracy": location.verticalAccuracy,
                "speed": location.speed,
                "course": location.course,
                "timestamp": location.timestamp.timeIntervalSince1970
            ]
            locationDataArray.append(locData)
        }
        walkLog.locationData = locationDataArray
        
        // Add metrics
        walkLog.avgHeartRate = heartRate > 0 ? heartRate : nil
        walkLog.avgCadence = cadence > 0 ? cadence : nil
        walkLog.steps = steps > 0 ? steps : nil
        walkLog.walkType = walkType.rawValue
        
        // Capture walkLog data before async call to avoid capturing struct in escaping closure
        let walkDistance = walkLog.distance ?? formattedDistance
        let walkSteps = walkLog.steps
        let walkAvgHeartRate = walkLog.avgHeartRate
        let walkId = walkLog.id
        
        // Save to AWS asynchronously
        // Note: walkLog.id is already set to workoutId.uuidString, so it has an ID
        // The AWS activityId will be stored in UserDefaults for future reference
        saveWalkToAWS(
            walkDistance: walkDistance,
            walkSteps: walkSteps,
            walkAvgHeartRate: walkAvgHeartRate,
            walkId: walkId
        ) { activityId in
            // Store the AWS activity ID in UserDefaults
            // The walkLog already has a UUID ID, and the AWS ID can be retrieved later if needed
            if let activityId = activityId {
                UserDefaults.standard.set(activityId, forKey: "lastSavedWalkId")
            }
        }
        
        return walkLog
    }
    
    // MARK: - AWS Persistence
    
    private func saveWalkToAWS(
        walkDistance: String,
        walkSteps: Int?,
        walkAvgHeartRate: Double?,
        walkId: String?,
        completion: @escaping (String?) -> Void
    ) {
        // Get user ID from various sources (prioritize currentUser, fallback to UserIDHelper)
        let userId: String? = currentUser ?? UserIDHelper.shared.getCurrentUserID()
        
        guard let userId = userId else {
            print("📱 💾 WALK SAVE: ❌ No current user")
            completion(nil)
            return
        }
        
        // Check idempotency - prevent duplicate saves
        if let lastSavedId = UserDefaults.standard.string(forKey: "lastSavedWalkId"),
           let walkId = walkId,
           lastSavedId == walkId {
            print("⚠️ Walk already saved, skipping duplicate save")
            completion(lastSavedId)
            return
        }
        
        // Convert locationList to route points format
        let routePoints: [[String: Any]] = locationList.map { location in
            [
                "timestamp": ISO8601DateFormatter().string(from: location.timestamp),
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "altitude": location.altitude,
                "horizontalAccuracy": location.horizontalAccuracy,
                "verticalAccuracy": location.verticalAccuracy,
                "speed": location.speed,
                "course": location.course
            ]
        }
        
        // Prepare start and end locations
        let startLoc: [String: Any]? = locationList.first.map {
            ["lat": $0.coordinate.latitude, "lon": $0.coordinate.longitude, "name": "Start"]
        }
        let endLoc: [String: Any]? = locationList.last.map {
            ["lat": $0.coordinate.latitude, "lon": $0.coordinate.longitude, "name": "End"]
        }
        
        // Prepare activity data
        var activityData: [String: Any] = [
            "walkType": walkType.rawValue,
            "formattedPace": formattedPace,
            "formattedDistance": walkDistance,
            "formattedTime": formattedTime
        ]
        
        // Include steps in activityData
        if let steps = walkSteps {
            activityData["steps"] = steps
        }
        
        // Calculate elevation loss if needed
        let elevationLossValue = elevationGain.value // For now, same as gain (can be calculated from location data)
        
        // Save to AWS
        ActivityService.shared.saveWalk(
            userId: userId,
            duration: elapsedTime,
            distance: distance.value, // Distance in meters
            calories: round(calories),
            steps: walkSteps,
            avgHeartRate: walkAvgHeartRate,
            maxHeartRate: nil, // WalkTrackingEngine doesn't track max heart rate separately
            elevationGain: elevationGain.value, // In meters
            elevationLoss: elevationLossValue, // In meters
            routePoints: routePoints,
            activityData: activityData,
            startLocation: startLoc,
            endLocation: endLoc,
            walkType: walkType.rawValue,
            isPublic: true,
            caption: nil
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let response):
                print("📱 💾 WALK SAVE: ✅ Walk saved to AWS successfully")
                print("📊 Saved with Distance: \(walkDistance)")
                print("📊 Saved with calories: \(round(self.calories))")
                print("📊 Saved with steps: \(walkSteps ?? 0)")
                print("📊 Saved with \(self.locationList.count) location data points")
                
                if let activityId = response.data?.activityId {
                    // Mark as saved to prevent duplicate saves
                    UserDefaults.standard.set(activityId, forKey: "lastSavedWalkId")
                    UserDefaults.standard.synchronize()
                    print("📊 Activity ID: \(activityId)")
                    completion(activityId)
                } else {
                    completion(nil)
                }
                
            case .failure(let error):
                print("📱 💾 WALK SAVE: ❌ Error saving walk to AWS: \(error.localizedDescription)")
                
                // Try again after delay with exponential backoff
                DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
                    self.saveWalkToAWS(
                        walkDistance: walkDistance,
                        walkSteps: walkSteps,
                        walkAvgHeartRate: walkAvgHeartRate,
                        walkId: walkId,
                        completion: completion
                    )
                }
            }
        }
        
        print("📱 💾 WALK SAVE: ✅ Walk save request sent to AWS")
    }

    // Unit helpers expected by UI
    func getElevationUnitString() -> String { return useMetric ? "m" : "ft" }
    func getPaceUnitString() -> String { return useMetric ? "min/km" : "min/mi" }
    
    // Get metrics as dictionary for watch communication
    func getMetrics() -> [String: Any] {
        return [
            "distance": distance.value,
            "elapsedTime": elapsedTime,
            "heartRate": heartRate,
            "calories": calories,
            "cadence": cadence,
            "elevationGain": elevationGain.value,
            "pace": pace.value,
            "steps": steps,
            "startTime": startTime.timeIntervalSince1970
        ]
    }
    
    // Update metrics from watch data
    func updateMetricsFromWatch(_ metrics: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Always accept heart rate from watch (watch is always primary for HR)
            if let heartRate = metrics["heartRate"] as? Double, heartRate > 0 {
                print("📱 Updating heart rate from watch: \(heartRate)")
                self.heartRate = heartRate
            }
            
            // Only accept other metrics if watch is primary for them
            if !self.isPrimaryForDistance, let distance = metrics["distance"] as? Double, distance > 0 {
                self.distance = Measurement(value: distance, unit: .meters)
            }
            
            if let elapsedTime = metrics["elapsedTime"] as? TimeInterval {
                self.elapsedTime = elapsedTime
            }
            
            if !self.isPrimaryForCalories, let calories = metrics["calories"] as? Double, calories > 0 {
                self.calories = calories
            }
            
            if !self.isPrimaryForCadence, let cadence = metrics["cadence"] as? Double, cadence > 0 {
                self.cadence = cadence
            }
            
            if let elevationGain = metrics["elevationGain"] as? Double {
                self.elevationGain = Measurement(value: elevationGain, unit: .meters)
            }
            
            if let pace = metrics["pace"] as? Double {
                self.pace = Measurement(value: pace, unit: self.useMetric ? .minutesPerKilometer : .minutesPerMile)
            }
            
            if let startTimeInterval = metrics["startTime"] as? TimeInterval {
                self.startTime = Date(timeIntervalSince1970: startTimeInterval)
            }
            
            if let steps = metrics["steps"] as? Int {
                self.steps = steps
            }
            
            // Update formatted values
            self.updateFormattedValues()
            
            // Notify listeners
            NotificationCenter.default.post(name: .didUpdateWalkMetrics, object: nil)
        }
    }

    // MARK: - Watch Connectivity (copied/adapted from Run)
    /// Push current walking tracking status to the watch using updateApplicationContext (last-wins, reliable).
    /// Falls back to transferUserInfo if context update fails. Ensures main-thread execution.
    public func updateApplicationContext() {
        // Skip sends while processing a remote state change to avoid feedback loops
        if isHandlingRemoteStateChange {
            print("📱 🎯 [Walk] Skipping updateApplicationContext - handling remote state change")
            return
        }

        // Ensure we're on main thread for WCSession interactions
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.updateApplicationContext()
            }
            return
        }

        let session = WCSession.default
        // Rate-limit connectivity checks
        let now = Date().timeIntervalSince1970
        if now - lastWatchConnectivityCheck < watchConnectivityCheckInterval {
            // continue without extra logging
        } else {
            lastWatchConnectivityCheck = now
            print("[WalkComm] updateApplicationContext: activationState=\(session.activationState.rawValue), isPaired=\(session.isPaired), isWatchAppInstalled=\(session.isWatchAppInstalled), isReachable=\(session.isReachable)")
        }

        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else {
            print("[WalkComm] Not updating application context (session not ready)")
            return
        }

        // Build context payload
        var contextData: [String: Any] = [
            "type": "trackingStatus",
            "workoutType": "walk",
            "timestamp": Date().timeIntervalSince1970,
            "workoutId": workoutId.uuidString,
            "useImperialUnits": useImperialUnits()
        ]

        // State
        let stateRaw = state.rawValue
        contextData["state"] = stateRaw
        contextData["walkState"] = stateRaw
        contextData["workoutActive"] = state.isActive
        contextData["watchTracking"] = isWatchTracking
        contextData["isIndoor"] = isIndoorMode

        // Metrics (nested for parity with running)
        contextData["metrics"] = getMetrics()

        // Timeout guard similar to Run (simple variant)
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            print("[WalkComm] ⚠️ updateApplicationContext took too long; consider reducing send frequency")
            self?.handleWatchCommunicationError()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: timeoutWorkItem)

        do {
            try session.updateApplicationContext(contextData)
            timeoutWorkItem.cancel()
        } catch {
            timeoutWorkItem.cancel()
            // Fallback – queue in background
            session.transferUserInfo(contextData)
            print("[WalkComm] updateApplicationContext failed; queued via transferUserInfo: \(error.localizedDescription)")
            handleWatchCommunicationError(error)
        }
    }

    private func startTiming() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsedTime += 1
            self.updateFormattedValues()
            self.updateLockScreen()
            NotificationCenter.default.post(name: .didUpdateWalkMetrics, object: nil)
        }
    }

    // MARK: - Formatting
    private func updateFormattedValues() {
        // Get user preference
        useMetric = UserDefaults.standard.bool(forKey: "useMetricUnits")
        
        // Distance
        let meters = distance.converted(to: .meters).value
        if useMetric {
            formattedDistance = String(format: "%.2f km", meters / 1000)
            let paceSec = max(0.0, pace.converted(to: .minutesPerKilometer).value)
            formattedPace = WalkTrackingEngine.formatPaceMinutes(paceSec)
            pace = Measurement(value: paceSec, unit: .minutesPerKilometer)
        } else {
            formattedDistance = String(format: "%.2f mi", meters / 1609.34)
            let paceMiles = pace.converted(to: .minutesPerMile).value
            formattedPace = WalkTrackingEngine.formatPaceMinutes(paceMiles)
            pace = Measurement(value: paceMiles, unit: .minutesPerMile)
        }

        // Time
        formattedTime = WalkTrackingEngine.formatTime(Int(elapsedTime))
        
        // Steps
        formattedSteps = formatSteps(steps)
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .didUpdateWalkMetrics, object: nil)
    }
    
    /// Format steps count for display
    private func formatSteps(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: count)) ?? "0"
    }

    static func formatPaceMinutes(_ minutesPerUnit: Double) -> String {
        guard minutesPerUnit > 0 && minutesPerUnit.isFinite else { return "-'--\"" }
        let minutes = Int(minutesPerUnit)
        let seconds = Int((minutesPerUnit - Double(minutes)) * 60)
        return String(format: "%d'%02d\"", minutes, seconds)
    }

    static func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    // MARK: - Watch Communication
    private func setupWatchCommunication() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Control messaging helpers
    private func sendControlToWatch(type: String) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let payload: [String: Any] = [
            "type": type,
            "workoutType": "walk",
            "timestamp": Date().timeIntervalSince1970,
            "state": state.rawValue,
            "walkState": state.rawValue,
            "workoutId": workoutId.uuidString
        ]
        session.sendMessage(payload, replyHandler: nil, errorHandler: { [weak self] error in
            self?.handleWatchCommunicationError(error)
        })
    }

    /// Ask the watch if there's an active walking workout and join it
    public func requestActiveWorkoutFromWatch() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let request: [String: Any] = [
            "type": "requestActiveWalkingWorkout",
            "timestamp": Date().timeIntervalSince1970
        ]
        session.sendMessage(request, replyHandler: { [weak self] response in
            guard let self = self else { return }
            DispatchQueue.main.async {
                // Expect: type=activeWalkingWorkoutResponse, metrics, state, walkState
                if let stateString = (response["walkState"] as? String) ?? (response["state"] as? String),
                   let newState = WalkState(rawValue: stateString) {
                    self.state = newState
                }
                if let metrics = response["metrics"] as? [String: Any] {
                    self.updateMetricsFromWatch(metrics)
                }
                if let idStr = response["workoutId"] as? String, let uuid = UUID(uuidString: idStr) {
                    self.workoutId = uuid
                }
                // Mark that watch is the tracking source when joining
                self.isWatchTracking = true
                // Ensure timer running if in progress
                if self.state == .inProgress { self.ensureTimerIsRunning() }
                // Update UI/application context
                self.updateApplicationContext()
            }
        }, errorHandler: { [weak self] error in
            self?.handleWatchCommunicationError(error)
        })
    }

    // Receive message without reply
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle updates pushed from watch without requiring a response
        // Always accept heart rate from watch
        if let heartRate = message["heartRate"] as? Double, heartRate > 0 {
            print("📱 Updating heart rate from watch: \(heartRate)")
            updateHeartRate(heartRate)
        }
        // Only accept other metrics if watch is primary
        if !isPrimaryForDistance, let distance = message["distance"] as? Double, distance > 0 {
            updateDistanceFromWatch(distance)
        }
        if !isPrimaryForCalories, let calories = message["calories"] as? Double, calories > 0 {
            updateCalories(calories)
        }
        if !isPrimaryForCadence, let cadence = message["cadence"] as? Double, cadence > 0 {
            updateCadence(cadence)
        }
    }

    // Receive message with reply
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        let messageType = message["type"] as? String ?? ""

        // Specialized fast path: reply with full active workout info if requested
        if messageType == "requestActiveWalkingWorkout" ||
           (messageType == "requestActiveWorkout" && (message["workoutType"] as? String)?.lowercased() == "walk") {
            let response = self.createActiveWalkingWorkoutResponse()
            replyHandler(response)
            return
        }

        // Default immediate acknowledgment for other messages
        let immediateAck: [String: Any] = [
            "status": "received",
            "timestamp": Date().timeIntervalSince1970,
            "hasActiveWorkout": state.isActive
        ]
        replyHandler(immediateAck)

        // Process the message on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.processWatchMessage(message)
        }
    }
    
    // Process watch messages
    private func processWatchMessage(_ message: [String: Any]) {
        // Ensure UI updates happen on main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.processWatchMessage(message)
            }
            return
        }
        
        let messageType = message["type"] as? String ?? ""
        print("📱 Processing watch message type: \(messageType)")
        
        switch messageType {
        case "workoutUpdate", "walkStateChange":  // Support both types for compatibility
            if let newState = message["state"] as? String,
               let walkState = WalkState(rawValue: newState) {
                isHandlingRemoteStateChange = true
                self.state = walkState
                isHandlingRemoteStateChange = false
                
                // Acknowledge state change
                syncWithWatch()
            }
            
        case "syncWorkoutData":
            if let metrics = message["metrics"] as? [String: Any] {
                // Always accept heart rate from watch (watch is always primary for HR)
                if let heartRate = metrics["heartRate"] as? Double, heartRate > 0 {
                    print("📱 Updating heart rate from watch: \(heartRate)")
                    self.heartRate = heartRate
                }
                
                // Only accept other metrics if watch is primary for them
                if !self.isPrimaryForDistance, let distance = metrics["distance"] as? Double, distance > 0 {
                    self.distance = Measurement(value: distance, unit: .meters)
                }
                if let elapsedTime = metrics["elapsedTime"] as? TimeInterval {
                    self.elapsedTime = elapsedTime
                }
                if !self.isPrimaryForCalories, let calories = metrics["calories"] as? Double, calories > 0 {
                    self.calories = calories
                }
                if !self.isPrimaryForCadence, let cadence = metrics["cadence"] as? Double, cadence > 0 {
                    self.cadence = cadence
                }
                if let elevationGain = metrics["elevationGain"] as? Double {
                    self.elevationGain = Measurement(value: elevationGain, unit: .meters)
                }
                if let steps = metrics["steps"] as? Int {
                    self.steps = steps
                }
                
                // Update formatted values after receiving new metrics
                self.updateFormattedValues()
                NotificationCenter.default.post(name: .didUpdateWalkMetrics, object: nil)
            }
        case "syncWalkingWorkoutData":
            // New walking-specific sync payload
            if let metrics = message["metrics"] as? [String: Any] {
                self.updateMetricsFromWatch(metrics)
            } else {
                // Fallback to top-level keys
                if let distance = message["distance"] as? Double {
                    self.distance = Measurement(value: distance, unit: .meters)
                }
                if let elapsed = message["elapsedTime"] as? TimeInterval {
                    self.elapsedTime = elapsed
                }
                // Always accept heart rate from watch
                if let hr = message["heartRate"] as? Double, hr > 0 {
                    print("📱 Updating heart rate from watch: \(hr)")
                    self.heartRate = hr
                }
                // Only accept other metrics if watch is primary
                if !self.isPrimaryForCalories, let kcal = message["calories"] as? Double, kcal > 0 {
                    self.calories = kcal
                }
                if !self.isPrimaryForCadence, let cad = message["cadence"] as? Double, cad > 0 {
                    self.cadence = cad
                }
                if let elev = message["elevationGain"] as? Double {
                    self.elevationGain = Measurement(value: elev, unit: .meters)
                }
                if let steps = message["steps"] as? Int {
                    self.steps = steps
                }
                self.updateFormattedValues()
                NotificationCenter.default.post(name: .didUpdateWalkMetrics, object: nil)
            }
            
        case "requestActiveWalkWorkout":
            // Backward compatibility: on legacy key, push an update
            if state.isActive { self.syncWithWatch() }
        
        default:
            print("📱 Unhandled message type: \(messageType)")
        }
    }

    // Build a detailed active workout response for the watch
    private func createActiveWalkingWorkoutResponse() -> [String: Any] {
        var base: [String: Any] = [
            "type": "activeWalkingWorkoutResponse",
            "workoutType": "walk",
            "timestamp": Date().timeIntervalSince1970,
            "useImperialUnits": useImperialUnits(),
            "workoutId": workoutId.uuidString,
        ]
        if state.isActive {
            base["hasActiveWorkout"] = true
            base["state"] = state.rawValue
            base["walkState"] = state.rawValue
            base["isIndoor"] = isIndoorMode
            // Include nested metrics (includes startTime)
            base["metrics"] = getMetrics()
            // Also mirror top-level convenience keys commonly read by watch handlers
            base["distance"] = distance.value
            base["elapsedTime"] = elapsedTime
            base["heartRate"] = heartRate
            base["calories"] = calories
            base["cadence"] = cadence
            base["steps"] = steps
            base["elevationGain"] = elevationGain.value
            base["pace"] = pace.value
        } else {
            base["hasActiveWorkout"] = false
            base["state"] = WalkState.notStarted.rawValue
            base["walkState"] = WalkState.notStarted.rawValue
        }
        return base
    }
    
    // Sync with watch
    private func syncWithWatch() {
        guard WCSession.isSupported() else { return }
        
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        
        // Don't send updates during remote state changes
        if isHandlingRemoteStateChange {
            print("📱 Skipping syncWithWatch - handling remote state change")
            return
        }
        
        // Rate limit updates to every 2 seconds
        let currentTime = Date().timeIntervalSince1970
        if currentTime - lastWatchSyncTime < 2.0 { return }
        lastWatchSyncTime = currentTime
        
        // Prepare metrics to send
        let metricsToSend: [String: Any] = [
            "distance": distance.value,
            "elapsedTime": elapsedTime,
            "heartRate": heartRate,
            "calories": calories,
            "cadence": cadence,
            "elevationGain": elevationGain.value,
            "pace": pace.value,
            "steps": steps
        ]
        
        let updateData: [String: Any] = [
            "type": "walkWorkoutUpdate",  // Unique identifier for walking workouts
            "workoutType": "walk",    // Identify as walk workout
            "walkType": walkingType.rawValue,  // Walking-specific type
            "state": state.rawValue,  // State key
            "walkState": state.rawValue,  // Walking-specific state key
            "metrics": metricsToSend,
            "isIndoor": isIndoorMode,
            "isWatchTracking": isWatchTracking,
            "hasGoodLocationData": hasGoodLocationData,
            "isPrimaryForDistance": isPrimaryForDistance,
            "isPrimaryForPace": isPrimaryForPace,
            "isPrimaryForHeartRate": isPrimaryForHeartRate,
            "isPrimaryForCalories": isPrimaryForCalories,
            "isPrimaryForCadence": isPrimaryForCadence,
            "isDashboardMode": isDashboardMode,
            "timestamp": currentTime,
            "workoutId": workoutId.uuidString,  // Include unique workout ID for better identification
            "useImperialUnits": useImperialUnits()
        ]
        
        // Send with error handling
        session.sendMessage(updateData, replyHandler: { [weak self] response in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Reset error count on successful send
                self.watchCommErrorCount = 0
                
                if let watchIsTracking = response["isWatchTracking"] as? Bool {
                    self.isWatchTracking = watchIsTracking
                }
            }
        }, errorHandler: { [weak self] error in
            DispatchQueue.main.async {
                self?.handleWatchCommunicationError(error)
            }
        })
    }

    // MARK: - WCSessionDelegate Required Methods
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("📱 WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("📱 WCSession activated successfully with state: \(activationState.rawValue)")
            // Try to join any active walking workout on the watch
            requestActiveWorkoutFromWatch()
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("📱 WCSession deactivated")
        // Reactivate for future use
        WCSession.default.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("📱 WCSession reachability changed: \(session.isReachable)")
        if session.isReachable {
            // Attempt to join if watch has an active walk
            requestActiveWorkoutFromWatch()
        }
    }
    
    // MARK: - Step Counting
    
    /// Request HealthKit authorization for step count
    private func requestHealthKitAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("⚠️ HealthKit not available on this device")
            return
        }
        
        // Types to read from HealthKit
        var typesToRead: Set<HKObjectType> = []
        
        // Step count for walking tracking
        if let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            typesToRead.insert(stepCountType)
        }
        
        // Heart rate for monitoring
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            typesToRead.insert(heartRateType)
        }
        
        // Distance for tracking
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            typesToRead.insert(distanceType)
        }
        
        // Body mass for calorie calculations
        if let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            typesToRead.insert(bodyMassType)
        }
        
        // Types to write to HealthKit (workouts, calories, distance)
        var typesToShare: Set<HKSampleType> = []
        
        // Workout type
        typesToShare.insert(HKObjectType.workoutType())
        
        // Active energy burned
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            typesToShare.insert(energyType)
        }
        
        // Distance
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            typesToShare.insert(distanceType)
        }
        
        // Request authorization for all types
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ HealthKit authorization granted for walking tracking")
                    print("   - Read: steps, heart rate, distance, body mass")
                    print("   - Write: workouts, calories, distance")
                } else if let error = error {
                    print("❌ HealthKit authorization failed: \(error.localizedDescription)")
                } else {
                    print("⚠️ HealthKit authorization denied")
                }
            }
        }
    }
    
    /// Get baseline step count at workout start
    private func getBaselineSteps(completion: @escaping (Int) -> Void) {
        guard HKHealthStore.isHealthDataAvailable(),
              let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(0)
            return
        }
        
        // Get steps up to workout start time
        let predicate = HKQuery.predicateForSamples(
            withStart: Date.distantPast,
            end: startTime,
            options: .strictEndDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: stepCountType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, statistics, error in
            DispatchQueue.main.async {
                guard let statistics = statistics, error == nil else {
                    print("⚠️ Error fetching baseline steps: \(error?.localizedDescription ?? "unknown")")
                    completion(0)
                    return
                }
                
                if let quantity = statistics.sumQuantity() {
                    let steps = Int(quantity.doubleValue(for: HKUnit.count()))
                    completion(steps)
                } else {
                    completion(0)
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    /// Start step counting with HealthKit observer query
    private func startStepCounting() {
        guard HKHealthStore.isHealthDataAvailable(),
              let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            print("⚠️ HealthKit step counting not available")
            return
        }
        
        // Request authorization if needed
        requestHealthKitAuthorization()
        
        // Get baseline steps
        getBaselineSteps { [weak self] baseline in
            guard let self = self else { return }
            self.workoutStartSteps = baseline
            self.steps = 0 // Reset to 0 at workout start
            print("🚶‍♂️ Step counting started. Baseline: \(baseline) steps")
        }
        
        // Create observer query for real-time step updates
        let predicate = HKQuery.predicateForSamples(
            withStart: startTime,
            end: nil,
            options: .strictStartDate
        )
        
        stepQuery = HKObserverQuery(sampleType: stepCountType, predicate: predicate) { [weak self] query, completionHandler, error in
            guard let self = self else {
                completionHandler()
                return
            }
            
            if let error = error {
                print("❌ Step observer query error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            // Fetch current step count since workout start
            self.fetchStepsSinceStart { stepCount in
                DispatchQueue.main.async {
                    self.steps = stepCount
                    print("🚶‍♂️ Steps updated: \(stepCount)")
                    NotificationCenter.default.post(name: .didUpdateWalkMetrics, object: nil)
                    self.updateLockScreen()
                }
                completionHandler()
            }
        }
        
        if let query = stepQuery {
            healthStore.execute(query)
            // Enable background delivery
            healthStore.enableBackgroundDelivery(for: stepCountType, frequency: .immediate) { success, error in
                if success {
                    print("✅ Background step count delivery enabled")
                } else if let error = error {
                    print("⚠️ Failed to enable background delivery: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Fetch steps since workout start
    private func fetchStepsSinceStart(completion: @escaping (Int) -> Void) {
        guard HKHealthStore.isHealthDataAvailable(),
              let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(0)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startTime,
            end: Date(),
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: stepCountType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, statistics, error in
            guard let statistics = statistics, error == nil else {
                completion(0)
                return
            }
            
            if let quantity = statistics.sumQuantity() {
                let totalSteps = Int(quantity.doubleValue(for: HKUnit.count()))
                // Subtract baseline to get steps during workout
                let workoutSteps = max(0, totalSteps - self.workoutStartSteps)
                completion(workoutSteps)
            } else {
                completion(0)
            }
        }
        
        healthStore.execute(query)
    }
    
    /// Stop step counting
    private func stopStepCounting() {
        if let query = stepQuery {
            healthStore.stop(query)
            stepQuery = nil
        }
        
        // Final step count fetch
        fetchStepsSinceStart { [weak self] finalSteps in
            DispatchQueue.main.async {
                self?.steps = finalSteps
                print("🚶‍♂️ Final step count: \(finalSteps)")
            }
        }
    }
    
    // Receive application context
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("📱 Received application context keys: \(applicationContext.keys.joined(separator: ", "))")

        // Update tracking flags if provided (support legacy keys)
        if let isTracking = applicationContext["isTracking"] as? Bool {
            isWatchTracking = isTracking
        }
        if let watchTracking = applicationContext["watchTracking"] as? Bool {
            isWatchTracking = watchTracking
        }

        // If walking payload, consume state and metrics
        let type = applicationContext["type"] as? String ?? ""
        let isWalkingPayload = type.contains("walk") || applicationContext["workoutType"] as? String == "walk"

        if isWalkingPayload || type == "trackingStatus" || type == "syncWalkingWorkoutData" {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                // State handling (support multiple keys)
                if let stateString = applicationContext["walkState"] as? String,
                   let newState = WalkState(rawValue: stateString) {
                    self.state = newState
                } else if let stateString = applicationContext["state"] as? String,
                          let newState = WalkState(rawValue: stateString) {
                    self.state = newState
                }

                // Metrics nested dict
                if let metrics = applicationContext["metrics"] as? [String: Any] {
                    self.updateMetricsFromWatch(metrics)
                }

                // Top-level fallbacks
                if let distance = applicationContext["distance"] as? Double {
                    self.distance = Measurement(value: distance, unit: .meters)
                }
                if let elapsed = applicationContext["elapsedTime"] as? TimeInterval {
                    self.elapsedTime = elapsed
                }
                // Always accept heart rate from watch
                if let hr = applicationContext["heartRate"] as? Double, hr > 0 {
                    print("📱 Updating heart rate from watch: \(hr)")
                    self.heartRate = hr
                }
                // Only accept other metrics if watch is primary
                if !self.isPrimaryForCalories, let kcal = applicationContext["calories"] as? Double, kcal > 0 {
                    self.calories = kcal
                }
                if !self.isPrimaryForCadence, let cad = applicationContext["cadence"] as? Double, cad > 0 {
                    self.cadence = cad
                }
                if let elev = applicationContext["elevationGain"] as? Double {
                    self.elevationGain = Measurement(value: elev, unit: .meters)
                }
                if let steps = applicationContext["steps"] as? Int {
                    self.steps = steps
                }

                // Refresh formatted strings/UI
                self.updateFormattedValues()
                NotificationCenter.default.post(name: .didUpdateWalkMetrics, object: nil)
            }
        } else if let type = applicationContext["type"] as? String,
                  (type == "workoutUpdate" || type == "walkWorkoutState"),
                  let stateString = applicationContext["state"] as? String,
                  let newState = WalkState(rawValue: stateString) {
            DispatchQueue.main.async { self.state = newState }
        }
    }
    
    // MARK: - Device Coordination
    
    // Establish initial device coordination roles
    private func establishDeviceCoordination() {
        guard state != .notStarted && state != .completed else { return }
        
        let isIndoor = isIndoorMode || walkingType == .treadmillWalk
        
        if isIndoor {
            // For indoor walks, watch takes precedence for all metrics
            isDashboardMode = true
            isWatchTracking = true
            
            // Set watch as primary for all metrics
            isPrimaryForDistance = false
            isPrimaryForPace = false
            isPrimaryForHeartRate = false
            isPrimaryForCalories = false
            isPrimaryForCadence = false
            
            print("📱 Indoor walk: Phone acting as dashboard")
            print("⌚️ Watch will be primary for all tracking metrics")
        } else {
            // For outdoor walks, determine based on GPS quality
            isDashboardMode = false
            
            // Check if we have good GPS data
            if hasGoodLocationData {
                // Phone is primary for GPS-based metrics
                isPrimaryForDistance = true
                isPrimaryForPace = true
                isPrimaryForHeartRate = false // Watch still better for HR
                isPrimaryForCalories = true   // Phone can calculate calories with distance
                isPrimaryForCadence = false   // Watch better for cadence
                
                print("📱 Outdoor walk with good GPS: Phone primary for distance/pace")
                print("⌚️ Watch primary for heart rate and cadence")
            } else {
                // Poor GPS quality, let watch take more metrics
                isPrimaryForDistance = false
                isPrimaryForPace = false
                isPrimaryForHeartRate = false
                isPrimaryForCalories = false
                isPrimaryForCadence = false
                isWatchTracking = true
                
                print("📱 Outdoor walk with poor GPS: Deferring to watch for metrics")
            }
        }
        
        // Update application context to let watch know current state
        updateApplicationContext()
        
        // Send immediate update to watch
        syncWithWatch()
    }
}

// MARK: - Watch Handoff and Multi-Device Support

extension WalkTrackingEngine {
    
    /// Initiate handoff to watch
    func initiateHandoffToWatch(completion: @escaping (Bool) -> Void) {
        guard state != .notStarted else {
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
            workoutType: .walking,
            workoutId: workoutId.uuidString,
            metrics: metrics,
            state: convertWalkStateToWorkoutState(state),
            startDate: startTime
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
                print("❌ [WalkTrackingEngine] Handoff failed: \(error.localizedDescription)")
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
        
        if state != .notStarted {
            handleHandoffConflict(phoneState: convertWalkStateToWorkoutState(state),
                                watchWorkout: handoffMessage)
            return
        }
        
        workoutId = UUID(uuidString: handoffMessage.workoutId) ?? UUID()
        startTime = handoffMessage.startDate
        
        distance = Measurement(value: handoffMessage.metrics.distance, unit: UnitLength.meters)
        elapsedTime = handoffMessage.metrics.elapsedTime
        heartRate = handoffMessage.metrics.heartRate
        pace = Measurement(value: handoffMessage.metrics.pace, unit: UnitSpeed.metersPerSecond)
        calories = handoffMessage.metrics.calories
        cadence = handoffMessage.metrics.cadence ?? 0
        
        state = convertWorkoutStateToWalkState(handoffMessage.state)
        
        if let session = WCSession.default as? WCSession, session.isReachable {
            session.sendMessage([
                "type": "handoffResponse",
                "accepted": true,
                "workoutId": workoutId.uuidString
            ], replyHandler: { response in
                print("📱 Watch acknowledged handoff response: \(response)")
            }, errorHandler: { error in
                print("📱 Error sending handoff response: \(error.localizedDescription)")
            })
        }
    }
    
    private func handleHandoffConflict(phoneState: WorkoutState, watchWorkout: WorkoutHandoffMessage) {
        workoutId = UUID(uuidString: watchWorkout.workoutId) ?? UUID()
        startTime = watchWorkout.startDate
        
        heartRate = watchWorkout.metrics.heartRate
        cadence = watchWorkout.metrics.cadence ?? cadence
        calories = max(calories, watchWorkout.metrics.calories)
        elapsedTime = max(elapsedTime, watchWorkout.metrics.elapsedTime)
        
        state = convertWorkoutStateToWalkState(watchWorkout.state)
    }
    
    // MARK: - Multi-Device Support
    
    func integrateWithExternalDevices() {
        let aggregator = MultiDeviceDataAggregator.shared
        var cancellables = Set<AnyCancellable>()
        
        aggregator.$aggregatedMetrics
            .sink { [weak self] metrics in
                self?.updateMetricsFromExternalDevices(metrics)
            }
            .store(in: &cancellables)
    }
    
    private func updateMetricsFromExternalDevices(_ metrics: WorkoutMetrics) {
        let coordinationEngine = DeviceCoordinationEngine.shared
        let isIndoor = walkingType == .treadmillWalk
        
        if let source = coordinationEngine.selectBestDataSource(
            for: .heartRate,
            workoutType: .walking,
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
        guard state != .notStarted else { return }
        
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
            workoutType: .walking
        )
    }
    
    // MARK: - State Conversion Helpers
    
    private func convertWalkStateToWorkoutState(_ walkState: WalkState) -> WorkoutState {
        switch walkState {
        case .notStarted, .preparing, .ready: return .idle
        case .inProgress: return .running
        case .paused: return .paused
        case .completed, .stopped, .error: return .stopped
        }
    }
    
    private func convertWorkoutStateToWalkState(_ workoutState: WorkoutState) -> WalkState {
        switch workoutState {
        case .idle: return .notStarted
        case .starting, .running: return .inProgress
        case .paused: return .paused
        case .stopping, .stopped, .completed: return .stopped
        }
    }
    
    // MARK: - Enhanced Watch Sync
    
    func enhancedSyncWithWatch() {
        syncWithWatch()
        
        WorkoutStateSync.shared.syncState(
            workoutId: workoutId.uuidString,
            workoutType: .walking,
            state: convertWalkStateToWorkoutState(state)
        )
    }
    
    // MARK: - Handoff Data Provider
    
    func getHandoffData() -> [String: Any]? {
        guard state != .notStarted else { return nil }
        
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
            workoutType: .walking,
            workoutId: workoutId.uuidString,
            metrics: metrics,
            state: convertWalkStateToWorkoutState(state),
            startDate: startTime
        )
        
        return handoffMessage.toDictionary()
    }
}



