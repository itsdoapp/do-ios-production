//
//  ModernLocationManager.swift
//  Do.
//
//  Created by Mikiyas Meseret on 3/12/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//
//  SMART LOCATION MANAGEMENT:
//  Only activates location when actually needed to save battery
//  Tracks active usage reasons and stops when no longer needed

import Foundation
import CoreLocation
import MapKit
import Combine
import HealthKit
import WatchConnectivity

/// Reasons why location is needed
enum LocationUsageReason: String, CaseIterable {
    case activeWorkout = "Active Workout"          // Running/biking/hiking in progress
    case watchWorkout = "Watch Workout"            // Apple Watch workout active
    case weatherFetch = "Weather"                  // Getting weather
    case routeDisplay = "Route Display"            // Showing route on map
    case postLocation = "Post Location"            // Adding location to post
    case oneTimeRequest = "One-Time Request"       // Single location request
}

class ModernLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // Singleton instance
    static let shared = ModernLocationManager()
    
    // Core location manager
    private(set) var manager = CLLocationManager()
    
    // SMART LOCATION: Track active usage reasons
    private var activeUsageReasons = Set<LocationUsageReason>()
    private var usageReasonTimestamps = [LocationUsageReason: Date]()
    
    // Published properties for SwiftUI binding
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    @Published var location: CLLocation?
    @Published var heading: CLHeading?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var totalDistance: Double = 0.0
    @Published var currentSpeed: Double = 0.0
    @Published var averageSpeed: Double = 0.0
    @Published var elevationGain: Double = 0.0
    @Published var isTracking: Bool = false
    @Published var isLocationActive: Bool = false  // NEW: Track if location is actually running
    
    // Running metrics
    @Published var currentPace: TimeInterval = 0 // seconds per km/mile
    @Published var averagePace: TimeInterval = 0 // seconds per km/mile
    @Published var calories: Double = 0
    
    // Direct access to CLLocationManager properties
    var delegate: CLLocationManagerDelegate? {
        get { return manager.delegate }
        set { manager.delegate = newValue }
    }
    
    var distanceFilter: CLLocationDistance {
        get { return manager.distanceFilter }
        set { manager.distanceFilter = newValue }
    }
    
    var desiredAccuracy: CLLocationAccuracy {
        get { return manager.desiredAccuracy }
        set { manager.desiredAccuracy = newValue }
    }
    
    var activityType: CLActivityType {
        get { return manager.activityType }
        set { manager.activityType = newValue }
    }
    
    var allowsBackgroundLocationUpdates: Bool {
        get { return manager.allowsBackgroundLocationUpdates }
        set { manager.allowsBackgroundLocationUpdates = newValue }
    }
    
    var pausesLocationUpdatesAutomatically: Bool {
        get { return manager.pausesLocationUpdatesAutomatically }
        set { manager.pausesLocationUpdatesAutomatically = newValue }
    }
    
    private var locationHistory: [CLLocation] = []
    private var startTime: Date?
    public var lastLocation: CLLocation?
    private var distanceSegments: [Double] = []
    private var speedReadings: [Double] = []
    private var cancellables = Set<AnyCancellable>()
    
    // Add property to track last location update time
    private var lastProcessedLocationTime: Date = Date.distantPast
    private let locationUpdateThrottleInterval: TimeInterval = 1.0 // seconds
    
    // Add property to track location failures
    private var locationFailureCount = 0
    
    // Initialization
    private override init() {
        super.init()
        manager.delegate = self
        // Use best for navigation to speed first fix and allow coarse arrival
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 2 // Update every 2 meters
        manager.activityType = .fitness
        authorizationStatus = manager.authorizationStatus
        
        // Synchronize with legacy LocationManager to maintain backward compatibility
        DispatchQueue.main.async {
            // Use async to avoid potential initialization ordering issues
            self.synchronizeWithLegacy(LocationManager.shared)
        }
        
        // Monitor for Apple Watch workouts
        setupWatchWorkoutMonitoring()
    }
    
    // MARK: - Smart Location Management
    
    /// Request location for a specific reason - only starts if not already active
    func requestLocation(for reason: LocationUsageReason) {
        print("📍 [SMART] Location requested for: \(reason.rawValue)")
        
        activeUsageReasons.insert(reason)
        usageReasonTimestamps[reason] = Date()
        
        // Auto-expire one-time requests after 30 seconds
        if reason == .oneTimeRequest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                self?.stopLocation(for: .oneTimeRequest)
            }
        }
        
        // Check authorization status first
        let authStatus = manager.authorizationStatus
        if authStatus == .notDetermined {
            print("📍 [SMART] Authorization not determined, requesting...")
            manager.requestWhenInUseAuthorization()
            // Will start location in locationManagerDidChangeAuthorization callback
            return
        }
        
        guard authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways else {
            print("⚠️ [SMART] Authorization denied/restricted: \(authStatus.rawValue)")
            return
        }
        
        // For weather/route fetching, use one-time request instead of continuous updates
        // This prevents unnecessary location updates after we have what we need
        if reason == .weatherFetch || reason == .routeDisplay {
            // Use cached location if available and recent (within 10 minutes)
            if let cachedLocation = self.location,
               Date().timeIntervalSince(cachedLocation.timestamp) < 600 {
                print("📍 [SMART] Using cached location for \(reason.rawValue) (age: \(Int(Date().timeIntervalSince(cachedLocation.timestamp)))s)")
                // Notify that we have a location (will trigger weather/route loading)
                NotificationCenter.default.post(
                    name: .locationDidUpdate,
                    object: self,
                    userInfo: ["location": cachedLocation]
                )
                // Auto-stop after a short delay to ensure we don't keep location active
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.stopLocation(for: reason)
                }
                return
            }
            
            // If no cached location or it's stale, request one-time location
            print("📍 [SMART] Requesting one-time location for \(reason.rawValue)")
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.requestLocation()
            }
            // Auto-stop after 30 seconds to ensure we don't keep location active
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                self?.stopLocation(for: reason)
            }
            return
        }
        
        // For other reasons (active workout, etc.), use continuous updates
        // Start location if not already active
        if !isLocationActive {
            print("📍 [SMART] Starting location services")
            print("📍 [SMART] Active reasons: \(activeUsageReasons.map { $0.rawValue }.joined(separator: ", "))")
            isLocationActive = true
            startUpdatingLocation()
        } else {
            print("📍 [SMART] Location already active, added reason")
        }
    }
    
    /// Stop location for a specific reason - only stops if no other reasons remain
    func stopLocation(for reason: LocationUsageReason) {
        print("📍 [SMART] Location stop requested for: \(reason.rawValue)")
        
        activeUsageReasons.remove(reason)
        usageReasonTimestamps.removeValue(forKey: reason)
        
        // If no more reasons, stop location
        if activeUsageReasons.isEmpty {
            print("📍 [SMART] No more active reasons, stopping location services")
            isLocationActive = false
            stopUpdatingLocation()
        } else {
            print("📍 [SMART] Still active for: \(activeUsageReasons.map { $0.rawValue }.joined(separator: ", "))")
        }
    }
    
    /// Check if location is needed for any reason
    var isLocationNeeded: Bool {
        return !activeUsageReasons.isEmpty
    }
    
    /// Get current active reasons
    func getActiveReasons() -> [LocationUsageReason] {
        return Array(activeUsageReasons)
    }
    
    /// Monitor for Apple Watch workouts
    private func setupWatchWorkoutMonitoring() {
        // Check if watch session is available
        if WCSession.isSupported() {
            let session = WCSession.default
            
            // Listen for watch workout state changes
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("WatchWorkoutStarted"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                print("📍 [SMART] Watch workout detected, requesting location")
                self?.requestLocation(for: .watchWorkout)
            }
            
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("WatchWorkoutEnded"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                print("📍 [SMART] Watch workout ended, stopping location")
                self?.stopLocation(for: .watchWorkout)
            }
        }
        
        // Monitor HealthKit for active workouts
        if HKHealthStore.isHealthDataAvailable() {
            // Check for active workout sessions periodically
            Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
                self?.checkForActiveWorkouts()
            }
        }
    }
    
    /// Check if there are active HealthKit workouts
    private func checkForActiveWorkouts() {
        // Check if RunTrackingEngine or BikeTrackingEngine are active
        let runEngine = RunTrackingEngine.shared
        let bikeEngine = BikeTrackingEngine.shared
        
        let hasActiveWorkout = runEngine.isRunning || bikeEngine.isRunning
        
        if hasActiveWorkout && !activeUsageReasons.contains(.activeWorkout) {
            print("📍 [SMART] Active workout detected")
            requestLocation(for: .activeWorkout)
        } else if !hasActiveWorkout && activeUsageReasons.contains(.activeWorkout) {
            print("📍 [SMART] No active workout, stopping location")
            stopLocation(for: .activeWorkout)
        }
    }
    
    // MARK: - Public Methods
    
    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }
    
    func startUpdatingLocation() {
        #if DEBUG
        print("📍 ModernLocationManager: Starting location updates")
        #endif
        
        guard CLLocationManager.locationServicesEnabled() else {
            #if DEBUG
            print("❌ Location services disabled")
            #endif
            return
        }
        
        // CRITICAL: Don't start location updates if authorization is notDetermined
        let authStatus = manager.authorizationStatus
        guard authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways else {
            print("⚠️ Cannot start location updates: authorization status is \(authStatus.rawValue) (notDetermined=0, denied=2, restricted=1)")
            if authStatus == .notDetermined {
                print("ℹ️ Request authorization first before starting location updates")
            }
            return
        }
        
        // Ensure delegate is set correctly
        if manager.delegate !== self {
            manager.delegate = self
        }
        manager.startUpdatingLocation()
        scheduleWatchdog()
    }
    
    func requestLocation() {
        print("📍 ModernLocationManager: Requesting single location fix…")
        if !CLLocationManager.locationServicesEnabled() {
            print("❌ Location services are disabled at the system level (requestLocation)")
            return
        }
        
        // Check authorization status - don't request location if permission not granted
        let authStatus = CLLocationManager.authorizationStatus()
        guard authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways else {
            print("⚠️ Cannot request location: authorization status is \(authStatus.rawValue) (notDetermined=0, denied=2, restricted=1)")
            if authStatus == .notDetermined {
                print("ℹ️ Permission not yet granted - request authorization first")
            }
            return
        }
        
        // Already off main thread from caller, but ensure delegate is set
        if manager.delegate !== self {
            print("⚠️ requestLocation: Delegate hijacked! Resetting to self")
            manager.delegate = self
        }
        manager.requestLocation()
        scheduleWatchdog()
    }

    // Request temporary full accuracy if currently reduced
    func ensurePreciseAccuracyIfNeeded() {
        if #available(iOS 14.0, *) {
            if manager.accuracyAuthorization == .reducedAccuracy {
                print("📍 Requesting temporary full accuracy authorization…")
                manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "PreciseLocation") { [weak self] error in
                    if let error = error { print("❌ Full accuracy request error: \(error.localizedDescription)") }
                    else { print("✅ Full accuracy granted (temporary)") }
                    // Kick a one-shot after accuracy upgrade
                    self?.requestLocation()
                }
            }
        }
    }

    // Counter for watchdog attempts
    private var watchdogAttempts = 0
    
    // Watchdog to retry if no location callbacks arrive
    private func scheduleWatchdog() {
        let deadline: DispatchTime = .now() + 3
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: deadline) { [weak self] in
            guard let self = self else { return }
            if self.location == nil {
                self.watchdogAttempts += 1
                print("⏱️ Watchdog: No location yet after 3s (attempt #\(self.watchdogAttempts))")
                print("⏱️ Watchdog: Delegate check: \(self.manager.delegate === self)")
                print("⏱️ Watchdog: Services enabled: \(CLLocationManager.locationServicesEnabled())")
                print("⏱️ Watchdog: Auth status: \(self.manager.authorizationStatus.rawValue)")
                
                // CRITICAL: Don't retry if authorization is not granted
                let authStatus = self.manager.authorizationStatus
                guard authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways else {
                    print("⏱️ Watchdog: Skipping retry - authorization status is \(authStatus.rawValue) (notDetermined=0, denied=2, restricted=1)")
                    return
                }
                
                // Force delegate back if hijacked
                if self.manager.delegate !== self {
                    print("⚠️ Watchdog: Delegate hijacked! Resetting to self")
                    self.manager.delegate = self
                }
                
                // NUCLEAR OPTION: After 3 failed attempts (9s), recreate the CLLocationManager
                if self.watchdogAttempts == 3 {
                    print("💣 NUCLEAR: No callbacks after 9s - Core Location may be frozen")
                    print("💣 NUCLEAR: Attempting to recreate CLLocationManager...")
                    DispatchQueue.main.async {
                        self.recreateLocationManager()
                    }
                } else {
                    // Retry location request only if authorized
                    print("⏱️ Watchdog: Retrying requestLocation()")
                    self.requestLocation() // Use our method which checks authorization
                }
            } else {
                // Reset counter on success
                self.watchdogAttempts = 0
            }
        }
    }
    
    // NUCLEAR OPTION: Completely recreate the location manager
    private func recreateLocationManager() {
        print("💣 Stopping existing location manager...")
        manager.stopUpdatingLocation()
        manager.delegate = nil
        
        print("💣 Creating new CLLocationManager instance...")
        manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 2
        manager.activityType = .fitness
        
        // Try different accuracy settings in case best navigation is broken
        print("💣 Trying kCLLocationAccuracyBest instead...")
        manager.desiredAccuracy = kCLLocationAccuracyBest
        
        print("💣 Requesting location with fresh manager...")
        manager.requestLocation()
        
        // Also try startUpdatingLocation for continuous mode
        print("💣 Also starting continuous location updates...")
        manager.startUpdatingLocation()
        
        // Schedule one more watchdog
        watchdogAttempts = 0
        scheduleWatchdog()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }
    
    func startUpdatingHeading() {
        manager.startUpdatingHeading()
    }
    
    func stopUpdatingHeading() {
        manager.stopUpdatingHeading()
    }
    
    func centerOnUser() {
        if let location = self.location {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
    
    /// Safely enable background location updates
    /// This can only be set when authorized with "Always" permission and the app has the proper capability
    /// Returns true if successfully enabled, false otherwise
    /// 
    /// IMPORTANT: This requires:
    /// 1. "Location updates" in UIBackgroundModes in Info.plist
    /// 2. .authorizedAlways authorization status
    /// 3. Background refresh to be available
    /// 
    /// If any of these conditions aren't met, this will return false and the app will
    /// continue tracking location in the foreground only.
    func safelyEnableBackgroundLocationUpdates() -> Bool {
        let authStatus = manager.authorizationStatus
        
        // CRITICAL: Background location updates require "Always" authorization
        // Setting this with "When In Use" authorization will cause an assertion failure
        guard authStatus == .authorizedAlways else {
            print("⚠️ [ModernLocationManager] Cannot enable background location updates: requires 'Always' authorization, but status is \(authStatus.rawValue)")
            return false
        }
        
        // Check if background refresh is available
        guard UIApplication.shared.backgroundRefreshStatus == .available else {
            print("⚠️ [ModernLocationManager] Background refresh not available - skipping background location updates")
            return false
        }
        
        // Attempt to enable background location updates
        // NOTE: This will cause an assertion failure if:
        // 1. The app doesn't have "Location updates" in UIBackgroundModes in Info.plist
        // 2. The authorization is not .authorizedAlways
        // We've checked authorization above, but the capability check happens at the CLLocationManager level
        // and cannot be caught with Swift error handling (it's an Objective-C assertion)
        manager.allowsBackgroundLocationUpdates = true
        print("✅ [ModernLocationManager] Background location updates enabled")
        return true
    }
    
    func startTracking() {
        print("📍 [SMART] Starting tracking mode")
        isTracking = true
        startTime = Date()
        locationHistory = []
        routeCoordinates = []
        totalDistance = 0
        elevationGain = 0
        currentPace = 0
        averagePace = 0
        speedReadings = []
        distanceSegments = []
        
        // Request authorization if needed before starting tracking
        let authStatus = manager.authorizationStatus
        if authStatus == .notDetermined {
            print("📍 [SMART] Authorization not determined, requesting...")
            manager.requestWhenInUseAuthorization()
            // Will continue in locationManagerDidChangeAuthorization callback
            return
        }
        
        // If we have "When In Use" but need background tracking, request "Always"
        if authStatus == .authorizedWhenInUse {
            print("📍 [SMART] Requesting 'Always' authorization for background tracking...")
            manager.requestAlwaysAuthorization()
        }
        
        // Safely enable background location updates (only if authorized)
        _ = safelyEnableBackgroundLocationUpdates()
        manager.pausesLocationUpdatesAutomatically = false
        
        // Use smart location request
        requestLocation(for: .activeWorkout)
    }
    
    func stopTracking() {
        print("📍 [SMART] Stopping tracking mode")
        isTracking = false
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
        
        // Stop location for this reason
        stopLocation(for: .activeWorkout)
    }
    
    func resetTracking() {
        locationHistory = []
        routeCoordinates = []
        totalDistance = 0
        currentSpeed = 0
        averageSpeed = 0
        elevationGain = 0
        currentPace = 0
        averagePace = 0
        calories = 0
        startTime = nil
        lastLocation = nil
        isTracking = false
    }
    
    // MARK: - Compatibility Helpers
    
    // These methods are provided for compatibility with code that might expect
    // LocationManager to have handlers rather than using Combine

    // This method allows you to synchronize with the legacy LocationManager
    func synchronizeWithLegacy(_ legacyManager: LocationManager) {
        // Note: LocationManager's properties (location, heading, authorizationStatus) are read-only
        // computed properties that return values from its underlying CLLocationManager.
        // Since both managers use separate CLLocationManager instances, we cannot directly
        // synchronize their read-only properties.
        //
        // The legacy LocationManager will automatically reflect values from its own
        // CLLocationManager instance when it's running. If synchronization is needed,
        // the legacy manager should be started/stopped independently, or the LocationManager
        // class would need to be modified to support settable properties.
        //
        // This method is kept for API compatibility but does not perform active synchronization
        // due to the read-only nature of LocationManager's properties.
    }

    func addLocationUpdateHandler(_ handler: @escaping (CLLocation) -> Void) {
        $location
            .compactMap { $0 }
            .sink { location in
                handler(location)
            }
            .store(in: &cancellables)
    }

    func addHeadingUpdateHandler(_ handler: @escaping (CLHeading) -> Void) {
        $heading
            .compactMap { $0 }
            .sink { heading in
                handler(heading)
            }
            .store(in: &cancellables)
    }

    func addAuthorizationStatusHandler(_ handler: @escaping (CLAuthorizationStatus) -> Void) {
        $authorizationStatus
            .sink { status in
                handler(status)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Dispatch to main thread for safe UI updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let oldStatus = self.authorizationStatus
            self.authorizationStatus = manager.authorizationStatus
            
            print("📍 Authorization changed: \(oldStatus.rawValue) → \(manager.authorizationStatus.rawValue)")
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                print("📍 [SMART] Authorization granted - waiting for explicit request")
                // CRITICAL: Force delegate to self
                if manager.delegate !== self {
                    print("⚠️ Delegate was hijacked! Forcing back to self")
                    manager.delegate = self
                }
                // DON'T auto-start location - use smart location management
                // Only start if there's an active usage reason
                if !activeUsageReasons.isEmpty {
                    print("📍 [SMART] Active reasons exist, starting location")
                    self.startUpdatingLocation()
                }
                if self.isTracking {
                    // Safely enable background location updates when authorization changes
                    _ = self.safelyEnableBackgroundLocationUpdates()
                    manager.pausesLocationUpdatesAutomatically = false
                }
            default:
                print("📍 Authorization not granted: \(manager.authorizationStatus.rawValue)")
                manager.stopUpdatingLocation()
                manager.allowsBackgroundLocationUpdates = false
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("🎉 SUCCESS: didUpdateLocations called with \(locations.count) locations")
        watchdogAttempts = 0 // Reset watchdog on success
        
        // Handle on main thread to avoid publishing from background
        DispatchQueue.main.async {
            // Reset error count when we get good locations
            self.locationFailureCount = 0
            
            // Process location updates
            if let location = locations.last {
                let now = Date()
                let timeSinceLastUpdate = now.timeIntervalSince(self.lastProcessedLocationTime)
                
                // Accept first location immediately; then accept any accuracy <= 65m within first 10s
                let isWithinWarmup = now.timeIntervalSince(self.lastProcessedLocationTime) == 0 ? true : (now.timeIntervalSince(self.lastProcessedLocationTime) < 10)
                
                print("📍 Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                print("📍 Accuracy: \(location.horizontalAccuracy)m")
                print("📍 Is first location: \(self.location == nil)")
                
                // CRITICAL: Accept first location regardless of accuracy
                // For subsequent locations, apply accuracy and time filtering
                let isFirstLocation = self.location == nil
                let hasGoodAccuracy = location.horizontalAccuracy <= 20 || (isWithinWarmup && location.horizontalAccuracy <= 65)
                let enoughTimePassed = timeSinceLastUpdate >= self.locationUpdateThrottleInterval
                
                if isFirstLocation {
                    print("📍 First location received: accuracy=\(location.horizontalAccuracy)m")
                    self.lastProcessedLocationTime = now
                    self.processLocationUpdate(location)
                } else if hasGoodAccuracy && enoughTimePassed {
                    print("📍 Subsequent location accepted")
                    self.lastProcessedLocationTime = now
                    self.processLocationUpdate(location)
                } else {
                    print("📍 Location rejected: goodAccuracy=\(hasGoodAccuracy), enoughTime=\(enoughTimePassed)")
                }
            }
        }
    }
    
    // CRITICAL FIX: Handle location errors gracefully
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Handle on main thread
        DispatchQueue.main.async {
            // Track consecutive failures
            self.locationFailureCount += 1
            
            // ALWAYS log first 5 errors, then every 10th
            if self.locationFailureCount <= 5 || self.locationFailureCount % 10 == 0 {
                print("❌ Location error (\(self.locationFailureCount)): \(error.localizedDescription)")
                if let clError = error as? CLError {
                    print("❌ CLError code: \(clError.code.rawValue)")
                    print("❌ CLError: \(clError)")
                }
            }
            
            // Post notification about the error so observers can react
            NotificationCenter.default.post(
                name: .locationErrorOccurred,
                object: self,
                userInfo: ["error": error]
            )
            
            // For permission errors, notify more specifically
            // CLError.Code doesn't have a 'restricted' member - use the correct codes
            if let clError = error as? CLError {
                // Check current authorization status to avoid misinterpreting errors
                let authStatus = CLLocationManager.authorizationStatus()
                
                // Check for permission-related errors
                switch clError.code {
                case .denied:
                    // Only treat as denied if authorization status is actually denied
                    if authStatus == .denied {
                        // User explicitly denied location authorization
                        print("📍 Location access denied by user")
                        NotificationCenter.default.post(
                            name: .locationPermissionDenied,
                            object: self
                        )
                    } else {
                        // Error code says denied but auth status doesn't match - likely notDetermined
                        print("📍 Location error with denied code but auth status is \(authStatus.rawValue) - likely notDetermined, not actual denial")
                        if authStatus == .notDetermined {
                            print("ℹ️ Permission not yet determined - request authorization first")
                        }
                    }
                case .locationUnknown:
                    // Location service couldn't determine location - this is temporary, retry
                    print("📍 Location unknown (temporary GPS issue) - will retry if authorized")
                    // Retry after a short delay if we have authorization
                    if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                            self?.requestLocation()
                        }
                    } else {
                        print("ℹ️ Not retrying - authorization status: \(authStatus.rawValue)")
                    }
                default:
                    // Other Core Location error
                    print("📍 Core Location error: \(clError.code)")
                }
            }
        }
    }
    
    // Helper method to calculate distance updates off the main thread
    private func calculateDistanceUpdates(with location: CLLocation) -> [String: Any] {
        var updates = [String: Any]()
        
        if let lastLocation = self.lastLocation {
            let segmentDistance = location.distance(from: lastLocation)
            updates["segmentDistance"] = segmentDistance
            
            // Calculate elevation gain if available
            if location.verticalAccuracy >= 0 && lastLocation.verticalAccuracy >= 0 {
                let elevationChange = location.altitude - lastLocation.altitude
                if elevationChange > 0 {
                    updates["elevationGain"] = elevationChange
                }
            }
            
            // Calculate speed
            if location.speed > 0 {
                updates["speed"] = location.speed
            }
        }
        
        updates["lastLocation"] = location
        return updates
    }
    
    // Apply the calculated updates on the main thread
    private func applyDistanceUpdates(_ updates: [String: Any]) {
        // These operations must run on the main thread
        if let segmentDistance = updates["segmentDistance"] as? Double, segmentDistance > 0 {
            totalDistance += segmentDistance
            distanceSegments.append(segmentDistance)
        }
        
        if let elevationGain = updates["elevationGain"] as? Double {
            self.elevationGain += elevationGain
        }
        
        if let speed = updates["speed"] as? Double {
            currentSpeed = speed
            speedReadings.append(speed)
            
            // Update average speed
            if !speedReadings.isEmpty {
                let validSpeeds = speedReadings.filter { $0 > 0 }
                if !validSpeeds.isEmpty {
                    averageSpeed = validSpeeds.reduce(0, +) / Double(validSpeeds.count)
                }
            }
        }
        
        if let newLastLocation = updates["lastLocation"] as? CLLocation {
            lastLocation = newLastLocation
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.heading = heading
        }
    }
    
    private func updatePace(with location: CLLocation) {
        // Calculate speed and pace
        if location.speed > 0 {
            currentSpeed = location.speed
            speedReadings.append(currentSpeed)
            averageSpeed = speedReadings.reduce(0, +) / Double(speedReadings.count)
            
            // Pace calculation (seconds per km or mile)
            currentPace = currentSpeed > 0 ? 1000 / currentSpeed : 0 // seconds per km
            
            if let startTime = startTime {
                let timeElapsed = Date().timeIntervalSince(startTime)
                averagePace = totalDistance > 0 ? timeElapsed / (totalDistance / 1000) : 0
            }
        }
        
        // Estimate calories (very rough estimate)
        // Assumes 70kg person, moderate intensity
        let caloriesPerKm = 65.0
        calories = (totalDistance / 1000.0) * caloriesPerKm
    }
    
    // Process location update after validation
    private func processLocationUpdate(_ location: CLLocation) {
        // Pre-calculate values to minimize work
        let currentCenter = self.region.center
        let newCenter = location.coordinate
        let distance = CLLocation(latitude: currentCenter.latitude, longitude: currentCenter.longitude)
            .distance(from: CLLocation(latitude: newCenter.latitude, longitude: newCenter.longitude))
        
        let shouldUpdateRegion = distance > 50 // If more than 50 meters from center
        let newRegion = shouldUpdateRegion ? MKCoordinateRegion(
            center: location.coordinate,
            span: self.region.span // Keep the current zoom level
        ) : self.region
        
        // Update location and region
        self.location = location
        
        // Cache the last known location for fallback use when location permission is denied
        UserDefaults.standard.set(location.coordinate.latitude, forKey: "lastKnownLatitude")
        UserDefaults.standard.set(location.coordinate.longitude, forKey: "lastKnownLongitude")
        UserDefaults.standard.synchronize()
        
        if shouldUpdateRegion {
            self.region = newRegion
        }
        
        // Only update tracking-related metrics if we're tracking
        if self.isTracking {
            // Add to route
            self.routeCoordinates.append(location.coordinate)
            
            // Update distance if we have a previous location
            if let lastLocation = self.lastLocation {
                let segmentDistance = location.distance(from: lastLocation)
                
                // Only add if it's a reasonable distance and accuracy
                if segmentDistance > 2.0 && location.horizontalAccuracy <= 20.0 {
                    self.totalDistance += segmentDistance
                    self.distanceSegments.append(segmentDistance)
                    
                    // Calculate elevation gain
                    if location.altitude > lastLocation.altitude {
                        self.elevationGain += location.altitude - lastLocation.altitude
                    }
                }
            }
            
            // Update speed/pace metrics if speed is available
            if location.speed > 0 {
                self.currentSpeed = location.speed
                self.speedReadings.append(self.currentSpeed)
                
                // Calculate average speed
                if !self.speedReadings.isEmpty {
                    let validSpeeds = self.speedReadings.filter { $0 > 0 }
                    if !validSpeeds.isEmpty {
                        self.averageSpeed = validSpeeds.reduce(0, +) / Double(validSpeeds.count)
                    }
                }
                
                // Calculate pace if we have distance and time
                if self.totalDistance > 0 && location.timestamp.timeIntervalSince(self.startTime ?? Date()) > 0 {
                    let elapsedTime = location.timestamp.timeIntervalSince(self.startTime ?? Date())
                    self.currentPace = elapsedTime / (self.totalDistance / 1000.0) // seconds per km
                    self.averagePace = elapsedTime / (self.totalDistance / 1000.0) // can be refined
                }
            }
        }
        
        // Always update the last location
        self.lastLocation = location
        
        // Notify listeners of location update
        NotificationCenter.default.post(
            name: .locationDidUpdate,
            object: self,
            userInfo: ["location": location]
        )
    }
    
    // MARK: - Background Operation
    
    func ensureLocationUpdates() {
        // Check authorization status first
        let status = manager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            print("⚠️ Location authorization not granted")
            return
        }
        
        // Safely ensure background updates are enabled
        _ = safelyEnableBackgroundLocationUpdates()
        manager.pausesLocationUpdatesAutomatically = false
        
        // Start location updates if not already running
        if manager.location == nil {
            startUpdatingLocation()
        }
        
        // Request a location update to keep the service active
        manager.requestLocation()
    }
    
    // MARK: - Watch Location Sync Methods
    
    /// Imports a complete set of locations from the watch
    func importLocations(_ locations: [CLLocation]) {
        print("📍 Importing \(locations.count) locations from watch")
        self.locationHistory = locations
        
        // Process the last location to update current position
        if let lastLocation = locations.last {
            self.processLocationUpdate(lastLocation)
            
            // Notify about the location update
            NotificationCenter.default.post(
                name: Notification.Name.locationDidUpdate,
                object: nil,
                userInfo: ["location": lastLocation]
            )
        }
    }
    
    /// Adds new locations from the watch to the existing array
    func supplementLocations(_ newLocations: [CLLocation]) {
        print("📍 Supplementing with \(newLocations.count) locations from watch")
        
        // Add only locations we don't already have
        var addedCount = 0
        for location in newLocations {
            // Skip if we already have a location with this timestamp
            if !self.locationHistory.contains(where: { 
                abs($0.timestamp.timeIntervalSince(location.timestamp)) < 0.01 
            }) {
                self.locationHistory.append(location)
                addedCount += 1
            }
        }
        
        print("📍 Added \(addedCount) new locations")
        
        // Sort locations by timestamp
        self.locationHistory.sort { $0.timestamp < $1.timestamp }
        
        // Process the last location
        if let lastLocation = newLocations.last {
            self.processLocationUpdate(lastLocation)
            
            // Notify about the location update
            NotificationCenter.default.post(
                name: Notification.Name.locationDidUpdate,
                object: nil,
                userInfo: ["location": lastLocation]
            )
        }
    }
} 
