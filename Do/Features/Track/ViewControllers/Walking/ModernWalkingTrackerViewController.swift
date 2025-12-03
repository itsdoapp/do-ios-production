

//
//  ModernWalkingTrackerViewController.swift
//  Do.
//
//  Created by Mikiyas Meseret on 3/12/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//


import SwiftUI
import UIKit
import CoreLocation
import MapKit
import HealthKit
import Combine
import WatchConnectivity
import Foundation
import Lottie
import WeatherKit

// Import the Track controller to access it directly
import Foundation
// The file that contains the Track class
// Add any other imports needed for the Track class

class ModernWalkingTrackerViewController: UIViewController, ObservableObject, CLLocationManagerDelegate, CategorySwitchable, WCSessionDelegate, OutdoorWalkViewControllerDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        DispatchQueue.main.async {
            print("📱 WCSession activation completed with state: \(activationState.rawValue)")
            if let error = error {
                print("📱 WCSession activation error: \(error.localizedDescription)")
            }
            
            // Check for active watch workouts after activation completes
            if activationState == .activated {
                self.checkForActiveWatchWorkouts()
            }
        }
    }
    
    /// Starts a periodic sync to the watch pushing trackingStatus using the engine's updateApplicationContext (every 5s)
    private func startWatchSync() {
        // Invalidate any existing timer first
        watchSyncTimer?.invalidate()
        watchSyncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let session = WCSession.default
            guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
            
            // Delegate payload building and reliable sending to the engine (mirrors Run)
            (self.walkingTracker as? WalkTrackingEngine)?.updateApplicationContext()
        }
    }
    
    /// Stops the periodic watch sync
    private func stopWatchSync() {
        watchSyncTimer?.invalidate()
        watchSyncTimer = nil
    }
    
    
    // MARK: - Map Position Enum
    enum MapPosition {
        case minimized
        case fullscreen
        case hidden
    }
    
    // MARK: - Properties
    
    weak var categoryDelegate: CategorySelectionDelegate?
    public var hostingController: UIHostingController<WalkingTrackerView>?
    public var walkingTracker = WalkTrackingEngine.shared
    private var cancellables = Set<AnyCancellable>()
    public let routePlanner = RoutePlanner.shared
    @Published private var mapPosition: MapPosition = .minimized
    @Published var routesForceRefreshID = UUID() // For forcing view refresh
    private var isWalking = false
    public var hasLoadedRoutes = false
    private var locationManager = ModernLocationManager.shared
    private let weatherService = WeatherService.shared
    
    // Route information
    @Published var selectedRoute: Trail?
    
    // Weather state
    @Published var weatherDataLoaded = false
    @Published var locationCity = "Loading location..."
    @Published var temperature: Double = 0.0
    @Published var humidity: Double = 0.0
    @Published var windSpeed: Double = 0.0
    @Published var weatherCondition: WeatherCondition = .unknown
    @Published var weatherIconName = "cloud"
    @Published var isNightMode = false
    @Published var forecastDescription = "Checking forecast..."
    // Walking history data
    private var outdoorWalkingLogs: [WalkLog] = []
    private var indoorWalkingLogs: [IndoorWalkLog] = []
    @Published var hasLoadedWalkingHistory: Bool = false
    private var isLoadingWalkingHistory: Bool = false
    
    // Active watch workout detection
    @Published var hasActiveWatchWorkout: Bool = false
    @Published var activeWorkoutData: ActiveWatchWorkoutData? = nil
    
    // Message batching for watch communication
    private var lastSyncDataProcessTime = Date(timeIntervalSince1970: 0)
    private var pendingSyncMessages: [[String: Any]] = []
    // Periodic sync timer for watch updates (mirrors running)
    private var watchSyncTimer: Timer?
    // Prevent duplicate prompts
    private var didShowJoinPromptFromWatch: Bool = false
    
    // Route loading cache
    private var lastRouteLoadTime: Date?
    private var lastRouteLoadLocation: CLLocation?
    
    // Walking type
    // MARK: - UI Outlets
    private var mapView: MKMapView!
    private var distanceLabel: UILabel!
    private var paceLabel: UILabel!
    private var durationLabel: UILabel!
    private var caloriesLabel: UILabel!
    private var startStopButton: UIButton!
    
    
    
    // Main container views
    private let mainContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(hex: "#0A0F1E") // Darker, more premium background
        return view
    }()
    
    private let contentScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 24 // Increased spacing for better visual separation
        stack.alignment = .fill
        stack.distribution = .fill
        return stack
    }()
    
    // MapView container
    private let mapContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(hex: "#0F1A45").withAlphaComponent(0.7)
        view.layer.cornerRadius = 24
        
        // Add shadow for depth
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.3
        return view
    }()
    
    // Stats container
    private let statsContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(hex: "#0F1A45").withAlphaComponent(0.7)
        view.layer.cornerRadius = 24
        
        // Add subtle gradient overlay
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(hex: "#0F1A45").withAlphaComponent(0.7).cgColor,
            UIColor(hex: "#1A2C65").withAlphaComponent(0.5).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 24
        view.layer.insertSublayer(gradientLayer, at: 0)
        
        // Add shadow for depth
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.3
        return view
    }()
    
    // Controls container
    private let controlsContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(hex: "#0F1A45").withAlphaComponent(0.8)
        view.layer.cornerRadius = 26
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        
        // Add shadow for depth
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: -3)
        view.layer.shadowRadius = 6
        view.layer.shadowOpacity = 0.2
        return view
    }()
    
    // Start/Stop button
    private let mainActionButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("START WALK", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 30
        
        // Create gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(hex: "#20B2AA").cgColor, // Light sea green for walking
            UIColor(hex: "#008B8B").cgColor  // Dark cyan
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        gradientLayer.cornerRadius = 30
        button.layer.insertSublayer(gradientLayer, at: 0)
        
        // Add shadow
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowRadius = 6
        button.layer.shadowOpacity = 0.4
        
        return button
    }()
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWalkingTracker()
        
        // Setup WCSession for watch communication
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        
        // Debug: check Lottie animation files
        ensureLottieAnimationFiles()
        
        setupHostingController()
        
        // Observe changes to UserPreferences
        observePreferencesChanges()
        
        // Add observer for walking selection from history
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWalkingSelected),
            name: Notification.Name("WalkingSelected"),
            object: nil
        )
        
        // Request location authorization if needed
        requestLocationAuthorizationIfNeeded()
        
        // Observe location authorization changes
        observeLocationAuthorization()
        
        // Listen for partial route updates from background tail processing
        NotificationCenter.default.addObserver(self, selector: #selector(didUpdateNearbyTrails(_:)), name: .didUpdateNearbyTrails, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // End initial load timer immediately - view is now visible
        PerformanceLogger.end("Track:initialLoad", extra: "view appeared")
        
        // Check and update hosting controller
        if let hostingView = hostingController?.view {
            // Find and configure scroll views
            findAndConfigureScrollViews(in: hostingView)
        }
        
        // Check for active watch workouts when the view appears
        print("📱 DIAGNOSTIC: ViewDidAppear called, checking for watch workouts...")
        checkForActiveWatchWorkouts()
        
        // Start periodic watch sync loop
        startWatchSync()
        
        // Show cached data immediately if available
        showCachedDataIfAvailable()
        
        // Load fresh data in background (non-blocking)
        if !hasLoadedInitialData {
            Task {
                // Load weather and routes in parallel for faster loading
                async let weatherTask = loadWeatherData()
                async let routesTask = fetchRoutes()
                
                // Wait for weather and routes (critical for UI)
                await weatherTask
                await routesTask
                
                // Stop location updates now that we have what we need
                ModernLocationManager.shared.stopLocation(for: .routeDisplay)
                
                // Load history in background (non-critical, can be deferred)
                Task.detached(priority: .utility) {
                    await MainActor.run {
                        self.loadWalkingHistory()
                    }
                }
            }
            hasLoadedInitialData = true
        }
    }
    
    private var hasLoadedInitialData = false
    
    /// Show cached weather and routes data immediately if available
    private func showCachedDataIfAvailable() {
        // Show cached weather if available and still valid
        if let cachedWeather = weatherService.currentWeather,
           let lastLocation = weatherService.lastLocation,
           let lastFetchTime = weatherService.lastWeatherFetchTime,
           Date().timeIntervalSince(lastFetchTime) < 3600, // Less than 1 hour old
           let currentLocation = locationManager.location,
           currentLocation.distance(from: lastLocation) < 1000 { // Within 1km
            print("📦 Showing cached weather data immediately")
            weatherCondition = cachedWeather.condition
            temperature = cachedWeather.temperature
            humidity = cachedWeather.humidity
            windSpeed = cachedWeather.windSpeed
            let isNight = Calendar.current.component(.hour, from: Date()) < 6 || Calendar.current.component(.hour, from: Date()) > 18
            weatherIconName = getWeatherIcon(for: cachedWeather.condition, isNight: isNight)
            forecastDescription = generateForecastDescription(cachedWeather)
            weatherDataLoaded = true
        }
        
        // Show cached routes if available
        if !RoutePlanner.shared.nearbyTrails.isEmpty {
            print("📦 Showing \(RoutePlanner.shared.nearbyTrails.count) cached routes")
            hasLoadedRoutes = true
            routesForceRefreshID = UUID()
        }
    }
    
    @objc private func didUpdateNearbyTrails(_ note: Notification) {
        guard let extra = note.object as? [Trail] else { return }
        var current = Array(RoutePlanner.shared.nearbyTrails)
        current.append(contentsOf: extra)
        let unique = Dictionary(grouping: current, by: { $0.id }).compactMap { $0.value.first }
        RoutePlanner.shared.setTrails(unique)
        // Trigger UI refresh
        routesForceRefreshID = UUID()
    }
    // Add a debouncing mechanism
    private var preferencesDebounceTimer: Timer?
    @objc private func userPreferencesDidChange() {
        print("🔄 User preferences changed notification received")
        
        // Cancel any existing timer
        preferencesDebounceTimer?.invalidate()
        
        // Create a new timer that will fire after a short delay
        preferencesDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            //            self.handlePreferencesChange()
        }
    }
    
    func ensureLottieAnimationFiles() {
        print("Checking Lottie animation availability...")
        
        // Print bundle paths for debugging
        if let resourcePath = Bundle.main.resourcePath {
            print("Resource path: \(resourcePath)")
        }
        
        // Try to load a test animation
        if let _ = LottieAnimation.named("day_partly_cloudy") {
            print("Successfully loaded day_partly_cloudy animation")
        } else {
            print("Failed to load day_partly_cloudy animation, will use SF Symbol fallbacks")
        }
        
        // Check document directory
        let fileManager = FileManager.default
        if let docDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            print("Document directory: \(docDir.path)")
            
            let animDir = docDir.appendingPathComponent("Animations")
            if !fileManager.fileExists(atPath: animDir.path) {
                do {
                    try fileManager.createDirectory(at: animDir, withIntermediateDirectories: true)
                    print("Created animations directory at: \(animDir.path)")
                } catch {
                    print("Error creating document animations directory: \(error)")
                }
            }
        }
    }
    
    func fetchRoutes(forceRefresh: Bool = false) {
        let routePlanner = RoutePlanner.shared
        
        // Always fetch fresh routes when switching categories or if force refresh is requested
        // Don't skip if we have routes - they might be from a different category
        if !forceRefresh && !routePlanner.nearbyTrails.isEmpty {
            // Check if routes are recent (less than 5 minutes old) and location hasn't changed much
            // If so, we can use cached routes, otherwise fetch fresh ones
            if let lastLoadTime = lastRouteLoadTime,
               Date().timeIntervalSince(lastLoadTime) < 300, // Less than 5 minutes
               let currentLocation = locationManager.location {
                // Check if location hasn't changed significantly (within 500m)
                if let cachedLocation = lastRouteLoadLocation,
                   currentLocation.distance(from: cachedLocation) < 500 {
                    print("✓ Using cached routes - \(routePlanner.nearbyTrails.count) routes available (recent & same location)")
                    hasLoadedRoutes = true
                    return
                }
            }
            // Routes exist but are stale or location changed - clear and fetch fresh
            print("🔄 Routes exist but are stale or location changed - fetching fresh routes")
            routePlanner.clearTrails()
        }
        
        print("🔄 Fetching routes...")
        
        // Reset state if force refreshing
        if forceRefresh {
            print("🔄 Force refreshing routes")
            
            // Clear existing routes to ensure UI refresh
            routePlanner.clearTrails()
            
            // Send change notifications
            objectWillChange.send()
            routesForceRefreshID = UUID()
        }
        
        // Get the user's current location if available
        var userLocation: CLLocationCoordinate2D? = nil
        if let location = locationManager.location {
            userLocation = location.coordinate
        }
        
        // Now fetch the routes (this uses a cached location if one isn't available)
        Task {
            // Use the walking-specific find method
            routePlanner.findWalkingTrails(radius: 3000) { [weak self] success in
                guard let self = self else { return }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    // Mark routes as loaded first
                    self.hasLoadedRoutes = true
                    
                    // Update cache timestamp and location
                    self.lastRouteLoadTime = Date()
                    self.lastRouteLoadLocation = self.locationManager.location
                    
                    // Force refresh IDs to ensure SwiftUI updates
                    self.routesForceRefreshID = UUID()
                    
                    // Send change notifications
                    self.objectWillChange.send()
                    
                    // Post notification about routes update
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RoutesUpdated"),
                        object: nil,
                        userInfo: ["timestamp": Date()]
                    )
                    
                    // Remove duplicate print message
                    print("📱 UI updated with available routes")
                }
            }
        }
    }
    
    public func observePreferencesChanges() {
        // Observe when user preferences change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userPreferencesDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    // Present history helper for SwiftUI action
    func presentHistory() {
        let historyVC = WalkHistoryViewController()
        let nav = UINavigationController(rootViewController: historyVC)
        
        // Set up for popup presentation with drag-to-dismiss
        nav.modalPresentationStyle = .pageSheet
        
        // Configure for drag-to-dismiss
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        self.present(nav, animated: true)
    }
    // Present settings view (reusing Run settings for consistency)
    func presentSettings() {
        let controller = UIHostingController(rootView: RunSettingsView())
        controller.modalPresentationStyle = .formSheet
        present(controller, animated: true)
    }
    // Start walk from SwiftUI button
    @objc func startWalk() {
        // Request location authorization before starting
        requestLocationAuthorizationIfNeeded()
        
        print("🚶‍♂️ Starting outdoor walk")
        let vc = OutdoorWalkViewController()
        vc.delegate = self
        if let trail = self.selectedRoute {
            vc.preSelectedRoute = Route(from: trail)
        }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }
    // Handle walking selection from history
    @objc private func handleWalkingSelected(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let selectedWalking = userInfo["selectedWalking"] {
            didSelectWalking(selectedWalking)
        }
    }
    
    private func updateLocationName(for location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Geocoding error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    if self.locationCity == "Loading location..." {
                        // Only update if we don't have a better location already
                        self.locationCity = "Location unavailable"
                    }
                }
                return
            }
            
            guard let placemark = placemarks?.first else {
                print("❌ No placemarks found")
                DispatchQueue.main.async {
                    if self.locationCity == "Loading location..." {
                        self.locationCity = "Location unavailable"
                    }
                }
                return
            }
            
            // Construct location string
            let city = placemark.locality ?? ""
            let state = placemark.administrativeArea ?? ""
            let country = placemark.country ?? ""
            
            var formattedLocation = city
            
            if country == "United States" || country == "USA" {
                if !state.isEmpty { formattedLocation += ", \(state)" }
            } else {
                if !country.isEmpty { formattedLocation += ", \(country)" }
            }
            
            print("📍 Location geocoded: \(formattedLocation)")
            
            DispatchQueue.main.async {
                self.locationCity = formattedLocation.isEmpty ? "Location unavailable" : formattedLocation
            }
        }
    }
    
    // Determine if it's night time based on the current hour
    private func updateNightMode() {
        let hour = Calendar.current.component(.hour, from: Date())
        self.isNightMode = hour < 6 || hour > 18
    }
    
    // Request authorization if needed. If denied/restricted, guide user to Settings
    private func requestLocationAuthorizationIfNeeded() {
        let status = CLLocationManager.authorizationStatus()
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            // Ensure precise accuracy if reduced
            ModernLocationManager.shared.ensurePreciseAccuracyIfNeeded()
            return
        case .notDetermined:
            print("📱 Requesting location authorization...")
            locationManager.manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("❌ Location permission denied/restricted. Prompting user to open Settings…")
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        @unknown default:
            return
        }
    }
    
    // MARK: - Location Authorization Monitoring
    
    private func observeLocationAuthorization() {
        // Observe location authorization status changes
        locationManager.$authorizationStatus
            .sink { [weak self] status in
                guard let self = self else { return }
                print("📍 Location authorization changed: \(status.rawValue)")
                
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    print("✅ Location granted! Loading weather/routes with cached location…")
                    
                    // Use cached location if available, otherwise request one-time location
                    if let cachedLocation = self.locationManager.location,
                       Date().timeIntervalSince(cachedLocation.timestamp) < 600 {
                        print("📍 Using cached location (age: \(Int(Date().timeIntervalSince(cachedLocation.timestamp)))s)")
                        Task { @MainActor [weak self] in
                            await self?.fetchRoutes()
                            await self?.loadWeatherData()
                            // Stop location updates after loading
                            ModernLocationManager.shared.stopLocation(for: .routeDisplay)
                        }
                    } else {
                        print("📍 No cached location or stale - requesting one-time location…")
                        // Request single location fix for initial data load
                        ModernLocationManager.shared.requestLocation(for: .routeDisplay)
                        // Reload routes and weather when location becomes available
                        Task { @MainActor [weak self] in
                            await self?.fetchRoutes()
                            await self?.loadWeatherData()
                            // Stop location updates after loading
                            ModernLocationManager.shared.stopLocation(for: .routeDisplay)
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    deinit {
        // Remove observers
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        UIApplication.shared.isIdleTimerDisabled = true // Prevent screen sleep
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        UIApplication.shared.isIdleTimerDisabled = false
        // Stop watch sync when view disappears
        stopWatchSync()
    }
    
    /// Checks if there's an active workout on the watch and prepares data for the card UI
    private func checkForActiveWatchWorkouts() {
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else {
            print("📱 DIAGNOSTIC: Watch app not available - activation: \(session.activationState.rawValue), paired: \(session.isPaired), installed: \(session.isWatchAppInstalled)")
            return
        }
        
        print("📱 DIAGNOSTIC: Sending active walking workout check to watch...")
        
        // Use the walking-specific request to mirror Running flow correctly
        let message: [String: Any] = [
            "type": "requestActiveWalkingWorkout",
            "workoutType": "walk",
            "timestamp": Date().timeIntervalSince1970
        ]
        session.sendMessage(message, replyHandler: { [weak self] response in
            print("📱 DIAGNOSTIC: Received watch response: \(response)")
            
            // Process response on main thread to avoid background thread publishing
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Check for the specific format we're seeing in the logs where the watch just acknowledges receipt
                if let type = response["type"] as? String, type == "requestActiveWalkingWorkout",
                   let status = response["status"] as? String, status == "received" {
                    
                    print("📱 Watch acknowledged our request but didn't provide workout data")
                    
                    // Instead of directly setting hasActiveWatchWorkout to false, check if we have
                    // data from syncWorkoutData messages that might indicate an active workout
                    if let activeWorkoutData = self.activeWorkoutData, activeWorkoutData.distance > 0 {
                        print("📱 Using existing active workout data from syncWorkoutData messages")
                        return // Keep existing workout data
                    }
                    
                    // Otherwise reset as there's no active workout
                    self.hasActiveWatchWorkout = false
                    self.activeWorkoutData = nil
                    self.objectWillChange.send()
                    return
                }
                
                // The standard processing for full workout data response
                // Reset active workout state first
                self.hasActiveWatchWorkout = false
                self.activeWorkoutData = nil
                
                // Extract workout information from response - check both workoutActive and hasActiveWorkout
                let isActive = (response["workoutActive"] as? Bool) ?? (response["hasActiveWorkout"] as? Bool) ?? false
                let workoutState = response["state"] as? String ?? ""
                let isValidState = workoutState == "inProgress" || workoutState == "paused" ||
                workoutState == "running" || workoutState == "active"
                
                if isActive && isValidState {
                    print("📱 DIAGNOSTIC: Active workout found on watch: \(workoutState)")
                    
                    // Get workout details - ensure we have default values to prevent nil issues
                    let isIndoorMode = response["isIndoor"] as? Bool ?? false
                    let distance = response["distance"] as? Double ?? 0
                    let elapsedTime = response["elapsedTime"] as? Double ?? 0
                    let heartRate = response["heartRate"] as? Double ?? 0
                    let calories = response["calories"] as? Double ?? 0
                    let cadence = response["cadence"] as? Double ?? 0
                    let pace = response["pace"] as? Double ?? 0
                    let steps = response["steps"] as? Int ?? 0
                    
                    // Extract start time
                    var startDate = Date(timeIntervalSinceNow: -elapsedTime)
                    if let startTimestamp = response["startDate"] as? TimeInterval {
                        startDate = Date(timeIntervalSince1970: startTimestamp)
                    } else if let startTimestamp = response["startTime"] as? TimeInterval {
                        startDate = Date(timeIntervalSince1970: startTimestamp)
                    }
                    
                    // Map state values to expected format
                    let normalizedState: String
                    switch workoutState {
                    case "running", "active":
                        normalizedState = "inProgress"
                    default:
                        normalizedState = workoutState
                    }
                    
                    // Create the active workout data object
                    let workoutData = ActiveWatchWorkoutData(
                        isIndoor: isIndoorMode,
                        state: normalizedState,
                        distance: distance,
                        elapsedTime: elapsedTime,
                        heartRate: heartRate,
                        calories: calories,
                        cadence: cadence,
                        pace: pace,
                        startDate: startDate,
                        rawData: response
                    )
                    
                    // Update UI directly on main thread (we're already in main thread)
                    print("📱 DIAGNOSTIC: Setting activeWorkoutData and hasActiveWatchWorkout=true")
                    self.activeWorkoutData = workoutData
                    self.hasActiveWatchWorkout = true
                    
                    // Send the objectWillChange notification to refresh existing views
                    self.objectWillChange.send()
                    // Start periodic sync now that we've joined an active workout
                    self.startWatchSync()
                } else {
                    print("📱 DIAGNOSTIC: No active workout found on watch. isActive: \(isActive), state: \(workoutState)")
                }
            }
        }, errorHandler: { error in
            print("📱 DIAGNOSTIC: Error checking for active workout: \(error.localizedDescription)")
        })
    }
    
    // New helper method to configure scroll views
    private func findAndConfigureScrollViews(in view: UIView) {
        // Process this view if it's a scroll view
        if let scrollView = view as? UIScrollView {
            scrollView.panGestureRecognizer.cancelsTouchesInView = false
            scrollView.delaysContentTouches = false
        }
        
        // Process subviews recursively
        for subview in view.subviews {
            findAndConfigureScrollViews(in: subview)
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupWalkingTracker() {
        // Initialize the walking tracker and set up the current user
        // Get user ID from UserIDHelper (uses Cognito, then fallbacks)
        if let userId = UserIDHelper.shared.getCurrentUserID() {
            walkingTracker.setCurrentUser(userId)
            walkingTracker.currentUser = userId
        }
        
        // Setup background capability
        walkingTracker.setupBackgroundCapabilities()
    }
    
    private func setupHostingController() {
        // Create the walking tracker view with both the view model and walking tracking engine
        let walkingTrackerView = WalkingTrackerView(
            viewModel: self,
            walkingTrackingEngine: WalkTrackingEngine.shared,
            categoryDelegate: self.categoryDelegate
        )
        
        // Create the hosting controller with the view
        hostingController = UIHostingController(rootView: walkingTrackerView)
        
        if let hostingController = hostingController {
            addChild(hostingController)
            view.addSubview(hostingController.view)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            hostingController.didMove(toParent: self)
        }
    }
    
    // Walking type
    private var selectedWalkingType: WalkingType = .outdoorWalk
    
    // MARK: - Weather Methods
    
    // Keep the cycleWeather method for backward compatibility but don't use it
    private func cycleWeather() {
        // This method is kept for compatibility but should not be used
        print("Warning: cycleWeather is deprecated, use loadWeatherData() instead")
    }
    
    public func loadWeatherData() async {
        print("📱 ModernWalkingTrackerViewController: Starting weather data loading")
        
        // Initialize weather state - but preserve existing weather data to avoid losing animation
        await MainActor.run {
            // Only reset weatherDataLoaded if we don't have any weather data yet
            // This prevents the animation from disappearing when refreshing weather
            if !self.weatherDataLoaded || self.weatherCondition == .unknown {
                self.weatherDataLoaded = false
            }
            self.forecastDescription = "Checking forecast..."
            
            // Set loading state but don't reset temperature to avoid flicker if we have data
            if self.temperature == 0.0 {
                self.locationCity = "Loading location..."
            }
        }
        
        // Update night mode based on current time
        updateNightMode()
        
        if let location = locationManager.location {
            // Get weather data
            print("📍 Fetching weather for: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            
            // Launch geocoding in parallel with weather fetch for efficiency
            updateLocationName(for: location)
            
            let (data, error) = await weatherService.fetchWeather(for: location)
            
            if let data = data {
                if UserPreferences.shared.useMetricSystem == false {
                    let fahrenheit = (data.temperature * 9/5) + 32
                }
                
                // Update all weather properties on main thread
                await MainActor.run {
                    // Make sure we're actually updating with new values
                    self.temperature = data.temperature
                    self.humidity = data.humidity
                    self.windSpeed = data.windSpeed
                    self.weatherCondition = data.condition
                    
                    // Use the improved icon selection
                    let isNight = Calendar.current.component(.hour, from: Date()) < 6 || Calendar.current.component(.hour, from: Date()) > 18
                    self.weatherIconName = self.getWeatherIcon(for: data.condition, isNight: isNight)
                    
                    // Generate a forecast description based on the weather
                    self.forecastDescription = self.generateForecastDescription(data)
                    
                    self.weatherDataLoaded = true
                    
                    // Test the temperature formatting to verify it's working
                    let formattedTemp = self.formatTemperature(self.temperature)
                    print("🌡️ Formatted real temperature: \(formattedTemp) from \(self.temperature)°C")
                }
            } else {
                // Handle weather loading error
                await MainActor.run {
                    if let error = error {
                        print("❌ Error loading weather: \(error.localizedDescription)")
                        self.forecastDescription = "Weather data unavailable"
                    } else {
                        print("❌ Unknown error loading weather")
                        self.forecastDescription = "Weather data unavailable"
                    }
                    
                    // Preserve existing weather condition if we have one, otherwise set to clear as fallback
                    // This prevents the animation from disappearing on error
                    if self.weatherCondition == .unknown {
                        self.weatherCondition = .clear // Default to clear instead of unknown
                    }
                    
                    // Show weather view with error message (preserve existing data)
                    self.weatherDataLoaded = true
                    if self.weatherIconName.isEmpty {
                        self.weatherIconName = "exclamationmark.triangle"
                    }
                }
            }
        } else {
            // Location services unavailable
            await MainActor.run {
                self.locationCity = "Location services unavailable"
                self.forecastDescription = "Weather data unavailable"
                self.weatherDataLoaded = true
                self.weatherIconName = "location.slash"
            }
        }
    }
    
    // Helper method to format temperature according to user preferences
    public func formatTemperature(_ temp: Double) -> String {
        if temp == 0.0 {
            return UserPreferences.shared.useMetricSystem ? "-- °C" : "-- °F"
        }
        
        if UserPreferences.shared.useMetricSystem {
            return "\(Int(round(temp)))°C"
        } else {
            // Convert Celsius to Fahrenheit: (C * 9/5) + 32
            let fahrenheit = (temp * 9/5) + 32
            return "\(Int(round(fahrenheit)))°F"
        }
    }
    
    public func generateForecastDescription(_ data: WeatherData) -> String {
        let temp = data.temperature
        let condition = data.condition
        let windSpeed = data.windSpeed
        let humidity = data.humidity
        let precipChance = data.precipitationChance ?? 0
        let precipAmount = data.precipitationAmount ?? 0
        
        var description = ""
        
        // Temperature description
        if temp > 30 {
            description += "It's very hot "
        } else if temp > 25 {
            description += "It's warm "
        } else if temp > 15 {
            description += "It's mild "
        } else if temp > 5 {
            description += "It's cool "
        } else if temp > 0 {
            description += "It's cold "
        } else {
            description += "It's freezing "
        }
        
        // Add condition description
        switch condition {
        case .clear:
            let hour = Calendar.current.component(.hour, from: Date())
            if hour >= 6 && hour <= 18 {
                description += "with clear skies"
            } else {
                description += "with a clear night sky"
            }
        case .partlyCloudy:
            description += "with some clouds"
        case .cloudy:
            description += "and cloudy"
        case .rainy:
            if precipAmount > 10 {
                description += "with heavy rain"
            } else if precipAmount > 5 {
                description += "with moderate rain"
            } else {
                description += "with light rain"
            }
        case .stormy:
            description += "with thunderstorms"
        case .snowy:
            if precipAmount > 5 {
                description += "with heavy snow"
            } else {
                description += "with light snow"
            }
        case .foggy:
            description += "and foggy"
        case .windy:
            description += "and windy"
        case .unknown:
            description += "with changing conditions"
        }
        
        // Add additional details if significant
        if windSpeed > 30 {
            description += ", strong winds"
        } else if windSpeed > 20 {
            description += ", breezy"
        }
        
        if humidity > 80 && condition != .rainy && condition != .stormy {
            description += ", high humidity"
        }
        
        // Add precipitation chance if applicable and not already mentioned rain
        if precipChance > 50 && condition != .rainy && condition != .stormy && condition != .snowy {
            description += ", precipitation likely"
        } else if precipChance > 30 && condition != .rainy && condition != .stormy && condition != .snowy {
            description += ", chance of precipitation"
        }
        
        return description
    }
    
    public func getWeatherIcon(for condition: WeatherCondition, isNight: Bool) -> String {
        switch condition {
        case .clear:
            return isNight ? "moon.stars.fill" : "sun.max.fill"
        case .cloudy:
            return "cloud.fill"
        case .partlyCloudy:
            return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        case .rainy:
            return "cloud.rain.fill"
        case .stormy:
            return "cloud.bolt.rain.fill"
        case .snowy:
            return "cloud.snow.fill"
        case .foggy:
            return "cloud.fog.fill"
        case .windy:
            return "wind"
        case .unknown:
            return "questionmark.diamond.fill"
        }
    }
    
    private func loadWalkingHistory() {
        if isLoadingWalkingHistory {
            return
        }
        
        isLoadingWalkingHistory = true
        
        // Check if we already have cached data
        if !outdoorWalkingLogs.isEmpty {
            self.hasLoadedWalkingHistory = true
            self.isLoadingWalkingHistory = false
            return
        }
        
        // Use background queue for async operations
        DispatchQueue.global(qos: .userInitiated).async {
            let dispatchGroup = DispatchGroup()
            
            // Load outdoor walking
            dispatchGroup.enter()
            self.getWalkingLogs { (walks, error) in
                defer { dispatchGroup.leave() }
                if let error = error {
                    print("Error fetching outdoor walks: \(error.localizedDescription)")
                    return
                }
                
                self.outdoorWalkingLogs = walks ?? []
            }
            
            // Load indoor walking
            dispatchGroup.enter()
            
            // Update UI when both are complete
            dispatchGroup.notify(queue: .main) {
                self.hasLoadedWalkingHistory = true
                self.isLoadingWalkingHistory = false
            }
        }
    }
    
    // MARK: - Get Walking Logs
    
    /// Fetches walking logs from AWS using ActivityService
    /// - Parameter completion: Completion handler with array of WalkLog or error
    func getWalkingLogs(completion: @escaping ([WalkLog]?, Error?) -> Void) {
        // Get current user ID
        guard let userId = UserIDResolver.shared.getBestUserIdForAPI(), !userId.isEmpty else {
            print("❌ [ModernWalkingTracker] No user ID available")
            completion(nil, NSError(domain: "ModernWalkingTracker", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        print("📥 [ModernWalkingTracker] Fetching walking logs for user: \(userId)")
        
        // Fetch all walks with pagination
        var allWalkLogs: [WalkLog] = []
        
        func fetchPage(nextToken: String?) {
            ActivityService.shared.getWalks(
                userId: userId,
                limit: 50,
                nextToken: nextToken,
                includeRouteUrls: true
            ) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let response):
                    guard let data = response.data else {
                        // No more data, return what we have
                        completion(allWalkLogs, nil)
                        return
                    }
                    
                    // Convert and append activities from this page
                    let pageLogs = data.activities.compactMap { activity -> WalkLog? in
                        guard !activity.isIndoorWalk else { return nil }
                        return self.convertAWSActivityToWalkLog(activity)
                    }
                    allWalkLogs.append(contentsOf: pageLogs)
                    
                    print("📄 [ModernWalkingTracker] Fetched page with \(pageLogs.count) walks (Total: \(allWalkLogs.count))")
                    
                    // Check if there are more pages
                    if data.hasMore, let token = data.nextToken {
                        fetchPage(nextToken: token)
                    } else {
                        // All pages fetched
                        print("✅ [ModernWalkingTracker] Fetched all walks from AWS: \(allWalkLogs.count) total")
                        completion(allWalkLogs, nil)
                    }
                    
                case .failure(let error):
                    print("❌ [ModernWalkingTracker] Error fetching walking logs: \(error.localizedDescription)")
                    // Return what we have so far, or empty array if nothing fetched
                    completion(allWalkLogs.isEmpty ? nil : allWalkLogs, error)
                }
            }
        }
        
        // Start fetching from the first page
        fetchPage(nextToken: nil)
    }
    
    // Helper methods for calculating statistics
    func calculateThisWeekDistance() -> Double {
        let calendar = Calendar.current
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            return 0.0
        }
        
        var totalDistanceMeters: Double = 0.0
        
        // Helper function to parse distance string (e.g., "2.5 mi" or "4.2 km") to meters
        func parseDistanceToMeters(_ distanceString: String) -> Double {
            let trimmed = distanceString.trimmingCharacters(in: .whitespaces)
            // Extract numeric value
            let numericString = trimmed.replacingOccurrences(of: "[^0-9\\.]", with: "", options: .regularExpression)
            guard let value = Double(numericString) else { return 0.0 }
            
            // Check unit and convert to meters
            if trimmed.lowercased().contains("mi") || trimmed.lowercased().contains("mile") {
                return value * 1609.34 // miles to meters
            } else if trimmed.lowercased().contains("km") || trimmed.lowercased().contains("kilometer") {
                return value * 1000.0 // km to meters
            } else {
                // Assume meters if no unit specified
                return value
            }
        }
        
        // Add outdoor walking distance
        for walk in outdoorWalkingLogs {
            if let date = walk.createdAt, date >= startOfWeek {
                if let distanceString = walk.distance {
                    totalDistanceMeters += parseDistanceToMeters(distanceString)
                }
            }
        }
        
        // Add indoor walking distance
        for walk in indoorWalkingLogs {
            if let date = walk.createdAt, date >= startOfWeek {
                if let distanceString = walk.distance {
                    totalDistanceMeters += parseDistanceToMeters(distanceString)
                }
            }
        }
        
        return totalDistanceMeters
    }
    
    func calculateAveragePace() -> String {
        var paceSum: Double = 0.0
        var paceCount: Int = 0
        
        // Process outdoor walking
        for walk in outdoorWalkingLogs.prefix(10) { // Consider only the most recent 10 walks
            if let paceString = walk.avgPace {
                let components = paceString.components(separatedBy: "'")
                if components.count >= 2,
                   let minutes = Double(components[0]) {
                    let secondsString = components[1].replacingOccurrences(of: "\"", with: "")
                    if let seconds = Double(secondsString) {
                        let paceInSeconds = minutes * 60 + seconds
                        paceSum += paceInSeconds
                        paceCount += 1
                    }
                }
            }
        }
        
        // Process indoor walking
        for walk in indoorWalkingLogs.prefix(10) { // Consider only the most recent 10 walks
            if let paceString = walk.avgPace {
                let components = paceString.components(separatedBy: "'")
                if components.count >= 2,
                   let minutes = Double(components[0]) {
                    let secondsString = components[1].replacingOccurrences(of: "\"", with: "")
                    if let seconds = Double(secondsString) {
                        let paceInSeconds = minutes * 60 + seconds
                        paceSum += paceInSeconds
                        paceCount += 1
                    }
                }
            }
        }
        
        if paceCount == 0 {
            return "0'00\""
        }
        
        let averagePaceInSeconds = paceSum / Double(paceCount)
        let minutes = Int(averagePaceInSeconds / 60)
        let seconds = Int(averagePaceInSeconds.truncatingRemainder(dividingBy: 60))
        
        return String(format: "%d'%02d\"", minutes, seconds)
    }
    
    func calculateThisWeekSteps() -> Int {
        let calendar = Calendar.current
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            return 0
        }
        
        var totalSteps: Int = 0
        
        // Add outdoor walking steps
        for walk in outdoorWalkingLogs {
            if let date = walk.createdAt, date >= startOfWeek {
                if let steps = walk.steps {
                    totalSteps += steps
                }
            }
        }
        
        // Add indoor walking steps (if they have steps)
        for walk in indoorWalkingLogs {
            if let date = walk.createdAt, date >= startOfWeek {
                // Note: IndoorWalkLog might not have steps, but check if it does
                // For now, we'll assume indoor walks may have steps too
            }
        }
        
        return totalSteps
    }
    
    
    // Required for WCSessionDelegate
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            print("📱 Watch session became inactive")
        }
    }
    
    // Required for WCSessionDelegate
    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate the session after it deactivates
        DispatchQueue.main.async {
            print("📱 Watch session deactivated")
            WCSession.default.activate()
        }
    }
    
    // Handle messages from watch
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("📱 Received message from watch: \(message.keys)")
            self.handleWatchMessage(message)
        }
    }
    
    // Handle messages from watch that expect a reply
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let type = message["type"] as? String ?? ""
            print("📱 Received message with reply from watch: \(type)")
            
            switch type {
            case "pauseWalkingWorkout", "pauseWorkout":
                if let engine = self.walkingTracker as? WalkTrackingEngine {
                    // Optional workoutId guard
                    if let incomingId = (message["workoutId"] as? String).flatMap(UUID.init(uuidString:)), incomingId != engine.workoutId {
                        replyHandler(["success": false, "error": "MismatchedWorkoutId", "state": engine.state.rawValue])
                        return
                    }
                    // State guard
                    if engine.state == .inProgress {
                        engine.pause()
                        engine.updateApplicationContext()
                        replyHandler([
                            "success": true,
                            "state": engine.state.rawValue,
                            "type": "pauseWalkingWorkoutAck",
                            "timestamp": Date().timeIntervalSince1970
                        ])
                    } else {
                        replyHandler(["success": false, "error": "InvalidState", "state": engine.state.rawValue])
                    }
                } else {
                    replyHandler(["success": false, "error": "EngineUnavailable"])
                }
                
            case "resumeWalkingWorkout", "resumeWorkout":
                if let engine = self.walkingTracker as? WalkTrackingEngine {
                    // Optional workoutId guard
                    if let incomingId = (message["workoutId"] as? String).flatMap(UUID.init(uuidString:)), incomingId != engine.workoutId {
                        replyHandler(["success": false, "error": "MismatchedWorkoutId", "state": engine.state.rawValue])
                        return
                    }
                    // State guard
                    if engine.state == .paused {
                        engine.resume()
                        engine.updateApplicationContext()
                        replyHandler([
                            "success": true,
                            "state": engine.state.rawValue,
                            "type": "resumeWalkingWorkoutAck",
                            "timestamp": Date().timeIntervalSince1970
                        ])
                    } else {
                        replyHandler(["success": false, "error": "InvalidState", "state": engine.state.rawValue])
                    }
                } else {
                    replyHandler(["success": false, "error": "EngineUnavailable"])
                }
                
            default:
                // Generic immediate ack, then process normally
                replyHandler([
                    "status": "received",
                    "timestamp": Date().timeIntervalSince1970
                ])
                self.handleWatchMessage(message)
            }
        }
    }
    
    // Handle user info from watch
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("📱 Received user info from watch: \(userInfo.keys)")
            self.handleWatchUserInfo(userInfo)
        }
    }
    
    // Handle application context updates
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("📱 Received application context from watch: \(applicationContext.keys)")
            
            // Process based on type
            if let type = applicationContext["type"] as? String {
                switch type {
                case "walkWorkoutUpdate", "activeWalkingWorkoutResponse":
                    // Update workout state if provided
                    if let state = applicationContext["walkState"] as? String {
                        print("📱 Received walk state from watch: \(state)")
                    }
                    
                    // Process metrics if available
                    if let metrics = applicationContext["metrics"] as? [String: Any] {
                        DispatchQueue.main.async {
                            self.processWatchMetrics(metrics)
                        }
                    }
                default:
                    print("📱 Unhandled application context type: \(type)")
                }
            }
        }
    }
    
    // Process metrics received from watch
    func processWatchMetrics(_ metrics: [String: Any]) {
        guard let walkingTracker = self.walkingTracker as? WalkTrackingEngine else { return }
        
        print("📱 Processing metrics from watch: \(metrics.keys)")
        
        // Update metrics in tracking engine on main thread for thread safety
        DispatchQueue.main.async {
            // Update metrics in tracking engine
            walkingTracker.updateMetricsFromWatch(metrics)
            
            // Update UI if needed
            if walkingTracker.state != .notStarted {
                // If we're in an active workout, update the UI
                self.updateWalkingUI()
            }
            
            // Notify UI of changes
            self.objectWillChange.send()
        }
    }
    
    func updateWalkingUI() {
        // Notify SwiftUI views of changes
        self.objectWillChange.send()
    }
    
    // Handle user info received from watch
    func handleWatchUserInfo(_ userInfo: [String: Any]) {
        // Extract data from user info dictionary
        if let type = userInfo["type"] as? String {
            switch type {
            case "heartRate":
                if let heartRate = userInfo["value"] as? Double {
                    // Update heart rate if we have a tracking engine
                    print("📱 Received heart rate from watch: \(heartRate)")
                    if let walkingTracker = self.walkingTracker as? WalkTrackingEngine {
                        DispatchQueue.main.async {
                            walkingTracker.updateHeartRate(heartRate)
                            self.objectWillChange.send()
                        }
                    }
                }
            case "metrics":
                // Handle metrics updates
                if let metrics = userInfo["data"] as? [String: Any] {
                    DispatchQueue.main.async {
                        self.processWatchMetrics(metrics)
                    }
                }
            case "heartbeat":
                print("📱 Received heartbeat from watch via user info")
                // Send a response via application context
                self.sendHeartbeatResponse()
            default:
                print("📱 Unhandled user info type: \(type)")
            }
        }
    }
    
    // Handle messages from watch
    func handleWatchMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        switch type {

        case "syncWorkoutData", "syncWalkingWorkoutData":
            // Forward raw metrics to the engine for merging
            if let metrics = message["metrics"] as? [String: Any] {
                DispatchQueue.main.async { self.processWatchMetrics(metrics) }
            }

            // Build/refresh UI model for join prompt and banner
            guard let state = message["state"] as? String else { return }
            let isActive = (state == "active" || state == "inProgress" || state == "running")

            // Extract once to avoid scope issues
            let distance = message["distance"] as? Double ?? 0
            let elapsedTime = message["elapsedTime"] as? Double ?? 0
            let heartRate = message["heartRate"] as? Double ?? 0
            let calories = message["calories"] as? Double ?? 0
            let cadence = message["cadence"] as? Double ?? 0
            // Pace from watch is informational (do not override phone calculation)
            let paceFromWatch = message["pace"] as? Double ?? 0

            var startDate = Date(timeIntervalSinceNow: -elapsedTime)
            if let startTimestamp = message["startDate"] as? TimeInterval {
                startDate = Date(timeIntervalSince1970: startTimestamp)
            }

            let workoutData = ActiveWatchWorkoutData(
                isIndoor: message["isIndoor"] as? Bool ?? false,
                state: state,
                distance: distance,
                elapsedTime: elapsedTime,
                heartRate: heartRate,
                calories: calories,
                cadence: cadence,
                pace: paceFromWatch,
                startDate: startDate,
                rawData: message
            )

            DispatchQueue.main.async {
                self.activeWorkoutData = workoutData
                self.hasActiveWatchWorkout = isActive
                self.objectWillChange.send()

                // If the phone isn't tracking, prompt to join
                if isActive,
                   let walkingTracker = self.walkingTracker as? WalkTrackingEngine,
                   walkingTracker.state == .notStarted,
                   !self.didShowJoinPromptFromWatch {
                    self.presentJoinPromptFromWatch(with: message, startDate: startDate)
                }
            }

        case "pauseWalkingWorkout", "pauseWorkout":
            if let walkingTracker = self.walkingTracker as? WalkTrackingEngine {
                // Optional workoutId guard
                if let incomingId = (message["workoutId"] as? String).flatMap(UUID.init(uuidString:)),
                   incomingId != walkingTracker.workoutId {
                    return
                }
                // State guard
                if walkingTracker.state == .inProgress {
                    walkingTracker.pause()
                    walkingTracker.updateApplicationContext()
                }
            }
            // Acknowledge back to the watch
            let ackPause: [String: Any] = [
                "type": "pauseWalkingWorkoutAck",
                "success": true,
                "state": (self.walkingTracker as? WalkTrackingEngine)?.state.rawValue ?? "paused",
                "timestamp": Date().timeIntervalSince1970
            ]
            WCSession.default.sendMessage(ackPause, replyHandler: nil, errorHandler: { error in
                print("📱 Error sending pause ack: \(error.localizedDescription)")
            })

        case "resumeWalkingWorkout", "resumeWorkout":
            if let walkingTracker = self.walkingTracker as? WalkTrackingEngine {
                // Optional workoutId guard
                if let incomingId = (message["workoutId"] as? String).flatMap(UUID.init(uuidString:)),
                   incomingId != walkingTracker.workoutId {
                    return
                }
                // State guard
                if walkingTracker.state == .paused {
                    walkingTracker.resume()
                    walkingTracker.updateApplicationContext()
                }
            }
            // Acknowledge back to the watch
            let ackResume: [String: Any] = [
                "type": "resumeWalkingWorkoutAck",
                "success": true,
                "state": (self.walkingTracker as? WalkTrackingEngine)?.state.rawValue ?? "inProgress",
                "timestamp": Date().timeIntervalSince1970
            ]
            WCSession.default.sendMessage(ackResume, replyHandler: nil, errorHandler: { error in
                print("📱 Error sending resume ack: \(error.localizedDescription)")
            })

        case "walkStateChange":
            // Keep phone in sync but respect current engine state and session id
            guard let walkingTracker = self.walkingTracker as? WalkTrackingEngine else { return }

            if let incomingId = (message["workoutId"] as? String).flatMap(UUID.init(uuidString:)),
               incomingId != walkingTracker.workoutId {
                return
            }

            if let state = message["state"] as? String {
                switch state {
                case "inProgress":
                    if walkingTracker.state == .paused {
                        walkingTracker.resume()
                        walkingTracker.updateApplicationContext()
                    }
                case "paused":
                    if walkingTracker.state == .inProgress {
                        walkingTracker.pause()
                        walkingTracker.updateApplicationContext()
                    }
                default:
                    break
                }
            }

            let session = WCSession.default
            guard session.activationState == .activated,
                  session.isPaired,
                  session.isWatchAppInstalled else {
                print("📱 Cannot send heartbeat response - watch not available")
                return
            }

            // Prepare response with current workout state and metrics
            var response: [String: Any] = [
                "type": "heartbeatResponse",
                "timestamp": Date().timeIntervalSince1970,
                "workoutType": "walk"
            ]

            response["state"] = walkingTracker.state.rawValue
            response["walkState"] = walkingTracker.state.rawValue
            response["metrics"] = walkingTracker.getMetrics()
            response["workoutId"] = walkingTracker.workoutId.uuidString

            // Send via application context for reliability
            do {
                try session.updateApplicationContext(response)
                print("📱 Sent heartbeat response via application context")
            } catch {
                print("📱 Error sending heartbeat response: \(error.localizedDescription)")
                // Fallback to message sending
                session.sendMessage(response, replyHandler: nil, errorHandler: { error in
                    print("📱 Error sending heartbeat response message: \(error.localizedDescription)")
                })
            }

        default:
            break
        }
    }
        
        
        func populateRecentWalkingHistory() {
            // Check if we already have cached data
            if !outdoorWalkingLogs.isEmpty {
                print("📊 Using cached walking history")
                analyzeWalkingHistory()
                return
            }
            
            // Fetch walking history from AWS
            guard let userId = UserIDHelper.shared.getCurrentUserID(), !userId.isEmpty else {
                print("❌ Error: No user ID available for fetching walking history")
                return
            }
            
            DispatchQueue.global(qos: .utility).async { [weak self] in
                var allWalkLogs: [WalkLog] = []
                
                func fetchPage(nextToken: String?) {
                    ActivityService.shared.getWalks(
                        userId: userId,
                        limit: 100,
                        nextToken: nextToken,
                        includeRouteUrls: false
                    ) { result in
                        switch result {
                        case .success(let response):
                            guard let data = response.data else {
                                // No more data, process what we have
                                DispatchQueue.main.async {
                                    self?.outdoorWalkingLogs = allWalkLogs
                                    self?.analyzeWalkingHistory()
                                }
                                return
                            }
                            
                            // Convert and append activities from this page
                            let pageLogs = data.activities.compactMap { self?.convertAWSActivityToWalkLog($0) }
                            allWalkLogs.append(contentsOf: pageLogs)
                            
                            print("📄 Fetched page with \(pageLogs.count) walks (Total: \(allWalkLogs.count))")
                            
                            // Check if there are more pages
                            if data.hasMore, let token = data.nextToken {
                                fetchPage(nextToken: token)
                            } else {
                                // All pages fetched, update cache and analyze
                                DispatchQueue.main.async {
                                    self?.outdoorWalkingLogs = allWalkLogs
                                    print("✅ Fetched all walks from AWS: \(allWalkLogs.count) total")
                                    self?.analyzeWalkingHistory()
                                }
                            }
                            
                        case .failure(let error):
                            print("❌ Error fetching walking history from AWS: \(error.localizedDescription)")
                            // Use what we have so far, or analyze empty if nothing fetched
                            DispatchQueue.main.async {
                                if !allWalkLogs.isEmpty {
                                    self?.outdoorWalkingLogs = allWalkLogs
                                }
                                self?.analyzeWalkingHistory()
                            }
                        }
                    }
                }
                
                // Start fetching from the first page
                fetchPage(nextToken: nil)
            }
        }
        
        /// Convert AWSActivity to WalkLog format
        private func convertAWSActivityToWalkLog(_ activity: AWSActivity) -> WalkLog? {
            var walkLog = WalkLog()
            
            walkLog.id = activity.id
            
            // Convert date
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = dateFormatter.date(from: activity.createdAt) {
                walkLog.createdAt = date
            } else {
                dateFormatter.formatOptions = [.withInternetDateTime]
                walkLog.createdAt = dateFormatter.date(from: activity.createdAt)
            }
            
            // Format createdAt
            if let createdAt = walkLog.createdAt {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM d, yyyy"
                walkLog.createdAtFormatted = formatter.string(from: createdAt)
            }
            
            // Format distance based on activityData or calculate from meters
            let useMetric = UserPreferences.shared.useMetricSystem
            if useMetric {
                let distanceKm = activity.distance / 1000.0
                walkLog.distance = String(format: "%.2f km", distanceKm)
            } else {
                let distanceMiles = activity.distance / 1609.34
                walkLog.distance = String(format: "%.2f mi", distanceMiles)
            }
            
            // Format duration
            let hours = Int(activity.duration) / 3600
            let minutes = (Int(activity.duration) % 3600) / 60
            let seconds = Int(activity.duration) % 60
            if hours > 0 {
                walkLog.duration = String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                walkLog.duration = String(format: "%d:%02d", minutes, seconds)
            }
            
            // Calculate pace based on unit system
            let paceValue: Double
            if useMetric {
                let distanceKm = activity.distance / 1000.0
                paceValue = activity.duration / 60.0 / max(distanceKm, 0.0001) // minutes per km
            } else {
                let distanceMiles = activity.distance / 1609.34
                paceValue = activity.duration / 60.0 / max(distanceMiles, 0.0001) // minutes per mile
            }
            let paceMin = Int(paceValue)
            let paceSec = Int((paceValue - Double(paceMin)) * 60)
            walkLog.avgPace = String(format: "%d'%02d\" /%@", paceMin, paceSec, useMetric ? "km" : "mi")
            
            // Set calories
            walkLog.caloriesBurned = activity.calories
            
            // Set heart rate
            walkLog.avgHeartRate = activity.avgHeartRate
            walkLog.maxHeartRate = activity.maxHeartRate
            
            // Handle elevation
            if let elevationGain = activity.elevationGain {
                walkLog.elevationGain = String(format: "%.0f", elevationGain * 3.28084) // Convert meters to feet
            }
            if let elevationLoss = activity.elevationLoss {
                walkLog.elevationLoss = String(format: "%.0f", elevationLoss * 3.28084)
            }
            
            // Set steps if available
            walkLog.steps = activity.steps
            
            return walkLog
        }
        
        func analyzeWalkingHistory() {
            let walkLogs = outdoorWalkingLogs
            
            // Filter for recent walks (last 90 days)
            let calendar = Calendar.current
            let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date()
            
            let recentWalks = walkLogs.filter { log in
                guard let createdAt = log.createdAt, createdAt >= ninetyDaysAgo else { return false }
                return true
            }
            
            guard !recentWalks.isEmpty else {
                print("📊 No recent walking history available for analysis")
                return
            }
            
            // Extract valid paces from walk logs
            var validPaces: [Double] = []
            
            for log in recentWalks {
                if let avgPaceString = log.avgPace,
                   let distanceString = log.distance,
                   let pace = parsePaceString(avgPaceString),
                   let distance = parseDistanceString(distanceString),
                   distance > 0.5 { // Only walks longer than 0.5 mile/km
                    validPaces.append(pace)
                }
            }
            
            if !validPaces.isEmpty {
                let averagePace = validPaces.reduce(0, +) / Double(validPaces.count)
                let recentPaces = Array(validPaces.prefix(3))
                let recentPace = recentPaces.reduce(0, +) / Double(recentPaces.count)
                
                // Set ideal pace as weighted average (70% recent, 30% overall)
                let idealPace = (recentPace * 0.7) + (averagePace * 0.3)
                
                DispatchQueue.main.async { [weak self] in
                    // You can store this in a property for use in tracking
                    print("📊 Set ideal walking pace from history: \(idealPace) from \(validPaces.count) walks")
                }
            }
            
            print("📊 Loaded \(validPaces.count) historical walking pace records")
        }
        
        // Helper methods for parsing
        func parsePaceString(_ paceString: String) -> Double? {
            // Parse pace string like "12'30\"" to seconds per mile/km
            let cleaned = paceString.replacingOccurrences(of: "'", with: ":")
                .replacingOccurrences(of: "\"", with: "")
            let components = cleaned.split(separator: ":")
            guard components.count == 2,
                  let minutes = Double(components[0]),
                  let seconds = Double(components[1]) else {
                return nil
            }
            return minutes * 60 + seconds
        }
        
        func parseDistanceString(_ distanceString: String) -> Double? {
            // Remove units and convert to Double
            let cleaned = distanceString.replacingOccurrences(of: " km", with: "")
                .replacingOccurrences(of: " mi", with: "")
                .replacingOccurrences(of: " miles", with: "")
            return Double(cleaned)
        }
    }


// (Removed duplicate local delegate protocol definition to use OutdoorWalkViewControllerDelegate defined in OutdoorWalkViewController)

// MARK: - Main View Structs

struct WalkingTrackerView: View {
    @ObservedObject var viewModel: ModernWalkingTrackerViewController
    @State private var showRoutePreview: Bool = false
    @State private var selectedTrailForPreview: Trail? = nil
    @ObservedObject var walkingTrackingEngine: WalkTrackingEngine
    @StateObject private var locationManager = ModernLocationManager.shared
    @StateObject private var routePlanner = RoutePlanner.shared
    @StateObject private var weatherService = WeatherService.shared
    @ObservedObject private var userPreferences = UserPreferences.shared
    @State var locationCity: String = "Loading Location ..."
    var categoryDelegate: CategorySelectionDelegate?
    @State private var showingCategorySelector: Bool = false
    @State private var selectedCategoryIndex: Int = 0
    // Keep identical order to Run so saved index matches across trackers
    private let categoryTitles = ["Running", "Gym", "Cycling", "Hiking", "Walking", "Swimming", "Food", "Meditation", "Sports"]
    private let categoryIcons = ["figure.run", "figure.strengthtraining.traditional", "figure.outdoor.cycle", "figure.hiking", "figure.walk", "figure.pool.swim", "fork.knife", "sparkles", "sportscourt"]
    @State private var showingFindRoutesView: Bool = false
    // State properties
    @State public var isOutdoorWalk: Bool = true {
        didSet {
            print("🔄 SwiftUI didSet: isOutdoorWalk changed to \(isOutdoorWalk)")
            UserDefaults.standard.set(isOutdoorWalk, forKey: "isOutdoorWalk")
            print("💾 Saved outdoor walk setting to UserDefaults")
        }
    }
    
    // Initialize with external hasLoadedRoutes state
    init(viewModel: ModernWalkingTrackerViewController, 
         walkingTrackingEngine: WalkTrackingEngine, 
         categoryDelegate: CategorySelectionDelegate?,
         initialHasLoadedRoutes: Bool = false) {
        self.viewModel = viewModel
        self.walkingTrackingEngine = walkingTrackingEngine
        self.categoryDelegate = categoryDelegate
        
        // Load outdoor walk setting from preferences or default to true
        let savedOutdoorWalk = UserDefaults.standard.object(forKey: "isOutdoorWalk") as? Bool ?? true
        self._isOutdoorWalk = State(initialValue: savedOutdoorWalk)
        print("🏁 WalkingTrackerView initialized with outdoor walk setting: \(savedOutdoorWalk)")
    }
    
    var body: some View {
        ZStack {
            Color(UIColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0))
            .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection()
                    weatherSection()
                    // Active watch workout card (if available) – mirror run
                    viewModel.createActiveWorkoutCardView()
                    // Mirror Run: add simple outdoor toggle chip row and a placeholder for routes
                    routesSection().id(viewModel.routesForceRefreshID)
                    startWalkButtonSection()
                    quickActionsSection()
                    walkingStatsSection()
                }
                .padding(.vertical, 20)
            }
        }
        .sheet(isPresented: $showingCategorySelector) {
            CategorySelectorView(
                isPresented: $showingCategorySelector,
                selectedCategory: Binding(
                    get: { self.selectedCategoryIndex },
                    set: { newIndex in
                        self.selectedCategoryIndex = newIndex
                        self.showingCategorySelector = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.categoryDelegate?.didSelectCategory(at: newIndex)
                        }
                    }
                ),
                categories: Array(zip(categoryTitles, categoryIcons)).map { ($0.0, $0.1) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Routes Section (mirrors simplified run routes)
    private func routesSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recommended Routes")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            if !viewModel.hasLoadedRoutes {
                HStack {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Finding nearby routes...")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else {
                routesList()
            }
        }
        .padding(.horizontal)
    }
    private func routesList() -> some View {
        let trails: [Trail] = Array(RoutePlanner.shared.nearbyTrails)
        return Group {
            if trails.isEmpty {
                VStack {
                    Text("No routes found nearby")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                        .padding()
                    Button(action: { viewModel.fetchRoutes(forceRefresh: true) }) {
                        Text("Refresh")
                            .foregroundColor(.cyan)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(trails, id: \.id) { trail in
                            Button(action: {
                                if let current = viewModel.selectedRoute, current.id == trail.id {
                                    viewModel.selectedRoute = nil
                                } else {
                                    viewModel.selectedRoute = trail
                                }
                                viewModel.objectWillChange.send()
                            }) {
                                // Match Run's routeCard style
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "figure.walk")
                                            .font(.system(size: 16))
                                            .foregroundColor(.blue)
                                        Text(trail.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    HStack(spacing: 12) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "ruler")
                                                .font(.system(size: 10))
                                                .foregroundColor(.gray)
                                            let km = trail.length * 1.60934
                                            Text(String(format: "%.1f km", km))
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                        }
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.up.right")
                                                .font(.system(size: 10))
                                                .foregroundColor(.gray)
                                            let meters = trail.elevationGain * 0.3048
                                            Text(String(format: "%.0f m", meters))
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                        }
                                        HStack(spacing: 4) {
                                            Image(systemName: "bolt.circle")
                                                .font(.system(size: 10))
                                                .foregroundColor(.yellow)
                                            Text(trail.difficulty.rawValue.capitalized)
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .padding()
                                .frame(width: 240, alignment: .leading)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12).stroke((viewModel.selectedRoute?.id == trail.id) ? categoryAccentColor(selectedCategoryIndex) : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5)
                                    .onEnded { _ in
                                        selectedTrailForPreview = trail
                                        showRoutePreview = true
                                    }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .sheet(isPresented: $showRoutePreview) {
            if let trail = selectedTrailForPreview {
                RoutePreviewView(
                    trail: trail,
                    onSelectRoute: {
                        viewModel.selectedRoute = trail
                        showRoutePreview = false
                    },
                    onDismiss: { showRoutePreview = false }
                )
            }
        }
    }

    private func headerSection() -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Walk Tracker")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("Let's go for a walk")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            Spacer()
            HStack {
                Button(action: { showingCategorySelector = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: categoryIcons[selectedCategoryIndex])
                            .font(.system(size: 14, weight: .medium))
                        Text(categoryTitles[selectedCategoryIndex])
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: categoryAccentGradient(selectedCategoryIndex)),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
            }
            .padding(.horizontal)
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                // Present RunSettingsView for now to match Run. Replace with walking-specific when ready.
                viewModel.presentSettings()
            }) {
                Image(systemName: "gear")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onAppear {
            // Load saved category selection and reflect in header
            let saved = UserDefaults.standard.object(forKey: UserDefaults.selectedCategoryIndexKey) as? Int
            if let saved, saved != selectedCategoryIndex {
                selectedCategoryIndex = saved
            }
        }
    }

    private func weatherSection() -> some View {
        Group {
            if viewModel.weatherDataLoaded {
                weatherView()
                    .padding(.horizontal)
            } else {
                VStack {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Loading weather data...")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                    .padding(.bottom, 8)
                    Button {
                        Task { await viewModel.loadWeatherData() }
                    } label: {
                        Text("Tap to load weather")
                            .font(.system(size: 14))
                            .foregroundColor(.cyan)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        if !viewModel.weatherDataLoaded {
                            viewModel.weatherDataLoaded = true
                        }
                    }
                }
            }
        }
    }

    private func weatherView() -> some View {
        ZStack(alignment: .top) {
            getRunStyleWeatherGradient()
                .cornerRadius(22)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                
            // Normal weather animation
            ZStack(alignment: .top) {
                switch viewModel.weatherCondition {
                case .clear:
                    if isNighttime() {
                        StarsView()
                    } else {
                        // Time of day variations based on actual hour
                        let hour = Calendar.current.component(.hour, from: Date())
                        if hour >= 5 && hour < 9 {
                            // Early morning (5-9 AM)
                            ClearMorningView()
                        } else if hour >= 17 && hour < 20 {
                            // Evening (5-8 PM)
                            ClearEveningView()
                        } else {
                            // Regular daytime
                            ClearDayView()
                        }
                    }
                case .partlyCloudy:
                    if isNighttime() {
                        PartlyCloudyNightView()
                    } else {
                        // Time of day variations for partly cloudy day
                        let hour = Calendar.current.component(.hour, from: Date())
                        if hour >= 5 && hour < 9 {
                            // Early morning (5-9 AM)
                            PartlyCloudyMorningView()
                        } else if hour >= 17 && hour < 20 {
                            // Evening (5-8 PM)
                            PartlyCloudyEveningView()
                        } else {
                            // Regular daytime
                            PartlyCloudyDayView()
                        }
                    }
                case .cloudy:
                    CloudOverlay(nightMode: isNighttime())
                case .rainy:
                    ModernRainOverlay(intensity: .medium, nightMode: isNighttime())
                case .stormy:
                    LightningView()
                case .snowy:
                    SnowfallView(nightMode: isNighttime())
                case .foggy:
                    ModernFogOverlay(nightMode: isNighttime())
                case .windy:
                    WindyOverlay(nightMode: isNighttime())
                case .unknown:
                    // Show a default clear animation instead of empty view to preserve visual continuity
                    ClearDayView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .opacity(1.0) // Full opacity for better visibility
            .blendMode(.normal) // Use normal blend mode for better visibility, especially at night
            // Use stable ID based on condition to preserve animation state across updates
            // Only changes when condition actually changes, not on every temperature update
            .id("weather-animation-\(viewModel.weatherCondition.rawValue)")
            .allowsHitTesting(false) // Allow touches to pass through to content
            
            VStack(spacing: 12) {
                walkWeatherHeader()
                walkWeatherContent()
                    .padding(.horizontal)
                walkForecastRow()
                    .padding(.bottom, 10)
            }
            .padding(.vertical, 15)
            .background(Color.clear) // Transparent background so animation shows through
            .zIndex(1) // Ensure content is above animation
        }
        .frame(height: 235)
        .cornerRadius(22)
    }

    
    private func getRunStyleWeatherGradient() -> LinearGradient {
        let hour = Calendar.current.component(.hour, from: Date())
        let colors = Color.weatherGradient(for: viewModel.weatherCondition, hour: hour)
        return LinearGradient(gradient: Gradient(colors: [colors.0, colors.1]), startPoint: .top, endPoint: .bottom)
    }
    
    // Helper function to determine if it's night time
    private func isNighttime() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour > 18
    }
    private func walkWeatherHeader() -> some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text(viewModel.locationCity)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                Spacer()
                Image(systemName: viewModel.weatherIconName)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(runStyleWeatherDescription())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text(viewModel.formatTemperature(viewModel.temperature))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .padding(.horizontal)
        }
    }
    private func walkWeatherContent() -> some View {
        HStack(spacing: 16) {
            weatherDetailItem(icon: "wind", value: runStyleWindText())
            weatherDetailItem(icon: "drop.fill", value: "\(Int(viewModel.humidity))%")
        }
    }
    private func walkForecastRow() -> some View {
        HStack(spacing: 10) {
            ForEach(0..<4) { i in
                walkForecastItem(
                    hour: getHourString(hoursFromNow: i + 1),
                    icon: getForecastIcon(hoursFromNow: i + 1),
                    temp: getForecastTemp(hoursFromNow: i + 1)
                )
            }
        }
        .padding(.horizontal)
    }
    private func walkForecastItem(hour: String, icon: String, temp: String) -> some View {
        VStack(spacing: 4) {
            Text(hour)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            Text(temp)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }
    private func getHourString(hoursFromNow: Int) -> String {
        let calendar = Calendar.current
        if let futureDate = calendar.date(byAdding: .hour, value: hoursFromNow, to: Date()) {
            let formatter = DateFormatter()
            formatter.dateFormat = "ha"
            return formatter.string(from: futureDate).lowercased()
        }
        return "\(hoursFromNow)h"
    }
    private func getForecastIcon(hoursFromNow: Int) -> String {
        switch viewModel.weatherCondition {
        case .clear: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .partlyCloudy: return (Calendar.current.component(.hour, from: Date()) < 6 || Calendar.current.component(.hour, from: Date()) > 18) ? "cloud.moon.fill" : "cloud.sun.fill"
        case .rainy: return "cloud.rain.fill"
        case .stormy: return "cloud.bolt.rain.fill"
        case .snowy: return "snow"
        case .foggy: return "cloud.fog.fill"
        case .windy: return "wind"
        case .unknown: return "questionmark"
        }
    }
    private func getForecastTemp(hoursFromNow: Int) -> String {
        let delta = Double(hoursFromNow) * 0.5
        let base = viewModel.temperature
        let hour = Calendar.current.component(.hour, from: Date())
        let night = (hour < 6 || hour > 18)
        let t = night ? max(0, base - delta) : base + delta
        return viewModel.formatTemperature(t)
    }
    private func weatherDetailItem(icon: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.2))
        .cornerRadius(10)
    }
    private func runStyleWindText() -> String {
        if UserPreferences.shared.useMetricSystem {
            return "\(Int(viewModel.windSpeed * 1.0)) km/h"
        } else {
            let mph = Int(viewModel.windSpeed * 0.621371)
            return "\(mph) mph"
        }
    }
    private func runStyleWeatherDescription() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let night = (hour < 6 || hour > 18)
        switch viewModel.weatherCondition {
        case .clear: return night ? "Clear Night" : "Clear Day"
        case .cloudy: return night ? "Cloudy Night" : "Cloudy"
        case .partlyCloudy: return night ? "Partly Cloudy Night" : "Partly Cloudy"
        case .rainy: return "Rainy"
        case .stormy: return "Thunderstorms"
        case .snowy: return "Snowy"
        case .foggy: return "Foggy"
        case .windy: return "Windy"
        case .unknown: return "Unknown Weather"
        }
    }

    private func startWalkButtonSection() -> some View {
        VStack {
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                viewModel.startWalk()
            }) {
                HStack {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 18))
                    Text("Start Walk")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.cyan, Color.cyan.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
        }
        .padding(.horizontal)
    }

    private func quickActionsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            HStack(spacing: 16) {
                actionButton(iconName: "map.fill", label: "Find Routes") {
                    showingFindRoutesView = true
                }
                actionButton(iconName: "clock.fill", label: "History") {
                    viewModel.presentHistory()
                }
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingFindRoutesView) {
            FindRoutesView()
        }
    }

    private func walkingStatsSection() -> some View {
        Group {
            if viewModel.hasLoadedWalkingHistory {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Walking Activity")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 12) {
                        let thisWeekDistanceMeters = viewModel.calculateThisWeekDistance()
                        let avgPace = viewModel.calculateAveragePace()
                        let thisWeekSteps = viewModel.calculateThisWeekSteps()
                        let formattedDistance = UserPreferences.shared.useMetricSystem ?
                            String(format: "%.1f", thisWeekDistanceMeters / 1000) :
                            String(format: "%.1f", thisWeekDistanceMeters / 1609.34)
                        let distanceUnit = UserPreferences.shared.useMetricSystem ? "km" : "mi"
                        let paceUnit = UserPreferences.shared.useMetricSystem ? "/km" : "/mi"
                        
                        // Format steps with commas
                        let formattedSteps: String = {
                            let formatter = NumberFormatter()
                            formatter.numberStyle = .decimal
                            formatter.groupingSeparator = ","
                            return formatter.string(from: NSNumber(value: thisWeekSteps)) ?? "0"
                        }()

                        statCard(title: "This Week", value: formattedDistance, unit: distanceUnit, color: .cyan)
                        statCard(title: "Avg. Pace", value: avgPace, unit: paceUnit, color: .blue)
                        statCard(title: "Steps", value: formattedSteps, unit: "", color: .green)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func actionButton(iconName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .frame(width: 80, height: 80)
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
        }
    }

    private func statCard(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(color)
                Text(unit)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.3))
        .cornerRadius(16)
    }

    // MARK: - Category Accent Helpers
    private func categoryAccentGradient(_ index: Int) -> [Color] {
        // Unify category chip/button accent to orange across all categories
        return [Color.orange, Color.orange.opacity(0.85)]
    }

    private func categoryAccentColor(_ index: Int) -> Color {
        return categoryAccentGradient(index).first ?? .orange
    }
}


// MARK: - Active Watch Workout Banner (UI Builder)
extension ModernWalkingTrackerViewController {
    @ViewBuilder
    public func createActiveWorkoutCardView() -> some View {
        if hasActiveWatchWorkout, let workoutData = activeWorkoutData {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(
                            workoutData.isIndoor ? "Indoor Walk" : "Outdoor Walk",
                            systemImage: "figure.walk"
                        )
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        Spacer()
                        Text(workoutData.formattedState)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                workoutData.state == "inProgress"
                                    ? Color.green.opacity(0.7)
                                    : Color.orange.opacity(0.7)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 1)
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Distance")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                Text(workoutData.formattedDistance)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Time")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                Text(workoutData.formattedTime)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pace")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                Text(workoutData.formattedPace)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Heart Rate")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                Text(workoutData.heartRate > 0 ? "\(Int(workoutData.heartRate)) BPM" : "-- BPM")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Button(action: { self.joinWatchWorkout() }) {
                        Text("Join Watch Workout")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.976, green: 0.576, blue: 0.125),
                                        Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .padding(.top, 8)
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.15, green: 0.20, blue: 0.30))
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Walking Completion Methods
extension ModernWalkingTrackerViewController {
    
    func didSelectWalking(_ walking: Any) {
        // Handle selection coming from history or UI
        if let walkLog = walking as? WalkLog {
            print("📄 Presenting analysis for selected walk log")
            let analysisVC = WalkAnalysisViewController()
            analysisVC.walk = walkLog
            analysisVC.modalPresentationStyle = .pageSheet
            if let sheet = analysisVC.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 20
            }
            present(analysisVC, animated: true)
            return
        }

        if let walkType = walking as? WalkingType {
            print("🚶‍♂️ Starting walk for selected type: \(walkType.rawValue)")
            // Update engine's selected walk type
            walkingTracker.walkType = walkType
            // Start standard outdoor/treadmill flow via existing helper
            startWalk()
            return
        }

        // Fallback: just start a walk
        print("ℹ️ Unknown walking selection type; starting default walk")
        startWalk()
    }
    
    func outdoorWalkDidComplete(with walkLog: WalkLog?) {
        print("🏁 Walking completed, handling completion in ModernWalkingTrackerViewController")

        // Walk is already saved to AWS via generateWalkLog() -> saveWalkToAWS()
        // Just present summary/analysis if available
        if let walkLog = walkLog {
            // Present summary/analysis after a slight delay to ensure dismissal animations complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                let analysisVC = WalkAnalysisViewController()
                analysisVC.walk = walkLog
                analysisVC.modalPresentationStyle = .fullScreen
                self.present(analysisVC, animated: true)
            }
        }

        // Refresh UI state
        objectWillChange.send()
    }

    func outdoorWalkWasCanceled() {
        print("🏁 Walking was canceled, returning to tracker")
        // Reset local UI/engine state as needed
        walkingTracker.isJoiningExistingWorkout = false
        walkingTracker.isWatchTracking = false
        walkingTracker.state = .notStarted
        objectWillChange.send()
    }

    /// Join a watch workout using the active workout data (walking)
    public func joinWatchWorkout() {
        guard let activeWorkout = activeWorkoutData else {
            print("⚠️ Cannot join - no active walking workout data")
            return
        }

        print("📱 Joining walking workout from watch")

        // Configure engine from watch state/metrics
        let isIndoor = activeWorkout.isIndoor
        walkingTracker.isIndoorMode = isIndoor
        walkingTracker.isJoiningExistingWorkout = true
        walkingTracker.isWatchTracking = true

        // Map state
        let targetState: WalkState = (activeWorkout.normalizedState == .running) ? .inProgress : .paused
        walkingTracker.state = targetState

        // Apply metrics
        walkingTracker.startTime = activeWorkout.startDate
        walkingTracker.distance = Measurement(value: activeWorkout.distance, unit: .meters)
        walkingTracker.elapsedTime = activeWorkout.elapsedTime
        walkingTracker.heartRate = activeWorkout.heartRate
        walkingTracker.calories = activeWorkout.calories
        walkingTracker.cadence = activeWorkout.cadence
        
        // Extract steps from raw data if available
        var stepsValue = 0
        if let steps = activeWorkout.rawData["steps"] as? Int {
            stepsValue = steps
            walkingTracker.steps = steps
            print("📱 Joined workout with \(steps) steps from watch")
        }
        
        // Pace in struct is seconds/km; engine expects minutes per km
        let minutesPerKm = max(0.0, activeWorkout.pace / 60.0)
        // Use the same unit type as the pace property (which is initialized with .minutesPerKilometer)
        walkingTracker.pace = Measurement(value: minutesPerKm, unit: walkingTracker.pace.unit)

        // Update formatted values and lock screen
        // This ensures UI consistency immediately after joining
        // (updateFormattedValues is private; trigger via metrics update helper)
        walkingTracker.updateMetricsFromWatch([
            "distance": activeWorkout.distance,
            "elapsedTime": activeWorkout.elapsedTime,
            "heartRate": activeWorkout.heartRate,
            "calories": activeWorkout.calories,
            "cadence": activeWorkout.cadence,
            "steps": stepsValue,
            "pace": minutesPerKm,
            "startTime": activeWorkout.startDate.timeIntervalSince1970
        ])

        // Present OutdoorWalkViewController (used for both indoor/outdoor for now)
        let vc = OutdoorWalkViewController()
        vc.isJoiningExistingWorkout = true
        vc.watchWorkoutStartDate = activeWorkout.startDate
        vc.delegate = self
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)

        // Notify watch we've joined
        sendJoinConfirmationToWatch()

        // Clear banner state
        hasActiveWatchWorkout = false
        activeWorkoutData = nil
        objectWillChange.send()
    }

    // Send join confirmation to watch (walking)
    private func sendJoinConfirmationToWatch() {
        guard WCSession.default.activationState == .activated else {
            print("⚠️ Cannot send join confirmation - WCSession not activated")
            return
        }

        let joinMessage: [String: Any] = [
            "type": "joinedWorkoutFromPhone",
            "workoutType": "walk",
            "status": "success",
            "timestamp": Date().timeIntervalSince1970,
            "phoneIsJoining": true,
            "phoneState": walkingTracker.state.rawValue,
            "phoneElapsedTime": walkingTracker.elapsedTime,
            "phoneDistance": walkingTracker.distance.value,
            "hasGoodLocationData": walkingTracker.hasGoodLocationData,
            "isPrimaryForHeartRate": false,
            "isPrimaryForDistance": walkingTracker.isPrimaryForDistance,
            "isPrimaryForPace": walkingTracker.isPrimaryForDistance
        ]

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(joinMessage, replyHandler: { reply in
                print("📱 Watch received walking join confirmation: \(reply)")
            }, errorHandler: { error in
                print("⚠️ Error sending walking join confirmation: \(error.localizedDescription)")
            })
        } else {
            try? WCSession.default.updateApplicationContext(joinMessage)
            print("📱 Sent walking join confirmation via context update")
        }

        print("📱 Sent walking join confirmation to watch")
    }
}

// MARK: - Persistence Helpers
// Note: Saving is now handled in WalkTrackingEngine.generateWalkLog() -> saveWalkToAWS()
// This extension is kept for any legacy code that might reference it
private extension ModernWalkingTrackerViewController {
    func saveWalkLogToParse(_ log: WalkLog) {
        // Deprecated: Walk logs are now saved to AWS via WalkTrackingEngine
        // This method is kept for backward compatibility but does nothing
        print("⚠️ saveWalkLogToParse called but saving is now handled in WalkTrackingEngine.saveWalkToAWS()")
    }
}


// MARK: - Watch Join + Heartbeat Helpers (controller scope)
extension ModernWalkingTrackerViewController {
    /// Publish state to show the SwiftUI join banner instead of a blocking alert.
    func presentJoinPromptFromWatch(with message: [String: Any], startDate: Date) {
        let isIndoor = (message["isIndoor"] as? Bool) ?? false
        let distance = (message["distance"] as? Double) ?? 0
        let elapsedTime = (message["elapsedTime"] as? Double) ?? 0
        let heartRate = (message["heartRate"] as? Double) ?? 0
        let calories = (message["calories"] as? Double) ?? 0
        let cadence = (message["cadence"] as? Double) ?? 0
        let pace = (message["pace"] as? Double) ?? 0
        let rawState = (message["state"] as? String) ?? "inProgress"
        let normalizedState = (rawState == "running" || rawState == "active") ? "inProgress" : rawState

        let workoutData = ActiveWatchWorkoutData(
            isIndoor: isIndoor,
            state: normalizedState,
            distance: distance,
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            calories: calories,
            cadence: cadence,
            pace: pace,
            startDate: startDate,
            rawData: message
        )

        DispatchQueue.main.async {
            self.activeWorkoutData = workoutData
            self.hasActiveWatchWorkout = true
            self.didShowJoinPromptFromWatch = true
            self.objectWillChange.send()
            self.startWatchSync()
        }
    }

    /// Reply to watch heartbeat with current walking state and metrics.
    func sendHeartbeatResponse() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }

        let response: [String: Any] = [
            "type": "heartbeatResponse",
            "timestamp": Date().timeIntervalSince1970,
            "workoutType": "walk",
            "state": walkingTracker.state.rawValue,
            "walkState": walkingTracker.state.rawValue,
            "metrics": walkingTracker.getMetrics(),
            "workoutId": walkingTracker.workoutId.uuidString
        ]

        do {
            try session.updateApplicationContext(response)
        } catch {
            session.sendMessage(response, replyHandler: nil, errorHandler: nil)
        }
    }
}




