//
//  ModernRunTrackerViewController.swift
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





// MARK: - Category Selection Protocols
// Protocols are now defined in: Protocols/CategorySelectionProtocols.swift
// Imported automatically - no need to redeclare here

// MARK: - Main ModernRunTracker View Controller

// Supporting types
enum RouteDifficulty {
    case easy
    case moderate
    case difficult
}

struct Route: Identifiable {
    let id: UUID
    let name: String?
    let distance: Double // in km
    let elevation: Double // in meters
    let difficulty: RouteDifficulty
    
    init(id: UUID = UUID(), name: String? = nil, distance: Double = 0, elevation: Double = 0, difficulty: RouteDifficulty = .moderate) {
        self.id = id
        self.name = name
        self.distance = distance
        self.elevation = elevation
        self.difficulty = difficulty
    }
}

extension Route {
    init(from trail: Trail) {
        self.id = UUID()
        self.name = trail.name
        // Convert trail length (miles) to km
        self.distance = trail.length * 1.60934
        // Convert elevation gain (feet) to meters
        self.elevation = trail.elevationGain * 0.3048
        // Map trail difficulty to route difficulty
        switch trail.difficulty {
        case .easy: self.difficulty = .easy
        case .moderate: self.difficulty = .moderate
        case .difficult, .veryDifficult: self.difficulty = .difficult
        }
    }
}

class ModernRunTrackerViewController: UIViewController, ObservableObject, CLLocationManagerDelegate, CategorySwitchable, WCSessionDelegate, OutdoorRunViewControllerDelegate {
    
    // MARK: - Map Position Enum
    enum MapPosition {
        case minimized
        case fullscreen
        case hidden
    }
    
    // MARK: - Properties
    
    weak var categoryDelegate: CategorySelectionDelegate?
    public var hostingController: UIHostingController<RunTrackerView>?
    public var runTracker = RunTrackingEngine.shared
    private var cancellables = Set<AnyCancellable>()
    public let routePlanner = RoutePlanner.shared
    @Published private var mapPosition: MapPosition = .minimized
    @Published var routesForceRefreshID = UUID() // For forcing view refresh
    private var isRunning = false
    public var hasLoadedRoutes = false
    private var locationManager = ModernLocationManager.shared
    private let weatherService = WeatherService.shared
    
    // Route information
    @Published var selectedRoute: Route?
    
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
    // Running history data - use RunHistoryService
    private let runHistoryService = RunHistoryService.shared
    @Published var hasLoadedRunningHistory: Bool = false
    
    // Computed properties for stats calculations
    private var outdoorRunLogs: [RunLog] {
        return runHistoryService.outdoorRuns
    }
    
    private var indoorRunLogs: [IndoorRunLog] {
        return runHistoryService.indoorRuns
    }
    
    // Active watch workout detection
    @Published var hasActiveWatchWorkout: Bool = false
    @Published var activeWorkoutData: ActiveWatchWorkoutData? = nil
    
    // Message batching for watch communication
    private var lastSyncDataProcessTime = Date(timeIntervalSince1970: 0)
    private var pendingSyncMessages: [[String: Any]] = []
    
    // Run type
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
        button.setTitle("START RUN", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 30
        
        // Create gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(hex: "#20D474").cgColor, // Bright green
            UIColor(hex: "#15A348").cgColor  // Darker green
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
        setupRunTracker()
        
        // Setup WCSession for watch communication
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        
        // Debug: check Lottie animation files
        ensureLottieAnimationFiles()
        
        setupHostingController()
        
        // Add settings button to navigation bar
//        addSettingsButton()
        
        // Observe changes to UserPreferences
        observePreferencesChanges()
        
        // Add observer for run selection from history
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRunSelected),
            name: Notification.Name("RunSelected"),
            object: nil
        )
        
        // DEFERRED: Don't fetch weather/routes on load - wait for location permission
        // These will be called in viewDidAppear if location is available
        
        // Observe location authorization changes to load data when granted
        observeLocationAuthorization()
        
        NotificationCenter.default.addObserver(self, selector: #selector(didUpdateNearbyTrails(_:)), name: .didUpdateNearbyTrails, object: nil)
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
    
    // Handle run selection from history
    @objc private func handleRunSelected(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let selectedRun = userInfo["selectedRun"] {
            didSelectRun(selectedRun)
        }
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
    }
    
    private var hasLoadedInitialData = false
    private var hasReceivedLocation = false
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Check and update hosting controller
        if let hostingView = hostingController?.view {
            // Find and configure scroll views
            findAndConfigureScrollViews(in: hostingView)
        }
        
        // Check for active watch workouts when the view appears
        print("📱 DIAGNOSTIC: ViewDidAppear called, checking for watch workouts...")
        checkForActiveWatchWorkouts()
        
        // Load weather/routes ONLY if location permission is granted
        if !hasLoadedInitialData {
            checkLocationAndLoadData()
            hasLoadedInitialData = true
        }
    }
    
    private func checkLocationAndLoadData() {
        let status = CLLocationManager.authorizationStatus()
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location authorized - requesting single fix for weather/routes")
            
            // Prefer one-shot request instead of continuous updates for initial load
            if locationManager.location == nil {
                print("📍 No cached location - requesting one-time location…")
                // Use smart location reason to avoid continuous updates
                ModernLocationManager.shared.requestLocation(for: .routeDisplay)
                
                // Wait for location, then load data
                waitForLocationThenLoadData()
            } else {
                print("📍 Using cached location")
                Task {
                    await loadWeatherData()
                    await fetchRoutes()
                    self.loadRunningHistory()
                }
            }
            
        case .notDetermined:
            print("📱 Location not determined - requesting permission")
            locationManager.requestWhenInUseAuthorization()
            // Will load data after permission granted via observer
            
        case .denied, .restricted:
            print("⚠️ Location denied/restricted - attempting weather/routes with fallback")
            // Still try to load weather/routes with fallback methods
            // Load history (doesn't require location)
            loadRunningHistory()
            
            // Attempt to load weather with fallback (e.g., using last known location or default)
            Task {
                await loadWeatherDataWithFallback()
                // Try to load popular routes instead of location-based routes
                fetchRoutesWithFallback()
            }
            
        @unknown default:
            break
        }
    }
    
    private func waitForLocationThenLoadData() {
        print("⏳ Waiting for location updates...")
        // Ensure we have authorization; if not, request it now
        requestLocationAuthorizationIfNeeded()

        // Kick a one-shot request off the main thread to avoid UI warnings
        DispatchQueue.global(qos: .userInitiated).async {
            ModernLocationManager.shared.requestLocation()
        }

        // Observe location updates with timeout
        var timeoutTask: DispatchWorkItem?
        
        let subscription = locationManager.$location
            .compactMap { $0 } // Only non-nil locations
            .first() // Take first location
            .sink { [weak self] location in
                guard let self = self else { return }
                
                // Prevent duplicate processing
                guard !self.hasReceivedLocation else {
                    print("⚠️ Location already processed, skipping duplicate")
                    return
                }
                self.hasReceivedLocation = true
                
                // Cancel timeout
                timeoutTask?.cancel()
                
                print("📍 Got location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                
                PerformanceLogger.start("Track:weather+routes")
                Task {
                    await self.loadWeatherData()
                    await self.fetchRoutes()
                    self.loadRunningHistory()
                    // Stop location now that we've got what we need for this screen
                    ModernLocationManager.shared.stopLocation(for: .routeDisplay)
                    PerformanceLogger.end("Track:weather+routes")
                    PerformanceLogger.end("Track:initialLoad")
                }
            }
        
        subscription.store(in: &cancellables)
        
        // Set timeout - if no location after 10 seconds, log error
        timeoutTask = DispatchWorkItem { [weak self] in
            print("❌ Location timeout - no location received after 10 seconds")
            print("📍 Current location status: \(self?.locationManager.location?.coordinate.latitude ?? -999)")
            print("📍 Authorization: \(CLLocationManager.authorizationStatus().rawValue)")
            PerformanceLogger.end("Track:initialLoad", extra: "location timeout")
        }
        
        if let task = timeoutTask {
            DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: task)
        }
    }

    // Request authorization if needed. If denied/restricted, guide user to Settings
    private func requestLocationAuthorizationIfNeeded() {
        // Check authorization status off main thread to avoid UI unresponsiveness warning
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let status = CLLocationManager.authorizationStatus()
            DispatchQueue.main.async {
                switch status {
                case .authorizedAlways, .authorizedWhenInUse:
                    // Ensure precise accuracy if reduced
                    ModernLocationManager.shared.ensurePreciseAccuracyIfNeeded()
                    return
                case .notDetermined:
                    // Use ModernLocationManager which handles the async dispatch
                    ModernLocationManager.shared.requestWhenInUseAuthorization()
                case .denied, .restricted:
                    print("❌ Location permission denied/restricted. Prompting user to open Settings…")
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                @unknown default:
                    return
                }
            }
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
                    // Only load data if we haven't already loaded it
                    guard !self.hasLoadedInitialData else {
                        print("✅ Location granted but data already loaded, skipping")
                        return
                    }
                    
                    print("✅ Location granted! Requesting one-time location for weather/routes…")
                    
                    // Mark as loading to prevent duplicate calls
                    self.hasLoadedInitialData = true
                    
                    // Request single location fix for initial data load
                    ModernLocationManager.shared.requestLocation(for: .routeDisplay)
                    self.waitForLocationThenLoadData()
                }
            }
            .store(in: &cancellables)
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
    
    private func setupRunTracker() {
        // Initialize the run tracker and set up the current user
        let user = CurrentUserService.shared.user
        if let userId = user.userID, !userId.isEmpty {
            runTracker.setCurrentUser(userId)
        } else if let userId = UserIDHelper.shared.getCurrentUserID(), !userId.isEmpty {
            runTracker.setCurrentUser(userId)
        }
        
        // Setup background capability
        runTracker.setupBackgroundCapabilities()
    }
    
    private func setupHostingController() {
        // Create the run tracker view with both the view model and run tracking engine
        let runTrackerView = RunTrackerView(
            viewModel: self,
            runTrackingEngine: RunTrackingEngine.shared,
            categoryDelegate: self.categoryDelegate
        )
        
        // Create the hosting controller with the view
        hostingController = UIHostingController(rootView: runTrackerView)
        
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
    
  
    
    // Run type
    private var selectedRunType: RunType = .outdoorRun
    
    // MARK: - Weather Methods

    // Keep the cycleWeather method for backward compatibility but don't use it
    private func cycleWeather() {
        // This method is kept for compatibility but should not be used
        print("Warning: cycleWeather is deprecated, use loadWeatherData() instead")
    }
    
    // Guard to prevent duplicate weather fetches
    private var isFetchingWeather = false
    private var weatherFetchStartedAt: Date?
    
    public func loadWeatherData() async {
        // Prevent duplicate concurrent requests
        if isFetchingWeather {
            if let started = weatherFetchStartedAt, Date().timeIntervalSince(started) > 10 {
                print("⚠️ Weather fetch timed out, resetting flag...")
                isFetchingWeather = false
                weatherFetchStartedAt = nil
            } else {
                print("⚠️ Already fetching weather, skipping duplicate request")
                return
            }
        }
        
        isFetchingWeather = true
        weatherFetchStartedAt = Date()
        
        print("📱 ModernRunTrackerViewController: Starting weather data loading")
        
        // Initialize weather state
        await MainActor.run {
            self.weatherDataLoaded = false
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
                    
                    // CRITICAL: Set weatherDataLoaded to true AFTER all other properties
                    // This ensures the UI updates when weather is fully loaded
                    self.weatherDataLoaded = true
                    
                    // Reset fetch flag on success
                    self.isFetchingWeather = false
                    self.weatherFetchStartedAt = nil
                    
                    // Test the temperature formatting to verify it's working
                    let formattedTemp = self.formatTemperature(self.temperature)
                    print("🌡️ Formatted real temperature: \(formattedTemp) from \(self.temperature)°C")
                    print("✅ [Weather] Weather data loaded - UI should update now")
                    
                    // Force UI update by triggering objectWillChange
                    self.objectWillChange.send()
                }
            } else {
                // Handle weather loading error
                await MainActor.run {
                    // Reset fetch flag on error
                    self.isFetchingWeather = false
                    self.weatherFetchStartedAt = nil
                    
                    if let error = error {
                        print("❌ Error loading weather: \(error.localizedDescription)")
                        self.forecastDescription = "Weather data unavailable"
                    } else {
                        print("❌ Unknown error loading weather")
                        self.forecastDescription = "Weather data unavailable"
                    }
                    
                    // Show weather view with error message
                    self.weatherDataLoaded = true
                    self.weatherIconName = "exclamationmark.triangle"
                }
            }
        } else {
            // Location services unavailable - try fallback methods
            await loadWeatherDataWithFallback()
        }
    }
    
    /// Fallback method to load weather when location is unavailable
    private func loadWeatherDataWithFallback() async {
        // Try to use last known location from cache or UserDefaults
        if let lastKnownLat = UserDefaults.standard.object(forKey: "lastKnownLatitude") as? Double,
           let lastKnownLon = UserDefaults.standard.object(forKey: "lastKnownLongitude") as? Double {
            let fallbackLocation = CLLocation(latitude: lastKnownLat, longitude: lastKnownLon)
            print("📍 Using cached location for weather: \(lastKnownLat), \(lastKnownLon)")
            
            let (data, error) = await weatherService.fetchWeather(for: fallbackLocation)
            if let data = data {
                await MainActor.run {
                    self.temperature = data.temperature
                    self.humidity = data.humidity
                    self.windSpeed = data.windSpeed
                    self.weatherCondition = data.condition
                    let isNight = Calendar.current.component(.hour, from: Date()) < 6 || Calendar.current.component(.hour, from: Date()) > 18
                    self.weatherIconName = self.getWeatherIcon(for: data.condition, isNight: isNight)
                    self.forecastDescription = self.generateForecastDescription(data)
                    self.locationCity = "Last known location"
                    self.weatherDataLoaded = true
                    self.isFetchingWeather = false
                    self.weatherFetchStartedAt = nil
                }
                return
            }
        }
        
        // If no cached location, show helpful message
        await MainActor.run {
            self.locationCity = "Enable location for weather"
            self.forecastDescription = "Location access needed for accurate weather"
            self.weatherDataLoaded = true
            self.weatherIconName = "location.slash"
            self.isFetchingWeather = false
            self.weatherFetchStartedAt = nil
        }
    }
    
    /// Fallback method to load routes when location is unavailable
    private func fetchRoutesWithFallback() {
        // Check if we have cached routes from a previous session
        let routePlanner = RoutePlanner.shared
        if !routePlanner.nearbyTrails.isEmpty {
            print("✓ Using cached routes from previous session")
            hasLoadedRoutes = true
            routesForceRefreshID = UUID()
            objectWillChange.send()
            return
        }
        
        // If no cached routes, show message that location is needed
        print("ℹ️ No location available - routes require location access")
        hasLoadedRoutes = true // Mark as loaded so UI doesn't wait
        routesForceRefreshID = UUID()
        objectWillChange.send()
    }
    
    
    private func loadRunningHistory() {
        // ModernRunTrackerViewController should observe and trigger loading if no data exists
        // RunHistoryViewController handles loading when user visits that view, but we need data for stats
        runHistoryService.$outdoorRuns
            .combineLatest(runHistoryService.$indoorRuns)
            .sink { [weak self] outdoor, indoor in
                DispatchQueue.main.async {
                    self?.hasLoadedRunningHistory = true
                    print("📥 [ModernRunTracker] History updated: \(outdoor.count) outdoor, \(indoor.count) indoor")
                    // Trigger UI update for stats - force view refresh
                    self?.routesForceRefreshID = UUID()
                }
            }
            .store(in: &cancellables)
        
        // Check if we have cached data
        if !runHistoryService.outdoorRuns.isEmpty || !runHistoryService.indoorRuns.isEmpty {
            print("📥 [ModernRunTracker] Using cached data: \(runHistoryService.outdoorRuns.count) outdoor, \(runHistoryService.indoorRuns.count) indoor")
            self.hasLoadedRunningHistory = true
        } else {
            // No cache - fetch data so stats can be calculated
            // This ensures stats are available even if user hasn't visited RunHistoryViewController yet
            print("📥 [ModernRunTracker] No cache - fetching data for stats calculation...")
            self.hasLoadedRunningHistory = false // Will be set to true when data arrives
            runHistoryService.loadRuns(forceRefresh: false) { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ [ModernRunTracker] Error loading history for stats: \(error.localizedDescription)")
                        // Still mark as loaded so UI doesn't wait forever
                        self?.hasLoadedRunningHistory = true
                    } else {
                        print("✅ [ModernRunTracker] Data loaded for stats calculation")
                        self?.hasLoadedRunningHistory = true
                    }
                }
            }
        }
    }
    
    // Helper methods to convert AWS activities to RunLog/IndoorRunLog
    // Using the same conversion logic as RunHistoryViewController
    private func convertAWSActivityToRunLog(_ activity: AWSActivity) -> RunLog? {
        // Check if this is an indoor/treadmill run and skip it
        if activity.isIndoorRun {
            return nil // Return nil for indoor runs - they'll be handled separately
        }
        
        var runLog = RunLog()
        runLog.id = activity.id
        
        // Convert date - Parse ISO8601 format
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = dateFormatter.date(from: activity.createdAt) {
            runLog.createdAt = date
        } else {
            // Fallback without fractional seconds
            dateFormatter.formatOptions = [.withInternetDateTime]
            runLog.createdAt = dateFormatter.date(from: activity.createdAt)
        }
        
        // Format distance (convert meters to miles string)
        let distanceMiles = activity.distance / 1609.34 // Convert meters to miles
        runLog.distance = String(format: "%.2f mi", distanceMiles)
        
        // Format duration
        let hours = Int(activity.duration) / 3600
        let minutes = (Int(activity.duration) % 3600) / 60
        let seconds = Int(activity.duration) % 60
        if hours > 0 {
            runLog.duration = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            runLog.duration = String(format: "%d:%02d", minutes, seconds)
        }
        
        // Calculate pace (minutes per mile)
        let minutesPerMile = activity.duration / 60.0 / max(distanceMiles, 0.0001)
        let paceMin = Int(minutesPerMile)
        let paceSec = Int((minutesPerMile - Double(paceMin)) * 60)
        runLog.avgPace = String(format: "%d'%02d\" /mi", paceMin, paceSec)
        
        // Set calories
        runLog.caloriesBurned = activity.calories
        
        // Set optional fields
        runLog.avgHeartRate = activity.avgHeartRate
        runLog.maxHeartRate = activity.maxHeartRate
        
        // Handle elevation
        if let elevationGain = activity.elevationGain {
            runLog.elevationGain = String(format: "%.0f", elevationGain * 3.28084) // Convert meters to feet
        }
        if let elevationLoss = activity.elevationLoss {
            runLog.elevationLoss = String(format: "%.0f", elevationLoss * 3.28084)
        }
        
        // Store S3 route data URL if available
        if let routeDataUrl = activity.routeDataUrl {
            runLog.routeDataUrl = routeDataUrl
        }
        
        // Parse locationData from activityData JSON string if available (legacy format)
        if let activityDataString = activity.activityData,
           let data = activityDataString.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let locationsArray = json["locationData"] as? [[String: Any]] {
                    runLog.locationData = locationsArray
                }
            } catch {
                print("⚠️ Failed to parse activityData for locationData: \(error)")
            }
        }
        
        // Parse weather data from activityData if not directly available
        if let activityDataString = activity.activityData,
           let data = activityDataString.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let weather = json["weather"] as? String {
                        runLog.weather = weather
                    }
                    if let temperature = json["temperature"] as? Double {
                        runLog.temperature = temperature
                    }
                }
            } catch {
                print("⚠️ Failed to parse activityData for weather: \(error)")
            }
        }
        
        return runLog
    }
    
    private func convertAWSActivityToIndoorRunLog(_ activity: AWSActivity) -> IndoorRunLog? {
        guard activity.isIndoorRun else { return nil }
        
        // Convert date - Parse ISO8601 format
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var createdAt: Date?
        if let date = dateFormatter.date(from: activity.createdAt) {
            createdAt = date
        } else {
            // Fallback without fractional seconds
            dateFormatter.formatOptions = [.withInternetDateTime]
            createdAt = dateFormatter.date(from: activity.createdAt)
        }
        
        // Format date string
        let dateFormatterString = DateFormatter()
        dateFormatterString.dateFormat = "MMMM d, yyyy"
        let createdAtFormatted = createdAt != nil ? dateFormatterString.string(from: createdAt!) : nil
        
        // Format distance (convert meters to miles string)
        let distanceMiles = activity.distance / 1609.34
        let distanceString = String(format: "%.2f mi", distanceMiles)
        
        // Format duration
        let hours = Int(activity.duration) / 3600
        let minutes = (Int(activity.duration) % 3600) / 60
        let seconds = Int(activity.duration) % 60
        let durationString: String
        if hours > 0 {
            durationString = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            durationString = String(format: "%d:%02d", minutes, seconds)
        }
        
        // Calculate pace
        let minutesPerMile = activity.duration / 60.0 / max(distanceMiles, 0.0001)
        let paceMin = Int(minutesPerMile)
        let paceSec = Int((minutesPerMile - Double(paceMin)) * 60)
        let avgPaceString = String(format: "%d'%02d\" /mi", paceMin, paceSec)
        
        // Create IndoorRunLog directly without Parse dependencies
        var indoorLog = IndoorRunLog()
        indoorLog.id = activity.id
        indoorLog.createdAt = createdAt
        indoorLog.createdAtFormatted = createdAtFormatted
        indoorLog.distance = distanceString
        indoorLog.duration = durationString
        indoorLog.avgPace = avgPaceString
        indoorLog.caloriesBurned = activity.calories
        indoorLog.createdBy = nil // No Parse dependency - AWS doesn't use PFUser
        indoorLog.runType = activity.runType ?? "treadmill_run"
        
        // Set optional fields
        indoorLog.avgHeartRate = activity.avgHeartRate
        indoorLog.maxHeartRate = activity.maxHeartRate
        
        // Parse heart rate zones if available in activityData
        if let activityDataString = activity.activityData,
           let data = activityDataString.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let zones = json["heartRateZones"] as? [String: Double] {
                    indoorLog.heartRateZones = zones
                }
            } catch {
                print("⚠️ Failed to parse heartRateZones: \(error)")
            }
        }
        
        return indoorLog
    }
    
    // Helper methods for calculating statistics
    func calculateThisWeekDistance() -> Double {
        let calendar = Calendar.current
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            return 0.0
        }
        
        var totalDistanceMeters: Double = 0.0
        
        // Add outdoor runs distance
        for run in outdoorRunLogs {
            if let date = run.createdAt, date >= startOfWeek {
                if let distanceString = run.distance {
                    // Parse distance string (format: "2.5 mi" or "4.0 km")
                    let distance = parseDistanceString(distanceString)
                    totalDistanceMeters += distance
                }
            }
        }
        
        // Add indoor runs distance
        for run in indoorRunLogs {
            if let date = run.createdAt, date >= startOfWeek {
                if let distanceString = run.distance {
                    // Parse distance string (format: "2.5 mi" or "4.0 km")
                    let distance = parseDistanceString(distanceString)
                    totalDistanceMeters += distance
                }
            }
        }
        
        return totalDistanceMeters
    }
    
    // Helper to parse distance string (e.g., "2.5 mi" -> meters)
    private func parseDistanceString(_ distanceString: String) -> Double {
        // Remove whitespace and convert to lowercase
        let cleaned = distanceString.trimmingCharacters(in: .whitespaces).lowercased()
        
        // Try to extract number and unit using regex
        let pattern = #"([\d.]+)\s*(mi|km|m|meters?)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleaned, options: [], range: NSRange(location: 0, length: cleaned.utf16.count)) {
            
            // Extract number
            if let numberRange = Range(match.range(at: 1), in: cleaned),
               let distance = Double(String(cleaned[numberRange])) {
                
                // Extract unit
                if match.numberOfRanges > 2 {
                    if let unitRange = Range(match.range(at: 2), in: cleaned) {
                        let unit = String(cleaned[unitRange])
                        
                        // Convert to meters
                        if unit.contains("mi") {
                            return distance * 1609.34 // miles to meters
                        } else if unit.contains("km") {
                            return distance * 1000 // km to meters
                        } else {
                            return distance // already in meters
                        }
                    }
                }
            }
        }
        
        // Fallback: try simple parsing for "X.X mi" format
        if cleaned.hasSuffix(" mi") {
            let numberString = cleaned.replacingOccurrences(of: " mi", with: "")
            if let distance = Double(numberString) {
                return distance * 1609.34 // miles to meters
            }
        } else if cleaned.hasSuffix(" km") {
            let numberString = cleaned.replacingOccurrences(of: " km", with: "")
            if let distance = Double(numberString) {
                return distance * 1000 // km to meters
            }
        }
        
        // Final fallback: try to parse as plain number (assume miles for backward compatibility)
        if let distance = Double(cleaned) {
            return distance * 1609.34 // assume miles
        }
        
        return 0.0
    }

    func calculateAveragePace() -> String {
        var paceSum: Double = 0.0
        var paceCount: Int = 0
        
        // Process outdoor runs
        for run in outdoorRunLogs.prefix(10) { // Consider only the most recent 10 runs
            if let paceString = run.avgPace {
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
        
        // Process indoor runs
        for run in indoorRunLogs.prefix(10) { // Consider only the most recent 10 runs
            if let paceString = run.avgPace {
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
    
    // Convert trail difficulty string to enum
    func convertDifficulty(_ difficultyString: String) -> RouteDifficulty {
        switch difficultyString.lowercased() {
        case "easy":
            return .easy
        case "moderate":
            return .moderate
        case "hard", "difficult":
            return .difficult
        case "very hard", "very difficult":
            return .difficult
        default:
            return .moderate
        }
    }

    // Get activity type from trail
    func getActivityTypeFromTrail(_ trail: Trail) -> ActivityRouteType {
        if let trailTypeString = trail.trailType?.lowercased() {
            if trailTypeString.contains("run") || trailTypeString.contains("jog") {
                return .running
            } else if trailTypeString.contains("hike") || trailTypeString.contains("walk") {
                return .hiking
            } else if trailTypeString.contains("bike") || trailTypeString.contains("cycle") {
                return .biking
            }
        }
        // Default to running if no specific type is found
        return .running
    }

    // Get icon for activity type
    func getActivityIcon(for activityType: ActivityRouteType) -> String {
        switch activityType {
        case .running:
            return "figure.run"
        case .hiking:
            return "figure.hiking"
        case .biking:
            return "figure.outdoor.cycle"
        case .walking:
            return "figure.walk"
        case .returnRoute:
            return "figure.walk"
        }
    }

    // Get color for activity type
    func getActivityColor(for activityType: ActivityRouteType) -> Color {
        switch activityType {
        case .running:
            return .blue
        case .hiking:
            return .green
        case .biking:
            return .orange
        case .walking:
            return .teal
        case .returnRoute:
            return .pink
        }
    }

    // Check if trail is a loop
    func isLoopTrail(_ coordinates: [CLLocationCoordinate2D]) -> Bool {
        guard coordinates.count > 2 else { return false }
        
        let start = coordinates.first!
        let end = coordinates.last!
        
        // Calculate distance between start and end points
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)
        
        let distance = startLocation.distance(from: endLocation)
        
        // If start and end points are close (less than 100m), consider it a loop
        return distance < 100
    }

    // Get difficulty icon
    func getDifficultyIcon(for difficulty: RouteDifficulty) -> String {
        switch difficulty {
        case .easy:
            return "circle"
        case .moderate:
            return "square"
        case .difficult:
            return "diamond"
        }
    }

    // Get difficulty color
    func getDifficultyColor(for difficulty: RouteDifficulty) -> Color {
        switch difficulty {
        case .easy:
            return .green
        case .moderate:
            return .blue
        case .difficult:
            return .red
        }
    }

    // Get difficulty text
    func getDifficultyText(for difficulty: RouteDifficulty) -> String {
        switch difficulty {
        case .easy:
            return "Easy"
        case .moderate:
            return "Moderate"
        case .difficult:
            return "Difficult"
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
    
    // Add a cache for routes
    private var cachedRoutes: [String: [Trail]] = [:]
    private var lastRouteLoadTime: Date?
    private var retryCount = 0
    private let maxRetries = 3
    
    // Add method to force refresh routes - will be called from SwiftUI view
    public func forceRefreshRoutes() {
        print("🔄 Forcing route refresh from RunTrackerView")
        
        // Send objectWillChange to notify observers
        self.objectWillChange.send()
        
        // Update the UUID to force view refreshes
        self.routesForceRefreshID = UUID()
        
        // Trigger UI refresh
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Call our refreshUIWithCurrentTrails which handles all UI updates
            self.refreshUIWithCurrentTrails()
            
            // Post notification for other components that might be listening
            NotificationCenter.default.post(
                name: NSNotification.Name("RoutesDidChange"),
                object: nil,
                userInfo: ["forceRefresh": true]
            )
        }
    }
    
    // Method to refresh UI with current trails
    public func refreshUIWithCurrentTrails() {
        print("🔄 Refreshing UI with current trails. Count: \(RoutePlanner.shared.nearbyTrails.count)")
        
        // Don't trigger fetchRoutes here - that leads to recursive calls
        // Instead, just trigger UI updates
        
        // Multiple UI refresh mechanisms for redundancy
        self.objectWillChange.send()
        
        // Update the routes refresh ID to force SwiftUI views to reload
        self.routesForceRefreshID = UUID()
        
        // Notify any observers that routes changed with UI update flag
        NotificationCenter.default.post(
            name: NSNotification.Name("RoutesUpdated"),
            object: nil,
            userInfo: ["timestamp": Date(), "forceUIUpdate": true]
        )
    }
    
    // Guard to prevent duplicate route fetches
    var isFetchingRoutes = false
    private var routesFetchStartedAt: Date?
    
    @MainActor
    func fetchRoutes(forceRefresh: Bool = false) {
        let routePlanner = RoutePlanner.shared
        
        // Prevent duplicate concurrent requests
        if isFetchingRoutes {
            if let started = routesFetchStartedAt, Date().timeIntervalSince(started) > 30 {
                print("⚠️ Routes fetch timed out, resetting flag...")
                isFetchingRoutes = false
                routesFetchStartedAt = nil
            } else {
                print("⚠️ Already fetching routes, skipping duplicate request")
                return
            }
        }
        
        // Skip if we already have routes and aren't forcing refresh
        if !forceRefresh && !routePlanner.nearbyTrails.isEmpty {
            print("✓ Using cached routes - \(routePlanner.nearbyTrails.count) routes available")
            hasLoadedRoutes = true
            return
        }
        
        isFetchingRoutes = true
        routesFetchStartedAt = Date()
        
        print("🔄 Fetching routes...")
        
        // Reset state if force refreshing
        if forceRefresh {
            print("🔄 Force refreshing routes")
            
            // Clear existing routes to ensure UI refresh
            routePlanner.nearbyTrails = []
            
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
            // Use the proper find method that exists in RoutePlanner
            routePlanner.findRunningTrails { [weak self] success in
                guard let self = self else {
                    // Reset flag even if self is deallocated
                    DispatchQueue.main.async {
                        RoutePlanner.shared.isFetchingTrails = false
                    }
                    return
                }
                
                // Reset fetch flag
                self.isFetchingRoutes = false
                self.routesFetchStartedAt = nil
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    // Mark routes as loaded first
                    self.hasLoadedRoutes = true
                    
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
    
    // Update the processFetchedTrails method to better handle UI updates
    @MainActor
    private func processFetchedTrails(_ allTrails: [Trail], forKey cacheKey: String) {
        // Filter very short trails (less than 0.05 miles)
        let filteredTrails = allTrails.filter { $0.length >= 0.05 }
        print("🚶‍♂️ Filtered out \(allTrails.count - filteredTrails.count) trails shorter than 0.05 miles")
        
        // Limit the number of trails to prevent UI performance issues
        let limitedTrails = Array(filteredTrails.prefix(15))
        
        // Cache the results for this location
        self.cachedRoutes[cacheKey] = limitedTrails
        self.lastRouteLoadTime = Date()
        
        // Update the route planner with our filtered trails
        RoutePlanner.shared.setTrails(limitedTrails)
        print("📝 Set trails to filtered list of \(limitedTrails.count) trails")
        
        // IMPORTANT: Set hasLoadedRoutes to true BEFORE refreshing UI
        self.hasLoadedRoutes = true
        
        // Reset fetching flag
        self.isFetchingRoutes = false
        
        // Use our improved UI refresh method that handles everything
        self.refreshUIWithCurrentTrails()
    }
    
    // Simplified method to show cached routes
    @MainActor
    private func showCachedRoutesIfAvailable() {
        let cacheKey = generateLocationCacheKey()
        
        if let cachedTrails = cachedRoutes[cacheKey] {
            // Use the cached trails immediately
            RoutePlanner.shared.setTrails(cachedTrails)
            print("📋 Using cached routes for location \(cacheKey): \(cachedTrails.count) trails available")
            print("🛤️ Loaded \(cachedTrails.count) trails for running")
            
            // Set hasLoadedRoutes to true
            hasLoadedRoutes = true
            
            // Use our improved UI refresh method
            self.refreshUIWithCurrentTrails()
        } else {
            print("No cached routes available for this location")
        }
    }
    
    
    // Helper method to try to find a SwiftUI @State keypath (this is a workaround for SwiftUI state binding)
    private func findKeyPath<T>(in view: T, forStateProperty name: String) -> KeyPath<T, Bool>? {
        let mirror = Mirror(reflecting: view)
        for child in mirror.children {
            if let label = child.label, label == "_" + name {
                if let keyPath = child.value as? KeyPath<T, Bool> {
                    return keyPath
                }
            }
        }
        return nil
    }
    
    private func generateLocationCacheKey() -> String {
        // Create a unique key based on user's approximate location
        // Round coordinates to 2 decimal places (~1km resolution) to avoid excessive cache entries
        if let location = ModernLocationManager.shared.location {
            let lat = round(location.coordinate.latitude * 100) / 100
            let lon = round(location.coordinate.longitude * 100) / 100
            return "\(lat),\(lon)"
        }
        return "default"
    }
    
    private func shouldRefreshTrails(for cacheKey: String) -> Bool {
        // Check if we have cached routes for this location
        if let cachedTrails = cachedRoutes[cacheKey], !cachedTrails.isEmpty {
            // Check if they're recent (less than 2 hours old)
            if let lastLoadTime = lastRouteLoadTime, 
               Date().timeIntervalSince(lastLoadTime) < 7200 { // 2 hours
                return false // Don't need to reload
            }
        }
        return true // Need to reload if we have no cache or it's old
    }
    
    // Add a function to manually refresh routes
    public func refreshRoutes() {
        print("🔄 Manually refreshing routes...")
        // Force a refresh by clearing the cache timestamp
        lastRouteLoadTime = nil
        fetchRoutes()
    }
    
    // Helper function for scoring trails based on run type
    public func scoreTrailForRunType(_ trail: Trail, runType: RunType) -> Int {
        var score = 0
        
        // Give significantly higher score for meaningful names (not just "Trail X")
        if trail.name.contains("Trail ") {
            // Generic unnamed trail
            score += 0 // Base score unchanged
        } else if trail.name.isEmpty || trail.name == "Unnamed" {
            // Completely unnamed trail (worse than generic number)
            score -= 5
        } else {
            // Named trail - big bonus!
            score += 25 // Substantial bonus for actual named trails
            
            // Extra points for names that match activity type
            if runType == .trailRun && (trail.name.contains("Trail") || trail.name.contains("Mountain")) {
                score += 5
            } else if runType == .outdoorRun && (trail.name.contains("Park") || trail.name.contains("Path")) {
                score += 5
            }
        }
        
        // Minimum score for very short trails
        if trail.length < 0.1 {
            score -= 5 // Penalty for extremely short trails
        }
        
        // Score based on trail length - prefer moderate lengths for most run types
        if trail.length > 0.5 && trail.length < 5.0 {
            score += 5 // Good length for running
        } else if trail.length >= 5.0 {
            score += 3 // Longer trails are good but not as preferred as moderate ones
        }
        
        // Base score on activity type match
        if let trailTypeString = trail.trailType?.lowercased() {
            switch runType {
            case .trailRun:
                // Trail runs prefer hiking trails, but also like running and biking trails
                if trailTypeString.contains("hik") { score += 8 }
                else if trailTypeString.contains("run") { score += 6 }
                else if trailTypeString.contains("bik") || trailTypeString.contains("cycle") { score += 3 }
                
                // Trail runs prefer more difficult trails
                if trail.difficulty == .moderate { score += 4 } 
                else if trail.difficulty == .difficult || trail.difficulty == .veryDifficult { score += 6 }
                
            case .outdoorRun:
                // Regular runs prefer running trails, but also like walking and biking trails
                if trailTypeString.contains("run") || trailTypeString.contains("track") { score += 8 }
                else if trailTypeString.contains("walk") || trailTypeString.contains("path") { score += 6 }
                else if trailTypeString.contains("bik") || trailTypeString.contains("cycle") { score += 4 }
                else if trailTypeString.contains("hik") { score += 3 }
                
                // Regular runs prefer moderate difficulty
                if trail.difficulty == .moderate { score += 5 }
                else if trail.difficulty == .easy { score += 3 }
                
            case .recoveryRun:
                // Recovery runs prefer easier, flatter trails
                if trailTypeString.contains("walk") { score += 8 }
                else if trailTypeString.contains("run") { score += 5 }
                
                // Recovery runs strongly prefer easier trails
                if trail.difficulty == .easy { score += 7 }
                else if trail.difficulty == .moderate { score += 2 }
                
            case .intervalTraining:
                // Interval training prefers flat, consistent surfaces
                if trailTypeString.contains("run") || trailTypeString.contains("track") { score += 10 }
                else if trailTypeString.contains("walk") { score += 5 }
                
                // Prefer easier or moderate trails for consistent pacing
                if trail.difficulty == .easy { score += 6 }
                else if trail.difficulty == .moderate { score += 4 }
                
            case .lapRun:
                // Lap runs prefer loop trails
                if trail.coordinates.count > 2 && self.isLoopTrail(trail.coordinates) { score += 10 }
                
                // Prefer running and biking trails which often have good loops
                if trailTypeString.contains("run") || trailTypeString.contains("track") { score += 8 }
                else if trailTypeString.contains("bik") || trailTypeString.contains("cycle") { score += 5 }
                
            case .treadmillRun:
                // Treadmill runs don't use outdoor trails
                score = 0
                
            default:
                // Default preference for running trails
                if trailTypeString.contains("run") { score += 5 }
            }
        }
        
        return score
    }
    
    /// Start the run with the selected run type
    @objc func startRun() {
        // CRITICAL: Get the run type from our improved method
        let selectedRunType = getSelectedRunType()
        print("🚀 Starting run with selected run type: \(selectedRunType.rawValue)")
        
        // PERMISSION CHECK: Ensure all required permissions before starting workout
        let isIndoor = (selectedRunType == .treadmillRun)
        PermissionsManager.shared.ensureWorkoutPermissions(for: "running", isIndoor: isIndoor) { success, missingPermissions in
            if !success {
                // Show alert about missing permissions
                let permissionNames = missingPermissions.map { $0.name }.joined(separator: ", ")
                let alert = UIAlertController(
                    title: "Permissions Required",
                    message: "To start your \(isIndoor ? "indoor" : "outdoor") run, Do. needs: \(permissionNames). Please grant these permissions in Settings.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                })
                self.present(alert, animated: true)
                return
            }
            
            // All permissions granted - proceed with starting the run
            self.continueStartingRun(with: selectedRunType)
        }
    }
    
    /// Continue starting the run after permissions are confirmed
    private func continueStartingRun(with selectedRunType: RunType) {
        print("✅ Permissions verified, continuing with run start")
        
        // Double-check engine state
        if runTracker.runType != selectedRunType {
            print("⚠️ Engine run type mismatch detected, fixing...")
            runTracker.runType = selectedRunType
        }
        print("✅ Engine run type: \(runTracker.runType.rawValue)")
        
        // Double-check UI state
        if let hostingController = self.hostingController,
           let rootView = hostingController.rootView as? RunTrackerView {
            if rootView.selectedRunType != selectedRunType {
                print("⚠️ UI run type mismatch detected, fixing...")
                setSelectedRunType(selectedRunType)
            }
            print("✅ View run type: \(rootView.selectedRunType.rawValue)")
        }
        
        // Ensure UserDefaults is consistent
        let savedType = UserDefaults.standard.string(forKey: "selectedRunType")
        if savedType != selectedRunType.rawValue {
            print("⚠️ UserDefaults run type mismatch detected, fixing...")
            UserDefaults.standard.set(selectedRunType.rawValue, forKey: "selectedRunType")
        }
        
        // Log the final confirmed run type
        print("✅ CONFIRMED: Starting \(selectedRunType.rawValue) run")
        
        // Handle route selection for non-treadmill runs
        if selectedRunType == .treadmillRun {
            print("ℹ️ Treadmill run - routes are irrelevant")
        } else if let selectedRoute = self.selectedRoute {
            print("📍 Selected route for run: \(selectedRoute.name ?? "Unnamed")")
            let routeIdString = selectedRoute.id.uuidString
            UserDefaults.standard.set(routeIdString, forKey: "lastSelectedRouteId")
        } else {
            print("ℹ️ No route selected for this run")
        }
        
        // Present the appropriate tracking view controller based on run type
        startTrackingForRunType(selectedRunType)
    }
    
    /// Presents the appropriate tracking view controller based on run type
    public func startTrackingForRunType(_ runType: RunType) {
        print("🏃‍♂️ Starting tracking for run type: \(runType.rawValue)")
        
        // Do a final validation of the run type to ensure consistency
        let isTreadmillRun = validateRunType(runType)
        
        // Present the appropriate view controller based on verified run type
        if isTreadmillRun {
            print("🏋️ Starting treadmill run tracking")
            // Use OutdoorRunViewController with treadmill run type
            let treadmillVC = OutdoorRunViewController()
            treadmillVC.runType = .treadmillRun
            treadmillVC.modalPresentationStyle = .fullScreen
            // Note: isJoiningExistingWorkout and watchWorkoutStartDate would need to be added to OutdoorRunViewController if needed
            present(treadmillVC, animated: true)
        } else {
            // For all outdoor run types
            print("🌳 Starting outdoor run tracking of type: \(runType.rawValue)")
            let outdoorVC = OutdoorRunViewController()
            outdoorVC.runType = runType  // Set the run type for outdoor runs
            outdoorVC.delegate = self    // **ADD THIS LINE**
            
            // If we have a selected route, pass it to the outdoor view controller
            if let selectedRoute = self.selectedRoute {
                print("📍 Starting run with selected route: \(selectedRoute.name ?? "Unnamed")")
                outdoorVC.preSelectedRoute = selectedRoute
            } else {
                print("ℹ️ No pre-selected route for outdoor run")
            }
            
            outdoorVC.modalPresentationStyle = .fullScreen
            present(outdoorVC, animated: true)
        }
    }
    
    
    func outdoorRunDidComplete(with runLog: RunLog?) {
            print("🏁 Run completed, showing summary from ModernRunTrackerViewController")
            
            // Show summary here on the main tracker interface
            if let runLog = runLog {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let summaryVC = RunAnalysisViewController()
                    summaryVC.run = runLog
                    summaryVC.modalPresentationStyle = .fullScreen
                    self.present(summaryVC, animated: true)
                }
            }
        }
        
    func outdoorRunWasCanceled() {
        print("🏁 Run was canceled, returning to tracker")
        // Optionally refresh the UI or do cleanup
        objectWillChange.send()
    }
    
    private func getSelectedRunType() -> RunType {
        // Collect all possible sources of truth
        var sources: [(String, RunType)] = []
        
        // Try to get the run type from the SwiftUI view
        if let hostingController = self.hostingController,
           let rootView = hostingController.rootView as? RunTrackerView {
            let uiRunType = rootView.selectedRunType
            print("🔍 UI run type: \(uiRunType.rawValue)")
            sources.append(("UI", uiRunType))
        }
        
        // Check UserDefaults
        if let savedTypeString = UserDefaults.standard.string(forKey: "selectedRunType"),
           let savedType = RunType(rawValue: savedTypeString) {
            print("🔍 UserDefaults run type: \(savedType.rawValue)")
            sources.append(("UserDefaults", savedType))
        }
        
        // Check engine
        let engineType = runTracker.runType
        print("🔍 Engine run type: \(engineType.rawValue)")
        sources.append(("Engine", engineType))
        
        // If we have multiple sources and they all agree, use that value
        if sources.count > 1 {
            let firstType = sources[0].1
            let allAgree = sources.allSatisfy { $0.1 == firstType }
            
            if allAgree {
                print("✅ All sources agree on run type: \(firstType.rawValue)")
                return firstType
            }
        }
        
        // If we got here, there's a conflict or only one source
        // Priority order: UI > UserDefaults > Engine
        
        // 1. UI has highest priority if available
        if let uiSource = sources.first(where: { $0.0 == "UI" }) {
            print("✅ Using UI run type as source of truth: \(uiSource.1.rawValue)")
            
            // Save to UserDefaults to maintain consistency
            UserDefaults.standard.set(uiSource.1.rawValue, forKey: "selectedRunType")
            
            // Update engine if different
            if engineType != uiSource.1 {
                print("🔄 Updating engine run type to match UI: \(uiSource.1.rawValue)")
                runTracker.runType = uiSource.1
            }
            
            return uiSource.1
        }
        
        // 2. UserDefaults has second priority
        if let defaultsSource = sources.first(where: { $0.0 == "UserDefaults" }) {
            print("✅ Using UserDefaults run type as source of truth: \(defaultsSource.1.rawValue)")
            
            // Update engine if different
            if engineType != defaultsSource.1 {
                print("🔄 Updating engine run type to match UserDefaults: \(defaultsSource.1.rawValue)")
                runTracker.runType = defaultsSource.1
            }
            
            return defaultsSource.1
        }
        
        // 3. Engine has lowest priority
        print("✅ Using engine run type as fallback: \(engineType.rawValue)")
        
        // Save to UserDefaults to maintain consistency
        UserDefaults.standard.set(engineType.rawValue, forKey: "selectedRunType")
        
        return engineType
    }
    
    public func setSelectedRunType(_ runType: RunType) {
        print("🔄 Setting selected run type to: \(runType.rawValue)")
        
        // Save to UserDefaults for consistency
        UserDefaults.standard.set(runType.rawValue, forKey: "selectedRunType")
        
        // Update the engine
        if runTracker.runType != runType {
            print("⚙️ Updating engine run type from \(runTracker.runType.rawValue) to \(runType.rawValue)")
            runTracker.runType = runType
        }
        
        // Use the force update method instead of trying to update the @State property directly
        forceViewRunTypeUpdate(runType)
    }
    
    // Public method for fetching routes
    public func fetchRecommendedRoutes() {
        print("📋 PUBLIC fetchRecommendedRoutes called - adding call trace:")
        
        // Add a simple stack trace
        let symbols = Thread.callStackSymbols
        if symbols.count > 1 {
            print("📋 Called from: \(symbols[1])")
            if symbols.count > 2 {
                print("📋 Previous: \(symbols[2])")
            }
        }
        
        let routePlanner = RoutePlanner.shared
        
        // Skip if already generating route
        if routePlanner.isGeneratingRoute {
            print("⚠️ Skipping route fetch: already in progress")
            return
        }
        
        // Add debugging info
        print("📋 FETCH ROUTES STARTED for run type: \(selectedRunType)")
        
        // Perform route fetching on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Clear existing trails on main thread
            DispatchQueue.main.async {
                routePlanner.clearTrails()
            }
            
            // Flag to track if we've already performed a search
            var routeSearchPerformed = false
            
            // Simple helper to avoid duplicate searches
            func performSearch(activity: () -> Void) {
                if !routeSearchPerformed {
                    activity()
                    routeSearchPerformed = true
                } else {
                    print("⚠️ Skipping additional route search")
                }
            }
            
            // Choose the most appropriate search based on run type
            switch self.selectedRunType {
            case .trailRun:
                // For trail runs, prioritize hiking trails
                performSearch {
                    print("📋 Finding hiking trails for trail run")
                    routePlanner.findHikingTrails(radius: 10000)
                    // Since findHikingTrails doesn't have a completion handler,
                    // we need to manually update hasLoadedRoutes after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.hasLoadedRoutes = true
                    }
                }
                
            case .outdoorRun, .recoveryRun, .intervalTraining, .lapRun:
                // For most run types, just use running trails
                performSearch {
                    print("📋 Finding running trails for \(self.selectedRunType)")
                    routePlanner.findRunningTrails { success in
                        print("📋 Running trails completion handler called: success=\(success)")
                        DispatchQueue.main.async {
                            self.hasLoadedRoutes = true
                        }
                    }
                }
                
            default:
                // Default behavior - get running trails
                performSearch {
                    routePlanner.findRunningTrails { _ in
                        DispatchQueue.main.async {
                            self.hasLoadedRoutes = true
                        }
                    }
                }
            }
        }
    }
    

    
    public func handleCategorySelection(_ index: Int) {
        print("🎯 Handling category selection for index: \(index)")
        
        // Save selected category to UserDefaults
        UserDefaults.standard.set(index, forKey: UserDefaults.selectedCategoryIndexKey)
        
        // First try to use the delegate (preferred approach)
        if let delegate = categoryDelegate {
            print("🎯 Using parent delegate to handle category selection")
            delegate.didSelectCategory(at: index)
            return
        }
        
        // If no delegate, directly create and present the appropriate view controller
        print("🎯 Using direct approach to switch categories")
        let viewController = createViewControllerForCategory(index)
        
        // If we're already in a navigation controller, push the new controller
        if let navigationController = self.navigationController {
            print("🎯 Presenting in navigation controller")
            navigationController.setViewControllers([viewController], animated: true)
        } else {
            // Otherwise, find the main tab controller and replace this tab's content
            print("🎯 Looking for tab controller")
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            if let tabBarController = window.rootViewController as? UITabBarController {
                // Keep the same tab index but replace the view controller
                let currentTabIndex = tabBarController.selectedIndex
                    print("🎯 Replacing view controller in tab \(currentTabIndex) with category \(index)")
                
                if let navigationController = tabBarController.viewControllers?[currentTabIndex] as? UINavigationController {
                    navigationController.setViewControllers([viewController], animated: true)
                    } else if let currentVC = tabBarController.viewControllers?[currentTabIndex] {
                        // If we're not in a navigation controller, we need to present modally
                        print("🎯 No navigation controller, presenting modally")
                        currentVC.present(viewController, animated: true)
                    }
                } else {
                    print("🎯 Could not find tab controller, presenting modally")
                    // If all else fails, present modally from self
                    self.present(viewController, animated: true)
                }
            }
        }
    }
    
    private func createViewControllerForCategory(_ index: Int) -> UIViewController {
        switch index {
        case 0: // Running (current view)
            return ModernRunTrackerViewController()
        case 1: // Gym
            return ModernGymTrackerViewController()
        case 2: // Cycling
            return ModernBikeTrackerViewController()
        case 3: // Hiking
            return ModernHikeTrackerViewController()
        case 4: // Walking
            return ModernWalkingTrackerViewController()
        case 5: // Swimming
            return ModernSwimmingTrackerViewController()
        case 6: // Food
            return ModernFoodTrackerViewController()
        case 7: // Meditation
            return ModernMeditationTrackerViewController()
        case 8: // Sports
            return ModernSportsTrackerViewController()
        default:
            return ModernRunTrackerViewController()
        }
    }
    
    // MARK: - Settings Observer
    
    private func observePreferencesChanges() {
        // Observe when user preferences change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userPreferencesDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
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
            self.handlePreferencesChange()
        }
    }
    
    private func handlePreferencesChange() {
        // Check if run type was changed in user preferences
        if let savedTypeString = UserDefaults.standard.string(forKey: "selectedRunType"),
           let savedType = RunType(rawValue: savedTypeString) {
            
            // Only update if the engine's type doesn't match the saved type
            if savedType != self.runTracker.runType {
                print("📱 User preferences changed: updating run type from \(self.runTracker.runType.rawValue) to \(savedType.rawValue)")
                self.runTracker.runType = savedType
                
                // Use the force update method to update the view with the correct run type
                forceViewRunTypeUpdate(savedType)
                return // Skip the standard view refresh since we're doing a complete refresh
            }
        }
        
        // Instead of recreating the view, just notify it about the preference change
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Send objectWillChange to notify the view that user preferences changed
            self.objectWillChange.send()
            print("🔄 Notified view about preference change without recreating it")
        }
    }
    
    // Update this method to create animations programmatically at runtime
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
    
    // Add this property to conform to CategorySelectionDelegate's expected value
    var currentSelectedCategoryIndex: Int? {
        return UserDefaults.standard.object(forKey: UserDefaults.selectedCategoryIndexKey) as? Int
    }
    
    // MARK: - CategorySelectionDelegate
    
    func didSelectCategory(at index: Int) {
        print("🎯 ModernRunTrackerViewController didSelectCategory called with index: \(index)")
        
        // Save the selection to UserDefaults
        UserDefaults.standard.set(index, forKey: UserDefaults.selectedCategoryIndexKey)
        
        // Notify observers that the category has changed
        NotificationCenter.default.post(
            name: .categoryDidChange,
            object: nil,
            userInfo: ["index": index]
        )
        
        // Use the delegate hierarchy if available
        if let delegate = categoryDelegate {
            delegate.didSelectCategory(at: index)
        } else {
            // Direct category switch if no delegate
            print("🎯 No parent delegate, handling category switch directly")
            handleCategorySelection(index)
        }
    }
    
    // Function to generate a forecast description based on weather data
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
    
    // Function to get the appropriate weather icon name based on condition and time of day
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
    
    // MARK: - Public Methods
    
 
    
    // Add this method to handle the treadmill run edge case
    public func validateRunType(_ runType: RunType) -> Bool {
        print("🔍 Validating run type: \(runType.rawValue)")
        
        if runType == .treadmillRun {
            print("✅ Confirmed treadmill run type. Will present TreadmillRunViewController.")
            
            // Double check the run trackers run type matches
            if runTracker.runType != .treadmillRun {
                print("⚠️ RunTracker had wrong run type! Setting to treadmill run.")
                runTracker.runType = .treadmillRun
            }
            
            return true
        }
        
        // Not a treadmill run
        print("🌳 Run type is not treadmill: \(runType.rawValue)")
        
        if runTracker.runType != runType {
            print("⚠️ RunTracker had wrong run type! Setting to \(runType.rawValue)")
            runTracker.runType = runType
        }
        
        return false
    }
    
    // Helper method to determine if a trail is a loop
    func isLoopTrail(_ coordinates: [Coordinate]) -> Bool {
        guard let first = coordinates.first, let last = coordinates.last else {
            return false
        }
        
        // Calculate distance between start and end points
        let startLat = first.latitude
        let startLon = first.longitude
        let endLat = last.latitude
        let endLon = last.longitude
        
        // Simple distance calculation (Euclidean)
        let distance = sqrt(pow(endLat - startLat, 2) + pow(endLon - startLon, 2))
        
        // If start and end points are close enough, consider it a loop
        return distance < 0.001 // Approximately 100 meters in decimal degrees
    }
    
    /// Check if a route is currently selected
    private func isRouteSelected(route: Route) -> Bool {
        return selectedRoute?.name == route.name
    }
    
    /// Toggle route selection (select if not selected, deselect if already selected)
    func toggleRouteSelection(route: Route) {
        if isRouteSelected(route: route) {
            // Deselect the route
            print("🚫 Deselected route: \(route.name ?? "Unnamed")")
            selectedRoute = nil
        } else {
            // Select the route
            print("✅ Selected route: \(route.name ?? "Unnamed")")
            selectedRoute = route
        }
        
        // Notify observers that the route changed
        objectWillChange.send()
    }
    
    /// Directly select a route (without toggling)
    func selectRoute(route: Route) {
        self.selectedRoute = route
        print("✅ Selected route: \(route.name ?? "Unnamed")")
        // Notify observers that the route changed
        self.objectWillChange.send()
    }
    
    // MARK: - Run History Delegate
    
    func didSelectRun(_ run: Any) {
        // Handle the selected run, e.g., show details or prepare to start a similar run
        print("Selected run: \(run)")
        
        // Here you could implement functionality to:
        // 1. Show detailed run stats
        // 2. Offer to start a similar run (same route or type)
        // 3. Compare with other runs
        
        // For now, we'll just show a detail view
        let detailVC = RunDetailViewController()
        
        if let outdoorRun = run as? RunLog {
            detailVC.configure(with: outdoorRun)
        } else if let indoorRun = run as? IndoorRunLog {
            detailVC.configure(with: indoorRun)
        }
        
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    // MARK: - Run History
  
    
    // Set up route change notifications
    private func setupRouteChangeNotifications() {
        // Set up notification center observer for route changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RoutesDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("📣 [ViewController] ✅ RECEIVED RoutesDidChange notification")
            // Get sender information
            if let sender = notification.object {
                print("📣 [ViewController] Notification sent by: \(type(of: sender))")
            }
            if let userInfo = notification.userInfo {
                print("📣 [ViewController] UserInfo: \(userInfo)")
            }
            print("📣 [ViewController] Trail count: \(RoutePlanner.shared.nearbyTrails.count)")
            
            // Force refresh by changing the ID
            guard let self = self else { return }
            
            // Simple refresh without redundant operations
            DispatchQueue.main.async {
                self.routesForceRefreshID = UUID()
                self.objectWillChange.send()
                
                if !self.hasLoadedRoutes && !self.routePlanner.nearbyTrails.isEmpty {
                    self.hasLoadedRoutes = true
                    print("🔄 [ViewController] Updated hasLoadedRoutes to true after notification")
                }
                print("🔄 [ViewController] Forced UI refresh with new UUID")
            }
        }
    }
    
    // Add this method to show run history using proper SwiftUI methods
    func showRunHistoryDirectly() {
        // Create the history view controller
        let historyVC = RunHistoryViewController()
        // Use our view extension to present the controller properly
        let navController = UINavigationController(rootViewController: historyVC)
        navController.modalPresentationStyle = .fullScreen
        self.present(navController, animated: true)
    }
    
    // MARK: - Event Handlers
    
    @objc func handleMapRegionChanged(_ notification: Notification) {
        // Update map position based on notification
        if let position = notification.userInfo?["position"] as? String {
            DispatchQueue.main.async {
                switch position {
                case "minimized":
                    self.mapPosition = .minimized
                case "fullscreen":
                    self.mapPosition = .fullscreen
                case "hidden":
                    self.mapPosition = .hidden
                default:
                    break
                }
            }
        }
    }
    
    // Add a property for WorldExplorerMap sheet
    @Published var showWorldExplorerMapSheet = false
    
    // Force a full view refresh with a specific run type
    private func forceViewRunTypeUpdate(_ runType: RunType) {
        print("🔨 Forcing view update to run type: \(runType.rawValue)")
        
        // Don't try to update the @State property directly, as it might not take effect
        // Instead, recreate the SwiftUI view with the correct run type
        if let hostingController = self.hostingController {
            // Get a reference to the current view
            if let runTrackerView = hostingController.rootView as? RunTrackerView {
                // Create a new RunTrackerView with the same parameters but updated run type
                let newView = RunTrackerView(
                    viewModel: self,
                    runTrackingEngine: self.runTracker,
                    categoryDelegate: runTrackerView.categoryDelegate,
                    initialHasLoadedRoutes: runTrackerView.hasLoadedRoutes,
                    initialRunType: runType // Set the run type explicitly
                )
                
                // Replace the view on the main thread
                DispatchQueue.main.async {
                    hostingController.rootView = newView
                    print("✅ View completely refreshed with run type: \(runType.rawValue)")
                }
            }
        }
    }
    
    // MARK: - Active Watch Workout Detection

    /// Checks if there's an active workout on the watch and prepares data for the card UI
    private func checkForActiveWatchWorkouts() {
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else {
            print("📱 DIAGNOSTIC: Watch app not available - activation: \(session.activationState.rawValue), paired: \(session.isPaired), installed: \(session.isWatchAppInstalled)")
            return
        }
        
        print("📱 DIAGNOSTIC: Sending active workout check to watch...")
        
        // Use requestActiveRunningWorkout which is what the watch expects
        let message: [String: Any] = ["type": "requestActiveRunningWorkout"]
        session.sendMessage(message, replyHandler: { [weak self] response in
            print("📱 DIAGNOSTIC: Received watch response: \(response)")
            
            guard let self = self else { return }
            
            // Check for the specific format we're seeing in the logs where the watch just acknowledges receipt
            if let type = response["type"] as? String, type == "requestActiveRunningWorkout",
               let status = response["status"] as? String, status == "received" {
                
                print("📱 Watch acknowledged our request but didn't provide workout data")
                
                // Instead of directly setting hasActiveWatchWorkout to false, check if we have
                // data from syncWorkoutData messages that might indicate an active workout
                if let activeWorkoutData = self.activeWorkoutData, activeWorkoutData.distance > 0 {
                    print("📱 Using existing active workout data from syncWorkoutData messages")
                    return // Keep existing workout data
                }
                
                // Otherwise reset as there's no active workout
                DispatchQueue.main.async {
                    self.hasActiveWatchWorkout = false
                    self.activeWorkoutData = nil
                }
                return
            }
            
            // The standard processing for full workout data response
            // Reset active workout state first
            DispatchQueue.main.async {
                self.hasActiveWatchWorkout = false
                self.activeWorkoutData = nil
            }
            
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
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    print("📱 DIAGNOSTIC: Setting activeWorkoutData and hasActiveWatchWorkout=true")
                    self.activeWorkoutData = workoutData
                    self.hasActiveWatchWorkout = true
                    
                    // Only send the objectWillChange notification to refresh existing views
                    // without recreating them
                    self.objectWillChange.send()
                    
                    // Don't force view refresh on hosting controller
                    // This was causing multiple view recreations
                    // if let hostingController = self.hostingController {
                    //     print("📱 DIAGNOSTIC: Refreshing hosting controller view")
                    //     hostingController.rootView = hostingController.rootView
                    // }
                }
            } else {
                print("📱 DIAGNOSTIC: No active workout found on watch. isActive: \(isActive), state: \(workoutState)")
            }
        }, errorHandler: { error in
            print("📱 DIAGNOSTIC: Error checking for active workout: \(error.localizedDescription)")
        })
    }

    /// Formats time interval into a readable string (HH:MM:SS)
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

 

    /// Join a watch workout using the active workout data
    public func joinWatchWorkout() {
        guard let activeWorkout = activeWorkoutData else {
            print("⚠️ Cannot join - no active workout data")
            return
        }
        
        print("📱 Joining workout from watch")
        
        // Get run type from workout data
        let runType: RunType = activeWorkout.isIndoor ? .treadmillRun : .outdoorRun
        
        // Determine run state
        let runState: RunState = activeWorkout.normalizedState.rawValue == "inProgress" ? .running : .paused
        
        // Set up the appropriate view controller for this run type
        if activeWorkout.isIndoor {
            // Create treadmill view controller using OutdoorRunViewController
            let treadmillVC = OutdoorRunViewController()
            treadmillVC.runType = .treadmillRun
            // Note: isJoiningExistingWorkout and watchWorkoutStartDate would need to be added to OutdoorRunViewController if needed
            
            // Import the workout
            runTracker.importWorkoutFromWatch(
                runType: runType,
                isIndoorMode: activeWorkout.isIndoor,
                distance: Measurement(value: activeWorkout.distance, unit: UnitLength.meters),
                elapsedTime: activeWorkout.elapsedTime,
                heartRate: activeWorkout.heartRate,
                calories: activeWorkout.calories,
                cadence: activeWorkout.cadence,
                rawData: activeWorkout.rawData,
                startDate: activeWorkout.startDate
            )
            
            // Present the view controller
            treadmillVC.modalPresentationStyle = .fullScreen
            present(treadmillVC, animated: true)
        } else {
            // Create outdoor view controller
            let outdoorVC = OutdoorRunViewController()
            outdoorVC.isJoiningExistingWorkout = true
            outdoorVC.watchWorkoutStartDate = activeWorkout.startDate
            outdoorVC.runType = runType
            
            // Import the workout
            runTracker.importWorkoutFromWatch(
                runType: runType,
                isIndoorMode: activeWorkout.isIndoor,
                distance: Measurement(value: activeWorkout.distance, unit: UnitLength.meters),
                elapsedTime: activeWorkout.elapsedTime,
                heartRate: activeWorkout.heartRate,
                calories: activeWorkout.calories,
                cadence: activeWorkout.cadence,
                rawData: activeWorkout.rawData,
                startDate: activeWorkout.startDate
            )
            
            // Present the view controller
            outdoorVC.modalPresentationStyle = .fullScreen
            present(outdoorVC, animated: true)
        }
        
        // Send explicit join confirmation to watch to streamline communication
        // This tells the watch we've successfully joined so it can optimize its messages
        sendJoinConfirmationToWatch()
        
        // Clear active workout data now that we've joined
        hasActiveWatchWorkout = false
        activeWorkoutData = nil
        
        // Force UI refresh
        objectWillChange.send()
    }
    
    // Send join confirmation to watch
    private func sendJoinConfirmationToWatch() {
        // Make sure WCSession is available
        guard WCSession.default.activationState == .activated else {
            print("⚠️ Cannot send join confirmation - WCSession not activated")
            return
        }
        
        // Create join confirmation message with enhanced data
        let joinMessage: [String: Any] = [
            "type": "joinedWorkoutFromPhone",
            "status": "success",
            "timestamp": Date().timeIntervalSince1970,
            "phoneIsJoining": true,
            "phoneState": runTracker.runState.rawValue,
            "phoneElapsedTime": runTracker.elapsedTime,
            "phoneDistance": runTracker.distance.value,
            "hasGoodLocationData": runTracker.hasGoodLocationData,
            "isPrimaryForHeartRate": runTracker.isPrimaryForHeartRate,
            "isPrimaryForDistance": runTracker.isPrimaryForDistance,
            "isPrimaryForPace": runTracker.isPrimaryForPace
        ]
        
        // Send the message
        if WCSession.default.isReachable {
            // Use interactive messaging when watch is reachable
            WCSession.default.sendMessage(joinMessage, replyHandler: { reply in
                print("📱 Watch received join confirmation: \(reply)")
                
                // Update the engine to recognize we've sent the join confirmation
                if let status = reply["status"] as? String, status == "received" {
                    // Mark in the engine that we've sent join confirmation
                    self.runTracker.watchHasAcknowledgedJoin = true
                }
            }, errorHandler: { error in
                print("⚠️ Error sending join confirmation: \(error.localizedDescription)")
            })
        } else {
            // Fall back to context update if not reachable
            try? WCSession.default.updateApplicationContext(joinMessage)
            print("📱 Sent join confirmation via context update")
        }
        
        print("📱 Sent join confirmation to watch")
    }
    
    @ViewBuilder
    public func createActiveWorkoutCardView() -> some View {
        if hasActiveWatchWorkout, let workoutData = activeWorkoutData {
            VStack(spacing: 0) {
                // Card content
                VStack(alignment: .leading, spacing: 12) {
                    // Header with workout type and state
                    HStack {
                        Label(
                            workoutData.runTypeText,
                            systemImage: workoutData.isIndoor ? "figure.run" : "figure.hiking"
                        )
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Status pill
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
                    
                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 1)
                    
                    // Metrics grid (2x2)
                    VStack(spacing: 12) {
                        // Top row: Distance & Time
                    HStack(spacing: 16) {
                        // Distance
                            VStack(alignment: .leading, spacing: 4) {
                            Text("Distance")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            Text(workoutData.formattedDistance)
                                    .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Time
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
                        
                        // Bottom row: Pace & Heart Rate (if available)
                        HStack(spacing: 16) {
                            // Pace
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pace")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                Text(workoutData.formattedPace)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Heart Rate if available
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
                    
                    // Join button
                    Button(action: {
                        self.joinWatchWorkout()
                    }) {
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

    // MARK: - WCSession Delegate Methods
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("📱 WCSession activation completed with state: \(activationState.rawValue)")
        if let error = error {
            print("📱 WCSession activation error: \(error.localizedDescription)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("📱 WCSession deactivated")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        processWatchMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        processWatchMessage(message)
        replyHandler(["status": "received"])
    }
    
    private func processWatchMessage(_ message: [String: Any]) {
        // Ensure we're on the main thread for all SwiftUI property updates
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.processWatchMessage(message)
            }
            return
        }

         // CRITICAL FIX: Stop processing syncWorkoutData when run is completed
        if let messageType = message["type"] as? String,
            messageType == "syncWorkoutData" && runTracker.runState == .completed {
            print("📱 Ignoring syncWorkoutData - run is already completed")
            return
        }
    
        // CRITICAL FIX: Handle command messages even when OutdoorRunViewController is active
        if let messageType = message["type"] as? String {
            if messageType == "outdoorRunStateChange" || messageType == "indoorRunStateChange" {
                print("📱 ModernRunTrackerViewController: Processing \(messageType) command message")
                // Forward command messages to RunTrackingEngine regardless of active view controller
                runTracker.session(WCSession.default, didReceiveMessage: message, replyHandler: { response in
                    print("📱 ModernRunTrackerViewController: Command processed with response: \(response)")
                })
                return
            }
        }
        
      

        // Check if we're in an active OutdoorRunViewController session for syncWorkoutData only
        if let topViewController = UIApplication.shared.windows.first?.rootViewController?.topMostViewController(),
           topViewController is OutdoorRunViewController {
            // Only skip syncWorkoutData processing for NEW workout detection, not ongoing sync
            if let messageType = message["type"] as? String, messageType == "syncWorkoutData" {
                // **CHANGED: Forward to RunTrackingEngine for ongoing sync instead of skipping**
                if runTracker.runState != .notStarted {
                    print("📱 ModernRunTrackerViewController: Forwarding syncWorkoutData to RunTrackingEngine (OutdoorRunViewController active)")
                    runTracker.processWatchMessage(message)
                } else {
                    print("📱 ModernRunTrackerViewController: Skipping syncWorkoutData processing - OutdoorRunViewController is active but no run started")
                }
                return
            }
        }

        // Also check if RunTrackingEngine is in an active outdoor run state for syncWorkoutData only
        if runTracker.runState != .notStarted && !runTracker.isIndoorMode {
            if let messageType = message["type"] as? String, messageType == "syncWorkoutData" {
                // **CHANGED: Always forward to RunTrackingEngine for sync instead of skipping**
                print("📱 ModernRunTrackerViewController: Forwarding syncWorkoutData to RunTrackingEngine (Active outdoor run)")
                runTracker.processWatchMessage(message)
                return
            }
        }
        
        // Track whether we're already joined to a workout
        let alreadyJoined = runTracker.runState != .notStarted
        
        // Check if this is workout sync data that could indicate an active workout
        if let messageType = message["type"] as? String, messageType == "syncWorkoutData" {
            // Message batching: Implement rate limiting to avoid processing too many messages
            let now = Date()
            if alreadyJoined && now.timeIntervalSince(lastSyncDataProcessTime) < 0.5 {
                // If we received a message within the last 0.5 seconds, just queue it and return
                pendingSyncMessages.append(message)
                if pendingSyncMessages.count > 10 {
                    // Keep only the most recent messages if the queue gets too large
                    pendingSyncMessages.removeFirst(pendingSyncMessages.count - 10)
                }
                return
            }
            
            // Update the timestamp for rate limiting
            lastSyncDataProcessTime = now
            
            // Reduce log spam once we've joined the workout
            if !alreadyJoined {
                print("📱 Received workout sync data from watch")
            }
            
            // Skip processing if we're already running a workout
            // This prevents false detection of a "new" watch workout when we're already synced
            if alreadyJoined {
                // Forward to RunTrackingEngine for ongoing metric updates
                print("📱 ModernRunTrackerViewController: Forwarding syncWorkoutData to RunTrackingEngine")
                runTracker.processWatchMessage(message)
                
                // Process any pending messages that were queued during rate limiting
                processPendingMessages()
                return
            }
            
            // Check if the message indicates active metrics
            let hasDistance = (message["distance"] as? Double ?? 0) > 0 || message["hasDistance"] as? Bool ?? false
            let hasHeartRate = (message["heartRate"] as? Double ?? 0) > 0 || message["hasHeartRate"] as? Bool ?? false
            let hasPace = (message["pace"] as? Double ?? 0) > 0 || message["hasPace"] as? Bool ?? false
            
            // Determine if this appears to be an active workout
            let isActiveWorkout = hasDistance || hasHeartRate || hasPace
            
            if isActiveWorkout {
                print("📱 Active workout detected from syncWorkoutData message")
                
                // Extract workout details - ensure we have default values to prevent nil issues
                let isIndoorMode = message["isIndoor"] as? Bool ?? false
                let distance = message["distance"] as? Double ?? 0
                let elapsedTime = message["elapsedTime"] as? Double ?? 0
                let heartRate = message["heartRate"] as? Double ?? 0
                let calories = message["calories"] as? Double ?? 0
                let cadence = message["cadence"] as? Double ?? 0
                let pace = message["pace"] as? Double ?? 0
                
                // Extract start time or calculate it from elapsed time
                var startDate = Date(timeIntervalSinceNow: -elapsedTime)
                if let startTimestamp = message["startDate"] as? TimeInterval {
                    startDate = Date(timeIntervalSince1970: startTimestamp)
                } else if let startTimestamp = message["startTime"] as? TimeInterval {
                    startDate = Date(timeIntervalSince1970: startTimestamp)
                }
                
                // Determine run state
                let workoutState = message["state"] as? String ?? "inProgress"
                
                // Create the active workout data object
                let workoutData = ActiveWatchWorkoutData(
                    isIndoor: isIndoorMode,
                    state: workoutState,
                    distance: distance,
                    elapsedTime: elapsedTime,
                    heartRate: heartRate,
                    calories: calories,
                    cadence: cadence,
                    pace: pace,
                    startDate: startDate,
                    rawData: message
                )
                
                // Log initial pace information for debugging
                print("🏃‍♂️ PACE DEBUG: Initial pace from watch: \(pace), formatted: \(workoutData.formattedPace)")
                
                // Update UI - we're already on main thread from the check at the top
                print("📱 Setting activeWorkoutData and hasActiveWatchWorkout=true from sync message")
                self.activeWorkoutData = workoutData
                self.hasActiveWatchWorkout = true
                self.objectWillChange.send()
            }
        }
    }
    
    /// Process data for ongoing workout
    private func processOngoingWorkoutData(_ message: [String: Any]) {
        // Ensure we're on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.processOngoingWorkoutData(message)
            }
            return
        }
        
        guard let activeWorkout = activeWorkoutData else {
            print("⚠️ Cannot process ongoing workout data - no active workout")
            return
        }
        
        // Extract metrics from message
        let heartRate = message["heartRate"] as? Double ?? activeWorkout.heartRate
        let distance = message["distance"] as? Double ?? activeWorkout.distance
        let elapsedTime = message["elapsedTime"] as? TimeInterval ?? activeWorkout.elapsedTime
        let calories = message["calories"] as? Double ?? activeWorkout.calories
        let cadence = message["cadence"] as? Double ?? activeWorkout.cadence
        var workoutState = message["state"] as? String ?? activeWorkout.state
        
        // Extract pace and log debug info
        let paceBefore = activeWorkout.pace
        let incomingPace = message["pace"] as? Double ?? activeWorkout.pace
        
        // CRITICAL FIX: Determine correct pace value based on format consistently
        // We need to ALWAYS store pace in seconds/km format regardless of incoming format
        let processedPace: Double
        
        // Process different pace formats based on clear numeric ranges
        if incomingPace > 20 {
            // Already in seconds/km format (typically 200-800 for most running paces)
            processedPace = incomingPace
        } else if incomingPace >= 0.5 && incomingPace <= 5.0 {
            // In meters/second format (typically 2.5-4.5 m/s for casual runners)
            // Convert from speed to pace (seconds per km)
            processedPace = (incomingPace > 0) ? 1000.0 / incomingPace : 0
        } else if incomingPace > 0 && incomingPace < 0.1 {
            // In seconds/meter format (very small numbers like 0.004)
            // Convert to seconds/km
            processedPace = incomingPace * 1000.0
        } else {
            // Use previous pace if we can't determine format
            processedPace = activeWorkout.pace
        }
        
        // Check timestamp sync
        let timestamp = message["timestamp"] as? TimeInterval ?? 0
        if timestamp > 0 {
            let messageTime = Date(timeIntervalSince1970: timestamp)
            let timeDiff = abs(messageTime.timeIntervalSinceNow)
            if timeDiff > 3.0 {
                print("⚠️ Large time difference (\(timeDiff)s) between watch and phone")
            }
        }
        
        // Use the incoming data to update our active workout
        let updatedWorkout = ActiveWatchWorkoutData(
            isIndoor: activeWorkout.isIndoor,
            state: workoutState,
            distance: distance,
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            calories: calories,
            cadence: cadence,
            pace: processedPace,
            startDate: activeWorkout.startDate,
            rawData: message
        )
        
        // Update our active workout data - already on main thread, no need for dispatch
        self.activeWorkoutData = updatedWorkout
        self.objectWillChange.send()
    }
    
    // Helper method to process any pending messages in the queue
    private func processPendingMessages() {
        // If we have pending messages, process at most 3 of them to avoid flooding
        var processCount = 0
        while !pendingSyncMessages.isEmpty && processCount < 3 {
            let nextMessage = pendingSyncMessages.removeFirst()
            
            // Only process if we have active workout data
            if hasActiveWatchWorkout && activeWorkoutData != nil {
                processOngoingWorkoutData(nextMessage)
            }
            
            // Forward to run tracker
            runTracker.processWatchMessage(nextMessage)
            
            processCount += 1
        }
        
        // If we still have more messages, log the count but keep them for next batch
        if !pendingSyncMessages.isEmpty && pendingSyncMessages.count > 5 {
            print("📱 Still have \(pendingSyncMessages.count) pending sync messages in queue")
        }
    }
}





// MARK: - Main View Structs

struct RunTrackerView: View {
    @ObservedObject var viewModel: ModernRunTrackerViewController
    @State private var showRoutePreview: Bool = false
    @State private var selectedTrailForPreview: Trail? = nil
    @ObservedObject var runTrackingEngine: RunTrackingEngine
    @StateObject private var locationManager = ModernLocationManager.shared
    @StateObject private var routePlanner = RoutePlanner.shared // Make sure this is properly initialized
    @StateObject private var weatherService = WeatherService.shared
    @ObservedObject private var userPreferences = UserPreferences.shared
    @State var locationCity: String = "Loading Location ..."
    var categoryDelegate: CategorySelectionDelegate?
    // State properties
    @State public var selectedRunType: RunType = .outdoorRun {
        didSet {
            print("🔄 SwiftUI didSet: selectedRunType changed from \(oldValue.rawValue) to \(selectedRunType.rawValue)")
            
            // Skip processing if it's the same run type (even though didSet shouldn't be called in this case)
            guard oldValue != selectedRunType else {
                print("✅ SwiftUI didSet: No change in run type, staying with: \(selectedRunType.rawValue)")
                return
            }
            
            // When the run type changes in the UI through explicit user selection,
            // update the engine and validate the selection
            print("⚠️ SwiftUI didSet: Engine run type (\(runTrackingEngine.runType.rawValue)) doesn't match UI - updating engine")
            runTrackingEngine.runType = selectedRunType
            print("✅ Set selectedRunType to \(selectedRunType.rawValue)")
            
            // Save to UserDefaults
            UserDefaults.standard.set(selectedRunType.rawValue, forKey: "selectedRunType")
            print("💾 Saved run type \(selectedRunType.rawValue) to UserDefaults")
            
            // Update the engine
            print("🔄 Updated runTrackingEngine.runType to \(selectedRunType.rawValue)")
            
            // Validate the run type selection
            let isTreadmillRun = viewModel.validateRunType(selectedRunType)
            
            // Log the result of validation
            if isTreadmillRun {
                print("ℹ️ Treadmill run selected - routes not applicable")
            } else {
                print("ℹ️ Outdoor run type selected: \(selectedRunType.rawValue)")
            }
        }
    }
    @State private var selectedDuration: TimeInterval = 1800 // 30 minutes
    @State private var showingRouteSelection = false
    @State private var weatherDataLoaded = false
    @State private var temperature: Double = 0
    @State private var humidity: Double = 0
    @State private var windSpeed: Double = 0
    @State private var weatherCondition: WeatherCondition = .clear
    @State private var weatherIconName: String = "sun.max.fill"
    @State public var hasLoadedRoutes = false
    @State private var showingCategorySelector = false
    @State private var showingSettingsView = false
    @State private var showingRunTypeInfo = false // For showing run type details
    @State private var infoForRunType: RunType? = nil // The run type to show info for
    @State private var showingFindRoutesView = false // For showing find routes view
    @State private var showRunTypeSelectionAnimation = false // Animation state
    @State private var isNightMode: Bool = false // Added missing isNightMode property
    @State private var routesForceRefreshID = UUID() // Used to force view refresh
    @State public var showRunHistorySheet = false
    
    // Reference to parent controller's runTracker
    private var runTracker: RunTrackingEngine { runTrackingEngine }
    
    // Category data
    private let categoryTitles = ["Running", "Gym", "Cycling", "Hiking", "Walking", "Swimming", "Food", "Meditation", "Sports"]
    private let categoryIcons = ["figure.run", "figure.strengthtraining.traditional", "figure.outdoor.cycle", "figure.hiking", "figure.walk", "figure.pool.swim", "fork.knife", "sparkles", "sportscourt"]
    @State private var selectedCategoryIndex: Int = 0 // Track the selected category
    
    // Initialize with external hasLoadedRoutes state
    init(viewModel: ModernRunTrackerViewController, 
         runTrackingEngine: RunTrackingEngine, 
         categoryDelegate: CategorySelectionDelegate?,
         initialHasLoadedRoutes: Bool = false,
         initialRunType: RunType? = nil) {
        self.viewModel = viewModel
        self.runTrackingEngine = runTrackingEngine
        self.categoryDelegate = categoryDelegate
        self._hasLoadedRoutes = State(initialValue: initialHasLoadedRoutes)
        
        // Set the initial run type if provided
        if let initialRunType = initialRunType {
            self._selectedRunType = State(initialValue: initialRunType)
            print("🏁 RunTrackerView initialized with explicit run type: \(initialRunType.rawValue)")
        } else {
            // Otherwise load from preferences or default to outdoorRun
            if let savedTypeString = UserDefaults.standard.string(forKey: "selectedRunType"),
               let savedType = RunType(rawValue: savedTypeString) {
                self._selectedRunType = State(initialValue: savedType)
                print("🏁 RunTrackerView initialized with saved run type: \(savedType.rawValue)")
            } else {
                self._selectedRunType = State(initialValue: .outdoorRun)
                print("🏁 RunTrackerView initialized with default run type: outdoorRun")
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background with dynamic gradient
            backgroundView()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Top section with header, category button, and settings button
                    headerSection()
                    
                    // Weather section
                    weatherSection()
                    
                    // Active watch workout card (if available)
                    viewModel.createActiveWorkoutCardView()
                    
                    // Run Type Selector
                    runTypeSelectorSection()
                    
                    // Nearby routes section - explicitly add .id to force refresh
                    recommendedRoutesSection()
                        .id(routesForceRefreshID)  // Force refresh when this ID changes
                    
                    // Start run button
                    startRunButtonSection()
                    
                    // Quick actions
                    quickActionsSection()
                    
                    // Running stats section - observe data changes for reactive updates
                    runningStatsSection()
                        .id("stats-\(viewModel.routesForceRefreshID)")
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
                        print("🎯 CategorySelectorView selected index: \(newIndex)")
                        // Directly update UI state
                        self.selectedCategoryIndex = newIndex
                        // Close the sheet first
                        self.showingCategorySelector = false
                        // Use a delay before triggering the navigation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            // Call the delegate directly for navigation
                            viewModel.categoryDelegate?.didSelectCategory(at: newIndex)
                        }
                    }
                ),
                categories: Array(zip(categoryTitles, categoryIcons)).map { ($0.0, $0.1) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSettingsView) {
            RunSettingsView()
        }
        .sheet(isPresented: $showingRouteSelection) {
            RouteSelectionView(onSelectRoute: { selectedRoute in
                // Set selected route using DispatchQueue to avoid SwiftUI build errors
                DispatchQueue.main.async {
                viewModel.selectedRoute = selectedRoute
                }
                showingRouteSelection = false
            }, onCancel: {
                showingRouteSelection = false
            })
        }
        .sheet(isPresented: $showingRunTypeInfo) {
            RunTypeInfoView(selectedType: infoForRunType)
        }
        .sheet(isPresented: $showingFindRoutesView) {
            FindRoutesView()
        }
        .onAppear {
            // First request location access
            locationManager.requestWhenInUseAuthorization()
            
            // Load weather with a slight delay to ensure location is available
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                loadWeatherData()
            }
            
            // Run remaining initialization
            handleOnAppear()
            
            // Initialize the selected category
            initializeSelectedCategory()
            
            // Set up a retry for weather if it fails to load
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if !viewModel.weatherDataLoaded {
                    print("⚠️ Weather loading timeout - retrying")
                    loadWeatherData()
                }
            }
            
            // Subscribe to route change notifications
            setupRouteChangeNotifications()
        }
        .sheet(isPresented: $showingCategorySelector) {
            CategorySelectorView(
                isPresented: $showingCategorySelector,
                selectedCategory: Binding(
                    get: { self.selectedCategoryIndex },
                    set: { newIndex in
                        print("🎯 CategorySelectorView selected index: \(newIndex)")
                        // Directly update UI state
                        self.selectedCategoryIndex = newIndex
                        // Close the sheet first
                        self.showingCategorySelector = false
                        // Use a delay before triggering the navigation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            // Call the delegate directly for navigation
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
    
    // Add method to initialize the selected category
    private func initializeSelectedCategory() {
        print("🔄 Initializing selected category in RunTrackerView")
        
        // Try to load the saved category index from UserDefaults
        if let savedCategoryIndex = UserDefaults.standard.object(forKey: "selectedCategoryIndex") as? Int {
            // Validate the index is within bounds
            if savedCategoryIndex >= 0 && savedCategoryIndex < categoryTitles.count {
                print("🔄 Using saved category index: \(savedCategoryIndex)")
                withAnimation {
                    selectedCategoryIndex = savedCategoryIndex
                }
            }
        }
        
        // Check if there's a category delegate that might have a different selection
        if let delegate = viewModel.categoryDelegate {
            print("🔄 Category delegate found")
            // Update based on the delegate's current selection
            if let currentIndex = delegate.currentSelectedCategoryIndex, 
               currentIndex >= 0 && currentIndex < categoryTitles.count {
                print("🔄 Using delegate category index: \(currentIndex)")
                withAnimation {
                    selectedCategoryIndex = currentIndex
                }
            }
            
            // Subscribe to category change notifications
            NotificationCenter.default.addObserver(
                forName: .categoryDidChange,
                object: nil,
                queue: .main
            ) { [self] notification in
                if let userInfo = notification.userInfo,
                   let newIndex = userInfo["index"] as? Int,
                   newIndex >= 0 && newIndex < self.categoryTitles.count {
                    print("🔄 Received category change notification with index: \(newIndex)")
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        self.selectedCategoryIndex = newIndex
                    }
                    
                    // Provide haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        } else {
            print("⚠️ No category delegate found")
        }
        
        // Log the final selection
        print("🔄 Final selected category index: \(selectedCategoryIndex) - \(categoryTitles[selectedCategoryIndex])")
    }
    

    
    private func updateNightMode() {
        let hour = Calendar.current.component(.hour, from: Date())
        self.isNightMode = hour < 6 || hour > 18
    }
    
    // Set up route change notifications in the SwiftUI view
    private func setupRouteChangeNotifications() {
        // Setup notification observer for route changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RoutesDidChange"),
            object: nil,
            queue: .main
        ) { [self] notification in
            // Get sender information
            if let sender = notification.object {
            }
            
            // Check if this is a force update notification
            let forceUpdate = (notification.userInfo?["forceUIUpdate"] as? Bool) ?? false
            
            // Simple, non-redundant refresh - just update the ID to force view refresh
            DispatchQueue.main.async {
                // Update the local UUID to force refresh the view
                self.routesForceRefreshID = UUID()
                
                // Update hasLoadedRoutes if needed
                if !self.hasLoadedRoutes && !routePlanner.nearbyTrails.isEmpty {
                    self.hasLoadedRoutes = true
                    print("🔄 [SwiftUI View] Updated hasLoadedRoutes to true after notification")
                }
                
                // If this is a force update, use more aggressive UI update strategies
                if forceUpdate {
                    print("🔄 [SwiftUI View] Force UI update requested - applying extra updates")
                    
                    // Mimic the behavior of run type button changes
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        // Toggle the animation state to force redraw
                        self.showRunTypeSelectionAnimation = false
                        
                        // Re-enable after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                self.showRunTypeSelectionAnimation = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func backgroundView() -> some View {
        Color(UIColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0))
            .edgesIgnoringSafeArea(.all)
    }
    
    private func headerSection() -> some View {
        HStack(spacing: 16) { // Add spacing between elements
            VStack(alignment: .leading, spacing: 8) {
                Text("Run Tracker")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Let's go for a run")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Add the category and settings buttons here
            HStack {
                // Category Button
                Button(action: {
                    showingCategorySelector = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 14, weight: .medium))
                        Text("Running")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
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
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
            }
            .padding(.horizontal)
            
            settingsButton()
        }
        .padding(.horizontal)
        .padding(.vertical, 8) // Add vertical padding
        .contentShape(Rectangle()) // Make entire header tappable if needed
    }
    
    private func categoryButton() -> some View {
        Button(action: {
            // Trigger haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            print("🔘 Category button tapped - showing selector sheet")
            showingCategorySelector = true
            
        }) {
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
                    gradient: Gradient(colors: [
                        Color(red: 0.976, green: 0.576, blue: 0.125),
                        Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.8)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }
    
    public func handleCategorySelection(_ index: Int) {
        print("🎯 RunTrackerView: handleCategorySelection called with index: \(index)")
        
        // Update local state
        selectedCategoryIndex = index
        
        // Save to UserDefaults
        UserDefaults.standard.set(index, forKey: UserDefaults.selectedCategoryIndexKey)
        
        // Use the category delegate directly if available
        if let categoryDelegate = viewModel.categoryDelegate {
            categoryDelegate.didSelectCategory(at: index)
        } else {
            // Fallback to viewModel's method if no delegate
        viewModel.handleCategorySelection(index)
        }
    }
    
    private func settingsButton() -> some View {
        Button(action: {
            // Trigger haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            print("⚙️ Settings button tapped")
            showingSettingsView = true
            print("⚙️ showingSettingsView set to: \(showingSettingsView)")
        }) {
            Image(systemName: "gear")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .padding(8)
                .background(Color.gray.opacity(0.3))
                .clipShape(Circle())
        }
        // Enhanced tap area and other properties to improve clickability
        .contentShape(Rectangle()) // Use rectangle for better tap area
        .frame(width: 50, height: 50) // Larger frame for easier tapping
        .buttonStyle(PlainButtonStyle())
        .zIndex(100) // Ensure it's above other elements
    }
    
    private func weatherSection() -> some View {
        Group {
            if viewModel.weatherDataLoaded {
                weatherView()
                    .padding(.horizontal)
                    .id("weather-loaded-\(viewModel.temperature)") // Force refresh when temperature changes
            } else {
                // Inline implementation instead of using WeatherLoadingView
                VStack {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Loading weather data...")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                    }
                    .padding(.bottom, 8)
                    
                    // Add a button to manually load weather if automatic loading is stuck
                    Button {
                        Task {
                            await viewModel.loadWeatherData()
                        }
                    } label: {
                        Text("Tap to load weather")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .onAppear {
                    // Use a traditional timer instead of Task + sleep to avoid "self" issues
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        if !viewModel.weatherDataLoaded {
                            print("Weather loading timed out, forcing weather display")
                            viewModel.weatherDataLoaded = true
                        }
                    }
                }
            }
        }
    }
    
    private func runTypeSelectorSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Run Type")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        showingRunTypeInfo = true
                        infoForRunType = nil // Show all types
                    }
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
            }
            
       
            
            ZStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        let runTypes = [RunType.outdoorRun, .treadmillRun, .trailRun, .recoveryRun]

                        ForEach(runTypes, id: \.self) { type in
                            runTypeButtonView(for: type)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16) // more breathing room for offset + scale
                }
            }
            .clipped(antialiased: false) // 👈 allow overflow
            .contentShape(Rectangle()) // 👈 allow gestures on overflowed area

            
            // Display selected run type description
            if showRunTypeSelectionAnimation {
                Text(selectedRunType.description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .fixedSize(horizontal: false, vertical: true) // Allow text to expand vertically
                    .transition(.opacity)
                    .animation(.easeIn, value: selectedRunType)
                
                // Add a spacer to maintain layout when description is hidden
                Spacer()
                    .frame(height: 40) // Minimum height for description area
            } else {
                // Add a spacer to maintain layout when description is hidden
                Spacer()
                    .frame(height: 40) // Minimum height for description area
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12) // Increased vertical padding
        .background(Color.black.opacity(0.2))
        .cornerRadius(16)
        .padding(.horizontal)
        .frame(minHeight: 220) // Ensure sufficient height for the section
    }
    

    
    private func recommendedRoutesSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
            Text("Recommended Routes")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                
                Spacer()
                
                // Show indicator if a route is selected
                if viewModel.selectedRoute != nil {
                    HStack(spacing: 4) {
                        Text("Route Selected")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 14))
                    }
                }
            }
                
            if !hasLoadedRoutes {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Finding nearby routes...")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else {
                // Show selected route info if available
                if let selectedRoute = viewModel.selectedRoute {
                    selectedRouteInfoView(selectedRoute)
                }
                
                routesList()
            }
        }
        .padding(.horizontal)
    }
    
    // Display info about the selected route
    private func selectedRouteInfoView(_ route: Route) -> some View {
        HStack(spacing: 16) {
            // Route icon
            Image(systemName: "map.fill")
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .frame(width: 36, height: 36)
                .background(Color.blue.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(route.name ?? "Unnamed Route")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack(spacing: 12) {
                    Text(String(format: "%.2f km", route.distance))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Text(String(format: "%.0f m elevation", route.elevation))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Text(getDifficultyText(for: route.difficulty))
                        .font(.system(size: 12))
                        .foregroundColor(getDifficultyColor(for: route.difficulty))
                }
            }
            
            Spacer()
            
            Button(action: {
                // Deselect the route
                viewModel.toggleRouteSelection(route: route)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.green.opacity(0.05)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .padding(.bottom, 8)
    }
    
    private func routesList() -> some View {
        // Access the trails array directly from the route planner to ensure freshness
        // Use a state to force view to update when the ID changes instead of Array reference
        let trails = Array(RoutePlanner.shared.nearbyTrails)
        
        return Group {
            if trails.isEmpty {
                VStack {
                    Text("No routes found nearby")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
                    .padding()
                    
                    Button(action: {
                        // Force regenerate the view's ID and refresh
                        self.routesForceRefreshID = UUID()
                        viewModel.routesForceRefreshID = UUID()
                        
                        withAnimation {
                            // Force refresh routes
                            viewModel.fetchRoutes(forceRefresh: true)
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .foregroundColor(.blue)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
            } else {
                // Get the current run type for display
                let runType = selectedRunType
                
                // Only show routes for outdoor run types 
                if runType == .treadmillRun {
                    Text("Routes not applicable for treadmill runs")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    // Sort trails based on relevance to the run type
                    let sortedTrails = trails.sorted { trail1, trail2 in
                        let trail1Score = viewModel.scoreTrailForRunType(trail1, runType: runType)
                        let trail2Score = viewModel.scoreTrailForRunType(trail2, runType: runType)
                        return trail1Score > trail2Score
                    }
                    
                    if sortedTrails.isEmpty {
                        Text("No suitable routes found for \(runType.displayName)")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                // Use the ID modifier with routesForceRefreshID to force refresh
                                ForEach(sortedTrails.prefix(10)) { trail in
                                    createTrailCard(trail: trail, runType: runType)
                                        .id("\(trail.id)_\(routesForceRefreshID)")
                                }
                            }
                            .padding(.horizontal)
                        }
                        // Add a text showing how many routes were found for debugging
                        Text("\(sortedTrails.count) routes available")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }
    
    // Helper function to create trail cards that doesn't cause SwiftUI build errors
    private func createTrailCard(trail: Trail, runType: RunType) -> some View {
        // Create a Route object from the Trail
        let route = Route(
            id: UUID(uuidString: trail.id) ?? UUID(),
            name: trail.name,
            distance: trail.length * 1.60934, // Convert miles to km
            elevation: trail.elevationGain * 0.3048, // Convert feet to meters
            difficulty: viewModel.convertDifficulty(trail.difficulty.rawValue)
        )
        
        // Check if this route is currently selected
        let isSelected = viewModel.selectedRoute?.name == route.name
        
        return ZStack {
            // Main card content
            VStack(alignment: .leading, spacing: 8) {
                // Route icon and name with activity type indicator
                HStack {
                    // Get activity type from trail
                    let activityType = viewModel.getActivityTypeFromTrail(trail)
                    
                    // Display appropriate icon based on activity type
                    Image(systemName: viewModel.getActivityIcon(for: activityType))
                        .font(.system(size: 16))
                        .foregroundColor(viewModel.getActivityColor(for: activityType))
                    
                    Text(trail.name)
                        .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Show loop indicator if it's a loop trail
                    if trail.coordinates.count > 2 && viewModel.isLoopTrail(trail.coordinates) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                            .foregroundColor(.blue.opacity(0.7))
                    }
                    
                    // Show selected indicator
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                    }
                }
                
                // Route stats
                HStack(spacing: 12) {
                    // Distance
                    HStack(spacing: 4) {
                        Image(systemName: "ruler")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text(String(format: "%.2f mi", trail.length))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    // Elevation
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text(String(format: "%.0f ft", trail.elevationGain))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    // Difficulty
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.getDifficultyIcon(for: viewModel.convertDifficulty(trail.difficulty.rawValue)))
                            .font(.system(size: 10))
                            .foregroundColor(viewModel.getDifficultyColor(for: viewModel.convertDifficulty(trail.difficulty.rawValue)))
                        Text(viewModel.getDifficultyText(for: viewModel.convertDifficulty(trail.difficulty.rawValue)))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                // Hint for long press
                HStack {
                    Spacer()
                    Text("Long press to preview")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.top, 4)
                }
            }
            .padding()
            .frame(width: 240, height: 100) // Increased height slightly for the hint text
            .background(
                LinearGradient(
                    gradient: Gradient(
                        colors: [
                            Color.black.opacity(0.4),
                            Color.blue.opacity(isSelected ? 0.3 : 0.1)
                        ]
                    ),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(16)
            
            // Invisible button for tap gesture (route selection)
            Button(action: {
                // Toggle the route selection
                DispatchQueue.main.async {
                    viewModel.toggleRouteSelection(route: route)
                }
            }) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 240, height: 100)
            }
            
            // Add long press gesture for preview
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        // Show preview
                        selectedTrailForPreview = trail
                        showRoutePreview = true
                    }
            )
        }
        .sheet(isPresented: $showRoutePreview) {
            if let trail = selectedTrailForPreview {
                RoutePreviewView(
                    trail: trail,
                    onSelectRoute: {
                        // Handle route selection from preview
                        DispatchQueue.main.async {
                            self.showRoutePreview = false
                        }
                        
                        // Create route from trail and select it
                        let route = Route(
                            id: UUID(uuidString: trail.id) ?? UUID(),
                            name: trail.name,
                            distance: trail.length * 1.60934,
                            elevation: trail.elevationGain * 0.3048,
                            difficulty: viewModel.convertDifficulty(trail.difficulty.rawValue)
                        )
                        
                        DispatchQueue.main.async {
                            viewModel.selectRoute(route: route)
                        }
                    },
                    onDismiss: {
                        // Just close the preview
                        showRoutePreview = false
                    }
                )
            }
        }
    }
    
    // Helper function to determine activity type from trail
    private func getActivityTypeFromTrail(_ trail: Trail) -> ActivityRouteType {
        if let trailTypeString = trail.trailType?.lowercased() {
            if trailTypeString.contains("run") || trailTypeString.contains("track") {
                return .running
            } else if trailTypeString.contains("hik") || trailTypeString.contains("mountain") {
                return .hiking
            } else if trailTypeString.contains("bik") || trailTypeString.contains("cycle") {
                return .biking
            } else if trailTypeString.contains("walk") || trailTypeString.contains("footway") {
                return .walking
            } else {
                return .running // Default to running
            }
        } else {
            return .running // Default to running if trailType is nil
        }
    }
    
    // Helper function to get icon for activity type
    private func getActivityIcon(for activityType: ActivityRouteType) -> String {
        switch activityType {
        case .running:
            return "figure.run"
        case .hiking:
            return "figure.hiking"
        case .biking:
            return "figure.outdoor.cycle"
        case .walking:
            return "figure.walk"
        case .returnRoute:
            return "arrow.triangle.turn.up.right.circle"
        }
    }
    
    // Helper function to get color for activity type
    private func getActivityColor(for activityType: ActivityRouteType) -> Color {
        switch activityType {
        case .running:
            return .blue
        case .hiking:
            return .green
        case .biking:
            return .orange
        case .walking:
            return .teal
        case .returnRoute:
            return .purple
        }
    }
    
    // Helper function to get background gradient color for activity type
    private func getActivityGradientColor(for activityType: ActivityRouteType) -> UIColor {
        switch activityType {
        case .running:
            return UIColor(hex: "#0055A9") // Darker blue
        case .hiking:
            return UIColor(hex: "#1E7A3C") // Darker green
        case .biking:
            return UIColor(hex: "#AF5700") // Darker orange
        case .walking:
            return UIColor(hex: "#006666") // Darker teal
        case .returnRoute:
            return UIColor(hex: "#500082") // Darker purple
        }
    }
    
    private func startRunButtonSection() -> some View {
        let currentRunType = selectedRunType
        return VStack {
            // Showing the selected run type
            HStack {
                Image(systemName: currentRunType.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                Text(currentRunType.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.bottom, 8)
            
            Button(action: {
                // Trigger haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                viewModel.startRun()
            }) {
                HStack {
                    Image(systemName: "figure.run")
                        .font(.system(size: 18))
                    Text("Start Run")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            
            // Show selected route information
            selectedRouteInfo()
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
                    print("🔍 Find Routes button tapped")
                    showingFindRoutesView = true
                    print("🔍 showingFindRoutesView set to: \(showingFindRoutesView)")
                }
                
                actionButton(iconName: "clock.fill", label: "History") {
                    // Use popover presentation for a more compact UI
                    showRunHistorySheet = true
                }
                
//                actionButton(iconName: "globe", label: "Explorer Map") {
//                    // Show the World Explorer Map
//                    showWorldExplorerMap()
//                }
            }
        }
        .padding(.horizontal)
        .popover(isPresented: $showRunHistorySheet, arrowEdge: .top) {
            RunHistoryPopover()
                .edgesIgnoringSafeArea(.all)
        }
    }
    
    // SwiftUI-friendly method to show run history directly
    private func showRunHistoryDirectly() {
        let historyVC = RunHistoryViewController()
        let navController = UINavigationController(rootViewController: historyVC)
        navController.modalPresentationStyle = .fullScreen
        self.presentViewController(navController)
    }
    
    private func runningStatsSection() -> some View {
        Group {
            // Always show stats section, but update when data becomes available
            VStack(alignment: .leading, spacing: 16) {
                Text("Your Running Activity")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 12) {
                    // Calculate values - these will update reactively when data changes
                    let thisWeekDistanceMeters = viewModel.calculateThisWeekDistance()
                    let avgPace = viewModel.calculateAveragePace()
                    
                    // Format distance based on user preferences
                    let formattedDistance = UserPreferences.shared.useMetricSystem ?
                        String(format: "%.1f", thisWeekDistanceMeters / 1000) :
                        String(format: "%.1f", thisWeekDistanceMeters / 1609.34)
                    
                    // Get units based on user preferences
                    let distanceUnit = UserPreferences.shared.useMetricSystem ? "km" : "mi"
                    let paceUnit = UserPreferences.shared.useMetricSystem ? "/km" : "/mi"
                    
                    // Show loading state if data hasn't loaded yet
                    if !viewModel.hasLoadedRunningHistory {
                        statCard(title: "This Week", value: "--", unit: distanceUnit, color: .blue)
                        statCard(title: "Avg. Pace", value: "--", unit: paceUnit, color: .green)
                    } else {
                        // Use the calculated values directly in the view
                        statCard(title: "This Week", value: formattedDistance, unit: distanceUnit, color: .blue)
                        statCard(title: "Avg. Pace", value: avgPace, unit: paceUnit, color: .green)
                    }
                }
            }
            .padding(.horizontal)
            // Force refresh when data changes
            .id(viewModel.routesForceRefreshID)
        }
    }
    
    
    
    private func selectedRouteInfo() -> some View {
        Group {
            if let selectedRoute = viewModel.selectedRoute {
                HStack(spacing: 8) {
                    Image(systemName: "map.fill")
                        .foregroundColor(.blue)
                    .font(.system(size: 14))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedRoute.name ?? "Unnamed Route")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text(String(format: "%.2f km • %.0f m elevation • %@", 
                              selectedRoute.distance, 
                              selectedRoute.elevation,
                              getDifficultyText(for: selectedRoute.difficulty)))
                            .font(.system(size: 12))
                    .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text("No route selected - will track open run")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
        }
    }
    

    
    
    private func handleOnAppear() {
        // Sync the hasLoadedRoutes state with the view model
        hasLoadedRoutes = viewModel.hasLoadedRoutes
        
        // If we haven't loaded routes yet, fetch them with a slight delay
        // to allow the view to fully appear first
        if !hasLoadedRoutes {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Use the improved fetchRoutes method
                viewModel.fetchRoutes()
            }
        }
        
        // No need for additional retries - the fetchRoutes method handles caching and retries
    }
    
    private func findNearbyRoutes() {
        // Use the improved fetchRoutes method
        viewModel.fetchRoutes()
        
        // No need for additional retries - the fetchRoutes method handles caching and retries
    }
    
    // Fetches recommended routes based on the current run type and location
    private func fetchRecommendedRoutes_Internal() {
        print("📋 PRIVATE fetchRecommendedRoutes_Internal called - adding call trace:")
        
        // Add a simple stack trace
        let symbols = Thread.callStackSymbols
        if symbols.count > 1 {
            print("📋 Called from: \(symbols[1])")
            if symbols.count > 2 {
                print("📋 Previous: \(symbols[2])")
            }
        }
        
        let routePlanner = RoutePlanner.shared
        let runType = selectedRunType
        
        // Skip if already generating route
        if routePlanner.isGeneratingRoute {
            print("⚠️ Skipping route fetch: already in progress")
            return
        }
        
        // Log which implementation is being used
        print("📋 Using PRIVATE implementation for run type: \(runType)")
        
        // This was causing a recursive call - instead, let's implement the logic directly
        // fetchRecommendedRoutes()
        
        // Use the same implementation as in the public method
        DispatchQueue.global(qos: .userInitiated).async {
            // Clear existing trails on main thread
            DispatchQueue.main.async {
                routePlanner.clearTrails()
            }
            
            // Flag to track if we've already performed a search
            var routeSearchPerformed = false
            
            // Simple helper to avoid duplicate searches
            func performSearch(activity: () -> Void) {
                if !routeSearchPerformed {
                    activity()
                    routeSearchPerformed = true
                } else {
                    print("⚠️ Skipping additional route search")
                }
            }
            
            // Choose the most appropriate search based on run type
            switch runType {
            case .trailRun:
                // For trail runs, prioritize hiking trails
                performSearch {
                    print("📋 Finding hiking trails for trail run")
                    routePlanner.findHikingTrails(radius: 10000)
                    // Since findHikingTrails doesn't have a completion handler,
                    // we need to manually update hasLoadedRoutes after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.hasLoadedRoutes = true
                    }
                }
                
            case .outdoorRun, .recoveryRun, .intervalTraining, .lapRun:
                // For most run types, just use running trails
                performSearch {
                    print("📋 Finding running trails for \(runType)")
                    routePlanner.findRunningTrails { success in
                        print("📋 Running trails completion handler called: success=\(success)")
                        DispatchQueue.main.async {
                            self.hasLoadedRoutes = true
                        }
                    }
                }
                
            default:
                // Default behavior - get running trails
                performSearch {
                    routePlanner.findRunningTrails { _ in
                        DispatchQueue.main.async {
                            self.hasLoadedRoutes = true
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - UI Components
    
    private func routeCard(route: Route) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                // Route icon and name
                HStack {
                    Image(systemName: "figure.run")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                    
                    Text(route.name ?? "Unnamed Route")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Route stats
                HStack(spacing: 12) {
                    // Distance
                    HStack(spacing: 4) {
                        Image(systemName: "ruler")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text(String(format: "%.1f km", route.distance))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    // Elevation
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text(String(format: "%.0f m", route.elevation))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    // Difficulty
                    HStack(spacing: 4) {
                        Image(systemName: getDifficultyIcon(for: route.difficulty))
                            .font(.system(size: 10))
                            .foregroundColor(getDifficultyColor(for: route.difficulty))
                        Text(getDifficultyText(for: route.difficulty))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
    }
    
    private func getDifficultyIcon(for difficulty: RouteDifficulty) -> String {
        switch difficulty {
        case .easy:
            return "figure.walk"
        case .moderate:
            return "figure.run"
        case .difficult:
            return "figure.highintensity.intervaltraining"
        }
    }
    
    private func getDifficultyText(for difficulty: RouteDifficulty) -> String {
        switch difficulty {
        case .easy:
            return "Easy"
        case .moderate:
            return "Moderate"
        case .difficult:
            return "Hard"
        }
    }
    
    private func getDifficultyColor(for difficulty: RouteDifficulty) -> Color {
        switch difficulty {
        case .easy:
            return .green
        case .moderate:
            return .yellow
        case .difficult:
            return .orange
        }
    }
    
    private func actionButton(iconName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            // Trigger haptic feedback
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
    
    private func weatherView() -> some View {
        ZStack(alignment: .top) {
            // Background
            getWeatherGradient(for: viewModel.weatherCondition)
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
                    CloudOverlay(nightMode: isNighttime(), cloudiness: .partial)
                case .cloudy:
                    CloudOverlay(nightMode: isNighttime())
                case .rainy:
                    ModernRainOverlay(intensity: .medium, nightMode: isNighttime())
                case .stormy:
                    LightningView()
                case .snowy:
                    SnowOverlay()
                case .foggy:
                    CloudOverlay(nightMode: isNighttime())
                case .windy:
                    CloudOverlay(nightMode: isNighttime(), cloudiness: .partial)
                case .unknown:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .opacity(0.9)
            .blendMode(.screen)
            
            // Content - enhanced with location and forecast
            VStack(spacing: 12) {
                // Main weather info
            weatherHeader()
            
            // Weather details
                weatherContent()
                    .padding(.horizontal)
                    
                // Forecast for upcoming hours
                forecastRow()
                    .padding(.bottom, 10)
            }
            .padding(.vertical, 15)
        }
        .frame(height: 235)
        .cornerRadius(22)
    }
    
    private func getWeatherGradient(for condition: WeatherCondition) -> LinearGradient {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let colors = Color.weatherGradient(for: condition, hour: currentHour)
        
        return LinearGradient(
            gradient: Gradient(colors: [colors.0, colors.1]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func forecastRow() -> some View {
        HStack(spacing: 10) {
            ForEach(0..<4) { i in
                forecastItem(
                    hour: getHourString(hoursFromNow: i + 1),
                    icon: getForecastIcon(hoursFromNow: i + 1),
                    temp: getForecastTemp(hoursFromNow: i + 1)
                )
            }
        }
        .padding(.horizontal)
    }
    
    private func forecastItem(hour: String, icon: String, temp: String) -> some View {
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
    
    // Helper methods for the forecast
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
        // Account for night time when returning forecast icons
        let forecastHour = Calendar.current.component(.hour, from: Date()) + hoursFromNow
        let willBeNight = forecastHour >= 19 || forecastHour < 6
        
        // Get the real forecast condition if available
        if let forecastConditions = weatherService.getForecastConditions(hours: 4),
           hoursFromNow <= forecastConditions.count {
            let condition = forecastConditions[hoursFromNow - 1]
            
            // Get the appropriate icon for this condition based on time of day
            switch condition {
            case .clear:
                return willBeNight ? "moon.stars.fill" : "sun.max.fill"
            case .partlyCloudy:
                return willBeNight ? "cloud.moon.fill" : "cloud.sun.fill"
            case .cloudy:
                return "cloud.fill"
            case .rainy:
                return willBeNight ? "cloud.moon.rain.fill" : "cloud.rain.fill"
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
        
        // Fallback to the simulation approach if real forecast isn't available
        // Simulate changing conditions but respect day/night cycle
        switch hoursFromNow {
        case 1: 
            if willBeNight {
                return "moon.stars.fill"
            } else {
                if viewModel.weatherCondition == .clear {
                    return "sun.max.fill"
                } else {
                    return "cloud.sun.fill"
                }
            }
        case 2: 
            if willBeNight {
                return viewModel.weatherCondition == .rainy ? "cloud.moon.rain.fill" : "cloud.moon.fill"
            } else {
                return viewModel.weatherCondition == .rainy ? "cloud.rain.fill" : 
                       viewModel.weatherCondition == .cloudy ? "cloud.fill" : "cloud.sun.fill"
            }
        case 3: 
            if willBeNight {
                return viewModel.weatherCondition == .rainy ? "cloud.moon.rain.fill" : "moon.stars.fill"
            } else {
                return viewModel.weatherCondition == .rainy ? "cloud.heavyrain.fill" : 
                       viewModel.weatherCondition == .cloudy ? "cloud.fill" : "sun.max.fill"
            }
        case 4:
            return willBeNight ? "moon.stars.fill" : "sun.max.fill"
        default:
            return "cloud.fill"
        }
    }
    
    private func getForecastTemp(hoursFromNow: Int) -> String {
        // Get the real forecast temperature from Weather Service
        // The temperature forecasts should be stored when we load weather data
        if let forecastTemps = weatherService.getForecastTemperatures(hours: 4),
           hoursFromNow <= forecastTemps.count {
            let temp = forecastTemps[hoursFromNow - 1]
            return formatTemperature(temp)
        }
        
        // Fallback to our current simulation approach if the real forecast isn't available
        let baseTemp = Int(viewModel.temperature)
        switch hoursFromNow {
        case 1: return "\(baseTemp - 1)°"
        case 2: return "\(baseTemp - 2)°"
        case 3: return "\(baseTemp - 1)°"
        case 4: return "\(baseTemp)°"
        default: return "\(baseTemp)°"
        }
    }
    
    // Helper function to determine if it's night time
    private func isNighttime() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour > 18
    }
    
    // Weather animation overlay function
    private func weatherAnimationOverlay(condition: WeatherCondition, isNight: Bool) -> some View {
        ZStack(alignment: .top) {
            switch condition {
            case .rainy:
                ModernRainOverlay(intensity: .medium, nightMode: isNight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .stormy:
                StormOverlay()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .snowy:
                SnowOverlay()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .foggy:
                FogOverlay()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .cloudy:
                CloudOverlay()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .partlyCloudy:
                if isNight {
                    ZStack(alignment: .top) {
                        StarryNightOverlay()
                        CloudOverlay(cloudiness: .partial)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    // Time of day variations
                    let hour = Calendar.current.component(.hour, from: Date())
                    if hour >= 5 && hour < 9 {
                        // Early morning (5-9 AM)
                        PartlyCloudyMorningView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else if hour >= 17 && hour < 20 {
                        // Evening (5-8 PM)
                        PartlyCloudyEveningView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        // Regular daytime
                        ZStack(alignment: .top) {
                            SunRaysView(showSun: false)
                            CloudOverlay(cloudiness: .partial)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                }
            case .clear:
                if isNight {
                    StarryNightOverlay()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    // Time of day variations
                    let hour = Calendar.current.component(.hour, from: Date())
                    if hour >= 5 && hour < 9 {
                        // Early morning (5-9 AM)
                        ClearMorningView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else if hour >= 17 && hour < 20 {
                        // Evening (5-8 PM)
                        ClearEveningView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        // Regular daytime
                        ClearDayView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                }
            case .windy:
                WindyWeatherView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .unknown:
                // For unknown weather, just show a clear day/night based on time
                if isNight {
                    StarryNightOverlay()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    ClearDayView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }
    
    private func weatherHeader() -> some View {
        VStack(spacing: 0) {
            // Top row with location and icon
            HStack {
                // Location - use locationCity directly and make it forcibly update when it changes
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    // Use Text with id modifier to force refresh when locationCity changes
                    Text(viewModel.locationCity)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .id("location_\(viewModel.locationCity)") // Force redraw when locationCity changes
                }
                
                Spacer()
                
                // Weather icon
                Image(systemName: viewModel.weatherIconName)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .id("weather-icon-\(viewModel.weatherIconName)") // Force refresh when icon changes
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Weather condition and temperature (left-aligned now)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(getWeatherDescription(condition: viewModel.weatherCondition, isNightMode: isNighttime()))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .id("weather-desc-\(viewModel.weatherCondition.rawValue)") // Force refresh
                    
                    Text(formatTemperature(viewModel.temperature))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .id("temperature-\(viewModel.temperature)") // Force refresh when temperature changes
                }
                
                Spacer()
            }
            .padding(.horizontal)
        }
    }
    
    private func weatherContent() -> some View {
        HStack(spacing: 16) {
            // Wind
            weatherDetailItem(
                icon: "wind",
                value: formatWindSpeed(viewModel.windSpeed)
            )
            
            // Humidity
            weatherDetailItem(
                icon: "drop.fill",
                value: "\(Int(viewModel.humidity))%"
            )
        }
        .padding(.horizontal)
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
    
    // Helper methods
    private func formatTemperature(_ temp: Double) -> String {
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
    
    // Helper method to format wind speed according to user preferences
    private func formatWindSpeed(_ speed: Double) -> String {
        return UserPreferences.shared.useMetricSystem ? 
            "\(Int(speed * 1.60934)) km/h" : 
            "\(Int(speed)) mph"
    }
    
    private func getWeatherDescription(condition: WeatherCondition, isNightMode: Bool) -> String {
        switch condition {
        case .clear:
            return isNightMode ? "Clear Night" : "Clear Day"
        case .cloudy:
            return isNightMode ? "Cloudy Night" : "Cloudy"
        case .partlyCloudy:
            return isNightMode ? "Partly Cloudy Night" : "Partly Cloudy"
        case .rainy:
            return "Rainy"
        case .stormy:
            return "Thunderstorms"
        case .snowy:
            return "Snowy"
        case .foggy:
            return "Foggy"
        case .windy:
            return "Windy"
        case .unknown:
            return "Unknown Weather"
        }
    }
    
    // MARK: - Weather Data Loading
    
    private func loadWeatherData() {
        Task {
            if let location = locationManager.location {
                // Immediately set coordinates while waiting for geocoding
                let lat = location.coordinate.latitude
                let lon = location.coordinate.longitude
                await MainActor.run {
                    locationCity = String(format: "%.2f, %.2f", lat, lon)
                }
                
                // Direct geocoding to get city name
                let geocoder = CLGeocoder()
                do {
                    let placemarks = try await geocoder.reverseGeocodeLocation(location)
                    if let placemark = placemarks.first {
                        let city = placemark.locality ?? ""
                        let state = placemark.administrativeArea ?? ""
                        let country = placemark.country ?? ""
                        
                        var formattedLocation = city
                        
                        if country == "United States" || country == "USA" {
                            if !state.isEmpty { formattedLocation += ", \(state)" }
                        } else {
                            if !country.isEmpty { formattedLocation += ", \(country)" }
                        }
                        
                        await MainActor.run {
                            locationCity = formattedLocation.isEmpty ? "Location unavailable" : formattedLocation
                        }
                    }
                } catch {
                    print("Geocoding error: \(error)")
                }
                
                // Load weather data
                let (data, error) = await weatherService.fetchWeather(for: location)
                
                await MainActor.run {
                    if let data = data {
                        temperature = data.temperature
                        humidity = data.humidity
                        windSpeed = data.windSpeed
                        weatherCondition = data.condition
                        weatherIconName = data.condition.icon
                        weatherDataLoaded = true
                    } else if let error = error {
                        print("Error loading weather: \(error.localizedDescription)")
                        weatherDataLoaded = true // Still show view even with error
                    }
                }
            } else {
                // Location services unavailable
                await MainActor.run {
                    self.locationCity = "Location services unavailable"
                    self.weatherDataLoaded = false
                    self.weatherIconName = "location.slash"
                }
            }
        }
    }
    
    private func locationHeader() -> some View {
        VStack(spacing: 2) {
            // City, Country
        HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(viewModel.locationCity)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            
            Spacer()
            
                // Date
                Text(formattedCurrentDate())
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal)
        }
    }
    
    private func formattedCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter.string(from: Date())
    }
    
    // Add this method to the onAppear block to load the last selected run type
    private func loadSavedRunType() {
        // Load the saved run type from user defaults or other storage
        if let savedRunTypeRawValue = UserDefaults.standard.string(forKey: "selectedRunType"),
           let savedRunType = RunType(rawValue: savedRunTypeRawValue) {
            selectedRunType = savedRunType
            runTracker.runType = savedRunType
        }
    }
    
    // Add this method to the RunTrackerView to create run type buttons
    private func runTypeButtonView(for type: RunType) -> some View {
        let isSelected = selectedRunType == type
        let shouldAnimate = showRunTypeSelectionAnimation && isSelected
        
        return runTypeButton(type)
            .offset(y: shouldAnimate ? -10 : 0)
            .scaleEffect(shouldAnimate ? 1.05 : 1.0)
            .shadow(
                color: Color.blue.opacity(shouldAnimate ? 0.5 : 0),
                radius: shouldAnimate ? 8 : 0,
                x: 0,
                y: 2
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedRunType)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showRunTypeSelectionAnimation)
    }
    
    private func runTypeButton(_ type: RunType) -> some View {
        let isSelected = selectedRunType == type
        
        return Button(action: {
            // Trigger haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            selectedRunTypeChanged(to: type)
        }) {
            VStack(spacing: 12) {
                // Icon
                    Image(systemName: type.icon)
                    .font(.system(size: 24, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .blue : .white)
                    .frame(height: 30)
                
                // Title
                Text(type.displayName)
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .blue : .white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 90) // Fixed width for consistent button sizing
            }
            .frame(width: 110, height: 110) // Increased dimensions
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? 
                          Color.blue.opacity(0.15) : 
                          Color.black.opacity(0.3))
            .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.blue : Color.clear, 
                                    lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle()) // For consistent tap behavior
    }
    
    private func selectedRunTypeChanged(to type: RunType) {
        // Animate out the current description
        withAnimation(.easeOut(duration: 0.2)) {
            showRunTypeSelectionAnimation = false
        }
        
        print("🎯 RunType changed from \(self.selectedRunType.rawValue) to \(type.rawValue)")
        
        // Change the type
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Update the SwiftUI @State var selectedRunType
            self.selectedRunType = type
            print("✅ Set selectedRunType to \(type.rawValue)")
            
            // Save the selected run type
            UserDefaults.standard.set(type.rawValue, forKey: "selectedRunType")
            print("💾 Saved run type \(type.rawValue) to UserDefaults")
            
            // Update the run tracking engine
            self.runTrackingEngine.runType = type
            print("🔄 Updated runTrackingEngine.runType to \(type.rawValue)")
            
            // Also ensure the viewModel's runTracker is updated
            self.viewModel.runTracker.runType = type
            
            // CRITICAL: Ensure ViewController's reference and UI are synchronized
            if let rootView = self.viewModel.hostingController?.rootView as? RunTrackerView {
                if rootView.selectedRunType != type {
                    DispatchQueue.main.async {
                        // Update via ViewController to ensure state consistency across the app
                        self.viewModel.setSelectedRunType(type)
                        // Verify the change took effect in both places
                        print("✅ Engine run type: \(self.runTrackingEngine.runType.rawValue)")
                        print("✅ View run type: \(rootView.selectedRunType.rawValue)")
                    }
                }
            }
            
            // Now animate in the new description
            withAnimation(.easeIn(duration: 0.3)) {
                self.showRunTypeSelectionAnimation = true
            }
            
            // For treadmill runs, routes aren't relevant - just mark as loaded
            if type == .treadmillRun {
                print("ℹ️ Treadmill run selected - routes not applicable")
                self.hasLoadedRoutes = true
                
                // Force UI refresh for treadmill mode
                DispatchQueue.main.async {
                    self.viewModel.refreshUIWithCurrentTrails()
                }
                return
            }
            
            // Only reload routes for outdoor run types
            if !RoutePlanner.shared.nearbyTrails.isEmpty {
                print("🔄 Reloading routes optimized for run type: \(type.rawValue)")
                self.hasLoadedRoutes = true  // Prevent automatic refresh
                
                // Force UI refresh with existing routes
                DispatchQueue.main.async {
                    self.viewModel.refreshUIWithCurrentTrails()
                }
            } else {
                // If we have no routes yet, load them for outdoor runs
                print("⚠️ No routes loaded yet, fetching routes for run type: \(type.rawValue)")
                self.hasLoadedRoutes = false
                
                // Use the view model to fetch routes
                DispatchQueue.main.async {
                    self.viewModel.fetchRoutes() // Use fetchRoutes instead of findNearbyRoutes
                }
            }
        }
    }
    
  
    
    // Helper function to get weather description
    private func getWeatherDescription(_ condition: WeatherCondition) -> String {
        let isNight = isNighttime()
        
        switch condition {
        case .clear:
            return isNight ? "Clear Night" : "Clear Day"
        case .cloudy:
            return "Cloudy"
        case .partlyCloudy:
            return isNight ? "Partly Cloudy Night" : "Partly Cloudy"
        case .rainy:
            return "Rainy"
        case .stormy:
            return "Thunderstorms"
        case .snowy:
            return "Snowy"
        case .foggy:
            return "Foggy"
        case .windy:
            return "Windy"
        case .unknown:
            return "Unknown Weather"
        }
    }
    
    // Helper function to convert TrailDifficulty to RouteDifficulty
    private func convertDifficulty(_ difficulty: TrailDifficulty) -> RouteDifficulty {
        switch difficulty {
        case .easy:
            return .easy
        case .moderate:
            return .moderate
        case .difficult, .veryDifficult:
            return .difficult
        }
    }
    
    // Helper function to score how well a trail matches the selected run type
    private func scoreTrailForRunType(_ trail: Trail, runType: RunType) -> Int {
        var score = 0
        
        // Get the activity type from trailType string
        let activityType: ActivityRouteType
        if let trailTypeString = trail.trailType?.lowercased() {
            if trailTypeString.contains("run") || trailTypeString.contains("track") {
                activityType = .running
            } else if trailTypeString.contains("hik") || trailTypeString.contains("mountain") {
                activityType = .hiking
            } else if trailTypeString.contains("bik") || trailTypeString.contains("cycle") {
                activityType = .biking
            } else if trailTypeString.contains("walk") || trailTypeString.contains("footway") {
                activityType = .walking
            } else {
                // Default to running if we can't determine
                activityType = .running
            }
        } else {
            // Default to running if trailType is nil
            activityType = .running
        }
        
        // Determine if the trail is a loop (by checking if first and last coordinates are close)
        let isLoop = trail.coordinates.count > 2 && self.isLoopTrail(trail.coordinates)
        
        // Base score on activity type match
        switch runType {
        case .trailRun:
            // Trail runs prefer hiking trails, but also like running and biking trails
            if activityType == .hiking { score += 5 }
            else if activityType == .running { score += 3 }
            else if activityType == .biking { score += 1 }
            
            // Trail runs prefer more difficult trails
            if trail.difficulty == .moderate { score += 2 }
            else if trail.difficulty == .difficult || trail.difficulty == .veryDifficult { score += 3 }
            
        case .outdoorRun:
            // Regular runs prefer running trails, but also like walking and biking trails
            if activityType == .running { score += 5 }
            else if activityType == .walking { score += 3 }
            else if activityType == .biking { score += 2 }
            else if activityType == .hiking { score += 1 }
            
            // Regular runs prefer moderate difficulty
            if trail.difficulty == .moderate { score += 3 }
            else if trail.difficulty == .easy { score += 2 }
            
        case .recoveryRun:
            // Recovery runs prefer easier, flatter trails
            if activityType == .walking { score += 5 }
            else if activityType == .running { score += 3 }
            
            
            // Recovery runs strongly prefer easier trails
            if trail.difficulty == .easy { score += 5 }
            else if trail.difficulty == .moderate { score += 1 }
            
        case .intervalTraining:
            // Interval training prefers flat, consistent surfaces
            if activityType == .running { score += 5 }
            else if activityType == .walking { score += 3 }
            
            // Prefer easier or moderate trails for consistent pacing
            if trail.difficulty == .easy || trail.difficulty == .moderate { score += 3 }
            
        case .lapRun:
            // Lap runs prefer loop trails
            if isLoop { score += 5 }
            
            // Prefer running and biking trails which often have good loops
            if activityType == .running { score += 4 }
            else if activityType == .biking { score += 3 }
            
        default:
            // Default preference for running trails
            if activityType == .running { score += 3 }
        }
        
        return score
    }

    // Helper method to determine if a trail is a loop
    private func isLoopTrail(_ coordinates: [Coordinate]) -> Bool {
        guard let first = coordinates.first, let last = coordinates.last else {
            return false
        }
        
        // Calculate distance between start and end points
        let startLat = first.latitude
        let startLon = first.longitude
        let endLat = last.latitude
        let endLon = last.longitude
        
        // Simple distance calculation (Euclidean)
        let distance = sqrt(pow(endLat - startLat, 2) + pow(endLon - startLon, 2))
        
        // If start and end points are close enough, consider it a loop
        return distance < 0.001 // Approximately 100 meters in decimal degrees
    }
    
    // Helper method to show the World Explorer Map
    private func showWorldExplorerMap() {
//        let worldExplorerVC = WorldExplorerMapViewController()
//        let navController = UINavigationController(rootViewController: worldExplorerVC)
//        navController.modalPresentationStyle = .fullScreen
//        self.presentViewController(navController)
    }
    
//    // SwiftUI wrapper for the World Explorer Map
//    private struct WorldExplorerMapView: UIViewControllerRepresentable {
////        func makeUIViewController(context: Context) -> UIViewController {
//////            let worldExplorerVC = WorldExplorerMapViewController()
////            return UINavigationController(rootViewController: worldExplorerVC)
////        }
//        
//        func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
//    }
}

// MARK: - Weather Animation Views

// Redesigned rain overlay with realistic rain streaks
struct RainOverlay: View {
    // Main rain streaks
    let lightRainCount = 30
    let mediumRainCount = 20
    let heavyRainCount = 10
    
    // Background rain blur effect
    @State private var backgroundOpacity = 0.0
    
    var body: some View {
        GeometryReader { geometry in
        ZStack {
                // Background rain blur effect
                Color.gray.opacity(0.05)
                    .opacity(backgroundOpacity)
                    .onAppear {
                        withAnimation(.easeIn(duration: 1.0)) {
                            backgroundOpacity = 1.0
                        }
                    }
                
                // Main rain streaks - lightest and fastest in background
                RainStreakLayer(
                    count: lightRainCount,
                    lengthRange: 10...30,
                    widthRange: 0.5...1.0,
                    opacityRange: 0.1...0.25,
                    speedRange: 0.15...0.3,
                    color: Color(red: 0.7, green: 0.7, blue: 0.8),
                    bounds: geometry.size
                )
                
                // Medium rain streaks
                RainStreakLayer(
                    count: mediumRainCount,
                    lengthRange: 20...50,
                    widthRange: 1.0...1.5,
                    opacityRange: 0.2...0.4,
                    speedRange: 0.25...0.4,
                    color: Color(red: 0.6, green: 0.6, blue: 0.75),
                    bounds: geometry.size
                )
                
                // Heavy foreground rain streaks
                RainStreakLayer(
                    count: heavyRainCount,
                    lengthRange: 40...100,
                    widthRange: 1.5...2.5,
                    opacityRange: 0.3...0.6,
                    speedRange: 0.4...0.7,
                    color: Color(red: 0.5, green: 0.5, blue: 0.7),
                    bounds: geometry.size
                )
                
                // Water impact splashes (subtle)
                RainSplashLayer(count: 8, bounds: geometry.size)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

// Note: RainSplashLayer and RainSplash are defined in WeatherViews.swift

// Layer of vertical rain streaks
struct RainStreakLayer: View {
    let count: Int
    let lengthRange: ClosedRange<CGFloat>
    let widthRange: ClosedRange<CGFloat>
    let opacityRange: ClosedRange<Double>
    let speedRange: ClosedRange<Double>
    let color: Color
    let bounds: CGSize
    
    var body: some View {
            ForEach(0..<count, id: \.self) { _ in
            RainStreak(
                length: CGFloat.random(in: lengthRange),
                width: CGFloat.random(in: widthRange),
                opacity: Double.random(in: opacityRange),
                speed: Double.random(in: speedRange),
                    startPosition: CGPoint(
                    x: CGFloat.random(in: 0...bounds.width),
                        y: CGFloat.random(in: -50...0)
                    ),
                screenHeight: bounds.height,
                color: color
                )
        }
    }
}

// Individual rain streak
struct RainStreak: View {
    let length: CGFloat
    let width: CGFloat
    let opacity: Double
    let speed: Double
    let startPosition: CGPoint
    let screenHeight: CGFloat
    let color: Color
    
    @State private var yOffset: CGFloat = 0
    
    var body: some View {
        // Vertical line with slight gradient for the streak
        LinearGradient(
                gradient: Gradient(colors: [
                color.opacity(opacity * 0.7),
                color.opacity(opacity)
                ]),
                startPoint: .top,
                endPoint: .bottom
        )
            .frame(width: width, height: length)
        .blur(radius: 0.3) // Slight blur for softer edge
        .position(x: startPosition.x, y: startPosition.y + yOffset)
            .onAppear {
                startRainAnimation()
            }
    }
    
    private func startRainAnimation() {
        // Random delay before starting to stagger raindrops
        let initialDelay = Double.random(in: 0...0.5)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) {
            // Animate falling continuously
            withAnimation(Animation.linear(duration: 1.0 / speed).repeatForever(autoreverses: false)) {
                yOffset = screenHeight + length + 50
            }
        }
    }
}

// Note: RainSplashLayer and RainSplash are defined in WeatherViews.swift

// Enhanced snow overlay with realistic 3D snowflakes
struct SnowOverlay: View {
    let smallFlakeCount = 20
    let mediumFlakeCount = 15
    let largeFlakeCount = 10
    
    var body: some View {
        GeometryReader { geometry in
        ZStack {
            // Multiple layers of snowflakes for 3D depth effect
                SnowflakeLayer(count: smallFlakeCount, size: 8...12, speed: 15...25, swayFactor: 20, opacity: 0.6, zPos: 20, bounds: geometry.size)
                .blur(radius: 0.3) // Slight blur for closest layer
            
                SnowflakeLayer(count: mediumFlakeCount, size: 12...18, speed: 10...20, swayFactor: 30, opacity: 0.8, zPos: 0, bounds: geometry.size)
            
                SnowflakeLayer(count: largeFlakeCount, size: 18...24, speed: 8...15, swayFactor: 40, opacity: 0.7, zPos: -20, bounds: geometry.size)
                .blur(radius: 0.5) // Stronger blur for distant layer
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

struct SnowflakeLayer: View {
    let count: Int
    let size: ClosedRange<CGFloat>
    let speed: ClosedRange<Double>
    let swayFactor: CGFloat
    let opacity: Double
    let zPos: CGFloat // 3D z-position for depth
    let bounds: CGSize
    
    var body: some View {
            ForEach(0..<count, id: \.self) { _ in
                EnhancedSnowflake(
                    size: CGFloat.random(in: size),
                    speed: Double.random(in: speed),
                    swayFactor: CGFloat.random(in: swayFactor/2...swayFactor),
                    startPosition: CGPoint(
                    x: CGFloat.random(in: 0...bounds.width),
                        y: CGFloat.random(in: -50...0)
                    ),
                canvasSize: bounds
                )
                .opacity(opacity)
                // Apply a depth effect with a subtle scaling instead of z-offset
                .scaleEffect(1.0 - (zPos * 0.01))
        }
    }
}

struct EnhancedSnowflake: View {
    let size: CGFloat
    let speed: Double
    let swayFactor: CGFloat
    let startPosition: CGPoint
    let canvasSize: CGSize
    
    @State private var xPosition: CGFloat = 0
    @State private var yPosition: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1
    
    // Choose various snowflake designs for variety
    let snowflakeOptions = ["❄️", "❅", "❆", "✻", "✼"]
    @State private var snowflakeType: String = "❄️" // Will be randomized on appear
    
    var body: some View {
        Text(snowflakeType)
            .font(.system(size: size))
            .foregroundColor(.white)
            .position(x: xPosition, y: yPosition)
            .rotationEffect(Angle(degrees: rotation))
            .scaleEffect(scale)
            .shadow(color: .white.opacity(0.5), radius: 2, x: 0, y: 0)
            .onAppear {
                // Randomize starting properties
                snowflakeType = snowflakeOptions.randomElement() ?? "❄️"
                xPosition = startPosition.x
                yPosition = startPosition.y
                
                // Start various animations for realistic movement
                startFallingAnimation()
                startSwayingAnimation()
                startRotatingAnimation()
                startPulsingAnimation()
            }
    }
    
    // Falling animation - vertical movement
    private func startFallingAnimation() {
        let fallDuration = speed + Double.random(in: 0...3)
        let delay = Double.random(in: 0...3)
        
        withAnimation(Animation.linear(duration: fallDuration).delay(delay).repeatForever(autoreverses: false)) {
            yPosition = canvasSize.height + 50 // Fall beyond bottom of screen
        }
    }
    
    // Swaying animation - horizontal movement
    private func startSwayingAnimation() {
        let startX = xPosition
        let maxWidth = canvasSize.width
        let fallDuration = speed + Double.random(in: 0...3)
        let delay = Double.random(in: 0...1)
        let swayCount = Int.random(in: 3...6) // How many sways during fall
        
        // Create realistic side-to-side motion while falling
        for i in 0..<swayCount {
            let swayDelay = fallDuration / Double(swayCount) * Double(i)
            let direction = i % 2 == 0 ? 1.0 : -1.0
            let swayDistance = CGFloat.random(in: swayFactor/2...swayFactor) * direction
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + swayDelay) {
                withAnimation(Animation.easeInOut(duration: fallDuration / Double(swayCount))) {
                    xPosition = max(min(startX + swayDistance, maxWidth), 0)
                }
            }
        }
    }
    
    // Rotation animation
    private func startRotatingAnimation() {
        let rotationSpeed = Double.random(in: 2...5)
        let rotationDirection = Bool.random() ? 1.0 : -1.0
        let rotationAmount = 360 * rotationDirection
        
        withAnimation(Animation.linear(duration: rotationSpeed).repeatForever(autoreverses: false)) {
            rotation = rotationAmount
        }
    }
    
    // Pulsing animation for size variation
    private func startPulsingAnimation() {
        let pulseSpeed = Double.random(in: 1.5...3)
        
        withAnimation(Animation.easeInOut(duration: pulseSpeed).repeatForever(autoreverses: true)) {
            scale = CGFloat.random(in: 0.85...1.15)
        }
    }
}

// Fog overlay with realistic rising fog effect
struct FogOverlay: View {
    let fogLayerCount = 6
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Add cloud base similar to CloudOverlay for consistency
                CloudBase(opacity: 0.3)

                // Multiple layers of fog for realistic depth
                ForEach(0..<fogLayerCount, id: \.self) { index in
                    FogLayer(
                        density: getFogDensity(for: index),
                        speed: getFogSpeed(for: index),
                        baseOffset: CGFloat(index) * 60,
                        opacity: getFogOpacity(for: index),
                        bounds: geometry.size
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
    
    // Helper functions to create varying fog characteristics
    private func getFogDensity(for index: Int) -> Int {
        let baseDensity = [3, 4, 5, 4, 3, 2]
        return baseDensity[index % baseDensity.count]
    }
    
    private func getFogSpeed(for index: Int) -> Double {
        let baseSpeed = [45.0, 60.0, 50.0, 55.0, 65.0, 70.0]
        return baseSpeed[index % baseSpeed.count]
    }
    
    private func getFogOpacity(for index: Int) -> Double {
        // Front and back layers are more transparent
        if index == 0 || index == fogLayerCount-1 {
            return 0.15
        } else if index == 1 || index == fogLayerCount-2 {
            return 0.25
        } else {
            return 0.3
        }
    }
}

// Individual layer of fog
struct FogLayer: View {
    let density: Int
    let speed: Double
    let baseOffset: CGFloat
    let opacity: Double
    let bounds: CGSize
    
    @State private var xOffset: CGFloat = -100
    @State private var yOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Create multiple fog elements
            ForEach(0..<density, id: \.self) { index in
                FogElement(
                    size: getFogSize(for: index),
                    position: getFogPosition(for: index),
                    opacity: opacity
                )
            }
        }
        .offset(x: xOffset, y: yOffset)
        .onAppear {
            startFogAnimation()
        }
    }
    
    private func getFogSize(for index: Int) -> CGSize {
        let width = CGFloat.random(in: bounds.width * 0.3...bounds.width * 0.5)
        let height = CGFloat.random(in: 30...60)
        return CGSize(width: width, height: height)
    }
    
    private func getFogPosition(for index: Int) -> CGPoint {
        let x = CGFloat.random(in: 0...bounds.width)
        let y = baseOffset + CGFloat.random(in: -20...20)
        // Keep within view bounds
        return CGPoint(
            x: x,
            y: min(max(20, y), bounds.height - 20)
        )
    }
    
    private func startFogAnimation() {
        // Initial delay based on layer
        let initialDelay = Double.random(in: 0...2.0)
        
        // Slowly move fog across the screen
        withAnimation(Animation.linear(duration: speed).delay(initialDelay).repeatForever(autoreverses: false)) {
            xOffset = bounds.width + 100
        }
        
        // Subtle vertical drift
        withAnimation(Animation.easeInOut(duration: 10).delay(initialDelay).repeatForever(autoreverses: true)) {
            yOffset = CGFloat.random(in: -15...15)
        }
    }
}

// Individual fog element
struct FogElement: View {
    let size: CGSize
    let position: CGPoint
    let opacity: Double
    
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(opacity * 1.2),
                        Color.white.opacity(opacity),
                        Color.white.opacity(0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: size.width, height: size.height)
            .position(position)
            .blur(radius: 15)
            .scaleEffect(scale)
            .onAppear {
                // Subtle pulsing for more natural fog effect
                withAnimation(Animation.easeInOut(duration: Double.random(in: 4...8)).repeatForever(autoreverses: true)) {
                    scale = CGFloat.random(in: 0.9...1.1)
                }
            }
    }
}


// Field of stars with various properties
struct StarField: View {
    let count: Int
    let sizeRange: ClosedRange<CGFloat>
    let opacityRange: ClosedRange<Double>
    let twinkleIntensity: Double
    let bounds: CGSize
    
    var body: some View {
        ForEach(0..<count, id: \.self) { _ in
            Star(
                size: CGFloat.random(in: sizeRange),
                position: CGPoint(
                    x: CGFloat.random(in: 0...bounds.width),
                    y: CGFloat.random(in: 0...bounds.height * 0.7)
                ),
                baseOpacity: Double.random(in: opacityRange),
                twinkleIntensity: twinkleIntensity
            )
        }
    }
}

// Individual star with twinkling animation
struct Star: View {
    let size: CGFloat
    let position: CGPoint
    let baseOpacity: Double
    let twinkleIntensity: Double
    
    @State private var opacity: Double
    @State private var scale: CGFloat = 1.0
    
    init(size: CGFloat, position: CGPoint, baseOpacity: Double, twinkleIntensity: Double) {
        self.size = size
        self.position = position
        self.baseOpacity = baseOpacity
        self.twinkleIntensity = twinkleIntensity
        self._opacity = State(initialValue: baseOpacity)
    }
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: size, height: size)
            .position(position)
            .opacity(opacity)
            .scaleEffect(scale)
            .blur(radius: 0.2)
            .onAppear {
                startTwinkling()
            }
    }
    
    private func startTwinkling() {
        // Only apply twinkling if intensity is sufficient
        guard twinkleIntensity > 0.1 else { return }
        
        // Get random timing for natural effect
        let duration = Double.random(in: 1.0...3.0)
        let delay = Double.random(in: 0...3.0)
        
        // Subtle opacity variation based on twinkle intensity
        let minOpacity = max(0.1, baseOpacity - (twinkleIntensity * baseOpacity * 0.7))
        
        // Start twinkling animation with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Opacity animation (twinkling)
            withAnimation(Animation.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                opacity = minOpacity
            }
            
            // Scale animation (subtle pulsing)
            withAnimation(Animation.easeInOut(duration: duration * 1.5).repeatForever(autoreverses: true)) {
                scale = 1.0 - (twinkleIntensity * 0.3)
            }
        }
    }
}

// Enhanced storm overlay with realistic lightning and 3D effects
struct StormOverlay: View {
    // Lightning state variables
    @State private var isLightning = false
    @State private var lightningOpacity: Double = 0
    @State private var lightningPosition: CGPoint = .zero
    @State private var showBolt: Bool = false
    
    // More intense rain parameters
    let stormRainCount = 100
    
    var body: some View {
        GeometryReader { geometry in
        ZStack {
            // Dark storm clouds with bluish tint
            CloudOverlay()
                .colorMultiply(Color(red: 0.2, green: 0.2, blue: 0.3))
                .blur(radius: 1)
            
            // Intense rain
            RainOverlay()
            
            // Lightning effects
            ZStack {
                // Full-screen flash
                Rectangle()
                    .fill(Color.white)
                    .opacity(lightningOpacity)
                    .blendMode(.plusLighter)
                
                // Lightning bolt
                if showBolt {
                    LightningBolt()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 80, height: 150)
                        .shadow(color: .white, radius: 12, x: 0, y: 0)
                        .position(lightningPosition)
                        .opacity(isLightning ? 1 : 0)
                        .transition(.opacity)
                        .blendMode(.plusLighter)
                }
            }
            
                // Heavy rain foreground layer - additional storm rain
                RainStreakLayer(
                    count: stormRainCount,
                    lengthRange: 40...100,
                    widthRange: 1.5...3.0,
                    opacityRange: 0.3...0.6,
                    speedRange: 0.4...0.7,
                    color: Color(red: 0.5, green: 0.5, blue: 0.7),
                    bounds: geometry.size
                )
                .blendMode(.plusLighter)
        }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
                startLightningSequence(in: geometry)
            }
        }
    }
    
    // More realistic lightning with random timing
    private func startLightningSequence(in geometry: GeometryProxy) {
        // Schedule next lightning strike
        let nextStrike = Double.random(in: 2.0...6.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + nextStrike) {
            // Random position for the lightning bolt
            lightningPosition = CGPoint(
                x: CGFloat.random(in: 50...geometry.size.width-50),
                y: CGFloat.random(in: 50...200)
            )
            
            // First determine if this is a bolt strike or just a flash
            let isBoltStrike = Bool.random()
            showBolt = isBoltStrike
            
            // Initial bright flash
            withAnimation(.easeIn(duration: 0.1)) {
                lightningOpacity = Double.random(in: 0.2...0.5)
                isLightning = true
            }
            
            // Between 1-3 flickers for realism
            let flickerCount = Int.random(in: 1...3)
            var cumulativeDelay = 0.1
            
            for _ in 0..<flickerCount {
                cumulativeDelay += Double.random(in: 0.05...0.2)
                
                // Dim down
                DispatchQueue.main.asyncAfter(deadline: .now() + cumulativeDelay) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        lightningOpacity = Double.random(in: 0.05...0.2)
                    }
                }
                
                cumulativeDelay += 0.1
                
                // Bright again
                DispatchQueue.main.asyncAfter(deadline: .now() + cumulativeDelay) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        lightningOpacity = Double.random(in: 0.2...0.5)
                    }
                }
            }
            
            // Fade out the lightning
            DispatchQueue.main.asyncAfter(deadline: .now() + cumulativeDelay + 0.2) {
                withAnimation(.easeOut(duration: 0.3)) {
                    lightningOpacity = 0
                    isLightning = false
                }
                
                // Hide the bolt
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showBolt = false
                    startLightningSequence(in: geometry) // Start the next cycle
                }
            }
        }
    }
}

// Lightning bolt shape
struct LightningBolt: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Create a more realistic lightning path
        let width = rect.width
        let height = rect.height
        
        // Starting point
        path.move(to: CGPoint(x: width/2, y: 0))
        
        // Zigzag pattern
        path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.2))
        path.addLine(to: CGPoint(x: width * 0.65, y: height * 0.35))
        path.addLine(to: CGPoint(x: width * 0.3, y: height * 0.55))
        path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.75))
        path.addLine(to: CGPoint(x: width * 0.2, y: height))
        
        // Add a few branches for a more realistic bolt
        path.move(to: CGPoint(x: width * 0.4, y: height * 0.2))
        path.addLine(to: CGPoint(x: width * 0.2, y: height * 0.3))
        
        path.move(to: CGPoint(x: width * 0.65, y: height * 0.35))
        path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.45))
        
        return path
    }
}

// Note: CloudLayer is now defined in WeatherViews.swift

// Animated storm clouds component
struct StormClouds: View {
    @State private var cloudOffset1: CGFloat = 0
    @State private var cloudOffset2: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
        ZStack {
                // Darker background clouds
                CloudLayer(
                    count: 3,
                    sizeRange: 80...150,
                    opacityRange: 0.3...0.5,
                    speedRange: 50...70,
                    bounds: geometry.size,
                    zIndex: 1
                )
                
                // Lighter foreground clouds
                CloudLayer(
                    count: 2,
                    sizeRange: 100...180,
                    opacityRange: 0.2...0.4,
                    speedRange: 30...50,
                    bounds: geometry.size,
                    zIndex: 2
                )
            }
        }
    }
}


// Base cloud background
struct CloudBase: View {
    let opacity: Double
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(opacity),
                Color.white.opacity(opacity * 0.6)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .opacity(0.3)
    }
}



// Add a more subtle animation for weather icons
struct SubtleWeatherAnimation: ViewModifier {
    @State private var isAnimating = false
    let condition: WeatherCondition
    
    func body(content: Content) -> some View {
        // Return content without animations
        content
    }
    
    // These methods are no longer used, but kept for reference
    private func getScale() -> CGFloat {
        return 1.0
    }
    
    private func getRotation() -> Double {
        return 0
    }
    
    private func getOffset() -> CGFloat {
        return 0
    }
    
    private func getDuration() -> Double {
        return 0
    }
}

// Simplified LottieWeatherView implementation with no errors
struct LottieWeatherView: UIViewRepresentable {
    let weather: WeatherCondition
    let isNight: Bool
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView(frame: .zero)
        updateWeatherIcon(containerView)
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.subviews.forEach { $0.removeFromSuperview() }
        updateWeatherIcon(uiView)
    }
    
    private func updateWeatherIcon(_ containerView: UIView) {
        // Create icon container
        let iconContainer = UIView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconContainer)
        
        NSLayoutConstraint.activate([
            iconContainer.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconContainer.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            iconContainer.heightAnchor.constraint(equalTo: containerView.heightAnchor)
        ])
        
        // Use the enhanced icons based on weather condition
        switch weather {
        case .clear:
            addEnhancedClearIcon(to: iconContainer, isNight: isNight)
        case .partlyCloudy:
            addEnhancedPartlyCloudyIcon(to: iconContainer, isNight: isNight)
        case .cloudy:
            addEnhancedCloudyIcon(to: iconContainer, isNight: isNight)
        case .rainy:
            addEnhancedRainyIcon(to: iconContainer, isNight: isNight)
        case .stormy:
            addEnhancedStormyIcon(to: iconContainer, isNight: isNight)
        case .snowy:
            addEnhancedSnowyIcon(to: iconContainer, isNight: isNight)
        case .foggy:
            addEnhancedFoggyIcon(to: iconContainer, isNight: isNight)
        case .windy:
            addEnhancedWindyIcon(to: iconContainer, isNight: isNight)
        default:
            // Fallback to simple icon for unknown conditions
            let imageView = createIconImageView(systemName: "questionmark.circle.fill")
            imageView.tintColor = UIColor.systemGray
            iconContainer.addSubview(imageView)
            setupFullSizeConstraints(for: imageView, in: iconContainer)
        }
    }
}

// Add this function after the getWeatherGradient function
private func getWeatherDescription(condition: WeatherCondition, isNightMode: Bool) -> String {
    switch condition {
    case .clear:
        return isNightMode ? "Clear Night" : "Clear Day"
    case .cloudy:
        return "Cloudy"
    case .partlyCloudy:
        return isNightMode ? "Partly Cloudy Night" : "Partly Cloudy"
    case .rainy:
        return "Rainy"
    case .stormy:
        return "Thunderstorms"
    case .snowy:
        return "Snowy"
    case .foggy:
        return "Foggy"
    case .windy:
        return "Windy"
    case .unknown:
        return "Unknown Weather"
    }
}


struct CloudGroup: View {
    let count: Int
    let opacity: Double
    let scale: CGFloat
    let speed: Double
    
    @State private var cloudPositions: [(offsetX: CGFloat, offsetY: CGFloat, size: CGFloat)] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<count, id: \.self) { index in
                    if index < cloudPositions.count {
                        Cloud(opacity: opacity, speed: speed)
                            .scaleEffect(cloudPositions[index].size * scale)
                            .offset(x: cloudPositions[index].offsetX * geometry.size.width, 
                                    y: cloudPositions[index].offsetY * geometry.size.height)
                    }
                }
            }
            .onAppear {
                // Initialize cloud positions evenly distributed across the view
                cloudPositions = (0..<count).map { index in
                    let section = 1.0 / CGFloat(count)
                    let offsetX = CGFloat(index) * section
                    let offsetY = CGFloat.random(in: -0.2...0.2) // Slight vertical variation
                    let size = CGFloat.random(in: 0.8...1.2) // Size variation
                    return (offsetX: offsetX, offsetY: offsetY, size: size)
                }
            }
        }
    }
}

struct Cloud: View {
    let opacity: Double
    let speed: Double
    @State private var pulse = false
    
    var body: some View {
        Image(systemName: "cloud.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 80, height: 50)
            .foregroundColor(.white.opacity(opacity))
            .scaleEffect(pulse ? 1.03 : 1.0)
            .animation(
                Animation.easeInOut(duration: speed/10)
                    .repeatForever(autoreverses: true),
                value: pulse
            )
            .onAppear {
                pulse = true
            }
            .blur(radius: 0.5) // Slight blur for soft edges
    }
}

// Add the missing helper methods for LottieWeatherView

// MARK: - Weather Icon Implementations
private func addEnhancedClearIcon(to container: UIView, isNight: Bool) {
    // Clear existing views
    container.subviews.forEach { $0.removeFromSuperview() }
    
    let iconView = createIconImageView(
        systemName: isNight ? "moon.stars.fill" : "sun.max.fill"
    )
    iconView.tintColor = UIColor.white
    container.addSubview(iconView)
    
    // Set up constraints
    NSLayoutConstraint.activate([
        iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        iconView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.8),
        iconView.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.8)
    ])
        
        // Add glow effect
    addGlowEffect(to: iconView, color: UIColor.white, radius: 8)
    
    // Add subtle animation
    addFloatingAnimation(to: iconView, offsetY: 3)
}

private func addEnhancedPartlyCloudyIcon(to container: UIView, isNight: Bool) {
    // Clear existing views
    container.subviews.forEach { $0.removeFromSuperview() }
    
    let iconView = createIconImageView(
        systemName: isNight ? "cloud.moon.fill" : "cloud.sun.fill"
    )
    iconView.tintColor = UIColor.white
    container.addSubview(iconView)
    
    // Set up constraints
    NSLayoutConstraint.activate([
        iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        iconView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.8),
        iconView.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.8)
    ])
    
    // Add glow effect
    addGlowEffect(to: iconView, color: UIColor.white, radius: 6)
        
        // Add subtle animation
    addFloatingAnimation(to: iconView, offsetY: 2)
}

private func addEnhancedCloudyIcon(to container: UIView, isNight: Bool) {
    // Clear any existing views
    container.subviews.forEach { $0.removeFromSuperview() }
    
    // Container dimensions
    let containerWidth = container.bounds.width
    let containerHeight = container.bounds.height
    
    // Add a light background for better visibility
    let backgroundView = UIView(frame: container.bounds)
    backgroundView.backgroundColor = UIColor.clear
    backgroundView.layer.cornerRadius = 20
    container.addSubview(backgroundView)
    
    // Add cloud base
    let cloudBase = UIView(frame: container.bounds)
    let cloudGradient = CAGradientLayer()
    cloudGradient.frame = cloudBase.bounds
    cloudGradient.colors = [
        UIColor.white.withAlphaComponent(0.4).cgColor,
        UIColor.white.withAlphaComponent(0.2).cgColor
    ]
    cloudGradient.startPoint = CGPoint(x: 0.5, y: 0)
    cloudGradient.endPoint = CGPoint(x: 0.5, y: 1)
    cloudBase.layer.addSublayer(cloudGradient)
    cloudBase.layer.cornerRadius = 20
    cloudBase.clipsToBounds = true
    container.addSubview(cloudBase)
    
    // Add stationary cloud elements
    addStationaryCloud(to: container, size: containerWidth * 0.4, x: containerWidth * 0.3, y: containerHeight * 0.3, opacity: 0.8)
    addStationaryCloud(to: container, size: containerWidth * 0.35, x: containerWidth * 0.5, y: containerHeight * 0.5, opacity: 0.7)
    
    // Add moving cloud elements
    addMovingClouds(to: container, count: 2)
}

// Function to add stationary cloud elements
private func addStationaryCloud(to container: UIView, size: CGFloat, x: CGFloat, y: CGFloat, opacity: CGFloat) {
    let cloudView = UIView(frame: CGRect(x: x, y: y, width: size, height: size * 0.6))
    let cloudLayer = CAShapeLayer()
    cloudLayer.path = UIBezierPath(ovalIn: cloudView.bounds).cgPath
    cloudLayer.fillColor = UIColor.white.withAlphaComponent(opacity).cgColor
    cloudView.layer.addSublayer(cloudLayer)
    cloudView.layer.shadowColor = UIColor.white.cgColor
    cloudView.layer.shadowOpacity = 0.3
    cloudView.layer.shadowRadius = 8
    cloudView.layer.shadowOffset = CGSize.zero
    
    container.addSubview(cloudView)
    
    // Add floating animation to cloud
    UIView.animate(withDuration: Double.random(in: 2...4), delay: 0, options: [.autoreverse, .repeat], animations: {
        cloudView.transform = CGAffineTransform(translationX: 0, y: CGFloat.random(in: -8...(-3)))
    }, completion: nil)
}

// Function to add moving cloud elements
private func addMovingClouds(to container: UIView, count: Int) {
    let containerWidth = container.bounds.width
    let containerHeight = container.bounds.height
    
    for i in 0..<count {
        // Create cloud element
        let cloudHeight = CGFloat.random(in: 40...60)
        let cloudWidth = containerWidth * CGFloat.random(in: 0.4...0.6)
        
        let yPosition = containerHeight * CGFloat(i) / CGFloat(count * 2)
            + CGFloat.random(in: -5...5)
            + containerHeight * 0.2 // Start higher in the container
        
        let cloudView = UIView(frame: CGRect(
            x: -cloudWidth,  // Start outside the container
            y: min(max(10, yPosition), containerHeight - cloudHeight - 10), // Keep within bounds
            width: cloudWidth,
            height: cloudHeight
        ))
        
        // Use oval shape for cloud
        let cloudShape = CAShapeLayer()
        cloudShape.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: cloudWidth, height: cloudHeight)).cgPath
        cloudShape.fillColor = UIColor.white.withAlphaComponent(CGFloat.random(in: 0.4...0.7)).cgColor
        cloudView.layer.addSublayer(cloudShape)
        
        // Add blur effect for cloud-like appearance
        cloudView.layer.shadowColor = UIColor.white.cgColor
        cloudView.layer.shadowOpacity = 0.5
        cloudView.layer.shadowRadius = 10
        cloudView.layer.shadowOffset = CGSize.zero
        cloudView.alpha = 0
        
        container.addSubview(cloudView)
        
        // Animate the cloud
        let delay = Double(i) * 1.0 + Double.random(in: 0...2.0)
        animateMovingCloud(cloudView, delay: delay, containerWidth: containerWidth)
    }
}

// Function to animate moving clouds
private func animateMovingCloud(_ cloudView: UIView, delay: Double, containerWidth: CGFloat) {
    // Fade in
    UIView.animate(withDuration: 1.5, delay: delay, options: [], animations: {
        cloudView.alpha = 1.0
    }, completion: nil)
    
    // Move across the screen
    let duration = Double.random(in: 15...25) // Slower than fog
    UIView.animate(
        withDuration: duration,
        delay: delay,
        options: [.curveLinear],
        animations: {
            cloudView.frame.origin.x = containerWidth
        },
        completion: { _ in
            // Remove when animation completes
            cloudView.removeFromSuperview()
            
            // Add a new cloud element to replace this one
            if let container = cloudView.superview {
                addMovingClouds(to: container, count: 1)
            }
        }
    )
    
    // Add subtle vertical drift
    let smallDrift: CGFloat = CGFloat.random(in: -8...8)
    UIView.animate(
        withDuration: 5.0,
        delay: delay,
        options: [.autoreverse, .repeat],
        animations: {
            cloudView.transform = CGAffineTransform(translationX: 0, y: smallDrift)
        },
        completion: nil
    )
}

private func addEnhancedRainyIcon(to container: UIView, isNight: Bool) {
    // Clear existing views
    container.subviews.forEach { $0.removeFromSuperview() }
    
    // Cloud
    let cloudView = createIconImageView(systemName: "cloud.fill")
    cloudView.tintColor = UIColor.white
    
    // Raindrops
    let rainContainer = UIView()
    rainContainer.translatesAutoresizingMaskIntoConstraints = false
    
    // Add to container
    container.addSubview(cloudView)
    container.addSubview(rainContainer)
    
    // Set up constraints
    NSLayoutConstraint.activate([
        cloudView.topAnchor.constraint(equalTo: container.topAnchor, constant: 5),
        cloudView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        cloudView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.8),
        cloudView.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.5),
        
        rainContainer.topAnchor.constraint(equalTo: cloudView.bottomAnchor, constant: -5),
        rainContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        rainContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        rainContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])
    
    // Add raindrops (white)
    addRaindrops(to: rainContainer, color: .white)
    
    // Add floating animation to cloud
    addFloatingAnimation(to: cloudView, offsetY: 2)
}

private func addEnhancedStormyIcon(to container: UIView, isNight: Bool) {
    // Clear existing views
    container.subviews.forEach { $0.removeFromSuperview() }
    
    // Cloud
    let cloudView = createIconImageView(systemName: "cloud.fill")
    cloudView.tintColor = UIColor.white
    
    // Lightning bolt
    let boltView = createIconImageView(systemName: "bolt.fill")
    boltView.tintColor = UIColor.white
    
    // Add to container
    container.addSubview(cloudView)
    container.addSubview(boltView)
    
    // Set up constraints
    NSLayoutConstraint.activate([
        cloudView.topAnchor.constraint(equalTo: container.topAnchor, constant: 5),
        cloudView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        cloudView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.8),
        cloudView.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.5),
        
        boltView.topAnchor.constraint(equalTo: cloudView.bottomAnchor, constant: -5),
        boltView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        boltView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.4),
        boltView.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.5)
    ])
    
    // Add glow to bolt
    addGlowEffect(to: boltView, color: UIColor.white, radius: 5)
    
    // Add lightning flash animation
    addLightningFlashAnimation(to: boltView)
    
    // Add floating animation to cloud
    addFloatingAnimation(to: cloudView, offsetY: 2)
}

private func addEnhancedSnowyIcon(to container: UIView, isNight: Bool) {
    // Clear existing views
    container.subviews.forEach { $0.removeFromSuperview() }
    
    // Cloud
    let cloudView = createIconImageView(systemName: "cloud.fill")
    cloudView.tintColor = UIColor.white
    
    // Snowflakes container
    let snowContainer = UIView()
    snowContainer.translatesAutoresizingMaskIntoConstraints = false
    
    // Add to container
    container.addSubview(cloudView)
    container.addSubview(snowContainer)
    
    // Set up constraints
    NSLayoutConstraint.activate([
        cloudView.topAnchor.constraint(equalTo: container.topAnchor, constant: 5),
        cloudView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        cloudView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.8),
        cloudView.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.5),
        
        snowContainer.topAnchor.constraint(equalTo: cloudView.bottomAnchor, constant: -5),
        snowContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        snowContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        snowContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])
    
    // Add snowflakes (white)
    addSnowflakes(to: snowContainer, color: .white)
    
    // Add floating animation to cloud
    addFloatingAnimation(to: cloudView, offsetY: 2)
}

private func addEnhancedFoggyIcon(to container: UIView, isNight: Bool) {
    // Clear any existing views
    container.subviews.forEach { $0.removeFromSuperview() }
    
    // Container dimensions
    let containerWidth = container.bounds.width
    let containerHeight = container.bounds.height
    
    // Add a light background for better visibility
    let backgroundView = UIView(frame: container.bounds)
    backgroundView.backgroundColor = UIColor.clear
    backgroundView.layer.cornerRadius = 20
    container.addSubview(backgroundView)
    
    // Add cloud base
    let cloudBase = UIView(frame: container.bounds)
    let cloudGradient = CAGradientLayer()
    cloudGradient.frame = cloudBase.bounds
    cloudGradient.colors = [
        UIColor.white.withAlphaComponent(0.3).cgColor,
        UIColor.white.withAlphaComponent(0.1).cgColor
    ]
    cloudGradient.startPoint = CGPoint(x: 0.5, y: 0)
    cloudGradient.endPoint = CGPoint(x: 0.5, y: 1)
    cloudBase.layer.addSublayer(cloudGradient)
    cloudBase.layer.cornerRadius = 20
    cloudBase.clipsToBounds = true
    container.addSubview(cloudBase)
    
    // Add a few cloud elements for consistency with cloud effect
    let cloudSize: CGFloat = containerWidth * 0.3
    let cloudY = containerHeight * 0.3
    
    let cloudView = UIView(frame: CGRect(x: containerWidth * 0.1, y: cloudY, width: cloudSize, height: cloudSize * 0.6))
    let cloudLayer = CAShapeLayer()
    cloudLayer.path = UIBezierPath(ovalIn: cloudView.bounds).cgPath
    cloudLayer.fillColor = UIColor.white.withAlphaComponent(0.6).cgColor
    cloudView.layer.addSublayer(cloudLayer)
    cloudView.layer.shadowColor = UIColor.white.cgColor
    cloudView.layer.shadowOpacity = 0.3
    cloudView.layer.shadowRadius = 8
    cloudView.layer.shadowOffset = CGSize.zero
    cloudView.alpha = 0.8
    container.addSubview(cloudView)
    
    // Add floating animation to cloud
    UIView.animate(withDuration: 3.0, delay: 0, options: [.autoreverse, .repeat], animations: {
        cloudView.transform = CGAffineTransform(translationX: 0, y: -5)
    }, completion: nil)
    
    // Add fog elements - horizontal moving fog
    addFogElements(to: container, count: 5)
}

private func addFogElements(to container: UIView, count: Int) {
    let containerWidth = container.bounds.width
    let containerHeight = container.bounds.height
    
    for i in 0..<count {
        // Create fog element - use capsule shape for horizontal fog
        let fogHeight = CGFloat.random(in: 25...45)
        let fogWidth = containerWidth * CGFloat.random(in: 0.3...0.5)
        
        let yPosition = containerHeight * CGFloat(i) / CGFloat(count)
            + CGFloat.random(in: -10...10)
            + containerHeight * 0.2 // Start a bit higher in the container
        
        let fogView = UIView(frame: CGRect(
            x: -fogWidth,  // Start outside the container
            y: min(max(10, yPosition), containerHeight - fogHeight - 10), // Keep within bounds
            width: fogWidth,
            height: fogHeight
        ))
        
        // Create gradient for the fog
        let fogGradient = CAGradientLayer()
        fogGradient.frame = fogView.bounds
        fogGradient.cornerRadius = fogHeight / 2  // Make it a capsule
        
        // Use white with varying opacity for the gradient
        let startOpacity = CGFloat.random(in: 0.2...0.4)
        fogGradient.colors = [
            UIColor.white.withAlphaComponent(startOpacity).cgColor,
            UIColor.white.withAlphaComponent(startOpacity * 0.6).cgColor,
            UIColor.white.withAlphaComponent(startOpacity * 0.2).cgColor
        ]
        
        // Horizontal gradient
        fogGradient.startPoint = CGPoint(x: 0, y: 0.5)
        fogGradient.endPoint = CGPoint(x: 1, y: 0.5)
        
        fogView.layer.addSublayer(fogGradient)
        fogView.layer.cornerRadius = fogHeight / 2
        fogView.clipsToBounds = true
        fogView.alpha = 0
        
        container.addSubview(fogView)
        
        // Animate the fog element
        let delay = Double(i) * 0.5 + Double.random(in: 0...1.0)
        animateFogElement(fogView, delay: delay, containerWidth: containerWidth)
    }
}

private func animateFogElement(_ fogView: UIView, delay: Double, containerWidth: CGFloat) {
    // Fade in
    UIView.animate(withDuration: 1.0, delay: delay, options: [], animations: {
        fogView.alpha = 1.0
    }, completion: nil)
    
    // Move across the screen
    let duration = Double.random(in: 8...12)
    UIView.animate(
        withDuration: duration,
        delay: delay,
        options: [.curveLinear],
        animations: {
            fogView.frame.origin.x = containerWidth
        },
        completion: { _ in
            // Remove when animation completes
            fogView.removeFromSuperview()
            
            // Add a new fog element to replace this one
            if let container = fogView.superview {
                addFogElements(to: container, count: 1)
            }
        }
    )
    
    // Add subtle vertical drift
    let smallDrift: CGFloat = CGFloat.random(in: -5...5)
    UIView.animate(
        withDuration: 3.0,
        delay: delay,
        options: [.autoreverse, .repeat],
        animations: {
            fogView.transform = CGAffineTransform(translationX: 0, y: smallDrift)
        },
        completion: nil
    )
}

private func addEnhancedWindyIcon(to container: UIView, isNight: Bool) {
    // Clear existing views
    container.subviews.forEach { $0.removeFromSuperview() }
    
    // Main wind icon
    let windView = createIconImageView(systemName: "wind")
    windView.tintColor = UIColor.white
    
    // Secondary smaller wind icons for effect
    let windView2 = createIconImageView(systemName: "wind")
    windView2.tintColor = UIColor.white.withAlphaComponent(0.7)
    windView2.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        .translatedBy(x: -20, y: 15)
    
    let windView3 = createIconImageView(systemName: "wind")
    windView3.tintColor = UIColor.white.withAlphaComponent(0.5)
    windView3.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        .translatedBy(x: -15, y: -15)
    
    // Add to container
    container.addSubview(windView3) // Background
    container.addSubview(windView2) // Middle
    container.addSubview(windView) // Foreground
    
    // Setup constraints
    NSLayoutConstraint.activate([
        windView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        windView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        windView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.9),
        windView.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.5),
        
        windView2.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.6),
        windView2.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.4),
        
        windView3.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.5),
        windView3.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.3)
    ])
    
    // Add wind animation
    addWindAnimation(to: windView)
    addWindAnimation(to: windView2, delay: 0.2)
    addWindAnimation(to: windView3, delay: 0.4)
}

// Helper methods
private func setupFullSizeConstraints(for view: UIView, in container: UIView) {
    NSLayoutConstraint.activate([
        view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        view.topAnchor.constraint(equalTo: container.topAnchor),
        view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])
}

private func createIconImageView(systemName: String) -> UIImageView {
    let imageView = UIImageView()
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.contentMode = .scaleAspectFit
    imageView.image = UIImage(systemName: systemName)
    return imageView
}

private func addGlowEffect(to view: UIView, color: UIColor, radius: CGFloat) {
    view.layer.shadowColor = color.cgColor
    view.layer.shadowRadius = radius
    view.layer.shadowOpacity = 0.7
    view.layer.shadowOffset = CGSize.zero
    view.layer.masksToBounds = false
}

private func addFloatingAnimation(to view: UIView, offsetY: CGFloat = 3, duration: Double = 1.5) {
    UIView.animate(withDuration: duration, delay: 0, options: [.autoreverse, .repeat, .curveEaseInOut], animations: {
        view.transform = CGAffineTransform(translationX: 0, y: offsetY)
    }, completion: nil)
}

private func addWindAnimation(to view: UIView, delay: Double = 0) {
    // First move left
    UIView.animate(withDuration: 1.5, delay: delay, options: .curveEaseInOut, animations: {
        view.transform = CGAffineTransform(translationX: -10, y: 0)
    }, completion: { _ in
        // Then move right further
        UIView.animate(withDuration: 1.5, delay: delay, options: .curveEaseInOut, animations: {
            view.transform = CGAffineTransform(translationX: 10, y: 0)
        }, completion: { _ in
            // Reset and repeat
            UIView.animate(withDuration: 0.0, animations: {
                view.transform = .identity
            }, completion: { _ in
                addWindAnimation(to: view, delay: delay)
            })
        })
    })
}

private func addRaindrops(to container: UIView, color: UIColor = .white) {
    // Clear existing raindrops if any
    container.subviews.forEach { $0.removeFromSuperview() }
    
    let bounds = container.bounds
    let dropCount = 8
    
    for i in 0..<dropCount {
        let drop = UIView()
        drop.backgroundColor = color
        drop.alpha = 0.7
        
        // Randomize size and position
        let dropWidth = CGFloat.random(in: 1...2)
        let dropHeight = CGFloat.random(in: 5...15)
        let xPosition = CGFloat(i) * bounds.width / CGFloat(dropCount) + CGFloat.random(in: -5...5)
        let yPosition = CGFloat.random(in: 0...20)
        
        drop.frame = CGRect(x: xPosition, y: yPosition, width: dropWidth, height: dropHeight)
        drop.layer.cornerRadius = dropWidth / 2
        
        container.addSubview(drop)
        
        // Animate falling rain
        UIView.animate(withDuration: 1.0, delay: Double.random(in: 0...0.5), options: [.repeat, .curveLinear], animations: {
            drop.frame.origin.y = bounds.height
        })
    }
}

private func addSnowflakes(to container: UIView, color: UIColor = .white) {
    // Clear existing snowflakes if any
    container.subviews.forEach { $0.removeFromSuperview() }
    
    let bounds = container.bounds
    let flakeCount = 8
    
    for _ in 0..<flakeCount {
        let snowflake = UILabel()
        snowflake.text = "❄︎"
        snowflake.textColor = color
        snowflake.font = UIFont.systemFont(ofSize: CGFloat.random(in: 8...15))
        
        // Randomize position
        let xPosition = CGFloat.random(in: 0...bounds.width)
        let yPosition = CGFloat.random(in: 0...20)
        
        snowflake.frame = CGRect(x: xPosition, y: yPosition, width: 15, height: 15)
        container.addSubview(snowflake)
        
        // Animate falling snow with slight horizontal movement
        UIView.animateKeyframes(withDuration: Double.random(in: 2.5...4.0), delay: Double.random(in: 0...1.0), options: [.repeat], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.3) {
                snowflake.transform = CGAffineTransform(translationX: CGFloat.random(in: -5...5), y: 0)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.3, relativeDuration: 0.4) {
                snowflake.transform = CGAffineTransform(translationX: CGFloat.random(in: -5...5), y: bounds.height / 3)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.7, relativeDuration: 0.3) {
                snowflake.transform = CGAffineTransform(translationX: CGFloat.random(in: -5...5), y: bounds.height)
            }
        })
        
        // Add rotation
        UIView.animate(withDuration: Double.random(in: 2...4), delay: 0, options: [.repeat, .curveLinear], animations: {
            snowflake.transform = snowflake.transform.rotated(by: .pi * 2)
        })
    }
}

private func addLightningFlashAnimation(to view: UIView) {
    // Lightning function with randomized timing
    func flashLightning() {
        // Initial state
        view.alpha = 0.4
        
        // First bright flash
        UIView.animate(withDuration: 0.1, animations: {
            view.alpha = 1.0
            view.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }, completion: { _ in
            // Brief dim
            UIView.animate(withDuration: 0.1, animations: {
                view.alpha = 0.6
                view.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            }, completion: { _ in
                // Second flash
                UIView.animate(withDuration: 0.1, animations: {
                    view.alpha = 0.9
                    view.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                }, completion: { _ in
                    // Fade out
                    UIView.animate(withDuration: 0.2, animations: {
                        view.alpha = 0.4
                        view.transform = .identity
                    }, completion: { _ in
                        // Schedule next lightning with random timing
                        let nextDelay = Double.random(in: 2.0...5.0)
                        DispatchQueue.main.asyncAfter(deadline: .now() + nextDelay) {
                            flashLightning()
                        }
                    })
                })
            })
        })
    }
    
    // Start the lightning sequence
    let initialDelay = Double.random(in: 0.2...1.0)
    DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) {
        flashLightning()
    }
}

// Simplified WeatherAnimationTestView
struct WeatherAnimationTestView: View {
    @State private var currentCondition: WeatherCondition = .clear
    @State private var isNight: Bool = false
    @State private var timer: Timer? = nil
    
    var body: some View {
        ZStack {
            // Background color
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("Weather Animation Test")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                // Weather display
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.weatherGradient(for: currentCondition, hour: isNight ? 22 : 12).0,
                                    Color.weatherGradient(for: currentCondition, hour: isNight ? 22 : 12).1
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Weather animation overlay
                    weatherAnimationOverlay(condition: currentCondition, isNight: isNight)
                    
                    // Weather content
                    VStack {
                        Text("\(getWeatherDescription(condition: currentCondition, isNightMode: isNight))")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top, 10)
                        
                        LottieWeatherView(weather: currentCondition, isNight: isNight)
                            .frame(width: 100, height: 100)
                            .padding()
                    }
                }
                .frame(height: 200)
                .padding(.horizontal)
                
                HStack {
                    Text("Condition: \(currentCondition.rawValue)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Toggle("Night Mode", isOn: $isNight)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                .padding(.horizontal)
                
                // Controls for cycling through conditions
                HStack(spacing: 20) {
                    Button("Previous") {
                        cycleCondition(forward: false)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Button("Next") {
                        cycleCondition(forward: true)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                
                Spacer()
                
                Button("Close") {
                    timer?.invalidate()
                    self.dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 30)
            }
            .padding()
        }
        .onAppear {
            // Set up timer to cycle through conditions
            timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                cycleCondition(forward: true)
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func cycleCondition(forward: Bool) {
        let conditions: [WeatherCondition] = [.clear, .partlyCloudy, .cloudy, .rainy, .stormy, .snowy, .foggy, .windy]
        
        if let index = conditions.firstIndex(of: currentCondition) {
            if forward {
                currentCondition = conditions[(index + 1) % conditions.count]
            } else {
                currentCondition = conditions[(index - 1 + conditions.count) % conditions.count]
            }
        }
    }
    
    private func dismiss() {
        if let window = UIApplication.shared.windows.first {
            window.rootViewController?.dismiss(animated: true)
        }
    }
    
    // Weather animation overlay function
    private func weatherAnimationOverlay(condition: WeatherCondition, isNight: Bool) -> some View {
        ZStack(alignment: .top) {
            switch condition {
            case .rainy:
                ModernRainOverlay(intensity: .medium, nightMode: isNight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .stormy:
                StormOverlay()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .snowy:
                SnowOverlay()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .foggy:
                FogOverlay()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .cloudy:
                CloudOverlay()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .partlyCloudy:
                if isNight {
                    ZStack(alignment: .top) {
                        StarryNightOverlay()
                        CloudOverlay(cloudiness: .partial)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    // Time of day variations
                    let hour = Calendar.current.component(.hour, from: Date())
                    if hour >= 5 && hour < 9 {
                        // Early morning (5-9 AM)
                        PartlyCloudyMorningView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else if hour >= 17 && hour < 20 {
                        // Evening (5-8 PM)
                        PartlyCloudyEveningView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        // Regular daytime
                        ZStack(alignment: .top) {
                            SunRaysView(showSun: false)
                            CloudOverlay(cloudiness: .partial)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                }
            case .clear, .unknown:
                if isNight {
                    StarryNightOverlay()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    // Time of day variations
                    let hour = Calendar.current.component(.hour, from: Date())
                    if hour >= 5 && hour < 9 {
                        // Early morning (5-9 AM)
                        ClearMorningView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else if hour >= 17 && hour < 20 {
                        // Evening (5-8 PM)
                        ClearEveningView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        // Regular daytime
                        ClearDayView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                }
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }
    
    // Button style for consistency
    struct PrimaryButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
                .opacity(configuration.isPressed ? 0.9 : 1)
        }
    }
    
    // Add weather description function
    private func getWeatherDescription(condition: WeatherCondition, isNightMode: Bool) -> String {
        switch condition {
        case .clear:
            return isNightMode ? "Clear Night" : "Clear Day"
        case .cloudy:
            return "Cloudy"
        case .partlyCloudy:
            return isNightMode ? "Partly Cloudy Night" : "Partly Cloudy"
        case .rainy:
            return "Rainy"
        case .stormy:
            return "Thunderstorms"
        case .snowy:
            return "Snowy"
        case .foggy:
            return "Foggy"
        case .windy:
            return "Windy"
        case .unknown:
            return "Unknown Weather"
        }
    }
}

// Add Color.weatherGradient extension

// Add RunTypeInfoView definition to fix the "Cannot find in scope" error
struct RunTypeInfoView: View {
    var selectedType: RunType?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // If a specific run type is selected, show just that one
                    if let type = selectedType {
                        runTypeDetailCard(type)
                    } else {
                        // Otherwise show all run types
                        Text("Run Types Guide")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.bottom, 8)
                        
                        Text("Choose the right run type for your goals and terrain.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 16)
                        
                        // Display all run types
                        ForEach(RunType.allCases) { type in
                            runTypeDetailCard(type)
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitle(selectedType == nil ? "Run Types" : selectedType!.rawValue, displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func runTypeDetailCard(_ type: RunType) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.headline)
                    
                    Text(type.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Tips for this run type
            Text("Tips")
                .font(.headline)
                .padding(.bottom, 8)
            
            ForEach(type.coachingTips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                    
                    Text(tip)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.vertical, 8)
    }
}

struct RouteSelectionView: View {
    var onSelectRoute: (Route) -> Void
    var onCancel: () -> Void
    
    @State private var searchText = ""
    @Environment(\.presentationMode) private var presentationMode
    
    // Sample routes for demonstration
    private let routes: [Route] = [
        Route(name: "Park Loop", distance: 3.2, elevation: 45, difficulty: .easy),
        Route(name: "River Trail", distance: 5.6, elevation: 120, difficulty: .moderate),
        Route(name: "Mountain Path", distance: 8.4, elevation: 350, difficulty: .difficult),
        Route(name: "City Run", distance: 4.1, elevation: 30, difficulty: .easy),
        Route(name: "Waterfront Route", distance: 6.8, elevation: 80, difficulty: .moderate)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.opacity(0.9).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search routes", text: $searchText)
                            .foregroundColor(.white)
                            .accentColor(.blue)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Routes list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredRoutes) { route in
                                routeCard(route: route)
                                    .onTapGesture {
                                        onSelectRoute(route)
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitle("Select Route", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    onCancel()
                },
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private var filteredRoutes: [Route] {
        if searchText.isEmpty {
            return routes
        } else {
            return routes.filter { route in
                // Safely unwrap the optional name, defaulting to empty string if nil
                let routeName = route.name?.lowercased() ?? ""
                return routeName.contains(searchText.lowercased())
            }
        }
    }
    
    private func routeCard(route: Route) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Route icon and name
            HStack {
                Image(systemName: "figure.run")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                Text(route.name ?? "Unnamed Route")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Route stats
            HStack(spacing: 12) {
                // Distance
                HStack(spacing: 4) {
                    Image(systemName: "ruler")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f km", route.distance))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                // Elevation
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Text(String(format: "%.0f m", route.elevation))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                // Difficulty
                HStack(spacing: 4) {
                    Image(systemName: getDifficultyIcon(for: route.difficulty))
                        .font(.system(size: 10))
                        .foregroundColor(getDifficultyColor(for: route.difficulty))
                    Text(getDifficultyText(for: route.difficulty))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
    
    private func getDifficultyIcon(for difficulty: RouteDifficulty) -> String {
        switch difficulty {
        case .easy:
            return "figure.walk"
        case .moderate:
            return "figure.run"
        case .difficult:
            return "figure.highintensity.intervaltraining"
        }
    }
    
    private func getDifficultyText(for difficulty: RouteDifficulty) -> String {
        switch difficulty {
        case .easy:
            return "Easy"
        case .moderate:
            return "Moderate"
        case .difficult:
            return "Hard"
        }
    }
    
    private func getDifficultyColor(for difficulty: RouteDifficulty) -> Color {
        switch difficulty {
        case .easy:
            return .green
        case .moderate:
            return .yellow
        case .difficult:
            return .orange
        }
    }
}

// Helper view for star backgrounds
private struct StarryBackgroundView: View {
    let starOpacity: Double
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background stars (static, smaller)
                ForEach(0..<20, id: \.self) { i in
                    Circle()
                        .fill(Color.white)
                        .frame(width: CGFloat.random(in: 1...2), height: CGFloat.random(in: 1...2))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                        .opacity(Double.random(in: 0.2...0.5) * starOpacity)
                }
            }
        }
    }
}



// Note: ShimmerWave is now defined in WeatherViews.swift

// Add this extension to make the hour check more readable
extension Int {
    fileprivate func isBetween(_ lower: Int, and upper: Int) -> Bool {
        return self >= lower && self <= upper
    }
}




// Add this extension to SwiftUI's View
extension View {
    func getRootViewController() -> UIViewController? {
        // Get the UIWindow scenes
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return nil
        }
        
        // Return the topmost view controller
        var topController = rootViewController
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        
        return topController
    }
    
    // Helper function to present a view controller from SwiftUI
    func presentViewController(_ viewController: UIViewController, animated: Bool = true) {
        if let rootViewController = self.getRootViewController() {
            rootViewController.present(viewController, animated: animated)
        }
    }
}

// MARK: - Run History Popover
struct RunHistoryPopover: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let historyVC = RunHistoryViewController()
        
        // Set up for popup presentation with drag-to-dismiss
        historyVC.modalPresentationStyle = .pageSheet
        historyVC.preferredContentSize = CGSize(
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height * 0.9
        )
        
        // Wrap in navigation controller for proper presentation
        let navController = UINavigationController(rootViewController: historyVC)
        navController.modalPresentationStyle = .pageSheet
        
        // Configure for drag-to-dismiss
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        // Set transparent navigation bar
        navController.navigationBar.tintColor = .white
        navController.navigationBar.backgroundColor = UIColor.clear
        navController.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navController.navigationBar.shadowImage = UIImage()
        navController.navigationBar.isTranslucent = true
        
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // Coordinator class to handle presentation delegate
    class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            // Handle dismissal if needed
        }
    }
}

// Add this method near the WCSession handling

// MARK: - Thread-Safe Watch Communication

/// Sends a message to the watch with proper thread safety and timeout handling
private func sendWatchMessage(_ message: [String: Any], timeout: TimeInterval = 3.0, 
                             completion: ((Bool, Error?) -> Void)? = nil) {
    // Ensure we're on the main thread for WCSession operations
    if !Thread.isMainThread {
        DispatchQueue.main.async {
            sendWatchMessage(message, timeout: timeout, completion: completion)
        }
        return
    }
    
    guard WCSession.default.activationState == .activated, 
          WCSession.default.isReachable else {
        print("⚠️ Watch is not reachable")
        completion?(false, NSError(domain: "com.do.watchconnectivity", 
                                  code: 1, 
                                  userInfo: [NSLocalizedDescriptionKey: "Watch not reachable"]))
        return
    }
    
    // Setup timeout
    let timeoutWorkItem = DispatchWorkItem {
        print("⚠️ Watch communication timed out")
        completion?(false, NSError(domain: "com.do.watchconnectivity", 
                                  code: 2, 
                                  userInfo: [NSLocalizedDescriptionKey: "Watch communication timed out"]))
    }
    
    // Schedule timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
    
    // Send message with reply handler
    WCSession.default.sendMessage(message, replyHandler: { reply in
        // Cancel timeout since we got a response
        timeoutWorkItem.cancel()
        
        // Handle reply on main thread
        DispatchQueue.main.async {
            completion?(true, nil)
        }
    }, errorHandler: { error in
        // Cancel timeout since we got an error
        timeoutWorkItem.cancel()
        
        // Handle error on main thread
        DispatchQueue.main.async {
            print("⚠️ Watch communication error: \(error.localizedDescription)")
            completion?(false, error)
        }
    })
}

// MARK: - Active Watch Workout Data Structure

// Define a struct to hold active workout data
struct ActiveWatchWorkoutData {
    let isIndoor: Bool
    let state: String
    let distance: Double
    let elapsedTime: TimeInterval
    let heartRate: Double
    let calories: Double
    let cadence: Double
    let pace: Double
    let startDate: Date
    let rawData: [String: Any]
    
    // Helper computed properties for display
    var formattedDistance: String {
        if distance > 0 {
            let useMetric = UserPreferences.shared.useMetricSystem
            
            if useMetric {
                // Metric: Use kilometers for distances > 1000m
            if distance >= 1000 {
                return String(format: "%.2f km", distance / 1000)
            } else {
                return String(format: "%.0f m", distance)
            }
        } else {
                // Imperial: Use miles
                let miles = distance * 0.000621371 // Convert meters to miles
                if miles >= 0.1 {
                    return String(format: "%.2f mi", miles)
                } else {
                    // Convert to feet for very short distances
                    let feet = distance * 3.28084
                    return String(format: "%.0f ft", feet)
                }
            }
        } else {
            return UserPreferences.shared.useMetricSystem ? "0 m" : "0 ft"
        }
    }
    
    var formattedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var formattedPace: String {
        if pace <= 0 {
            return "--:--"
        }
        
        // Ensure we have a stable reference to the unit preference to avoid flickering
        // This is critical - we must capture the value once and use it consistently
        let useMetric = UserPreferences.shared.useMetricSystem
        
        // IMPORTANT: After our conversion in processOngoingWorkoutData, 
        // the pace is now ALWAYS in seconds/km format
        
        // Now convert to proper units based on user preference
        let displayPaceSeconds: Double
        
        
        
        if useMetric {
            // For metric, no conversion needed since we already have seconds/km
            displayPaceSeconds = pace
        } else {
            // For imperial, convert seconds/km to seconds/mile
            displayPaceSeconds = pace * 1.60934
        }
        
        // Format as minutes:seconds
        let safePace = displayPaceSeconds.isFinite ? displayPaceSeconds : 0
        let minutes = Int(safePace) / 60

        let seconds = Int(safePace) % 60
        
        // Create final display string with correct unit suffix
        // Using standard format to match the phone's native display
        return String(format: "%d:%02d%@", minutes, seconds, (useMetric ? "/km" : "/mi"))
    }
    
    // Normalized state for internal use
    var normalizedState: RunState {
        switch state.lowercased() {
        case "inprogress", "running", "active":
            return .running
        case "paused":
            return .paused
        default:
            return .running // Default to running if state is unknown
        }
    }
    
    var formattedState: String {
        switch state.lowercased() {
        case "inprogress", "running", "active":
            return "In Progress"
        case "paused":
            return "Paused"
        default:
            return "In Progress" // Default display
        }
    }
    
    var runTypeText: String {
        if let runTypeString = rawData["runType"] as? String {
            switch runTypeString {
            case "outdoorRun": return "Outdoor Run"
            case "treadmillRun": return "Treadmill Run"
            case "trailRun": return "Trail Run"
            case "intervalTraining": return "Interval Training"
            case "recoveryRun": return "Recovery Run"
            case "lapRun": return "Lap Run"
            default: return isIndoor ? "Indoor Run" : "Outdoor Run"
            }
        } else if let workoutType = rawData["workoutType"] as? String {
            return workoutType == "indoorRun" ? "Indoor Run" : "Outdoor Run"
        } else {
        return isIndoor ? "Indoor Run" : "Outdoor Run"
        }
    }
}

