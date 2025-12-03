//
//  ModernHikeTrackerViewController.swift
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

class ModernHikeTrackerViewController: UIViewController, ObservableObject, CLLocationManagerDelegate, CategorySwitchable, WCSessionDelegate, OutdoorHikeViewControllerDelegate {
    
    // MARK: - Map Position Enum
    enum MapPosition {
        case minimized
        case fullscreen
        case hidden
    }
    
    // MARK: - Properties
    weak var categoryDelegate: CategorySelectionDelegate?
    public var hostingController: UIHostingController<HikeTrackerView>?
    public var hikeTracker = HikeTrackingEngine.shared
    private var cancellables = Set<AnyCancellable>()
    public let routePlanner = RoutePlanner.shared
    @Published private var mapPosition: MapPosition = .minimized
    @Published var routesForceRefreshID = UUID() // For forcing view refresh
    private var isHiking = false
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
    // Hiking history data
    private var outdoorHikeLogs: [HikeLog] = []
    @Published var hasLoadedHikingHistory: Bool = false
    private var isLoadingHikeHistory: Bool = false
    
    // Active watch workout detection
    @Published var hasActiveWatchWorkout: Bool = false
    @Published var activeWorkoutData: ActiveWatchWorkoutData? = nil
    
    // Message batching for watch communication
    private var lastSyncDataProcessTime = Date(timeIntervalSince1970: 0)
    private var pendingSyncMessages: [[String: Any]] = []
    
    // Route loading cache
    private var lastRouteLoadTime: Date?
    private var lastRouteLoadLocation: CLLocation?
    
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
        view.backgroundColor = UIColor(hex: "#1a1a2e") // Match weather view night gradient for better color harmony
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
        button.setTitle("START HIKE", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 30
        
        // Create gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(hex: "#228B22").cgColor, // Forest green for hiking
            UIColor(hex: "#006400").cgColor  // Dark green
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
        setupHikeTracker()
        
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
        
        // Add observer for hike selection from history
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHikeSelected),
            name: Notification.Name("HikeSelected"),
            object: nil
        )
        
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
    
    // Handle hike selection from history
    @objc private func handleHikeSelected(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let selectedHike = userInfo["selectedHike"] {
            didSelectHike(selectedHike)
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
        
        // Stop watch sync when view disappears
        stopWatchSync()
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
                
                // Load history in background (non-critical, can be deferred)
                Task.detached(priority: .utility) {
                    await MainActor.run {
                        self.loadHikingHistory()
                    }
                }
            }
            hasLoadedInitialData = true
        }
    }
    
    private var hasLoadedInitialData = false
    private var watchSyncTimer: Timer?
    
    /// Starts a periodic sync to the watch pushing trackingStatus using the engine's updateApplicationContext (every 5s)
    private func startWatchSync() {
        // Invalidate any existing timer first
        watchSyncTimer?.invalidate()
        watchSyncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let session = WCSession.default
            guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
            
            // Delegate payload building and reliable sending to the engine (mirrors Run)
            self.hikeTracker.updateApplicationContext()
        }
    }
    
    /// Stops the periodic watch sync
    private func stopWatchSync() {
        watchSyncTimer?.invalidate()
        watchSyncTimer = nil
    }
    
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

    /// Join a watch workout using the active workout data
    public func joinWatchWorkout() {
        guard let activeWorkout = activeWorkoutData else {
            print("⚠️ Cannot join - no active workout data")
            return
        }

        print("📱 Joining hike workout from watch")

        // Present outdoor hike tracker (hiking is outdoor)
        let hikeVC = OutdoorHikeViewController()
        hikeVC.isJoiningExistingWorkout = true
        hikeVC.watchWorkoutStartDate = activeWorkout.startDate

        // Import the workout metrics into the engine
        hikeTracker.importWorkoutFromWatch(
            isIndoorMode: activeWorkout.isIndoor,
            distance: Measurement(value: activeWorkout.distance, unit: UnitLength.meters),
            elapsedTime: activeWorkout.elapsedTime,
            heartRate: activeWorkout.heartRate,
            calories: activeWorkout.calories,
            cadence: activeWorkout.cadence,
            rawData: activeWorkout.rawData,
            startDate: activeWorkout.startDate
        )

        // Present
        hikeVC.modalPresentationStyle = .fullScreen
        present(hikeVC, animated: true)

        // Notify watch and clear UI state
        sendJoinConfirmationToWatch()
        hasActiveWatchWorkout = false
        activeWorkoutData = nil
        objectWillChange.send()
    }

    // Send join confirmation to watch
    private func sendJoinConfirmationToWatch() {
        guard WCSession.default.activationState == .activated else {
            print("⚠️ Cannot send join confirmation - WCSession not activated")
            return
        }

        let joinMessage: [String: Any] = [
            "type": "joinedWorkoutFromPhone",
            "status": "success",
            "timestamp": Date().timeIntervalSince1970,
            "phoneIsJoining": true,
            "phoneState": hikeTracker.hikeState.rawValue,
            "phoneElapsedTime": hikeTracker.elapsedTime,
            "phoneDistance": hikeTracker.distance.value,
            "hasGoodLocationData": hikeTracker.hasGoodLocationData
        ]

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(joinMessage, replyHandler: { reply in
                print("📱 Watch received join confirmation: \(reply)")
                if let status = reply["status"] as? String, status == "received" {
                    self.hikeTracker.watchHasAcknowledgedJoin = true
                }
            }, errorHandler: { error in
                print("⚠️ Error sending join confirmation: \(error.localizedDescription)")
            })
        } else {
            try? WCSession.default.updateApplicationContext(joinMessage)
            print("📱 Sent join confirmation via context update")
        }

        print("📱 Sent join confirmation to watch")
    }

    @ViewBuilder
    public func createActiveWorkoutCardView() -> some View {
        if hasActiveWatchWorkout, let workoutData = activeWorkoutData {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(
                            workoutData.runTypeText,
                            systemImage: workoutData.isIndoor ? "figure.hiking" : "figure.hiking"
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
    
    private func setupHikeTracker() {
        // Initialize the hike tracker and set up the current user
        // Extract user ID from UserModel or use UserIDResolver as fallback
        let userId: String? = CurrentUserService.shared.user.userID ?? UserIDResolver.shared.getBestUserIdForAPI()
        hikeTracker.setCurrentUser(userId)
        
        // Setup background capability
        hikeTracker.setupBackgroundCapabilities()
    }
    
    private func setupHostingController() {
        // Create the hike tracker view with both the view model and hike tracking engine
        let hikeTrackerView = HikeTrackerView(
            viewModel: self,
            hikeTrackingEngine: HikeTrackingEngine.shared,
            categoryDelegate: self.categoryDelegate
        )
        
        // Create the hosting controller with the view
        hostingController = UIHostingController(rootView: hikeTrackerView)
        
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
    
    // Hike tracking - outdoor only
    private var isOutdoorHike = true
    
    // MARK: - Weather Methods

    // Keep the cycleWeather method for backward compatibility but don't use it
    private func cycleWeather() {
        // This method is kept for compatibility but should not be used
        print("Warning: cycleWeather is deprecated, use loadWeatherData() instead")
    }
    
    public func loadWeatherData() async {
        print("📱 ModernHikeTrackerViewController: Starting weather data loading")
        
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
    
    // Add getWeatherIcon method
    private func getWeatherIcon(for condition: WeatherCondition, isNight: Bool) -> String {
        switch condition {
        case .clear: return isNight ? "moon.stars.fill" : "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .partlyCloudy: return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        case .rainy: return isNight ? "cloud.moon.rain.fill" : "cloud.rain.fill"
        case .stormy: return "cloud.bolt.rain.fill"
        case .snowy: return "snow"
        case .foggy: return "cloud.fog.fill"
        case .windy: return "wind"
        case .unknown: return "questionmark"
        }
    }
    
    private func loadHikingHistory() {
        if isLoadingHikeHistory {
            return
        }
        
        isLoadingHikeHistory = true
        
        // Check if we already have cached data
        let cachedLogs: [HikeLog] = []
        if !cachedLogs.isEmpty {
            self.outdoorHikeLogs = cachedLogs
            self.hasLoadedHikingHistory = true
            self.isLoadingHikeHistory = false
            return
        }
        
        // Use background queue for async operations
        DispatchQueue.global(qos: .userInitiated).async {
            let dispatchGroup = DispatchGroup()
            
            // Load outdoor hikes
            dispatchGroup.enter()
            self.getHikingLogs { (hikes, error) in
                defer { dispatchGroup.leave() }
                if let error = error {
                    print("Error fetching outdoor hikes: \(error.localizedDescription)")
                    return
                }
                
                self.outdoorHikeLogs = hikes ?? []
            }
            
           
            
            // Update UI when both are complete
            dispatchGroup.notify(queue: .main) {
                // Cache the data
                // Note: Caching logic can be added here if needed
                
                self.hasLoadedHikingHistory = true
                self.isLoadingHikeHistory = false
            }
        }
    }
    
    // MARK: - Get Hiking Logs
    
    /// Fetches hiking logs from AWS using ActivityService
    /// - Parameter completion: Completion handler with array of HikeLog or error
    func getHikingLogs(completion: @escaping ([HikeLog]?, Error?) -> Void) {
        // Get current user ID
        guard let userId = UserIDResolver.shared.getBestUserIdForAPI(), !userId.isEmpty else {
            print("❌ [ModernHikeTracker] No user ID available")
            completion(nil, NSError(domain: "ModernHikeTracker", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        print("📥 [ModernHikeTracker] Fetching hiking logs for user: \(userId)")
        
        // Fetch all hikes with pagination
        var allHikeLogs: [HikeLog] = []
        
        func fetchPage(nextToken: String?) {
            ActivityService.shared.getHikes(
                userId: userId,
                limit: 50,
                nextToken: nextToken,
                includeRouteUrls: true
            ) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let response):
                    guard let data = response.data else {
                        print("❌ [ModernHikeTracker] No data in response")
                        completion(nil, NSError(domain: "ModernHikeTracker", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"]))
                        return
                    }
                    
                    // Convert AWS activities to HikeLog
                    let pageLogs = data.activities.compactMap { self.convertAWSActivityToHikeLog($0) }
                    allHikeLogs.append(contentsOf: pageLogs)
                    
                    print("📄 [ModernHikeTracker] Fetched page with \(pageLogs.count) hikes (Total: \(allHikeLogs.count))")
                    
                    // Check if there are more pages
                    if data.hasMore, let token = data.nextToken {
                        print("📄 [ModernHikeTracker] Has more pages, fetching next...")
                        fetchPage(nextToken: token)
                    } else {
                        print("✅ [ModernHikeTracker] Fetched all hikes: \(allHikeLogs.count) total")
                        // Sort by date (newest first)
                        let sortedLogs = allHikeLogs.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
                        completion(sortedLogs, nil)
                    }
                    
                case .failure(let error):
                    print("❌ [ModernHikeTracker] Error fetching hikes: \(error.localizedDescription)")
                    completion(nil, error)
                }
            }
        }
        
        // Start fetching from the first page
        fetchPage(nextToken: nil)
    }
    
    // MARK: - Convert AWS Activity to HikeLog
    
    /// Converts an AWSActivity to HikeLog format
    /// - Parameter activity: The AWS activity to convert
    /// - Returns: A HikeLog if conversion is successful, nil otherwise
    private func convertAWSActivityToHikeLog(_ activity: AWSActivity) -> HikeLog? {
        var hikeLog = HikeLog()
        hikeLog.id = activity.id
        
        // Convert date - Parse ISO8601 format
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = dateFormatter.date(from: activity.createdAt) {
            hikeLog.createdAt = date
            // Format date for display
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            hikeLog.createdAtFormatted = displayFormatter.string(from: date)
        } else {
            // Fallback without fractional seconds
            dateFormatter.formatOptions = [.withInternetDateTime]
            if let date = dateFormatter.date(from: activity.createdAt) {
                hikeLog.createdAt = date
                let displayFormatter = DateFormatter()
                displayFormatter.dateStyle = .medium
                displayFormatter.timeStyle = .short
                hikeLog.createdAtFormatted = displayFormatter.string(from: date)
            }
        }
        
        // Format distance (convert meters to miles string)
        let distanceMiles = activity.distance / 1609.34 // Convert meters to miles
        hikeLog.distance = String(format: "%.2f mi", distanceMiles)
        
        // Format duration
        let hours = Int(activity.duration) / 3600
        let minutes = (Int(activity.duration) % 3600) / 60
        let seconds = Int(activity.duration) % 60
        if hours > 0 {
            hikeLog.duration = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            hikeLog.duration = String(format: "%d:%02d", minutes, seconds)
        }
        
        // Calculate pace (minutes per mile)
        let minutesPerMile = activity.duration / 60.0 / max(distanceMiles, 0.0001)
        let paceMin = Int(minutesPerMile)
        let paceSec = Int((minutesPerMile - Double(paceMin)) * 60)
        hikeLog.avgPace = String(format: "%d'%02d\" /mi", paceMin, paceSec)
        
        // Set calories
        hikeLog.caloriesBurned = activity.calories
        
        // Set createdBy
        hikeLog.createdBy = activity.userId
        
        // Handle elevation
        if let elevationGain = activity.elevationGain {
            hikeLog.elevationGain = String(format: "%.0f", elevationGain * 3.28084) // Convert meters to feet
        }
        if let elevationLoss = activity.elevationLoss {
            hikeLog.elevationLoss = String(format: "%.0f", elevationLoss * 3.28084)
        }
        if let elevationGain = activity.elevationGain, let elevationLoss = activity.elevationLoss {
            let netElevation = elevationGain - elevationLoss
            hikeLog.netElevation = String(format: "%.0f", netElevation * 3.28084)
        }
        
        // Parse locationData from activityData JSON string if available
        if let activityDataString = activity.activityData,
           let data = activityDataString.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let locationsArray = json["locationData"] as? [[String: Any]] {
                        hikeLog.locationData = locationsArray
                    }
                    if let coordArray = json["coordinateArray"] as? [[String: Double]] {
                        hikeLog.coordinateArray = coordArray
                    }
                }
            } catch {
                print("⚠️ [ModernHikeTracker] Failed to parse activityData: \(error)")
            }
        }
        
        return hikeLog
    }
    
    // Helper methods for calculating statistics
    func calculateThisWeekDistance() -> Double {
        let calendar = Calendar.current
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            return 0.0
        }
        
        var totalDistanceInMeters: Double = 0.0
        
        // Add outdoor hikes distance
        for hike in outdoorHikeLogs {
            if let date = hike.createdAt, date >= startOfWeek {
                if let distanceString = hike.distance, let distance = Double(distanceString) {
                    // Convert to meters (assuming the stored distance is in km)
                    totalDistanceInMeters += distance * 1000
                }
            }
        }
        
        
        
        return totalDistanceInMeters
    }

    func calculateAveragePace() -> String {
        var paceSum: Double = 0.0
        var paceCount: Int = 0
        
        // Process outdoor hikes
        for hike in outdoorHikeLogs.prefix(10) { // Consider only the most recent 10 hikes
            if let paceString = hike.avgPace {
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
    
    // Continue with more hike-specific methods...
    // (The rest of the file continues with similar pattern - changing Run/Running to Hike/Hiking)
}


// MARK: - Main View Structs

struct HikeTrackerView: View {
    @ObservedObject var viewModel: ModernHikeTrackerViewController
    @State private var showRoutePreview: Bool = false
    @State private var selectedTrailForPreview: Trail? = nil
    @ObservedObject var hikeTrackingEngine: HikeTrackingEngine
    @StateObject private var locationManager = ModernLocationManager.shared
    @StateObject private var routePlanner = RoutePlanner.shared
    @StateObject private var weatherService = WeatherService.shared
    @ObservedObject private var userPreferences = UserPreferences.shared
    @State var locationCity: String = "Loading Location ..."
    var categoryDelegate: CategorySelectionDelegate?
    // State properties
    @State public var selectedHikeType: HikeType = .trail {
        didSet {
            print("🔄 SwiftUI didSet: selectedHikeType changed from \(oldValue.rawValue) to \(selectedHikeType.rawValue)")
            guard oldValue != selectedHikeType else { return }
            hikeTrackingEngine.hikeType = selectedHikeType
            UserDefaults.standard.set(selectedHikeType.rawValue, forKey: "selectedHikeType")
            print("💾 Saved hike type \(selectedHikeType.rawValue) to UserDefaults")
            print("🔄 Updated hikeTrackingEngine.hikeType to \(selectedHikeType.rawValue)")
        }
    }
    @State private var selectedDuration: TimeInterval = 1800 // 30 minutes
    @State private var showingRouteSelection = false
    @State private var showingCategorySelector = false
    @State private var showingSettingsView = false
    @State private var showingHikeTypeInfo = false
    @State private var infoForHikeType: HikeType? = nil
    @State private var showingFindRoutesView = false
    @State private var showHikeTypeSelectionAnimation = false
    @State private var isNightMode: Bool = false
    @State private var routesForceRefreshID = UUID()
    @State public var showHikeHistorySheet = false
    private var hikeTracker: HikeTrackingEngine { hikeTrackingEngine }
    // Keep the same ordering as Run to ensure the saved index maps correctly across trackers
    private let categoryTitles = ["Running", "Gym", "Cycling", "Hiking", "Walking", "Swimming", "Food", "Meditation", "Sports"]
    private let categoryIcons = ["figure.run", "figure.strengthtraining.traditional", "figure.outdoor.cycle", "figure.hiking", "figure.walk", "figure.pool.swim", "fork.knife", "sparkles", "sportscourt"]
    @State private var selectedCategoryIndex: Int = 0
    init(viewModel: ModernHikeTrackerViewController,
         hikeTrackingEngine: HikeTrackingEngine,
         categoryDelegate: CategorySelectionDelegate?,
         initialHasLoadedRoutes: Bool = false,
         initialHikeType: HikeType? = nil) {
        self.viewModel = viewModel
        self.hikeTrackingEngine = hikeTrackingEngine
        self.categoryDelegate = categoryDelegate
//        self._hasLoadedRoutes = State(initialValue: initialHasLoadedRoutes)
        if let initialHikeType = initialHikeType {
            self._selectedHikeType = State(initialValue: initialHikeType)
        } else if let savedTypeString = UserDefaults.standard.string(forKey: "selectedHikeType"),
                  let savedType = HikeType(rawValue: savedTypeString) {
            self._selectedHikeType = State(initialValue: savedType)
        } else {
            self._selectedHikeType = State(initialValue: .trail)
        }
    }
    var body: some View {
        ZStack {
            backgroundView()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection()
                    weatherSection()
                    // Active watch workout card (if available)
                    viewModel.createActiveWorkoutCardView()
                    hikeTypeSelectorSection()
                    recommendedRoutesSection().id(routesForceRefreshID)
                    startHikeButtonSection()
                    quickActionsSection()
                    hikingStatsSection()
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
    // MARK: - Background View
    private func backgroundView() -> some View {
        // Use the exact background color as Run for consistency
        Color(UIColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0))
            .edgesIgnoringSafeArea(.all)
    }
    // MARK: - Header Section
    private func headerSection() -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Hike Tracker")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("Let's go for a hike")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            Spacer()
            HStack {
                Button(action: {
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
            .padding(.horizontal)
            settingsButton()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onAppear {
            let saved = UserDefaults.standard.object(forKey: UserDefaults.selectedCategoryIndexKey) as? Int
            if let saved, saved != selectedCategoryIndex {
                selectedCategoryIndex = saved
            }
        }
    }
    // MARK: - Settings Button
    private func settingsButton() -> some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            showingSettingsView = true
        }) {
            Image(systemName: "gear")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .padding(8)
                .background(Color.gray.opacity(0.3))
                .clipShape(Circle())
        }
        .contentShape(Rectangle())
        .frame(width: 50, height: 50)
        .buttonStyle(PlainButtonStyle())
        .zIndex(100)
    }
    // MARK: - Weather Section
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
                            .foregroundColor(.green)
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
    // MARK: - Weather View Helper
    private func weatherView() -> some View {
        // Exact layout/size parity with Run
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
                hikeWeatherHeader()
                hikeWeatherContent()
                    .padding(.horizontal)
                hikeForecastRow()
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
        // Reuse Run's approach: pick colors based on condition + hour
        let hour = Calendar.current.component(.hour, from: Date())
        let colors = Color.weatherGradient(for: viewModel.weatherCondition, hour: hour)
        return LinearGradient(gradient: Gradient(colors: [colors.0, colors.1]), startPoint: .top, endPoint: .bottom)
    }
    
    // Helper function to determine if it's night time
    private func isNighttime() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour > 18
    }
    private func hikeWeatherHeader() -> some View {
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
    private func hikeWeatherContent() -> some View {
        HStack(spacing: 16) {
            weatherDetailItem(icon: "wind", value: runStyleWindText())
            weatherDetailItem(icon: "drop.fill", value: "\(Int(viewModel.humidity))%")
        }
    }
    private func hikeForecastRow() -> some View {
        HStack(spacing: 10) {
            ForEach(0..<4) { i in
                hikeForecastItem(
                    hour: getHourString(hoursFromNow: i + 1),
                    icon: getForecastIcon(hoursFromNow: i + 1),
                    temp: getForecastTemp(hoursFromNow: i + 1)
                )
            }
        }
        .padding(.horizontal)
    }
    private func hikeForecastItem(hour: String, icon: String, temp: String) -> some View {
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
        // Simple mapping based on current condition
        switch viewModel.weatherCondition {
        case .clear: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .partlyCloudy: return isNightMode ? "cloud.moon.fill" : "cloud.sun.fill"
        case .rainy: return "cloud.rain.fill"
        case .stormy: return "cloud.bolt.rain.fill"
        case .snowy: return "snow"
        case .foggy: return "cloud.fog.fill"
        case .windy: return "wind"
        case .unknown: return "questionmark"
        }
    }
    private func getForecastTemp(hoursFromNow: Int) -> String {
        // Nudge temp slightly for preview
        let delta = Double(hoursFromNow) * 0.5
        let base = viewModel.temperature
        let t = isNightMode ? max(0, base - delta) : base + delta
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
        // Use night check consistent with Run
        let night = isNightMode
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
    // MARK: - Start Hike Button Section
    private func startHikeButtonSection() -> some View {
        VStack {
            HStack {
//                Image(systemName: selectedHikeType.icon)
//                    .font(.system(size: 16))
//                    .foregroundColor(.green)
//                Text(selectedHikeType.rawValue)
//                    .font(.system(size: 16, weight: .medium))
//                    .foregroundColor(.white)
//                Spacer()
            }
            .padding(.bottom, 8)
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                viewModel.startHike()
            }) {
                HStack {
                    Image(systemName: "figure.hiking")
                        .font(.system(size: 18))
                    Text("Start Hike")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            if let route = viewModel.selectedRoute {
                selectedRouteInfoView(route)
            }
        }
        .padding(.horizontal)
    }
    // MARK: - Quick Actions Section
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
                    showHikeHistorySheet = true
                }
            }
        }
        .padding(.horizontal)
        .popover(isPresented: $showHikeHistorySheet, arrowEdge: .top) {
            HikeHistoryPopover()
                .edgesIgnoringSafeArea(.all)
        }
        .sheet(isPresented: $showingFindRoutesView) {
            RouteSelectionView(
                onSelectRoute: { selectedRoute in
                    viewModel.selectedRoute = selectedRoute
                    showingFindRoutesView = false
                },
                onCancel: {
                    showingFindRoutesView = false
                }
            )
        }
    }
    // MARK: - Hiking Stats Section
    private func hikingStatsSection() -> some View {
        Group {
            if viewModel.hasLoadedHikingHistory {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Hiking Activity")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    HStack(spacing: 12) {
                        let thisWeekDistanceMeters = viewModel.calculateThisWeekDistance()
                        let avgPace = viewModel.calculateAveragePace()
                        let formattedDistance = UserPreferences.shared.useMetricSystem ?
                            String(format: "%.1f", thisWeekDistanceMeters / 1000) :
                            String(format: "%.1f", thisWeekDistanceMeters / 1609.34)
                        let distanceUnit = UserPreferences.shared.useMetricSystem ? "km" : "mi"
                        let paceUnit = UserPreferences.shared.useMetricSystem ? "/km" : "/mi"
                        statCard(title: "This Week", value: formattedDistance, unit: distanceUnit, color: .green)
                        statCard(title: "Avg. Pace", value: avgPace, unit: paceUnit, color: .blue)
                    }
                }
            }
        }
    }
    // MARK: - Hike Type Selector
    private func hikeTypeSelectorSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Hike Type")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(HikeType.allCases), id: \.self) { type in
                        hikeTypeButton(type)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    private func hikeTypeButton(_ type: HikeType) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedHikeType = type
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill").foregroundColor(.white)
                Text(type.rawValue)
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(selectedHikeType == type ? Color.green.opacity(0.3) : Color.black.opacity(0.3))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selectedHikeType == type ? Color.green : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    // MARK: - Routes Section
    private func recommendedRoutesSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recommended Routes")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
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
            if !viewModel.hasLoadedRoutes {
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: 0x5AC8FA)))
                        .scaleEffect(1.2)
                    
                    Text("Finding nearby hiking trails...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("This may take a few moments")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
            } else {
                if let route = viewModel.selectedRoute { selectedRouteInfoView(route) }
                routesList()
            }
        }
        .padding(.horizontal)
    }
    private func selectedRouteInfoView(_ route: Route) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 18))
                .foregroundColor(.green)
                .frame(width: 36, height: 36)
                .background(Color.green.opacity(0.2))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(route.name ?? "Unnamed Route")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                HStack(spacing: 12) {
                    // Using Trail.length (miles) for display; convert to km if metric
                    let km = route.distance * 1.60934
                    Text(String(format: "%.2f km", km))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    // Elevation gain is in feet; convert to meters
                    let meters = route.elevation * 0.3048
                    Text(String(format: "%.0f m elevation", meters))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text(getDifficultyText(for: route.difficulty))
                        .font(.system(size: 12))
                        .foregroundColor(getDifficultyColor(for: route.difficulty))
                }
            }
            Spacer()
            Button(action: { viewModel.toggleRouteSelection(route: route) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .padding()
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.1), Color.blue.opacity(0.05)]), startPoint: .leading, endPoint: .trailing)
        )
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.3), lineWidth: 1))
        .padding(.bottom, 8)
    }
    
    // Update the routesList method to match the running implementation exactly
    private func routesList() -> some View {
        // Access the trails array directly from the route planner to ensure freshness
        let trails = Array(RoutePlanner.shared.nearbyTrails)
        
        return Group {
            if trails.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "map")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: 0x5AC8FA).opacity(0.6))
                    
                    Text("No routes found nearby")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(routeEmptyStateGuidance())
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    Button(action: routeEmptyStateAction) {
                        HStack {
                            Image(systemName: routeEmptyStateActionText() == "Open Settings" ? "gear" : "arrow.clockwise")
                            Text(routeEmptyStateActionText())
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
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
                        .cornerRadius(25)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Get the current hike type for display
                let hikeType = hikeTrackingEngine.hikeType
                
                // Sort trails based on relevance to the hike type
                let sortedTrails = trails.sorted { trail1, trail2 in
                    let trail1Score = scoreTrailForHikeType(trail1, hikeType: hikeType)
                    let trail2Score = scoreTrailForHikeType(trail2, hikeType: hikeType)
                    return trail1Score > trail2Score
                }
                
                if sortedTrails.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.hiking")
                            .font(.system(size: 32))
                            .foregroundColor(Color(hex: 0x5AC8FA).opacity(0.6))
                        
                        Text("No suitable routes found for \(hikeType.rawValue)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("Try changing your hike type or check back later for more routes.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 12) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(sortedTrails.prefix(10)) { trail in
                                    createTrailCard(trail: trail, hikeType: hikeType)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Add a text showing how many routes were found for debugging
                        HStack(spacing: 8) {
                            Text("\(sortedTrails.count) routes available")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            // Note about route overlap
                            Text("• Some routes may overlap")
                                .font(.system(size: 12))
                                .foregroundColor(.gray.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    // MARK: - Empty-state helpers (self-contained, no viewModel coupling)
    private func isLocationAuthorizedNow() -> Bool {
        let status = ModernLocationManager.shared.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }
    
    private func routeEmptyStateGuidance() -> String {
        let lm = ModernLocationManager.shared
        if lm.location == nil { return "Location access is required to find nearby trails. Please enable location permissions in Settings." }
        if !isLocationAuthorizedNow() { return "Location permissions are required. Please enable location access in Settings to find nearby trails." }
        return "We couldn't find any hiking trails in your area. This could be due to no trails being available nearby or temporary service issues."
    }
    
    private func routeEmptyStateActionText() -> String {
        let lm = ModernLocationManager.shared
        if lm.location == nil || !isLocationAuthorizedNow() { return "Open Settings" }
        return "Retry"
    }
    
    private func routeEmptyStateAction() {
        let lm = ModernLocationManager.shared
        if lm.location == nil || !isLocationAuthorizedNow() {
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        } else {
            // Retry without referencing viewModel directly; call local loaders
            Task {
                await viewModel.loadWeatherData()
                viewModel.fetchRoutes(forceRefresh: true)
            }
        }
    }

    // Helper function to create trail cards that matches the running implementation
    private func createTrailCard(trail: Trail, hikeType: HikeType) -> some View {
        // Create a Route object from the Trail (matching the running pattern)
        let route = Route(
            id: UUID(uuidString: trail.id) ?? UUID(),
            name: trail.name,
            distance: trail.length * 1.60934, // Convert miles to km
            elevation: trail.elevationGain * 0.3048, // Convert feet to meters
            difficulty: convertDifficulty(trail.difficulty.rawValue)
        )
        
        // Check if this route is currently selected
        let isSelected = viewModel.selectedRoute?.name == route.name
        
        return ZStack {
            // Main card content
            VStack(alignment: .leading, spacing: 8) {
                // Route icon and name with activity type indicator
                HStack {
                    // Display appropriate icon based on hike type
                    Image(systemName: getActivityIcon(for: hikeType))
                        .font(.system(size: 16))
                        .foregroundColor(getActivityColor(for: hikeType))
                    
                    Text(trail.name)
                        .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Show loop indicator if it's a loop trail
                    if trail.coordinates.count > 2 {
                        let coords: [CLLocationCoordinate2D] = trail.coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                        if isLoopTrail(coords) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))
                                .foregroundColor(.blue.opacity(0.7))
                        }
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
                        Image(systemName: getDifficultyIcon(for: convertDifficulty(trail.difficulty.rawValue)))
                            .font(.system(size: 10))
                            .foregroundColor(getDifficultyColor(for: convertDifficulty(trail.difficulty.rawValue)))
                        Text(getDifficultyText(for: convertDifficulty(trail.difficulty.rawValue)))
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
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? categoryAccentColor(selectedCategoryIndex) : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .onTapGesture {
            viewModel.toggleRouteSelection(route: route)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    selectedTrailForPreview = trail
                    showRoutePreview = true
                }
        )
    }

    // Add the supporting methods that match the running implementation
    private func scoreTrailForHikeType(_ trail: Trail, hikeType: HikeType) -> Double {
        // Simple scoring based on hike type preferences
        var score: Double = 0.0
        
        switch hikeType {
        case .trail:
            // Prefer trails with more elevation gain for trail hiking
            score += trail.elevationGain * 0.01
        case .mountain, .nature:
            // Prefer trails with more elevation gain for mountain hiking
            score += trail.elevationGain * 0.02
        case .urban, .other:
            // Prefer shorter, easier trails for urban hiking
            score += (100 - trail.length) * 0.1
            score += (trail.difficulty == .easy ? 10 : 0)
    
        }
        
        return score
    }

    private func convertDifficulty(_ difficulty: String) -> RouteDifficulty {
        switch difficulty.lowercased() {
        case "easy":
            return .easy
        case "moderate":
            return .moderate
        case "difficult", "verydifficult":
            return .difficult
        default:
            return .moderate
        }
    }

    private func getActivityIcon(for hikeType: HikeType) -> String {
        switch hikeType {
        case .trail:
            return "figure.hiking"
        case .mountain:
            return "mountain.2.fill"
        case .urban:
            return "figure.walk"
        case .nature:
            return "leaf.fill"
        case .other:
            return "figure.hiking"
        }
    }

    private func getActivityColor(for hikeType: HikeType) -> Color {
        switch hikeType {
        case .trail:
            return .blue
        case .mountain:
            return .orange
        case .urban:
            return .green
        case .nature:
            return .brown
        case .other:
            return .gray
        }
    }

    private func getDifficultyIcon(for difficulty: RouteDifficulty) -> String {
        switch difficulty {
        case .easy:
            return "figure.walk"
        case .moderate:
            return "figure.hiking"
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

    private func isLoopTrail(_ coordinates: [CLLocationCoordinate2D]) -> Bool {
        guard coordinates.count > 2 else { return false }
        
        let first = coordinates.first!
        let last = coordinates.last!
        
        // Check if start and end are close enough to be considered a loop
        let distance = sqrt(pow(last.latitude - first.latitude, 2) + pow(last.longitude - first.longitude, 2))
        return distance < 0.001 // Very small threshold for coordinates
    }
    // MARK: - Difficulty Helpers
    private func getDifficultyText(for difficulty: Any) -> String {
        if let value = difficulty as? Int {
            switch value { case 0: return "Easy"; case 1: return "Moderate"; case 2: return "Hard"; default: return "Varied" }
        }
        if let value = difficulty as? String { return value.capitalized }
        return "Varied"
    }
    private func getDifficultyColor(for difficulty: Any) -> Color {
        if let value = difficulty as? Int {
            switch value { case 0: return .green; case 1: return .yellow; case 2: return .red; default: return .gray }
        }
        return .gray
    }
    // MARK: - Helper Buttons and Cards
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

// MARK: - Hike Completion Methods
extension ModernHikeTrackerViewController {
    // MARK: - Start & Route Selection
    /// Toggle currently selected route
    func toggleRouteSelection(route: Route) {
        if let current = selectedRoute, current.id == route.id {
            selectedRoute = nil
        } else {
            selectedRoute = route
        }
        objectWillChange.send()
    }

    /// Start a hike using the current selection
    @objc func startHike() {
        let root = hostingController?.rootView as? HikeTrackerView
        let hikeType = root?.selectedHikeType ?? .trail
        print("🚀 Starting hike with type: \(hikeType.rawValue)")
        
        // PERMISSION CHECK: Hiking is always outdoor and requires location, health, and motion
        PermissionsManager.shared.ensureWorkoutPermissions(for: "hiking", isIndoor: false) { success, missingPermissions in
            if !success {
                // Show alert about missing permissions
                let permissionNames = missingPermissions.map { $0.name }.joined(separator: ", ")
                let alert = UIAlertController(
                    title: "Permissions Required",
                    message: "To start your hike, Do. needs: \(permissionNames). Please grant these permissions in Settings.",
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
            
            // All permissions granted - proceed with starting the hike
            self.startTrackingForHikeType(hikeType)
        }
    }

    /// Present the outdoor hike tracker
    public func startTrackingForHikeType(_ hikeType: HikeType) {
        let vc = OutdoorHikeViewController()
        vc.delegate = self
        if let route = self.selectedRoute { vc.preSelectedRoute = route }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }
    
    func didSelectHike(_ hike: Any) {
        // Implementation for handling hike selection
        print("Selected hike: \(hike)")
    }
    
    func outdoorHikeDidComplete(with hikeLog: HikeLog?) {
        print("🏁 Hike completed, showing summary from ModernHikeTrackerViewController")
    }
    
    func outdoorHikeWasCanceled() {
        print("🏁 Hike was canceled, returning to tracker")
    }
}

// MARK: - Hike History Analysis
extension ModernHikeTrackerViewController {
    
    private func populateRecentHikeHistory() {
        // Check if we already have cached data
        let cachedLogs: [HikeLog] = []
        if !cachedLogs.isEmpty {
            print("📊 Using cached hike history")
            analyzeHikeHistory()
            return
        }
        
        // Fetch hike history using existing method
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.getHikingLogs { (hikes, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error fetching hike history for analysis: \(error.localizedDescription)")
                    } else {
                        // Store hikes for analysis
                        if let hikes = hikes {
                            self?.outdoorHikeLogs = hikes
                        }
                        self?.analyzeHikeHistory()
                    }
                }
            }
        }
    }
    
    private func analyzeHikeHistory() {
        let hikeLogs = outdoorHikeLogs
        
        // Filter for recent hikes (last 90 days)
        let calendar = Calendar.current
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        
        let recentHikes = hikeLogs.filter { log in
            guard let createdAt = log.createdAt, createdAt >= ninetyDaysAgo else { return false }
            return true
        }
        
        guard !recentHikes.isEmpty else {
            print("📊 No recent hike history available for analysis")
            return
        }
        
        // Extract valid paces from hike logs
        var validPaces: [Double] = []
        
        for log in recentHikes {
            if let avgPaceString = log.avgPace,
               let distanceString = log.distance,
               let pace = parsePaceString(avgPaceString),
               let distance = parseDistanceString(distanceString),
               distance > 0.5 { // Only hikes longer than 0.5 mile/km
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
                print("📊 Set ideal hike pace from history: \(idealPace) from \(validPaces.count) hikes")
            }
        }
        
        print("📊 Loaded \(validPaces.count) historical hike pace records")
    }
    
    // Helper methods for parsing
    private func parsePaceString(_ paceString: String) -> Double? {
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
    
    private func parseDistanceString(_ distanceString: String) -> Double? {
        // Remove units and convert to Double
        let cleaned = distanceString.replacingOccurrences(of: " km", with: "")
            .replacingOccurrences(of: " mi", with: "")
            .replacingOccurrences(of: " miles", with: "")
        return Double(cleaned)
    }
}

// MARK: - Utility Methods
extension ModernHikeTrackerViewController {
    
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
    
    // MARK: - Settings Observer
    
    private func observePreferencesChanges() {
        // Initialize tracked preference value
        if let savedTypeString = UserDefaults.standard.string(forKey: "selectedHikeType"),
           let savedType = HikeType(rawValue: savedTypeString) {
            previousHikeType = savedType
        }
        
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
    // Track previous preference values to detect actual changes
    private var previousHikeType: HikeType?
    
    @objc private func userPreferencesDidChange() {
        // Check if the actual preference key changed before processing
        let currentHikeTypeString = UserDefaults.standard.string(forKey: "selectedHikeType")
        let currentHikeType = currentHikeTypeString.flatMap { HikeType(rawValue: $0) }
        
        // Only process if the preference actually changed
        guard currentHikeType != previousHikeType else {
            // Not a preference change we care about - ignore
            return
        }
        
        // Update tracked value
        previousHikeType = currentHikeType
        
        // Cancel any existing timer
        preferencesDebounceTimer?.invalidate()
        
        // Create a new timer that will fire after a short delay
        preferencesDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.handlePreferencesChange()
        }
    }
    
    private func handlePreferencesChange() {
        // Check if hike type was changed in user preferences
        if let savedTypeString = UserDefaults.standard.string(forKey: "selectedHikeType"),
           let savedType = HikeType(rawValue: savedTypeString) {
            
            // Only update if the engine's type doesn't match the saved type
            if savedType != self.hikeTracker.hikeType {
                print("📱 User preferences changed: updating hike type from \(self.hikeTracker.hikeType.rawValue) to \(savedType.rawValue)")
                self.hikeTracker.hikeType = savedType
                
                // Use the force update method to update the view with the correct hike type
                forceViewHikeTypeUpdate(savedType)
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
    
    private func forceViewHikeTypeUpdate(_ hikeType: HikeType) {
        // Force view refresh with new hike type
        print("🔄 Force updating view with hike type: \(hikeType.rawValue)")
        self.objectWillChange.send()
    }
    
    public func fetchRoutes(forceRefresh: Bool = false) {
        print("🗺️ Fetching hiking routes...")
        let planner = RoutePlanner.shared
        
        // Always fetch fresh routes when switching categories or if force refresh is requested
        // Don't skip if we have routes - they might be from a different category
        if !forceRefresh && !planner.nearbyTrails.isEmpty {
            // Check if routes are recent (less than 5 minutes old) and location hasn't changed much
            // If so, we can use cached routes, otherwise fetch fresh ones
            if let lastLoadTime = lastRouteLoadTime,
               Date().timeIntervalSince(lastLoadTime) < 300, // Less than 5 minutes
               let currentLocation = locationManager.location {
                // Check if location hasn't changed significantly (within 500m)
                if let cachedLocation = lastRouteLoadLocation,
                   currentLocation.distance(from: cachedLocation) < 500 {
                    print("✓ Using cached routes - \(planner.nearbyTrails.count) routes available (recent & same location)")
                    hasLoadedRoutes = true
                    return
                }
            }
            // Routes exist but are stale or location changed - clear and fetch fresh
            print("🔄 Routes exist but are stale or location changed - fetching fresh routes")
            planner.clearTrails()
        }
        
        if forceRefresh {
            planner.clearTrails()
        }
        
        let performFetch: () -> Void = { [weak self] in
            guard let self = self else { return }
            planner.findHikingTrails(radius: 10000) { success in
                DispatchQueue.main.async {
                    print("🗺️ Fetched hiking routes - success: \(success)")
                    // Notify UI
                    self.hasLoadedRoutes = true
                    
                    // Update cache timestamp and location
                    self.lastRouteLoadTime = Date()
                    self.lastRouteLoadLocation = self.locationManager.location
                    
                    self.routesForceRefreshID = UUID()
                    self.objectWillChange.send()
                    NotificationCenter.default.post(name: NSNotification.Name("RoutesUpdated"), object: nil)
                    
                    // If no trails found, log it for debugging
                    if planner.nearbyTrails.isEmpty {
                        print("⚠️ No hiking trails found in the area")
                    } else {
                        print("✅ Loaded \(planner.nearbyTrails.count) hiking routes")
                    }
                }
            }
        }
        // If location isn't ready yet, retry shortly to avoid 0 results on first load
        if ModernLocationManager.shared.location == nil {
            print("📍 Location not ready, retrying in 1 second...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { performFetch() }
        } else {
            performFetch()
        }
    }
    
    private func checkForActiveWatchWorkouts() {
        // Check for active watch workouts
        print("⌚️ Checking for active watch workouts...")
        if WCSession.default.isReachable {
            let message = ["type": "checkActiveWorkout"]
            WCSession.default.sendMessage(message, replyHandler: { response in
                DispatchQueue.main.async {
                    if let isActive = response["isActive"] as? Bool {
                        self.hasActiveWatchWorkout = isActive
                        print("⌚️ Active watch workout: \(isActive)")
                    }
                }
            }, errorHandler: { error in
                print("⌚️ Error checking watch workout: \(error.localizedDescription)")
            })
        }
    }
    
    private func updateNightMode() {
        // Update night mode based on current time
        let hour = Calendar.current.component(.hour, from: Date())
        let isNight = hour < 6 || hour > 18
        self.isNightMode = isNight
        print("🌙 Night mode updated: \(isNight)")
    }
    
    private func updateLocationName(for location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    self?.locationCity = placemark.locality ?? "Unknown location"
                }
            }
        }
    }
    
    // Helper method to provide better user guidance when no routes are found
    
}

// MARK: - WCSessionDelegate Methods
extension ModernHikeTrackerViewController {
    
    // Required for WCSessionDelegate
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("Watch session became inactive")
    }
    
    // Required for WCSessionDelegate
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
                    // Update heart rate if we have a tracking engine
                    print("Received heart rate from watch: \(heartRate)")
                }
            case "metrics":
                // Handle metrics updates
                if let metrics = userInfo["data"] as? [String: Any] {
                    if let distance = metrics["distance"] as? Double {
                        print("Received distance from watch: \(distance)")
                    }
                    if let heartRate = metrics["heartRate"] as? Double {
                        print("Received heart rate from watch: \(heartRate)")
                    }
                }
            default:
                print("Unhandled user info type: \(type)")
            }
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("Watch session activation error: \(error.localizedDescription)")
        } else {
            print("Watch session activated with state: \(activationState.rawValue)")
        }
    }
}



// Add a stub for fetchNearbyTrails if not present
extension RoutePlanner {
    func fetchNearbyTrails(completion: @escaping ([Trail]) -> Void) {
        // TODO: Implement actual fetching logic
        completion([])
    }
}

// MARK: - Hike History Popover
struct HikeHistoryPopover: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let historyVC = HikeHistoryViewController()
        
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
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            // Handle dismissal if needed
        }
    }
}





