//
//  SportsTrackingEngine.swift
//  Do.
//
//  Created by Mikiyas Meseret on 3/26/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import CoreLocation
import HealthKit
import Combine
import WatchConnectivity
import UIKit
import MapKit

// MARK: - Sports Tracking State
enum SportsTrackingState: String {
    case notStarted = "notStarted"
    case starting = "starting"
    case active = "active"
    case paused = "paused"
    case ended = "ended"
}

// MARK: - Location Data Structure
struct SportsLocationData: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let speed: Double
    let course: Double
    let timestamp: Date
    let heartRate: Double?
    let cadence: Double?
    
    init(from location: CLLocation, heartRate: Double? = nil, cadence: Double? = nil) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
        self.speed = location.speed
        self.course = location.course
        self.timestamp = location.timestamp
        self.heartRate = heartRate
        self.cadence = cadence
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude,
            "altitude": altitude,
            "horizontalAccuracy": horizontalAccuracy,
            "verticalAccuracy": verticalAccuracy,
            "speed": speed,
            "course": course,
            "timestamp": timestamp.timeIntervalSince1970,
        ]
        if let hr = heartRate {
            dict["heartRate"] = hr
        }
        if let cad = cadence {
            dict["cadence"] = cad
        }
        return dict
    }
}

// MARK: - Sports Log Structure
struct SportsLog: Codable, Identifiable {
    var id: String?
    var sportType: String
    var duration: String?
    var distance: String?
    var caloriesBurned: Double?
    var locationData: [SportsLocationData]?
    var startDate: Date?
    var endDate: Date?
    var createdAt: Date?
    var heartRate: Double?
    var avgHeartRate: Double?
    var maxHeartRate: Double?
    var elevationGain: String?
    var elevationLoss: String?
    var netElevation: String?
    
    init() {
        self.sportType = "other"
    }
}

// MARK: - Sports Tracking Engine
// Minimum iOS target: 16.0
class SportsTrackingEngine: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = SportsTrackingEngine()
    
    // MARK: - Published Properties
    @Published var state: SportsTrackingState = .notStarted
    @Published var sportType: SportType = .basketball
    @Published var isTracking = false
    @Published var isPaused = false
    @Published var isWatchTracking = false
    @Published var currentUser: UserModel?
    
    // Device coordination properties
    @Published var isIndoorMode: Bool = false
    @Published var hasGoodLocationData: Bool = true
    @Published var isPrimaryForDistance: Bool = true
    @Published var isPrimaryForPace: Bool = true
    @Published var isPrimaryForHeartRate: Bool = false // Watch is always primary for HR
    @Published var isPrimaryForCalories: Bool = true
    @Published var isPrimaryForCadence: Bool = false // Watch is better for cadence
    @Published var isDashboardMode: Bool = false
    
    // Tracking Metrics
    @Published var distance: Measurement<UnitLength> = Measurement(value: 0, unit: .meters)
    @Published var elapsedTime: TimeInterval = 0
    @Published var calories: Double = 0
    @Published var heartRate: Double = 0
    @Published var avgHeartRate: Double = 0
    @Published var maxHeartRate: Double = 0
    @Published var elevationGain: Measurement<UnitLength> = Measurement(value: 0, unit: .meters)
    @Published var elevationLoss: Measurement<UnitLength> = Measurement(value: 0, unit: .meters)
    
    // Location tracking
    @Published var locationList: [SportsLocationData] = []
    private var locationManager: CLLocationManager?
    private var lastLocation: CLLocation?
    
    // Formatted values
    @Published var formattedDistance: String = "0.00"
    @Published var formattedTime: String = "00:00:00"
    @Published var formattedCalories: String = "0"
    @Published var formattedHeartRate: String = "--"
    @Published var distanceUnit: String = "km"
    
    // HealthKit - iOS 16.0 compatible
    private let healthStore = HKHealthStore()
    private var workoutBuilder: HKWorkoutBuilder?
    
    // Timer
    private var timer: Timer?
    private var startDate: Date?
    private var pausedTime: TimeInterval = 0
    private var totalPausedDuration: TimeInterval = 0
    private var cancellables = Set<AnyCancellable>()
    internal var workoutId = UUID()
    
    // Sports log
    private var currentSportsLog: SportsLog = SportsLog()
    
    // Retry management
    private var saveRetryCount: Int = 0
    private let maxRetryAttempts: Int = 5
    private let retryDelay: TimeInterval = 2.0
    
    // Backup storage key
    private struct BackupKeys {
        static let pendingSportsSession = "pendingSportsSession"
        static let currentTrackingData = "currentTrackingData"
    }
    
    private override init() {
        super.init()
        setupLocationManager()
        setupWatchConnectivity()
        setupHealthKit()
    }
    
    // MARK: - Setup Methods
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = 5.0 // Update every 5 meters
        // CRITICAL: Don't set allowsBackgroundLocationUpdates here - it can only be set
        // when authorized and during active tracking. Set it in startTracking() instead.
        locationManager?.pausesLocationUpdatesAutomatically = false
    }
    
    /// Safely enable background location updates
    /// This can only be set when authorized with "Always" permission and the app has the capability
    /// Note: This will only work if the app has "Location updates" background mode in Info.plist
    /// IMPORTANT: If the app crashes here, ensure "Location updates" is in UIBackgroundModes in Info.plist
    private func enableBackgroundLocationUpdates() {
        guard let locationManager = locationManager else { return }
        
        let authStatus = CLLocationManager.authorizationStatus()
        guard authStatus == .authorizedAlways else {
            // Only works with "Always" authorization
            return
        }
        
        // Check if background refresh is available
        guard UIApplication.shared.backgroundRefreshStatus == .available else {
            print("⚠️ [SportsTrackingEngine] Background refresh not available - skipping background location updates")
            return
        }
        
        // Only set if we're actively tracking (state is active or starting)
        guard state == .active || state == .starting else {
            return
        }
        
        // Attempt to enable background location updates
        // IMPORTANT: This requires "Location updates" in UIBackgroundModes in Info.plist
        // If the capability is missing, this will cause an assertion failure
        // The app must have this capability configured in the Xcode project settings
        // Only set when we have "Always" authorization and are actively tracking
        if authStatus == .authorizedAlways {
            // Set background location updates only when properly authorized
            // This must be set AFTER authorization and BEFORE starting location updates
            locationManager.allowsBackgroundLocationUpdates = true
        }
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    private func setupHealthKit() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if let error = error {
                print("HealthKit authorization error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Public Methods
    
    func setCurrentUser() {
        // Get user ID from Cognito
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            print("❌ No user ID for setting current user")
            return
        }
        
        Task {
            do {
                // Fetch user profile from AWS
                let userModel = try await UserProfileService.shared.fetchUserProfile(userId: userId)
                
                await MainActor.run {
                    self.currentUser = userModel
                }
            } catch {
                print("❌ Error fetching user profile: \(error.localizedDescription)")
                // Create a minimal UserModel with just the userId
                await MainActor.run {
                    var minimalUser = UserModel()
                    minimalUser.userID = userId
                    self.currentUser = minimalUser
                }
            }
        }
    }
    
    func startTracking(sportType: SportType) async {
        guard state == .notStarted else { return }
        
        await MainActor.run {
            self.state = .starting
            self.sportType = sportType
            self.startDate = Date()
            self.currentSportsLog = SportsLog()
            self.currentSportsLog.sportType = sportType.rawValue
            self.currentSportsLog.startDate = self.startDate
            
            // Reset metrics
            self.distance = Measurement(value: 0, unit: .meters)
            self.elapsedTime = 0
            self.calories = 0
            self.heartRate = 0
            self.avgHeartRate = 0
            self.maxHeartRate = 0
            self.elevationGain = Measurement(value: 0, unit: .meters)
            self.elevationLoss = Measurement(value: 0, unit: .meters)
            self.locationList = []
            self.lastLocation = nil
            self.totalPausedDuration = 0
            self.pausedTime = 0
            
            // Request location permissions
            self.locationManager?.requestAlwaysAuthorization()
            
            // Start location updates
            let authStatus = CLLocationManager.authorizationStatus()
            if authStatus == .authorizedAlways || authStatus == .authorizedWhenInUse {
                // CRITICAL: Only set allowsBackgroundLocationUpdates when authorized and tracking
                // This must be set AFTER authorization and BEFORE starting location updates
                if authStatus == .authorizedAlways {
                    // Safely enable background location updates
                    enableBackgroundLocationUpdates()
                }
                self.locationManager?.startUpdatingLocation()
            }
            
            // Start HealthKit workout
            self.startHealthKitWorkout()
            
            // Start timer
            self.startTimer()
            
            self.state = .active
            self.isTracking = true
            self.isPaused = false
            
            // Establish device coordination when sports tracking starts
            self.establishDeviceCoordination()
            
            // Start smart handoff monitoring
            SmartHandoffCoordinator.shared.startMonitoring(workoutType: .sports)
        }
        
        // Notify watch
        sendStateToWatch(.active)
    }
    
    func pauseTracking() {
        guard state == .active else { return }
        
        state = .paused
        isPaused = true
        pausedTime = Date().timeIntervalSince1970
        
        locationManager?.stopUpdatingLocation()
        timer?.invalidate()
        
        // Pause workout collection based on iOS version
        pauseWorkoutCollection()
        
        sendStateToWatch(.paused)
    }
    
    func resumeTracking() async {
        guard state == .paused else { return }
        
        // Calculate paused duration
        if pausedTime > 0 {
            let pauseDuration = Date().timeIntervalSince1970 - pausedTime
            totalPausedDuration += pauseDuration
            pausedTime = 0
        }
        
        await MainActor.run {
            state = .active
            isPaused = false
            
            // Resume location updates
            let authStatus = CLLocationManager.authorizationStatus()
            if authStatus == .authorizedAlways || authStatus == .authorizedWhenInUse {
                // Re-enable background location updates if we have "Always" authorization
                if authStatus == .authorizedAlways {
                    enableBackgroundLocationUpdates()
                }
                locationManager?.startUpdatingLocation()
            }
            
            // Resume workout collection
            resumeWorkoutCollection()
            
            startTimer()
        }
        
        sendStateToWatch(.active)
    }
    
    func endTracking() async {
        guard state == .active || state == .paused else { return }
        
        await MainActor.run {
            state = .ended
            isTracking = false
            isPaused = false
            
            // Stop everything
            locationManager?.stopUpdatingLocation()
            // Disable background location updates when stopping
            locationManager?.allowsBackgroundLocationUpdates = false
            timer?.invalidate()
            
            let endDate = Date()
            currentSportsLog.endDate = endDate
            
            // End HealthKit workout
            endHealthKitWorkout()
            
            // Save to database
            saveSportsSession()
            
            // Stop smart handoff monitoring
            SmartHandoffCoordinator.shared.stopMonitoring()
        }
        
        sendStateToWatch(.ended)
    }
    
    func endSports() {
        Task {
            await endTracking()
        }
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }
    
    private func updateTimer() {
        guard let startDate = startDate else { return }
        
        let currentTime = Date().timeIntervalSince1970
        elapsedTime = currentTime - startDate.timeIntervalSince1970 - totalPausedDuration
        
        updateFormattedValues()
    }
    
    // MARK: - Formatted Values
    
    private func updateFormattedValues() {
        // Format time
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        formattedTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        
        // Format distance
        let distanceValue = distance.value
        if distanceUnit == "km" {
            formattedDistance = String(format: "%.2f", distanceValue / 1000.0)
        } else {
            formattedDistance = String(format: "%.2f", distanceValue / 1609.34)
        }
        
        // Format calories
        formattedCalories = String(format: "%.0f", calories)
        
        // Format heart rate
        if heartRate > 0 {
            formattedHeartRate = String(format: "%.0f", heartRate)
        } else {
            formattedHeartRate = "--"
        }
    }
    
    // MARK: - HealthKit Workout (Version-Safe)
    
    private func startHealthKitWorkout() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("⚠️ HealthKit not available")
            return
        }
        
        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = getHKWorkoutActivityType(for: sportType)
        workoutConfiguration.locationType = needsGPS(for: sportType) ? .outdoor : .indoor
        
        // Use HKWorkoutBuilder (iOS 16.0+)
        workoutBuilder = HKWorkoutBuilder(healthStore: healthStore, configuration: workoutConfiguration, device: nil)
        
        let startDate = Date()
        workoutBuilder?.beginCollection(withStart: startDate) { [weak self] success, error in
            if let error = error {
                print("Error beginning workout collection: \(error.localizedDescription)")
            } else {
                print("✅ Started HealthKit workout collection")
            }
        }
    }
    
    private func pauseWorkoutCollection() {
        guard let builder = workoutBuilder else { return }
        
        builder.endCollection(withEnd: Date()) { success, error in
            if let error = error {
                print("Error pausing workout collection: \(error.localizedDescription)")
            }
        }
    }
    
    private func resumeWorkoutCollection() {
        guard let builder = workoutBuilder else { return }
        
        builder.beginCollection(withStart: Date()) { success, error in
            if let error = error {
                print("Error resuming workout collection: \(error.localizedDescription)")
            }
        }
    }
    
    private func endHealthKitWorkout() {
        guard let builder = workoutBuilder else { return }
        
        let endDate = Date()
        
        builder.endCollection(withEnd: endDate) { success, error in
            if let error = error {
                print("Error ending workout collection: \(error.localizedDescription)")
            }
        }
        
        builder.finishWorkout { workout, error in
            if let error = error {
                print("Error finishing workout: \(error.localizedDescription)")
            } else if let workout = workout {
                print("✅ Sports workout saved to HealthKit")
            }
        }
        
        // Clean up
        workoutBuilder = nil
    }
    
    private func getHKWorkoutActivityType(for sportType: SportType) -> HKWorkoutActivityType {
        switch sportType {
        case .basketball: return .basketball
        case .soccer: return .soccer
        case .tennis: return .tennis
        case .volleyball: return .volleyball
        case .baseball: return .baseball
        case .hockey: return .hockey
        case .rugby: return .rugby
        case .kayaking: return .paddleSports
        case .golf: return .golf
        case .paddleboard: return .paddleSports
        case .surfing: return .surfingSports
        case .other: return .traditionalStrengthTraining
        }
    }
    
    private func needsGPS(for sportType: SportType) -> Bool {
        switch sportType {
        case .kayaking, .surfing, .paddleboard, .golf: return true
        default: return false
        }
    }
    
    // MARK: - Database Saving (AWS with Backup)
    
    private func saveSportsSession() {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            print("❌ No user ID for saving sports session")
            saveToBackupStorage()
            return
        }
        
        // Check if we've already saved this session (idempotency)
        if let lastSavedId = UserDefaults.standard.string(forKey: "lastSavedSportsSessionId"),
           lastSavedId == currentSportsLog.id {
            print("⚠️ Session already saved, skipping duplicate save")
            return
        }
        
        // Prepare route points
        var routePoints: [[String: Any]] = []
        var startLocation: [String: Any]?
        var endLocation: [String: Any]?
        
        if !locationList.isEmpty {
            // Convert location data to route points format
            routePoints = locationList.map { locationData in
                var point: [String: Any] = [
                    "timestamp": locationData.timestamp.ISO8601Format(),
                    "latitude": locationData.latitude,
                    "longitude": locationData.longitude,
                    "altitude": locationData.altitude,
                    "horizontalAccuracy": locationData.horizontalAccuracy,
                    "verticalAccuracy": locationData.verticalAccuracy,
                    "speed": locationData.speed,
                    "course": locationData.course
                ]
                
                if let hr = locationData.heartRate {
                    point["heartRate"] = hr
                }
                if let cad = locationData.cadence {
                    point["cadence"] = cad
                }
                
                return point
            }
            
            // Set start and end locations
            if let firstLocation = locationList.first {
                startLocation = [
                    "lat": firstLocation.latitude,
                    "lon": firstLocation.longitude,
                    "name": "Start"
                ]
            }
            if let lastLocation = locationList.last {
                endLocation = [
                    "lat": lastLocation.latitude,
                    "lon": lastLocation.longitude,
                    "name": "End"
                ]
            }
        }
        
        // Prepare activity data
        let activityData: [String: Any] = [
            "sportType": sportType.rawValue,
            "distanceUnit": distanceUnit,
            "formattedDistance": formattedDistance,
            "formattedTime": formattedTime
        ]
        
        // Save to AWS using ActivityService
        ActivityService.shared.saveSports(
            userId: userId,
            sportType: sportType.rawValue,
            duration: elapsedTime,
            distance: distance.value,
            calories: calories,
            avgHeartRate: avgHeartRate > 0 ? avgHeartRate : nil,
            maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil,
            elevationGain: elevationGain.value > 0 ? elevationGain.value : nil,
            elevationLoss: elevationLoss.value > 0 ? elevationLoss.value : nil,
            routePoints: routePoints,
            activityData: activityData,
            startLocation: startLocation,
            endLocation: endLocation,
            isPublic: true,
            caption: nil,
            createdAt: currentSportsLog.startDate
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let response):
                print("✅ Sports session saved to AWS successfully")
                if let activityId = response.data?.activityId {
                    self.currentSportsLog.id = activityId
                    // Mark as saved to prevent duplicate saves
                    UserDefaults.standard.set(activityId, forKey: "lastSavedSportsSessionId")
                    UserDefaults.standard.synchronize()
                    print("   Activity ID: \(activityId)")
                    // Clear backup storage on success
                    self.clearBackupStorage()
                    self.saveRetryCount = 0
                }
                
            case .failure(let error):
                print("❌ Error saving sports session to AWS: \(error.localizedDescription)")
                // Save to backup storage for retry
                self.saveToBackupStorage()
                
                // Retry with exponential backoff
                if self.saveRetryCount < self.maxRetryAttempts {
                    self.saveRetryCount += 1
                    let delay = self.retryDelay * pow(2.0, Double(self.saveRetryCount - 1))
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        print("🔄 Retrying save (attempt \(self.saveRetryCount)/\(self.maxRetryAttempts))")
                        self.saveSportsSession()
                    }
                } else {
                    print("⚠️ Max retry attempts reached. Session saved to backup storage.")
                }
            }
        }
    }
    
    // MARK: - Backup Storage
    
    private func saveToBackupStorage() {
        let backupData: [String: Any] = [
            "sportType": sportType.rawValue,
            "duration": elapsedTime,
            "distance": distance.value,
            "calories": calories,
            "avgHeartRate": avgHeartRate > 0 ? avgHeartRate : 0,
            "maxHeartRate": maxHeartRate > 0 ? maxHeartRate : 0,
            "elevationGain": elevationGain.value,
            "elevationLoss": elevationLoss.value,
            "formattedTime": formattedTime,
            "formattedDistance": formattedDistance,
            "startDate": currentSportsLog.startDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
            "endDate": currentSportsLog.endDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
            "locationList": locationList.map { $0.toDictionary() },
            "userId": UserIDHelper.shared.getCurrentUserID() ?? ""
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: backupData),
           let jsonString = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(jsonString, forKey: BackupKeys.pendingSportsSession)
            UserDefaults.standard.synchronize()
            print("💾 Saved sports session to backup storage")
        }
    }
    
    private func clearBackupStorage() {
        UserDefaults.standard.removeObject(forKey: BackupKeys.pendingSportsSession)
        UserDefaults.standard.synchronize()
    }
    
    // Call this on app launch to retry failed saves
    static func retryPendingSaves() {
        guard let backupString = UserDefaults.standard.string(forKey: BackupKeys.pendingSportsSession),
              let backupData = backupString.data(using: .utf8),
              let backup = try? JSONSerialization.jsonObject(with: backupData) as? [String: Any],
              let userId = backup["userId"] as? String,
              !userId.isEmpty else {
            return
        }
        
        print("🔄 Found pending sports session in backup storage, retrying save...")
        
        let sportType = backup["sportType"] as? String ?? "other"
        let duration = backup["duration"] as? Double ?? 0
        let distance = backup["distance"] as? Double ?? 0
        let calories = backup["calories"] as? Double ?? 0
        let avgHeartRate = backup["avgHeartRate"] as? Double
        let maxHeartRate = backup["maxHeartRate"] as? Double
        let elevationGain = backup["elevationGain"] as? Double
        let elevationLoss = backup["elevationLoss"] as? Double
        
        var routePoints: [[String: Any]] = []
        if let locationList = backup["locationList"] as? [[String: Any]] {
            routePoints = locationList
        }
        
        var createdAt: Date?
        if let startDateTimestamp = backup["startDate"] as? TimeInterval {
            createdAt = Date(timeIntervalSince1970: startDateTimestamp)
        }
        
        ActivityService.shared.saveSports(
            userId: userId,
            sportType: sportType,
            duration: duration,
            distance: distance,
            calories: calories,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            routePoints: routePoints,
            activityData: [:],
            startLocation: nil,
            endLocation: nil,
            isPublic: true,
            caption: nil,
            createdAt: createdAt
        ) { result in
            switch result {
            case .success:
                print("✅ Retry successful - cleared backup storage")
                UserDefaults.standard.removeObject(forKey: BackupKeys.pendingSportsSession)
                UserDefaults.standard.synchronize()
            case .failure(let error):
                print("❌ Retry failed: \(error.localizedDescription)")
                // Keep in backup for next app launch
            }
        }
    }
    
    // MARK: - Watch Connectivity
    
    func sendStateToWatch(_ state: SportsTrackingState) {
        guard WCSession.isSupported(), WCSession.default.isReachable else { return }
        
        let message: [String: Any] = [
            "type": "sportsStateChange",
            "sportType": sportType.rawValue,
            "state": state.rawValue,
            "isTracking": state == .active,
            "isPaused": state == .paused,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Error sending state to watch: \(error.localizedDescription)")
        }
    }
    
    func sendMetricsToWatch() {
        guard WCSession.isSupported(), WCSession.default.isReachable else { return }
        
        let message: [String: Any] = [
            "type": "sportsMetricsUpdate",
            "distance": distance.value,
            "elapsedTime": elapsedTime,
            "calories": calories,
            "heartRate": heartRate,
            "formattedDistance": formattedDistance,
            "formattedTime": formattedTime,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Error sending metrics to watch: \(error.localizedDescription)")
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation error: \(error.localizedDescription)")
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handleWatchMessage(message, replyHandler: replyHandler)
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleWatchMessage(applicationContext, replyHandler: { _ in })
    }
    
    private func handleWatchMessage(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            if let type = message["type"] as? String {
                switch type {
                case "requestSportsWorkout":
                    let response = self.prepareWorkoutResponse()
                    replyHandler(response)
                    
                case "sportsWorkoutUpdate":
                    self.handleWatchWorkoutUpdate(message)
                    replyHandler(["status": "received"])
                    
                case "sportsStateChange":
                    if let stateStr = message["state"] as? String,
                       let newState = SportsTrackingState(rawValue: stateStr) {
                        self.handleWatchStateChange(newState)
                        replyHandler(["status": "received"])
                    }
                    
                default:
                    replyHandler(["status": "unknown"])
                }
            }
        }
    }
    
    private func prepareWorkoutResponse() -> [String: Any] {
        return [
            "status": "processed",
            "workoutActive": state == .active,
            "hasActiveWorkout": state == .active || state == .paused,
            "state": state.rawValue,
            "sportType": sportType.rawValue,
            "distance": distance.value,
            "elapsedTime": elapsedTime,
            "calories": calories,
            "heartRate": heartRate,
            "formattedDistance": formattedDistance,
            "formattedTime": formattedTime,
            "isPaused": isPaused,
            "isIndoor": isIndoorMode,
            "isWatchTracking": isWatchTracking,
            "hasGoodLocationData": hasGoodLocationData,
            "isPrimaryForDistance": isPrimaryForDistance,
            "isPrimaryForPace": isPrimaryForPace,
            "isPrimaryForHeartRate": isPrimaryForHeartRate,
            "isPrimaryForCalories": isPrimaryForCalories,
            "isPrimaryForCadence": isPrimaryForCadence,
            "isDashboardMode": isDashboardMode
        ]
    }
    
    private func handleWatchWorkoutUpdate(_ update: [String: Any]) {
        // Ensure @Published properties are updated on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Always accept heart rate from watch (watch is always primary for HR)
            if let heartRate = update["heartRate"] as? Double, heartRate > 0 {
                print("📱 Updating heart rate from watch: \(heartRate)")
                self.heartRate = heartRate
                if heartRate > self.maxHeartRate {
                    self.maxHeartRate = heartRate
                }
            }
            
            // Only accept other metrics if watch is primary for them
            if !self.isPrimaryForDistance, let distance = update["distance"] as? Double, distance > 0 {
                self.distance = Measurement(value: distance, unit: .meters)
            }
            if !self.isPrimaryForCalories, let calories = update["calories"] as? Double, calories > 0 {
                self.calories = calories
            }
        }
    }
    
    private func handleWatchStateChange(_ newState: SportsTrackingState) {
        Task {
            switch newState {
            case .active:
                if state == .notStarted {
                    await startTracking(sportType: sportType)
                } else if state == .paused {
                    await resumeTracking()
                }
            case .paused:
                if state == .active {
                    pauseTracking()
                }
            case .ended:
                await endTracking()
            default:
                break
            }
        }
    }
    
    // MARK: - History Retrieval (AWS)
    
    func getSportsHistory(limit: Int = 50) async throws -> [SportsLog] {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            throw NSError(domain: "SportsTrackingEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            ActivityService.shared.getSports(
                userId: userId,
                limit: limit,
                nextToken: nil,
                sportType: nil
            ) { result in
                switch result {
                case .success(let response):
                    guard let activities = response.data?.activities else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    var sportsLogs: [SportsLog] = []
                    for activity in activities {
                        // Only process sports activities
                        guard activity.activityType == "sports" else { continue }
                        
                        var log = SportsLog()
                        log.id = activity.activityId ?? activity.id
                        
                        // Get sportType - check direct property first, then activityData
                        var sportType = activity.sportType ?? "other"
                        if sportType == "other" || sportType.isEmpty {
                            if let activityDataString = activity.activityData,
                               let data = activityDataString.data(using: .utf8),
                               let activityData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let type = activityData["sportType"] as? String {
                                sportType = type
                            }
                        }
                        log.sportType = sportType
                        
                        // Convert duration from seconds to formatted string
                        let durationSeconds = activity.duration
                        let hours = Int(durationSeconds) / 3600
                        let minutes = (Int(durationSeconds) % 3600) / 60
                        let seconds = Int(durationSeconds) % 60
                        log.duration = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
                        
                        // Convert distance from meters to formatted string
                        let distanceMeters = activity.distance
                        let distanceKm = distanceMeters / 1000.0
                        log.distance = String(format: "%.2f km", distanceKm)
                        
                        log.caloriesBurned = activity.calories
                        log.avgHeartRate = activity.avgHeartRate
                        log.maxHeartRate = activity.maxHeartRate
                        
                        // Parse dates
                        let formatter = ISO8601DateFormatter()
                        log.createdAt = formatter.date(from: activity.createdAt)
                        
                        // Elevation (convert from meters if needed)
                        if let elevationGain = activity.elevationGain {
                            let elevationFeet = elevationGain * 3.28084
                            log.elevationGain = String(format: "%.0f ft", elevationFeet)
                        }
                        if let elevationLoss = activity.elevationLoss {
                            let elevationFeet = elevationLoss * 3.28084
                            log.elevationLoss = String(format: "%.0f ft", elevationFeet)
                        }
                        
                        sportsLogs.append(log)
                    }
                    
                    continuation.resume(returning: sportsLogs)
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getStatistics() async -> (sessions: Int, totalTime: TimeInterval, sportsPlayed: Set<String>) {
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            return (0, 0, Set())
        }
        
        return await withCheckedContinuation { continuation in
            ActivityService.shared.getSports(
                userId: userId,
                limit: 1000, // Get all for stats
                nextToken: nil,
                sportType: nil
            ) { result in
                switch result {
                case .success(let response):
                    guard let activities = response.data?.activities else {
                        continuation.resume(returning: (0, 0, Set()))
                        return
                    }
                    
                    var totalTimeSeconds: TimeInterval = 0
                    var sportsSet = Set<String>()
                    
                    for activity in activities {
                        // Only process sports activities
                        guard activity.activityType == "sports" else { continue }
                        
                        // Get sportType - check direct property first, then activityData
                        var sportType = activity.sportType ?? "other"
                        if sportType == "other" || sportType.isEmpty {
                            if let activityDataString = activity.activityData,
                               let data = activityDataString.data(using: .utf8),
                               let activityData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let type = activityData["sportType"] as? String {
                                sportType = type
                            }
                        }
                        sportsSet.insert(sportType)
                        totalTimeSeconds += activity.duration
                    }
                    
                    continuation.resume(returning: (activities.count, totalTimeSeconds, sportsSet))
                    
                case .failure(let error):
                    print("Error fetching sports statistics: \(error.localizedDescription)")
                    continuation.resume(returning: (0, 0, Set()))
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension SportsTrackingEngine: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, state == .active else { return }
        
        // Filter out invalid locations
        guard location.horizontalAccuracy > 0 && location.horizontalAccuracy < 100 else { return }
        
        // Calculate distance
        if let lastLocation = lastLocation {
            let distanceIncrement = location.distance(from: lastLocation)
            if distanceIncrement > 0 && distanceIncrement < 1000 { // Filter out jumps > 1km
                distance = Measurement(value: distance.value + distanceIncrement, unit: .meters)
                
                // Calculate elevation changes
                let altitudeDiff = location.altitude - lastLocation.altitude
                if altitudeDiff > 0 {
                    elevationGain = Measurement(value: elevationGain.value + abs(altitudeDiff), unit: .meters)
                } else if altitudeDiff < 0 {
                    elevationLoss = Measurement(value: elevationLoss.value + abs(altitudeDiff), unit: .meters)
                }
            }
        }
        
        lastLocation = location
        
        // Store location data
        let locationData = SportsLocationData(from: location, heartRate: heartRate > 0 ? heartRate : nil, cadence: nil)
        locationList.append(locationData)
        
        // Update formatted values
        updateFormattedValues()
        
        // Send metrics to watch every 5 seconds
        if Int(elapsedTime) % 5 == 0 {
            sendMetricsToWatch()
        }
        
        // Estimate calories based on sport type and activity
        estimateCalories()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    private func estimateCalories() {
        // Basic calorie estimation based on sport type, duration, and distance
        // More accurate calculations would use MET values for each sport
        let baseMET: Double
        switch sportType {
        case .basketball: baseMET = 8.0
        case .soccer: baseMET = 10.0
        case .tennis: baseMET = 7.0
        case .volleyball: baseMET = 3.0
        case .baseball: baseMET = 5.0
        case .hockey: baseMET = 8.0
        case .rugby: baseMET = 10.0
        case .kayaking: baseMET = 5.0
        case .golf: baseMET = 4.5
        case .paddleboard: baseMET = 6.0
        case .surfing: baseMET = 3.0
        case .other: baseMET = 5.0
        }
        
        // Estimate weight (default 70kg if not available)
        var weightKg = currentUser?.weight ?? 70.0
        if let weightUnit = currentUser?.weightUnit, weightUnit == "lbs" {
            // Convert lbs to kg
            let weightLbs = currentUser?.weight ?? 154.0
            weightKg = weightLbs * 0.453592
        }
        
        // Calories = MET * weight(kg) * time(hours)
        let hours = elapsedTime / 3600.0
        let calculatedCalories = baseMET * weightKg * hours
        
        // Ensure @Published property is updated on main thread
        DispatchQueue.main.async { [weak self] in
            self?.calories = calculatedCalories
        }
    }
    
    // MARK: - Device Coordination
    
    // Establish initial device coordination roles
    private func establishDeviceCoordination() {
        guard state != .notStarted && state != .ended else { return }
        
        if isIndoorMode {
            // For indoor sports, watch takes precedence for all metrics
            isDashboardMode = true
            isWatchTracking = true
            
            // Set watch as primary for all metrics
            isPrimaryForDistance = false
            isPrimaryForPace = false
            isPrimaryForHeartRate = false
            isPrimaryForCalories = false
            isPrimaryForCadence = false
            
            print("📱 Indoor sports: Phone acting as dashboard")
            print("⌚️ Watch will be primary for all tracking metrics")
        } else {
            // For outdoor sports, determine based on GPS quality
            isDashboardMode = false
            
            // Check if we have good GPS data
            if hasGoodLocationData {
                // Phone is primary for GPS-based metrics
                isPrimaryForDistance = true
                isPrimaryForPace = true
                isPrimaryForHeartRate = false // Watch still better for HR
                isPrimaryForCalories = true   // Phone can calculate calories with distance
                isPrimaryForCadence = false   // Watch better for cadence
                
                print("📱 Outdoor sports with good GPS: Phone primary for distance/pace")
                print("⌚️ Watch primary for heart rate and cadence")
            } else {
                // Poor GPS quality, let watch take more metrics
                isPrimaryForDistance = false
                isPrimaryForPace = false
                isPrimaryForHeartRate = false
                isPrimaryForCalories = false
                isPrimaryForCadence = false
                isWatchTracking = true
                
                print("📱 Outdoor sports with poor GPS: Deferring to watch for metrics")
            }
        }
        
        // Update application context to let watch know current state
        updateApplicationContext()
    }
}

// MARK: - Watch Handoff and Multi-Device Support

extension SportsTrackingEngine {
    
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
            pace: 0, // Sports may not have pace
            calories: calories,
            cadence: 0,
            elevationGain: elevationGain.value
        )
        
        let handoffMessage = WorkoutHandoffMessage(
            direction: .phoneToWatch,
            workoutType: .sports,
            workoutId: workoutId.uuidString,
            metrics: metrics,
            state: convertSportsStateToWorkoutState(state),
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
                    Task {
                        await self.endTracking()
                    }
                }
                completion(accepted)
            }, errorHandler: { error in
                print("❌ [SportsTrackingEngine] Handoff failed: \(error.localizedDescription)")
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
            handleHandoffConflict(phoneState: convertSportsStateToWorkoutState(state),
                                watchWorkout: handoffMessage)
            return
        }
        
        workoutId = UUID(uuidString: handoffMessage.workoutId) ?? UUID()
        startDate = handoffMessage.startDate
        
        distance = Measurement(value: handoffMessage.metrics.distance, unit: UnitLength.meters)
        elapsedTime = handoffMessage.metrics.elapsedTime
        heartRate = handoffMessage.metrics.heartRate
        calories = handoffMessage.metrics.calories
        
        state = convertWorkoutStateToSportsState(handoffMessage.state)
        
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
        startDate = watchWorkout.startDate
        
        heartRate = watchWorkout.metrics.heartRate
        calories = max(calories, watchWorkout.metrics.calories)
        elapsedTime = max(elapsedTime, watchWorkout.metrics.elapsedTime)
        
        state = convertWorkoutStateToSportsState(watchWorkout.state)
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
        
        if let source = coordinationEngine.selectBestDataSource(
            for: .heartRate,
            workoutType: .sports,
            isIndoor: isIndoorMode,
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
            pace: 0,
            calories: calories,
            cadence: 0,
            elevationGain: elevationGain.value
        )
        
        LiveMetricsSync.shared.syncMetrics(
            metrics: metrics,
            workoutId: workoutId.uuidString,
            workoutType: .sports
        )
    }
    
    // MARK: - State Conversion Helpers
    
    private func convertSportsStateToWorkoutState(_ sportsState: SportsTrackingState) -> WorkoutState {
        switch sportsState {
        case .notStarted: return .idle
        case .starting, .active: return .running
        case .paused: return .paused
        case .ended: return .stopped
        }
    }
    
    private func convertWorkoutStateToSportsState(_ workoutState: WorkoutState) -> SportsTrackingState {
        switch workoutState {
        case .idle: return .notStarted
        case .starting, .running: return .active
        case .paused: return .paused
        case .stopping, .stopped, .completed: return .ended
        }
    }
    
    // MARK: - Enhanced Watch Sync
    
    func enhancedSyncWithWatch() {
        updateApplicationContext()
        
        WorkoutStateSync.shared.syncState(
            workoutId: workoutId.uuidString,
            workoutType: .sports,
            state: convertSportsStateToWorkoutState(state)
        )
    }
    
    // MARK: - Handoff Data Provider
    
    func getHandoffData() -> [String: Any]? {
        guard state != .notStarted else { return nil }
        
        let metrics = WorkoutMetrics(
            distance: distance.value,
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            pace: 0,
            calories: calories,
            cadence: 0,
            elevationGain: elevationGain.value
        )
        
        let handoffMessage = WorkoutHandoffMessage(
            direction: .phoneToWatch,
            workoutType: .sports,
            workoutId: workoutId.uuidString,
            metrics: metrics,
            state: convertSportsStateToWorkoutState(state),
            startDate: startDate ?? Date()
        )
        
        return handoffMessage.toDictionary()
    }

    
    // Update application context
    private func updateApplicationContext() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        
        let context: [String: Any] = [
            "type": "sportsWorkoutState",
            "state": state.rawValue,
            "sportType": sportType.rawValue,
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
}

// Note: HKWorkoutSessionDelegate is only needed for iOS 17+
// iOS 16.0 uses HKWorkoutBuilder directly without session delegate
