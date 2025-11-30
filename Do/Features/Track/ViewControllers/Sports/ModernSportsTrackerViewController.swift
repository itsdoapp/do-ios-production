//
//  ModernSportsTrackerViewController.swift
//  Do.
//
//  Created by Mikiyas Meseret on 3/26/25.
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

// MARK: - Main ModernSportsTracker View Controller
// Minimum iOS target: 16.0
class ModernSportsTrackerViewController: UIViewController, ObservableObject, CategorySwitchable {
    
    // MARK: - Properties
    private var hostingController: UIHostingController<SportsTrackerView>?
    // SportsTrackingEngine supports iOS 16.0+ (minimum target)
    private var sportsTracker: SportsTrackingEngine {
        return SportsTrackingEngine.shared
    }
    private var cancellables = Set<AnyCancellable>()
    
    // State properties
    @Published var isLoadingLocations = false
    @Published var sportsLocations: [Trail] = []
    @Published var selectedSportType: SportType = .basketball
    @State private var showingLocationSelector = false
    @State private var showingCategorySelector = false
    @State private var selectedCategoryIndex: Int = 8 // Default to Sports (index 8)
    
    // Weather properties for precipitation
    @Published var precipitationChance: Double? = nil
    @Published var precipitationAmount: Double? = nil
    
    weak var categoryDelegate: CategorySelectionDelegate?
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSportsTracker()
        setupHostingController()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: - Setup Methods
    private func setupSportsTracker() {
        // Initialize the sports tracker and set up the current user
        if CurrentUserService.shared.user == nil {
            sportsTracker.setCurrentUser()
        } else {
            sportsTracker.currentUser = CurrentUserService.shared.user
        }
    }
    
    private func setupHostingController() {
        let sportsTrackerView = SportsTrackerView(viewModel: self, sportsTrackingEngine: sportsTracker)
        hostingController = UIHostingController(rootView: sportsTrackerView)
        
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
    
    // MARK: - Public Methods
    public func handleCategorySelection(_ index: Int) {
        categoryDelegate?.didSelectCategory(at: index)
    }
    
    public func startSportsTracking() {
        // Request permissions first
        PermissionsManager.shared.ensureWorkoutPermissions(for: "sports", isIndoor: false) { [weak self] success, missingPermissions in
            guard let self = self else { return }
            
            if !success {
                // Show alert about missing permissions
                let permissionNames = missingPermissions.map { $0.name }.joined(separator: ", ")
                let alert = UIAlertController(
                    title: "Permissions Required",
                    message: "To start sports tracking, Do. needs: \(permissionNames). Please grant these permissions in Settings.",
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
            
            // All permissions granted - proceed with starting sports tracking
            print("✅ Permissions verified, starting sports tracking")
            Task {
                await self.sportsTracker.startTracking(sportType: self.selectedSportType)
                
                // Navigate to outdoor sports tracking view
                await MainActor.run {
                    self.navigateToOutdoorSportsTracking()
                }
            }
        }
    }
    
    private func navigateToOutdoorSportsTracking() {
        // For now, the tracking happens in the background via SportsTrackingEngine
        // A full OutdoorSportsViewController similar to OutdoorRunViewController could be created
        // but that's a large implementation. For now, users can track from watch or see updates via notifications.
        print("✅ Sports tracking started for: \(selectedSportType.rawValue)")
        
        // TODO: Create OutdoorSportsViewController for full UI tracking experience
        // Similar to OutdoorRunViewController with map, metrics, controls, etc.
    }
    
    // MARK: - Sports Locations Finding
    
    public func findNearbySportsLocations() {
        Task {
            await MainActor.run {
                // Start loading
                isLoadingLocations = true
            }
            
            let routePlanner = RoutePlanner.shared
            
            // Create a custom query for sports facilities based on selected sport type
            let query = createSportsQuery(sportType: selectedSportType, radius: 7500)
            
            // Use a custom method to find sports locations
            findSportsLocations(query: query)
            
            // Wait for location data to load (max 10 seconds)
            let startTime = Date()
            while routePlanner.isGeneratingRoute && Date().timeIntervalSince(startTime) < 10 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            await MainActor.run {
                isLoadingLocations = false
                
                // Check if we found any sports locations
                if sportsLocations.isEmpty {
                    print("No sports facilities found or error occurred")
                } else {
                    print("Found \(sportsLocations.count) sports facilities")
                }
            }
        }
    }
    
    private func createSportsQuery(sportType: SportType, radius: Double) -> String {
        guard let userLocation = ModernLocationManager.shared.location?.coordinate else {
            return ""
        }
        
        // Base query components
        var queryComponents = [
            // Common sports facilities
            "leisure=sports_centre",
            "leisure=pitch",
            "leisure=fitness_centre"
        ]
        
        // Add sport-specific components
        switch sportType {
        case .basketball:
            queryComponents.append(contentsOf: [
                "sport=basketball",
                "leisure=pitch AND sport=basketball"
            ])
        case .soccer:
            queryComponents.append(contentsOf: [
                "sport=soccer",
                "sport=football",
                "leisure=pitch AND sport=soccer"
            ])
        case .tennis:
            queryComponents.append(contentsOf: [
                "sport=tennis",
                "leisure=pitch AND sport=tennis"
            ])
        case .golf:
            queryComponents.append(contentsOf: [
                "sport=golf",
                "leisure=pitch AND sport=golf"
            ])
        case .baseball:
            queryComponents.append(contentsOf: [
                "sport=baseball",
                "leisure=pitch AND sport=baseball"
            ])
        case .volleyball:
            queryComponents.append(contentsOf: [
                "sport=volleyball",
                "leisure=pitch AND sport=volleyball"
            ])
        case .kayaking:
            // OSM often uses canoe for kayaking areas; include beach/water access
            queryComponents.append(contentsOf: [
                "sport=canoe",
                "sport=kayak",
                "leisure=slipway"
            ])
        case .surfing:
            queryComponents.append(contentsOf: [
                "sport=surfing",
                "natural=beach"
            ])
        case .paddleboard:
            // Stand up paddling can be tagged as stand_up_paddling or surfing
            queryComponents.append(contentsOf: [
                "sport=stand_up_paddling",
                "sport=surfing",
                "leisure=slipway"
            ])
        default:
            // Add general sports facilities
            queryComponents.append(contentsOf: [
                "sport=multi",
                "leisure=recreation_ground"
            ])
        }
        
        // Construct the full query
        let formattedComponents = queryComponents.map { comp -> String in
            let parts = comp.split(separator: " AND ")
            if parts.count > 1 {
                return "way[\"\(parts[0])\"][\"\(parts[1])\"](around:\(radius),\(userLocation.latitude),\(userLocation.longitude));"
            } else {
                return "way[\"\(comp)\"](around:\(radius),\(userLocation.latitude),\(userLocation.longitude));"
            }
        }.joined(separator: "\n  ")
        
        let query = """
        [out:json];
        (
          // Sport-specific facilities
          \(formattedComponents)
        );
        out body;
        >;
        out skel qt;
        """
        
        return query
    }
    
    private func findSportsLocations(query: String) {
        guard !query.isEmpty else { return }
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://overpass-api.de/api/interpreter?data=" + encodedQuery) else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching sports locations: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("No data received for sports locations")
                    return
                }
                
                // Process the returned data
                self.processSportsLocationData(data)
            }
        }.resume()
    }
    
    private func processSportsLocationData(_ data: Data) {
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(OverpassResponse.self, from: data)
            
            // Process the response data and create Trail objects for sports locations
            print("Received \(response.elements.count) elements from Overpass API")
            
            var locations: [Trail] = []
            
            for element in response.elements {
                guard let tags = element.tags,
                      let lat = element.lat,
                      let lon = element.lon,
                      let name = tags["name"] ?? tags["description"] else { continue }
                
                // Create a basic coordinate
                let coordinate = Coordinate(latitude: lat, longitude: lon)
                
                // Determine the sport type
                let sportType = tags["sport"] ?? "unknown"
                let description = "A \(sportType) facility"
                
                // Create a simple trail object to represent the sports location
                let location = Trail(
                    id: "\(element.id ?? Int.random(in: 1000...9999))",
                    name: name,
                    difficulty: .easy,
                    length: 0, // Not applicable for sports locations
                    elevationGain: 0,
                    rating: 5.0,
                    coordinates: [coordinate],
                    description: description,
                    estimatedDuration: 3600, // Default 1 hour
                    trailType: sportType
                )
                
                locations.append(location)
            }
            
            // Update the locations on the main thread
            DispatchQueue.main.async { [weak self] in
                self?.sportsLocations = locations
            }
            
        } catch {
            print("Error parsing sports location data: \(error)")
        }
    }
}

// MARK: - Main SwiftUI View
// Minimum iOS target: 16.0
struct SportsTrackerView: View {
    @ObservedObject var viewModel: ModernSportsTrackerViewController
    @ObservedObject var sportsTrackingEngine: SportsTrackingEngine
    @StateObject private var locationManager = ModernLocationManager.shared
    @StateObject private var weatherService = WeatherService.shared
    
    // State properties
    @State private var showingCategorySelector = false
    @State private var sportsHistoryStats: (sessions: Int, totalTime: TimeInterval, sportsPlayed: Set<String>) = (0, 0, Set())
    @State private var isLoadingStats = false
    
    // Bind to viewModel properties instead of duplicating state
    private var selectedSportType: SportType { viewModel.selectedSportType }
    private var isLoadingLocations: Bool { viewModel.isLoadingLocations }
    private var sportsLocations: [Trail] { viewModel.sportsLocations }
    
    // Weather data state properties
    @State var weatherDataLoaded = false
    @State var temperature: Double = 0
    @State var humidity: Double = 0
    @State var windSpeed: Double = 0
    @State var weatherCondition: WeatherCondition = .clear
    @State var weatherIconName: String = "sun.max.fill"
    @State var locationCity: String = "Location"
    @State private var selectedCategoryIndex: Int = 8 // Default to Sports (index 8)
    weak var categoryDelegate: CategorySelectionDelegate?
    // Category data
    private let categoryTitles = ["Running", "Gym", "Cycling", "Hiking", "Walking", "Swimming", "Food", "Meditation", "Sports"]
    private let categoryIcons = ["figure.run", "figure.strengthtraining.traditional", "figure.outdoor.cycle", "figure.hiking", "figure.walk", "figure.pool.swim", "fork.knife", "sparkles", "sportscourt"]
    
    var body: some View {
        ZStack {
            // Background with orange/sports-themed gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor(red: 0.15, green: 0.1, blue: 0.05, alpha: 1.0)),
                    Color(UIColor(red: 0.25, green: 0.15, blue: 0.1, alpha: 1.0))
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header section with title and category selector
                    headerSection()
                    
                    // Weather section
                    weatherSection()
                    
                    // Sport type selector
                    sportTypeSelector()
                        .padding(.horizontal)
                    
                    // Start tracking button
                    startTrackingButton()
                        .padding(.horizontal)
                    
                    // Quick actions section
                    quickActionsSection()
                        .padding(.horizontal)
                    
                    // Stats/progress section
                    statsSection()
                        .padding(.horizontal)
                }
                .padding(.vertical, 20)
            }
            .onAppear {
                loadWeatherData()
                viewModel.findNearbySportsLocations()
                loadSportsStatistics()
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
    }
    
    // MARK: - Weather Section
    
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
    
    // MARK: - Weather Components
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
                    CloudOverlay(nightMode: isNighttime(), cloudiness: .partial)
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
                default:
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
        // Simulate temperature changes
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
        return "\(Int(round(temp)))°C"
    }
    
    private func formatWindSpeed(_ speed: Double) -> String {
        return "\(Int(speed)) mph"
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
    
    // MARK: - Header Section
    private func headerSection() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sports")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Track your game")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Category Button
            Button(action: {
                showingCategorySelector = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "sportscourt")
                        .font(.system(size: 14, weight: .medium))
                    Text("Sports")
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
    }
    
    // MARK: - UI Components
    private func sportTypeSelector() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Sport")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(SportType.allCases) { type in
                        sportTypeButton(type)
                    }
                }
                .padding(.horizontal, 4) // Add some padding for better edge spacing
            }
        }
    }
    
    private func sportTypeButton(_ type: SportType) -> some View {
        Button(action: {
            viewModel.selectedSportType = type
        }) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(viewModel.selectedSportType == type ? .white : .gray)
                
                Text(type.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(viewModel.selectedSportType == type ? .white : .gray)
            }
            .frame(width: 80, height: 80)
            .background(viewModel.selectedSportType == type ? 
                       LinearGradient(
                           gradient: Gradient(colors: [
                               Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.4),
                               Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.2)
                           ]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing
                       ) :
                       LinearGradient(
                           gradient: Gradient(colors: [
                               Color.black.opacity(0.3),
                               Color.black.opacity(0.2)
                           ]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing
                       ))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(viewModel.selectedSportType == type ? 
                           Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.6) : 
                           Color.clear, lineWidth: 2)
            )
        }
    }
    
    private func startTrackingButton() -> some View {
        Button(action: {
            viewModel.startSportsTracking()
        }) {
            HStack {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24))
                Text("Start Tracking")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.976, green: 0.576, blue: 0.125),
                        Color(red: 1.0, green: 0.42, blue: 0.21)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    private func quickActionsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Start")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    quickActionButton(iconName: "figure.basketball", label: "Basketball", color: Color(red: 0.976, green: 0.576, blue: 0.125)) {
                        viewModel.selectedSportType = .basketball
                        viewModel.startSportsTracking()
                    }
                    
                    quickActionButton(iconName: "figure.soccer", label: "Soccer", color: Color(red: 0.976, green: 0.576, blue: 0.125)) {
                        viewModel.selectedSportType = .soccer
                        viewModel.startSportsTracking()
                    }
                    
                    quickActionButton(iconName: "figure.tennis", label: "Tennis", color: Color(red: 0.976, green: 0.576, blue: 0.125)) {
                        viewModel.selectedSportType = .tennis
                        viewModel.startSportsTracking()
                    }
                    
                    quickActionButton(iconName: "figure.golf", label: "Golf", color: Color(red: 0.976, green: 0.576, blue: 0.125)) {
                        viewModel.selectedSportType = .golf
                        viewModel.startSportsTracking()
                    }
                }
                
                HStack(spacing: 12) {
                    quickActionButton(iconName: "figure.kayaking", label: "Kayaking", color: Color(red: 0.976, green: 0.576, blue: 0.125)) {
                        viewModel.selectedSportType = .kayaking
                        viewModel.startSportsTracking()
                    }
                    
                    quickActionButton(iconName: "figure.surfing", label: "Surfing", color: Color(red: 0.976, green: 0.576, blue: 0.125)) {
                        viewModel.selectedSportType = .surfing
                        viewModel.startSportsTracking()
                    }
                    
                    quickActionButton(iconName: "figure.paddleboarding", label: "Paddle", color: Color(red: 0.976, green: 0.576, blue: 0.125)) {
                        viewModel.selectedSportType = .paddleboard
                        viewModel.startSportsTracking()
                    }
                    
                    quickActionButton(iconName: "volleyball.fill", label: "Volleyball", color: Color(red: 0.976, green: 0.576, blue: 0.125)) {
                        viewModel.selectedSportType = .volleyball
                        viewModel.startSportsTracking()
                    }
                }
            }
        }
    }
    
    private func quickActionButton(iconName: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        color.opacity(0.25),
                        color.opacity(0.15)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private func statsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Progress")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            if isLoadingStats {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Loading stats...")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                HStack(spacing: 16) {
                    statCard(value: "\(sportsHistoryStats.sessions)", label: "Sessions", icon: "calendar")
                    statCard(value: formatTotalTime(sportsHistoryStats.totalTime), label: "Total Time", icon: "clock.fill")
                    statCard(value: "\(sportsHistoryStats.sportsPlayed.count)", label: "Sports", icon: "sportscourt.fill")
                }
            }
        }
    }
    
    private func formatTotalTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "0m"
        }
    }
    
    private func loadSportsStatistics() {
        isLoadingStats = true
        Task {
            let stats = await sportsTrackingEngine.getStatistics()
            await MainActor.run {
                sportsHistoryStats = stats
                isLoadingStats = false
            }
        }
    }
    
    private func statCard(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(red: 0.976, green: 0.576, blue: 0.125))
            
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func actionButton(iconName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
}

// MARK: - Supporting Types

enum SportType: String, CaseIterable, Identifiable {
    case basketball
    case soccer
    case tennis
    case volleyball
    case baseball
    case hockey
    case rugby
    case kayaking
    case golf
    case paddleboard
    case surfing
    case other
    
    var id: String { rawValue }
    
    var name: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .basketball: return "basketball.fill"
        case .soccer: return "soccerball"
        case .tennis: return "tennis.racket"
        case .volleyball: return "volleyball.fill"
        case .baseball: return "baseball.fill"
        case .hockey: return "hockey.puck.fill"
        case .rugby: return "football.fill"
        case .kayaking: return "figure.kayaking"
        case .golf: return "figure.golf"
        case .paddleboard: return "figure.paddleboarding"
        case .surfing: return "figure.surfing"
        case .other: return "figure.run"
        }
    }
}

// Import the SportsTrackingEngine from the separate file
// SportsTrackingEngine is now defined in SportsTrackingEngine.swift


 
