//
//  ModernBikeTrackerViewController.swift
//  Do.
//
//  Created by Mikiyas Meseret on 3/25/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//


//
//  ModernBikeTrackerViewController.swift
//  Do.
//
//  Created by Mikiyas Meseret on 11/6/23.
//  Copyright © 2023 Mikiyas Tadesse. All rights reserved.
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


// Import custom managers from Running directory - these aren't needed as imports since they're in different folders
// Just keeping the reference to the shared instances:
// ModernLocationManager.shared
// RoutePlanner.shared

// MARK: - Main ModernBikeTracker View Controller


// MARK: - Map Position Enum
enum MapPosition {
    case minimized
    case fullscreen
    case hidden
}

// MARK: - Activity Type
enum ActivityType: String {
    case cycling
    case hiking
    case running
    case walking
}

// MARK: - Bike History Delegate Extension
extension ModernBikeTrackerViewController: BikeHistoryDelegate {
    func didSelectBikeRide(_ ride: Any) {
        // Handle when a bike ride is selected from history
        guard let bikeRide = ride as? BikeRideLog else { return }
        
        // Show bike ride details
        // This could navigate to a detail screen or update the current view
        print("Selected bike ride: \(bikeRide.id ?? "unknown")")
        
        // For example, you might want to show the bike detail view controller
        let detailVC = BikeDetailViewController()
        detailVC.configure(with: bikeRide)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}


// Add RunTypeInfoView definition to fix the "Cannot find in scope" error
struct BikeTypeInfoView: View {
    var selectedType: BikeType?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // If a specific bike type is selected, show just that one
                    if let type = selectedType {
                        bikeTypeDetailCard(type)
                    } else {
                        // Otherwise show all bike types
                        Text("Bike Types Guide")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.bottom, 8)
                        
                        Text("Choose the right bike type for your goals and terrain.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 16)
                        
                        // Display all bike types
                        ForEach(BikeType.allCases) { type in
                            bikeTypeDetailCard(type)
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitle(selectedType == nil ? "Bike Types" : selectedType!.rawValue, displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func bikeTypeDetailCard(_ type: BikeType) -> some View {
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
                    Text(type.rawValue)
                        .font(.headline)
                    
                    Text(type.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.vertical, 8)
    }
}

class ModernBikeTrackerViewController:  UIViewController, ObservableObject, CLLocationManagerDelegate, CategorySwitchable, WCSessionDelegate, OutdoorBikeViewControllerDelegate{
    
    // MARK: - Map Position Enum
    enum MapPosition {
        case minimized
        case fullscreen
        case hidden
    }
    
    // MARK: - Properties
    
    weak var categoryDelegate: CategorySelectionDelegate?
    public var hostingController: UIHostingController<BikeTrackerView>?
    public var bikeTracker = BikeTrackingEngine.shared
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
    // Running history data
    private var bikeLogs: [BikeRideLog] = []
    private var indoorRunLogs: [IndoorRunLog] = []
    @Published var hasLoadedBikingHistory: Bool = false
    private var isLoadingRunHistory: Bool = false
    private var runHistoryLoadStartedAt: Date?
    
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
        // Set lighter orange gradient background using DoColorOrange
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = view.bounds
        gradientLayer.colors = [
            UIColor(red: 0.969, green: 0.576, blue: 0.122, alpha: 1.0).cgColor, // Lighter DoColorOrange (0xF7931F)
            UIColor(red: 0.976, green: 0.676, blue: 0.222, alpha: 1.0).cgColor  // Even lighter orange
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(gradientLayer, at: 0)
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
                        self.loadBikeHistory()
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
            bikeTracker.setCurrentUser(userId)
        } else if let userId = UserIDHelper.shared.getCurrentUserID() {
            bikeTracker.setCurrentUser(userId)
        }
        
        // Setup background capability
        bikeTracker.setupBackgroundCapabilities()
    }
    
    private func setupHostingController() {
        // Create the run tracker view with both the view model and run tracking engine
        let runTrackerView = BikeTrackerView(
            viewModel: self,
            bikeTrackingEngine: BikeTrackingEngine.shared,
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
    private var selectedBikeType: BikeType = .outdoorBike
    
    // MARK: - Weather Methods

    // Keep the cycleWeather method for backward compatibility but don't use it
    private func cycleWeather() {
        // This method is kept for compatibility but should not be used
        print("Warning: cycleWeather is deprecated, use loadWeatherData() instead")
    }
    
    public func loadWeatherData() async {
        print("📱 ModernRunTrackerViewController: Starting weather data loading")
        
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
                // Preserve existing weather condition if we have one
                if self.weatherCondition == .unknown {
                    self.weatherCondition = .clear // Default to clear instead of unknown
                }
                self.weatherDataLoaded = true
                if self.weatherIconName.isEmpty {
                    self.weatherIconName = "location.slash"
                }
            }
        }
    }
    
    
    private func loadBikeHistory() {
        // Prevent overlapping requests, but allow retry if a previous attempt appears stuck (> 8s)
        if isLoadingRunHistory {
            if let started = runHistoryLoadStartedAt, Date().timeIntervalSince(started) > 8 {
                print("⚠️ loadBikeHistory: previous attempt timed out, resetting flag…")
                isLoadingRunHistory = false
            } else {
                print("⚠️ Already loading bikes, skipping request")
                return
            }
        }
        
        isLoadingRunHistory = true
        runHistoryLoadStartedAt = Date()
        
        // Check if we already have cached data
        if ![].isEmpty {
            print("📥 Using cached bike history - \([].count) rides")
            self.bikeLogs = []
            self.bikeLogs = self.bikeLogs.sorted(by: { $0.createdAt ?? Date.distantPast > $1.createdAt ?? Date.distantPast })
            self.hasLoadedBikingHistory = true
            self.isLoadingRunHistory = false
            runHistoryLoadStartedAt = nil
            return
        }
        
        print("📥 No cache available - loading from AWS...")
        
        // Use AWS API instead of outdated Parse methods
        guard let userId = UserIDHelper.shared.getCurrentUserID(), !userId.isEmpty else {
            print("❌ No user ID available for loading bike history")
            self.isLoadingRunHistory = false
            self.runHistoryLoadStartedAt = nil
            return
        }
        
        // Fetch all bikes from AWS
        var allBikeLogs: [BikeRideLog] = []
        
        func fetchPage(nextToken: String?) {
            ActivityService.shared.getBikes(
                userId: userId,
                limit: 100,
                nextToken: nextToken,
                includeRouteUrls: true
            ) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let response):
                    guard let data = response.data else {
                        print("⚠️ No data in response")
                        DispatchQueue.main.async {
                            // Update UI with what we have
                            self.bikeLogs = allBikeLogs.sorted(by: { $0.createdAt ?? Date.distantPast > $1.createdAt ?? Date.distantPast })
                            self.hasLoadedBikingHistory = true
                            self.isLoadingRunHistory = false
                            self.runHistoryLoadStartedAt = nil
                        }
                        return
                    }
                    
                    // Convert activities from this page
                    let pageLogs = data.activities.compactMap { self.convertAWSActivityToBikeLog($0) }
                    allBikeLogs.append(contentsOf: pageLogs)
                    
                    print("📄 Fetched page with \(pageLogs.count) bikes (Total: \(allBikeLogs.count))")
                    
                    // Check if there are more pages
                    if data.hasMore, let token = data.nextToken {
                        print("📄 Has more pages, fetching next...")
                        fetchPage(nextToken: token)
                    } else {
                        print("✅ Fetched all bikes: \(allBikeLogs.count) total")
                        
                        // Update UI on main thread
                        DispatchQueue.main.async {
                            self.bikeLogs = allBikeLogs.sorted(by: { $0.createdAt ?? Date.distantPast > $1.createdAt ?? Date.distantPast })
                            self.hasLoadedBikingHistory = true
                            self.isLoadingRunHistory = false
                            self.runHistoryLoadStartedAt = nil
                        }
                    }
                    
                case .failure(let error):
                    print("❌ Error fetching bikes from AWS: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        // Still update UI with what we have (if any)
                        if !allBikeLogs.isEmpty {
                            self.bikeLogs = allBikeLogs.sorted(by: { $0.createdAt ?? Date.distantPast > $1.createdAt ?? Date.distantPast })
                        }
                        self.hasLoadedBikingHistory = true
                        self.isLoadingRunHistory = false
                        self.runHistoryLoadStartedAt = nil
                    }
                }
            }
        }
        
        // Start fetching from the first page
        fetchPage(nextToken: nil)
    }
    
    // Helper method to convert AWS activity to BikeRideLog
    // Using the same conversion logic as BikeHistoryViewController
    private func convertAWSActivityToBikeLog(_ activity: AWSActivity) -> BikeRideLog? {
        var bikeLog = BikeRideLog()
        
        bikeLog.id = activity.id
        
        // Convert date - Parse ISO8601 format
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = dateFormatter.date(from: activity.createdAt) {
            bikeLog.createdAt = date
        } else {
            // Fallback without fractional seconds
            dateFormatter.formatOptions = [.withInternetDateTime]
            bikeLog.createdAt = dateFormatter.date(from: activity.createdAt)
        }
        
        // Format distance (convert meters to miles, then to string)
        let distanceMiles = activity.distance / 1609.34
        bikeLog.distance = String(format: "%.2f mi", distanceMiles)
        
        // Format duration
        let hours = Int(activity.duration) / 3600
        let minutes = (Int(activity.duration) % 3600) / 60
        let seconds = Int(activity.duration) % 60
        if hours > 0 {
            bikeLog.duration = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            bikeLog.duration = String(format: "%d:%02d", minutes, seconds)
        }
        
        // Calculate average speed (mph)
        let hoursDecimal = activity.duration / 3600.0
        let avgSpeed = hoursDecimal > 0 ? distanceMiles / hoursDecimal : 0
        bikeLog.avgSpeed = avgSpeed
        
        // Set calories (Double, not Int)
        bikeLog.caloriesBurned = activity.calories
        
        // Set heart rate
        bikeLog.avgHeartRate = activity.avgHeartRate
        
        // Handle elevation
        if let elevationGain = activity.elevationGain {
            bikeLog.elevationGain = String(format: "%.0f", elevationGain * 3.28084) // Convert meters to feet
        }
        
        // Store S3 route data URL if available
        if let routeDataUrl = activity.routeDataUrl {
            bikeLog.routeDataUrl = routeDataUrl
        }
        
        // Parse locationData from activityData JSON string if available (legacy format)
        if let activityDataString = activity.activityData,
           let data = activityDataString.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Extract location data
                    if let locationsArray = json["locationData"] as? [[String: Any]] {
                        bikeLog.locationData = locationsArray
                    }
                    
                    // Extract bike type
                    if let bikeType = json["bikeType"] as? String {
                        bikeLog.bikeType = bikeType
                    }
                    
                    // Extract weather data
                    if let weather = json["weather"] as? String {
                        bikeLog.weather = weather
                    }
                    if let temperature = json["temperature"] as? Double {
                        bikeLog.temperature = temperature
                    }
                }
            } catch {
                print("⚠️ Failed to parse activityData for bike log: \(error)")
            }
        }
        
        return bikeLog
    }
    
    // Helper methods for calculating statistics
    func calculateThisWeekDistance() -> Double {
        let calendar = Calendar.current
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            return 0.0
        }
        
        var totalDistanceMeters: Double = 0.0
        
        // Add outdoor bike distance
        for bike in bikeLogs {
            if let date = bike.createdAt, date >= startOfWeek {
                if let distanceString = bike.distance {
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
        for run in bikeLogs.prefix(10) { // Consider only the most recent 10 runs
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
    private var lastRouteLoadLocation: CLLocation?
    private var retryCount = 0
    private let maxRetries = 3
    private var isFetchingRoutes = false // Flag to prevent concurrent fetches
    
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
    
    @MainActor
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
            // Ensure we have a location before fetching
            if locationManager.location == nil {
                print("📍 Location not ready yet, waiting 1 second before fetching routes...")
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
            }
            
            // Use the bike-specific find method (now uses unified findTrailsForActivity)
            routePlanner.findBikeFriendlyTrails(radius: 10000) { [weak self] success in
                guard let self = self else { return }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    // Mark routes as loaded first
                    self.hasLoadedRoutes = true
                    
                    // Update cache timestamp and location
                    self.lastRouteLoadTime = Date()
                    self.lastRouteLoadLocation = self.locationManager.location
                    
                    // Log the result
                    let trailCount = routePlanner.nearbyTrails.count
                    if trailCount > 0 {
                        print("✅ Successfully loaded \(trailCount) bike routes")
                    } else {
                        print("⚠️ No bike routes found (success: \(success))")
                    }
                    
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
    
    // Helper function for scoring trails based on bike type
    public func scoreTrailForBikeType(_ trail: Trail, bikeType: BikeType) -> Int {
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
            if bikeType == .trailBike && (trail.name.contains("Trail") || trail.name.contains("Mountain")) {
                score += 5
            } else if bikeType == .outdoorBike && (trail.name.contains("Park") || trail.name.contains("Path")) {
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
            switch bikeType {
            case .trailBike:
                // Trail runs prefer hiking trails, but also like running and biking trails
                if trailTypeString.contains("hik") { score += 8 }
                else if trailTypeString.contains("run") { score += 6 }
                else if trailTypeString.contains("bik") || trailTypeString.contains("cycle") { score += 3 }
                
                // Trail runs prefer more difficult trails
                if trail.difficulty == .moderate { score += 4 }
                else if trail.difficulty == .difficult || trail.difficulty == .veryDifficult { score += 6 }
                
            case .outdoorBike:
                // Regular runs prefer running trails, but also like walking and biking trails
                if trailTypeString.contains("run") || trailTypeString.contains("track") { score += 8 }
                else if trailTypeString.contains("walk") || trailTypeString.contains("path") { score += 6 }
                else if trailTypeString.contains("bik") || trailTypeString.contains("cycle") { score += 4 }
                else if trailTypeString.contains("hik") { score += 3 }
                
                // Regular runs prefer moderate difficulty
                if trail.difficulty == .moderate { score += 5 }
                else if trail.difficulty == .easy { score += 3 }
                
            case .casualBike:
                // Recovery runs prefer easier, flatter trails
                if trailTypeString.contains("walk") { score += 8 }
                else if trailTypeString.contains("run") { score += 5 }
                
                // Recovery runs strongly prefer easier trails
                if trail.difficulty == .easy { score += 7 }
                else if trail.difficulty == .moderate { score += 2 }
                
            case .roadBike:
                // Interval training prefers flat, consistent surfaces
                if trailTypeString.contains("run") || trailTypeString.contains("track") { score += 10 }
                else if trailTypeString.contains("walk") { score += 5 }
                
                // Prefer easier or moderate trails for consistent pacing
                if trail.difficulty == .easy { score += 6 }
                else if trail.difficulty == .moderate { score += 4 }
                
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
        let selectedBikeType = getSelectedRunType()
        print("🚀 Starting bike with selected bike type: \(selectedBikeType.rawValue)")
        
        // PERMISSION CHECK: Ensure all required permissions before starting workout
        // All bike types are outdoor for now (no stationary bike type exists)
        let isIndoor = false
        PermissionsManager.shared.ensureWorkoutPermissions(for: "cycling", isIndoor: isIndoor) { success, missingPermissions in
            if !success {
                // Show alert about missing permissions
                let permissionNames = missingPermissions.map { $0.name }.joined(separator: ", ")
                let alert = UIAlertController(
                    title: "Permissions Required",
                    message: "To start your \(isIndoor ? "indoor" : "outdoor") bike ride, Do. needs: \(permissionNames). Please grant these permissions in Settings.",
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
            
            // All permissions granted - proceed with starting the bike ride
            self.continueStartingBike(with: selectedBikeType)
        }
    }
    
    /// Continue starting the bike ride after permissions are confirmed
    private func continueStartingBike(with selectedBikeType: BikeType) {
        print("✅ Permissions verified, continuing with bike start")
        
        // Double-check engine state
        if bikeTracker.bikeType != selectedBikeType {
            print("⚠️ Engine bike type mismatch detected, fixing...")
            bikeTracker.bikeType = selectedBikeType
        }
        print("✅ Engine bike type: \(bikeTracker.bikeType.rawValue)")
        
        // Double-check UI state
        if let hostingController = self.hostingController,
           let rootView = hostingController.rootView as? BikeTrackerView {
            if rootView.selectedBikeType != selectedBikeType {
                print("⚠️ UI run type mismatch detected, fixing...")
                setSelectedBikeType(selectedBikeType)
            }
            print("✅ View run type: \(rootView.selectedBikeType.rawValue)")
        }
        
        // Ensure UserDefaults is consistent
        let savedType = UserDefaults.standard.string(forKey: "selectedBikeType")
        if savedType != selectedBikeType.rawValue {
            print("⚠️ UserDefaults run type mismatch detected, fixing...")
            UserDefaults.standard.set(selectedBikeType.rawValue, forKey: "selectedBikeType")
        }
        
        // Log the final confirmed run type
        print("✅ CONFIRMED: Starting \(selectedBikeType.rawValue) run")
        
        // Handle route selection for non-treadmill runs
      if let selectedRoute = self.selectedRoute {
            print("📍 Selected route for run: \(selectedRoute.name ?? "Unnamed")")
            let routeIdString = selectedRoute.id.uuidString
            UserDefaults.standard.set(routeIdString, forKey: "lastSelectedRouteId")
        } else {
            print("ℹ️ No route selected for this run")
        }
        
        // Present the appropriate tracking view controller based on run type
        startTrackingForBikeType(selectedBikeType)
    }
    
    /// Presents the appropriate tracking view controller based on bike type
    public func startTrackingForBikeType(_ bikeType: BikeType) {
        
        // Do a final validation of the bike type to ensure consistency
        // For all outdoor bike types
        print("🌳 Starting bike tracking of type: \(bikeType.rawValue)")
        
        let outdoorBikeVC = OutdoorBikeViewController()
        outdoorBikeVC.bikeType = bikeType  // Set the bike type for outdoor rides
        outdoorBikeVC.delegate = self    // Set the delegate
        
        // If we have a selected route, pass it to the outdoor bike view controller
        if let selectedRoute = self.selectedRoute {
            print("📍 Starting bike ride with selected route: \(selectedRoute.name ?? "Unnamed")")
            outdoorBikeVC.preSelectedRoute = selectedRoute
        } else {
            print("ℹ️ No pre-selected route for outdoor bike ride")
        }
        
        outdoorBikeVC.modalPresentationStyle = .fullScreen
        present(outdoorBikeVC, animated: true)
    }
    
    
    func outdoorBikeRideDidComplete(with bikeRideLog: BikeRideLog?) {
            print("🏁 Bike ride completed, showing summary from ModernBikeTrackerViewController")
            
            // Show summary here on the main tracker interface
            if let bikeRideLog = bikeRideLog {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let summaryVC = RunAnalysisViewController()
                    summaryVC.run = bikeRideLog
                    summaryVC.modalPresentationStyle = .fullScreen
                    self.present(summaryVC, animated: true)
                }
            }
        }
        
    func outdoorBikeRideWasCanceled() {
        print("🏁 Bike ride was canceled, returning to tracker")
        // Optionally refresh the UI or do cleanup
        objectWillChange.send()
    }
    
    private func getSelectedRunType() -> BikeType {
        // Collect all possible sources of truth
        var sources: [(String, BikeType)] = []
        
        // Try to get the run type from the SwiftUI view
        if let hostingController = self.hostingController,
           let rootView = hostingController.rootView as? BikeTrackerView {
            let uiRunType = rootView.selectedBikeType
            print("🔍 UI run type: \(uiRunType.rawValue)")
            sources.append(("UI", uiRunType))
        }
        
        // Check UserDefaults
        if let savedTypeString = UserDefaults.standard.string(forKey: "selectedBikeType"),
           let savedType = BikeType(rawValue: savedTypeString) {
            print("🔍 UserDefaults run type: \(savedType.rawValue)")
            sources.append(("UserDefaults", savedType))
        }
        
        // Check engine
        let engineType = bikeTracker.bikeType
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
            UserDefaults.standard.set(uiSource.1.rawValue, forKey: "selectedBikeType")
            
            // Update engine if different
            if engineType != uiSource.1 {
                print("🔄 Updating engine run type to match UI: \(uiSource.1.rawValue)")
                bikeTracker.bikeType = uiSource.1
            }
            
            return uiSource.1
        }
        
        // 2. UserDefaults has second priority
        if let defaultsSource = sources.first(where: { $0.0 == "UserDefaults" }) {
            print("✅ Using UserDefaults run type as source of truth: \(defaultsSource.1.rawValue)")
            
            // Update engine if different
            if engineType != defaultsSource.1 {
                print("🔄 Updating engine run type to match UserDefaults: \(defaultsSource.1.rawValue)")
                bikeTracker.bikeType = defaultsSource.1
            }
            
            return defaultsSource.1
        }
        
        // 3. Engine has lowest priority
        print("✅ Using engine run type as fallback: \(engineType.rawValue)")
        
        // Save to UserDefaults to maintain consistency
        UserDefaults.standard.set(engineType.rawValue, forKey: "selectedBikeType")
        
        return engineType
    }
    
    public func setSelectedBikeType(_ bikeType: BikeType) {
        print("🔄 Setting selected run type to: \(bikeType.rawValue)")
        
        // Save to UserDefaults for consistency
        UserDefaults.standard.set(bikeType.rawValue, forKey: "selectedBikeType")
        
        // Update the engine
        if bikeTracker.bikeType != bikeType {
            print("⚙️ Updating engine run type from \(bikeTracker.bikeType.rawValue) to \(bikeType.rawValue)")
            bikeTracker.bikeType = bikeType
        }
        
        // Use the force update method instead of trying to update the @State property directly
        forceViewBikeTypeUpdate(bikeType)
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
        print("📋 FETCH ROUTES STARTED for run type: \(selectedBikeType)")
        
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
            switch self.selectedBikeType {
            case .trailBike:
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
                
            case .outdoorBike, .trailBike, .mountainBike, .casualBike, .roadBike:
                // For most run types, just use running trails
                performSearch {
                    print("📋 Finding running trails for \(self.selectedBikeType)")
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
        if let savedTypeString = UserDefaults.standard.string(forKey: "selectedBikeType"),
           let savedType = BikeType(rawValue: savedTypeString) {
            
            // Only update if the engine's type doesn't match the saved type
            if savedType != self.bikeTracker.bikeType {
                print("📱 User preferences changed: updating run type from \(self.bikeTracker.bikeType.rawValue) to \(savedType.rawValue)")
                self.bikeTracker.bikeType = savedType
                
                // Use the force update method to update the view with the correct run type
                forceViewBikeTypeUpdate(savedType)
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
        print("🎯 ModernBikeTrackerViewController didSelectCategory called with index: \(index)")
        
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
    public func validateRunType(_ bikeType: BikeType) -> Bool {
        print("🔍 Validating run type: \(bikeType.rawValue)")
      
        
        // Not a treadmill run
        print("🌳 Run type is not treadmill: \(bikeType.rawValue)")
        
        if bikeTracker.bikeType != bikeType {
            print("⚠️ bikeTracker had wrong run type! Setting to \(bikeType.rawValue)")
            bikeTracker.bikeType = bikeType
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
        
        if let outdoorBike = run as? RunLog {
            detailVC.configure(with: outdoorBike)
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
            print("📣 [ViewController] Received RoutesDidChange notification")
            // Get sender information
            if let sender = notification.object {
                print("📣 [ViewController] Notification sent by: \(type(of: sender))")
            }
            
            // Force refresh by changing the ID
            guard let self = self else { return }
            
            // Simple refresh without redundant operations
            DispatchQueue.main.async {
                if !self.hasLoadedRoutes && !self.routePlanner.nearbyTrails.isEmpty {
                    self.hasLoadedRoutes = true
                    print("🔄 [ViewController] Updated hasLoadedRoutes to true after notification")
                }
            }
        }
    }
    
    // Add this method to show bike history using proper SwiftUI methods
    func showBikeHistoryDirectly() {
        // Create the bike history view controller
        let historyVC = BikeHistoryViewController()
        historyVC.delegate = self
        
        // Present as a draggable sheet (popup)
        let navController = UINavigationController(rootViewController: historyVC)
        navController.modalPresentationStyle = .pageSheet
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
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
    private func forceViewBikeTypeUpdate(_ bikeType: BikeType) {
        print("🔨 Forcing view update to run type: \(bikeType.rawValue)")
        
        // Don't try to update the @State property directly, as it might not take effect
        // Instead, recreate the SwiftUI view with the correct run type
        if let hostingController = self.hostingController {
            // Get a reference to the current view
            if let bikeTrackerView = hostingController.rootView as? BikeTrackerView {
                // Create a new RunTrackerView with the same parameters but updated run type
                let newView = BikeTrackerView(
                    viewModel: self,
                    bikeTrackingEngine: self.bikeTracker,
                    categoryDelegate: bikeTrackerView.categoryDelegate,
                    initialHasLoadedRoutes: bikeTrackerView.hasLoadedRoutes,
                    initialBikeType: bikeType // Set the run type explicitly
                )
                
                // Replace the view on the main thread
                DispatchQueue.main.async {
                    hostingController.rootView = newView
                    print("✅ View completely refreshed with run type: \(bikeType.rawValue)")
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
        
        print("📱 Joining bike workout from watch")
        
        // Determine bike type (treat watch-provided indoor as stationary, else outdoor)
        let bikeType: BikeType = .outdoorBike
        
        // Create appropriate VC (we currently support OutdoorBikeViewController for presentation)
        let bikeVC = OutdoorBikeViewController()
        bikeVC.isJoiningExistingWorkout = true
        bikeVC.watchWorkoutStartDate = activeWorkout.startDate
        
        // Import the workout metrics into the engine
        bikeTracker.importWorkoutFromWatch(
            bikeType: bikeType,
            isIndoorMode: activeWorkout.isIndoor,
            distance: Measurement(value: activeWorkout.distance, unit: UnitLength.meters),
            elapsedTime: activeWorkout.elapsedTime,
            heartRate: activeWorkout.heartRate,
            calories: activeWorkout.calories,
            cadence: activeWorkout.cadence,
            rawData: activeWorkout.rawData,
            startDate: activeWorkout.startDate
        )
        
        // Present the tracker screen
        bikeVC.modalPresentationStyle = .fullScreen
        present(bikeVC, animated: true)
        
        // Notify the watch we've joined
        sendJoinConfirmationToWatch()
        
        // Clear prompt state
        hasActiveWatchWorkout = false
        activeWorkoutData = nil
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
            "phoneState": bikeTracker.bikeState.rawValue,
            "phoneElapsedTime": bikeTracker.elapsedTime,
            "phoneDistance": bikeTracker.distance.value,
            "hasGoodLocationData": bikeTracker.hasGoodLocationData,
            "isPrimaryForHeartRate": bikeTracker.isPrimaryForHeartRate,
            "isPrimaryForDistance": bikeTracker.isPrimaryForDistance,
            "isPrimaryForPace": bikeTracker.isPrimaryForPace
        ]
        
        // Send the message
        if WCSession.default.isReachable {
            // Use interactive messaging when watch is reachable
            WCSession.default.sendMessage(joinMessage, replyHandler: { reply in
                print("📱 Watch received join confirmation: \(reply)")
                
                // Update the engine to recognize we've sent the join confirmation
                if let status = reply["status"] as? String, status == "received" {
                    // Mark in the engine that we've sent join confirmation
                    self.bikeTracker.watchHasAcknowledgedJoin = true
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
            messageType == "syncWorkoutData" && bikeTracker.bikeState == .finished {
            print("📱 Ignoring syncWorkoutData - run is already completed")
            return
        }
    
        // CRITICAL FIX: Handle command messages even when OutdoorRunViewController is active
        if let messageType = message["type"] as? String {
            if messageType == "outdoorRunStateChange" || messageType == "indoorRunStateChange" {
                print("📱 ModernRunTrackerViewController: Processing \(messageType) command message")
                // Forward command messages to RunTrackingEngine regardless of active view controller
                bikeTracker.session(WCSession.default, didReceiveMessage: message, replyHandler: { response in
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
                if bikeTracker.bikeState != .notStarted {
                    print("📱 ModernRunTrackerViewController: Forwarding syncWorkoutData to RunTrackingEngine (OutdoorRunViewController active)")
                    bikeTracker.processWatchMessage(message)
                } else {
                    print("📱 ModernRunTrackerViewController: Skipping syncWorkoutData processing - OutdoorRunViewController is active but no run started")
                }
                return
            }
        }

        // Also check if RunTrackingEngine is in an active outdoor run state for syncWorkoutData only
        if bikeTracker.bikeState != .notStarted && !bikeTracker.isIndoorMode {
            if let messageType = message["type"] as? String, messageType == "syncWorkoutData" {
                // **CHANGED: Always forward to RunTrackingEngine for sync instead of skipping**
                print("📱 ModernRunTrackerViewController: Forwarding syncWorkoutData to RunTrackingEngine (Active outdoor run)")
                bikeTracker.processWatchMessage(message)
                return
            }
        }
        
        // Track whether we're already joined to a workout
        let alreadyJoined = bikeTracker.bikeState != .notStarted
        
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
                bikeTracker.processWatchMessage(message)
                
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
            bikeTracker.processWatchMessage(nextMessage)
            
            processCount += 1
        }
        
        // If we still have more messages, log the count but keep them for next batch
        if !pendingSyncMessages.isEmpty && pendingSyncMessages.count > 5 {
            print("📱 Still have \(pendingSyncMessages.count) pending sync messages in queue")
        }
    }
}

// MARK: - Main SwiftUI View

// Speed Zone enum definition
enum SpeedZone {
    case tooSlow
    case optimal
    case tooFast
}

// Define RideType enum
enum RideType: String, CaseIterable, Identifiable {
    case roadBike
    case mountainBike
    case gravelBike
    case stationaryBike
    case commute
    
    var id: String { self.rawValue }
}

// MARK: - App Theme
enum AppTheme: String, CaseIterable {
    case dark = "Dark"
    case mountain = "Mountain"
    case energy = "Energy"
    
    func backgroundGradient(bikeTracker: BikeTrackingEngine) -> LinearGradient {
        if !bikeTracker.isPaused {
            // Gradient for when a ride is in progress - darker gradients
            return LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(UIColor(red: 0.05, green: 0.1, blue: 0.15, alpha: 1.0))]),
                startPoint: .top,
                endPoint: .bottom
            )
        } else if bikeTracker.isPaused {
            // Gradient for when a ride is paused - warmer tones
            return LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(UIColor(red: 0.15, green: 0.1, blue: 0.05, alpha: 1.0))]),
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            // Gradient for pre-ride screen - using a solid color with slight gradient
            return LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.black.opacity(0.95)]),
                startPoint: .top,
                endPoint: .center
            )
        }
    }
}

// MARK: - Trail Type


struct BikeTrackerView: View {
    @ObservedObject var viewModel: ModernBikeTrackerViewController
    @State private var showRoutePreview: Bool = false
    @State private var selectedTrailForPreview: Trail? = nil
    @ObservedObject var bikeTrackingEngine: BikeTrackingEngine
    @StateObject private var locationManager = ModernLocationManager.shared
    @StateObject private var routePlanner = RoutePlanner.shared // Make sure this is properly initialized
    @StateObject private var weatherService = WeatherService.shared
    @ObservedObject private var userPreferences = UserPreferences.shared
    @State var locationCity: String = "Loading Location ..."
    var categoryDelegate: CategorySelectionDelegate?
    // State properties
    @State public var selectedBikeType: BikeType = .outdoorBike {
        didSet {
            
            // Skip processing if it's the same run type (even though didSet shouldn't be called in this case)
            guard oldValue != selectedBikeType else {
                print("✅ SwiftUI didSet: No change in run type, staying with: \(selectedBikeType.rawValue)")
                return
            }
            
            // When the run type changes in the UI through explicit user selection,
            // update the engine and validate the selection
            bikeTrackingEngine.bikeType = selectedBikeType
            print("✅ Set selectedBikeType to \(selectedBikeType.rawValue)")
            
            // Save to UserDefaults
            UserDefaults.standard.set(selectedBikeType.rawValue, forKey: "selectedBikeType")
            print("💾 Saved run type \(selectedBikeType.rawValue) to UserDefaults")
            
            // Update the engine
            print("🔄 Updated runTrackingEngine.bikeType to \(selectedBikeType.rawValue)")
            
         
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
    @State private var infoForRunType: BikeType? = nil // The run type to show info for
    @State private var showingFindRoutesView = false // For showing find routes view
    @State private var showRunTypeSelectionAnimation = false // Animation state
    @State private var isNightMode: Bool = false // Added missing isNightMode property
    @State private var routesForceRefreshID = UUID() // Used to force view refresh
    @State public var showRunHistorySheet = false
    
    // Reference to parent controller's bikeTracker
    private var bikeTracker: BikeTrackingEngine { bikeTrackingEngine }
    
    // Category data
    private let categoryTitles = ["Running", "Gym", "Cycling", "Hiking", "Walking", "Swimming", "Food", "Meditation", "Sports"]
    private let categoryIcons = ["figure.run", "figure.strengthtraining.traditional", "figure.outdoor.cycle", "figure.hiking", "figure.walk", "figure.pool.swim", "fork.knife", "sparkles", "sportscourt"]
    @State private var selectedCategoryIndex: Int = 2 // Track the selected category - default to Cycling (index 2)
    
    // Initialize with external hasLoadedRoutes state
    init(viewModel: ModernBikeTrackerViewController,
         bikeTrackingEngine: BikeTrackingEngine,
         categoryDelegate: CategorySelectionDelegate?,
         initialHasLoadedRoutes: Bool = false,
         initialBikeType: BikeType? = nil) {
        self.viewModel = viewModel
        self.bikeTrackingEngine = bikeTrackingEngine
        self.categoryDelegate = categoryDelegate
        self._hasLoadedRoutes = State(initialValue: initialHasLoadedRoutes)
        
        // Set the initial bike type if provided
        if let initialBikeType = initialBikeType {
            self._selectedBikeType = State(initialValue: initialBikeType)
            print("🏁 BikeTrackerView initialized with explicit bike type: \(initialBikeType.rawValue)")
        } else {
            // Otherwise load from preferences or default to outdoorBike
            if let savedTypeString = UserDefaults.standard.string(forKey: "selectedBikeType"),
               let savedType = BikeType(rawValue: savedTypeString) {
                self._selectedBikeType = State(initialValue: savedType)
                print("🏁 BikeTrackerView initialized with saved bike type: \(savedType.rawValue)")
            } else {
                self._selectedBikeType = State(initialValue: .outdoorBike)
                print("🏁 BikeTrackerView initialized with default bike type: outdoorBike")
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
                    
                    // Bike Type Selector
                    bikeTypeSelectorSection()
                    
                    // Nearby routes section - explicitly add .id to force refresh
                    recommendedRoutesSection()
                        .id(routesForceRefreshID)  // Force refresh when this ID changes
                    
                    // Start bike button
                    startBikeButtonSection()
                    
                    // Quick actions
                    quickActionsSection()
                    
                    // Biking stats section
                    bikingStatsSection()
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
                        // Use a delay before triggering the navigation to ensure sheet is fully dismissed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // Call the delegate directly for navigation
                            if let delegate = viewModel.categoryDelegate {
                                print("🎯 Calling delegate didSelectCategory with index: \(newIndex)")
                                delegate.didSelectCategory(at: newIndex)
                            } else {
                                print("⚠️ No category delegate available")
                            }
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
            BikeTypeInfoView(selectedType: infoForRunType)
        }
        .sheet(isPresented: $showingFindRoutesView) {
            FindRoutesView()
        }
        .onAppear {
            // First request location access if needed
            let status = CLLocationManager.authorizationStatus()
            if status == .notDetermined {
                print("📱 Requesting location authorization in FindRoutesView...")
                locationManager.manager.requestWhenInUseAuthorization()
            }
            
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
    }
    
    // Add method to initialize the selected category
    private func initializeSelectedCategory() {
        print("🔄 Initializing selected category in BikeTrackerView")
        
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
        // Modern biking background: distinct blue gradient (different from running)
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: 0x081A2A), // deep navy
                Color(hex: 0x0B3A66)  // cobalt/teal blue
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .edgesIgnoringSafeArea(.all)
    }
    
    private func headerSection() -> some View {
        HStack(spacing: 16) { // Add spacing between elements
            VStack(alignment: .leading, spacing: 8) {
                Text("Bike Tracker")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Ready to bike?")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Add the category and settings buttons here
            HStack {
                // Category Button
                categoryButton()
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
        print("🎯 BikeTrackerView: handleCategorySelection called with index: \(index)")
        
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
            if weatherDataLoaded {
                weatherView()
                    .padding(.horizontal)
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
                        loadWeatherData()
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
                        if !weatherDataLoaded {
                            print("Weather loading timed out, forcing weather display")
                            weatherDataLoaded = true
                        }
                    }
                }
            }
        }
    }
    
    private func bikeTypeSelectorSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Bike Type")
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
                        let runTypes = [BikeType.outdoorBike, .casualBike, .mountainBike, .roadBike, .trailBike]

                        ForEach(runTypes, id: \.self) { type in
                            bikeTypeButton(type)
                                .offset(y: showRunTypeSelectionAnimation && selectedBikeType == type ? -10 : 0)
                                .scaleEffect(showRunTypeSelectionAnimation && selectedBikeType == type ? 1.05 : 1.0)
                                .shadow(color: Color.blue.opacity(showRunTypeSelectionAnimation && selectedBikeType == type ? 0.5 : 0),
                                        radius: showRunTypeSelectionAnimation && selectedBikeType == type ? 8 : 0,
                                        x: 0, y: 2)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedBikeType)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showRunTypeSelectionAnimation)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16) // more breathing room for offset + scale
                }
            }
            .clipped(antialiased: false) // 👈 allow overflow
            .contentShape(Rectangle()) // 👈 allow gestures on overflowed area

            
            // Display selected bike type description
            if showRunTypeSelectionAnimation {
                Text(selectedBikeType.description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .fixedSize(horizontal: false, vertical: true) // Allow text to expand vertically
                    .transition(.opacity)
                    .animation(.easeIn, value: selectedBikeType)
                
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
                let bikeType = selectedBikeType
                
                let sortedTrails = trails.sorted { trail1, trail2 in
                                    let trail1Score = viewModel.scoreTrailForBikeType(trail1, bikeType: bikeType)
                let trail2Score = viewModel.scoreTrailForBikeType(trail2, bikeType: bikeType)
                    return trail1Score > trail2Score
                }
                
                if sortedTrails.isEmpty {
                    Text("No suitable routes found for \(bikeType.rawValue)")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Use the ID modifier with routesForceRefreshID to force refresh
                            ForEach(sortedTrails.prefix(10)) { trail in
                                createTrailCard(trail: trail, bikeType: bikeType)
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
    
    // Helper function to create trail cards that doesn't cause SwiftUI build errors
    private func createTrailCard(trail: Trail, bikeType: BikeType) -> some View {
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
    
    private func startBikeButtonSection() -> some View {
        VStack {
            // Showing the selected bike type
            HStack {
                Image(systemName: selectedBikeType.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                Text(selectedBikeType.rawValue)
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
                    Image(systemName: "figure.outdoor.cycle")
                        .font(.system(size: 18))
                    Text("Start Bike")
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
                    // Show bike history
                    viewModel.showBikeHistoryDirectly()
                }
                
//                actionButton(iconName: "globe", label: "Explorer Map") {
//                    // Show the World Explorer Map
//                    showWorldExplorerMap()
//                }
            }
        }
        .padding(.horizontal)
        .popover(isPresented: $showRunHistorySheet, arrowEdge: .top) {
            BikeHistoryPopover()
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
    
    private func bikingStatsSection() -> some View {
        Group {
            // Always show stats section, but update when data becomes available
            VStack(alignment: .leading, spacing: 16) {
                Text("Your Biking Activity")
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
                    if !viewModel.hasLoadedBikingHistory {
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
            .id("bike-stats-\(viewModel.routesForceRefreshID)")
        }
    }
    
    // Helper function for backward compatibility
    private func bikingStatsSectionOld() -> some View {
        Group {
            if viewModel.hasLoadedBikingHistory {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Biking Activity")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        // Calculate values outside of the view hierarchy
                        let thisWeekDistanceMeters = viewModel.calculateThisWeekDistance()
                        let avgPace = viewModel.calculateAveragePace()
                        
                        // Format distance based on user preferences
                        let formattedDistance = UserPreferences.shared.useMetricSystem ?
                            String(format: "%.1f", thisWeekDistanceMeters / 1000) :
                            String(format: "%.1f", thisWeekDistanceMeters / 1609.34)
                        
                        // Get units based on user preferences
                        let distanceUnit = UserPreferences.shared.useMetricSystem ? "km" : "mi"
                        let paceUnit = UserPreferences.shared.useMetricSystem ? "/km" : "/mi"
                        
                        // Use the calculated values directly in the view
                        statCard(title: "This Week", value: formattedDistance, unit: distanceUnit, color: .blue)
                        statCard(title: "Avg. Pace", value: avgPace, unit: paceUnit, color: .green)
                    }
                }
                .padding(.horizontal)
            }
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
                Text("No route selected - will track open bike ride")
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
        let bikeType = selectedBikeType
        
        // Skip if already generating route
        if routePlanner.isGeneratingRoute {
            print("⚠️ Skipping route fetch: already in progress")
            return
        }
        
        // Log which implementation is being used
        print("📋 Using PRIVATE implementation for run type: \(bikeType)")
        
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
            switch bikeType {
            case .trailBike:
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
                
            case .outdoorBike, .trailBike:
                // For most run types, just use running trails
                performSearch {
                    print("📋 Finding running trails for \(bikeType)")
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
            getWeatherGradient(for: weatherCondition)
                .cornerRadius(22)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                
            // Normal weather animation
            ZStack(alignment: .top) {
                switch weatherCondition {
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
                    ModernFogOverlay(nightMode: isNighttime())
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
            .id("weather-animation-\(weatherCondition.rawValue)")
            .allowsHitTesting(false) // Allow touches to pass through to content
            
            // Content - enhanced with location and forecast (placed on top of animation)
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
            .background(Color.clear) // Transparent background so animation shows through
            .zIndex(1) // Ensure content is above animation
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
                if weatherCondition == .clear {
                    return "sun.max.fill"
                } else {
                    return "cloud.sun.fill"
                }
            }
        case 2:
            if willBeNight {
                return weatherCondition == .rainy ? "cloud.moon.rain.fill" : "cloud.moon.fill"
            } else {
                return weatherCondition == .rainy ? "cloud.rain.fill" :
                       weatherCondition == .cloudy ? "cloud.fill" : "cloud.sun.fill"
            }
        case 3:
            if willBeNight {
                return weatherCondition == .rainy ? "cloud.moon.rain.fill" : "moon.stars.fill"
            } else {
                return weatherCondition == .rainy ? "cloud.heavyrain.fill" :
                       weatherCondition == .cloudy ? "cloud.fill" : "sun.max.fill"
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
        let baseTemp = Int(temperature)
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
                LightningView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .snowy:
                SnowfallView(nightMode: isNighttime())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .foggy:
                CloudOverlay(nightMode: isNight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .cloudy:
                CloudOverlay(nightMode: isNight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .partlyCloudy:
                if isNight {
                    PartlyCloudyNightView()
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
                        PartlyCloudyDayView()
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
                WindyOverlay(nightMode: isNight)
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
                    Text(locationCity)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .id("location_\(locationCity)") // Force redraw when locationCity changes
                }
                
                Spacer()
                
                // Weather icon
                Image(systemName: weatherIconName)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Weather condition and temperature (left-aligned now)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(getWeatherDescription(condition: weatherCondition, isNightMode: isNighttime()))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(formatTemperature(temperature))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
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
                value: formatWindSpeed(windSpeed)
            )
            
            // Humidity
            weatherDetailItem(
                icon: "drop.fill",
                value: "\(Int(humidity))%"
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
    private func loadSavedBikeType() {
        // Load the saved run type from user defaults or other storage
        if let savedRunTypeRawValue = UserDefaults.standard.string(forKey: "selectedBikeType"),
           let savedRunType = BikeType(rawValue: savedRunTypeRawValue) {
            selectedBikeType = savedRunType
            bikeTracker.bikeType = savedRunType
        }
    }
    
    // Add this method to the RunTrackerView to create run type buttons
    private func bikeTypeButton(_ type: BikeType) -> some View {
        let isSelected = selectedBikeType == type
        
        return Button(action: {
            // Trigger haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            selectedBikeTypeChanged(to: type)
        }) {
            VStack(spacing: 12) {
                // Icon
                    Image(systemName: type.icon)
                    .font(.system(size: 24, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .blue : .white)
                    .frame(height: 30)
                
                // Title
                Text(type.rawValue)
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
    
    private func selectedBikeTypeChanged(to type: BikeType) {
        // Animate out the current description
        withAnimation(.easeOut(duration: 0.2)) {
            showRunTypeSelectionAnimation = false
        }
        
        print("🎯 BikeType changed from \(self.selectedBikeType.rawValue) to \(type.rawValue)")
        
        // Change the type
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Update the SwiftUI @State var selectedBikeType
            self.selectedBikeType = type
            print("✅ Set selectedBikeType to \(type.rawValue)")
            
            // Save the selected run type
            UserDefaults.standard.set(type.rawValue, forKey: "selectedBikeType")
            print("💾 Saved run type \(type.rawValue) to UserDefaults")
            
            // Update the run tracking engine
            self.bikeTrackingEngine.bikeType = type
            print("🔄 Updated runTrackingEngine.bikeType to \(type.rawValue)")
            
            // Also ensure the viewModel's bikeTracker is updated
            self.viewModel.bikeTracker.bikeType = type
            
            // CRITICAL: Ensure ViewController's reference and UI are synchronized
            if let rootView = self.viewModel.hostingController?.rootView as? BikeTrackerView {
                if rootView.selectedBikeType != type {
                    DispatchQueue.main.async {
                        // Update via ViewController to ensure state consistency across the app
                        self.viewModel.setSelectedBikeType(type)
                        // Verify the change took effect in both places
                        print("✅ Engine run type: \(self.bikeTrackingEngine.bikeType.rawValue)")
                        print("✅ View run type: \(rootView.selectedBikeType.rawValue)")
                    }
                }
            }
            
            // Now animate in the new description
            withAnimation(.easeIn(duration: 0.3)) {
                self.showRunTypeSelectionAnimation = true
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
    
    // Helper function to score how well a trail matches the selected bike type
    private func scoreTrailForBikeType(_ trail: Trail, bikeType: BikeType) -> Int {
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
                // Default to biking if we can't determine
                activityType = .biking
            }
        } else {
            // Default to biking if trailType is nil
            activityType = .biking
        }
        
        // Determine if the trail is a loop (by checking if first and last coordinates are close)
        let isLoop = trail.coordinates.count > 2 && self.isLoopTrail(trail.coordinates)
        
        // Base score on activity type match
        switch bikeType {
        case .trailBike:
            // Trail bikes prefer biking trails, but also like hiking and running trails
            if activityType == .biking { score += 5 }
            else if activityType == .hiking { score += 3 }
            else if activityType == .running { score += 1 }
            
            // Trail bikes prefer more difficult trails
            if trail.difficulty == .moderate { score += 2 }
            else if trail.difficulty == .difficult || trail.difficulty == .veryDifficult { score += 3 }
            
        case .outdoorBike:
            // Regular bikes prefer biking trails, but also like running and walking trails
            if activityType == .biking { score += 5 }
            else if activityType == .running { score += 3 }
            else if activityType == .walking { score += 2 }
            else if activityType == .hiking { score += 1 }
            
            // Regular bikes prefer moderate difficulty
            if trail.difficulty == .moderate { score += 3 }
            else if trail.difficulty == .easy { score += 2 }
            
        default:
            // Default preference for biking trails
            if activityType == .biking { score += 3 }
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



// MARK: - Bike Tracking Engine



// Placeholder for the StationaryBikeViewController
class StationaryBikeViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Implementation would go here
    }
}

// MARK: - Bike History Popover
struct BikeHistoryPopover: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let historyVC = BikeHistoryViewController()
        
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
