//
//  RunAnalysisViewController.swift
//  Do.
//
//  Created by Mikiyas Meseret on 4/5/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit
import SwiftUI
import MapKit
import Charts
import Parse

// MARK: - Utility Shapes
struct PolylineShape: Shape {
    let coordinates: [CLLocationCoordinate2D]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard coordinates.count >= 2 else { return path }
        
        // Convert the coordinates to the map view's rect
        let points = convertCoordinatesToPoints(coordinates, in: rect)
        
        path.move(to: points[0])
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        
        return path
    }
    
    private func convertCoordinatesToPoints(_ coordinates: [CLLocationCoordinate2D], in rect: CGRect) -> [CGPoint] {
        // Find the bounding box of the coordinates
        var minLat = coordinates[0].latitude
        var maxLat = minLat
        var minLon = coordinates[0].longitude
        var maxLon = minLon
        
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        
        // Add padding to the bounds to avoid drawing at the very edges
        let latPadding = (maxLat - minLat) * 0.05
        let lonPadding = (maxLon - minLon) * 0.05
        
        minLat -= latPadding
        maxLat += latPadding
        minLon -= lonPadding
        maxLon += lonPadding
        
        let latRange = maxLat - minLat
        let lonRange = maxLon - minLon
        
        // Adjust for the aspect ratio of the rect to avoid distortion
        let mapAspect = rect.width / rect.height
        let coordAspect = lonRange / latRange
        
        var adjustedRect = rect
        if coordAspect > mapAspect {
            // The coordinates are wider than the rect
            let newHeight = rect.width / coordAspect
            let heightDiff = rect.height - newHeight
            adjustedRect = CGRect(x: rect.origin.x, y: rect.origin.y + heightDiff/2, width: rect.width, height: newHeight)
        } else {
            // The coordinates are taller than the rect
            let newWidth = rect.height * coordAspect
            let widthDiff = rect.width - newWidth
            adjustedRect = CGRect(x: rect.origin.x + widthDiff/2, y: rect.origin.y, width: newWidth, height: rect.height)
        }
        
        // Convert each coordinate to a point in the rect
        return coordinates.map { coordinate in
            let x = ((coordinate.longitude - minLon) / lonRange) * adjustedRect.width + adjustedRect.origin.x
            let y = (1 - (coordinate.latitude - minLat) / latRange) * adjustedRect.height + adjustedRect.origin.y
            return CGPoint(x: x, y: y)
        }
    }
}

class RunAnalysisViewController: UIViewController {
    
    // MARK: - Properties
    private var hostingController: UIHostingController<RunAnalysisView>?
    var run: Any? { // Can be RunLog or IndoorRunLog
        didSet {
            // If view is already loaded and run is set, recreate the hosting controller
            if isViewLoaded, run != nil {
                setupHostingController()
            }
        }
    }
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupHostingController()
    }
    
    // MARK: - Setup Methods
    private func setupHostingController() {
        guard let run = run else { return }
        
        // Remove existing hosting controller if present
        if let existingController = hostingController {
            existingController.willMove(toParent: nil)
            existingController.view.removeFromSuperview()
            existingController.removeFromParent()
        }
        
        // Create analysis view based on run type
        let analysisView = RunAnalysisView(run: run, onDismiss: { [weak self] in
            self?.dismiss(animated: true)
        })
        
        hostingController = UIHostingController(rootView: analysisView)
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
}

// MARK: - SwiftUI Views
struct RunAnalysisView: View {
    let run: Any
    let onDismiss: () -> Void
    
    @State private var selectedTab = 0
    @State private var showingShareSheet = false
    @State private var routeLocations: [CLLocation] = []
    @State private var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var animationTrigger = UUID() // Added UUID for animation triggering
    @State private var animatingPulse = false // Added for map pulse animation
    
    // Route animation state
    @State private var routeProgress: Double = 0.0
    @State private var isPlayingRoute: Bool = false
    
    var isOutdoorRun: Bool {
        run is RunLog
    }
    
    // MARK: - Root View Body with Animations

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: 0x0A1128),
                    Color(hex: 0x1C2541),
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with dismiss button
                headerView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeOut(duration: 0.4), value: animationTrigger)
                
                // Summary cards
                summaryCardsView
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.5).delay(0.1), value: animationTrigger)
                
                // Tab selector
                tabSelectorView
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: animationTrigger)
                
                // Tab content
                tabContentView
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.7).delay(0.3), value: animationTrigger)
                
                Spacer()
                
                // Footer actions (removed)
            }
            .padding(.top, 8)
        }
        .onAppear {
            print("RunAnalysisView: onAppear triggered")
            setupData()
            
            // Initialize map region to show the entire route when view appears
            setMapRegion()
            
            // Force rendering of the map after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("RunAnalysisView: Forcing route redraw after delay")
                // Create a small change to force view refresh
                let existingRegion = mapRegion
                var adjustedRegion = existingRegion
                adjustedRegion.span.latitudeDelta = existingRegion.span.latitudeDelta * 0.999
                mapRegion = adjustedRegion
                
                // Then set it back to the correct region
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    mapRegion = existingRegion
                }
            }
        }
        .fullScreenCover(isPresented: $showingShareSheet) {
            if isOutdoorRun {
                RunVideoPreviewViewControllerRepresentable(run: run)
            } else {
                IndoorRunShareView(run: run as! IndoorRunLog, onDismiss: { showingShareSheet = false })
            }
        }
    }
    
    // MARK: - View Components
    
    var headerView: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(10)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            HStack(spacing: 6) {
                if isOutdoorRun {
                    Image(systemName: "figure.run")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(hex: 0x4CD964))
            } else {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(hex: 0xFF9500))
                }
                
                Text(isOutdoorRun ? "Outdoor Run" : "Indoor Run")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
            )
            
            Spacer()
            
            Button(action: {
                showingShareSheet = true
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(10)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    var summaryCardsView: some View {
        VStack(spacing: 16) {
            // Date card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDate())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(formatTime())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Weather icon (outdoor runs only)
                if isOutdoorRun, let outdoorRun = run as? RunLog, let weather = outdoorRun.weather {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: getWeatherIcon(weather))
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.9))
                            
                            Text(weather)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        if let temp = outdoorRun.temperature {
                            Text("\(Int(temp))°")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
            )
            .transition(.scale(scale: 0.95).combined(with: .opacity))
            
            // Key metrics cards
            HStack(spacing: 8) {
                // Distance card
                metricCard(
                    title: "DISTANCE",
                    value: getDistance(),
                    icon: "figure.run",
                    color: Color(hex: 0x4CD964)
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
                .animation(.easeOut(duration: 0.5).delay(0.1), value: animationTrigger) // Updated to use animationTrigger
                
                // Time card
                metricCard(
                    title: "TIME",
                    value: getDuration(),
                    icon: "clock",
                    color: Color(hex: 0xFF9500)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeOut(duration: 0.5).delay(0.2), value: animationTrigger) // Updated to use animationTrigger
                
                // Pace card
                metricCard(
                    title: "AVG PACE",
                    value: getPace(),
                    icon: "speedometer",
                    color: Color(hex: 0x007AFF)
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(.easeOut(duration: 0.5).delay(0.3), value: animationTrigger) // Updated to use animationTrigger
            }
        }
        .padding(.horizontal, 16)
    }
    
    var tabSelectorView: some View {
        HStack(spacing: 0) {
            ForEach(0..<(isOutdoorRun ? 3 : 2), id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(getTabTitle(index))
                            .font(.system(size: 14, weight: selectedTab == index ? .semibold : .medium))
                            .foregroundColor(selectedTab == index ? .white : .white.opacity(0.6))
                        
                        // Active indicator
                        Rectangle()
                            .fill(selectedTab == index ? Color(hex: 0x4CD964) : Color.clear)
                            .frame(height: 3)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
    
    var tabContentView: some View {
        Group {
            if isOutdoorRun {
                if selectedTab == 0 {
                    mapView
                } else if selectedTab == 1 {
                    statsView
                } else {
                    chartsView
                }
            } else {
                if selectedTab == 0 {
                    treadmillStatsView
                } else {
                    treadmillChartsView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    

    
    var statsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Performance Score Card
                performanceScoreCard
                
                // Calories and Heart Rate
                HStack(spacing: 12) {
                    statCard(
                        title: "CALORIES",
                        value: getCalories(),
                        icon: "flame.fill",
                        color: Color(hex: 0xFF3B30)
                    )
                    
                    statCard(
                        title: "HEART RATE",
                        value: getHeartRate(),
                        icon: "heart.fill",
                        color: Color(hex: 0xFF375F)
                    )
                }
                
                // Elevation
                if isOutdoorRun, let runLog = run as? RunLog {
                    HStack(spacing: 12) {
                        statCard(
                            title: "ELEVATION GAIN",
                            value: elevationGainFormatted(runLog),
                            icon: "arrow.up.right",
                            color: Color(hex: 0x5856D6)
                        )
                        
                        statCard(
                            title: "ELEVATION LOSS",
                            value: elevationLossFormatted(runLog),
                            icon: "arrow.down.right",
                            color: Color(hex: 0x5AC8FA)
                        )
                    }
                }
                
                // Cadence and Max Speed
                if isOutdoorRun, let runLog = run as? RunLog {
                HStack(spacing: 12) {
                    statCard(
                            title: "AVG CADENCE",
                            value: runLog.avgCadence != nil ? "\(Int(runLog.avgCadence!)) spm" : "-- spm",
                            icon: "figure.walk",
                        color: Color(hex: 0x34C759)
                    )
                    
                    statCard(
                        title: "MAX SPEED",
                            value: formatSpeed(runLog.maxSpeed),
                        icon: "speedometer",
                            color: Color(hex: 0x4CD964)
                    )
                    }
                }
                
                // Mile Splits
                if isOutdoorRun && !routeLocations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(UserPreferences.shared.useMetricSystem ? "KM SPLITS" : "MILE SPLITS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                        
                        let splits = calculateMileSplits()
                        if !splits.isEmpty {
                            VStack(spacing: 0) {
                                // Header
                                HStack {
                                    Text(UserPreferences.shared.useMetricSystem ? "KM" : "MILE")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(width: 40, alignment: .leading)
                                    
                                    Text("PACE")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(width: 70, alignment: .leading)
                                    
                                    Text("TIME")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(width: 55, alignment: .leading)
                                    
                                    Text("HR")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(width: 50, alignment: .leading)
                                    
                                    Text("CADENCE")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 12)
                                .padding(.bottom, 8)
                                
                                // Splits
                                ForEach(0..<splits.count, id: \.self) { index in
                                    let split = splits[index]
                                    HStack {
                                        Text("\(split.mile)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 40, alignment: .leading)
                                        
                                        Text(formatPaceValue(split.pace))
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .frame(width: 70, alignment: .leading)
                                        
                                        let timeString = formatMileSplitTime(split.time)
                                        Text(timeString)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .frame(width: 55, alignment: .leading)
                                        
                                        // Heart Rate
                                        Text(split.avgHeartRate != nil ? "\(Int(split.avgHeartRate!))bpm" : "--")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .frame(width: 50, alignment: .leading)
                                        
                                        // Cadence
                                        Text(split.avgCadence != nil ? "\(Int(split.avgCadence!))spm" : "--")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(index % 2 == 0 ? Color.white.opacity(0.05) : Color.clear)
                                    .cornerRadius(8)
                                }
                            }
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(12)
                        } else {
                            Text("No split data available")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .padding()
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(16)
        }
    }
    
    var chartsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Pace Chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("PACE VARIATION")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    
                    paceChartView
                        .frame(height: 200)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                }
                
                // Elevation Chart
                if isOutdoorRun {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ELEVATION PROFILE")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                        
                        elevationChartView
                            .frame(height: 200)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                    }
                }
                
                // Heart Rate Chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("HEART RATE")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    
                    heartRateChartView
                        .frame(height: 200)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                }
            }
            .padding(16)
        }
    }
    
    var treadmillStatsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Performance Score Card
                performanceScoreCard
                
                // Treadmill Performance Metrics
                HStack(spacing: 12) {
                    statCard(
                        title: "CALORIES",
                        value: getCalories(),
                        icon: "flame.fill",
                        color: Color(hex: 0xFF3B30)
                    )
                    
                    statCard(
                        title: "HEART RATE",
                        value: getHeartRate(),
                        icon: "heart.fill",
                        color: Color(hex: 0xFF375F)
                    )
                }
                
                // Treadmill Settings
                if let indoorRun = run as? IndoorRunLog {
                    HStack(spacing: 12) {
                        statCard(
                            title: "AVG SPEED",
                            value: String(format: "%.1f mph", indoorRun.avgSpeed ?? 0),
                            icon: "speedometer",
                            color: Color(hex: 0x5856D6)
                        )
                        
                        statCard(
                            title: "AVG INCLINE",
                            value: String(format: "%.1f%%", indoorRun.avgIncline ?? 0),
                            icon: "arrow.up.forward",
                            color: Color(hex: 0x5AC8FA)
                        )
                    }
                }
                
                // Additional Treadmill Stats
                HStack(spacing: 12) {
                    statCard(
                        title: "CADENCE",
                        value: getCadence(),
                        icon: "metronome",
                        color: Color(hex: 0x34C759)
                    )
                    
                    statCard(
                        title: "MAX SPEED",
                        value: getMaxSpeed(),
                        icon: "speedometer",
                        color: Color(hex: 0xAF52DE)
                    )
                }
                
                // Heart Rate Distribution
                if let zones = getHeartRateZones(), !zones.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("HEART RATE ZONES")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                        
                        HStack(spacing: 0) {
                            ForEach(zones.sorted(by: { $0.key < $1.key }), id: \.key) { zone, percentage in
                                heartRateZoneBar(zone: zone, percentage: percentage)
                            }
                        }
                        .frame(height: 120)
                        .padding(.top, 8)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                }
                
                // Workout Summary or Notes
                if let notes = getNotes(), !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTES")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(notes)
                            .font(.system(size: 14))
                            .lineSpacing(4)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                }
            }
            .padding(16)
        }
    }
    
    var treadmillChartsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Speed Chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("SPEED VARIATION")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    
                    speedChartView
                        .frame(height: 200)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                }
                
                // Incline Chart
                if let indoorRun = run as? IndoorRunLog, indoorRun.avgIncline != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("INCLINE VARIATION")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                        
                        inclineChartView
                            .frame(height: 200)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                    }
                }
                
                // Heart Rate Chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("HEART RATE")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    
                    heartRateChartView
                        .frame(height: 200)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupData() {
        print("RunAnalysisViewController: Setting up data...")
        // Create new UUID to trigger animations
        animationTrigger = UUID()
        
        if isOutdoorRun, let runLog = run as? RunLog {
            print("RunAnalysisViewController: Processing outdoor run data")
            // Extract route data for map
            if let locationData = runLog.locationData {
                print("RunAnalysisViewController: Found locationData with \(locationData.count) points")
                routeLocations = extractLocationData(from: locationData)
                if !routeLocations.isEmpty {
                    print("RunAnalysisViewController: Extracted \(routeLocations.count) valid locations")
                    setMapRegion()
                    
                    // Add route analytics for display
                    analyzeRouteData()
                    
                    // Ensure map is updated in the next run loop
                    DispatchQueue.main.async {
                        self.setMapRegion()
                    }
                } else {
                    print("RunAnalysisViewController: No valid locations extracted from locationData")
                }
            } else if let coordinateArray = runLog.coordinateArray, !coordinateArray.isEmpty {
                // Fallback to coordinateArray if locationData is not available
                print("RunAnalysisViewController: Using coordinateArray with \(coordinateArray.count) points")
                routeLocations = coordinateArray.compactMap { geoPoint in
                    // geoPoint is a [String: Double] dictionary
                    guard let lat = geoPoint["latitude"] ?? geoPoint["lat"],
                          let lon = geoPoint["longitude"] ?? geoPoint["lon"] ?? geoPoint["lng"] else {
                        return nil
                    }
                    return CLLocation(
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        altitude: 0,
                        horizontalAccuracy: 0,
                        verticalAccuracy: 0,
                        course: 0,
                        speed: 0,
                        timestamp: Date()
                    )
                }
                if !routeLocations.isEmpty {
                    print("RunAnalysisViewController: Created \(routeLocations.count) locations from coordinateArray")
                    setMapRegion()
                    
                    // Add route analytics for display
                    analyzeRouteData()
                    
                    // Ensure map is updated in the next run loop
                    DispatchQueue.main.async {
                        self.setMapRegion()
                    }
                } else {
                    print("RunAnalysisViewController: Failed to create locations from coordinateArray")
                }
            } else {
                print("RunAnalysisViewController: No location data found in run log")
            }
        } else if let indoorRun = run as? IndoorRunLog {
            print("RunAnalysisViewController: Processing indoor run data")
            // Handle indoor run specific data
        } else {
            print("RunAnalysisViewController: Unknown run type")
        }
    }
    
    // Add the missing setMapRegion function
    private func setMapRegion() {
        guard !routeLocations.isEmpty else { return }
        
        // Find the bounding box of all locations
        var minLat = routeLocations[0].coordinate.latitude
        var maxLat = minLat
        var minLon = routeLocations[0].coordinate.longitude
        var maxLon = minLon
        
        for location in routeLocations {
            minLat = min(minLat, location.coordinate.latitude)
            maxLat = max(maxLat, location.coordinate.latitude)
            minLon = min(minLon, location.coordinate.longitude)
            maxLon = max(maxLon, location.coordinate.longitude)
        }
        
        // Calculate center coordinate
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        
        // Calculate span with padding
        let latDelta = (maxLat - minLat) * 1.3 // Add 15% padding
        let lonDelta = (maxLon - minLon) * 1.3
        let span = MKCoordinateSpan(latitudeDelta: max(0.005, latDelta), longitudeDelta: max(0.005, lonDelta))
        
        // Set the map region
        mapRegion = MKCoordinateRegion(center: center, span: span)
    }
    
    private func extractLocationData(from locationData: [[String: Any]]) -> [CLLocation] {
        // First extract all valid locations
        var allLocations = [CLLocation]()
        
        for dict in locationData {
            var latitude: Double?
            var longitude: Double?
            var altitude: Double = 0
            var horizontalAccuracy: Double = 0
            var verticalAccuracy: Double = 0
            var course: Double = 0
            var speed: Double = 0
            var timestamp = Date().timeIntervalSince1970
            
            // Check all possible formats for coordinates
            if let lat = dict["latitude"] as? Double, let lng = dict["longitude"] as? Double {
                latitude = lat
                longitude = lng
            } else if let lat = dict["lat"] as? Double, let lng = dict["lng"] as? Double {
                latitude = lat
                longitude = lng
            } else if let location = dict["location"] as? [String: Any] {
                if let lat = location["latitude"] as? Double, let lng = location["longitude"] as? Double {
                    latitude = lat
                    longitude = lng
                } else if let lat = location["lat"] as? Double, let lng = location["lng"] as? Double {
                    latitude = lat
                    longitude = lng
                }
            } else if let locationDict = dict["CLLocation"] as? [String: Any],
                      let coordinate = locationDict["coordinate"] as? [String: Any],
                      let lat = coordinate["latitude"] as? Double,
                      let lng = coordinate["longitude"] as? Double {
                latitude = lat
                longitude = lng
            }
            
            // Get additional data if available
            if let alt = dict["altitude"] as? Double {
                altitude = alt
            }
            
            if let acc = dict["horizontalAccuracy"] as? Double {
                horizontalAccuracy = acc
            }
            
            if let vacc = dict["verticalAccuracy"] as? Double {
                verticalAccuracy = vacc
            }
            
            if let crs = dict["course"] as? Double {
                course = crs
            }
            
            if let spd = dict["speed"] as? Double {
                speed = spd
            }
            
            if let ts = dict["timestamp"] as? TimeInterval {
                timestamp = ts
            }
            
            // Create CLLocation if valid coordinates were found
            if let lat = latitude, let lng = longitude, 
               (-90...90).contains(lat) && (-180...180).contains(lng) {
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                let location = CLLocation(
                coordinate: coordinate,
                altitude: altitude,
                horizontalAccuracy: horizontalAccuracy,
                verticalAccuracy: verticalAccuracy,
                course: course,
                speed: speed,
                timestamp: Date(timeIntervalSince1970: timestamp)
            )
                allLocations.append(location)
            }
        }
        
        // If we have very few points, return them all
        if allLocations.count <= 50 {
            return allLocations
        }
        
        // For routes with many points, use a smarter filtering algorithm
        return downsampleRoutePoints(allLocations)
    }
    
    private func downsampleRoutePoints(_ locations: [CLLocation]) -> [CLLocation] {
        guard locations.count > 50 else { return locations }
        
        var filteredLocations: [CLLocation] = []
        
        // Always include first point
        if let firstLocation = locations.first {
            filteredLocations.append(firstLocation)
        }
        
        // Douglas-Peucker algorithm-inspired approach for route simplification
        // Parameters for filtering
        let minDistance: Double = 10 // Minimum distance in meters
        let maxSpeedChange: Double = 1.0 // m/s
        let maxCourseChange: Double = 20.0 // degrees
        
        let step = max(1, locations.count / 200) // Aim for ~200 points max
        var lastAddedIndex = 0
        
        for i in stride(from: 1, to: locations.count - 1, by: step) {
            let currentLocation = locations[i]
            let lastAddedLocation = locations[lastAddedIndex]
            
            // Always add points that are far enough from last added point
            if lastAddedLocation.distance(from: currentLocation) >= minDistance {
                filteredLocations.append(currentLocation)
                lastAddedIndex = i
                continue
            }
            
            // Add points with significant speed or heading changes
            if abs(currentLocation.speed - lastAddedLocation.speed) > maxSpeedChange ||
               abs(currentLocation.course - lastAddedLocation.course) > maxCourseChange {
                filteredLocations.append(currentLocation)
                lastAddedIndex = i
                continue
            }
            
            // Add points that form a significant angle with previous and next points
            if i > 1 && i < locations.count - 1 {
                let prevLocation = locations[i-1]
                let nextLocation = locations[i+1]
                
                let bearingPrevToCurrent = getBearing(from: prevLocation, to: currentLocation)
                let bearingCurrentToNext = getBearing(from: currentLocation, to: nextLocation)
                
                if abs(bearingPrevToCurrent - bearingCurrentToNext) > maxCourseChange {
                    filteredLocations.append(currentLocation)
                    lastAddedIndex = i
                    continue
                }
                }
            }
            
            // Always include the last location
        if let lastLocation = locations.last, lastAddedIndex != locations.count - 1 {
                filteredLocations.append(lastLocation)
        }
        
        return filteredLocations
    }
    
    private func getBearing(from: CLLocation, to: CLLocation) -> Double {
        let lat1 = from.coordinate.latitude * .pi / 180
        let lon1 = from.coordinate.longitude * .pi / 180
        let lat2 = to.coordinate.latitude * .pi / 180
        let lon2 = to.coordinate.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var bearing = atan2(y, x) * 180 / .pi
        
        if bearing < 0 {
            bearing += 360
        }
        
        return bearing
    }
    
    // Calculate route analytics for display
    private func analyzeRouteData() {
        guard !routeLocations.isEmpty else { return }
        
        // Calculate route segments
        if routeLocations.count > 1 {
            var fastestPace: Double = .infinity
            var slowestPace: Double = 0
            var steepestClimb: Double = 0
            var steepestDescent: Double = 0
            var segmentDistances: [Double] = []
            var segmentPaces: [Double] = []
            var maxSpeed: Double = 0
            var totalCadence: Double = 0
            var cadenceCount: Int = 0
            var elevationGain: Double = 0
            var elevationLoss: Double = 0
            
            for i in 0..<routeLocations.count-1 {
                let currentLocation = routeLocations[i]
                let nextLocation = routeLocations[i+1]
                
                // Calculate segment distance
                let distance = currentLocation.distance(from: nextLocation)
                segmentDistances.append(distance)
                
                // Calculate segment pace if we have valid speeds
                if nextLocation.speed > 0 {
                    // Convert m/s to mins per km or mile
                    let useMetric = UserPreferences.shared.useMetricSystem
                    let paceInMinutesPerUnit = (1 / nextLocation.speed) / (useMetric ? 16.6667 : 26.8224)
                    segmentPaces.append(paceInMinutesPerUnit)
                    
                    // Track fastest/slowest pace
                    if paceInMinutesPerUnit < fastestPace {
                        fastestPace = paceInMinutesPerUnit
                    }
                    if paceInMinutesPerUnit > slowestPace {
                        slowestPace = paceInMinutesPerUnit
                    }
                    
                    // Track maximum speed (mph)
                    let speedMph = nextLocation.speed * 2.23694 // Convert m/s to mph
                    maxSpeed = max(maxSpeed, speedMph)
                }
                
                // Calculate elevation changes
                let elevationChange = nextLocation.altitude - currentLocation.altitude
                if elevationChange > 0 {
                    elevationGain += elevationChange
                } else {
                    elevationLoss += abs(elevationChange)
                }
                
                if i > 0 {
                    let elevationGradient = (elevationChange / distance) * 100 // Percentage grade
                    
                    if elevationGradient > steepestClimb {
                        steepestClimb = elevationGradient
                    }
                    if elevationGradient < steepestDescent {
                        steepestDescent = elevationGradient
                    }
                }
                
                // Process cadence data if available in location extras
                if let locationData = (run as? RunLog)?.locationData {
                    // Try to find cadence data for current location
                    if i < locationData.count, let cadence = locationData[i]["cadence"] as? Double, cadence > 0 {
                        totalCadence += cadence
                        cadenceCount += 1
                    }
                }
            }
            
            // Calculate average cadence
            let avgCadence = cadenceCount > 0 ? totalCadence / Double(cadenceCount) : 0
            
            // Update run with calculated values if they're not already set
            if var outdoorRun = run as? RunLog {
                if outdoorRun.elevationGain == nil || outdoorRun.elevationGain == "0" || outdoorRun.elevationGain == "0 m" || outdoorRun.elevationGain == "0 ft" {
                    if UserPreferences.shared.useMetricSystem {
                        outdoorRun.elevationGain = String(format: "%.0f m", elevationGain)
                    } else {
                        outdoorRun.elevationGain = String(format: "%.0f ft", elevationGain * 3.28084)
                    }
                }
                
                if outdoorRun.elevationLoss == nil || outdoorRun.elevationLoss == "0" || outdoorRun.elevationLoss == "0 m" || outdoorRun.elevationLoss == "0 ft" {
                    if UserPreferences.shared.useMetricSystem {
                        outdoorRun.elevationLoss = String(format: "%.0f m", elevationLoss)
                    } else {
                        outdoorRun.elevationLoss = String(format: "%.0f ft", elevationLoss * 3.28084)
                    }
                }
                
                if outdoorRun.maxSpeed == nil || outdoorRun.maxSpeed == 0 {
                    outdoorRun.maxSpeed = maxSpeed
                }
                
                if outdoorRun.avgCadence == nil || outdoorRun.avgCadence == 0 {
                    outdoorRun.avgCadence = avgCadence
                }
                
                // We don't need to reassign to run as outdoorRun is a reference type
                // Changes made to outdoorRun directly affect the original object
            }
            
            // Store route analysis data for display
            routeAnalysis = RouteAnalysis(
                totalPoints: routeLocations.count,
                fastestPace: fastestPace != .infinity ? fastestPace : nil,
                slowestPace: slowestPace > 0 ? slowestPace : nil,
                steepestClimb: steepestClimb,
                steepestDescent: abs(steepestDescent)
            )
        }
    }
    
    // MARK: - Map View Components
    
    var mapView: some View {
        ZStack {
            // The map view
            MapViewWrapper(
                locations: routeLocations,
                region: $mapRegion,
                progress: $routeProgress
            )
            
            // Route seek control and stats overlay
            VStack {
                Spacer()
                
                // Combine both controls in a ZStack for overlay positioning
                ZStack(alignment: .bottom) {
                    // Stats card showing position data
                    RoutePositionStatsCard(
                        routeLocations: routeLocations,
                        run: run,
                        progress: $routeProgress,
                        isPlaying: $isPlayingRoute
                    )
                    
                    // Seek slider positioned at the same place
                    RouteSeekSlider(
                        value: $routeProgress,
                        isPlaying: $isPlayingRoute,
                        run: run,
                        onPlayPause: { isPlaying in
                            withAnimation {
                                isPlayingRoute = isPlaying
                            }
                        }
                    )
                    .offset(y: 22) // Increased from 15 to 22 to match the increased stats card height
                }
                .padding(.horizontal, 8) // Reduced horizontal padding to make the control wider
                .padding(.bottom, 8) // Further reduced bottom padding from 16 to 8 to move the entire control even closer to the bottom
                .frame(maxWidth: .infinity) // Ensure the control takes up full width
            }
        }
        .onAppear {
            // Initialize map region to show the entire route when view appears
            setMapRegion()
        }
    }

    private func statsItem(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Route Data Structures
    
    // RouteMarker for start, end and key points
    private var routeMarkers: [RouteMarker] {
        var markers = [RouteMarker]()
        
        if !routeLocations.isEmpty {
            // Add start marker
            if let firstLocation = routeLocations.first {
                markers.append(RouteMarker(
                    id: UUID(),
                    coordinate: firstLocation.coordinate,
                    type: .start
                ))
            }
            
            // Add end marker
            if let lastLocation = routeLocations.last, routeLocations.count > 1 {
                markers.append(RouteMarker(
                    id: UUID(),
                    coordinate: lastLocation.coordinate,
                    type: .end
                ))
            }
            
            // Add markers for significant points (could be highest elevation, fastest pace, etc.)
            // This would require further route analysis
        }
        
        return markers
    }
    
    // Route analysis data structure
    struct RouteAnalysis {
        let totalPoints: Int
        let fastestPace: Double?
        let slowestPace: Double?
        let steepestClimb: Double
        let steepestDescent: Double
    }
    @State private var routeAnalysis: RouteAnalysis?
    
    // Route marker types
    enum RouteMarkerType {
        case start
        case end
        case highPoint
        case lowPoint
        case fastestSegment
        case slowestSegment
    }
    
    // Route marker structure
    struct RouteMarker: Identifiable {
        let id: UUID
        let coordinate: CLLocationCoordinate2D
        let type: RouteMarkerType
    }
    
    // Custom route marker view
    struct RouteMarkerView: View {
        let type: RouteMarkerType
        
        var body: some View {
            ZStack {
                Circle()
                    .fill(markerColor)
                    .frame(width: 24, height: 24)
                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 2)
                
                Image(systemName: markerIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        
        private var markerColor: Color {
            switch type {
            case .start:
                return Color(hex: 0x4CD964) // Green
            case .end:
                return Color(hex: 0xFF3B30) // Red
            case .highPoint:
                return Color(hex: 0x5856D6) // Purple
            case .lowPoint:
                return Color(hex: 0x5AC8FA) // Blue
            case .fastestSegment:
                return Color(hex: 0xFF9500) // Orange
            case .slowestSegment:
                return Color(hex: 0x8E8E93) // Gray
            }
        }
        
        private var markerIcon: String {
            switch type {
            case .start:
                return "flag.fill"
            case .end:
                return "flag.checkered"
            case .highPoint:
                return "arrow.up"
            case .lowPoint:
                return "arrow.down"
            case .fastestSegment:
                return "bolt.fill"
            case .slowestSegment:
                return "tortoise.fill"
            }
        }
    }
    
    // Route analysis popover
    struct RouteAnalysisPopover: View {
        let analysis: RouteAnalysis
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("ROUTE HIGHLIGHTS")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                
                if let fastestPace = analysis.fastestPace {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: 0xFF9500))
                        Text("Fastest: \(formatPaceValue(fastestPace))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                
                if analysis.steepestClimb > 1.0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: 0x5856D6))
                        Text("Climb: \(String(format: "%.1f%%", analysis.steepestClimb))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                
                if analysis.steepestDescent > 1.0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: 0x5AC8FA))
                        Text("Descent: \(String(format: "%.1f%%", analysis.steepestDescent))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
        }
        
        private func formatPaceValue(_ pace: Double) -> String {
            let minutes = Int(pace)
            let seconds = Int((pace - Double(minutes)) * 60)
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    // Improved polyline overlay
    struct RoutePolylineOverlay: View {
        let locations: [CLLocation]
        
        var body: some View {
            GeometryReader { geo in
                ZStack {
                    // Main route line
                    RouteLineShape(locations: locations)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: 0x4CD964), // Green start
                                    Color(hex: 0x007AFF), // Blue middle
                                    Color(hex: 0xFF3B30)  // Red end
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 1)
                }
            }
        }
    }
    
    // Helper view to break down the complex expression
    struct RouteLinesContent: View {
        let locations: [CLLocation]
        let frame: CGRect
        
        var body: some View {
            ZStack {
                // Main route line
                RouteLineShape(locations: locations)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: 0x4CD964), // Green start
                                Color(hex: 0x007AFF), // Blue middle
                                Color(hex: 0xFF3B30)  // Red end
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 1)
                
                // Direction arrows along the path
                RouteDirectionArrows(locations: locations, frame: frame)
            }
        }
    }
    
    // Further break down the direction arrows rendering
    struct RouteDirectionArrows: View {
        let locations: [CLLocation]
        let frame: CGRect
        
        var body: some View {
            Group {
                if locations.count > 20 {
                    ForEach(createArrowIndices(), id: \.self) { index in
                        if index < locations.count - 1 {
                            let startPoint = convertLocationToPoint(locations[index], in: frame)
                            let endPoint = convertLocationToPoint(locations[index + 1], in: frame)
                            DirectionArrow(start: startPoint, end: endPoint)
                        }
                    }
                }
            }
        }
        
        // Helper method to create arrow indices
        private func createArrowIndices() -> [Int] {
            let step = locations.count / 5
            return stride(from: locations.count/10, to: locations.count, by: step).map { $0 }
        }
        
        // Helper to convert CLLocation to point in view coordinates
        private func convertLocationToPoint(_ location: CLLocation, in rect: CGRect) -> CGPoint {
            guard !locations.isEmpty else { return .zero }
            
            // Find bounds
            var minLat = locations[0].coordinate.latitude
        var maxLat = minLat
            var minLon = locations[0].coordinate.longitude
            var maxLon = minLon
        
            for loc in locations {
                minLat = min(minLat, loc.coordinate.latitude)
                maxLat = max(maxLat, loc.coordinate.latitude)
                minLon = min(minLon, loc.coordinate.longitude)
                maxLon = max(maxLon, loc.coordinate.longitude)
            }
            
            let latRange = maxLat - minLat
            let lonRange = maxLon - minLon
            
            // Convert coordinate to point
            let x = (location.coordinate.longitude - minLon) / lonRange * rect.width
            let y = (1 - (location.coordinate.latitude - minLat) / latRange) * rect.height
            
            return CGPoint(x: x, y: y)
        }
        }
        
    // Direction arrow to show route direction
    struct DirectionArrow: View {
        let start: CGPoint
        let end: CGPoint
        
        var body: some View {
            ArrowShape(start: start, end: end)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.3), radius: 1)
        }
    }
    
    // Shape for drawing the route line
    struct RouteLineShape: Shape {
        let locations: [CLLocation]
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            
            guard locations.count >= 2 else { return path }
            
            // Find bounds with padding to avoid issues
            let coordinates = locations.map { $0.coordinate }
            let (minLat, maxLat, minLon, maxLon) = getBoundingBox(for: coordinates)
            
            // Calculate range - add padding to avoid division by zero
            let latRange = max(0.001, maxLat - minLat)
            let lonRange = max(0.001, maxLon - minLon)
            
            // Convert first coordinate to a point
            let firstLocation = locations[0]
            let firstX = (firstLocation.coordinate.longitude - minLon) / lonRange * rect.width
            let firstY = (1 - (firstLocation.coordinate.latitude - minLat) / latRange) * rect.height
            
            // Start the path
            path.move(to: CGPoint(x: firstX, y: firstY))
            
            // Add all other points
            for i in 1..<locations.count {
                let location = locations[i]
                let x = (location.coordinate.longitude - minLon) / lonRange * rect.width
                let y = (1 - (location.coordinate.latitude - minLat) / latRange) * rect.height
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            return path
        }
        
        // Helper function to get the bounding box
        private func getBoundingBox(for coordinates: [CLLocationCoordinate2D]) -> (Double, Double, Double, Double) {
            var minLat = coordinates[0].latitude
            var maxLat = minLat
            var minLon = coordinates[0].longitude
            var maxLon = minLon
            
            for coordinate in coordinates {
                minLat = min(minLat, coordinate.latitude)
                maxLat = max(maxLat, coordinate.latitude)
                minLon = min(minLon, coordinate.longitude)
                maxLon = max(maxLon, coordinate.longitude)
            }
            
            return (minLat, maxLat, minLon, maxLon)
        }
    }
    
    // Separate shape for the arrow
    struct ArrowShape: Shape {
        let start: CGPoint
        let end: CGPoint
        
        func path(in rect: CGRect) -> Path {
            let angle = atan2(end.y - start.y, end.x - start.x)
            
            var path = Path()
            
            let point1 = CGPoint(
                x: end.x - 6 * cos(angle) - 3 * cos(angle + .pi/2),
                y: end.y - 6 * sin(angle) - 3 * sin(angle + .pi/2)
            )
            
            let point2 = CGPoint(
                x: end.x - 6 * cos(angle) - 3 * cos(angle - .pi/2),
                y: end.y - 6 * sin(angle) - 3 * sin(angle - .pi/2)
            )
            
            path.move(to: point1)
            path.addLine(to: end)
            path.addLine(to: point2)
            
            return path
        }
    }
    
    // Improved route progress marker
    struct RouteProgressMarker: View {
        let locations: [CLLocation]
        let rect: CGRect
        
        @State private var animationProgress: Double = 0
        @State private var isPulsing = false
        
        var body: some View {
            if locations.count >= 2 {
                // Convert CLLocation array to CLLocationCoordinate2D array
                let coordinates = locations.map { $0.coordinate }
                let points = convertCoordinatesToPoints(coordinates, in: rect)
                let currentPoint = getCurrentPoint(points: points, progress: animationProgress)
                
                ZStack {
                    // Main dot
                    Circle()
                        .fill(Color(hex: 0xFF3B30))
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 2)
                        .position(currentPoint)
        
                    // Pulsing effect
                    Circle()
                        .fill(Color(hex: 0xFF3B30).opacity(0.3))
                        .frame(width: 24, height: 24)
                        .position(currentPoint)
                        .scaleEffect(isPulsing ? 1.8 : 1.0)
                        .opacity(isPulsing ? 0 : 0.6)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: isPulsing
                        )
                    
                    // Trail effect - add small dots behind to show movement
                    ForEach(0..<6) { i in
                        let trailProgress = max(0, animationProgress - Double(i) * 0.03)
                        if trailProgress > 0 {
                            let trailPoint = getCurrentPoint(points: points, progress: trailProgress)
                            Circle()
                                .fill(Color(hex: 0xFF3B30).opacity(0.7 - Double(i) * 0.1))
                                .frame(width: 3 - Double(i) * 0.3, height: 3 - Double(i) * 0.3)
                                .position(trailPoint)
                        }
                    }
                }
                .onAppear {
                    isPulsing = true
                    // Animate marker along the route
                    withAnimation(Animation.linear(duration: 12).repeatForever(autoreverses: false)) {
                        animationProgress = 1.0
                    }
                }
            } else {
                EmptyView()
            }
        }
        
        private func getCurrentPoint(points: [CGPoint], progress: Double) -> CGPoint {
            guard !points.isEmpty else { return .zero }
            
            if progress <= 0 { return points.first! }
            if progress >= 1 { return points.last! }
            
            // Calculate which segment we're on
            let segmentCount = points.count - 1
            let targetSegment = Int(floor(progress * Double(segmentCount)))
            let segmentProgress = (progress * Double(segmentCount)) - Double(targetSegment)
            
            // Bounds checking
            let currentIndex = min(targetSegment, segmentCount - 1)
            let nextIndex = min(currentIndex + 1, points.count - 1)
        
            // Interpolate between the two points
            return CGPoint(
                x: points[currentIndex].x + (points[nextIndex].x - points[currentIndex].x) * CGFloat(segmentProgress),
                y: points[currentIndex].y + (points[nextIndex].y - points[currentIndex].y) * CGFloat(segmentProgress)
            )
        }
        
        private func convertCoordinatesToPoints(_ coordinates: [CLLocationCoordinate2D], in rect: CGRect) -> [CGPoint] {
            guard !coordinates.isEmpty else { return [] }
            
            // Find bounds with padding to avoid issues
            var minLat = coordinates[0].latitude
            var maxLat = minLat
            var minLon = coordinates[0].longitude
            var maxLon = minLon
            
            for coordinate in coordinates {
                minLat = min(minLat, coordinate.latitude)
                maxLat = max(maxLat, coordinate.latitude)
                minLon = min(minLon, coordinate.longitude)
                maxLon = max(maxLon, coordinate.longitude)
            }
            
            // Calculate range - add padding to avoid division by zero
            let latRange = max(0.001, maxLat - minLat)
            let lonRange = max(0.001, maxLon - minLon)
            
            // Convert each coordinate to a point in the rect
            return coordinates.map { coordinate in
                let x = (coordinate.longitude - minLon) / lonRange * rect.width
                let y = (1 - (coordinate.latitude - minLat) / latRange) * rect.height
                return CGPoint(x: x, y: y)
            }
        }
    }
    
    // MARK: - Data Formatting Methods
    
    private func formatDate() -> String {
        if let outdoorRun = run as? RunLog, let date = outdoorRun.createdAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        } else if let indoorRun = run as? IndoorRunLog, let date = indoorRun.createdAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return "Unknown Date"
    }
    
    private func formatTime() -> String {
        if let outdoorRun = run as? RunLog, let date = outdoorRun.createdAt {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if let indoorRun = run as? IndoorRunLog, let date = indoorRun.createdAt {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return "Unknown Time"
    }
    
    private func getDistance() -> String {
        // Always save data in miles (imperial) but display according to user preferences
        if let outdoorRun = run as? RunLog, let distanceStr = outdoorRun.distance {
            // First try to parse as a simple number
            if let distanceValue = Double(distanceStr) {
                return UserPreferences.shared.formatDistance(distanceValue * 1609.34) // Convert miles to meters before formatting
            }
            // If that fails, use the more complex extraction
            if let distanceValue = extractDistanceValue(distanceStr) {
                return UserPreferences.shared.formatDistance(distanceValue * 1609.34) // Convert miles to meters before formatting
            }
            // If all parsing fails, return the original string
            return distanceStr
        } else if let indoorRun = run as? IndoorRunLog, let distanceStr = indoorRun.distance {
            if let distanceValue = Double(distanceStr) {
                return UserPreferences.shared.formatDistance(distanceValue * 1609.34)
            }
            if let distanceValue = extractDistanceValue(distanceStr) {
                return UserPreferences.shared.formatDistance(distanceValue * 1609.34)
            }
            return distanceStr
        }
        return UserPreferences.shared.formatDistance(0)
    }
    
    private func extractDistanceValue(_ distanceStr: String) -> Double? {
        // First check for simple decimal format (e.g., "5.8")
        if let value = Double(distanceStr) {
            return value
        }
        
        // Try extracting a number from a string like "5.8 mi" or "8.4 km"
        let trimmedStr = distanceStr.trimmingCharacters(in: .whitespaces)
        
        // Check for "X.X mi" format
        if trimmedStr.hasSuffix(" mi") {
            let numStr = trimmedStr.replacingOccurrences(of: " mi", with: "")
            if let value = Double(numStr) {
                return value // Already in miles
            }
        }
        
        // Check for "X.X km" format
        if trimmedStr.hasSuffix(" km") {
            let numStr = trimmedStr.replacingOccurrences(of: " km", with: "")
            if let value = Double(numStr) {
                return value / 1.60934 // Convert km to miles
            }
        }
        
        // Fallback to more generic extraction
        let components = distanceStr.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
        if let firstComponent = components.first, let value = Double(firstComponent) {
            // If the string contains "km", convert to miles for storage
            if distanceStr.contains("km") {
                return value / 1.60934 // Convert km to miles
            }
            return value // Already in miles
        }
        
        return nil
    }
    
    private func getDuration() -> String {
        if let outdoorRun = run as? RunLog {
            return outdoorRun.duration ?? "00:00"
        } else if let indoorRun = run as? IndoorRunLog {
            return indoorRun.duration ?? "00:00"
        }
        return "00:00"
    }
    
    private func getPace() -> String {
        // Always save pace in min/mi (imperial) but display according to user preferences
        if let outdoorRun = run as? RunLog, let paceStr = outdoorRun.avgPace {
            // First try to parse as a simple number (e.g., pace stored as seconds or minutes)
            if let paceValue = Double(paceStr) {
                let paceInSecondsPerMeter = (paceValue * 60) / 1609.34 // Convert min/mi to seconds/meter
                return UserPreferences.shared.formatPace(paceInSecondsPerMeter)
            }
            
            // If that fails, try the more complex extraction
            if let paceValue = extractPaceValue(paceStr) {
                let paceInSecondsPerMeter = (paceValue * 60) / 1609.34 // Convert min/mi to seconds/meter
                return UserPreferences.shared.formatPace(paceInSecondsPerMeter)
            }
            
            // If all parsing fails, return the original string
            return paceStr
        } else if let indoorRun = run as? IndoorRunLog, let paceStr = indoorRun.avgPace {
            if let paceValue = Double(paceStr) {
                let paceInSecondsPerMeter = (paceValue * 60) / 1609.34
                return UserPreferences.shared.formatPace(paceInSecondsPerMeter)
            }
            if let paceValue = extractPaceValue(paceStr) {
                let paceInSecondsPerMeter = (paceValue * 60) / 1609.34
                return UserPreferences.shared.formatPace(paceInSecondsPerMeter)
            }
            return paceStr
        }
        return UserPreferences.shared.formatPace(0)
    }
    
    private func extractPaceValue(_ paceStr: String) -> Double? {
        // First try simple decimal format (e.g., "8.5")
        if let value = Double(paceStr) {
            return value
        }
        
        // Try parsing "MM:SS/mi" format
        let trimmedStr = paceStr.trimmingCharacters(in: .whitespaces)
        
        // Check for "X:XX/mi" format
        if trimmedStr.contains("/mi") {
            let parts = trimmedStr.components(separatedBy: "/mi")[0].trimmingCharacters(in: .whitespaces)
            let timeComponents = parts.components(separatedBy: ":")
            if timeComponents.count == 2, let minutes = Double(timeComponents[0]), let seconds = Double(timeComponents[1]) {
                return minutes + seconds / 60.0 // Already in min/mi
            }
        }
        
        // Check for "X:XX/km" format
        if trimmedStr.contains("/km") {
            let parts = trimmedStr.components(separatedBy: "/km")[0].trimmingCharacters(in: .whitespaces)
            let timeComponents = parts.components(separatedBy: ":")
            if timeComponents.count == 2, let minutes = Double(timeComponents[0]), let seconds = Double(timeComponents[1]) {
                return (minutes + seconds / 60.0) * 1.60934 // Convert min/km to min/mi
            }
        }
        
        // Fallback to original implementation
        let components = paceStr.components(separatedBy: CharacterSet(charactersIn: ":/")).filter { !$0.isEmpty }
        if components.count >= 2, let minutes = Double(components[0]), let seconds = Double(components[1]) {
            let paceInMinutes = minutes + seconds / 60.0
            
            // If the string contains "/km", convert to min/mi for storage
            if paceStr.contains("/km") {
                return paceInMinutes * 1.60934 // Convert min/km to min/mi
            }
            return paceInMinutes // Already in min/mi
        }
        
        return nil
    }
    
    private func getCalories() -> String {
        if let outdoorRun = run as? RunLog, let calories = outdoorRun.caloriesBurned {
            return "\(Int(calories)) kcal"
        } else if let indoorRun = run as? IndoorRunLog, let calories = indoorRun.caloriesBurned {
            return "\(Int(calories)) kcal"
        }
        return "0 kcal"
    }
    
    private func getHeartRate() -> String {
        if let outdoorRun = run as? RunLog, let heartRate = outdoorRun.avgHeartRate {
            return "\(Int(heartRate)) bpm"
        } else if let indoorRun = run as? IndoorRunLog, let heartRate = indoorRun.avgHeartRate {
            return "\(Int(heartRate)) bpm"
        }
        return "--"
    }
    
    private func getCadence() -> String {
        if let outdoorRun = run as? RunLog, let cadence = outdoorRun.avgCadence {
            return "\(Int(cadence)) spm"
        } else if let indoorRun = run as? IndoorRunLog, let cadence = indoorRun.avgCadence {
            return "\(Int(cadence)) spm"
        }
        return "--"
    }
    
    private func getMaxSpeed() -> String {
        if let outdoorRun = run as? RunLog, let maxSpeed = outdoorRun.maxSpeed {
            return formatSpeed(maxSpeed)
        } else if let indoorRun = run as? IndoorRunLog, let maxSpeed = indoorRun.maxSpeed {
            return formatSpeed(maxSpeed)
        }
        return "--"
    }
    
    private func getNotes() -> String? {
        if let outdoorRun = run as? RunLog {
            return outdoorRun.notes
        } else if let indoorRun = run as? IndoorRunLog {
            return indoorRun.notes
        }
        return nil
    }
    
    private func getTabTitle(_ index: Int) -> String {
        if isOutdoorRun {
            return ["Route", "Stats", "Charts"][index]
        } else {
            return ["Stats", "Charts"][index]
        }
    }
    
    private func getWeatherIcon(_ weatherString: String) -> String {
        let weather = weatherString.lowercased()
        if weather.contains("clear") || weather.contains("sunny") {
            return "sun.max.fill"
        } else if weather.contains("cloud") {
            if weather.contains("partly") {
                return "cloud.sun.fill"
            } else {
                return "cloud.fill"
            }
        } else if weather.contains("rain") {
            return "cloud.rain.fill"
        } else if weather.contains("snow") {
            return "cloud.snow.fill"
        } else if weather.contains("wind") {
            return "wind"
        } else if weather.contains("fog") {
            return "cloud.fog.fill"
        }
        return "thermometer"
    }
    
    // MARK: - UI Components
    
    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .minimumScaleFactor(0.8)
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .minimumScaleFactor(0.8)
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .transition(.scale(scale: 0.95).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.5), value: animationTrigger) // Updated to use animationTrigger
    }
    
    // MARK: - Map and Chart Components
    
    // Route coordinates for map
    private var routeCoordinates: [LocationCoordinate] {
        routeLocations.map { location in
            LocationCoordinate(
                id: UUID(),
                coordinate: location.coordinate
            )
        }
    }
    
    // Replace the old routeOverlay with this new MapPolylineOverlay struct
    struct MapPolylineOverlay: View {
        let coordinates: [CLLocationCoordinate2D]
        
        init(locations: [CLLocation]) {
            self.coordinates = locations.map { $0.coordinate }
        }
        
        var body: some View {
            if coordinates.count >= 2 {
                PolylineShape(coordinates: coordinates)
                    .stroke(Color.blue, lineWidth: 4)
                    .opacity(0.8)
            } else {
                EmptyView()
            }
        }
    }

    struct PolylineShape: Shape {
        let coordinates: [CLLocationCoordinate2D]
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            
            guard coordinates.count >= 2 else { return path }
            
            // Convert the coordinates to the map view's rect
            let points = convertCoordinatesToPoints(coordinates, in: rect)
            
            path.move(to: points[0])
            for i in 1..<points.count {
                path.addLine(to: points[i])
            }
            
            return path
        }
        
        private func convertCoordinatesToPoints(_ coordinates: [CLLocationCoordinate2D], in rect: CGRect) -> [CGPoint] {
            // Find the bounding box of the coordinates
            var minLat = coordinates[0].latitude
            var maxLat = minLat
            var minLon = coordinates[0].longitude
            var maxLon = minLon
            
            for coordinate in coordinates {
                minLat = min(minLat, coordinate.latitude)
                maxLat = max(maxLat, coordinate.latitude)
                minLon = min(minLon, coordinate.longitude)
                maxLon = max(maxLon, coordinate.longitude)
            }
            
            // Add padding to the bounds to avoid drawing at the very edges
            let latPadding = (maxLat - minLat) * 0.05
            let lonPadding = (maxLon - minLon) * 0.05
            
            minLat -= latPadding
            maxLat += latPadding
            minLon -= lonPadding
            maxLon += lonPadding
            
            let latRange = maxLat - minLat
            let lonRange = maxLon - minLon
            
            // Adjust for the aspect ratio of the rect to avoid distortion
            let mapAspect = rect.width / rect.height
            let coordAspect = lonRange / latRange
            
            var adjustedRect = rect
            if coordAspect > mapAspect {
                // The coordinates are wider than the rect
                let newHeight = rect.width / coordAspect
                let heightDiff = rect.height - newHeight
                adjustedRect = CGRect(x: rect.origin.x, y: rect.origin.y + heightDiff/2, width: rect.width, height: newHeight)
            } else {
                // The coordinates are taller than the rect
                let newWidth = rect.height * coordAspect
                let widthDiff = rect.width - newWidth
                adjustedRect = CGRect(x: rect.origin.x + widthDiff/2, y: rect.origin.y, width: newWidth, height: rect.height)
            }
            
            // Convert each coordinate to a point in the rect
            return coordinates.map { coordinate in
                let x = ((coordinate.longitude - minLon) / lonRange) * adjustedRect.width + adjustedRect.origin.x
                let y = (1 - (coordinate.latitude - minLat) / latRange) * adjustedRect.height + adjustedRect.origin.y
                return CGPoint(x: x, y: y)
            }
        }
    }
    
    // Charts Implementation
    
    private var paceChartView: some View {
        Chart {
            if isOutdoorRun, let outdoorRun = run as? RunLog, !routeLocations.isEmpty {
                // Calculate pace directly from locationData instead of relying on paceValues
                let paceDataPoints = calculatePaceChartData()
                
                ForEach(Array(paceDataPoints.enumerated()), id: \.offset) { index, pacePoint in
                    LineMark(
                        x: .value("Distance", pacePoint.distance),
                        y: .value("Pace", pacePoint.pace)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: 0x4CD964),
                                Color(hex: 0x007AFF)
                            ]), 
                            startPoint: .leading, 
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    
                    AreaMark(
                        x: .value("Distance", pacePoint.distance),
                        y: .value("Pace", pacePoint.pace)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: 0x4CD964).opacity(0.4),
                                Color(hex: 0x007AFF).opacity(0.1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    if index % max(1, paceDataPoints.count / 6) == 0 {
                        PointMark(
                            x: .value("Distance", pacePoint.distance),
                            y: .value("Pace", pacePoint.pace)
                        )
                        .foregroundStyle(Color.white)
                        .symbolSize(30)
                    }
                }
            } else if let indoorRun = run as? IndoorRunLog, let treadmillData = indoorRun.treadmillDataPoints {
                // Existing code for indoor runs
                let paceValues = treadmillData.map { $0.pace }
                let normalizedPaceValues = paceValues.map { max(0, min($0, 20)) }
                let timeInterval = 1.0
                
                ForEach(Array(normalizedPaceValues.enumerated()), id: \.offset) { index, pace in
                    LineMark(
                        x: .value("Time", Double(index) * timeInterval),
                        y: .value("Pace", pace)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: 0xFF9500),
                                Color(hex: 0x007AFF)
                            ]), 
                            startPoint: .leading, 
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    
                    AreaMark(
                        x: .value("Time", Double(index) * timeInterval),
                        y: .value("Pace", pace)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: 0xFF9500).opacity(0.4),
                                Color(hex: 0x007AFF).opacity(0.1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(Color.white.opacity(0.3))
                AxisValueLabel() {
                    if let pace = value.as(Double.self) {
                        Text(formatPaceValue(pace))
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(Color.white.opacity(0.3))
                AxisValueLabel() {
                    if let distance = value.as(Double.self) {
                        Text(formatDistanceValue(distance))
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .chartYScale(domain: 0...20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                Text("PACE CHART")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: 0x4CD964))
                        .frame(width: 8, height: 8)
                    Text(UserPreferences.shared.useMetricSystem ? "min/km" : "min/mi")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                if let paceAvg = getPaceAverage() {
                    Text("Avg: \(formatPaceValue(paceAvg))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(12)
        }
        .animation(.easeInOut, value: selectedTab)
    }
    
    // Add the function to calculate pace data from locationData
    private func calculatePaceChartData() -> [PacePoint] {
        guard !routeLocations.isEmpty else { return [] }
        
        var pacePoints: [PacePoint] = []
        let useMetric = UserPreferences.shared.useMetricSystem
        let distanceUnit = useMetric ? 1000.0 : 1609.34 // km or mile in meters
        
        // Determine total distance and duration
        var totalDistance: Double = 0
        for i in 1..<routeLocations.count {
            totalDistance += routeLocations[i].distance(from: routeLocations[i-1])
        }
        
        let totalDuration = routeLocations.last!.timestamp.timeIntervalSince(routeLocations.first!.timestamp)
        
        // Limit samples for better performance and visualization
        let maxSamples = 50
        let sampleSize = max(5, routeLocations.count / maxSamples) // At least 5 data points per sample
        
        var currentDistance: Double = 0
        var lastSampleIndex = 0
        
        for i in stride(from: sampleSize, to: routeLocations.count, by: sampleSize) {
            let endIndex = min(i, routeLocations.count - 1)
            
            // Calculate distance for this segment
            var segmentDistance: Double = 0
            for j in (lastSampleIndex + 1)...(endIndex) {
                segmentDistance += routeLocations[j].distance(from: routeLocations[j-1])
            }
            
            // Calculate time for this segment
            let startTime = routeLocations[lastSampleIndex].timestamp
            let endTime = routeLocations[endIndex].timestamp
            let segmentDuration = endTime.timeIntervalSince(startTime)
            
            if segmentDuration > 0 && segmentDistance > 0 {
                // Update total distance counter
                currentDistance += segmentDistance
                
                // Calculate pace in minutes per distance unit (km or mile)
                let speedMetersPerSecond = segmentDistance / segmentDuration
                
                // Convert from m/s to pace (min/distance unit)
                let paceMinutesPerUnit = (distanceUnit / speedMetersPerSecond) / 60.0
                
                // Cap extreme values for better visualization
                let cappedPace = min(20.0, max(3.0, paceMinutesPerUnit))
                
                // Add to chart data
                pacePoints.append(PacePoint(
                    distance: currentDistance / distanceUnit, // Convert to km or miles
                    pace: cappedPace
                ))
            }
            
            lastSampleIndex = endIndex
        }
        
        // If we have very few points, interpolate
        if pacePoints.count < 5 && pacePoints.count > 0 {
            // Add overall average as fallback
            let avgSpeed = totalDistance / totalDuration
            let avgPace = (distanceUnit / avgSpeed) / 60.0
            let cappedAvgPace = min(20.0, max(3.0, avgPace))
            
            // Create evenly spaced points
            let interpolatedPoints: [PacePoint] = (0..<5).map { i in
                let distance = totalDistance * Double(i) / 5.0 / distanceUnit
                return PacePoint(distance: distance, pace: cappedAvgPace)
            }
            
            return interpolatedPoints
        }
        
        return pacePoints
    }

    // Define PacePoint struct for pace chart data
    private struct PacePoint {
        let distance: Double  // In user's preferred unit (miles or km)
        let pace: Double      // In minutes per unit (min/mile or min/km)
    }
    
    private var elevationChartView: some View {
        Group {
            if let outdoorRun = run as? RunLog, 
               let locationData = outdoorRun.locationData,
               !locationData.isEmpty {
                let elevationData = extractElevationData(from: locationData)
                
                Chart {
                    ForEach(Array(elevationData.enumerated()), id: \.offset) { index, elevation in
                        LineMark(
                            x: .value("Distance", Double(index) * getChartDistanceInterval(elevationData.count)),
                            y: .value("Elevation", elevation)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: 0x5856D6),
                                    Color(hex: 0x5AC8FA)
                                ]), 
                                startPoint: .leading, 
                                endPoint: .trailing
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        
                        AreaMark(
                            x: .value("Distance", Double(index) * getChartDistanceInterval(elevationData.count)),
                            y: .value("Elevation", elevation)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: 0x5856D6).opacity(0.4),
                                    Color(hex: 0x5AC8FA).opacity(0.1)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.white.opacity(0.3))
                        AxisValueLabel() {
                            if let elevation = value.as(Double.self) {
                                let useMetric = UserPreferences.shared.useMetricSystem
                                if useMetric {
                                    Text("\(Int(elevation))m")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.7))
                                } else {
                                    // Convert meters to feet (1m = 3.28084ft)
                                    let elevationFeet = elevation * 3.28084
                                    Text("\(Int(elevationFeet))ft")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.white.opacity(0.3))
                        AxisValueLabel() {
                            if let distance = value.as(Double.self) {
                                Text(formatDistanceValue(distance))
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: 0x5AC8FA))
                                .frame(width: 8, height: 8)
                            Text(UserPreferences.shared.useMetricSystem ? "Elevation (m)" : "Elevation (ft)")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        if let elevGain = outdoorRun.elevationGain, let elevLoss = outdoorRun.elevationLoss {
                            HStack(spacing: 8) {
                                Text("Gain: \(elevGain)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                Text("Loss: \(elevLoss)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                    .padding(12)
                }
                .animation(.easeInOut, value: selectedTab)
            } else {
                Text("No elevation data available")
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Helper Methods for Charts
    
    private func getChartDistanceInterval(_ pointCount: Int) -> Double {
        // Extract total distance from run
        var totalDistance: Double = 1.0
        if let outdoorRun = run as? RunLog, let distanceStr = outdoorRun.distance {
            totalDistance = Double(distanceStr.replacingOccurrences(of: " km", with: "")
                                 .replacingOccurrences(of: " mi", with: "")) ?? 1.0
        } else if let indoorRun = run as? IndoorRunLog, let distanceStr = indoorRun.distance {
            totalDistance = Double(distanceStr.replacingOccurrences(of: " km", with: "")
                                 .replacingOccurrences(of: " mi", with: "")) ?? 1.0
        }
        
        // Use the actual distance in miles/km for x-axis scaling
        // Divide by the number of segments (pointCount - 1) to get interval
        let interval = totalDistance / Double(max(1, pointCount - 1))
        
        // Ensure we return a reasonable interval value
        return max(0.01, interval)
    }
    
    private func getChartTimeInterval(_ pointCount: Int) -> Double {
        // Extract total duration from run in minutes
        var totalDuration: Double = 30.0 // default 30 minutes
        if let outdoorRun = run as? RunLog, let durationStr = outdoorRun.duration {
            totalDuration = convertDurationToMinutes(durationStr)
        } else if let indoorRun = run as? IndoorRunLog, let durationStr = indoorRun.duration {
            totalDuration = convertDurationToMinutes(durationStr)
        }
        
        return max(0.5, totalDuration / Double(max(1, pointCount - 1)))
    }
    
    private func convertDurationToMinutes(_ durationStr: String) -> Double {
        let components = durationStr.components(separatedBy: ":")
        if components.count == 3 {
            // Hour:Minute:Second format
            let hours = Double(components[0]) ?? 0
            let minutes = Double(components[1]) ?? 0
            let seconds = Double(components[2]) ?? 0
            return hours * 60 + minutes + seconds / 60
        } else if components.count == 2 {
            // Minute:Second format
            let minutes = Double(components[0]) ?? 0
            let seconds = Double(components[1]) ?? 0
            return minutes + seconds / 60
        }
        return 30.0 // Default
    }
    
    private func formatPaceValue(_ pace: Double) -> String {
        // Format pace value according to user preferences
        let useMetric = UserPreferences.shared.useMetricSystem
        let convertedPace = useMetric ? pace / 1.60934 : pace // Convert from min/mi to min/km if metric
        
        let minutes = Int(convertedPace)
        let seconds = Int((convertedPace - Double(minutes)) * 60)
        
        let unit = useMetric ? "/km" : "/mi"
        return String(format: "%d:%02d %@", minutes, seconds, unit)
    }
    
    private func formatDistanceValue(_ distance: Double) -> String {
        // Assume input distance is in miles
        let useMetric = UserPreferences.shared.useMetricSystem
        let convertedDistance = useMetric ? distance * 1.60934 : distance // Convert miles to km if metric
        
        let unit = useMetric ? "km" : "mi"
        return String(format: "%.1f %@", convertedDistance, unit)
    }
    
    private func formatTimeValue(_ time: Double) -> String {
        // Convert minutes to hours:minutes format if over 60 minutes
        if time >= 60 {
            let hours = Int(time) / 60
            let minutes = Int(time) % 60
            return String(format: "%d:%02dh", hours, minutes)
        } else {
            let minutes = Int(time)
            return "\(minutes)m"
        }
    }
    
    private func getPaceAverage() -> Double? {
        if let outdoorRun = run as? RunLog, let paceValues = outdoorRun.paceValues, !paceValues.isEmpty {
            let sum = paceValues.reduce(0, +)
            return sum / Double(paceValues.count)
        } else if let indoorRun = run as? IndoorRunLog, let treadmillData = indoorRun.treadmillDataPoints, !treadmillData.isEmpty {
            let paceValues = treadmillData.map { $0.pace }
            let sum = paceValues.reduce(0, +)
            return sum / Double(paceValues.count)
        }
        return nil
    }
    
    private func extractElevationData(from locationData: [[String: Any]]) -> [Double] {
        return locationData.compactMap { dict -> Double? in
            return dict["altitude"] as? Double
        }
    }
    
    private func getElevationGain() -> String? {
        if let outdoorRun = run as? RunLog {
            return outdoorRun.elevationGain
        }
        return nil
    }
    
    private func getElevationLoss() -> String? {
        if let outdoorRun = run as? RunLog {
            return outdoorRun.elevationLoss
        }
        return nil
    }
    
    private func extractHeartRateData() -> [Double]? {
        if let outdoorRun = run as? RunLog, let locationData = outdoorRun.locationData {
            let heartRates = locationData.compactMap { dict -> Double? in
                return dict["heartRate"] as? Double
            }
            return heartRates.isEmpty ? nil : heartRates
        } else if let indoorRun = run as? IndoorRunLog, let treadmillData = indoorRun.treadmillDataPoints {
            let heartRates = treadmillData.map { $0.heartRate }
            return heartRates.isEmpty ? nil : heartRates
        }
        return nil
    }
    
    private func getHeartRateAverage() -> Int? {
        if let outdoorRun = run as? RunLog, let avg = outdoorRun.avgHeartRate {
            return Int(avg)
        } else if let indoorRun = run as? IndoorRunLog, let avg = indoorRun.avgHeartRate {
            return Int(avg)
        }
        return nil
    }
    
    private func getHeartRateMax() -> Int? {
        if let outdoorRun = run as? RunLog, let max = outdoorRun.maxHeartRate {
            return Int(max)
        } else if let indoorRun = run as? IndoorRunLog, let max = indoorRun.maxHeartRate {
            return Int(max)
        }
        return nil
    }
    
    private func getHeartRateZones() -> [Int: Double]? {
        if let outdoorRun = run as? RunLog, let zones = outdoorRun.heartRateZones {
            return stringKeyToIntKey(zones)
        } else if let indoorRun = run as? IndoorRunLog, let zones = indoorRun.heartRateZones {
            return stringKeyToIntKey(zones)
        }
        return nil
    }
    
    private func stringKeyToIntKey(_ dict: [String: Double]) -> [Int: Double] {
        var result: [Int: Double] = [:]
        for (key, value) in dict {
            if let intKey = Int(key) {
                result[intKey] = value
            }
        }
        return result
    }
    
    private func getZoneColor(_ zone: Int) -> Color {
        switch zone {
        case 1: return Color(hex: 0x34C759) // Green
        case 2: return Color(hex: 0x5AC8FA) // Blue
        case 3: return Color(hex: 0x5856D6) // Indigo
        case 4: return Color(hex: 0xFF9500) // Orange
        case 5: return Color(hex: 0xFF3B30) // Red
        default: return Color.gray
        }
    }
    
    private func heartRateGradient() -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: 0xFF375F),
                Color(hex: 0xFF3B30)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // MARK: - Performance Score Calculation Methods

    private func getOverallScore() -> Double {
        let metrics = getPerformanceMetrics()
        if metrics.isEmpty { return 0 }
        
        let sum = metrics.reduce(0) { $0 + $1.score }
        return sum / Double(metrics.count)
    }

    private func getScoreGradient() -> AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                Color(hex: 0x4CD964), // Green
                Color(hex: 0x5AC8FA), // Blue
                Color(hex: 0xFF9500), // Orange
                Color(hex: 0x4CD964)  // Back to green to complete the circle
            ]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
    }

    private struct PerformanceMetric {
        let name: String
        let score: Double
        let icon: String
        let color: Color
    }

    private func getPerformanceMetrics() -> [PerformanceMetric] {
        var metrics: [PerformanceMetric] = []
        
        // Pace Consistency Score - Only include if real data is available
        if let paceConsistencyScore = calculatePaceConsistencyScore() {
            metrics.append(PerformanceMetric(
                name: "PACE",
                score: paceConsistencyScore,
                icon: "speedometer",
                color: Color(hex: 0x4CD964)
            ))
        }
        
        // Heart Rate Zone Score - Only include if real data is available
        if let heartRateZoneScore = calculateHeartRateZoneScore() {
            metrics.append(PerformanceMetric(
                name: "HEART RATE",
                score: heartRateZoneScore,
                icon: "heart.fill",
                color: Color(hex: 0xFF375F)
            ))
        }
        
        // Duration Score - Always include as it's always available
        metrics.append(PerformanceMetric(
            name: "ENDURANCE",
            score: calculateDurationScore(),
            icon: "clock",
            color: Color(hex: 0xFF9500)
        ))
        
        // Distance Score - Always include as it's always available
        metrics.append(PerformanceMetric(
            name: "DISTANCE",
            score: calculateDistanceScore(),
            icon: "figure.run",
            color: Color(hex: 0x5AC8FA)
        ))
        
        // Elevation Score for outdoor runs - Only include if real data is available
        if isOutdoorRun, let elevationScore = calculateElevationScore() {
            metrics.append(PerformanceMetric(
                name: "ELEVATION",
                score: elevationScore,
                icon: "mountain.2.fill",
                color: Color(hex: 0x5856D6)
            ))
        }
        
        // Incline Score for indoor runs - Only include if real data is available
        if !isOutdoorRun, let inclineScore = calculateInclineScore() {
            metrics.append(PerformanceMetric(
                name: "INCLINE",
                score: inclineScore,
                icon: "arrow.up.right",
                color: Color(hex: 0x5856D6)
            ))
        }
        
        return metrics
    }

    // Calculate a score based on how consistent the pace was
    private func calculatePaceConsistencyScore() -> Double? {
        if let outdoorRun = run as? RunLog, let paceValues = outdoorRun.paceValues, !paceValues.isEmpty {
            let paceValues = paceValues.map { $0 }
            
            // If all pace values are identical, score is 100
            if Set(paceValues).count == 1 { return 100.0 }
            
            // Calculate standard deviation as a measure of consistency
            let avg = paceValues.reduce(0, +) / Double(paceValues.count)
            let sumOfSquaredDifferences = paceValues.reduce(0) { $0 + pow($1 - avg, 2) }
            let standardDeviation = sqrt(sumOfSquaredDifferences / Double(paceValues.count))
            
            // Lower standard deviation is better - score declines as standard deviation increases
            let score = max(0, 100 - (standardDeviation * 15)) // Scaled to give reasonable scores
            return score
        } else if let indoorRun = run as? IndoorRunLog, let treadmillData = indoorRun.treadmillDataPoints, !treadmillData.isEmpty {
            let paceValues = treadmillData.map { $0.pace }
            
            // If all pace values are identical, score is 100
            if Set(paceValues).count == 1 { return 100.0 }
            
            // Calculate standard deviation as a measure of consistency
            let avg = paceValues.reduce(0, +) / Double(paceValues.count)
            let sumOfSquaredDifferences = paceValues.reduce(0) { $0 + pow($1 - avg, 2) }
            let standardDeviation = sqrt(sumOfSquaredDifferences / Double(paceValues.count))
            
            // Lower standard deviation is better - score declines as standard deviation increases
            let score = max(0, 100 - (standardDeviation * 15)) // Scaled to give reasonable scores
            return score
        } else {
            // If no pace data is available, try to calculate from route locations
            if !routeLocations.isEmpty && routeLocations.count > 2 {
                var paceValues: [Double] = []
                
                // Calculate pace at regular intervals from location data
                for i in 1..<routeLocations.count-1 {
                    let prev = routeLocations[i-1]
                    let curr = routeLocations[i]
                    let next = routeLocations[i+1]
                    
                    let distance1 = prev.distance(from: curr)
                    let distance2 = curr.distance(from: next)
                    let totalDistance = distance1 + distance2
                    
                    let time1 = curr.timestamp.timeIntervalSince(prev.timestamp)
                    let time2 = next.timestamp.timeIntervalSince(curr.timestamp)
                    let totalTime = time1 + time2
                    
                    if totalDistance > 10 && totalTime > 0 { // Ensure meaningful measurements
                        let pace = totalTime / totalDistance // seconds per meter
                        paceValues.append(pace)
                    }
                }
                
                if !paceValues.isEmpty {
                    // If all pace values are identical, score is 100
                    if Set(paceValues).count == 1 { return 100.0 }
                    
                    // Calculate standard deviation as a measure of consistency
                    let avg = paceValues.reduce(0, +) / Double(paceValues.count)
                    let sumOfSquaredDifferences = paceValues.reduce(0) { $0 + pow($1 - avg, 2) }
                    let standardDeviation = sqrt(sumOfSquaredDifferences / Double(paceValues.count))
                    
                    // Lower standard deviation is better - score declines as standard deviation increases
                    let score = max(0, 100 - (standardDeviation * 15)) // Scaled to give reasonable scores
                    return score
                }
            }
            
            // If we still can't calculate a score, return nil
            return nil
        }
    }

    // Calculate a score based on time spent in target heart rate zones
    private func calculateHeartRateZoneScore() -> Double? {
        if let zones = getHeartRateZones(), !zones.isEmpty {
            // Heart rate zones 2-4 are typically considered optimal for training
            // Zone 1 is too low, Zone 5 is too high for extended periods
            var score = 0.0
            
            // Weight the zones - zones 2-4 contribute positively
            if let zone2 = zones[2] { score += zone2 * 1.0 }
            if let zone3 = zones[3] { score += zone3 * 1.2 }
            if let zone4 = zones[4] { score += zone4 * 0.8 }
            
            // Zone 1 is too low for effective training, Zone 5 is too intense for extended periods
            if let zone1 = zones[1] { score -= zone1 * 0.3 }
            if let zone5 = zones[5] { score -= (zone5 > 10 ? (zone5 - 10) : 0) * 0.5 }
            
            return max(0, min(100, score))
        } else {
            // Try to calculate heart rate score from raw heart rate data
            if let heartRateData = extractHeartRateData(), !heartRateData.isEmpty {
                // Calculate average heart rate
                let avgHeartRate = heartRateData.reduce(0, +) / Double(heartRateData.count)
                
                // Calculate heart rate variability (as a simple measure of training effort)
                var minHR = Double.greatestFiniteMagnitude
                var maxHR = 0.0
                
                for hr in heartRateData {
                    minHR = min(minHR, hr)
                    maxHR = max(maxHR, hr)
                }
                
                let hrRange = maxHR - minHR
                
                // Estimate max heart rate using common formula (220 - age)
                // Since we don't have age, use a default max of 180
                let estimatedMaxHR = 180.0
                
                // Calculate percentage of max heart rate
                let percentOfMax = avgHeartRate / estimatedMaxHR
                
                // Score based on average heart rate as percentage of max
                // 60-85% of max heart rate is generally considered optimal for training
                var score = 0.0
                
                if percentOfMax < 0.5 {
                    // Too low for effective training
                    score = 60.0 + (percentOfMax * 20.0)
                } else if percentOfMax < 0.6 {
                    // Low but acceptable
                    score = 70.0 + ((percentOfMax - 0.5) * 100)
                } else if percentOfMax < 0.85 {
                    // Optimal training zone
                    score = 80.0 + ((percentOfMax - 0.6) * 80)
                } else if percentOfMax < 0.95 {
                    // High intensity, good for short periods
                    score = 90.0 - ((percentOfMax - 0.85) * 50)
                } else {
                    // Too high for sustained periods
                    score = 85.0 - ((percentOfMax - 0.95) * 100)
                }
                
                // Add bonus for heart rate variability (indicates interval training)
                if hrRange > 30 {
                    score += min(10.0, hrRange / 10.0)
                }
                
                return max(0, min(100, score))
            }
            
            // If no heart rate data is available, return nil
            return nil
        }
    }

    // Calculate a score based on duration - longer runs typically score higher
    private func calculateDurationScore() -> Double {
        // Target durations in minutes - adjust based on your app's user base
        let targetDuration = 30.0 // 30 minutes is a solid run
        var actualDuration = 0.0
        
        if let outdoorRun = run as? RunLog, let durationStr = outdoorRun.duration {
            actualDuration = convertDurationToMinutes(durationStr)
        } else if let indoorRun = run as? IndoorRunLog, let durationStr = indoorRun.duration {
            actualDuration = convertDurationToMinutes(durationStr)
        }
        
        // Score increases with duration, max score at targetDuration
        let rawScore = min(actualDuration / targetDuration * 100, 100)
        
        // Bonus for runs longer than target
        let bonus = actualDuration > targetDuration ? min((actualDuration - targetDuration) / 15 * 10, 20) : 0
        
        return min(100, rawScore + bonus)
    }

    // Calculate a score based on distance
    private func calculateDistanceScore() -> Double {
        // Target distance in miles or km - adjust based on your app's user base
        let targetDistance = 3.0 // 3 miles or 5km is a good run
        var actualDistance = 0.0
        
        if let outdoorRun = run as? RunLog, let distanceStr = outdoorRun.distance {
            actualDistance = extractDistanceValue(distanceStr)
        } else if let indoorRun = run as? IndoorRunLog, let distanceStr = indoorRun.distance {
            actualDistance = extractDistanceValue(distanceStr)
        }
        
        // Score increases with distance, max score at targetDistance
        let rawScore = min(actualDistance / targetDistance * 100, 100)
        
        // Bonus for runs longer than target
        let bonus = actualDistance > targetDistance ? min((actualDistance - targetDistance) / 2 * 10, 20) : 0
        
        return min(100, rawScore + bonus)
    }

    private func extractDistanceValue(_ distanceStr: String) -> Double {
        // Extract numeric value from strings like "5.2 km" or "3.4 mi"
        return Double(distanceStr.replacingOccurrences(of: " km", with: "")
                               .replacingOccurrences(of: " mi", with: "")) ?? 0.0
    }

    // Calculate a score based on elevation gain (outdoor runs)
    private func calculateElevationScore() -> Double? {
        if let outdoorRun = run as? RunLog, let elevationGainStr = outdoorRun.elevationGain {
            // Skip if elevation gain is zero or not set properly
            if elevationGainStr == "0" || elevationGainStr == "0 m" || elevationGainStr == "0 ft" {
                // Check if we can calculate from route
                var totalElevationGain: Double = 0
                if routeLocations.count > 1 {
                    for i in 1..<routeLocations.count {
                        let current = routeLocations[i]
                        let previous = routeLocations[i-1]
                        let elevationChange = current.altitude - previous.altitude
                        if elevationChange > 0 {
                            totalElevationGain += elevationChange
                        }
                    }
                    
                    // Only return a score if we actually have elevation gain
                    if totalElevationGain > 0 {
                        // Typical elevation targets - adjust based on your app's user base
                        let targetElevation = 100.0 // 100m elevation gain is a good target
                        
                        // Score increases with elevation gain, max score at targetElevation
                        let rawScore = min(totalElevationGain / targetElevation * 100, 100)
                        
                        // Bonus for significant elevation
                        let bonus = totalElevationGain > targetElevation ? min((totalElevationGain - targetElevation) / 50 * 5, 20) : 0
                        
                        return min(100, rawScore + bonus)
                    }
                    
                    return nil
                }
                
                return nil
            }
            
            // Extract numeric value (assume in meters)
            let elevationGain = Double(elevationGainStr.replacingOccurrences(of: " m", with: "")
                                                     .replacingOccurrences(of: " ft", with: "")) ?? 0.0
            
            // Return nil if elevation gain is zero
            if elevationGain <= 0 {
                return nil
            }
            
            // Convert feet to meters if necessary
            let elevationGainMeters = elevationGainStr.contains(" ft") ? elevationGain / 3.28084 : elevationGain
            
            // Typical elevation targets - adjust based on your app's user base
            let targetElevation = 100.0 // 100m elevation gain is a good target
            
            // Score increases with elevation gain, max score at targetElevation
            let rawScore = min(elevationGainMeters / targetElevation * 100, 100)
            
            // Bonus for significant elevation
            let bonus = elevationGainMeters > targetElevation ? min((elevationGainMeters - targetElevation) / 50 * 5, 20) : 0
            
            return min(100, rawScore + bonus)
        }
        return nil
    }

    // Calculate a score based on incline (indoor/treadmill runs)
    private func calculateInclineScore() -> Double? {
        if let indoorRun = run as? IndoorRunLog, let avgIncline = indoorRun.avgIncline {
            // Typical treadmill incline targets
            // 0-1% is minimal, 1-2% is low, 2-5% is moderate, 5-10% is challenging, >10% is very steep
            
            // Scale based on average incline
            if avgIncline < 0.5 {
                return 60.0 // Minimal challenge
            } else if avgIncline < 1.0 {
                return 70.0 // Low challenge
            } else if avgIncline < 2.0 {
                return 80.0 // Moderate challenge
            } else if avgIncline < 5.0 {
                return 90.0 // Good challenge
            } else {
                return 100.0 // Excellent challenge
            }
        }
        return nil
    }
    
    // Modify the heart rate zones bar chart to be animated
    private func heartRateZoneBar(zone: Int, percentage: Double) -> some View {
        VStack(alignment: .center) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 100)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(getZoneColor(zone))
                    .frame(height: 0) // Start at zero height
                    .animation(.easeInOut(duration: 1.0).delay(Double(zone) * 0.2), value: percentage) // Staggered animation based on zone number
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            _ = RoundedRectangle(cornerRadius: 4)
                                .fill(getZoneColor(zone))
                                .frame(height: max(10, 100 * percentage / 100)) // Animate to final height
                        }
                    }
            }
            .overlay(
                Text("\(Int(percentage))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 4),
                alignment: .bottom
            )
            
            Text("Zone \(zone)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 2)
    }

    // MARK: - Performance Score Card

    private var performanceScoreCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PERFORMANCE")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            
            HStack(spacing: 20) {
                // Overall Score
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(
                                Color.white.opacity(0.1),
                                lineWidth: 8
                            )
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(min(getOverallScore() / 100, 1.0)))
                            .stroke(
                                getScoreGradient(),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1.0), value: getOverallScore())
                        
                        VStack(spacing: 0) {
                            Text("\(Int(getOverallScore()))")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("/100")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Text("OVERALL")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Individual Score Metrics
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(getPerformanceMetrics(), id: \.name) { metric in
                        HStack(spacing: 16) {
                            // Metric Name
                            HStack(spacing: 4) {
                                Image(systemName: metric.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(metric.color)
                                
                                Text(metric.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .frame(width: 100, alignment: .leading)
                            
                            // Score bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 6)
                                        .cornerRadius(3)
                                    
                                    Rectangle()
                                        .fill(metric.color)
                                        .frame(width: geo.size.width * CGFloat(min(metric.score / 100, 1.0)), height: 6)
                                        .cornerRadius(3)
                                        .animation(.easeInOut(duration: 0.8), value: metric.score)
                                }
                            }
                            .frame(height: 6)
                            
                            // Score number
                            Text("\(Int(metric.score))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
            
            // Performance score legend
            VStack(alignment: .leading, spacing: 8) {
                Text("SCORING GUIDE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 4)
                
                Text("• Pace: Consistency of your pace during the run")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("• Heart Rate: Time spent in optimal training zones")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("• Endurance: Duration relative to your history")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("• Distance: Comparison to your typical runs")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("Higher scores (80-100) indicate excellent performance")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // Add these functions to the class

    private func calculateMileSplits() -> [(mile: Int, pace: Double, time: Double, avgHeartRate: Double?, avgCadence: Double?)] {
        guard !routeLocations.isEmpty else { return [] }
        
        print("RunAnalysisViewController: Calculating mile splits with \(routeLocations.count) locations")
        
        var splits: [(mile: Int, pace: Double, time: Double, avgHeartRate: Double?, avgCadence: Double?)] = []
        
        // Use metric system preference to determine mile/km distance
        let useMetric = UserPreferences.shared.useMetricSystem
        let unitDistance: Double = useMetric ? 1000.0 : 1609.34 // 1km or 1mile in meters
        let unitName = useMetric ? "km" : "mile"
        
        var cumulativeDistance: Double = 0
        var lastMilestoneDistance: Double = 0
        // Use Date instead of TimeInterval to avoid possible precision issues
        var lastMilestoneTimePoint: Date = routeLocations.first!.timestamp
        var currentMile = 1
        
        // Get location data array with heart rate and cadence if available
        var locationData: [[String: Any]] = []
        if let outdoorRun = run as? RunLog, let runLocationData = outdoorRun.locationData {
            locationData = runLocationData
            print("RunAnalysisViewController: Found \(locationData.count) location data points with HR/cadence")
        }
        
        // Calculate total distance properly first
        var totalDistance: Double = 0
        for i in 1..<routeLocations.count {
            let prevLocation = routeLocations[i-1]
            let currentLocation = routeLocations[i]
            
            let segmentDistance = prevLocation.distance(from: currentLocation)
            if segmentDistance > 0 && segmentDistance < 100 { // Filter out unrealistic jumps
                totalDistance += segmentDistance
            }
        }
        print("RunAnalysisViewController: Total distance calculated: \(totalDistance) meters")
        
        // Reset variables for the actual split calculation
        cumulativeDistance = 0
        
        // For collecting heart rate and cadence data for each split
        var splitHeartRates: [Double] = []
        var splitCadences: [Double] = []
        var splitStartIndex = 0
        
        // Get the total duration
        let totalDuration = routeLocations.last!.timestamp.timeIntervalSince(routeLocations.first!.timestamp)
        print("RunAnalysisViewController: Total duration: \(totalDuration) seconds (\(formatTimeValue(totalDuration/60)))")
        
        // Locations must be sorted by timestamp for accurate calculations
        let sortedLocations = routeLocations.sorted(by: { $0.timestamp < $1.timestamp })
        
        // Check if location timestamps look valid
        var useDistanceBasedEstimation = false
        var estimatedPacePerMeter = 0.0
        
        if sortedLocations.count > 1 {
            let firstTime = sortedLocations.first!.timestamp
            let lastTime = sortedLocations.last!.timestamp
            let timeDiff = lastTime.timeIntervalSince(firstTime)
            print("RunAnalysisViewController: Time range: \(firstTime) to \(lastTime) (total: \(timeDiff) seconds)")
            
            // Check if timestamps are too close together, which would indicate a timestamp issue
            if timeDiff < 10 && sortedLocations.count > 10 {
                print("RunAnalysisViewController: WARNING - Very small time range for many locations. Timestamps may be invalid.")
                useDistanceBasedEstimation = true
                
                // Get pace data from the run metadata if available
                if let outdoorRun = run as? RunLog, let avgPaceString = outdoorRun.avgPace, 
                   let durationString = outdoorRun.duration {
                    
                    // Parse pace string (format like "8:30 /mi")
                    let paceComponents = avgPaceString.components(separatedBy: " ")[0].components(separatedBy: ":")
                    if paceComponents.count == 2, 
                       let minutes = Double(paceComponents[0]),
                       let seconds = Double(paceComponents[1]) {
                        
                        let paceSeconds = minutes * 60 + seconds
                        
                        // Parse duration string (format like "1:23:45")
                        let durationComponents = durationString.components(separatedBy: ":")
                        var durationInSeconds = 0.0
                        
                        if durationComponents.count == 3 {
                            if let hours = Double(durationComponents[0]),
                               let mins = Double(durationComponents[1]),
                               let secs = Double(durationComponents[2]) {
                                durationInSeconds = hours * 3600 + mins * 60 + secs
                            }
                        } else if durationComponents.count == 2 {
                            if let mins = Double(durationComponents[0]),
                               let secs = Double(durationComponents[1]) {
                                durationInSeconds = mins * 60 + secs
                            }
                        }
                        
                        if durationInSeconds > 0 && paceSeconds > 0 {
                            // Convert pace from min/mile to seconds/meter
                            estimatedPacePerMeter = (paceSeconds / unitDistance)
                            print("RunAnalysisViewController: Using estimated pace of \(estimatedPacePerMeter) seconds per meter from run metadata")
                        }
                    }
                }
                
                // If we couldn't get pace from metadata, use a reasonable default
                if estimatedPacePerMeter <= 0 {
                    // Assume an 10:00 min/mile pace (reasonable default)
                    estimatedPacePerMeter = (10.0 * 60) / unitDistance
                    print("RunAnalysisViewController: Using default estimated pace of \(estimatedPacePerMeter) seconds per meter")
                }
            }
        }
        
        for i in 1..<sortedLocations.count {
            let prevLocation = sortedLocations[i-1]
            let currentLocation = sortedLocations[i]
            
            // Check for valid timestamps - locations should be at least 1 second apart typically
            let timeDiff = currentLocation.timestamp.timeIntervalSince(prevLocation.timestamp)
            if timeDiff < 0.001 && i % 10 == 0 {  // Only log occasionally to avoid too many messages
                print("RunAnalysisViewController: Warning - Very small time difference between locations: \(timeDiff) seconds")
            }
            
            // Calculate distance between consecutive points
            let segmentDistance = prevLocation.distance(from: currentLocation)
            
            // Skip unrealistic jumps (GPS errors)
            if segmentDistance > 0 && segmentDistance < 100 {
                cumulativeDistance += segmentDistance
                
                // Collect heart rate and cadence data if available
                if i < locationData.count {
                    if let heartRate = locationData[i]["heartRate"] as? Double, heartRate > 0 {
                        splitHeartRates.append(heartRate)
                    }
                    
                    if let cadence = locationData[i]["cadence"] as? Double, cadence > 0 {
                        splitCadences.append(cadence)
                    }
                }
            } else {
                continue
            }
            
            // Check if we've crossed a mile/km milestone
            if cumulativeDistance >= Double(currentMile) * unitDistance {
                // Calculate time taken for this split 
                var splitTime: TimeInterval
                
                if useDistanceBasedEstimation {
                    // Calculate time based on distance and estimated pace
                    let splitDistance = cumulativeDistance - lastMilestoneDistance
                    splitTime = splitDistance * estimatedPacePerMeter
                    print("RunAnalysisViewController: Split \(currentMile) - ESTIMATED time: \(splitTime) seconds")
                } else {
                    // Use timestamp-based calculation
                    splitTime = currentLocation.timestamp.timeIntervalSince(lastMilestoneTimePoint)
                    print("RunAnalysisViewController: Split \(currentMile) - time elapsed: \(splitTime) seconds")
                }
                
                // Calculate split distance (should be close to unitDistance but may have some excess)
                let splitDistance = cumulativeDistance - lastMilestoneDistance
                
                print("RunAnalysisViewController: Split \(currentMile) - distance: \(splitDistance)m, time: \(splitTime)s")
                
                // Calculate pace for this split (minutes per unit distance)
                // Only calculate if we have a meaningful distance and time
                if splitDistance > 0 && splitTime > 0 {
                    let paceSeconds = (splitTime / splitDistance) * unitDistance
                    let paceMinutes = paceSeconds / 60.0
                    
                    print("RunAnalysisViewController: Split \(currentMile) - pace: \(paceMinutes) min/\(unitName)")
                    
                    // Calculate average heart rate for this split
                    let avgHeartRate = splitHeartRates.isEmpty ? nil : splitHeartRates.reduce(0, +) / Double(splitHeartRates.count)
                    
                    // Calculate average cadence for this split
                    let avgCadence = splitCadences.isEmpty ? nil : splitCadences.reduce(0, +) / Double(splitCadences.count)
                    
                    // Only add the split if the pace is reasonable (filter out errors)
                    if useDistanceBasedEstimation || (paceMinutes > 3 && paceMinutes < 30) {
                        splits.append((mile: currentMile, pace: paceMinutes, time: splitTime, avgHeartRate: avgHeartRate, avgCadence: avgCadence))
                        print("RunAnalysisViewController: Added split \(currentMile) with pace \(paceMinutes) min/\(unitName)")
                    } else {
                        print("RunAnalysisViewController: Skipping split \(currentMile) with unreasonable pace: \(paceMinutes) min/\(unitName)")
                    }
                } else {
                    print("RunAnalysisViewController: Invalid split time (\(splitTime)s) or distance (\(splitDistance)m)")
                }
                
                // Update milestone tracking
                lastMilestoneDistance = cumulativeDistance
                lastMilestoneTimePoint = currentLocation.timestamp
                currentMile += 1
                
                // Reset heart rate and cadence collections for next split
                splitHeartRates = []
                splitCadences = []
                splitStartIndex = i
            }
        }
        
        // Add final partial split if significant distance covered
        if (cumulativeDistance - lastMilestoneDistance) > (unitDistance * 0.2) {
            let finalDistance = cumulativeDistance - lastMilestoneDistance
            if finalDistance > 100 { // At least 100 meters
                var finalTime: TimeInterval
                
                if useDistanceBasedEstimation {
                    // Calculate time based on distance and estimated pace
                    finalTime = finalDistance * estimatedPacePerMeter
                    print("RunAnalysisViewController: Final partial split - ESTIMATED time: \(finalTime) seconds")
                } else {
                    // Use timestamp-based calculation
                    finalTime = sortedLocations.last!.timestamp.timeIntervalSince(lastMilestoneTimePoint)
                }
                
                print("RunAnalysisViewController: Final partial split - distance: \(finalDistance)m, time: \(finalTime)s")
                
                // Calculate pace for partial split
                if finalTime > 0 {
                    let paceSeconds = (finalTime / finalDistance) * unitDistance
                    let paceMinutes = paceSeconds / 60.0
                    
                    print("RunAnalysisViewController: Final split pace: \(paceMinutes) min/\(unitName)")
                    
                    // Calculate average heart rate for this final split
                    let avgHeartRate = splitHeartRates.isEmpty ? nil : splitHeartRates.reduce(0, +) / Double(splitHeartRates.count)
                    
                    // Calculate average cadence for this final split
                    let avgCadence = splitCadences.isEmpty ? nil : splitCadences.reduce(0, +) / Double(splitCadences.count)
                    
                    // Only add if the pace is reasonable
                    if useDistanceBasedEstimation || (paceMinutes > 3 && paceMinutes < 30) {
                        splits.append((mile: currentMile, pace: paceMinutes, time: finalTime, avgHeartRate: avgHeartRate, avgCadence: avgCadence))
                        print("RunAnalysisViewController: Added final split with pace \(paceMinutes) min/\(unitName)")
                    } else {
                        print("RunAnalysisViewController: Skipping final split with unreasonable pace: \(paceMinutes) min/\(unitName)")
                    }
                }
            }
        }
        
        print("RunAnalysisViewController: Found \(splits.count) valid splits")
        
        // If we still have no valid splits, attempt to generate them from the total run data
        if splits.isEmpty && totalDistance > 0 {
            print("RunAnalysisViewController: No valid splits found. Creating estimated splits from total run data.")
            
            // Calculate number of complete units (miles or km)
            let completeUnits = Int(totalDistance / unitDistance)
            
            // Determine run duration from metadata if timestamps are invalid
            var runDuration = totalDuration
            if runDuration < 10 && completeUnits > 0 {
                if let outdoorRun = run as? RunLog, let durationString = outdoorRun.duration {
                    // Parse duration string (format like "1:23:45")
                    let durationComponents = durationString.components(separatedBy: ":")
                    
                    if durationComponents.count == 3 {
                        if let hours = Double(durationComponents[0]),
                           let mins = Double(durationComponents[1]),
                           let secs = Double(durationComponents[2]) {
                            runDuration = hours * 3600 + mins * 60 + secs
                            print("RunAnalysisViewController: Using run duration from metadata: \(runDuration) seconds")
                        }
                    } else if durationComponents.count == 2 {
                        if let mins = Double(durationComponents[0]),
                           let secs = Double(durationComponents[1]) {
                            runDuration = mins * 60 + secs
                            print("RunAnalysisViewController: Using run duration from metadata: \(runDuration) seconds")
                        }
                    }
                }
            }
            
            if completeUnits > 0 && runDuration > 10 {
                // Calculate average pace in minutes per unit
                let averagePaceSeconds = (runDuration / totalDistance) * unitDistance
                let averagePaceMinutes = averagePaceSeconds / 60.0
                
                // Calculate average split time
                let averageSplitTime = runDuration / Double(completeUnits)
                
                print("RunAnalysisViewController: Estimating \(completeUnits) splits with avg pace: \(averagePaceMinutes) min/\(unitName)")
                
                // Get overall average heart rate and cadence if available
                var overallAvgHR: Double? = nil
                var overallAvgCadence: Double? = nil
                
                if let outdoorRun = run as? RunLog {
                    overallAvgHR = outdoorRun.avgHeartRate
                    overallAvgCadence = outdoorRun.avgCadence
                }
                
                // Create estimated splits based on the average pace
                for i in 1...completeUnits {
                    if averagePaceMinutes > 3 && averagePaceMinutes < 30 {
                        splits.append((mile: i, pace: averagePaceMinutes, time: averageSplitTime, avgHeartRate: overallAvgHR, avgCadence: overallAvgCadence))
                    }
                }
                
                print("RunAnalysisViewController: Created \(splits.count) estimated splits from total run data")
            }
        }
        
        return splits
    }

    private func formatMileSplitTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    private func formatSpeed(_ speed: Double?) -> String {
        if let speed = speed, speed > 0 {
            // Convert speed (m/s) to mph or km/h based on user preferences
            let useMetric = UserPreferences.shared.useMetricSystem
            if useMetric {
                // Convert to km/h (1 m/s = 3.6 km/h)
                let kmh = speed * 3.6
                return String(format: "%.1f km/h", kmh)
            } else {
                // Convert to mph (1 m/s = 2.23694 mph)
                let mph = speed * 2.23694
                return String(format: "%.1f mph", mph)
            }
        }
        
        // Calculate from route if not available
        if routeLocations.count > 1 {
            var maxSpeedMps: Double = 0
            for location in routeLocations {
                if location.speed > maxSpeedMps {
                    maxSpeedMps = location.speed
                }
            }
            
            if maxSpeedMps > 0 {
                // Convert speed (m/s) to mph or km/h based on user preferences
                let useMetric = UserPreferences.shared.useMetricSystem
                if useMetric {
                    // Convert to km/h (1 m/s = 3.6 km/h)
                    let kmh = maxSpeedMps * 3.6
                    return String(format: "%.1f km/h", kmh)
                } else {
                    // Convert to mph (1 m/s = 2.23694 mph)
                    let mph = maxSpeedMps * 2.23694
                    return String(format: "%.1f mph", mph)
                }
            }
        }
        
        let useMetric = UserPreferences.shared.useMetricSystem
        return useMetric ? "-- km/h" : "-- mph"
    }

    private func formatCadence(_ cadence: Double?) -> String {
        if let cadence = cadence, cadence > 0 {
            return String(format: "%.0f spm", cadence)
        }
        
        // Calculate from route if not available
        if routeLocations.count > 1 {
            var validCadences = 0
            var totalCadence: Double = 0
            
            // CLLocation doesn't have a cadence property
            // Instead, we need to get cadence from locationData
            if let outdoorRun = run as? RunLog, let locationData = outdoorRun.locationData {
                // Make sure locationData has enough entries
                let count = min(routeLocations.count, locationData.count)
                
                for i in 0..<count {
                    if let cadence = locationData[i]["cadence"] as? Double, cadence > 0 {
                        totalCadence += cadence
                        validCadences += 1
                    }
                }
                
                if validCadences > 0 {
                    let avgCadence = totalCadence / Double(validCadences)
                    return String(format: "%.0f spm", avgCadence)
                }
            } else if let indoorRun = run as? IndoorRunLog, let treadmillData = indoorRun.treadmillDataPoints {
                for dataPoint in treadmillData {
                    if dataPoint.cadence > 0 {
                        totalCadence += cadence ?? 0
                        validCadences += 1
                    }
                }
                
                if validCadences > 0 {
                    let avgCadence = totalCadence / Double(validCadences)
                    return String(format: "%.0f spm", avgCadence)
                }
            }
        }
        
        return "-- spm"
    }

    // MARK: - Chart Components
    
    private var heartRateChartView: some View {
        Group {
            if let heartRateData = extractHeartRateData(), !heartRateData.isEmpty {
                // Normalize heart rate data to avoid extreme values
                let normalizedHeartRates = heartRateData.map { max(0, min($0, 220)) }
                let timeInterval = getChartTimeInterval(normalizedHeartRates.count)
                
                Chart {
                    ForEach(Array(normalizedHeartRates.enumerated()), id: \.offset) { index, heartRate in
                        LineMark(
                            x: .value("Time", Double(index) * timeInterval),
                            y: .value("Heart Rate", heartRate)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: 0xFF375F),
                                    Color(hex: 0xFF3B30)
                                ]), 
                                startPoint: .leading, 
                                endPoint: .trailing
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        
                        AreaMark(
                            x: .value("Time", Double(index) * timeInterval),
                            y: .value("Heart Rate", heartRate)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: 0xFF375F).opacity(0.4),
                                    Color(hex: 0xFF3B30).opacity(0.1)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.white.opacity(0.3))
                        AxisValueLabel() {
                            if let heartRate = value.as(Double.self) {
                                Text("\(Int(heartRate)) bpm")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.white.opacity(0.3))
                        AxisValueLabel() {
                            if let time = value.as(Double.self) {
                                Text(formatTimeValue(time))
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: 0xFF3B30))
                                .frame(width: 8, height: 8)
                            Text("BPM")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        if let avgHR = getHeartRateAverage(), let maxHR = getHeartRateMax() {
                            HStack(spacing: 8) {
                                Text("Avg: \(avgHR) bpm")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                Text("Max: \(maxHR) bpm")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                    .padding(12)
                }
                .animation(.easeInOut, value: selectedTab)
            } else {
                Text("No heart rate data available")
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var speedChartView: some View {
        Chart {
            if let indoorRun = run as? IndoorRunLog, let treadmillData = indoorRun.treadmillDataPoints, !treadmillData.isEmpty {
                // Extract speed data from treadmill data points
                // Use direct property access instead of subscripts
                ForEach(Array(treadmillData.enumerated()), id: \.offset) { index, dataPoint in
                    LineMark(
                        x: .value("Time", Double(index) * getChartTimeInterval(treadmillData.count)),
                        y: .value("Speed", dataPoint.speed)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: 0xFF9500),
                                Color(hex: 0xFF3B30)
                            ]), 
                            startPoint: .leading, 
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    
                    AreaMark(
                        x: .value("Time", Double(index) * getChartTimeInterval(treadmillData.count)),
                        y: .value("Speed", dataPoint.speed)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: 0xFF9500).opacity(0.4),
                                Color(hex: 0xFF3B30).opacity(0.1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let speed = value.as(Double.self) {
                        let useMetric = UserPreferences.shared.useMetricSystem
                        // Convert m/s to km/h or mph
                        let displaySpeed = useMetric ? speed * 3.6 : speed * 2.23694
                        Text(String(format: "%.1f %@", displaySpeed, useMetric ? "km/h" : "mph"))
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisValueLabel {
                    if let time = value.as(Double.self) {
                        Text(formatTimeValue(time))
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: 0xFF9500))
                        .frame(width: 8, height: 8)
                    Text("Speed (\(UserPreferences.shared.useMetricSystem ? "km/h" : "mph"))")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                if let indoorRun = run as? IndoorRunLog, let avgSpeed = indoorRun.avgSpeed {
                    let useMetric = UserPreferences.shared.useMetricSystem
                    // Convert to preferred units if necessary
                    let displaySpeed = useMetric ? avgSpeed * 1.60934 : avgSpeed
                    Text("Avg: \(String(format: "%.1f", displaySpeed)) \(useMetric ? "km/h" : "mph")")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(12)
        }
        .animation(.easeInOut, value: selectedTab)
    }

    private var inclineChartView: some View {
        Group {
            if let indoorRun = run as? IndoorRunLog, 
               let treadmillData = indoorRun.treadmillDataPoints,
               !treadmillData.isEmpty {
                
                Chart {
                    ForEach(Array(treadmillData.enumerated()), id: \.offset) { index, dataPoint in
                        // Assuming the TreadmillDataPoint has an incline property
                        // If it doesn't, you'll need to modify this to use the correct property
                        let inclineValue = dataPoint.cadence // Using cadence as a placeholder - replace with actual incline property if available
                        
                        LineMark(
                            x: .value("Time", Double(index) * getChartTimeInterval(treadmillData.count)),
                            y: .value("Incline", inclineValue)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: 0x5856D6),
                                    Color(hex: 0x5AC8FA)
                                ]), 
                                startPoint: .leading, 
                                endPoint: .trailing
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        
                        AreaMark(
                            x: .value("Time", Double(index) * getChartTimeInterval(treadmillData.count)),
                            y: .value("Incline", inclineValue)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: 0x5856D6).opacity(0.4),
                                    Color(hex: 0x5AC8FA).opacity(0.1)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.white.opacity(0.3))
                        AxisValueLabel() {
                            if let incline = value.as(Double.self) {
                                Text(String(format: "%.1f%%", incline))
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.white.opacity(0.3))
                        AxisValueLabel() {
                            if let time = value.as(Double.self) {
                                Text(formatTimeValue(time))
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: 0x5AC8FA))
                                .frame(width: 8, height: 8)
                            Text("Incline (%)")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        if let avgIncline = indoorRun.avgIncline, let maxIncline = indoorRun.maxIncline {
                            HStack(spacing: 8) {
                                Text(String(format: "Avg: %.1f%%", avgIncline))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                Text(String(format: "Max: %.1f%%", maxIncline))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                    .padding(12)
                }
                .animation(.easeInOut, value: selectedTab)
            } else {
                Text("No incline data available")
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // Helper methods for formatting elevation values
    private func elevationGainFormatted(_ runLog: RunLog) -> String {
        if let elevationGain = runLog.elevationGain {
            return elevationGain
        }
        
        // Calculate from route if not available
        var totalElevationGain: Double = 0
        if routeLocations.count > 1 {
            for i in 1..<routeLocations.count {
                let current = routeLocations[i]
                let previous = routeLocations[i-1]
                let elevationChange = current.altitude - previous.altitude
                if elevationChange > 0 {
                    totalElevationGain += elevationChange
                }
            }
        }
        
        return UserPreferences.formatElevationWithPreferredUnit(elevation: totalElevationGain)
    }
    
    private func elevationLossFormatted(_ runLog: RunLog) -> String {
        if let elevationLoss = runLog.elevationLoss {
            return elevationLoss
        }
        
        // Calculate from route if not available
        var totalElevationLoss: Double = 0
        if routeLocations.count > 1 {
            for i in 1..<routeLocations.count {
                let current = routeLocations[i]
                let previous = routeLocations[i-1]
                let elevationChange = current.altitude - previous.altitude
                if elevationChange < 0 {
                    totalElevationLoss += abs(elevationChange)
                }
            }
        }
        
        return UserPreferences.formatElevationWithPreferredUnit(elevation: totalElevationLoss)
    }
}

// MARK: - Helper Structures

struct LocationCoordinate: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Extensions

extension Color {
    init(hex: Int, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

// Define a custom button style for the buttons
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// Add this struct at the bottom of the file, after all other code
// For shimmer effect on loading or for highlights

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: phase - 0.2),
                            .init(color: .white.opacity(0.3), location: phase),
                            .init(color: .clear, location: phase + 0.2)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .mask(content)
                    .blur(radius: 3)
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Map Views

struct MapPolylineOverlay: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    
    init(locations: [CLLocation]) {
        self.coordinates = locations.map { $0.coordinate }
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isUserInteractionEnabled = false
        mapView.delegate = context.coordinator
        
        // Create and add the polyline
        if coordinates.count > 1 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
            
            // Set the visible region to match parent map region
            let region = MKCoordinateRegion(
                coordinates: coordinates,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            )
            mapView.setRegion(region, animated: false)
        }
        
        mapView.alpha = 1.0
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Update polyline if needed
        uiView.removeOverlays(uiView.overlays)
        
        if coordinates.count > 1 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            uiView.addOverlay(polyline)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 0.29, green: 0.85, blue: 0.39, alpha: 1.0) // Green
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

extension MKCoordinateRegion {
    init(coordinates: [CLLocationCoordinate2D], latitudinalMeters: CLLocationDistance = 1000, longitudinalMeters: CLLocationDistance = 1000) {
        guard !coordinates.isEmpty else {
            self = MKCoordinateRegion()
            return
        }
        
        var minLat = coordinates[0].latitude
        var maxLat = minLat
        var minLon = coordinates[0].longitude
        var maxLon = minLon
        
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        // Calculate span with padding
        let latDelta = (maxLat - minLat) * 1.2 // Add 20% padding
        let lonDelta = (maxLon - minLon) * 1.2
        
        self.init(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: max(0.005, latDelta),
                longitudeDelta: max(0.005, lonDelta)
            )
        )
    }
}

struct MapProgressMarker: UIViewRepresentable {
    let locations: [CLLocation]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isUserInteractionEnabled = false
        mapView.delegate = context.coordinator
        
        // Make this map view transparent - we're only using it for the marker
        mapView.alpha = 0.999 // Almost invisible but allows interactions
        mapView.backgroundColor = .clear
        
        // Set up the map region to match the parent map
        let coordinates = locations.map { $0.coordinate }
        if coordinates.count > 1 {
            let region = MKCoordinateRegion(coordinates: coordinates)
            mapView.setRegion(region, animated: false)
        }
        
        // Start the animation
        context.coordinator.startAnimation(for: mapView, locations: locations)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Reset animation if needed
        if context.coordinator.isAnimating == false {
            context.coordinator.startAnimation(for: uiView, locations: locations)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var animationTimer: Timer?
        var currentIndex: Int = 0
        var lastDate = Date()
        var markerAnnotation: MKPointAnnotation?
        var isAnimating = false
        var userAnnotation: RouteUserAnnotation?
        var routeLocations: [CLLocation] = []
        private var animationProgress: Double = 0.0
        private var animationDuration: TimeInterval = 15.0 // Seconds to complete the animation
        
        deinit {
            stopAnimation()
        }
        
        func startAnimation(for mapView: MKMapView, locations: [CLLocation]) {
            stopAnimation()
            
            guard locations.count > 1 else { return }
            
            // Store the route locations
            self.routeLocations = locations
            
            // Create marker annotation
            let marker = MKPointAnnotation()
            marker.coordinate = locations.first!.coordinate
            mapView.addAnnotation(marker)
            markerAnnotation = marker
            
            // Create user annotation for animated movement
            let user = RouteUserAnnotation()
            user.coordinate = locations.first!.coordinate
            user.heading = 0
            mapView.addAnnotation(user)
            userAnnotation = user
            
            currentIndex = 0
            animationProgress = 0.0
            isAnimating = true
            
            // Start animation timer - update at 60fps
            animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
                guard let self = self, 
                      let userAnnotation = self.userAnnotation, 
                      !self.routeLocations.isEmpty else { 
                    self?.isAnimating = false
                    return 
                }
                
                // Update progress (complete route in animationDuration seconds)
                self.animationProgress += 1.0 / (self.animationDuration * 60.0) // 60fps
                
                // Wrap around when complete
                if self.animationProgress >= 1.0 {
                    self.animationProgress = 0.0
                }
                
                // Calculate position based on progress
                let position = self.calculatePosition(at: self.animationProgress)
                
                // Update annotation position directly without UIView animation for smoother movement
                userAnnotation.coordinate = position.coordinate
                userAnnotation.heading = position.heading
                
                // Also update the marker annotation for backward compatibility
                if let marker = self.markerAnnotation {
                    marker.coordinate = position.coordinate
                }
            }
            
            self.lastDate = Date()
        }
        
        func updateAnnotationPosition(for mapView: MKMapView, locations: [CLLocation], progress: Double) {
            guard let marker = markerAnnotation, locations.count > 1 else { return }
            
            // Convert progress to a position along the route
            let targetDistance = progress * totalDistance(for: locations)
            var currentDistance: Double = 0
            
            // Find the segment we're on
            for i in 0..<(locations.count - 1) {
                let segmentDistance = locations[i].distance(from: locations[i+1])
                
                if currentDistance + segmentDistance >= targetDistance {
                    // We're in this segment
                    let segmentProgress = (targetDistance - currentDistance) / segmentDistance
                    
                    // Interpolate between the two points
                    let startCoord = locations[i].coordinate
                    let endCoord = locations[i+1].coordinate
                    
                    let newLat = startCoord.latitude + (endCoord.latitude - startCoord.latitude) * segmentProgress
                    let newLng = startCoord.longitude + (endCoord.longitude - startCoord.longitude) * segmentProgress
                    
                    // Update the marker position
                    marker.coordinate = CLLocationCoordinate2D(latitude: newLat, longitude: newLng)
                    return
                }
                
                currentDistance += segmentDistance
            }
            
            // If we get here, we're at the end
            marker.coordinate = locations.last!.coordinate
        }
        
        func totalDistance(for locations: [CLLocation]) -> Double {
            var distance: Double = 0
            for i in 0..<(locations.count - 1) {
                distance += locations[i].distance(from: locations[i+1])
            }
            return distance
        }
        
        func stopAnimation() {
            animationTimer?.invalidate()
            animationTimer = nil
            isAnimating = false
        }
        
        // Delegate method to customize marker appearance
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "progressMarker"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                
                // Create custom marker view
                let markerView = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
                
                // Main circle
                let circleView = UIView(frame: CGRect(x: 5, y: 5, width: 10, height: 10))
                circleView.backgroundColor = UIColor(red: 1, green: 0.23, blue: 0.19, alpha: 1.0) // Red
                circleView.layer.cornerRadius = 5
                circleView.layer.borderWidth = 2
                circleView.layer.borderColor = UIColor.white.cgColor
                circleView.layer.shadowColor = UIColor.black.cgColor
                circleView.layer.shadowOpacity = 0.3
                circleView.layer.shadowOffset = CGSize(width: 0, height: 1)
                circleView.layer.shadowRadius = 2
                
                // Pulsing effect
                let pulseView = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
                pulseView.backgroundColor = UIColor(red: 1, green: 0.23, blue: 0.19, alpha: 0.4) // Red with opacity
                pulseView.layer.cornerRadius = 10
                
                // Add pulse animation
                let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
                pulseAnimation.duration = 1.5
                pulseAnimation.fromValue = 1.0
                pulseAnimation.toValue = 1.8
                pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
                pulseAnimation.autoreverses = false
                pulseAnimation.repeatCount = Float.infinity
                
                let opacityAnimation = CABasicAnimation(keyPath: "opacity")
                opacityAnimation.duration = 1.5
                opacityAnimation.fromValue = 0.6
                opacityAnimation.toValue = 0
                opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
                opacityAnimation.autoreverses = false
                opacityAnimation.repeatCount = Float.infinity
                
                let animationGroup = CAAnimationGroup()
                animationGroup.animations = [pulseAnimation, opacityAnimation]
                animationGroup.duration = 1.5
                animationGroup.repeatCount = Float.infinity
                
                pulseView.layer.add(animationGroup, forKey: "pulse")
                
                markerView.addSubview(pulseView)
                markerView.addSubview(circleView)
                
                view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
                view?.addSubview(markerView)
                view?.centerOffset = CGPoint(x: 0, y: -10) // Adjust so the marker is centered
            } else {
                view?.annotation = annotation
            }
            
            return view
        }
        
        // Calculate position along the route based on progress
        private func calculatePosition(at progress: Double) -> (coordinate: CLLocationCoordinate2D, heading: Double) {
            guard !routeLocations.isEmpty else { 
                return (CLLocationCoordinate2D(latitude: 0, longitude: 0), 0) 
            }
            
            // For a single point, return that point
            if routeLocations.count == 1 {
                return (routeLocations[0].coordinate, 0)
            }
            
            // Find position by interpolating between points
            let targetIndex = progress * Double(routeLocations.count - 1)
            let lowerIndex = min(Int(floor(targetIndex)), routeLocations.count - 2)
            let upperIndex = min(lowerIndex + 1, routeLocations.count - 1)
            let segmentProgress = targetIndex - Double(lowerIndex)
            
            // Get coordinates
            let fromCoord = routeLocations[lowerIndex].coordinate
            let toCoord = routeLocations[upperIndex].coordinate
            
            // Interpolate between them
            let lat = fromCoord.latitude + segmentProgress * (toCoord.latitude - fromCoord.latitude)
            let lon = fromCoord.longitude + segmentProgress * (toCoord.longitude - fromCoord.longitude)
            
            // Calculate heading
            let heading = calculateHeading(from: fromCoord, to: toCoord)
            
            return (CLLocationCoordinate2D(latitude: lat, longitude: lon), heading)
        }
        
        // Calculate heading (bearing) between two coordinates
        private func calculateHeading(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
            let lat1 = from.latitude * .pi / 180
            let lon1 = from.longitude * .pi / 180
            let lat2 = to.latitude * .pi / 180
            let lon2 = to.longitude * .pi / 180
            
            let dLon = lon2 - lon1
            let y = sin(dLon) * cos(lat2)
            let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
            var heading = atan2(y, x) * 180 / .pi
            
            // Normalize to 0-360
            if heading < 0 {
                heading += 360
            }
            
            return heading
        }
    }
}

struct EnhancedMapOverlay: View {
    let locations: [CLLocation]
    let progress: Double
    let useAnimatedMarker: Bool
    
    @State private var animationPhase: CGFloat = 0
    @State private var showStats: Bool = false
    
    init(locations: [CLLocation], progress: Double = 1.0, useAnimatedMarker: Bool = true) {
        self.locations = locations
        self.progress = progress
        self.useAnimatedMarker = useAnimatedMarker
    }
    
    var body: some View {
        ZStack {
            // Base route line
            if locations.count >= 2 {
                PolylineShape(coordinates: locations.map { $0.coordinate })
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: 0x4CD964), Color(hex: 0x007AFF)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 2)
            }
            
            // Glowing effect on the route
            if locations.count >= 2 {
                PolylineShape(coordinates: locations.map { $0.coordinate })
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 3)
                    .opacity(0.5)
            }
            
            // Animated marker along the route if enabled
            if useAnimatedMarker, !locations.isEmpty {
                let markerPosition = calculateMarkerPosition(progress: animationPhase)
                
                VStack(spacing: 0) {
                    // F1-inspired marker
                    ZStack {
                        // Outer glow
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 30, height: 30)
                            .blur(radius: 8)
                        
                        // Main marker
                        Image(systemName: "car.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color(hex: 0x007AFF))
                                    .frame(width: 24, height: 24)
                            )
                            .shadow(color: Color(hex: 0x007AFF).opacity(0.7), radius: 10, x: 0, y: 0)
                        
                        // Speed lines
                        ForEach(0..<3) { i in
                            Rectangle()
                                .fill(Color.white.opacity(0.6))
                                .frame(width: CGFloat(i + 1) * 3, height: 1)
                                .offset(x: -CGFloat(i + 1) * 5 - 12)
                                .blur(radius: 1)
                        }
                    }
                    .rotationEffect(.degrees(calculateMarkerDirection(progress: animationPhase)))
                    
                    // Stats popup when showing
                    if showStats {
                        statsPopup(at: animationPhase)
                            .offset(y: -50)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .position(markerPosition)
                .onAppear {
                    // Animate the marker along the path
                    withAnimation(Animation.linear(duration: 10).repeatForever(autoreverses: false)) {
                        animationPhase = 1.0
                    }
                    
                    // Toggle stats display periodically
                    withAnimation {
                        showStats = true
                    }
                    
                    // Timer to toggle stats visibility
                    Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                        withAnimation {
                            showStats.toggle()
                        }
                    }
                }
            }
        }
    }
    
    // Calculate the marker position along the path based on progress
    private func calculateMarkerPosition(progress: CGFloat) -> CGPoint {
        guard !locations.isEmpty else { return .zero }
        
        if locations.count == 1 {
            return CGPoint(x: locations[0].coordinate.longitude, y: locations[0].coordinate.latitude)
        }
        
        let targetDistance = progress * totalDistance(for: locations)
        var currentDistance: Double = 0
        
        for i in 0..<(locations.count - 1) {
            let from = locations[i]
            let to = locations[i + 1]
            let segmentDistance = from.distance(from: to)
            
            if currentDistance + segmentDistance >= targetDistance {
                // We found the segment where the marker should be
                let segmentProgress = (targetDistance - currentDistance) / segmentDistance
                
                // Linear interpolation between the two points
                let lat = from.coordinate.latitude + segmentProgress * (to.coordinate.latitude - from.coordinate.latitude)
                let lon = from.coordinate.longitude + segmentProgress * (to.coordinate.longitude - from.coordinate.longitude)
                
                return CGPoint(x: lon, y: lat)
            }
            
            currentDistance += segmentDistance
        }
        
        // Default to the last point if we get here
        let last = locations.last!
        return CGPoint(x: last.coordinate.longitude, y: last.coordinate.latitude)
    }
    
    // Calculate the direction the marker should be pointing
    private func calculateMarkerDirection(progress: CGFloat) -> Double {
        guard locations.count >= 2 else { return 0 }
        
        let targetDistance = progress * totalDistance(for: locations)
        var currentDistance: Double = 0
        
        for i in 0..<(locations.count - 1) {
            let from = locations[i]
            let to = locations[i + 1]
            let segmentDistance = from.distance(from: to)
            
            if currentDistance + segmentDistance >= targetDistance {
                // Get bearing between these two points
                return bearing(from: from.coordinate, to: to.coordinate)
            }
            
            currentDistance += segmentDistance
        }
        
        // Default direction (last segment)
        if locations.count >= 2 {
            let secondLast = locations[locations.count - 2]
            let last = locations.last!
            return bearing(from: secondLast.coordinate, to: last.coordinate)
        }
        
        return 0
    }
    
    // Helper to calculate bearing between two coordinates
    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi
        
        return bearing + 90 // Adjust for the car icon orientation
    }
    
    // Stats popup view
    private func statsPopup(at progress: CGFloat) -> some View {
        let index = min(Int(progress * Double(locations.count - 1)), locations.count - 1)
        let location = locations[index]
        
        // Calculate current stats for display
        let speed = location.speed > 0 ? location.speed : 3.0 // Default to reasonable speed if not available
        let altitude = location.altitude
        
        // Format according to user preferences
        let useMetric = UserPreferences.shared.useMetricSystem
        let speedValue = useMetric ? speed * 3.6 : speed * 2.23694 // Convert m/s to km/h or mph
        let speedUnit = useMetric ? "km/h" : "mph"
        let altitudeValue = useMetric ? altitude : altitude * 3.28084 // Convert m to ft
        let altitudeUnit = useMetric ? "m" : "ft"
        
        return VStack(spacing: 4) {
            Text("STATS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 2)
            
            HStack(spacing: 10) {
                VStack(alignment: .leading) {
                    Text("SPEED")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text(String(format: "%.1f %@", speedValue, speedUnit))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading) {
                    Text("ALTITUDE")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text(String(format: "%.0f %@", altitudeValue, altitudeUnit))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.5), radius: 5, x: 0, y: 2)
    }
    
    // Calculate total distance along the path
    private func totalDistance(for locations: [CLLocation]) -> Double {
        guard locations.count >= 2 else { return 0 }
        
        var distance: Double = 0
        for i in 0..<(locations.count - 1) {
            distance += locations[i].distance(from: locations[i + 1])
        }
        return distance
    }
}

// Custom UIViewRepresentable for MKMapView to ensure proper route display
struct RunAnalysisRouteMapView: UIViewRepresentable {
    let locations: [CLLocation]
    var region: MKCoordinateRegion
    var routeColor: LinearGradient
    
    // Pass segment info through the coordinator to avoid immutability issues
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        mapView.showsCompass = true
        mapView.mapType = .standard
        mapView.pointOfInterestFilter = .excludingAll
        
        // Process locations to filter out inaccurate points
        let filteredLocations = filterLocations(locations)
        
        // Add route overlay as multiple segments for better visualization
        if filteredLocations.count >= 2 {
            // Use a single continuous line connecting all exact coordinates
            let coordinates = filteredLocations.map { $0.coordinate }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline, level: .aboveRoads)
            
            // Add start and end markers
            if let first = filteredLocations.first, let last = filteredLocations.last {
                // Check if this is a circular route (start and end are very close)
                let isCircularRoute = first.distance(from: last) < 50 // Within 50 meters
                
                // Always add a start marker
                let startAnnotation = RunAnalysisRouteAnnotation(coordinate: first.coordinate, type: .start)
                mapView.addAnnotation(startAnnotation)
                
                // For circular routes, use the same location but different annotation type
                if isCircularRoute {
                    // Place the finish slightly offset for visibility when routes are circular
                    let finishCoord = CLLocationCoordinate2D(
                        latitude: first.coordinate.latitude + 0.00005, 
                        longitude: first.coordinate.longitude + 0.00005
                    )
                    let endAnnotation = RunAnalysisRouteAnnotation(
                        coordinate: finishCoord, 
                        type: .end, 
                        value: "Same as Start"
                    )
                    mapView.addAnnotation(endAnnotation)
                } else {
                    // Regular end marker for non-circular routes
                    let endAnnotation = RunAnalysisRouteAnnotation(coordinate: last.coordinate, type: .end)
                    mapView.addAnnotation(endAnnotation)
                }
                
                // Add elevation and pace markers if we have enough data points
                if filteredLocations.count >= 10 {
                    addSignificantPointMarkers(to: mapView, locations: filteredLocations)
                }
                
                // Add animated user marker that follows the route
                addAnimatedUserMarker(to: mapView, locations: filteredLocations, coordinator: context.coordinator)
            }
            
            // Calculate and set optimal region to show the entire route
            setOptimalRegion(for: mapView, locations: filteredLocations)
        } else {
            // Just set the provided region if we don't have enough locations
        mapView.setRegion(region, animated: false)
        }
        
        return mapView
    }
    
    // Add an animated marker that travels along the route
    private func addAnimatedUserMarker(to mapView: MKMapView, locations: [CLLocation], coordinator: Coordinator) {
        guard locations.count >= 2 else { return }
        
        // Create user annotation
        let userAnnotation = RouteUserAnnotation()
        userAnnotation.coordinate = locations.first!.coordinate
        userAnnotation.title = "You"
        
        // Add to map
        mapView.addAnnotation(userAnnotation)
        
        // Store reference in coordinator
        coordinator.userAnnotation = userAnnotation
        coordinator.routeLocations = locations
        
        // Start animation
        coordinator.startUserAnimation()
    }

    // Filter out inaccurate or redundant location points
    private func filterLocations(_ locations: [CLLocation]) -> [CLLocation] {
        guard locations.count > 2 else { return locations }
        
        var filteredLocations: [CLLocation] = []
        
        // Always include first point
        filteredLocations.append(locations.first!)
        
        // Filter criteria
        let minDistance: CLLocationDistance = 5 // Minimum 5 meters between points
        let maxAccuracy: CLLocationAccuracy = 30 // Maximum acceptable accuracy (lower is better)
        let maxSpeed: CLLocationSpeed = 10 // Maximum realistic running speed (m/s)
        
        for i in 1..<locations.count-1 {
            let prevLocation = filteredLocations.last!
            let currentLocation = locations[i]
            
            // Skip if accuracy is poor
            if currentLocation.horizontalAccuracy > maxAccuracy {
                continue
            }
            
            // Skip if too close to previous point
            let distance = currentLocation.distance(from: prevLocation)
            if distance < minDistance {
                continue
            }
            
            // Skip if speed between points is unrealistic
            if distance > 0 && currentLocation.timestamp.timeIntervalSince(prevLocation.timestamp) > 0 {
                let speed = distance / currentLocation.timestamp.timeIntervalSince(prevLocation.timestamp)
                if speed > maxSpeed {
                    continue
                }
            }
            
            // Check if the point creates a sharp angle with previous and next points
            if filteredLocations.count >= 1 && i < locations.count - 1 {
                let prevLoc = filteredLocations.last!
                let nextLoc = locations[i+1]
                
                // Calculate bearings
                let bearing1 = calculateBearing(from: prevLoc.coordinate, to: currentLocation.coordinate)
                let bearing2 = calculateBearing(from: currentLocation.coordinate, to: nextLoc.coordinate)
                
                // If the angle is too sharp (>90 degrees), skip this point
                let angleDiff = abs(bearing1 - bearing2)
                if angleDiff > 120 && angleDiff < 240 {
                    continue
                }
            }
            
            filteredLocations.append(currentLocation)
        }
        
        // Always include last point
        if locations.count > 1 && (filteredLocations.last != locations.last) {
            filteredLocations.append(locations.last!)
        }
        
        return filteredLocations
    }
    
    // Calculate bearing between two coordinates (in degrees)
    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var bearing = atan2(y, x) * 180 / .pi
        
        // Normalize to 0-360
        if bearing < 0 {
            bearing += 360
        }
        
        return bearing
    }
    
    // Add a continuous route for the whole path
    private func addContinuousRoute(to mapView: MKMapView, locations: [CLLocation]) {
        let isCircularRoute = locations.first?.distance(from: locations.last ?? locations.first!) ?? 0 < 50
        
        if isCircularRoute && locations.count > 10 {
            // For circular routes, create a slightly offset path for the second half
            let midIndex = locations.count / 2
            let firstHalf = Array(locations[0...midIndex])
            let secondHalf = Array(locations[midIndex...locations.count-1])
            
            // Outbound path
            let outboundCoordinates = firstHalf.map { $0.coordinate }
            let outboundPolyline = MKPolyline(coordinates: outboundCoordinates, count: outboundCoordinates.count)
            mapView.addOverlay(outboundPolyline, level: .aboveRoads)
            
            // Return path with slight offset for visibility
            var inboundCoordinates = secondHalf.map { location -> CLLocationCoordinate2D in
                // Calculate perpendicular offset - simplified approach
                // Find direction perpendicular to path
                let bearing = calculateBearing(from: locations.first!.coordinate, to: locations.last!.coordinate)
                let perpendicularBearing = (bearing + 90) * Double.pi / 180
                
                // Apply small offset (0.00005 degrees ≈ 5m)
                let offsetDistance = 0.00005
                let offsetLat = location.coordinate.latitude + offsetDistance * cos(perpendicularBearing)
                let offsetLon = location.coordinate.longitude + offsetDistance * sin(perpendicularBearing)
                
                return CLLocationCoordinate2D(latitude: offsetLat, longitude: offsetLon)
            }
            
            let inboundPolyline = MKPolyline(coordinates: inboundCoordinates, count: inboundCoordinates.count)
            mapView.addOverlay(inboundPolyline, level: .aboveRoads)
        } else {
            // Regular non-circular route
            let coordinates = locations.map { $0.coordinate }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline, level: .aboveRoads)
        }
    }
    
    // Add the route as multiple segments to show pace variations
    private func addRouteOverlays(to mapView: MKMapView, coordinator: Coordinator, locations: [CLLocation]) {
        // Exit if not enough locations
        guard locations.count >= 4 else { return }
        
        // Divide route into segments (fewer segments for shorter routes)
        let segmentCount = min(10, max(3, locations.count / 10))
        let segmentSize = locations.count / segmentCount
        
        for i in 0..<segmentCount {
            let startIdx = i * segmentSize
            let endIdx = min(startIdx + segmentSize, locations.count - 1)
            
            if endIdx > startIdx {
                let segmentLocations = Array(locations[startIdx...endIdx])
                let coordinates = segmentLocations.map { $0.coordinate }
                
                // Create a regular MKPolyline instead of subclassing
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                
                // Store the segment information in the coordinator
                coordinator.registerPolyline(polyline, segmentIndex: i, totalSegments: segmentCount)
                
                // Add the overlay to the map
                mapView.addOverlay(polyline, level: .aboveRoads)
            }
        }
    }
    
    // Calculate and set the optimal region to show the entire route
    private func setOptimalRegion(for mapView: MKMapView, locations: [CLLocation]) {
        // Find the bounding box
        var minLat = locations.first!.coordinate.latitude
        var maxLat = minLat
        var minLon = locations.first!.coordinate.longitude
        var maxLon = minLon
        
        for location in locations {
            minLat = min(minLat, location.coordinate.latitude)
            maxLat = max(maxLat, location.coordinate.latitude)
            minLon = min(minLon, location.coordinate.longitude)
            maxLon = max(maxLon, location.coordinate.longitude)
        }
        
        // Add padding (15% on each side)
        let latPadding = (maxLat - minLat) * 0.15
        let lonPadding = (maxLon - minLon) * 0.15
        
        minLat -= latPadding
        maxLat += latPadding
        minLon -= lonPadding
        maxLon += lonPadding
        
        // Create and set the region
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.005, maxLat - minLat),
            longitudeDelta: max(0.005, maxLon - minLon)
        )
        
        let region = MKCoordinateRegion(center: center, span: span)
        mapView.setRegion(region, animated: false)
    }
    
    // Add markers for significant points (highest elevation, fastest pace, etc)
    private func addSignificantPointMarkers(to mapView: MKMapView, locations: [CLLocation]) {
        // Find highest elevation point
        if let highestPoint = locations.max(by: { $0.altitude < $1.altitude }) {
            let highAnnotation = RunAnalysisRouteAnnotation(
                coordinate: highestPoint.coordinate,
                type: .highPoint,
                value: String(format: "%.0f m", highestPoint.altitude)
            )
            mapView.addAnnotation(highAnnotation)
        }
        
        // Find lowest elevation point
        if let lowestPoint = locations.min(by: { $0.altitude < $1.altitude }) {
            let lowAnnotation = RunAnalysisRouteAnnotation(
                coordinate: lowestPoint.coordinate,
                type: .lowPoint,
                value: String(format: "%.0f m", lowestPoint.altitude)
            )
            mapView.addAnnotation(lowAnnotation)
        }
        
        // Find fastest segment (if speed data available)
        if locations.contains(where: { $0.speed > 0 }) {
            if let fastestPoint = locations.max(by: { $0.speed < $1.speed }) {
                let fastAnnotation = RunAnalysisRouteAnnotation(
                    coordinate: fastestPoint.coordinate,
                    type: .fastestSegment,
                    value: String(format: "%.1f km/h", fastestPoint.speed * 3.6)
                )
                mapView.addAnnotation(fastAnnotation)
            }
        }
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update the region if it changes significantly
        if !mapView.region.isApproximatelyEqual(to: region, within: 0.2) {
            mapView.setRegion(region, animated: true)
        }
        
        // Ensure animation is running - this helps when returning from other tabs
        if !context.coordinator.isAnimating && !context.coordinator.routeLocations.isEmpty {
            print("🏃‍♂️ Restarting user animation that was not running")
            context.coordinator.startUserAnimation()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        // Store segment information in the coordinator
        private var polylineSegmentInfo: [MKPolyline: (segmentIndex: Int, totalSegments: Int)] = [:]
        
        // Animation properties
        var userAnnotation: RouteUserAnnotation?
        var routeLocations: [CLLocation] = []
        private var animationTimer: Timer?
        private var animationProgress: Double = 0.0
        private var animationDuration: TimeInterval = 15.0 // Slightly faster for better perceived smoothness
        var isAnimating: Bool = false
        private var lastPosition: CLLocationCoordinate2D?
        
        func registerPolyline(_ polyline: MKPolyline, segmentIndex: Int, totalSegments: Int) {
            polylineSegmentInfo[polyline] = (segmentIndex: segmentIndex, totalSegments: totalSegments)
        }
        
        // Start animation of user marker along the route
        func startUserAnimation() {
            // Clear any existing timer
            animationTimer?.invalidate()
            
            // Reset progress
            animationProgress = 0.0
            isAnimating = true
            
            print("🏃‍♂️ Starting user animation along the route")
            
            // Force an immediate position update before starting the timer
            if let userAnnotation = self.userAnnotation, !self.routeLocations.isEmpty {
                let position = self.calculatePosition(at: self.animationProgress)
                userAnnotation.coordinate = position.coordinate
                userAnnotation.heading = position.heading
            }
            
            // Start animation timer - update at 60fps for smoother animation
            animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
                guard let self = self, let userAnnotation = self.userAnnotation, !self.routeLocations.isEmpty else { 
                    self?.isAnimating = false
                    return 
                }
                
                // Update progress (complete route in animationDuration seconds)
                self.animationProgress += 1.0 / (self.animationDuration * 60.0) // 60fps
                
                // Wrap around when complete
                if self.animationProgress >= 1.0 {
                    self.animationProgress = 0.0
                }
                
                // Calculate position based on progress
                let position = self.calculatePosition(at: self.animationProgress)
                
                // Update annotation position
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.2) {
                        userAnnotation.coordinate = position.coordinate
                        userAnnotation.heading = position.heading
                    }
                }
            }
            
            // Ensure the timer runs on the main run loop
            RunLoop.main.add(animationTimer!, forMode: .common)
        }
        
        // Calculate position along the route based on progress
        private func calculatePosition(at progress: Double) -> (coordinate: CLLocationCoordinate2D, heading: Double) {
            guard !routeLocations.isEmpty else { 
                return (CLLocationCoordinate2D(latitude: 0, longitude: 0), 0) 
            }
            
            // For a single point, return that point
            if routeLocations.count == 1 {
                return (routeLocations[0].coordinate, 0)
            }
            
            // Find position by interpolating between points
            let targetIndex = progress * Double(routeLocations.count - 1)
            let lowerIndex = min(Int(floor(targetIndex)), routeLocations.count - 2)
            let upperIndex = min(lowerIndex + 1, routeLocations.count - 1)
            let segmentProgress = targetIndex - Double(lowerIndex)
            
            // Get coordinates
            let fromCoord = routeLocations[lowerIndex].coordinate
            let toCoord = routeLocations[upperIndex].coordinate
            
            // Interpolate between them
            let lat = fromCoord.latitude + segmentProgress * (toCoord.latitude - fromCoord.latitude)
            let lon = fromCoord.longitude + segmentProgress * (toCoord.longitude - fromCoord.longitude)
            
            // Calculate heading
            let heading = calculateHeading(from: fromCoord, to: toCoord)
            
            return (CLLocationCoordinate2D(latitude: lat, longitude: lon), heading)
        }
        
        // Calculate heading (bearing) between two coordinates
        private func calculateHeading(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
            let lat1 = from.latitude * .pi / 180
            let lon1 = from.longitude * .pi / 180
            let lat2 = to.latitude * .pi / 180
            let lon2 = to.longitude * .pi / 180
            
            let dLon = lon2 - lon1
            let y = sin(dLon) * cos(lat2)
            let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
            var heading = atan2(y, x) * 180 / .pi
            
            // Normalize to 0-360
            if heading < 0 {
                heading += 360
            }
            
            return heading
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                
                // Simplified rendering - one consistent style for all lines
                renderer.strokeColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0) // Blue
                renderer.lineWidth = 4
                renderer.lineJoin = .round
                renderer.lineCap = .round
                
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Handle user annotation for animated marker
            if let userAnnotation = annotation as? RouteUserAnnotation {
                let identifier = "userRouteAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKAnnotationView
                
                if view == nil {
                    view = MKAnnotationView(annotation: userAnnotation, reuseIdentifier: identifier)
                    view?.canShowCallout = false
                    
                    // Set up the custom view for the user
                    let container = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
                    
                    // Pulse effect
                    let pulseView = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
                    pulseView.backgroundColor = UIColor(red: 0, green: 0.48, blue: 1.0, alpha: 0.3)
                    pulseView.layer.cornerRadius = 22
                    
                    // Add pulse animation
                    let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
                    pulseAnimation.duration = 1.2
                    pulseAnimation.fromValue = 0.9
                    pulseAnimation.toValue = 1.1
                    pulseAnimation.autoreverses = true
                    pulseAnimation.repeatCount = .infinity
                    pulseView.layer.add(pulseAnimation, forKey: "pulse")
                    
                    container.addSubview(pulseView)
                    
                    // Direction indicator
                    let directionView = UIImageView(frame: CGRect(x: 17, y: 0, width: 10, height: 16))
                    directionView.image = UIImage(systemName: "arrowtriangle.up.fill")
                    directionView.tintColor = .white
                    directionView.contentMode = .scaleAspectFit
                    container.addSubview(directionView)
                    
                    // Create an outer shadow container that doesn't clip
                    let shadowContainer = UIView(frame: CGRect(x: 7, y: 7, width: 30, height: 30))
                    shadowContainer.backgroundColor = .clear
                    shadowContainer.layer.shadowColor = UIColor.black.cgColor
                    shadowContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
                    shadowContainer.layer.shadowRadius = 4
                    shadowContainer.layer.shadowOpacity = 0.7
                    container.addSubview(shadowContainer)
                    
                    // Profile image view in a perfect circle
                    let profileView = UIImageView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
                    profileView.contentMode = .scaleAspectFill
                    profileView.layer.cornerRadius = 15
                    profileView.clipsToBounds = true
                    profileView.layer.borderWidth = 2
                    profileView.layer.borderColor = UIColor.white.cgColor
                    
                    // Set profile image if available
                    if let profileImage = CurrentUserService.shared.user.profilePicture {
                        profileView.image = profileImage
                    } else {
                        profileView.image = UIImage(systemName: "person.fill")
                        profileView.tintColor = .white
                        profileView.backgroundColor = UIColor(red: 0, green: 0.48, blue: 1.0, alpha: 1.0)
                    }
                    
                    // Add profile view to shadow container
                    shadowContainer.addSubview(profileView)
                    
                    // Add rotation tag for updating direction
                    directionView.tag = 100
                    
                    view?.addSubview(container)
                    view?.frame = container.frame
                } else {
                    view?.annotation = userAnnotation
                }
                
                // Update direction arrow based on heading
                if let directionView = view?.viewWithTag(100) {
                    directionView.transform = CGAffineTransform(rotationAngle: CGFloat(userAnnotation.heading * .pi / 180.0))
                }
                
                return view
            }
            
            // Handle route annotation points
            guard let routeAnnotation = annotation as? RunAnalysisRouteAnnotation else { return nil }
            
            let identifier = "RoutePoint"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if view == nil {
                view = MKMarkerAnnotationView(annotation: routeAnnotation, reuseIdentifier: identifier)
                view?.displayPriority = .required
                view?.canShowCallout = true
                
                // Add detailed subtitle to callout if available
                if let value = routeAnnotation.value {
                    let detail = UILabel()
                    detail.text = value
                    detail.font = UIFont.systemFont(ofSize: 12)
                    detail.textColor = .darkGray
                    view?.detailCalloutAccessoryView = detail
                }
            } else {
                view?.annotation = routeAnnotation
            }
            
            switch routeAnnotation.type {
            case .start:
                view?.markerTintColor = UIColor(Color(hex: 0x4CD964))
                view?.glyphImage = UIImage(systemName: "flag.fill")
            case .end:
                view?.markerTintColor = UIColor(Color(hex: 0xFF3B30))
                view?.glyphImage = UIImage(systemName: "flag.checkered")
            case .highPoint:
                view?.markerTintColor = UIColor(Color(hex: 0x5856D6))
                view?.glyphImage = UIImage(systemName: "arrow.up")
            case .lowPoint:
                view?.markerTintColor = UIColor(Color(hex: 0x5AC8FA))
                view?.glyphImage = UIImage(systemName: "arrow.down")
            case .fastestSegment:
                view?.markerTintColor = UIColor(Color(hex: 0xFF9500))
                view?.glyphImage = UIImage(systemName: "bolt.fill")
            case .slowestSegment:
                view?.markerTintColor = UIColor(Color(hex: 0x8E8E93))
                view?.glyphImage = UIImage(systemName: "tortoise.fill")
            }
            
            return view
        }
        
        // Stop animation when coordinator is destroyed
        deinit {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }
}

// Custom annotation class for the user marker that includes heading
class RouteUserAnnotation: MKPointAnnotation {
    var heading: Double = 0.0
}

// Extension to compare map regions
extension MKCoordinateRegion {
    func isApproximatelyEqual(to region: MKCoordinateRegion, within threshold: Double) -> Bool {
        let latDiff = abs(self.center.latitude - region.center.latitude)
        let lonDiff = abs(self.center.longitude - region.center.longitude)
        let spanLatDiff = abs(self.span.latitudeDelta - region.span.latitudeDelta)
        let spanLonDiff = abs(self.span.longitudeDelta - region.span.longitudeDelta)
        
        return latDiff < threshold && lonDiff < threshold && 
               spanLatDiff < threshold && spanLonDiff < threshold
    }
}

// Custom annotation class for route points
class RunAnalysisRouteAnnotation: NSObject, MKAnnotation {
    enum AnnotationType {
        case start
        case end
        case highPoint
        case lowPoint
        case fastestSegment
        case slowestSegment
    }
    
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType
    let value: String?
    
    init(coordinate: CLLocationCoordinate2D, type: AnnotationType, value: String? = nil) {
        self.coordinate = coordinate
        self.type = type
        self.value = value
        super.init()
    }
    
    var title: String? {
        switch type {
        case .start: return "Start"
        case .end: return "Finish"
        case .highPoint: return "Highest Point"
        case .lowPoint: return "Lowest Point"
        case .fastestSegment: return "Fastest Pace"
        case .slowestSegment: return "Slowest Pace"
        }
    }
    
    var subtitle: String? {
        return value
    }
}

// Extension to help with color interpolation
extension UIColor {
    var redComponent: CGFloat {
        var red: CGFloat = 0
        getRed(&red, green: nil, blue: nil, alpha: nil)
        return red
    }
    
    var greenComponent: CGFloat {
        var green: CGFloat = 0
        getRed(nil, green: &green, blue: nil, alpha: nil)
        return green
    }
    
    var blueComponent: CGFloat {
        var blue: CGFloat = 0
        getRed(nil, green: nil, blue: &blue, alpha: nil)
        return blue
    }
}

// SwiftUI wrapper for RunVideoPreviewViewController
struct RunVideoPreviewViewControllerRepresentable: UIViewControllerRepresentable {
    let run: Any
    
    func makeUIViewController(context: Context) -> RunVideoPreviewViewController {
        return RunVideoPreviewViewController(runData: run as! RunLog)
    }
    
    func updateUIViewController(_ uiViewController: RunVideoPreviewViewController, context: Context) {
        // No updates needed
    }
}

// Route seek slider
struct RouteSeekSlider: View {
    @Binding var value: Double
    @Binding var isPlaying: Bool
    let run: Any // Add reference to the run data
    var onPlayPause: (Bool) -> Void
    
    @State private var timer: Timer?
    @State private var isDragging = false
    
    // Get total duration from run data
    private var totalDuration: TimeInterval {
        if let outdoorRun = run as? RunLog, let durationStr = outdoorRun.duration {
            return convertDurationToSeconds(durationStr)
        } else if let indoorRun = run as? IndoorRunLog, let durationStr = indoorRun.duration {
            return convertDurationToSeconds(durationStr)
        }
        return 1800 // 30 minutes as fallback
    }
    
    // Calculate playback increment based on duration
    private var playbackIncrement: Double {
        // We want to complete playback in about 10-15 seconds regardless of run length
        // For a 30min run at 0.0005 increment per 0.033s interval, it takes ~20s to complete
        // So scale accordingly for longer runs to keep playback time reasonable
        let baseIncrement = 0.0005
        let targetPlaybackDuration = 15.0 // Target duration in seconds for full playback
        let intervals = targetPlaybackDuration / 0.033 // How many timer intervals in target duration
        
        // Calculate increment needed to complete in target time
        return min(0.005, 1.0 / intervals) // Cap at 0.005 for very short runs
    }
    
    // Convert duration string to seconds
    private func convertDurationToSeconds(_ durationStr: String) -> Double {
        let components = durationStr.components(separatedBy: ":")
        if components.count == 3 {
            // Hour:Minute:Second format
            let hours = Double(components[0]) ?? 0
            let minutes = Double(components[1]) ?? 0
            let seconds = Double(components[2]) ?? 0
            return hours * 3600 + minutes * 60 + seconds
        } else if components.count == 2 {
            // Minute:Second format
            let minutes = Double(components[0]) ?? 0
            let seconds = Double(components[1]) ?? 0
            return minutes * 60 + seconds
        }
        return 1800 // Default
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Slider track and thumb
            HStack(spacing: 12) {
                // Play/pause button
                Button(action: {
                    // First toggle the playing state
                    let newIsPlaying = !isPlaying
                    
                    // Then call the onPlayPause callback with the new state
                    onPlayPause(newIsPlaying)
                    
                    // Finally, start or stop playback based on the new state
                    if newIsPlaying {
                        startPlayback()
                    } else {
                        stopPlayback()
                    }
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38) // Slightly bigger button
                        .background(Color(hex: 0x4CD964))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2) // Enhanced shadow
                }
                
                // Custom slider with gradient background
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Track background
                        RoundedRectangle(cornerRadius: 6) // Increased from 4 to 6
                            .fill(Color.white.opacity(0.2)) // Slightly more visible track
                            .frame(height: 10) // Increased from 8 to 10
                        
                        // Progress fill - extend all the way to the button
                        RoundedRectangle(cornerRadius: 6) // Increased from 4 to 6
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: 0x4CD964),
                                        Color(hex: 0x007AFF)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, CGFloat(value) * geometry.size.width), height: 10) // Increased from 8 to 10
                        
                        // Draggable thumb
                        Circle()
                            .fill(Color.white)
                            .frame(width: 22, height: 22) // Increased from 18 to 22
                            .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2) // Enhanced shadow
                            .offset(x: max(0, CGFloat(value) * geometry.size.width - 11)) // Adjusted for new size (-11 instead of -9)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { gesture in
                                        isDragging = true
                                        if isPlaying {
                                            stopPlayback()
                                        }
                                        
                                        let newValue = gesture.location.x / geometry.size.width
                                        value = max(0, min(1, Double(newValue)))
                                    }
                                    .onEnded { _ in
                                        isDragging = false
                                    }
                            )
                    }
                }
                .frame(height: 38) // Increased from 36 to 38
            }
            
            // Time indicators
            HStack {
                Text("0:00")
                    .font(.system(size: 11, weight: .medium)) // Increased from 10 to 11
                    .foregroundColor(.white.opacity(0.8)) // More visible text
                
                Spacer()
                
                Text(formatTime(totalDuration))
                    .font(.system(size: 11, weight: .medium)) // Increased from 10 to 11
                    .foregroundColor(.white.opacity(0.8)) // More visible text
            }
            .padding(.horizontal, 12) // Increased from 8 to 12
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8) // Reduced from 16 to 8 to make it wider
        .onDisappear {
            stopPlayback()
        }
    }
    
    // Format time for display
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    // Start automatic playback
    private func startPlayback() {
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in
            if value < 1.0 {
                value += playbackIncrement // Use calculated increment
            } else {
                value = 0.0 // Loop back to beginning
            }
        }
    }
    
    // Stop automatic playback
    private func stopPlayback() {
        timer?.invalidate()
        timer = nil
    }
}

// Card showing stats at the current position in the route
struct RoutePositionStatsCard: View {
    let routeLocations: [CLLocation]
    let run: Any // Add reference to the run data
    @Binding var progress: Double
    @Binding var isPlaying: Bool
    
    // Current location derived from progress
    private var currentLocation: CLLocation? {
        guard !routeLocations.isEmpty else { return nil }
        
        let index = min(Int(progress * Double(routeLocations.count)), routeLocations.count - 1)
        return routeLocations[index]
    }
    
    // Calculate distance covered up to current point
    private var distanceCovered: Double {
        guard !routeLocations.isEmpty, let current = currentLocation else { return 0 }
        
        let index = routeLocations.firstIndex(of: current) ?? 0
        var distance: Double = 0
        
        for i in 0..<index {
            distance += routeLocations[i].distance(from: routeLocations[i+1])
        }
        
        return distance
    }
    
    // Calculate total distance of the route from location data
    private var totalRouteDistance: Double {
        guard routeLocations.count > 1 else { return 0 }
        
        var totalDistance: Double = 0
        for i in 0..<(routeLocations.count - 1) {
            totalDistance += routeLocations[i].distance(from: routeLocations[i+1])
        }
        
        return totalDistance
    }
    
    // Calculate time elapsed up to current point (assuming constant speed)
    private var timeElapsed: TimeInterval {
        guard !routeLocations.isEmpty else { return 0 }
        
        // Estimate based on percentage of route completed
        return progress * totalRouteDuration
    }
    
    // Calculate average pace for the entire route from location data
    private var calculatedAveragePace: Double {
        let distance = totalRouteDistance
        let duration = totalRouteDuration
        
        // Avoid division by zero
        if distance > 0 && duration > 0 {
            // Calculate pace in seconds per meter
            return duration / distance
        }
        
        return 0
    }
    
    // Calculate current segment pace based on recent locations
    private var currentSegmentPace: Double? {
        guard routeLocations.count > 2, let current = currentLocation else { return nil }
        
        // Get the index of the current location
        let currentIndex = routeLocations.firstIndex(of: current) ?? 0
        
        // Need at least one point before and after for accurate instantaneous pace
        if currentIndex < 1 || currentIndex >= routeLocations.count - 1 {
            return nil
        }
        
        // Get the surrounding points to calculate instantaneous pace
        let prevLocation = routeLocations[currentIndex - 1]
        let nextLocation = routeLocations[min(currentIndex + 1, routeLocations.count - 1)]
        
        // Calculate distance and time between these points
        let distance = prevLocation.distance(from: nextLocation)
        let time = nextLocation.timestamp.timeIntervalSince(prevLocation.timestamp)
        
        // Only calculate if we have meaningful distance and time
        if distance > 5 && time > 1 {
            // Calculate pace in seconds per meter
            return time / distance
        } else if current.speed > 0 {
            // Fallback to use the speed directly from the location if available
            return 1.0 / current.speed
        }
        
        return nil
    }
    
    // Get total route duration from run data
    private var totalRouteDuration: TimeInterval {
        if let outdoorRun = run as? RunLog, let durationStr = outdoorRun.duration {
            return convertDurationToSeconds(durationStr)
        } else if let indoorRun = run as? IndoorRunLog, let durationStr = indoorRun.duration {
            return convertDurationToSeconds(durationStr)
        }
        return 1800 // 30 minutes as fallback
    }
    
    // Get heart rate at current position
    private var currentHeartRate: Double? {
        guard let currentLocation = currentLocation else { return nil }
        
        // Get the index of the current location
        let currentIndex = routeLocations.firstIndex(of: currentLocation) ?? 0
        
        if let outdoorRun = run as? RunLog, let locationData = outdoorRun.locationData {
            // We have location data with potentially heart rate info
            guard currentIndex < locationData.count else { return nil }
            
            // Extract heart rate from location data at current index
            return locationData[currentIndex]["heartRate"] as? Double
        } else if let indoorRun = run as? IndoorRunLog, let treadmillData = indoorRun.treadmillDataPoints {
            // We have treadmill data with potentially heart rate info
            guard currentIndex < treadmillData.count else { return nil }
            
            // Extract heart rate from treadmill data at current index
            return treadmillData[currentIndex].heartRate
        }
        
        return nil
    }
    
    // Convert duration string to seconds
    private func convertDurationToSeconds(_ durationStr: String) -> Double {
        let components = durationStr.components(separatedBy: ":")
        if components.count == 3 {
            // Hour:Minute:Second format
            let hours = Double(components[0]) ?? 0
            let minutes = Double(components[1]) ?? 0
            let seconds = Double(components[2]) ?? 0
            return hours * 3600 + minutes * 60 + seconds
        } else if components.count == 2 {
            // Minute:Second format
            let minutes = Double(components[0]) ?? 0
            let seconds = Double(components[1]) ?? 0
            return minutes * 60 + seconds
        }
        return 1800 // Default to 30 minutes if parsing fails
    }
    
    // Get elevation at current point
    private var currentElevation: Double? {
        return currentLocation?.altitude
    }
    
    // Format distance for display
    private func formatDistance(_ distance: Double) -> String {
        return UserPreferences.shared.formatDistance(distance)
    }
    
    // Format time for display
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    // Format elevation for display
    private func formatElevation(_ elevation: Double) -> String {
        return UserPreferences.formatElevationWithPreferredUnit(elevation: elevation)
    }
    
    // Format pace for display
    private func formatPace(_ secondsPerMeter: Double) -> String {
        // Check if pace is valid (avoid infinity or very large values)
        if secondsPerMeter <= 0 || secondsPerMeter > 1000 {
            return "--"
        }
        return UserPreferences.shared.formatPace(secondsPerMeter)
    }
    
    // Get color based on heart rate intensity
    private func heartRateColor(_ heartRate: Double) -> Color {
        // Get max heart rate (rough estimate if not available)
        let maxHeartRate: Double
        if let outdoorRun = run as? RunLog, let max = outdoorRun.maxHeartRate {
            maxHeartRate = Double(max)
        } else if let indoorRun = run as? IndoorRunLog, let max = indoorRun.maxHeartRate {
            maxHeartRate = Double(max)
        } else {
            // Estimate max heart rate if not available (common formula: 220 - age)
            // Since we don't have age, use a default max of 180
            maxHeartRate = 180
        }
        
        // Calculate intensity as percentage of max heart rate
        let intensity = heartRate / maxHeartRate
        
        // Color based on zones (approximately):
        // Zone 1 (<60%): Green - recovery
        // Zone 2 (60-70%): Blue - aerobic
        // Zone 3 (70-80%): Purple - tempo
        // Zone 4 (80-90%): Orange - threshold
        // Zone 5 (>90%): Red - anaerobic
        
        if intensity < 0.6 {
            return Color(hex: 0x4CD964) // Green (Zone 1)
        } else if intensity < 0.7 {
            return Color(hex: 0x5AC8FA) // Blue (Zone 2)
        } else if intensity < 0.8 {
            return Color(hex: 0x5856D6) // Purple (Zone 3)
        } else if intensity < 0.9 {
            return Color(hex: 0xFF9500) // Orange (Zone 4)
        } else {
            return Color(hex: 0xFF3B30) // Red (Zone 5)
        }
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                // Distance
                VStack(alignment: .leading, spacing: 4) { // Increased spacing from 2 to 4
                    Text("DISTANCE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false) // Prevent truncation
                    
                    Text(formatDistance(distanceCovered))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false) // Prevent truncation
                }
                .frame(minWidth: 80) // Minimum width to prevent cutting off text
                
                Divider()
                    .background(Color.white.opacity(0.4))
                    .frame(height: 30) // Increased from 28 to 30
                
                // Time
                VStack(alignment: .leading, spacing: 4) { // Increased spacing from 2 to 4
                    Text("TIME")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false) // Prevent truncation
                    
                    Text(formatTime(timeElapsed))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false) // Prevent truncation
                }
                .frame(minWidth: 70) // Minimum width to prevent cutting off text
                
                Divider()
                    .background(Color.white.opacity(0.4))
                    .frame(height: 30) // Increased from 28 to 30
                
                // Current pace (instantaneous)
                VStack(alignment: .leading, spacing: 4) { // Increased spacing from 2 to 4
                    Text("PACE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false) // Prevent truncation
                    
                    if let segmentPace = currentSegmentPace {
                        Text(formatPace(segmentPace))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false) // Prevent truncation
                    } else {
                        Text("--")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
                .frame(minWidth: 90) // Minimum width to prevent cutting off text
                
                Divider()
                    .background(Color.white.opacity(0.4))
                    .frame(height: 30) // Increased from 28 to 30
                
                // Elevation
                VStack(alignment: .leading, spacing: 4) { // Increased spacing from 2 to 4
                    Text("ELEVATION")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false) // Prevent truncation
                    
                    Text(currentElevation != nil ? formatElevation(currentElevation!) : "--")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false) // Prevent truncation
                }
                .frame(minWidth: 85) // Minimum width to prevent cutting off text
                
                Divider()
                    .background(Color.white.opacity(0.4))
                    .frame(height: 30) // Increased from 28 to 30
                
                // Heart Rate
                VStack(alignment: .leading, spacing: 4) { // Increased spacing from 2 to 4
                    Text("HEART RATE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false) // Prevent truncation
                    
                    if let currentHeartRate = currentHeartRate {
                        Text("\(Int(currentHeartRate)) bpm")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(heartRateColor(currentHeartRate))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false) // Prevent truncation
                    } else {
                        Text("-- bpm")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
                .frame(minWidth: 95) // Minimum width to prevent cutting off text
            }
            .padding(16) // Increased from 14 to 16
            .padding(.bottom, 50) // Increased from 36 to 50 for more space between stats and slider
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7))
                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
    }
}

// Updated MapViewWrapper to support the seek view
struct MapViewWrapper: UIViewRepresentable {
    let locations: [CLLocation]
    @Binding var region: MKCoordinateRegion
    @Binding var progress: Double
    
    func makeUIView(context: Context) -> MKMapView {
        print("MapViewWrapper: Creating map view with \(locations.count) locations")
        
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.mapType = .standard
        
        // Configure map appearance
        if #available(iOS 13.0, *) {
            mapView.overrideUserInterfaceStyle = .dark
            mapView.mapType = .mutedStandard
            mapView.pointOfInterestFilter = .excludingAll
        }
        
        // Add polyline for route - create colorful polylines similar to RunVideoPreviewViewController
        if locations.count > 1 {
            let polylines = createMulticolorPolylines(from: locations)
            print("MapViewWrapper: Created \(polylines.count) polylines")
            
            for polyline in polylines {
                mapView.addOverlay(polyline)
            }
            
            // Add start and end annotations
            if let first = locations.first, let last = locations.last {
                let startAnnotation = RunAnalysisRouteAnnotation(
                    coordinate: first.coordinate,
                    type: .start,
                    value: "Start"
                )
                
                let endAnnotation = RunAnalysisRouteAnnotation(
                    coordinate: last.coordinate,
                    type: .end,
                    value: "Finish"
                )
                
                mapView.addAnnotations([startAnnotation, endAnnotation])
            }
            
            // Force map to redraw after a short delay to ensure overlays are rendered
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("MapViewWrapper: Forcing map redraw, overlay count: \(mapView.overlays.count)")
                mapView.setNeedsDisplay()
            }
        }
        
        // Add gesture recognizers to detect user interaction
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapPan(_:)))
        mapView.addGestureRecognizer(panGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapPinch(_:)))
        mapView.addGestureRecognizer(pinchGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Only update the region if user hasn't interacted with the map
        if !context.coordinator.userInteracted {
            mapView.setRegion(region, animated: true)
        }
        
        // Check if overlays are missing and add them if needed
        if mapView.overlays.isEmpty && locations.count > 1 {
            print("MapViewWrapper: Re-adding missing overlays")
            let polylines = createMulticolorPolylines(from: locations)
            for polyline in polylines {
                mapView.addOverlay(polyline)
            }
            
            // Force redraw
            mapView.setNeedsDisplay()
        }
        
        // Update user's position along the route based on progress
        if let userAnnotation = context.coordinator.userAnnotation {
            // Remove existing user annotation
            mapView.removeAnnotation(userAnnotation)
        }
        
        // Add new user annotation at current position based on progress
        let userAnnotation = MKPointAnnotation()
        userAnnotation.coordinate = getCoordinateAtProgress(progress)
        context.coordinator.userAnnotation = userAnnotation
        mapView.addAnnotation(userAnnotation)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(progress: $progress)
    }
    
    // Create multicolor polylines like in RunVideoPreviewViewController
    private func createMulticolorPolylines(from locations: [CLLocation]) -> [RunRoutePolyline] {
        var coordinates: [(CLLocation, CLLocation)] = []
        var speeds: [Double] = []
        var minSpeed = Double.greatestFiniteMagnitude
        var maxSpeed = 0.0
        
        for (first, second) in zip(locations, locations.dropFirst()) {
            let start = CLLocation(latitude: first.coordinate.latitude, longitude: first.coordinate.longitude)
            let end = CLLocation(latitude: second.coordinate.latitude, longitude: second.coordinate.longitude)
            coordinates.append((start, end))
            
            let time = second.timestamp.timeIntervalSince(first.timestamp)
            let distance = end.distance(from: start)
            let speed = time > 0 ? distance / time : 0
            speeds.append(speed)
            minSpeed = min(minSpeed, speed)
            maxSpeed = max(maxSpeed, speed)
        }
        
        let midSpeed = speeds.reduce(0, +) / Double(speeds.count)
        
        var segments: [RunRoutePolyline] = []
        for ((start, end), speed) in zip(coordinates, speeds) {
            let coords = [start.coordinate, end.coordinate]
            let segment = RunRoutePolyline(coordinates: coords, count: 2)
            
            // Set color based on speed using our Do-branded orange-red palette
            segment.color = getSegmentColor(speed: speed,
                                         midSpeed: midSpeed,
                                         slowestSpeed: minSpeed,
                                         fastestSpeed: maxSpeed)
            
            // Set thicker line width for visibility
            let speedRatio = (speed - minSpeed) / (maxSpeed - minSpeed + 0.1)
            segment.lineWidth = 5.0 + CGFloat(speedRatio) * 3.0 // Width range: 5.0-8.0 for stronger visibility
            
            segments.append(segment)
        }
        
        return segments
    }
    
    // Color theme with speed variation
    private func getSegmentColor(speed: Double, midSpeed: Double, slowestSpeed: Double, fastestSpeed: Double) -> UIColor {
        enum SpeedColors {
            // Do brand orange for slow sections
            static let slow_red: CGFloat = 247/255
            static let slow_green: CGFloat = 147/255
            static let slow_blue: CGFloat = 31/255
            
            // Bright orange-yellow for mid sections
            static let mid_red: CGFloat = 255/255
            static let mid_green: CGFloat = 170/255
            static let mid_blue: CGFloat = 0/255
            
            // Intense red for fast sections
            static let fast_red: CGFloat = 220/255
            static let fast_green: CGFloat = 50/255
            static let fast_blue: CGFloat = 0/255
        }
        
        let red, green, blue: CGFloat
        
        if speed < midSpeed {
            let ratio = CGFloat((speed - slowestSpeed) / (midSpeed - slowestSpeed))
            red = SpeedColors.slow_red + ratio * (SpeedColors.mid_red - SpeedColors.slow_red)
            green = SpeedColors.slow_green + ratio * (SpeedColors.mid_green - SpeedColors.slow_green)
            blue = SpeedColors.slow_blue + ratio * (SpeedColors.mid_blue - SpeedColors.slow_blue)
        } else {
            let ratio = CGFloat((speed - midSpeed) / (fastestSpeed - midSpeed))
            red = SpeedColors.mid_red + ratio * (SpeedColors.fast_red - SpeedColors.mid_red)
            green = SpeedColors.mid_green + ratio * (SpeedColors.fast_green - SpeedColors.mid_green)
            blue = SpeedColors.mid_blue + ratio * (SpeedColors.fast_blue - SpeedColors.mid_blue)
        }
        
        return UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
    
    // Get coordinate at specific progress point
    private func getCoordinateAtProgress(_ progress: Double) -> CLLocationCoordinate2D {
        guard locations.count > 1 else {
            return locations.first?.coordinate ?? CLLocationCoordinate2D()
        }
        
        let index = min(Int(progress * Double(locations.count - 1)), locations.count - 1)
        return locations[index].coordinate
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        @Binding var progress: Double
        var userAnnotation: MKPointAnnotation?
        var userInteracted: Bool = false
        
        init(progress: Binding<Double>) {
            self._progress = progress
        }
        
        @objc func handleMapPan(_ gesture: UIPanGestureRecognizer) {
            if gesture.state == .began {
                userInteracted = true
            }
        }
        
        @objc func handleMapPinch(_ gesture: UIPinchGestureRecognizer) {
            if gesture.state == .began {
                userInteracted = true
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // Handle RunRoutePolyline
            if let polyline = overlay as? RunRoutePolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = polyline.color
                renderer.lineWidth = polyline.lineWidth
                renderer.lineCap = .round
                renderer.lineJoin = .round
                
                print("MapViewWrapper: Created renderer for polyline with color: \(polyline.color), width: \(polyline.lineWidth)")
                return renderer
            }
            
            // Default renderer for other overlay types
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 247/255.0, green: 147/255.0, blue: 31/255.0, alpha: 1.0) // Do orange
                renderer.lineWidth = 4.0
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            if let routeAnnotation = annotation as? RunAnalysisRouteAnnotation {
                let identifier = "RouteAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if view == nil {
                    view = MKMarkerAnnotationView(annotation: routeAnnotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                }
                
                // Configure based on type
                switch routeAnnotation.type {
                case .start:
                    view?.markerTintColor = .green
                    view?.glyphImage = UIImage(systemName: "flag.fill")
                case .end:
                    view?.markerTintColor = .red
                    view?.glyphImage = UIImage(systemName: "flag.checkered")
                case .highPoint:
                    view?.markerTintColor = .purple
                    view?.glyphImage = UIImage(systemName: "arrow.up")
                case .lowPoint:
                    view?.markerTintColor = .blue
                    view?.glyphImage = UIImage(systemName: "arrow.down")
                case .fastestSegment:
                    view?.markerTintColor = .orange
                    view?.glyphImage = UIImage(systemName: "bolt.fill")
                case .slowestSegment:
                    view?.markerTintColor = .gray
                    view?.glyphImage = UIImage(systemName: "tortoise.fill")
                }
                
                return view
            } else if annotation === userAnnotation {
                // Custom user annotation (runner on the route)
                let identifier = "UserAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = false
                    
                    // Create a custom profile image view
                    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
                    imageView.contentMode = .scaleAspectFill
                    imageView.layer.cornerRadius = 15
                    imageView.clipsToBounds = true
                    imageView.layer.borderWidth = 2
                    imageView.layer.borderColor = UIColor.white.cgColor
                    
                    // Add pulse effect background
                    let pulseView = UIView(frame: CGRect(x: -5, y: -5, width: 40, height: 40))
                    pulseView.backgroundColor = UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 0.4)
                    pulseView.layer.cornerRadius = 20
                    
                    // Set user profile image if available
                    if let userProfileImage = CurrentUserService.shared.user.profilePicture {
                        imageView.image = userProfileImage
                    } else {
                        // Use a system image as fallback
                        if #available(iOS 13.0, *) {
                            imageView.image = UIImage(systemName: "person.crop.circle.fill")
                            imageView.tintColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
                        } else {
                            // For older iOS versions
                            imageView.image = UIImage(named: "profile_placeholder")
                            imageView.backgroundColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
                        }
                    }
                    
                    view?.addSubview(pulseView)
                    view?.addSubview(imageView)
                    
                    // Set the view size
                    view?.frame.size = CGSize(width: 30, height: 30)
                    
                    // Add pulsing animation
                    let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
                    pulseAnimation.duration = 1.0
                    pulseAnimation.fromValue = 0.8
                    pulseAnimation.toValue = 1.2
                    pulseAnimation.autoreverses = true
                    pulseAnimation.repeatCount = Float.infinity
                    pulseView.layer.add(pulseAnimation, forKey: "pulse")
                } else {
                    view?.annotation = annotation
                }
                
                return view
            }
            
            return nil
        }
    }
}

// Indoor Run Share View - Used for sharing indoor runs since they don't have map data
struct IndoorRunShareView: View {
    let run: IndoorRunLog
    let onDismiss: () -> Void
    
    // Gradient for background
    private let backgroundGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(hex: 0x0A1128),
            Color(hex: 0x1C2541)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    // Calculate average pace from treadmill data points if needed
    private var calculatedAvgPace: String {
        // First check if run already has a valid avgPace that isn't in mph/kph format
        if let existingPace = run.avgPace, 
           (existingPace.contains("/mi") || existingPace.contains("/km")) &&
           !existingPace.contains("0:00") {
            return existingPace
        }
        
        // Calculate from treadmill data points if available
        if let treadmillData = run.treadmillDataPoints, !treadmillData.isEmpty {
            // Filter out invalid pace values (too slow or too fast)
            let validPaces = treadmillData.map { $0.pace }.filter { $0 >= 3 && $0 <= 20 }
            
            if !validPaces.isEmpty {
                let avgPace = validPaces.reduce(0, +) / Double(validPaces.count)
                let useMetric = UserPreferences.shared.useMetricSystem
                return formattedPace(avgPace, metric: useMetric)
            }
        }
        
        // If existing pace is in mph/kph format, convert it
        if let existingPace = run.avgPace {
            return formatPace(existingPace)
        }
        
        // Fallback if we can't calculate
        return UserPreferences.shared.useMetricSystem ? "0:00 /km" : "0:00 /mi"
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with dismiss button
                HStack {
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                ScrollView {
                    // Post container with border
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 24) {
                            // Profile and date section
                            VStack(alignment: .leading, spacing: 10) {
                                // Profile info
                                HStack(spacing: 12) {
                                    if let profileImage = CurrentUserService.shared.user.profilePicture {
                                        Image(uiImage: profileImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 2)
                                            )
                                            .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 40, height: 40)
                                            .foregroundColor(.gray)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 2)
                                            )
                                    }
                                    
                                    Text("@\(CurrentUserService.shared.user.userName?.lowercased() ?? "runner")")
                                        .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            
                                    Spacer()
                                    
                                    // Add Do logo on the right side
                                    Image(uiImage: UIImage(named: "logo_45") ?? UIImage())
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 28, height: 28)
                                }
                                
                                // Date
                                Text(formatRunDate(run.createdAt ?? Date()))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("Indoor Run")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.top, 4)
                            }
                            .padding(.horizontal)
                            .padding(.top, 16)
                            
                            // Compact Stats Section (Primary + Secondary + Performance)
                            VStack(spacing: 16) {
                                // Stats Grid (Primary + Secondary)
                                VStack(spacing: 8) {
                                    // First row: Distance, Time, Pace
                                    HStack(spacing: 0) {
                            // Distance
                                        statItem(
                                icon: "figure.run",
                                            value: formatDistance(run.distance),
                                            label: "DISTANCE",
                                            color: Color(hex: 0xFF9500)
                            )
                            
                            // Time
                                        statItem(
                                icon: "clock",
                                            value: run.duration ?? "00:00",
                                            label: "TIME",
                                            color: Color(hex: 0x5AC8FA)
                            )
                            
                            // Pace
                                        statItem(
                                icon: "speedometer",
                                            value: calculatedAvgPace,
                                            label: "AVG PACE",
                                color: Color(hex: 0x4CD964)
                            )
                        }
                        
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                    
                                    // Second row: Calories, Heart Rate, Cadence
                                    HStack(spacing: 0) {
                            // Calories
                                        statItem(
                                icon: "flame.fill",
                                            value: "\(Int(run.caloriesBurned ?? 0))",
                                            label: "CALORIES",
                                color: Color(hex: 0xFF3B30)
                            )
                            
                                        // Heart Rate
                                        statItem(
                                icon: "heart.fill",
                                            value: run.avgHeartRate != nil ? "\(Int(run.avgHeartRate!)) bpm" : "-- bpm",
                                            label: "AVG HR",
                                color: Color(hex: 0xFF375F)
                            )
                            
                                        // Cadence
                                        statItem(
                                icon: "figure.walk",
                                            value: run.avgCadence != nil ? "\(Int(run.avgCadence!)) spm" : "-- spm",
                                            label: "CADENCE",
                                color: Color(hex: 0x34C759)
                            )
                        }
                                }
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.08))
                                )
                                
                                // Performance Metrics - Compact Grid
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("PERFORMANCE")
                                        .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                                        .padding(.horizontal, 12)
                                    
                                    // 2x2 Grid of performance metrics
                                    VStack(spacing: 12) {
                                        HStack(spacing: 12) {
                                            // Pace
                                            compactPerformanceMetric(
                                                name: "PACE",
                                                icon: "speedometer",
                                                color: Color(hex: 0x4CD964),
                                                score: 85
                                            )
                                            
                                            // Heart Rate
                                            compactPerformanceMetric(
                                                name: "HEART RATE",
                                                icon: "heart.fill",
                                                color: Color(hex: 0xFF375F),
                                                score: 70
                                            )
                                        }
                                        
                                        HStack(spacing: 12) {
                                            // Endurance
                                            compactPerformanceMetric(
                                                name: "ENDURANCE",
                                                icon: "clock",
                                                color: Color(hex: 0xFF9500),
                                                score: 65
                                            )
                                            
                                            // Consistency
                                            compactPerformanceMetric(
                                                name: "CONSISTENCY",
                                                icon: "waveform.path",
                                                color: Color(hex: 0x5AC8FA),
                                                score: 80
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 12)
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.08))
                                )
                            }
                            .padding(.horizontal)
                            
                            // Combined pace and heart rate chart
                            if let treadmillData = run.treadmillDataPoints, !treadmillData.isEmpty {
        VStack(alignment: .leading, spacing: 10) {
                                    Text("PACE & HEART RATE")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.horizontal)
                                    
                                    combinedChart(treadmillData: treadmillData)
                                        .frame(height: 250)
                                        .padding(.horizontal, 4)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(hex: 0x0F1C3F).opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
        }
    }
    
    // Compact stat item for grid layout
    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    // Compact performance metric bar
    private func compactPerformanceMetric(name: String, icon: String, color: Color, score: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Metric name and score
            HStack {
                // Icon and name
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundColor(color)
                    
                    Text(name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                // Score value
                Text("\(score)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 5)
                        .cornerRadius(2.5)
                    
                    // Filled portion
                    Rectangle()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(score) / 100, height: 5)
                        .cornerRadius(2.5)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity)
    }
    
    // Combined pace and heart rate chart
    private func combinedChart(treadmillData: [TreadmillDataPoint]) -> some View {
        // First verify we have valid data
        if treadmillData.isEmpty {
            return AnyView(
                Text("No data available")
                    .foregroundColor(.white.opacity(0.7))
                .frame(height: 200)
            )
        }
        
        // Print data for debugging
        print("Treadmill data points: \(treadmillData.count)")
        for (i, point) in treadmillData.prefix(3).enumerated() {
            print("Point \(i): pace=\(point.pace), hr=\(point.heartRate)")
        }
        
        // Filter to valid data points only
        let validData = treadmillData.filter { 
            $0.pace >= 1 && $0.pace <= 30 && 
            $0.heartRate >= 40 && $0.heartRate <= 220 
        }
        
        if validData.isEmpty {
            return AnyView(
                Text("No valid data points found")
                    .foregroundColor(.white.opacity(0.7))
                    .frame(height: 200)
            )
        }
        
        // Use simpler approach to chart with separate Y scales
        return AnyView(
            VStack(spacing: 16) {
                // Heart Rate Chart
                Chart {
                    ForEach(Array(validData.enumerated()), id: \.offset) { index, dataPoint in
                LineMark(
                            x: .value("Distance", Double(index) / Double(max(1, validData.count - 1))),
                            y: .value("Heart Rate", dataPoint.heartRate)
                        )
                        .foregroundStyle(Color(hex: 0xFF375F))
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                
                AreaMark(
                            x: .value("Distance", Double(index) / Double(max(1, validData.count - 1))),
                            y: .value("Heart Rate", dataPoint.heartRate)
                        )
                        .foregroundStyle(Color(hex: 0xFF375F).opacity(0.2))
                        .interpolationMethod(.catmullRom)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let heartRate = value.as(Double.self) {
                                Text("\(Int(heartRate)) bpm")
                            .font(.system(size: 10))
                                    .foregroundColor(Color(hex: 0xFF375F).opacity(0.8))
                            }
                        }
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: 120)
                .overlay(alignment: .topLeading) {
                    Text("HEART RATE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: 0xFF375F).opacity(0.8))
                        .padding(8)
                }
                
                // Pace Chart
        Chart {
                    ForEach(Array(validData.enumerated()), id: \.offset) { index, dataPoint in
                LineMark(
                            x: .value("Distance", Double(index) / Double(max(1, validData.count - 1))),
                            y: .value("Pace", dataPoint.pace)
                        )
                        .foregroundStyle(Color(hex: 0x4CD964))
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                
                AreaMark(
                            x: .value("Distance", Double(index) / Double(max(1, validData.count - 1))),
                            y: .value("Pace", dataPoint.pace)
                        )
                        .foregroundStyle(Color(hex: 0x4CD964).opacity(0.2))
                        .interpolationMethod(.catmullRom)
            }
        }
        .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let pace = value.as(Double.self) {
                                let useMetric = UserPreferences.shared.useMetricSystem
                                Text(formattedPace(pace, metric: useMetric))
                            .font(.system(size: 10))
                                    .foregroundColor(Color(hex: 0x4CD964).opacity(0.8))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                    if let progress = value.as(Double.self), let distance = Double(run.distance?.replacingOccurrences(of: " mi", with: "").replacingOccurrences(of: " km", with: "") ?? "0") {
                        let progressDistance = progress * distance
                        Text(String(format: "%.1f", progressDistance))
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
                .frame(height: 120)
                .overlay(alignment: .topLeading) {
                    Text("PACE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: 0x4CD964).opacity(0.8))
                        .padding(8)
                }
            }
        )
    }
    
    // Helper functions
    private func formatRunDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatRunTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDistance(_ distanceString: String?) -> String {
        guard let distanceStr = distanceString else { return "0.0 mi" }
        
        // If the string already has units, extract the numeric part
        let numericPart: String
        let isMetric: Bool
        
        if distanceStr.contains("km") {
            numericPart = distanceStr.replacingOccurrences(of: " km", with: "")
            isMetric = true
        } else if distanceStr.contains("mi") {
            numericPart = distanceStr.replacingOccurrences(of: " mi", with: "")
            isMetric = false
        } else {
            // Assume it's just a number and use user preference for units
            numericPart = distanceStr
            isMetric = UserPreferences.shared.useMetricSystem
        }
        
        // Convert to double and format with 1 decimal place
        if let distance = Double(numericPart) {
            let unit = isMetric ? "km" : "mi"
            return String(format: "%.1f %@", distance, unit)
        }
        
        // Return original if parsing fails
        return distanceStr
    }
    
    private func formatPace(_ paceString: String?) -> String {
        guard let paceStr = paceString else { return "0:00 /mi" }
        
        // If already in min/mi or min/km format, return as is
        if paceStr.contains("/mi") || paceStr.contains("/km") {
            return paceStr
        }
        
        // Check if it's in mph or kph format
        if paceStr.contains("mph") || paceStr.contains("kph") {
            let numericPart: String
            let isMetric: Bool
            
            if paceStr.contains("kph") {
                numericPart = paceStr.replacingOccurrences(of: " kph", with: "")
                isMetric = true
            } else {
                numericPart = paceStr.replacingOccurrences(of: " mph", with: "")
                isMetric = false
            }
            
            // Convert speed to pace
            if let speed = Double(numericPart), speed > 0 {
                // Calculate minutes per mile/km
                let paceInMinutes = 60.0 / speed
                let minutes = Int(paceInMinutes)
                let seconds = Int((paceInMinutes - Double(minutes)) * 60)
                
                let unit = isMetric ? "/km" : "/mi"
                return String(format: "%d:%02d %@", minutes, seconds, unit)
            }
        }
        
        // Return original if parsing fails
        return paceStr
    }
    
    private func formattedPace(_ pace: Double, metric: Bool) -> String {
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        let unit = metric ? "/km" : "/mi"
        return String(format: "%d:%02d %@", minutes, seconds, unit)
    }
}

