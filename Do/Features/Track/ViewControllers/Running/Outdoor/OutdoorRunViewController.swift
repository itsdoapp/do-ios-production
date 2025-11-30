import UIKit
import CoreLocation
import MapKit
import HealthKit
import Combine
import SwiftUI
import AVFoundation
import WatchConnectivity
import CoreMotion

// MARK: - Notification Names
extension Notification.Name {
    static let didUpdateRoutePlan = Notification.Name("didUpdateRoutePlan")
}



// Near the top of the file, before the OutdoorRunViewController class
enum TurnDirection: CustomStringConvertible {
    case straight
    case slightLeft
    case left
    case sharpLeft
    case slightRight
    case right
    case sharpRight
    case uTurn
    
    var description: String {
        switch self {
        case .straight: return "Continue straight"
        case .slightLeft: return "Slight left turn"
        case .left: return "Turn left"
        case .sharpLeft: return "Sharp left turn"
        case .slightRight: return "Slight right turn"
        case .right: return "Turn right"
        case .sharpRight: return "Sharp right turn"
        case .uTurn: return "Make a U-turn"
        }
    }
}


// Extension to add properties needed for route coordinates
extension Route {
    // Optional property to store route points when available
    var routePoints: [RoutePoint]? {
        return nil // Default implementation returns nil, would be provided by data source
    }
    
    // Optional property to store route points as JSON string
    var routePointsData: String? {
        return nil // Default implementation returns nil, would be provided by data source
    }
    
    // Add this property to fix the route animation
    var routeCoordinates: [CLLocationCoordinate2D] {
        // Try to use pre-existing route points
        if let routePoints = self.routePoints, !routePoints.isEmpty {
            return routePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }
        
        // Try to use JSON data
        if let routePointsString = self.routePointsData, !routePointsString.isEmpty {
            do {
                if let data = routePointsString.data(using: .utf8),
                   let points = try JSONSerialization.jsonObject(with: data) as? [[String: Double]] {
                    return points.compactMap { point in
                        if let lat = point["lat"], let lon = point["lon"] {
                            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        }
                        return nil
                    }
                }
            } catch {
                print("Failed to parse route points data: \(error)")
            }
        }
        
        // Return empty array if no coordinates found
        return []
    }
}

// Simple struct to represent a point in a route
struct RoutePoint {
    let latitude: Double
    let longitude: Double
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

// Simple gradient overlay view for UI effects
class GradientOverlayView: UIView {
    public let gradientLayer = CAGradientLayer()
    var gradientColors: [CGColor] = [
        UIColor.clear.cgColor,
        UIColor.black.withAlphaComponent(0.7).cgColor
    ]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    public func setupGradient() {
        gradientLayer.colors = gradientColors
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    func updateGradient(colors: [CGColor]) {
        gradientColors = colors
        gradientLayer.colors = colors
    }
}

// Announcement types for voice feedback
enum AnnouncementType: String {
    case basic = "basic"
    case comprehensive = "comprehensive" 
    case custom = "custom"
}

// Pace status for run feedback
enum PaceStatus {
    case onTarget
    case tooFast
    case tooSlow
}

// Run goal for target tracking
struct RunGoal {
    let distance: Double
    let time: TimeInterval
    
    var targetPace: Double {
        guard distance > 0 else { return 0 }
        return time / 60 / distance // minutes per distance unit
    }
}



// MARK: - Color Extension for Screen Lock


//extension UIColor {
//    convenience init(_ color: Color) {
//        let uiColor = UIColor(color)
//        self.init(cgColor: uiColor.cgColor)
//    }
//}

// SwiftUI view for tracking interface
struct OutdoorRunTrackerView: View {
    @ObservedObject var viewModel: OutdoorRunViewController
    var mapView: MKMapView
    
    // State for cards and animations
    @State public var showMap = true
    @State public var showStats = true
    @State public var showPerformance = false
    @State public var showNavigation = false
    @State public var showingTrainingAlert = false
    @State public var trainingAlertText = ""
    @State public var cardOffset: CGFloat = 0
    @State public var showRouteOptions = false
    
    // Map view mode state
    @State public var mapViewMode: MapViewMode = .normal
    @State public var mapCardHeight: CGFloat = 300
    @State public var isMapExpanded = false
    
    // Route tracking state
    @State var routeCompletionPercentage: Double = 0.0
    @State var selectedRouteIndex: Int?
    
    // UI Configuration
    public let cardBackground = Color(UIColor(red: 0.12, green: 0.15, blue: 0.25, alpha: 0.9))
    public let cardCornerRadius: CGFloat = 16
    
    
    
    // Run engine reference for data (direct access, not computed)
    public let runEngine = RunTrackingEngine.shared
    
    var body: some View {
        GeometryReader { geometry in
                VStack(spacing: 0) {
                // Header
                headerView
                    .frame(height: 60) // Fixed height for header
                    .background(getBackgroundForRunType(viewModel.runType))
                    .zIndex(1) // Ensure header stays on top
                
                // ScrollView directly below header
                    ScrollView {
                    VStack(spacing: 16) {
                        // Map Card
                            if showMap {
                            MapCard(
                                mapView: mapView,
                                mapViewMode: $mapViewMode,
                                mapCardHeight: mapCardHeight,
                                cardCornerRadius: cardCornerRadius,
                                cardBackground: cardBackground,
                                onHomeButtonTapped: {
                                    viewModel.handleHomeButtonTap()
                                },
                                screenHeight: geometry.size.height,
                                viewModel: viewModel
                            )
                            .padding(.top, 16) // Add some space between header and map
                        }
                        
                        // Time and Distance Card
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("TIME")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    Text(viewModel.formattedElapsedTime)
                                        .font(.system(size: 42, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("DISTANCE")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    Text(runEngine.formattedDistance)
                                        .font(.system(size: 42, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                        .padding(.horizontal, 20)
                                .padding(.vertical, 20)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: cardCornerRadius)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                cardBackground.opacity(0.6),
                                                cardBackground.opacity(0.4)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: cardCornerRadius)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                            
                           
                            
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                    // Pace (new card)
                                    statsCard(
                                        title: "PACE",
                                        value: runEngine.formattedPace,
                                        unit: runEngine.getPaceUnitString(),
                                        icon: "speedometer",
                                        iconColor: .purple
                                    )
                                    
                                    // Heart Rate
                                    statsCard(
                                        title: "HEART RATE",
                                        value: "\(Int(runEngine.heartRate))",
                                        unit: "bpm",
                                        icon: "heart.fill",
                                        iconColor: .red
                                    )
                                    
                                    // Calories
                                    statsCard(
                                        title: "CALORIES",
                                        value: "\(Int(runEngine.calories))",
                                        unit: "kcal",
                                        icon: "flame.fill",
                                        iconColor: .orange
                                    )
                                    
                                    // Cadence
                                    statsCard(
                                        title: "CADENCE",
                                        value: "\(Int(runEngine.cadence))",
                                        unit: "spm",
                                        icon: "figure.walk",
                                        iconColor: .blue
                                    )
                                    
                                    // Elevation
                                    statsCard(
                                        title: "ELEVATION",
                                        value: "\(Int(runEngine.elevationGain.value))",
                                        unit: runEngine.getElevationUnitString(),
                                        icon: "mountain.2.fill",
                                        iconColor: .green
                                    )
                                }
                                .transition(.opacity)
                        .clipped() // ADD THIS to prevent any overflow
                        .background(Color.clear) // ADD THIS to ensure clean background
                        
                        // Performance Card
                        PerformanceCard(
                            showPerformance: $showPerformance,
                            cardBackground: cardBackground,
                            cardCornerRadius: cardCornerRadius,
                            runEngine: runEngine,
                            targetPace: viewModel.targetPace,
                            targetPaceSource: viewModel.targetPaceSource
                        )
                        .onAppear {
                            print("🎯 PerformanceCard: Target pace = \(viewModel.targetPace?.description ?? "nil"), Source = \(viewModel.targetPaceSource)")
                        }
                        .onChange(of: viewModel.targetPace) { newValue in
                            print("🎯 PerformanceCard: Target pace changed to = \(newValue?.description ?? "nil")")
                        }
                        .onChange(of: viewModel.targetPaceSource) { newValue in
                            print("🎯 PerformanceCard: Target pace source changed to = \(newValue)")
                        }
                       
                    
                            // Add space at the bottom for control buttons
                            Spacer().frame(height: 120)
                    }
                }
            }
            
            // Control buttons fixed at bottom
            VStack {
                Spacer()
                HStack(spacing: 24) {
                    // Stop button - Modern red gradient with shadow
                Button(action: {
                        // Trigger haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        viewModel.showEndRunConfirmation()
                }) {
                            Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#FF6B6B"), Color(hex: "#E53E3E")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white)
                                    .frame(width: 20, height: 20)
                                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                            )
                            .shadow(color: Color(hex: "#E53E3E").opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .scaleEffect(viewModel.isRunning ? 1.0 : 0.95)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isRunning)
                    
                    // Start/Pause button - Enhanced green gradient with animation
                Button(action: {
                        // Trigger haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        viewModel.toggleRunning()
                    }) {
                    Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#68D391"), Color(hex: "#38A169")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                            )
                            .shadow(color: Color(hex: "#38A169").opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .scaleEffect(viewModel.isRunning ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isRunning)
                    
                    // Lock button - Modern gray gradient with subtle shadow
                    // Lock button - Modern gray gradient with subtle shadow
            Button(action: {
                        // Trigger haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        
                       viewModel.toggleScreenLock()
                    }) {
                            Circle()
                           .fill(
                               LinearGradient(
                                   colors: [Color(hex: "#9CA3AF"), Color(hex: "#6B7280")],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing
                               )
                           )
                            .frame(width: 64, height: 64)
                            .overlay(
                               // REMOVE THE DUPLICATE OVERLAY - KEEP ONLY ONE:
                               Image(systemName: viewModel.isScreenLocked ? "lock.fill" : "lock.open.fill")
                                    .font(.system(size: 24))
                        .foregroundColor(.white)
                                   .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                            )
                           .shadow(color: Color(hex: "#6B7280").opacity(0.2), radius: 6, x: 0, y: 3)
                          
                    }
                   .scaleEffect(viewModel.isRunning ? 1.0 : 0.95)
                   .animation(.easeInOut(duration: 0.2), value: viewModel.isRunning)
                }
                .frame(maxWidth: .infinity) // Center the controls horizontally
                .padding(.bottom, geometry.safeAreaInsets.bottom + 16)
            }
        }
        // Add seamless background gradient to entire view
        .background(
            getBackgroundForRunType(viewModel.runType)
        )
    }
    
    var headerView: some View {
        // Remove the GeometryReader wrapper - this is likely causing layout issues
            HStack {
            Image("logo_45")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 45, height: 45)
            
            Text(viewModel.runType.rawValue)
                .font(.title2)
                .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
            // Map toggle button - Always visible with consistent icon
                Button(action: {
                    // Trigger haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    withAnimation {
                    showMap.toggle()
                    mapViewMode = showMap ? .normal : .hidden
                }
            }) {
                // Always use the same icon - don't change it based on state
                Image(systemName: "map.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.clear) // Ensure button has a clear background
                    .contentShape(Rectangle())
            }
            .buttonStyle(BorderlessButtonStyle())
            
            Spacer().frame(width: 24)
                
            Button(action: {
                // Trigger haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
                viewModel.showVoiceGuidanceSettings()
            }) {
                Image(systemName: "gear")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .frame(height: 60)
        .padding(.horizontal, 20)
        .padding(.top, 4) 
        .padding(.bottom, 16)
        // Updated background to seamlessly blend with main view
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    getBackgroundGradientStart(viewModel.runType),
                    Color(hex: "#0A0F1E")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // Extract Map Card to a separate struct
    // Extract Map Card to a separate struct (around line 520)
    struct MapCard: View {
        var mapView: MKMapView
        @Binding var mapViewMode: MapViewMode
        let mapCardHeight: CGFloat
        let cardCornerRadius: CGFloat
        let cardBackground: Color
        var onHomeButtonTapped: () -> Void
        let screenHeight: CGFloat
        @ObservedObject var viewModel: OutdoorRunViewController
        
        var body: some View {
            ZStack(alignment: .top) {
                // Main Map Card Content
        VStack(spacing: 0) {
                // Map Header
            HStack {
                    Text("MAP")
                        .font(.caption)
                                .foregroundColor(.gray)
                    
                    Spacer()
                
                    HStack(spacing: 16) {
                            // Dynamic Home/Clear Button
            Button(action: {
                                onHomeButtonTapped()
                            }) {
                                Image(systemName: viewModel.isReturnRouteEnabled ? "xmark.circle.fill" : "house.fill")
                                    .foregroundColor(viewModel.isReturnRouteEnabled ? .orange : .gray)
                                    .font(.system(size: 16, weight: .semibold))
                                    .animation(.easeInOut(duration: 0.2), value: viewModel.isReturnRouteEnabled)
                            }
                            .help(viewModel.isReturnRouteEnabled ? "Clear return route" : "Show return route")
                        
            Button(action: {
                            withAnimation {
                                mapViewMode = mapViewMode == .fullscreen ? .normal : .fullscreen
                            }
                        }) {
                            Image(systemName: mapViewMode == .fullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .foregroundColor(.gray)
                        }
                    }
                }
                    .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
                // Map View
                MapViewContainer(mapView: mapView, onHomeButtonTapped: onHomeButtonTapped, viewModel: viewModel)
                    .frame(height: mapViewMode == .fullscreen ? screenHeight * 0.7 : mapCardHeight)
                    .cornerRadius(cardCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: cardCornerRadius)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
        }
        .background(cardBackground)
            .cornerRadius(cardCornerRadius)
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                
                // Return Navigation Panel - Positioned at the very top
                VStack {
                    // Show navigation panel for either type of navigation
                    if viewModel.showNavigationPanel {
                        NavigationPanel(
                            instruction: viewModel.currentNavigationInstruction ?? "Continue navigation",
                            distance: viewModel.isNavigatingReturnRoute ? viewModel.distanceToNextInstruction : viewModel.distanceToNextTurn,
                            navigationType: viewModel.isNavigatingReturnRoute ? .returnRoute : .preloadedRoute,
                            onDismiss: {
                                if viewModel.isNavigatingReturnRoute {
                                    viewModel.disableReturnRouteFromPanel()
                                } else {
                                    viewModel.disableRouteNavigation()
                                }
                            }
                        )
                        .animation(.easeInOut(duration: 0.3), value: viewModel.isShowingNavigationPanel)
                        .padding(.top, 8) // Small padding from the very top of the card
                        
                        Spacer() // Push navigation panel to the top
                    }
                   
                }
            }
        }
    }

    // MARK: - Generic Navigation Panel SwiftUI View
    struct NavigationPanel: View {
        let instruction: String
        let distance: Double
        let navigationType: NavigationType
        let onDismiss: () -> Void
        
        enum NavigationType {
            case returnRoute
            case preloadedRoute
            
            var title: String {
                switch self {
                case .returnRoute: return "Return to Start"
                case .preloadedRoute: return "Route Navigation"
                }
            }
            
            var distanceLabel: String {
                switch self {
                case .returnRoute: return "to start location"
                case .preloadedRoute: return "to next turn"
                }
            }
        }
        
        var body: some View {
            VStack(spacing: 8) {
                // Header with navigation type
                HStack {
                    Text(navigationType.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title3)
                    }
                }
                
                // Main instruction and distance
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(instruction)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        Text(String(format: "%.0f m %@", distance, navigationType.distanceLabel))
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Direction arrow or icon
                    Image(systemName: navigationType == .returnRoute ? "house.fill" : "arrow.turn.up.right")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
            .padding()
            .background(Color.black.opacity(0.85))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    // Map View Container
    struct MapViewContainer: UIViewRepresentable {
        let mapView: MKMapView
        let onHomeButtonTapped: () -> Void
        let viewModel: OutdoorRunViewController // Add viewModel
        
        func makeUIView(context: Context) -> UIView {
            let container = UIView()
            
            // Make sure mapView has proper constraints
            mapView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(mapView)
            
            // Configure map view
            mapView.showsUserLocation = true
            mapView.userTrackingMode = .follow
            mapView.delegate = viewModel
            
            
            // Setup constraints
            NSLayoutConstraint.activate([
                mapView.topAnchor.constraint(equalTo: container.topAnchor),
                mapView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                mapView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                mapView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
            
            return container
        }
        
        func updateUIView(_ uiView: UIView, context: Context) {
            // IMPORTANT: Disable automatic region updates to prevent constant zooming
            // Instead of updating the region here, let the locationManager delegate handle it
            // Update button appearance when state changes
                    if let homeButton = context.coordinator.homeButton {
                        updateButtonAppearance(homeButton, isReturnRouteEnabled: viewModel.isReturnRouteEnabled)
                    }
            // Only update for initial setup or significant changes
            if mapView.overlays.isEmpty {
                // Add planned route if available
                if let route = viewModel.preSelectedRoute {
                    viewModel.loadPreSelectedRoute(route: route)
                } else if !viewModel.routePlanner.routePolyline.isEmpty {
                    viewModel.addPlannedRouteToMap()
                }
            }
            
            // Update run path if running and we don't have markers yet
            if viewModel.runEngine.runState == .running && viewModel.pathMarkers.isEmpty {
                if let currentLocation = viewModel.currentLocation {
                    viewModel.updateRunPath(with: currentLocation)
                }
            }
        }
        
        public func updateButtonAppearance(_ button: UIButton, isReturnRouteEnabled: Bool) {
                let symbolConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
                
                if isReturnRouteEnabled {
                    // Show clear button (X)
                    button.setImage(UIImage(systemName: "xmark.circle.fill")?.withConfiguration(symbolConfig), for: .normal)
                    button.tintColor = .systemOrange
                } else {
                    // Show home button
                    button.setImage(UIImage(systemName: "house.fill")?.withConfiguration(symbolConfig), for: .normal)
                    button.tintColor = .white
                }
                
                // Add subtle animation
                UIView.transition(with: button, duration: 0.2, options: .transitionCrossDissolve, animations: {
                    // The image and color changes above will be animated
                }, completion: nil)
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        class Coordinator: NSObject {
            let parent: MapViewContainer
                var homeButton: UIButton? // Store reference for updates
            
            init(_ parent: MapViewContainer) {
                self.parent = parent
            }
            
            @objc func homeButtonTapped() {
                parent.onHomeButtonTapped()
            }
        }
    }
    
    // Stats card component
    public func statsCard(title: String, value: String, unit: String, icon: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
            Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.body)
                
                Text(title)
                    .font(.caption)
                .foregroundColor(.gray)
            }
            
            HStack(alignment: .firstTextBaseline) {
            Text(value)
                    .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
                Text(unit)
                    .font(.caption)
                .foregroundColor(.gray)
                    .padding(.leading, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            cardBackground.opacity(0.6),
                            cardBackground.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
    }
    
    // Background gradient based on run type
    public func getBackgroundForRunType(_ runType: RunType) -> some View {
        switch runType {
        case .outdoorRun:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#0F1D44"),
                    Color(hex: "#0A0F1E")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        case .treadmillRun:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#1F1F35"),
                    Color(hex: "#0A0F1E")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        case .trailRun:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#213A22"),
                    Color(hex: "#0A0F1E")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        case .intervalTraining:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#3A2031"),
                    Color(hex: "#0A0F1E")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        case .recoveryRun:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#193A47"),
                    Color(hex: "#0A0F1E")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        case .lapRun:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#33302D"),
                    Color(hex: "#0A0F1E")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    // Helper function to get gradient start color for run type
    public func getBackgroundGradientStart(_ runType: RunType) -> Color {
        switch runType {
        case .outdoorRun:
            return Color(hex: "#0F1D44")
        case .treadmillRun:
            return Color(hex: "#1F1F35")
        case .trailRun:
            return Color(hex: "#213A22")
        case .intervalTraining:
            return Color(hex: "#3A2031")
        case .recoveryRun:
            return Color(hex: "#193A47")
        case .lapRun:
            return Color(hex: "#33302D")
        }
    }
    
    // Helper functions for performance card
    public func calculatePacePosition(in width: CGFloat) -> CGFloat {
        guard let targetPace = viewModel.targetPace else { return width * 0.5 }
        let currentPace = runEngine.pace.value > 0 ? min(max(runEngine.pace.value, 120), 1800) : targetPace

        // Calculate position based on pace difference from target
        let paceDiff = currentPace - targetPace
        let maxDiff = targetPace * 0.5 // 50% difference from target
        
        // Normalize the position between 0 and width
        let normalizedPosition = (paceDiff + maxDiff) / (2 * maxDiff)
        return max(0, min(width, width * normalizedPosition))
    }
    
    public func calculateHeartRatePosition(in width: CGFloat) -> CGFloat {
        let currentHR = runEngine.heartRate
        let maxHR = 220.0 // Simplified max heart rate calculation
        
        // Calculate position based on current heart rate
        let normalizedPosition = currentHR / maxHR
        return max(0, min(width, width * normalizedPosition))
    }
}

// Note: MapViewMode is now defined in TrackingModels.swift

class OutdoorRunViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, ObservableObject {
    
    // MARK: - Properties
    public var runEngine = RunTrackingEngine.shared
    public let locationManager = ModernLocationManager.shared
    // Add a computed property to safely expose the current location
    var currentLocation: CLLocation? {
        return locationManager.location
    }
    public let routePlanner = RoutePlanner.shared
    public let weatherService = WeatherService.shared
    public var metricsCoordinator: MetricsCoordinator?
    public var cancellables = Set<AnyCancellable>()
    public var hostingController: UIHostingController<OutdoorRunTrackerView>?
    
    // Add the route property used in the animation methods
    public var route: Route?
    
    // Add property for return route functionality
    public var isReturnRouteEnabled: Bool = false
    public var returnRouteOverlay: MKPolyline?
    
    // Add property for home location
    public var homeLocation: CLLocationCoordinate2D?
    
    // Audio feedback
    public let speechSynthesizer = AVSpeechSynthesizer()
    public var lastAnnouncement: Date?
    public var announcementInterval: TimeInterval = 300 // Every 5 minutes by default
    public var audioSession: AVAudioSession?
    public var audioEngine: AVAudioEngine?
    public var audioPlayer: AVAudioPlayer?
    public var defaultVoice: AVSpeechSynthesisVoice?
    
    // Announcement queue system
    public var announcementQueue: [String] = []
    public var isAnnouncementInProgress: Bool = false
    public var minimumTimeBetweenAnnouncements: TimeInterval = 1.0
    
    // Map overlay properties
    public var routeOverlay: MKPolyline?
    public var progressOverlay: MKPolyline?
    public var mileMarkers: [MKPointAnnotation] = []
    
    // Watch communication throttling
    public var lastWatchUpdateTime: TimeInterval = 0
    public let watchCommunicationInterval: TimeInterval = 20.0 // Reduced to 20 seconds to minimize communication
    
    // MARK: - Simplified Timer Properties
    /// The actual start date of the workout (from watch or when started locally)
    public var workoutStartDate: Date?
    /// Current elapsed time displayed to user (incremented every second)
    public var displayElapsedTime: TimeInterval = 0
    /// Simple timer that fires every second
    public var simpleTimer: Timer?
    
    // Interface mode - using module-level MapViewMode enum
    @Published var mapViewMode: MapViewMode = .normal
    @Published var isShowingMetricsPanel = true
    @Published var isShowingPerformanceView = false
    @Published var mapType: MKMapType = .standard
    
    // Performance data
    @Published var historicalPaces: [Double] = []
    @Published var currentPaceStatus: PaceStatus = .onTarget
    @Published var paceHistory: [Double] = []
    @Published var heartRateHistory: [Double] = []
    @Published var elevationProfile: [Double] = []
    @Published var targetPace: Double?
    @Published var targetPaceSource: String = "Default"
    @Published var runGoal: RunGoal?
    @Published var currentHeartRateZone: Int = 0
    
    // Run configuration
    var runType: RunType = .outdoorRun
    // Added property to handle pre-selected routes
    var preSelectedRoute: Route?
    
    // Run history cache
    private var outdoorRuns: [RunLog] = []
    private var indoorRuns: [RunLog] = [] // IndoorRunLog is a type alias for RunLog
    
    // Watch connectivity
    public var session: WCSession?
    @Published var isWatchConnected = false
    @Published var watchBatteryLevel: Double = -1
    
    // Navigation properties
    @Published var isNavigatingToStart: Bool = false
    @Published var currentNavigationInstruction: String = ""
    @Published var distanceToNextInstruction: Double = 0
    @Published var routeCompletionPercentage: Double = 0.0
    @Published var showNavigationPanel: Bool = false
    
    // User avatar animation
    public var userAvatarAnnotation: MKPointAnnotation?
    public var animationTimer: Timer?
    public var routeCoordinateIndex: Int = 0
    public var isAnimatingRoute: Bool = false
    
    // Voice guidance settings
    @Published var isVoiceGuidanceEnabled = true
    @Published var voiceGuidanceVolume: Float = 0.7
    @Published var announcementType: AnnouncementType = .comprehensive
    @Published var paceGuidanceEnabled = true
    
    // State tracking
    public var isRunning = false
    public var isPaused = false
    public var hasCompletedRun = false
    public var lastPaceAnnouncement: Date?
    public var paceAnnouncementCooldown: TimeInterval = 60 // 1 minute cooldown for pace announcements
    
    // Screen lock functionality
    @Published var isScreenLocked = false
    public var screenLockOverlay: UIView?
    
    // Add properties for settings
    @Published var voiceGuidanceLevel: VoiceGuidanceLevel = .comprehensive
    @Published var announcementFrequency: AnnouncementFrequency = .every5Minutes
    @Published var includePaceGuidance: Bool = true
    @Published var includeHeartRateGuidance: Bool = true
    @Published var includeNavigationGuidance: Bool = true
    
    // Add property for return route functionality
    public var returnRoute: MKRoute? // For turn-by-turn directions
    public var returnRouteDirections: [String] = []
    public var currentReturnDirectionIndex: Int = 0

    // Return route navigation state
    @Published var currentReturnInstruction: String = ""
    // MARK: - Navigation Panel State
    @Published var distanceToNextTurn: Double = 0
    @Published var isShowingNavigationPanel: Bool = false

    // Navigation state management
    public var isNavigatingReturn: Bool = false
    public var returnNavigationStartTime: Date?
    
    // MARK: - Return Route Navigation State
    public var isNavigatingReturnRoute = false
    public var currentStepIndex = 0
    
    public var hasAnnouncedDeviation = false
    public var wasOnRouteLastCheck = true
    
    // MARK: - Enhanced Route Management System
    @Published var routeProgress: RouteProgress = RouteProgress()
    @Published var currentRouteWaypoint: RouteWaypoint?
    @Published var isOnRoute: Bool = true
    @Published var routeDeviationDistance: Double = 0
    public var routeProgressOverlay: MKPolyline?
    public var routeRemainingOverlay: MKPolyline?
    
    // Add these properties to store waypoints and enhance functionality
    public var currentWaypoints: [RouteWaypoint] = []
    public var routeStartTime: Date?
    public var lastWaypointAnnouncementTime: Date = Date.distantPast
    
    // Add delegate property
    weak var delegate: OutdoorRunViewControllerDelegate?

    struct RouteProgress {
        var completedDistance: Double = 0
        var remainingDistance: Double = 0
        var completionPercentage: Double = 0
        var estimatedTimeRemaining: TimeInterval = 0
        var nextWaypointDistance: Double = 0
    }

    struct RouteWaypoint {
        let coordinate: CLLocationCoordinate2D
        let instruction: String
        let type: WaypointType
        let distanceFromStart: Double
    }

    enum WaypointType {
        case start
        case turn(direction: TurnDirection)
        case landmark(String)
        case checkpoint
        case finish
    }

    enum TurnDirection: CustomStringConvertible {
        case left, right, straight, sharpLeft, sharpRight, uTurn
        
        var description: String {
            switch self {
            case .left: return "Turn left"
            case .right: return "Turn right"
            case .straight: return "Continue straight"
            case .sharpLeft: return "Sharp left turn"
            case .sharpRight: return "Sharp right turn"
            case .uTurn: return "Make a U-turn"
            }
        }
    }
    
    
    
    // Add enum for voice guidance levels
    enum VoiceGuidanceLevel: String, CaseIterable {
        case none = "No Audio"
        case minimal = "Minimal"
        case moderate = "Moderate"
        case comprehensive = "Detailed"
        
        var description: String {
            switch self {
            case .none: return "Complete silence - no voice announcements"
            case .minimal: return "Basic stats only"
            case .moderate: return "Key stats and navigation"
            case .comprehensive: return "All stats, navigation, and guidance"
            }
        }
    }
    
    // Add enum for announcement frequencies
    enum AnnouncementFrequency: String, CaseIterable {
        case every2Minutes = "Every 2 minutes"
        case every5Minutes = "Every 5 minutes"
        case every10Minutes = "Every 10 minutes"
        case every15Minutes = "Every 15 minutes"
        
        var interval: TimeInterval {
            switch self {
            case .every2Minutes: return 120
            case .every5Minutes: return 300
            case .every10Minutes: return 600
            case .every15Minutes: return 900
            }
        }
    }
    
    // MARK: - UI Components
    private (set) var mapView: MKMapView = {
        let map = MKMapView()
        map.translatesAutoresizingMaskIntoConstraints = false
        map.showsUserLocation = true
        map.userTrackingMode = .follow
        map.mapType = .standard
        map.showsCompass = true
        map.showsScale = true
        map.showsTraffic = false
        map.showsBuildings = true
        return map
    }()
    
    public let gradientOverlayView: GradientOverlayView = {
        let overlay = GradientOverlayView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.alpha = 0.7
        return overlay
    }()
    
    // Add these properties to the class
    public var trackerView: UIView?
    public let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#0A0F1E")
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Flag to indicate if this is joining an existing workout from watch
    var isJoiningExistingWorkout: Bool = false
    /// The actual start date from the watch when joining an existing workout
    var watchWorkoutStartDate: Date?
    
    // MARK: - Navigation Panel Methods
    public func setupNavigationPanelUpdates() {
        // Set up timer or observer for navigation panel updates
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isNavigatingReturnRoute else { return }
            
            DispatchQueue.main.async {
                // Update navigation panel with current state
                self.isShowingNavigationPanel = self.isNavigatingReturnRoute
                // distanceToNextTurn is updated in checkReturnRouteProgress
            }
        }
    }
    
    @objc public func disableRouteNavigation() {
        // Disable regular route navigation
        routePlanner.navigationActive = false
        showNavigationPanel = false
        
        // Reset navigation state
        currentNavigationInstruction = ""
        distanceToNextTurn = 0
        
        announceMessage("Route navigation disabled")
    }

    @objc public func disableReturnRouteFromPanel() {
        // Disable return route when called from navigation panel
        isReturnRouteEnabled = false
        isNavigatingReturnRoute = false
        isShowingNavigationPanel = false
        
        // Remove return route overlay from map
        if let overlay = returnRouteOverlay {
            mapView.removeOverlay(overlay)
            returnRouteOverlay = nil
        }
        
        // Reset navigation state
        currentStepIndex = 0
        hasAnnouncedDeviation = false
        wasOnRouteLastCheck = true
        
        // Update UI
        DispatchQueue.main.async {
            self.currentNavigationInstruction = ""
            self.distanceToNextInstruction = 0
            self.distanceToNextTurn = 0
        }
        
        announceMessage("Return route disabled")
    }
    
    public func updateNavigationPanel() {
        // Show panel for return route navigation
        if isReturnRouteEnabled && isShowingNavigationPanel {
            showNavigationPanel = true
            currentNavigationInstruction = currentReturnInstruction ?? "Navigating to start location"
            distanceToNextInstruction = calculateDistanceToReturnDestination()
        }
        // Show panel for regular route navigation
        else if routePlanner.navigationActive && currentRouteWaypoint != nil {
            showNavigationPanel = true
            currentNavigationInstruction = currentRouteWaypoint?.instruction ?? "Continue on route"
            distanceToNextInstruction = routeProgress.nextWaypointDistance
        }
        // Hide panel when no navigation
        else {
            showNavigationPanel = false
            currentNavigationInstruction = ""
            distanceToNextInstruction = 0
        }
    }

    public func calculateDistanceToReturnDestination() -> Double {
        guard let homeLocation = homeLocation,
              let currentLocation = locationManager.location else { return 0 }
        
        let homeCL = CLLocation(latitude: homeLocation.latitude, longitude: homeLocation.longitude)
        return currentLocation.distance(from: homeCL)
    }
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Fix status bar color to match gradient
        if #available(iOS 13.0, *) {
            let statusBarManager = view.window?.windowScene?.statusBarManager
            let statusBarView = UIView(frame: statusBarManager?.statusBarFrame ?? CGRect.zero)
            statusBarView.backgroundColor = UIColor(getBackgroundGradientStart(runType))
            view.addSubview(statusBarView)
        }
        
        // Get the shared run engine
        runEngine = RunTrackingEngine.shared
        
        // Setup UI components and layout
        setupHostingController()
        
        // Setup workout communication
        setupWorkoutCommunication()
        
        // Configure map view
        setupMapView()
        
        // Configure location manager
        configureLocationManager()
        
        // Load voice guidance settings
        loadVoiceGuidanceSettings()
        
        // Setup audio services for voice announcements
        setupAudioServices()
        
        // Setup data bindings
        setupBindings()
        
        // Load run goals and historical data
        loadRunGoalAndHistoricalData()
        
        // Setup route planner
        setupRoutePlanner()
        
        // Setup timers for announcements and UI updates
        setupVoiceAnnouncementTimer()
        
        // Setup our independent UI timer
        setupUITimer()
        
        // Update UI to initial state
        updateStatusDisplay()
        
        // Add observers for app state changes to ensure continuous tracking
        setupAppStateHandling()
        
        // Set up notification for return route dismissal
           NotificationCenter.default.addObserver(
               self,
               selector: #selector(disableReturnRouteFromPanel),
               name: NSNotification.Name("DisableReturnRoute"),
               object: nil
           )
           
           // Set up navigation panel updates
           setupNavigationPanelUpdates()
        
        print("OutdoorRunViewController loaded successfully")
        
        // Check for saved incremental state first
        let restoredState = runEngine.restoreIncrementalState()
        
        if restoredState {
            print("🏃‍♂️ Restored previous run state from incremental save")
            
            // Update UI with restored metrics
            updateUIWithLatestMetrics()
            
            // Update map route if we have location data
            if let latestLocation = locationManager.location {
                updateRunPath(with: latestLocation)
            }
            
            // Update status display based on restored run state
            isRunning = runEngine.runState == .running
            isPaused = runEngine.runState == .paused
            updateStatusDisplay()
            
            // Show a message to the user
            let message = "Previous run restored"
            showToast(message: message)
        } else {
            // No state to restore, check if we're joining an existing workout or need to start a new one
            if isJoiningExistingWorkout {
                print("📱 Joining existing workout from watch, skipping auto-start")
                
                // Update UI immediately with current metrics
                updateUIWithLatestMetrics()
                
                // Force a full UI refresh to ensure timer is visible and updating
                objectWillChange.send()
                
                // Update status display based on run engine state
                isRunning = runEngine.runState == .running
                isPaused = runEngine.runState == .paused
                updateStatusDisplay()
                
                // Ensure the run engine timer is active
                if runEngine.ensureTimerIsRunning() {
                    print("📱 Timer was restarted for joined workout")
                }
                
                // IMPORTANT: Set the run state to running so syncWorkoutData messages are processed
                // The engine was imported with data but state remains notStarted
                if runEngine.runState == .notStarted {
                    print("📱 Setting run state to running for joined outdoor workout")
                    runEngine.runState = .running
                    
                    // Also ensure the timer is started in the engine
                    runEngine.ensureTimerIsRunning()
                }
                // Start or restart the UI timer for time display updates
                if runEngine.runState == .running {
                    // Use simplified timer with actual start date from watch
                    if let startDate = watchWorkoutStartDate {
                        setupSimplifiedTimer(startDate: startDate)
                        print("🕒 Simplified timer started for joined workout with actual start date: \(startDate)")
                    } else {
                        // Fallback to old logic if no start date available
                        startUITimer()
                        print("🕒 Fallback UI Timer started for joined workout")
                    }
                } else if runEngine.runState == .paused {
                    // For paused state, still setup the timer but it won't increment
                    if let startDate = watchWorkoutStartDate {
                        setupSimplifiedTimer(startDate: startDate)
                        print("🕒 Simplified timer setup for paused joined workout with actual start date: \(startDate)")
                    } else {
                        // Fallback to old sync logic
                        syncTimeWithEngine(forceSync: true)
                        print("🕒 Time synced for paused joined workout")
                    }
                }
                
                // If we're joining an outside run with the watch, check distance once
                if !runEngine.isPrimaryForDistance && !runEngine.isIndoorMode {
                    print("📱 Initiating one-time distance catch-up with watch")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.runEngine.catchUpDistanceWithWatch()
                    }
                }
                
                // Update the map with existing route path
                if let lastLocation = locationManager.location {
                    updateRunPath(with: lastLocation)
                }
                
                // Show a message to the user
                let message = "Joined watch workout"
                showToast(message: message)
            } else {
                // Automatically start a new run after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    print("🏃‍♂️ Automatically starting new run...")
                    self.startRun()
                }
            }
        }
    }
    
    public func getBackgroundGradientStart(_ runType: RunType) -> Color {
        switch runType {
        case .outdoorRun:
            return Color(hex: "#0F1D44")
        case .treadmillRun:
            return Color(hex: "#1F1F35")
        case .trailRun:
            return Color(hex: "#213A22")
        case .intervalTraining:
            return Color(hex: "#3A2031")
        case .recoveryRun:
            return Color(hex: "#193A47")
        case .lapRun:
            return Color(hex: "#33302D")
        }
    }
    
    // Add method to handle app state changes
    public func setupAppStateHandling() {
        // Register for app state notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        print("🔄 App state handling observers configured")
    }
    
    @objc public func handleAppWillResignActive() {
        print("📱 App going to background - ensuring tracking continues")
        
        // Make sure location updates continue in background
        locationManager.allowsBackgroundLocationUpdates = true
        
        // Ensure audio session is active to maintain background operation
        LoudnessManager.shared.startBackgroundAudio()
        
        // Explicitly tell the run engine to maintain tracking
        if runEngine.runState == .running {
            // Save current state in case of termination
            runEngine.saveIncremental()
            
            print("🏃‍♂️ Run is active, background tracking enabled")
        }
    }
    
    @objc public func handleAppDidBecomeActive() {
        print("📱 App returning to foreground - resuming UI updates")
        
        // Refresh data from run engine
        updateUIWithLatestMetrics()
        
        // Refresh map if needed
        if runEngine.runState == .running {
            updateRunPath(with: locationManager.location ?? CLLocation())
        }
    }
    
    @objc public func handleAppWillTerminate() {
        print("📱 App about to terminate - saving run state")
        
        // Make sure we save current run state
        if runEngine.runState == .running || runEngine.runState == .paused {
            runEngine.saveIncremental()
        }
    }
    
    public func setupWorkoutCommunication() {
        // Set this view controller as the delegate for workout communication
        WorkoutCommunicationHandler.shared.delegate = self
        
        // Start listening for workout updates
        print("📱 Set up workout communication - now listening for watch updates")
        
        // Add watch connectivity change observer
        NotificationCenter.default.addObserver(
            self, 
            selector: #selector(handleWatchConnectivityChanged), 
            name: NSNotification.Name("WatchConnectivityChanged"), 
            object: nil
        )
        
        // Send initial status to watch in background to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
        if WCSession.default.activationState == .activated && WCSession.default.isReachable {
            let message: [String: Any] = [
                "type": "trackingStatus",
                "isPhoneTracking": true
            ]
                
                // Use atomic flag pattern to prevent multiple completions
                let operationCompleted = AtomicFlag()
                
                // Create a timeout timer
                var timeoutTimer: Timer? = nil
                timeoutTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                    // Only execute if this is the first completion
                    if operationCompleted.testAndSet() {
                        print("📱 Initial watch communication timed out")
                        timeoutTimer?.invalidate()
                    }
                }
            
            WCSession.default.sendMessage(message, replyHandler: { response in
                    // Only execute if this is the first completion
                    if operationCompleted.testAndSet() {
                        timeoutTimer?.invalidate()
                print("📱 Watch acknowledged tracking status")
                    }
            }, errorHandler: { error in
                    // Only execute if this is the first completion
                    if operationCompleted.testAndSet() {
                        timeoutTimer?.invalidate()
                print("📱 Error sending tracking status to watch: \(error.localizedDescription)")
                    }
            })
                
                // Let the runloop process the timer
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.6))
        } else {
            print("📱 Watch not reachable, will connect when available")
            }
        }
    }
    
    public func setupOutdoorRunNotifications() {
        // Add observer for outdoor run state change messages from watch
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOutdoorRunStateChangeFromWatch),
            name: NSNotification.Name("OutdoorRunStateChangeReceived"),
            object: nil
        )
        
        print("📱 OutdoorRunViewController: Set up outdoor run state change notifications")
    }
    
    @objc public func handleOutdoorRunStateChangeFromWatch(_ notification: Notification) {
        print("📱 OutdoorRunViewController: Received outdoor run state change from watch")
        
        guard let userInfo = notification.userInfo,
            let command = userInfo["command"] as? String else {
            print("📱 OutdoorRunViewController: Missing command in notification")
            return
        }
        
        print("📱 OutdoorRunViewController: Processing command: \(command)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch command {
            case "paused":
                if self.runEngine.runState == .running {
                    print("📱 OutdoorRunViewController: Pausing from watch command")
                    // Call runEngine directly - this will fire notifications to update UI
                    self.runEngine.pauseRun()
                    
                    // Update UI state immediately
                    self.isRunning = false
                    self.isPaused = true
                    
                    // Stop location updates to save battery
                    self.locationManager.stopUpdatingLocation()
                    
                    // Update status display
                    self.updateStatusDisplay()
                }
            case "inProgress":
                if self.runEngine.runState == .paused {
                    print("📱 OutdoorRunViewController: Resuming from watch command")
                    // Call runEngine directly - this will fire notifications to update UI
                    self.runEngine.resumeRun()
                    
                    // Update UI state immediately
                    self.isRunning = true
                    self.isPaused = false
                    
                    // Resume location updates
                    self.locationManager.startUpdatingLocation()
                    
                    // Update status display
                    self.updateStatusDisplay()
                }
            case "completed":
                if self.runEngine.runState == .running || self.runEngine.runState == .paused {
                    print("📱 OutdoorRunViewController: Ending from watch command")                    
                    // Update UI state immediately
                    self.isRunning = false
                    self.isPaused = false
                    self.hasCompletedRun = true
                    
                    // Stop location updates
                    self.locationManager.stopUpdatingLocation()
                    
                    // Show run summary
                    self.showRunSummary()
                }
            default:
                print("📱 OutdoorRunViewController: Unknown command: \(command)")
            }
        }
    }
    
    // Handle watch connectivity changes
    @objc public func handleWatchConnectivityChanged(_ notification: Notification) {
        guard let isReachable = notification.userInfo?["isReachable"] as? Bool else { return }
        
        DispatchQueue.main.async {
            if isReachable {
                print("📱 Watch is now reachable")
                // Send status update to synchronize
                self.sendTrackingStatusToWatch()
            } else {
                print("📱 Watch is no longer reachable")
                // Ensure we're using phone-based tracking
                self.runEngine.evaluatePrimarySource()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        locationManager.startUpdatingLocation()
        UIApplication.shared.isIdleTimerDisabled = true // Prevent screen sleep
        
        // CRITICAL FIX: Sync UI timer with engine when returning to screen
        // This prevents the timer display from being out of sync after navigation
        if runEngine.runState == .running || runEngine.runState == .paused {
            print("⏱️ Syncing UI timer on viewWillAppear - engine time: \(String(format: "%.2f", runEngine.elapsedTime)), display time: \(String(format: "%.2f", displayElapsedTime))")
            syncTimeWithEngine(forceSync: true, fromExternal: true)
            
            // If the timer isn't running but should be (because we're in running state), restart it
            if runEngine.runState == .running && uiTimer == nil {
                startUITimer()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // CRITICAL FIX: Sync with engine before disappearing to ensure accurate time tracking
        if runEngine.runState == .running || runEngine.runState == .paused {
            syncTimeWithEngine(forceSync: true)
            print("⏱️ Synced UI timer on viewWillDisappear - display time: \(String(format: "%.2f", displayElapsedTime))")
        }
        
        if !hasCompletedRun && isRunning {
            // If navigating away while running, pause tracking
            runEngine.pauseRun()
        }
        UIApplication.shared.isIdleTimerDisabled = false
        
        // Clean up audio resources
        audioPlayer?.stop()
        audioPlayer = nil
        audioEngine?.stop()
        audioEngine = nil
        try? audioSession?.setActive(false)
    }
    
    // MARK: - Setup Methods
    public func setupUI() {
        view.backgroundColor = UIColor(hex: "#0A0F1E") // Dark background
        
        // Add mapView to view hierarchy
        view.addSubview(mapView)
        view.addSubview(gradientOverlayView)
        view.addSubview(headerView)
        
        // Set the map delegate
        mapView.delegate = self
        
        // Setup constraints for map
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Header view constraints
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60), // Use an appropriate height
            
            // Gradient overlay at bottom of screen
            gradientOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            gradientOverlayView.heightAnchor.constraint(equalToConstant: 300)
        ])
        
        // Set map style based on run type
        setupMapStyleForRunType()
    }
    
    public func configureLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // Update every 5 meters for more accuracy
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.startUpdatingLocation()
    }
    
    public func setupBindings() {
        // Bind to run engine state changes
        runEngine.$runState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.handleRunStateChange(state)
            }
            .store(in: &cancellables)
        
        // Add a specific binding for elapsed time updates
        runEngine.$elapsedTime
            .throttle(for: .seconds(1.0), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                self?.updateUIWithLatestMetrics()
            }
            .store(in: &cancellables)
        
        // Bind to locationList changes to update map
        runEngine.$locationList
            .receive(on: RunLoop.main)
            .map { locationDataArray -> [CLLocation] in
                // Convert LocationData array to CLLocation array
                return locationDataArray.map { locationData in
                    return CLLocation(
                        coordinate: CLLocationCoordinate2D(
                            latitude: locationData.latitude,
                            longitude: locationData.longitude
                        ),
                        altitude: locationData.altitude,
                        horizontalAccuracy: locationData.horizontalAccuracy,
                        verticalAccuracy: locationData.verticalAccuracy,
                        course: locationData.course,
                        speed: locationData.speed,
                        timestamp: locationData.timestamp
                    )
                }
            }
            .sink { [weak self] locations in
                self?.updateMapRoute(with: locations)
            }
            .store(in: &cancellables)
            
        // Bind to heart rate changes for UI updates
        runEngine.$heartRate
            .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] heartRate in
                self?.updateHeartRateDisplay()
                
                // Add to history for graphs
                if heartRate > 0 {
                    self?.heartRateHistory.append(heartRate)
                    // Keep a reasonable amount of data points for performance
                    if self?.heartRateHistory.count ?? 0 > 100 {
                        self?.heartRateHistory.removeFirst()
                    }
                }
            }
            .store(in: &cancellables)
            
        // Bind to distance for mile marker updates
        runEngine.$distance
            .throttle(for: .seconds(2), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] distance in
                self?.updateMileMarkers(for: distance)
            }
            .store(in: &cancellables)
            
        // Bind to pace for pace feedback
        runEngine.$pace
            .throttle(for: .seconds(5), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] pace in
                guard let self = self else { return }
                
                // Add to pace history for graphs
                let paceValue = pace.value
                if paceValue > 0 {
                    self.paceHistory.append(paceValue)
                    // Keep a reasonable amount of data points for performance
                    if self.paceHistory.count > 100 {
                        self.paceHistory.removeFirst()
                    }
                    
                    // Update pace status based on target or historical data
                    self.updatePaceStatus(currentPace: paceValue)
                    
                    // Debug: Log current pace and status
                    print("📊 Current pace: \(paceValue) min/km, Status: \(self.currentPaceStatus)")
                    if let targetPace = self.targetPace {
                        print("📊 Target pace: \(targetPace) sec/km (converted: \(targetPace/60.0) min/km)")
                    }
                    
                    // Check if we should provide pace guidance
                    self.checkForPaceGuidance()
                }
            }
            .store(in: &cancellables)
            
        // Bind to mapViewMode changes
        $mapViewMode
            .sink { [weak self] mode in
                self?.updateMapDisplay(mode: mode)
            }
            .store(in: &cancellables)
            
        // Bind to mapType changes
        $mapType
            .sink { [weak self] mapType in
                self?.mapView.mapType = mapType
            }
            .store(in: &cancellables)
            
        // Bind to elevation changes
        runEngine.$elevationGain
            .throttle(for: .seconds(5), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] elevation in
                // Add to elevation profile for graphs
                self?.elevationProfile.append(elevation.value)
                // Keep a reasonable amount of data points for performance
                if self?.elevationProfile.count ?? 0 > 100 {
                    self?.elevationProfile.removeFirst()
                }
            }
            .store(in: &cancellables)
        
        // Add observer for run metrics updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRunMetricsUpdate),
            name: .didUpdateRunMetrics, 
            object: nil
        )
        
        // Setup screen lock bindings
        setupScreenLockBindings()
    }
    
    // Add a method to update UI with latest metrics
    public func updateUIWithLatestMetrics() {
        // Always ensure UI updates happen on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.updateUIWithLatestMetrics()
            }
            return
        }
        
        // Now we're guaranteed to be on the main thread
        guard !isPaused || runEngine.runState != .paused else { return }
        
        // Notify observers that metrics have changed
        objectWillChange.send()
        
        // Post notification for metrics update - using a more efficient approach
        // that doesn't require recreating the entire view hierarchy
        NotificationCenter.default.post(name: NSNotification.Name("MetricsDidUpdate"), object: nil)
    }
    
    // Handle run metrics updates notification - this now primarily syncs non-time metrics
    @objc public func handleRunMetricsUpdate() {
        // Check if there's a significant time difference between engine and display
        let engineElapsedTime = runEngine.elapsedTime
        let timeDifference = abs(engineElapsedTime - displayElapsedTime)
        
        if timeDifference > 5.0 {
            print("⏱️ Large time difference detected (\(String(format: "%.2f", timeDifference))s) - syncing with smooth transition")
            syncTimeWithEngine(forceSync: true, fromExternal: true)
        } else if lastSyncTime == nil || Date().timeIntervalSince(lastSyncTime!) >= syncInterval {
            // Normal periodic sync
            syncTimeWithEngine(forceSync: false, fromExternal: false)
        }
        
        // Update other metrics from the engine
        updateUIWithLatestMetrics()
    }
    
    public func setupHostingController() {
        // Set background color for the view controller
        view.backgroundColor = UIColor(hex: "#0A0F1E") // Dark background
        
        // Set the map delegate
        mapView.delegate = self
        
        // Set map style based on run type
        setupMapStyleForRunType()
        
        // Create the outdoor run tracker view with view model
        let outdoorRunTrackerView = OutdoorRunTrackerView(
            viewModel: self,
            mapView: self.mapView
        )
        
        // Create the hosting controller with the view
        hostingController = UIHostingController(rootView: outdoorRunTrackerView)
        
        if let hostingController = hostingController {
            addChild(hostingController)
            view.addSubview(hostingController.view)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            hostingController.view.backgroundColor = .clear
            
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
            hostingController.didMove(toParent: self)
        }
    }
    
    public func setupWatchConnectivity() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            self.session = session
            
            // Initial check for watch reachability
            self.isWatchConnected = session.isReachable
        }
    }
    
    public func setupMetricsCoordinator() {
        metricsCoordinator = MetricsCoordinator(runEngine: runEngine)
    }
    
    public func loadUserPreferences() {
        // Load voice guidance settings
        isVoiceGuidanceEnabled = UserDefaults.standard.bool(forKey: "voiceGuidanceEnabled")
        voiceGuidanceVolume = UserDefaults.standard.float(forKey: "voiceGuidanceVolume")
        
        // Load announcement type
        if let announcementValue = UserDefaults.standard.string(forKey: "announcementType"),
           let announcementType = AnnouncementType(rawValue: announcementValue) {
            self.announcementType = announcementType
        }
        
        // Set announcement interval
        let interval = UserDefaults.standard.double(forKey: "announcementInterval")
        announcementInterval = interval > 0 ? interval : 300 // Default to 5 minutes
    }
    
    public func setupMapStyleForRunType() {
        // Set different map styles and backgrounds based on run type
        switch runType {
        case .outdoorRun:
            mapView.mapType = .standard
            gradientOverlayView.updateGradient(colors: [
                UIColor(hex: "#0F1D44").withAlphaComponent(0.1).cgColor,
                UIColor(hex: "#0A0F1E").withAlphaComponent(0.9).cgColor
            ])
            // Set route color for outdoor runs
            routeColor = UIColor(hex: "#4A90E2") // Blue for outdoor runs
            progressColor = UIColor(hex: "#50E3C2") // Teal for progress
            
        case .treadmillRun:
            mapView.mapType = .mutedStandard
            gradientOverlayView.updateGradient(colors: [
                UIColor(hex: "#1F1F35").withAlphaComponent(0.1).cgColor,
                UIColor(hex: "#0A0F1E").withAlphaComponent(0.9).cgColor
            ])
            routeColor = UIColor(hex: "#9B59B6") // Purple for treadmill
            progressColor = UIColor(hex: "#E74C3C") // Red for progress
            
        case .trailRun:
            mapView.mapType = .hybrid
            gradientOverlayView.updateGradient(colors: [
                UIColor(hex: "#213A22").withAlphaComponent(0.1).cgColor,
                UIColor(hex: "#0A0F1E").withAlphaComponent(0.9).cgColor
            ])
            routeColor = UIColor(hex: "#2ECC71") // Green for trails
            progressColor = UIColor(hex: "#F1C40F") // Yellow for progress
            
        case .intervalTraining:
            mapView.mapType = .standard
            gradientOverlayView.updateGradient(colors: [
                UIColor(hex: "#3A2031").withAlphaComponent(0.1).cgColor,
                UIColor(hex: "#0A0F1E").withAlphaComponent(0.9).cgColor
            ])
            routeColor = UIColor(hex: "#E74C3C") // Red for intervals
            progressColor = UIColor(hex: "#3498DB") // Blue for progress
            
        case .recoveryRun:
            mapView.mapType = .mutedStandard
            gradientOverlayView.updateGradient(colors: [
                UIColor(hex: "#193A47").withAlphaComponent(0.1).cgColor,
                UIColor(hex: "#0A0F1E").withAlphaComponent(0.9).cgColor
            ])
            routeColor = UIColor(hex: "#3498DB") // Blue for recovery
            progressColor = UIColor(hex: "#2ECC71") // Green for progress
            
        case .lapRun:
            mapView.mapType = .standard
            gradientOverlayView.updateGradient(colors: [
                UIColor(hex: "#33302D").withAlphaComponent(0.1).cgColor,
                UIColor(hex: "#0A0F1E").withAlphaComponent(0.9).cgColor
            ])
            routeColor = UIColor(hex: "#F39C12") // Orange for laps
            progressColor = UIColor(hex: "#9B59B6") // Purple for progress
        }
    }
    
    // Add properties for route colors
    public var routeColor: UIColor = UIColor(hex: "#4A90E2")
    public var progressColor: UIColor = UIColor(hex: "#50E3C2")
    
    // Add property for tracking run path
    public var runPathOverlay: MKPolyline?
    
    // MARK: - State Handling
    public func handleRunStateChange(_ state: RunState) {
        switch state {
        case .notStarted:
            isRunning = false
            isPaused = false
        case .running:
            isRunning = true
            isPaused = false
            // Configure map for tracking
            if runEngine.isAutoCenter {
                mapView.userTrackingMode = .follow
            }
            // Begin voice guidance if enabled
            if isVoiceGuidanceEnabled {
                announceStartOfRun()
            }
        case .paused:
            isRunning = false // Change to false to properly update button UI
            isPaused = true
            // Announce pause if voice enabled
            if isVoiceGuidanceEnabled {
                announceMessage("Run paused")
            }
            // Update watch
            sendTrackingStatusToWatch()
        case .completed:
            isRunning = false
            isPaused = false
            hasCompletedRun = true
            // Final announcement if voice enabled - ONLY ONCE
            if isVoiceGuidanceEnabled && !announcementDone {
                announceRunSummary()
            }
            // Show run summary when completed
            showRunSummary()
            // Update watch
            sendTrackingStatusToWatch()
        }
        
        // Force UI update
        objectWillChange.send()
    }
    
    // MARK: - Map Updates
    public func updateMapRoute(with locations: [CLLocation]) {
        guard locations.count > 1 else { return }
        
        // Create polyline from coordinates
        let coordinates = locations.map { $0.coordinate }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        
        // Store reference to run path for proper styling
        runPathOverlay = polyline
        
        // Remove old progress overlay if it exists
        if let oldOverlay = progressOverlay {
            mapView.removeOverlay(oldOverlay)
        }
        
        // Store new overlay reference and add to map
        progressOverlay = polyline
        mapView.addOverlay(polyline, level: .aboveRoads)
        
        print("🗺️ Updated run path on map with \(coordinates.count) points")
        
        // Update region to follow user if auto-centering is enabled
        if runEngine.isAutoCenter {
            if let lastLocation = locations.last {
                // Create a smaller region to zoom in closer to the runner's position
                let region = MKCoordinateRegion(
                    center: lastLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003) // Zoomed in more
                )
                mapView.setRegion(region, animated: true)
            }
        }
        
        // Update return route if enabled
        if isReturnRouteEnabled && locations.count > 5 {
            updateReturnRoute(from: locations.last!.coordinate)
        }
        
        // Add current location annotation if it doesn't exist
        updateRunnerAnnotation(at: locations.last!)
    }
    
    public func updateReturnRoute(from currentLocation: CLLocationCoordinate2D) {
        guard let startLocation = runEngine.locationList.first?.coordinate else { return }
        
        // Remove old return route if exists
        if let returnRoute = returnRouteOverlay {
            mapView.removeOverlay(returnRoute)
        }
        
        // Create a direct path from current location to start
        var returnCoordinates: [CLLocationCoordinate2D] = []
        
        // Add current location
        returnCoordinates.append(currentLocation)
        
        // Add start location - simplified path (direct line)
        returnCoordinates.append(startLocation)
        
        // If we have more than 10 points in our run, add some intermediate points 
        // to create a smoothed return path
        if runEngine.locationList.count > 10 {
            // Create a smoothed path back to start with fewer points than the full run
            // This makes it visually distinct and clearer for navigation
            let stepSize = max(1, runEngine.locationList.count / 4)
            var smoothedPath: [CLLocationCoordinate2D] = []
            
            // Add current location
            smoothedPath.append(currentLocation)
            
            // Add intermediate points with offset for visual distinction
            for i in stride(from: 0, to: runEngine.locationList.count, by: stepSize) {
                let location = runEngine.locationList[i]
                let offsetCoordinate = CLLocationCoordinate2D(
                    latitude: location.coordinate.latitude - 0.00005, // Larger offset
                    longitude: location.coordinate.longitude + 0.00005  // Different direction
                )
                smoothedPath.append(offsetCoordinate)
            }
            
            // Ensure we include the start point
            if let firstLocation = runEngine.locationList.first {
                smoothedPath.append(firstLocation.coordinate)
            }
            
            returnCoordinates = smoothedPath
        }
        
        // Create polyline for return route
        let returnPolyline = MKPolyline(coordinates: returnCoordinates, count: returnCoordinates.count)
        returnRouteOverlay = returnPolyline
        mapView.addOverlay(returnPolyline)
        print("🗺️ Updated return route with \(returnCoordinates.count) points")
    }
    
    public func addPlannedRouteToMap() {
        // First remove any existing route overlay
        if let existingRoute = routeOverlay {
            mapView.removeOverlay(existingRoute)
        }
        
        // Make sure we have valid route data
        guard !routePlanner.routePolyline.isEmpty else {
            print("🗺️ No route polyline available to add to map")
            return
        }
        
        print("🗺️ Adding planned route to map with \(routePlanner.routePolyline.count) points")
        
        // Create polyline from planned route
        let polyline = MKPolyline(coordinates: routePlanner.routePolyline, count: routePlanner.routePolyline.count)
        routeOverlay = polyline
        mapView.addOverlay(polyline)
        
        // Add route annotations - convert to MKAnnotation-compatible versions
        for annotation in routePlanner.routeAnnotations {
            // Create MKAnnotation-compatible version using the convenience initializer
            let mkAnnotation = RouteAnnotationMK(
                coordinate: annotation.coordinate,
                type: annotation.type,
                title: annotation.title
            )
            mapView.addAnnotation(mkAnnotation)
        }
        
        // Add special markers for start and end if they don't exist in annotations
        if routePlanner.routeAnnotations.isEmpty, routePlanner.routePolyline.count >= 2 {
            let startCoord = routePlanner.routePolyline.first!
            let endCoord = routePlanner.routePolyline.last!
            
            // Add start marker
            let startAnnotation = RouteAnnotationMK(
                coordinate: startCoord,
                type: .start,
                title: "Start"
            )
            mapView.addAnnotation(startAnnotation)
            
            // Create end annotation
            let endAnnotation = RouteAnnotationMK(
                coordinate: endCoord,
                type: .end,
                title: "Finish"
            )
            mapView.addAnnotation(endAnnotation)
        }
        
        // Zoom to show the entire route
        zoomToFitRoute()
    }
    
    public func zoomToFitRoute() {
        if !routePlanner.routePolyline.isEmpty {
            var mapRect = MKMapRect.null
            
            for coordinate in routePlanner.routePolyline {
                let point = MKMapPoint(coordinate)
                let rect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
                mapRect = mapRect.union(rect)
            }
            
            // Add some padding
            let padding = min(view.bounds.width, view.bounds.height) * 0.2
            mapView.setVisibleMapRect(mapRect, edgePadding: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding), animated: true)
        }
    }
    
    public func zoomToFitRoute(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else { return }
        
        if coordinates.count == 1 {
            // Single point - zoom to reasonable level around that point
            let region = MKCoordinateRegion(center: coordinates[0],
                                           latitudinalMeters: 2000,
                                           longitudinalMeters: 2000)
            mapView.setRegion(region, animated: true)
            return
        }
        
        // Multiple points - fit all coordinates
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        
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
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3, // Add 30% padding
            longitudeDelta: (maxLon - minLon) * 1.3
        )
        
        let region = MKCoordinateRegion(center: center, span: span)
        mapView.setRegion(region, animated: true)
    }

    
    public func updateMileMarkers(for distance: Measurement<UnitLength>) {
        // Remove existing mile markers
        mapView.removeAnnotations(mileMarkers)
        mileMarkers.removeAll()
        
        // Determine marker distance (mile or km)
        let markerDistanceMeters = runEngine.useMetric ? 1000.0 : 1609.34 // 1km or 1mi
        
        // Only show markers after we've covered enough distance
        guard distance.value > markerDistanceMeters else { return }
        
        let locations = runEngine.locationList
        guard locations.count > 10 else { return }
        
        // Calculate how many markers to show
        let totalMarkers = Int(distance.value / markerDistanceMeters)
        
        for i in 1...totalMarkers {
            let targetDistance = Double(i) * markerDistanceMeters
            
            // Find location closest to this distance
            if let markerLocation = findLocationAtDistance(targetDistance) {
                let annotation = MKPointAnnotation()
                annotation.coordinate = markerLocation.coordinate
                annotation.title = runEngine.useMetric ? "\(i) km" : "\(i) mi"
                
                mileMarkers.append(annotation)
                mapView.addAnnotation(annotation)
            }
        }
    }
    
    public func findLocationAtDistance(_ targetDistance: Double) -> CLLocation? {
        let locations = runEngine.locationList
        guard locations.count > 1 else { return nil }
        
        var currentDistance = 0.0
        
        for i in 1..<locations.count {
            let prevLocation = locations[i-1]
            let currentLocation = locations[i]
            
            let segmentDistance = prevLocation.distance(from: currentLocation)
            let newDistance = currentDistance + segmentDistance
            
            // If we've passed the target distance
            if newDistance >= targetDistance {
                // Calculate fraction of segment where the target distance falls
                let fraction = (targetDistance - currentDistance) / segmentDistance
                
                // Use linear interpolation to find the coordinate
                let latitude = prevLocation.coordinate.latitude + fraction * (currentLocation.coordinate.latitude - prevLocation.coordinate.latitude)
                let longitude = prevLocation.coordinate.longitude + fraction * (currentLocation.coordinate.longitude - prevLocation.coordinate.longitude)
                
                return CLLocation(
                    latitude: latitude,
                    longitude: longitude
                )
            }
            
            currentDistance = newDistance
        }
        
        return nil
    }
    
    public func updateMapDisplay(mode: MapViewMode) {
        let hostingView = hostingController?.view
        
        switch mode {
        case .fullscreen:
            // Hide UI elements for fullscreen map
            UIView.animate(withDuration: 0.3) {
                hostingView?.alpha = 0.3
                self.gradientOverlayView.alpha = 0.2
            }
            
        case .normal:
            // Normal view with map and stats
            UIView.animate(withDuration: 0.3) {
                hostingView?.alpha = 1.0
                self.gradientOverlayView.alpha = 0.7
            }
            
        case .minimized:
            // Show small map with more focus on stats
            UIView.animate(withDuration: 0.3) {
                hostingView?.alpha = 1.0
                self.gradientOverlayView.alpha = 0.9
            }
            
        case .hidden:
            // Hide map completely for stats-only view
            UIView.animate(withDuration: 0.3) {
                hostingView?.alpha = 1.0
                self.mapView.alpha = 0
                self.gradientOverlayView.alpha = 1.0
            }
            
        case .satellite, .hybrid, .terrain:
            // Map type changes don't affect display mode, just map appearance
            UIView.animate(withDuration: 0.3) {
                hostingView?.alpha = 1.0
                self.gradientOverlayView.alpha = 0.7
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Only process location updates when we're actively running
        if runEngine.runState == .running {
            // Process location on a background queue to prevent UI blocking
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                // Process the location in the run engine (this updates pace, distance, etc.)
                self.runEngine.processLocationUpdate(location)
                
                
                // Return to main thread for UI updates
                DispatchQueue.main.async {
                    // Update the run path on the map (already throttled in the method)
                    self.updateRunPath(with: location)
                    
                   
                    
                    // Update the map view's region (less frequently to avoid constant movement)
                    self.updateMapRegionIfNeeded(with: location)
                    
                    // Add route progress tracking for preloaded routes
                    if !self.routePlanner.routePolyline.isEmpty && self.runEngine.runState == .running {
                            if let currentLocation = locations.last {
                                self.updateRouteProgress(at: currentLocation)
                            }
                        }
                }
            }
        }
    
    }
    
    // Separate method for map region updates to reduce complexity
    public func updateMapRegionIfNeeded(with location: CLLocation) {
        // Skip if map is in fullscreen mode or we're animating a route
        if isAnimatingRoute || mapViewMode == .fullscreen {
            return
        }
        
        // Throttle map updates to avoid constant movement
        let now = Date()
        let updateInterval: TimeInterval = 7.0 // Seconds between updates
        let distanceThreshold: CLLocationDistance = 280 // Distance threshold for updates
        
        if lastMapUpdate == nil || 
           now.timeIntervalSince(lastMapUpdate!) > updateInterval ||
           (lastMapLocation != nil && location.distance(from: lastMapLocation!) > distanceThreshold) {
            
            // Use a consistent zoom level for better user experience
            let zoomRadius: CLLocationDistance = 400
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: zoomRadius,
                longitudinalMeters: zoomRadius
            )
            
            // Apply smooth animation
            UIView.animate(withDuration: 2.0) {
                self.mapView.setRegion(region, animated: false)
            }
            
            // Track when we last updated
            lastMapUpdate = now
            lastMapLocation = location
        }
    }
    
    // Add properties for map update throttling
    public var lastMapUpdate: Date?
    public var lastMapLocation: CLLocation?

    // Update the updateRunPath method to ensure proper drawing and throttle updates
    public func updateRunPath(with location: CLLocation) {
        let locations = runEngine.locationList
        guard locations.count > 0 else { 
            print("📍 Not enough locations to draw path yet")
            return 
        }
        
        // Only update map every few points to reduce overhead
        // Check if we should update based on throttling or significant changes
        let shouldUpdate = runPathOverlay == nil || 
                          (locations.count % 5 == 0) || // Update every 5 points
                          (lastPathUpdateTime == nil || 
                           Date().timeIntervalSince(lastPathUpdateTime!) > 3.0) // No more than once every 3 seconds
        
        guard shouldUpdate else { return }
        
        // Always use the main thread for UI updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Remove previous run path polyline
            if let existingRunPath = self.runPathOverlay {
                self.mapView.removeOverlay(existingRunPath)
            }
            
            // Convert locations to coordinates
            let coordinates = locations.map { $0.coordinate }
            
            // Create a single continuous polyline
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            self.runPathOverlay = polyline
            self.mapView.addOverlay(polyline)
            
            // Record the update time
            self.lastPathUpdateTime = Date()
            
            // Make sure the mapView updates visually
            self.mapView.setNeedsDisplay()
        }
    }
    
    // Add property for path update throttling
    public var lastPathUpdateTime: Date?

    // Add property for path markers
    public var pathMarkers: [MKPointAnnotation] = []
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Ensure this runs on the main thread to prevent UI lock-ups
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("📍 Location manager error: \(error.localizedDescription), code: \((error as NSError).code)")
            
            // Handle specific error codes
            if let clError = error as? CLError {
                switch clError.code {
                case .locationUnknown:
                    print("📍 Location currently unknown, will keep trying")
                    // This is a temporary error, no need to take action
                    
                case .denied:
                    print("📍 Location access denied")
                    self.showLocationPermissionAlert()
                    
                default:
                    print("📍 Other location error: \(clError.code)")
                    // Prevent lockup by restarting location services after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        manager.stopUpdatingLocation()
                        manager.startUpdatingLocation()
                    }
                }
            } else {
                // Non-CLError type error
                let locationError = error as NSError
                
                if locationError.code == 0 {
                    print("📍 General location error code 0 - restarting updates")
                    // Prevent lockup by restarting location services after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        manager.stopUpdatingLocation()
                        manager.startUpdatingLocation()
                    }
                }
            }
            
            // Only announce if error is significant (not temporary issues)
            if self.isVoiceGuidanceEnabled && !(error is CLError && (error as! CLError).code == .locationUnknown) {
                self.announceMessage("Location accuracy reduced. Please check GPS signal.")
            }
        }
    }
    
    /// Show alert to help user enable location access
    public func showLocationPermissionAlert() {
        let alert = UIAlertController(
            title: "Location Access Required",
            message: "Do requires location access to track your runs. Please enable it in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    public func checkRouteProgress(_ location: CLLocation) {
        // If we have a planned route, check progress
        if routePlanner.navigationActive {
            // Find closest point on route to current location
            if let closestPoint = findClosestPointOnRoute(to: location.coordinate) {
                // Calculate progress along route
                let progressIndex = closestPoint.index
                routeCoordinateIndex = progressIndex
                routeCompletionPercentage = Double(progressIndex) / Double(routePlanner.routePolyline.count - 1) * 100.0
                
                // Check if we need to give a navigation instruction
                if !routePlanner.navigationDirections.isEmpty && 
                   routePlanner.nextDirectionIndex < routePlanner.navigationDirections.count {
                    
                    // Update navigation panel visibility
                    isShowingNavigationPanel = true
                    
                    // Check if we reached a point for the next instruction
                    let instructionThreshold = Double(routePlanner.routePolyline.count) / Double(routePlanner.navigationDirections.count)
                    let nextInstructionIndex = Int(Double(routePlanner.nextDirectionIndex) * instructionThreshold)
                    
                    if progressIndex >= nextInstructionIndex {
                        // Time to give the next instruction
                        currentNavigationInstruction = routePlanner.navigationDirections[routePlanner.nextDirectionIndex]
                        
                        // Speak the instruction if voice guidance is enabled
                        if isVoiceGuidanceEnabled {
                            announceMessage(routePlanner.navigationDirections[routePlanner.nextDirectionIndex])
                        }
                        
                        // Advance to next instruction
                        routePlanner.nextDirectionIndex += 1
                    }
                    
                    // Show distance to next instruction if more available
                    if routePlanner.nextDirectionIndex < routePlanner.navigationDirections.count {
                        let nextInstructionIndex = Int(Double(routePlanner.nextDirectionIndex) * instructionThreshold)
                        let segmentsToNextInstruction = nextInstructionIndex - progressIndex
                        
                        if segmentsToNextInstruction > 0 {
                            var distanceSum: Double = 0
                            
                            for i in progressIndex..<min(nextInstructionIndex, routePlanner.routePolyline.count - 1) {
                                let point1 = routePlanner.routePolyline[i]
                                let point2 = routePlanner.routePolyline[i + 1]
                                
                                let loc1 = CLLocation(latitude: point1.latitude, longitude: point1.longitude)
                                let loc2 = CLLocation(latitude: point2.latitude, longitude: point2.longitude)
                                
                                distanceSum += loc1.distance(from: loc2)
                            }
                            
                            distanceToNextTurn = distanceSum
                        }
                    } else {
                        distanceToNextTurn = 0
                    }
                }
            }
        }
    }
    
    // MARK: - Voice Guidance
    public func checkForVoiceAnnouncement(at time: TimeInterval) {
    // Early exit if voice guidance level is set to none
    guard voiceGuidanceLevel != .none else { return }
    guard isVoiceGuidanceEnabled, !isPaused else { return }
    
    // Don't make ANY announcements in the first minute
    guard time >= 60 else { return }
    
    let currentDistanceValue = runEngine.distance.converted(to: .miles).value
    
    // Priority 1: Check for milestone announcements (most important)
    if shouldAnnounceMilestone(distance: currentDistanceValue) {
        let announcement = createProgressAnnouncement()
        announceMessage(announcement)
        lastAnnouncement = Date()
                return 
            }
            
    // Priority 2: Check for meaningful time-based announcements (only for longer runs)
    if shouldAnnounceTimeUpdate(at: time, distance: currentDistanceValue) {
            let announcement = createProgressAnnouncement()
            announceMessage(announcement)
            lastAnnouncement = Date()
        return
    }
}

    public func shouldAnnounceMilestone(distance: Double) -> Bool {
        // Don't announce anything in the first minute
        guard runEngine.elapsedTime >= 60 else { return false }
        
        let useMetric = UserDefaults.standard.bool(forKey: "useMetric")
        let unit: Double = useMetric ? 1.0 : 1.0 // km or mile
        
        // Only announce when we've actually completed a FULL unit (1 mile, 2 miles, etc.)
        // Not "mile 0" which doesn't exist
        guard distance >= 0.95 else { return false } // Must have run at least 0.95 of a unit
        
        let completedUnits = floor(distance / unit)
        let distanceIntoCurrentUnit = distance - (completedUnits * unit)
        
        // Check if we just crossed a milestone (within the last 0.05 units)
        // But only for actual milestones (1, 2, 3, etc., not 0)
        if completedUnits >= 1 && distanceIntoCurrentUnit <= 0.05 {
            let milestoneNumber = Int(completedUnits)
            let milestoneKey = "announced_milestone_\(milestoneNumber)"
            
            // Only announce if we haven't announced this milestone yet
            if !UserDefaults.standard.bool(forKey: milestoneKey) {
                UserDefaults.standard.set(true, forKey: milestoneKey)
                return true
            }
        }
        
        return false
    }

    public func shouldAnnounceTimeUpdate(at time: TimeInterval, distance: Double) -> Bool {
        let timeInMinutes = Int(time / 60)
        
        // Only make time-based announcements for longer runs (10+ minutes)
        guard timeInMinutes >= 10 else { return false }
        
        // Only announce at meaningful time intervals (every 10 minutes for long runs)
        guard timeInMinutes % 10 == 0 else { return false }
        
        // Check if we already announced at this time interval
        let timeKey = "announced_time_\(timeInMinutes)"
        if UserDefaults.standard.bool(forKey: timeKey) {
            return false
        }
        
        // Don't announce if we're close to a milestone (would be redundant)
        let useMetric = UserDefaults.standard.bool(forKey: "useMetric")
        let unit: Double = useMetric ? 1.0 : 1.0
        let nextMilestone = ceil(distance / unit) * unit
        let distanceToMilestone = nextMilestone - distance
        
        // If we're within 0.2 units of a milestone, wait for the milestone announcement instead
        if distanceToMilestone < 0.2 {
            return false
        }
        
        UserDefaults.standard.set(true, forKey: timeKey)
        return true
    }

    // Add method to reset announcement tracking when starting a new run
    public func resetAnnouncementTracking() {
        // Clear all milestone and time announcement flags
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys
        
        for key in keys {
            if key.starts(with: "announced_milestone_") || key.starts(with: "announced_time_") {
                defaults.removeObject(forKey: key)
            }
        }
    }       

    // Add this helper method
    public func getNextMilestone(distance: Double) -> Double {
        let unit = UserDefaults.standard.bool(forKey: "useMetric") ? 1.0 : 1.0 // km or mile
        let currentMilestone = floor(distance / unit)
        return (currentMilestone + 1) * unit
    }

    
    public func createProgressAnnouncement() -> String {
        guard voiceGuidanceLevel != .none else { return "" }
        
        let currentDistanceValue = runEngine.distance.converted(to: .miles).value
        let isAtMilestone = isAtDistanceMilestone(currentDistanceValue)
        let speechTime = formatTimeForSpeech(runEngine.formattedTime)
        
        // For milestones, create a special announcement
        if isAtMilestone {
            return createMilestoneAnnouncement(distance: currentDistanceValue, time: speechTime)
        }
        
        // For time-based updates (only for longer runs)
        return createTimeBasedAnnouncement(time: speechTime)
    }

   public func createMilestoneAnnouncement(distance: Double, time: String) -> String {
    let useMetric = UserDefaults.standard.bool(forKey: "useMetric")
    let unit: Double = useMetric ? 1.0 : 1.0
    
    // Calculate which milestone we just completed
    let completedUnits = floor(distance / unit)
    let mileNumber = Int(completedUnits)
    
    // Make sure we're announcing a valid milestone (1, 2, 3, etc.)
    guard mileNumber >= 1 else {
        return "Keep running!" // Fallback, but this shouldn't happen
    }
    
    let unitName = useMetric ? "kilometer" : "mile"
    let pace = runEngine.formattedPace
    
    // Create natural announcement with proper pauses
    var announcement = "\(unitName.capitalized) \(mileNumber)... completed"
    
    if includePaceGuidance {
        announcement += "... at a \(pace) pace"
    }
    
    if voiceGuidanceLevel == .comprehensive {
        announcement += "... excellent work!"
    }
    
    return announcement
}

    public func createTimeBasedAnnouncement(time: String) -> String {
        let distance = runEngine.formattedDistance
        
        switch voiceGuidanceLevel {
        case .minimal:
            return "\(distance) in \(time)"
            
        case .moderate:
            var announcement = "\(distance) in \(time)"
            if includePaceGuidance {
                announcement += ". Pace: \(runEngine.formattedPace)"
            }
            return announcement
            
        case .comprehensive:
            var announcement = "\(distance) in \(time)"
            if includePaceGuidance {
                announcement += ". Pace: \(runEngine.formattedPace)"
            }
            if includeHeartRateGuidance, runEngine.heartRate > 0 {
                announcement += ". Heart rate: \(Int(runEngine.heartRate))"
            }
            return announcement
            
        case .none:
            return ""
        }
    }

    // Add these helper methods
    public func isAtDistanceMilestone(_ distance: Double) -> Bool {
        let unit = UserDefaults.standard.bool(forKey: "useMetric") ? 1.0 : 1.0
        let remainder = distance.truncatingRemainder(dividingBy: unit)
        return remainder < 0.05 // Within 50m/yards of milestone
    }

    public func createEncouragementMessage() -> String? {
        let timeInMinutes = runEngine.elapsedTime / 60
        let currentDistanceValue = runEngine.distance.converted(to: .miles).value
        let currentPace = runEngine.pace.value
        
        // Milestone achievements with specific data
        if isAtDistanceMilestone(currentDistanceValue) {
            let distanceInt = Int(currentDistanceValue)
            let timeString = formatTimeForSpeech(runEngine.formattedTime)
            
            // Compare with historical performance
            if let avgHistoricalPace = getAverageHistoricalPace(), currentPace < avgHistoricalPace {
                let improvement = Int((avgHistoricalPace - currentPace) / 60) // minutes better
                if improvement > 0 {
                    return "Mile \(distanceInt) complete in \(timeString)! You're \(improvement) second\(improvement == 1 ? "" : "s") per mile faster than your recent average!"
                }
            }
            
            return "Mile \(distanceInt) completed in \(timeString)! Your pace is looking strong!"
        }
        
        // Pace consistency encouragement
        if timeInMinutes > 10 && isPaceConsistent() {
            return "Excellent pace consistency! You're maintaining a steady \(runEngine.formattedPace) rhythm!"
        }
        
        // Heart rate zone encouragement
        if runEngine.heartRate > 0 {
            let heartRateZone = getHeartRateZone(runEngine.heartRate)
            if heartRateZone == "aerobic" && timeInMinutes > 15 {
                return "Perfect aerobic zone at \(Int(runEngine.heartRate)) BPM! This builds your endurance base!"
            }
        }
        
        // Distance progress compared to recent runs
        if timeInMinutes > 20, let avgRecentDistance = getAverageRecentDistance() {
            if currentDistanceValue > avgRecentDistance * 1.1 { // 10% further than average
                return "You're already \(String(format: "%.1f", currentDistanceValue - avgRecentDistance)) miles beyond your recent average! Strong progress!"
            }
        }
        
        // Time-based achievements with context
        if timeInMinutes > 30 && Int(timeInMinutes) % 15 == 0 {
            let paceCategory = categorizePace(currentPace)
            return "Running strong for \(Int(timeInMinutes)) minutes at a \(paceCategory) pace! Keep that energy!"
        }
        
        // Improvement over last similar run
        if let lastSimilarRunPace = getLastSimilarRunPace(at: currentDistanceValue),
           currentPace < lastSimilarRunPace {
            let improvement = Int(lastSimilarRunPace - currentPace)
            return "You're running \(improvement) seconds per mile faster than your last run at this distance!"
        }
        
        return nil
    }

    // Helper methods for data-driven encouragement
    public func getAverageHistoricalPace() -> Double? {
        guard !historicalPaces.isEmpty else { return nil }
        return historicalPaces.reduce(0, +) / Double(historicalPaces.count)
    }

    public func isPaceConsistent() -> Bool {
        guard paceHistory.count >= 5 else { return false }
        
        let recent5Paces = Array(paceHistory.suffix(5))
        let average = recent5Paces.reduce(0, +) / Double(recent5Paces.count)
        
        // Check if all recent paces are within 10% of average
        return recent5Paces.allSatisfy { abs($0 - average) / average < 0.1 }
    }

    public func getHeartRateZone(_ heartRate: Double) -> String {
        // Simplified heart rate zones (you can make this more sophisticated)
        switch heartRate {
        case 100..<140:
            return "aerobic"
        case 140..<160:
            return "threshold"
        case 160...:
            return "anaerobic"
        default:
            return "recovery"
        }
    }

    public func getAverageRecentDistance() -> Double? {
        // Use cached run logs
        let outdoorLogs = self.outdoorRuns
        let indoorLogs = self.indoorRuns
        
        // Get distances from last 5 runs
        var recentDistances: [Double] = []
        
        // Add outdoor runs if relevant
        if runType != .treadmillRun {
            for log in outdoorLogs.prefix(5) {
                if let distanceString = log.distance,
                   let distance = parseDistanceString(distanceString) {
                    recentDistances.append(distance)
                }
            }
        }
        
        // Add indoor runs if relevant
        if runType == .treadmillRun {
            for log in indoorLogs.prefix(5) {
                if let distanceString = log.distance,
                   let distance = parseDistanceString(distanceString) {
                    recentDistances.append(distance)
                }
            }
        }
        
        guard !recentDistances.isEmpty else { return nil }
        return recentDistances.reduce(0, +) / Double(recentDistances.count)
    }

    public func categorizePace(_ pace: Double) -> String {
        // Convert pace to minutes per mile for categorization
        let minutesPerMile = pace / 60
        
        switch minutesPerMile {
        case 0..<6:
            return "elite"
        case 6..<7:
            return "competitive"
        case 7..<8:
            return "strong"
        case 8..<9:
            return "steady"
        case 9..<10:
            return "comfortable"
        default:
            return "easy"
        }
    }

    public func getLastSimilarRunPace(at currentDistance: Double) -> Double? {
        // Handle different log types separately to avoid type ambiguity
        if runType == .treadmillRun {
            let indoorLogs = self.indoorRuns
            for log in indoorLogs {
                if let distanceString = log.distance,
                   let distance = parseDistanceString(distanceString),
                   abs(distance - currentDistance) < 0.5,
                   let paceString = log.avgPace,
                   let pace = parsePaceString(paceString) {
                    return pace
                }
            }
        } else {
            let outdoorLogs = self.outdoorRuns
            for log in outdoorLogs {
                if let distanceString = log.distance,
                   let distance = parseDistanceString(distanceString),
                   abs(distance - currentDistance) < 0.5,
                   let paceString = log.avgPace,
                   let pace = parsePaceString(paceString) {
                    return pace
                }
            }
        }
        
        return nil
    }



    public func createContextualPaceMessage() -> String {
        guard let targetPace = targetPace, targetPace > 0 else {
            return runEngine.formattedPace
        }
        
        let currentPace = runEngine.pace.value
        let difference = currentPace - targetPace
        let percentage = abs(difference) / targetPace
        
        if percentage < 0.05 {
            return "Perfect pace"
        } else if difference > 0 {
            return percentage > 0.15 ? "Running slower than usual" : "Slightly slower than target"
        } else {
            return percentage > 0.15 ? "Running faster than usual" : "Slightly faster than target"
        }
    }

 
    
    // Helper method to format time string for speech
    // IMPROVED: Better time formatting for speech with more natural language
    public func formatTimeForSpeech(_ timeString: String) -> String {
        let components = timeString.split(separator: ":")
        
        if components.count == 3 {
            let hours = Int(components[0]) ?? 0
            let minutes = Int(components[1]) ?? 0
            let seconds = Int(components[2]) ?? 0
            
            if hours > 0 {
                if minutes > 0 {
                    return "\(hours) hour\(hours == 1 ? "" : "s") and \(minutes) minute\(minutes == 1 ? "" : "s")"
                } else {
                    return "\(hours) hour\(hours == 1 ? "" : "s")"
                }
            } else if minutes > 0 {
                return "\(minutes) minute\(minutes == 1 ? "" : "s") and \(seconds) second\(seconds == 1 ? "" : "s")"
            } else {
                return "\(seconds) second\(seconds == 1 ? "" : "s")"
            }
            
        } else if components.count == 2 {
            let minutes = Int(components[0]) ?? 0
            let seconds = Int(components[1]) ?? 0
            
            if minutes > 0 {
                return "\(minutes) minute\(minutes == 1 ? "" : "s") and \(seconds) second\(seconds == 1 ? "" : "s")"
            } else {
                return "\(seconds) second\(seconds == 1 ? "" : "s")"
            }
        }
        
        return timeString
    }
    
    // Add helper method for next turn information
    public func getNextTurnInfo() -> String? {
        guard includeNavigationGuidance,
              let currentLocation = locationManager.location?.coordinate,
              let nextTurn = findNextTurn(from: currentLocation) else {
            return nil
        }
        
        let distance = formatDistance(nextTurn.distance)
        return "\(nextTurn.direction.description) in \(distance)"
    }
    
    // Add helper method for route progress
    public func getRouteProgress() -> String? {
        guard let route = route,
              let currentLocation = locationManager.location?.coordinate,
              let progress = calculateRouteProgress(from: currentLocation) else {
            return nil
        }
        
        let remaining = formatDistance(progress.remainingDistance)
        let percentage = Int(progress.completionPercentage)
        return "Route progress: \(percentage)%. \(remaining) remaining"
    }
    
    // Add helper method to find next turn
    public func findNextTurn(from location: CLLocationCoordinate2D) -> (direction: TurnDirection, distance: Double)? {
        guard let routePoints = route?.routeCoordinates,
              let currentIndex = findClosestPointOnRoute(to: location)?.index,
              currentIndex < routePoints.count - 1 else {
            return nil
        }
        
        // Look ahead for the next significant turn
        let lookAhead = min(5, routePoints.count - currentIndex - 1)
        for i in 1...lookAhead {
            let nextIndex = currentIndex + i
            let direction = calculateTurnDirection(
                from: routePoints[nextIndex - 1],
                through: routePoints[nextIndex],
                to: routePoints[min(nextIndex + 1, routePoints.count - 1)]
            )
            
            if direction != .straight {
                // Calculate distance to this turn
                var distance: Double = 0
                for j in currentIndex..<nextIndex {
                    let point1 = CLLocation(latitude: routePoints[j].latitude, longitude: routePoints[j].longitude)
                    let point2 = CLLocation(latitude: routePoints[j + 1].latitude, longitude: routePoints[j + 1].longitude)
                    distance += point1.distance(from: point2)
                }
                
                return (direction, distance)
            }
        }
        
        return nil
    }
    
    // Add helper method to calculate turn direction
    public func calculateTurnDirection(from p1: CLLocationCoordinate2D, through p2: CLLocationCoordinate2D, to p3: CLLocationCoordinate2D) -> TurnDirection {
        let bearing1 = calculateBearing(from: p1, to: p2)
        let bearing2 = calculateBearing(from: p2, to: p3)
        var angle = bearing2 - bearing1
        
        // Normalize angle to -180 to 180 degrees
        while angle > 180 { angle -= 360 }
        while angle < -180 { angle += 360 }
        
        switch angle {
        case -45 ..< 45: return .straight
        case 45 ..< 135: return .right
        case 135 ... 180, -180 ..< -135: return .sharpRight
        case -135 ..< -45: return .left
        case -45 ..< 45: return .straight
        default: return .straight
        }
    }
    
    
    // Add helper method to format distance
    public func formatDistance(_ meters: Double) -> String {
        if runEngine.useMetric {
            return String(format: "%.0f meters", meters)
        } else {
            return String(format: "%.0f feet", meters * 3.28084)
        }
    }
    
    // Add helper method to calculate route progress
    public func calculateRouteProgress(from location: CLLocationCoordinate2D) -> (completionPercentage: Double, remainingDistance: Double)? {
        guard let routePoints = route?.routeCoordinates,
              let closestPoint = findClosestPointOnRoute(to: location) else {
            return nil
        }
        
        // Calculate total route distance
        var totalDistance: Double = 0
        for i in 0..<routePoints.count - 1 {
            let point1 = CLLocation(latitude: routePoints[i].latitude, longitude: routePoints[i].longitude)
            let point2 = CLLocation(latitude: routePoints[i + 1].latitude, longitude: routePoints[i + 1].longitude)
            totalDistance += point1.distance(from: point2)
        }
        
        // Calculate completed distance
        var completedDistance: Double = 0
        for i in 0..<closestPoint.index {
            let point1 = CLLocation(latitude: routePoints[i].latitude, longitude: routePoints[i].longitude)
            let point2 = CLLocation(latitude: routePoints[i + 1].latitude, longitude: routePoints[i + 1].longitude)
            completedDistance += point1.distance(from: point2)
        }
        
        let completionPercentage = (completedDistance / totalDistance) * 100
        let remainingDistance = totalDistance - completedDistance
        
        return (completionPercentage, remainingDistance)
    }
    
   
    
    public func announceRunSummary() {
        let speechTime = formatTimeForSpeech(runEngine.formattedTime)
        let summary = "Run completed. Total distance: \(runEngine.formattedDistance). Time: \(speechTime). Great job!"
        announceMessage(summary)
    }
    
    // Announce a message using text-to-speech
    public func announceMessage(_ message: String) {
    // Skip if voice guidance level is set to none
    guard voiceGuidanceLevel != .none else { 
        print("🔇 Voice guidance set to 'No Audio', skipping announcement")
        return 
    }
    
        // Skip if voice guidance is disabled
        guard isVoiceGuidanceEnabled else { 
            print("🔇 Voice guidance disabled, skipping announcement")
        return 
    }
    
    // Skip if message is empty
    guard !message.isEmpty else {
        print("🔇 Empty message, skipping announcement")
        return 
    }
    
    // CRITICAL: If we're already speaking, ignore new announcements to prevent overlap
    if isAnnouncementInProgress || speechSynthesizer.isSpeaking {
        print("🔇 Already speaking, ignoring new announcement: \(message)")
            return 
        }
        
        // Add message to queue
        announcementQueue.append(message)
        print("🔊 Added to queue: \(message)")
        
        // Process queue if not already processing
        if !isAnnouncementInProgress {
            processAnnouncementQueue()
        }
    }
    
    // Complete enhanced announcement queue processing
    public func processAnnouncementQueue() {
        // Check if there are messages in the queue
        guard !announcementQueue.isEmpty else {
            isAnnouncementInProgress = false
            return
        }
        
        // Ensure we're on the main thread for UI operations
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.processAnnouncementQueue()
            }
            return
        }
        
        // Set flag to indicate announcement in progress
        isAnnouncementInProgress = true
        
        // Get the next message
        let message = announcementQueue.removeFirst()
        print("🔊 Processing from queue: \(message)")
        
        // Configure audio session for highest quality speech
        configureAudioSessionForRealisticSpeech()
        
        // Create an utterance with the message
        let utterance = AVSpeechUtterance(string: message)
        
        // Determine message type for optimal speech configuration
        let messageType = determineMessageType(from: message)
        
        // Configure the most realistic voice possible
        configureRealisticVoice(for: utterance)
        
        // Optimize speech parameters for natural delivery
        configureNaturalSpeechParameters(for: utterance, messageType: messageType)
        
        // Apply advanced speech processing for even more natural delivery
        applyAdvancedSpeechProcessing(for: utterance, messageType: messageType)
        
        // Stop any existing announcements safely
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            // Add a small delay to ensure the stop completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.performSpeechAnnouncement(utterance: utterance, message: message)
            }
        } else {
            performSpeechAnnouncement(utterance: utterance, message: message)
        }
    }

    public func configureAudioSessionForRealisticSpeech() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Only reconfigure if not already optimally configured
            if audioSession.category != .playback || audioSession.mode != .spokenAudio {
                // Configure for highest quality speech output
                try audioSession.setCategory(.playback,
                                           mode: .spokenAudio,
                                           options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker])
                
                // Set optimal audio quality settings
                try audioSession.setPreferredSampleRate(48000.0)  // High quality sample rate
                try audioSession.setPreferredIOBufferDuration(0.01) // Low latency for responsive speech
            }
            
            // Activate with high priority if not already active
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true, options: [])
            }
            
            print("🔊 Audio session optimized for realistic speech")
        } catch {
            print("❌ Failed to configure premium audio session: \(error.localizedDescription)")
            // Fallback to basic configuration
            configureFallbackAudioSession()
        }
    }

    public func configureFallbackAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try audioSession.setActive(true)
            print("🔊 Using fallback audio session configuration")
        } catch {
            print("❌ Failed to configure fallback audio session: \(error.localizedDescription)")
        }
    }

    public func determineMessageType(from message: String) -> AnnouncementMessageType {
        let lowercaseMessage = message.lowercased()
        
        // Check for milestone messages
        if lowercaseMessage.contains("milestone") ||
           lowercaseMessage.contains("completed") ||
           lowercaseMessage.contains("great job") ||
           lowercaseMessage.contains("congratulations") {
            return .milestone
        }
        
        // Check for coaching/guidance messages
        if lowercaseMessage.contains("too fast") ||
           lowercaseMessage.contains("too slow") ||
           lowercaseMessage.contains("slow down") ||
           lowercaseMessage.contains("pick up") ||
           lowercaseMessage.contains("pace") {
            return .warning
        }
        
        // Check for coaching tips
        if lowercaseMessage.contains("tip") ||
           lowercaseMessage.contains("remember") ||
           lowercaseMessage.contains("try") ||
           lowercaseMessage.contains("consider") {
            return .coaching
        }
        
        // Default to announcement
        return .announcement
    }

    public func configureRealisticVoice(for utterance: AVSpeechUtterance) {
    // Use the UserPreferences voice selection which handles male/female choice
    if let bestVoice = UserPreferences.shared.preferredVoiceType.bestAvailableVoice {
        utterance.voice = bestVoice
        print("🔊 Using selected voice: \(bestVoice.identifier) (\(bestVoice.name)) - Type: \(UserPreferences.shared.preferredVoiceType.displayName)")
        } else {
        // Fallback logic
        if let fallbackVoice = self.defaultVoice {
            utterance.voice = fallbackVoice
            print("🔊 Using fallback voice: \(fallbackVoice.identifier)")
        } else {
            // Final fallback to system default
            let systemVoice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.voice = systemVoice
            print("🔊 Using system default voice: \(systemVoice?.identifier ?? "unknown")")
        }
    }
}

    public func initializePremiumVoices() {
        // Use the bestAvailableVoice from UserPreferences which handles male/female selection
        if let bestVoice = UserPreferences.shared.preferredVoiceType.bestAvailableVoice {
            self.defaultVoice = bestVoice
            print("🔊 Initialized with voice: \(bestVoice.identifier) (\(bestVoice.name)) - Type: \(UserPreferences.shared.preferredVoiceType.displayName)")
        } else {
            // Fallback to system voice
            if let languageCode = Locale.current.language.languageCode?.identifier {
                self.defaultVoice = AVSpeechSynthesisVoice(language: languageCode)
            } else {
                self.defaultVoice = AVSpeechSynthesisVoice(language: "en-US")
            }
            print("🔊 Initialized with system voice: \(defaultVoice?.identifier ?? "unknown") - no premium voices available")
        }
        
        // Preload voices to reduce first-time latency
        preloadVoices()
    }

    public func configureNaturalSpeechParameters(for utterance: AVSpeechUtterance, messageType: AnnouncementMessageType) {
        switch messageType {
        case .announcement:
            // Standard announcements - clear and natural
            utterance.rate = 0.48          // Slightly slower for clarity during exercise
            utterance.pitchMultiplier = 1.05 // Slightly higher for better audibility
            utterance.volume = 1.0         // Full volume
            
        case .coaching:
            // Coaching tips - more conversational
            utterance.rate = 0.52          // Slightly faster, more natural
            utterance.pitchMultiplier = 1.0  // Natural pitch
            utterance.volume = 0.95        // Slightly softer
            
        case .milestone:
            // Milestone celebrations - enthusiastic
            utterance.rate = 0.50          // Measured pace for impact
            utterance.pitchMultiplier = 1.1  // Higher pitch for excitement
            utterance.volume = 1.0         // Full volume
            
        case .warning:
            // Pace guidance/warnings - attention-getting
            utterance.rate = 0.45          // Slower for attention
            utterance.pitchMultiplier = 1.15 // Higher pitch for alert
            utterance.volume = 1.0         // Full volume
        }
    }

    public func applyAdvancedSpeechProcessing(for utterance: AVSpeechUtterance, messageType: AnnouncementMessageType) {
        // Create a processed version of the speech string for more natural delivery
        let originalString = utterance.speechString
        var processedString = originalString
        
        // Add natural pauses and improve pronunciation
        switch messageType {
        case .announcement:
            // Add natural pauses after key metrics for better comprehension
            processedString = processedString.replacingOccurrences(of: "Time:", with: "Time,")
            processedString = processedString.replacingOccurrences(of: "Distance:", with: "Distance,")
            processedString = processedString.replacingOccurrences(of: "Pace:", with: "Pace,")
            processedString = processedString.replacingOccurrences(of: "Heart rate:", with: "Heart rate,")
            
            // Improve number pronunciation
            processedString = improveNumberPronunciation(processedString)
            
        case .milestone:
          // Add natural pauses for milestone celebrations
        processedString = processedString.replacingOccurrences(of: "completed", with: "completed...")
        processedString = processedString.replacingOccurrences(of: "pace", with: "pace...")
            processedString = processedString.replacingOccurrences(of: "work!", with: "work!")
        
        // Add emphasis spacing
        processedString = processedString.replacingOccurrences(of: "Kilometer ", with: "Kilometer... ")
        processedString = processedString.replacingOccurrences(of: "Mile ", with: "Mile... ")
            // Add emphasis and excitement to milestone achievements
            if processedString.contains("Milestone reached") {
                processedString = processedString.replacingOccurrences(of: "Milestone reached!", with: "Milestone reached!")
            }
            if processedString.contains("Great job") {
                processedString = processedString.replacingOccurrences(of: "Great job!", with: "Great job!")
            }
            
        case .coaching:
            // Make coaching sound more conversational and natural
            processedString = processedString.replacingOccurrences(of: "You're", with: "You are")
            processedString = processedString.replacingOccurrences(of: "Try to", with: "Try to")
            processedString = processedString.replacingOccurrences(of: "Consider", with: "Consider")
            
        case .warning:
            // Add natural emphasis to important guidance
            processedString = processedString.replacingOccurrences(of: "too fast", with: "too fast")
            processedString = processedString.replacingOccurrences(of: "too slow", with: "too slow")
            processedString = processedString.replacingOccurrences(of: "slow down", with: "slow down")
            processedString = processedString.replacingOccurrences(of: "pick up", with: "pick up")
        }
        
        // If we improved the string, create a new utterance with the processed text
        if processedString != originalString {
            let newUtterance = AVSpeechUtterance(string: processedString)
            newUtterance.voice = utterance.voice
            newUtterance.rate = utterance.rate
            newUtterance.pitchMultiplier = utterance.pitchMultiplier
            newUtterance.volume = utterance.volume
            
            // Use the processed utterance
            performSpeechAnnouncement(utterance: newUtterance, message: processedString)
            return
        }
    }

    public func improveNumberPronunciation(_ text: String) -> String {
        var improvedText = text
        
        // Improve time format pronunciation (e.g., "12:34" -> "12 minutes 34 seconds")
        let timePattern = #"(\d{1,2}):(\d{2})"#
        let timeRegex = try? NSRegularExpression(pattern: timePattern)
        let timeMatches = timeRegex?.matches(in: improvedText, range: NSRange(improvedText.startIndex..., in: improvedText)) ?? []
        
        // Process matches in reverse order to maintain correct indices
        for match in timeMatches.reversed() {
            guard let fullRange = Range(match.range, in: improvedText),
                  let minutesRange = Range(match.range(at: 1), in: improvedText),
                  let secondsRange = Range(match.range(at: 2), in: improvedText) else {
                continue
            }
            
            let minutes = String(improvedText[minutesRange])
            let seconds = String(improvedText[secondsRange])
            
            let minuteText = minutes == "1" ? "minute" : "minutes"
            let secondText = seconds == "01" ? "second" : "seconds"
            
            let replacement = "\(minutes) \(minuteText) \(seconds) \(secondText)"
            improvedText.replaceSubrange(fullRange, with: replacement)
        }
        
        // Improve decimal pronunciation (e.g., "3.2 miles" -> "3 point 2 miles")
        // Use a simpler approach for decimal replacement
        let decimalPattern = #"(\d+)\.(\d+)"#
        if let decimalRegex = try? NSRegularExpression(pattern: decimalPattern) {
            let nsString = improvedText as NSString
            let matches = decimalRegex.matches(in: improvedText, range: NSRange(location: 0, length: nsString.length))
            
            // Process in reverse order to maintain indices
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: improvedText) else { continue }
                
                let wholeNumber = nsString.substring(with: match.range(at: 1))
                let decimal = nsString.substring(with: match.range(at: 2))
                
                let replacement = "\(wholeNumber) point \(decimal)"
                improvedText.replaceSubrange(fullRange, with: replacement)
            }
        }
        
        return improvedText
    }

    public func performSpeechAnnouncement(utterance: AVSpeechUtterance, message: String) {
        // Ensure the speech synthesizer is properly configured
        if speechSynthesizer.delegate == nil {
            speechSynthesizer.delegate = self
        }
        
        // Apply final quality settings
        speechSynthesizer.usesApplicationAudioSession = true
        
        // Add a tiny pre-speech delay for audio session settling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
        
        // Speak the message
            self.speechSynthesizer.speak(utterance)
            print("🔊 Speaking with enhanced voice: \(utterance.voice?.identifier ?? "unknown")")
        
        // Record the time of last announcement
            self.lastAnnouncement = Date()
        }
    }

    
    // MARK: - Actions
    func startRun() {
        resetAnnouncementTracking() 
        // Call engine's startRun first
        runEngine.runType = runType
        runEngine.startRun(runType: runType)

        if !routePlanner.routePolyline.isEmpty && routePlanner.navigationDirections.isEmpty {
        let waypoints = generateIntelligentWaypoints(from: routePlanner.routePolyline)
        routePlanner.navigationDirections = generateDetailedNavigationDirections(from: waypoints)
        routePlanner.navigationActive = true
        routePlanner.nextDirectionIndex = 0
        
        // Announce first direction
        if !routePlanner.navigationDirections.isEmpty && voiceGuidanceLevel != .none {
            announceMessage(routePlanner.navigationDirections[0])
        }
    }
        
        // Start simplified timer with current date as start time
        let startDate = Date()
        setupSimplifiedTimer(startDate: startDate)
        print("🕒 Simplified timer started for new run with start date: \(startDate)")
        
        // Update UI state
        updateStatusDisplay()
        
        // Notify watch
        sendTrackingStatusToWatch()
        
        // Populate run history in background for pace analysis
          DispatchQueue.global(qos: .utility).async { [weak self] in
              self?.populateRecentRunHistory()
          }
    }
    
   
    
    func endRun() {
        // Call engine's endRun first
        runEngine.endRun()
        
        // Stop the simplified timer
        stopSimpleTimer()
        print("🕒 Simplified timer stopped for ended run")
        
        // Update UI state
        updateStatusDisplay()
        
        // Notify watch
        sendTrackingStatusToWatch()
    }
    
    func toggleMapMode() {
        cycleMapViewMode()
    }
    
    func togglePerformanceView() {
        isShowingPerformanceView.toggle()
    }
    
    func cycleMapType() {
        switch mapType {
        case .standard:
            mapType = .hybrid
        case .hybrid:
            mapType = .satelliteFlyover
        case .satelliteFlyover:
            mapType = .standard
        default:
            mapType = .standard
        }
    }
    
    func toggleVoiceGuidance() {
        isVoiceGuidanceEnabled.toggle()
        UserDefaults.standard.set(isVoiceGuidanceEnabled, forKey: "voiceGuidanceEnabled")
        
        // Announce the change
        announceMessage(isVoiceGuidanceEnabled ? "Voice guidance enabled" : "Voice guidance disabled")
    }
    
    func togglePaceGuidance() {
        paceGuidanceEnabled.toggle()
        UserDefaults.standard.set(paceGuidanceEnabled, forKey: "paceGuidanceEnabled")
        
        // Briefly announce the change
        if isVoiceGuidanceEnabled {
            announceMessage(paceGuidanceEnabled ? "Pace guidance enabled" : "Pace guidance disabled")
        }
    }
    
    func showRunSummary() {
        // Create and present run summary
        if let runLog = runEngine.generateRunLog() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let summaryVC = RunAnalysisViewController()
                summaryVC.run = runLog
                summaryVC.modalPresentationStyle = .fullScreen
                self.present(summaryVC, animated: true)
            }
        } else {
            // If no valid run data, just dismiss
            dismiss(animated: true)
        }
    }
    
    // MARK: - Load Run Goals and Historical Data
    public func loadRunGoalAndHistoricalData() {
        print("📱 🚀 OutdoorRunViewController: LOADING RUN GOAL AND HISTORICAL DATA")
        
        // Check initial state of cached run logs
        print("📱 📊 Initial cached run logs state:")
        print("📱 📊 - Outdoor runs: \(outdoorRuns.count)")
        print("📱 📊 - Indoor runs: \(indoorRuns.count)")
        
        // Load target pace from previous runs or user settings
        if let savedTargetPace = UserDefaults.standard.object(forKey: "targetPace_\(runType.rawValue)") as? Double {
            targetPace = savedTargetPace
            targetPaceSource = "Recent Runs"
            print("📱 ✅ Loaded saved target pace: \(savedTargetPace)")
        } else {
            print("📱 ❌ No saved target pace found")
        }
        
        // Load run goal if one was set
        if let goalDistance = UserDefaults.standard.object(forKey: "goalDistance_\(runType.rawValue)") as? Double,
           let goalTime = UserDefaults.standard.object(forKey: "goalTime_\(runType.rawValue)") as? TimeInterval {
            runGoal = RunGoal(distance: goalDistance, time: goalTime)
            print("📱 ✅ Loaded saved run goal: \(goalDistance) distance, \(goalTime) time")
        } else {
            print("📱 ❌ No saved run goal found")
        }
        
        // Load historical data by calling the functions that populate GlobalVariables
        print("📱 🔄 Starting historical data fetch...")
        
        let group = DispatchGroup()
        
        // Fetch outdoor runs to populate cache
        group.enter()
        print("📱 🔄 Fetching outdoor runs...")
        getRunningLogs { [weak self] logs, error in
            defer { group.leave() }
            
            if let error = error {
                print("📱 ❌ Error fetching outdoor runs: \(error.localizedDescription)")
                return
            }
            
            if let logs = logs {
                self?.outdoorRuns = logs
                print("📱 ✅ Successfully fetched \(logs.count) outdoor runs")
                print("📱 💾 outdoorRuns now has \(logs.count) runs")
                
                // Log first few runs for debugging
                for (index, run) in logs.prefix(3).enumerated() {
                    print("📱 🏃 Outdoor run \(index + 1): pace=\(run.avgPace ?? "nil"), distance=\(run.distance ?? "nil"), duration=\(run.duration ?? "nil"), created=\(run.createdAt?.description ?? "nil")")
                }
            } else {
                print("📱 ❌ No outdoor runs data returned")
            }
        }
        
        // Fetch indoor runs to populate cache
        group.enter()
        print("📱 🔄 Fetching indoor runs...")
        getTreadmillLogs { [weak self] logs, error in
            defer { group.leave() }
            
            if let error = error {
                print("📱 ❌ Error fetching indoor runs: \(error.localizedDescription)")
                return
            }
            
            if let logs = logs {
                self?.indoorRuns = logs
                print("📱 ✅ Successfully fetched \(logs.count) indoor runs")
                print("📱 💾 indoorRuns now has \(logs.count) runs")
                
                // Log first few runs for debugging
                for (index, run) in logs.prefix(3).enumerated() {
                    print("📱 🏃‍♂️ Indoor run \(index + 1): pace=\(run.avgPace ?? "nil"), distance=\(run.distance ?? "nil"), duration=\(run.duration ?? "nil"), created=\(run.createdAt?.description ?? "nil")")
                }
            } else {
                print("📱 ❌ No indoor runs data returned")
            }
        }
        
        // When both fetches complete, process the data
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            print("📱 🔄 Processing historical data for pace calculation...")
            print("📱 📊 Final cached run logs state:")
            print("📱 📊 - Outdoor runs: \(self.outdoorRuns.count)")
            print("📱 📊 - Indoor runs: \(self.indoorRuns.count)")
            
            // Add a small delay to ensure GlobalVariables are populated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Now load historical paces for this specific run type
                Task {
                    do {
                        // Get previous runs of this type using the populated global variables
                        let previousRuns = try await self.getRunLogsForType(runType: self.runType.rawValue, limit: 5)
                        
                        print("📱 📊 Got \(previousRuns.count) runs for type: \(self.runType.rawValue)")
                    
                    // Calculate average paces
                    let paces = previousRuns.compactMap { run -> Double? in
                        // Convert string values to numeric types
                        guard let distanceString = run.distance,
                              let distanceValue = Double(distanceString.replacingOccurrences(of: " km", with: "").replacingOccurrences(of: " mi", with: "")),
                              let durationString = run.duration,
                              let durationValue = self.timeStringToSeconds(durationString),
                              distanceValue > 0, durationValue > 0 else { 
                            print("📱 ❌ Invalid pace data: distance=\(run.distance ?? "nil"), duration=\(run.duration ?? "nil")")
                            return nil 
                        }
                        
                        // Database always stores distances in miles (imperial units)
                        // Calculate pace in seconds per mile (database units)
                        let paceInSecondsPerMile = Double(durationValue) / distanceValue
                        print("📱 📊 Calculated pace: \(paceInSecondsPerMile) sec/mi (from database)")
                        
                        // Convert to user's preferred units
                        if self.runEngine.useMetric {
                            // Convert from seconds per mile to seconds per km
                            let paceInSecondsPerKm = paceInSecondsPerMile / 1.60934
                            print("📱 📊 Converted to metric: \(paceInSecondsPerKm) sec/km")
                            return paceInSecondsPerKm
                        } else {
                            // Keep in seconds per mile (imperial)
                            print("📱 📊 Using imperial: \(paceInSecondsPerMile) sec/mi")
                            return paceInSecondsPerMile
                        }
                    }
                    
                    // Update on main thread
                    await MainActor.run {
                        self.historicalPaces = paces
                        print("📱 ✅ Updated historicalPaces with \(paces.count) valid paces")
                        print("📱 📊 Historical paces: \(paces)")
                        
                        // Update target pace based on historical data
                        if !paces.isEmpty {
                            let averagePace = paces.reduce(0, +) / Double(paces.count)
                            let oldTargetPace = self.targetPace
                            self.targetPace = averagePace
                            self.targetPaceSource = "Historical Data (\(paces.count) runs)"
                            let unit = self.runEngine.useMetric ? "sec/km" : "sec/mi"
                            print("📱 ✅ Updated target pace from historical data: \(averagePace) \(unit)")
                            print("📱 📊 Target pace changed: \(oldTargetPace?.description ?? "nil") -> \(averagePace)")
                            
                            // Save to UserDefaults
                            UserDefaults.standard.set(averagePace, forKey: "targetPace_\(self.runType.rawValue)")
                            print("📱 💾 Saved target pace to UserDefaults: \(averagePace)")
                            
                            // Send to watch if available
                            self.sendTargetPaceToWatch(targetPace: averagePace)
                            
                            // Force UI update
                            DispatchQueue.main.async {
                                self.objectWillChange.send()
                                print("📱 🔄 Forced UI update for target pace: \(self.targetPace?.description ?? "nil")")
                            }
                        } else if self.targetPace == nil {
                            // Use default target pace if no historical data and no existing target
                            if self.runEngine.useMetric {
                                self.targetPace = 360.0 // 6:00 min/km as default (360 seconds/km)
                                self.targetPaceSource = "Default (6:00 min/km)"
                                print("📱 ✅ Set default target pace: 360.0 seconds/km")
                            } else {
                                self.targetPace = 480.0 // 8:00 min/mi as default (480 seconds/mi)
                                self.targetPaceSource = "Default (8:00 min/mi)"
                                print("📱 ✅ Set default target pace: 480.0 seconds/mi")
                            }
                        } else {
                            print("📱 📊 Target pace already set to: \(self.targetPace?.description ?? "nil")")
                        }
                    }
                } catch {
                    print("📱 ❌ Error loading historical pace data: \(error)")
                }
            }
        }
    }
    }
    
    // MARK: - Fetch Run Logs Methods
    
    /// Fetch outdoor running logs from AWS
    private func getRunningLogs(completion: @escaping ([RunLog]?, Error?) -> Void) {
        guard let userId = UserIDResolver.shared.getBestUserIdForAPI() else {
            completion(nil, NSError(domain: "OutdoorRunViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "User ID not available"]))
            return
        }
        
        ActivityService.shared.getRuns(userId: userId, limit: 100) { result in
            switch result {
            case .success(let response):
                guard let activities = response.data?.activities else {
                    completion([], nil)
                    return
                }
                
                // Convert AWSActivity to RunLog (filter out indoor runs)
                let runLogs = activities.compactMap { activity -> RunLog? in
                    guard !activity.isIndoorRun else { return nil }
                    return self.convertAWSActivityToRunLog(activity)
                }
                
                // Update cache
                self.outdoorRuns = runLogs
                
                completion(runLogs, nil)
                
            case .failure(let error):
                print("❌ [OutdoorRunViewController] Error fetching running logs: \(error.localizedDescription)")
                completion(nil, error)
            }
        }
    }
    
    /// Fetch treadmill/indoor running logs from AWS
    private func getTreadmillLogs(completion: @escaping ([RunLog]?, Error?) -> Void) {
        guard let userId = UserIDResolver.shared.getBestUserIdForAPI() else {
            completion(nil, NSError(domain: "OutdoorRunViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "User ID not available"]))
            return
        }
        
        ActivityService.shared.getRuns(userId: userId, limit: 100) { result in
            switch result {
            case .success(let response):
                guard let activities = response.data?.activities else {
                    completion([], nil)
                    return
                }
                
                // Convert AWSActivity to RunLog (filter for indoor runs only)
                let indoorLogs = activities.compactMap { activity -> RunLog? in
                    guard activity.isIndoorRun else { return nil }
                    return self.convertAWSActivityToIndoorRunLog(activity)
                }
                
                // Update cache (IndoorRunLog is a type alias for RunLog)
                self.indoorRuns = indoorLogs
                
                completion(indoorLogs, nil)
                
            case .failure(let error):
                print("❌ [OutdoorRunViewController] Error fetching treadmill logs: \(error.localizedDescription)")
                completion(nil, error)
            }
        }
    }
    
    // MARK: - Conversion Methods
    
    /// Convert AWSActivity to RunLog
    private func convertAWSActivityToRunLog(_ activity: AWSActivity) -> RunLog? {
        guard !activity.isIndoorRun else { return nil }
        
        var runLog = RunLog()
        runLog.id = activity.id
        
        // Convert date
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = dateFormatter.date(from: activity.createdAt) {
            runLog.createdAt = date
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            runLog.createdAtFormatted = formatter.string(from: date)
        }
        
        runLog.createdBy = activity.userId
        runLog.duration = formatDuration(activity.duration)
        runLog.distance = formatDistance(activity.distance, useMetric: runEngine.useMetric)
        runLog.caloriesBurned = activity.calories
        runLog.type = "outdoor"
        runLog.runType = activity.runType ?? "outdoor_run"
        
        // Parse activityData JSON string for pace and location data
        if let activityDataString = activity.activityData,
           let data = activityDataString.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Parse average pace
                    if let avgPace = json["averagePace"] as? String {
                        runLog.avgPace = avgPace
                    }
                    
                    // Parse location data if available
                    if let locationData = json["locationData"] as? [[String: Any]] {
                        runLog.locationData = locationData
                    }
                    
                    // Parse coordinate array if available
                    if let coordinateArray = json["coordinateArray"] as? [[String: Double]] {
                        runLog.coordinateArray = coordinateArray
                    }
                }
            } catch {
                print("⚠️ [OutdoorRunViewController] Failed to parse activityData: \(error)")
            }
        }
        
        return runLog
    }
    
    /// Convert AWSActivity to IndoorRunLog (which is a type alias for RunLog)
    private func convertAWSActivityToIndoorRunLog(_ activity: AWSActivity) -> RunLog? {
        guard activity.isIndoorRun else { return nil }
        
        // Convert date
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var createdAt: Date?
        if let date = dateFormatter.date(from: activity.createdAt) {
            createdAt = date
        } else {
            dateFormatter.formatOptions = [.withInternetDateTime]
            createdAt = dateFormatter.date(from: activity.createdAt)
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        let createdAtFormatted = createdAt.map { formatter.string(from: $0) }
        
        var indoorLog = RunLog()
        indoorLog.id = activity.id
        indoorLog.createdBy = activity.userId
        indoorLog.createdAt = createdAt
        indoorLog.createdAtFormatted = createdAtFormatted
        indoorLog.duration = formatDuration(activity.duration)
        indoorLog.distance = formatDistance(activity.distance, useMetric: runEngine.useMetric)
        indoorLog.caloriesBurned = activity.calories
        indoorLog.type = "indoor"
        indoorLog.runType = activity.runType ?? "treadmill_run"
        
        // Parse activityData JSON string
        if let activityDataString = activity.activityData,
           let data = activityDataString.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Parse average pace
                    if let avgPace = json["averagePace"] as? String {
                        indoorLog.avgPace = avgPace
                    }
                    
                    // Parse treadmill data points
                    if let treadmillDataPoints = json["treadmillDataPoints"] as? [[String: Any]] {
                        indoorLog.treadmillDataPoints = treadmillDataPoints.compactMap { dict -> TreadmillDataPoint? in
                            return TreadmillDataPoint.fromDictionary(dict)
                        }
                    }
                }
            } catch {
                print("⚠️ [OutdoorRunViewController] Failed to parse activityData: \(error)")
            }
        }
        
        return indoorLog
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func formatDistance(_ meters: Double, useMetric: Bool) -> String {
        if useMetric {
            if meters >= 1000 {
                return String(format: "%.2f km", meters / 1000.0)
            } else {
                return String(format: "%.0f m", meters)
            }
        } else {
            let miles = meters / 1609.34
            return String(format: "%.2f mi", miles)
        }
    }
    
    public func getRunLogsForType(runType: String, limit: Int? = nil) async throws -> [RunLog] {
        // Determine which function to call based on run type
        if runType == "treadmillRun" {
            // For treadmill runs, use getTreadmillLogs
            return try await withCheckedThrowingContinuation { continuation in
                getTreadmillLogs { indoorLogs, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    // Convert IndoorRunLog to RunLog with treadmillRun type
                    let runLogs = indoorLogs?.map { indoorLog -> RunLog in
                        var runLog = RunLog()
                        runLog.id = indoorLog.id
                        runLog.duration = indoorLog.duration
                        runLog.distance = indoorLog.distance
                        runLog.avgPace = indoorLog.avgPace
                        runLog.createdAt = indoorLog.createdAt
                        runLog.createdAtFormatted = indoorLog.createdAtFormatted
                        runLog.createdBy = indoorLog.createdBy
                        runLog.caloriesBurned = indoorLog.caloriesBurned
                        return runLog
                    }
                    
                    // Apply limit if specified
                    if let limit = limit, let logs = runLogs, logs.count > limit {
                        continuation.resume(returning: Array(logs.prefix(limit)))
                    } else {
                        continuation.resume(returning: runLogs ?? [])
                    }
                }
            }
        } else {
            // For outdoor runs and other types, use getRunningLogs
            // First check if we have cached results that match
            if !outdoorRuns.isEmpty {
                let filteredLogs: [RunLog] = outdoorRuns
                
                if !filteredLogs.isEmpty {
                    if let limit = limit, filteredLogs.count > limit {
                        return Array(filteredLogs.prefix(limit))
                    } else {
                        return filteredLogs
                    }
                }
            }
            
            // No matching cached results, get from server
            return try await withCheckedThrowingContinuation { continuation in
                getRunningLogs { logs, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let logs = logs else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    // Use all logs regardless of run type
                    // Apply limit if needed
                    if let limit = limit, logs.count > limit {
                        continuation.resume(returning: Array(logs.prefix(limit)))
                    } else {
                        continuation.resume(returning: logs)
                    }
                    
                }
            }
        }
    }
    
    func cycleMapViewMode() {
        switch mapViewMode {
        case .normal:
            mapViewMode = .fullscreen
        case .fullscreen:
            mapViewMode = .minimized
        case .minimized:
            mapViewMode = .hidden
        case .hidden:
            mapViewMode = .normal
        case .satellite:
            mapViewMode = .normal
        case .hybrid:
            mapViewMode = .normal
        case .terrain:
            mapViewMode = .normal
        }
    }
    
    public func updatePaceStatus(currentPace: Double) {
        // runEngine.pace is in minutes/km, convert to user's preferred units
        let currentPaceInUserUnits: Double
        if runEngine.useMetric {
            // Convert from minutes/km to seconds/km
            currentPaceInUserUnits = currentPace * 60.0
        } else {
            // Convert from minutes/km to seconds/mile
            currentPaceInUserUnits = currentPace * 60.0 * 1.60934
        }
        
        guard currentPaceInUserUnits > 0 else { return }
        
        if let targetPace = targetPace {
            // Compare to target pace (if set) - both now in user's preferred units
            let paceVariance = currentPaceInUserUnits - targetPace
            let varianceThreshold = targetPace * 0.1 // 10% variance
            
            // Debug logging
            print("🎯 Pace Comparison: Current=\(String(format: "%.1f", currentPaceInUserUnits)) sec, Target=\(String(format: "%.1f", targetPace)) sec, Variance=\(String(format: "%.1f", paceVariance))")
            
            if abs(paceVariance) <= varianceThreshold * 0.5 {
                // Within 5% of target
                currentPaceStatus = .onTarget
                print("🎯 Status: On Target")
            } else if paceVariance > varianceThreshold {
                // Too slow (higher pace value = slower)
                currentPaceStatus = .tooSlow
                print("🎯 Status: Too Slow")
            } else {
                // Too fast (lower pace value = faster)
                currentPaceStatus = .tooFast
                print("🎯 Status: Too Fast")
            }
        } else if !historicalPaces.isEmpty {
            // Compare to historical averages - both now in user's preferred units
            let avgHistoricalPace = historicalPaces.reduce(0, +) / Double(historicalPaces.count)
            let paceVariance = currentPaceInUserUnits - avgHistoricalPace
            let varianceThreshold = avgHistoricalPace * 0.1 // 10% variance
            
            if abs(paceVariance) <= varianceThreshold * 0.5 {
                // Within 5% of average
                currentPaceStatus = .onTarget
            } else if paceVariance > varianceThreshold {
                // Too slow (higher pace value)
                currentPaceStatus = .tooSlow
            } else {
                // Too fast (lower pace value)
                currentPaceStatus = .tooFast
            }
        } else {
            // No comparison data available
            currentPaceStatus = .onTarget
        }
    }
    
    public func sendTargetPaceToWatch(targetPace: Double) {
        // Send target pace to watch if session is available
        guard WCSession.isSupported() && WCSession.default.isReachable else {
            print("📱 ⌚️ Watch not reachable, skipping target pace update")
            return
        }
        
        let message: [String: Any] = [
            "type": "targetPaceUpdate",
            "targetPace": targetPace,
            "targetPaceSource": targetPaceSource,
            "runType": runType.rawValue,
            "useMetric": runEngine.useMetric
        ]
        
        WCSession.default.sendMessage(message, replyHandler: { reply in
            print("📱 ✅ Watch acknowledged target pace update: \(targetPace)")
        }, errorHandler: { error in
            print("📱 ❌ Failed to send target pace to watch: \(error.localizedDescription)")
        })
    }
    
    public func checkForPaceGuidance() {
         // Skip pace guidance if no audio is selected
        guard voiceGuidanceLevel != .none else { return }
        
        guard paceGuidanceEnabled, isRunning, !isPaused else { return }
        
        // Wait for user to settle into their pace (avoid guidance during initial acceleration)
        let minimumTimeBeforeGuidance: TimeInterval = 30.0 // Wait 30 seconds before first guidance
        
        guard runEngine.elapsedTime >= minimumTimeBeforeGuidance else {
            return
        }
        
        // Additional check: ensure we have a stable pace reading
        let currentPace = runEngine.pace.value
        guard currentPace > 0.1 && currentPace < 20.0 else {
            // Pace is still unstable (too fast or too slow)
            return
        }
        
        // Ensure we don't provide guidance too frequently
        let now = Date()
        guard lastPaceAnnouncement == nil || now.timeIntervalSince(lastPaceAnnouncement!) > paceAnnouncementCooldown else {
            return
        }
        
        // Only provide guidance if the pace status is not on target
        if currentPaceStatus != .onTarget {
            let guidanceMessage: String
            
            switch currentPaceStatus {
            case .tooFast:
                guidanceMessage = "You're going a bit fast. Consider slowing your pace slightly."
            case .tooSlow:
                guidanceMessage = "Try to pick up the pace a little to reach your target."
            case .onTarget:
                return // No guidance needed
            }
            
            // Announce the guidance
            if isVoiceGuidanceEnabled {
                // Use a softer voice for pace guidance
                let utterance = AVSpeechUtterance(string: guidanceMessage)
                utterance.rate = 0.5
                utterance.volume = voiceGuidanceVolume * 0.8 // Slightly quieter
                
                if let language = Locale.current.languageCode {
                    utterance.voice = AVSpeechSynthesisVoice(language: language)
                }
                
                speechSynthesizer.speak(utterance)
            }
            
            // Update coach feedback
            runEngine.coachFeedback = guidanceMessage
            
            // Set the timestamp for the last announcement
            lastPaceAnnouncement = now
        }
    }
    

    
    
    public func updateCurrentWaypoint() {
        // Find the next waypoint based on current progress
        guard let waypoints = getCurrentWaypoints(),
              routePlanner.nextDirectionIndex < waypoints.count else {
            currentRouteWaypoint = nil
            return
        }
        
        currentRouteWaypoint = waypoints[routePlanner.nextDirectionIndex]
    }

    // Update the getCurrentWaypoints function to use stored waypoints
    public func getCurrentWaypoints() -> [RouteWaypoint]? {
        return currentWaypoints.isEmpty ? nil : currentWaypoints
    }

    public func completeRouteNavigation() {
        // Route navigation completed
        routePlanner.navigationActive = false
        isShowingNavigationPanel = false
        currentRouteWaypoint = nil
        
        // Announce completion
        if voiceGuidanceLevel != .none {
            announceMessage("Route completed! Great job!")
        }
        
        // Optional: Show completion animation or update UI
        print("🎉 Route navigation completed")
    }

    public func initializeRouteProgress(coordinates: [CLLocationCoordinate2D]) {
        let totalDistance = calculateTotalDistance(coordinates: coordinates)
        
        routeProgress = RouteProgress()
        routeProgress.remainingDistance = totalDistance
        routeProgress.completedDistance = 0
        routeProgress.completionPercentage = 0
        routeProgress.estimatedTimeRemaining = 0
        routeProgress.nextWaypointDistance = 0
        
        print("📊 Route progress initialized - total distance: \(formatDistance(totalDistance))")
    }

    public func setupRouteAnnotations(coordinates: [CLLocationCoordinate2D], waypoints: [RouteWaypoint]) {
        // Remove existing route annotations
        let existingAnnotations = mapView.annotations.filter { annotation in
            return annotation.title??.contains("Route") == true ||
                   annotation.title??.contains("Waypoint") == true
        }
        mapView.removeAnnotations(existingAnnotations)
        
        // Add start annotation
        if let startCoord = coordinates.first {
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = startCoord
            startAnnotation.title = "Route Start"
            startAnnotation.subtitle = "Begin your run here"
            mapView.addAnnotation(startAnnotation)
        }
        
        // Add finish annotation
        if let endCoord = coordinates.last, coordinates.count > 1 {
            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = endCoord
            endAnnotation.title = "Route Finish"
            endAnnotation.subtitle = "End of your planned route"
            mapView.addAnnotation(endAnnotation)
        }
        
        // Add significant waypoint annotations (turns only, not checkpoints)
        for waypoint in waypoints {
            if case .turn(let direction) = waypoint.type {
                let annotation = MKPointAnnotation()
                annotation.coordinate = waypoint.coordinate
                annotation.title = "Waypoint"
                annotation.subtitle = direction.description
                mapView.addAnnotation(annotation)
            }
        }
        
        print("📍 Added \(waypoints.count) waypoint annotations to map")
    }

    public func createFallbackRoute() -> [CLLocationCoordinate2D] {
        // Create a simple default route if no route data is available
        guard let currentLocation = locationManager.location?.coordinate else {
            // If no location available, create a generic route around a default area
            let defaultCenter = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
            return createCircularRoute(center: defaultCenter, radiusMeters: 1000)
        }
        
        // Create a simple circular route around current location
        return createCircularRoute(center: currentLocation, radiusMeters: 1000)
    }

    public func createCircularRoute(center: CLLocationCoordinate2D, radiusMeters: Double) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        let numberOfPoints = 20 // Create a smooth circle
        let radiusInDegrees = radiusMeters / 111000.0 // Rough conversion to degrees (1 degree ≈ 111km)
        
        for i in 0...numberOfPoints {
            let angle = (Double(i) / Double(numberOfPoints)) * 2 * Double.pi
            let latitude = center.latitude + radiusInDegrees * cos(angle)
            let longitude = center.longitude + radiusInDegrees * sin(angle) / cos(center.latitude * Double.pi / 180)
            
            coordinates.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
        
        return coordinates
    }
    
    
    public func generateIntelligentWaypoints(from coordinates: [CLLocationCoordinate2D]) -> [RouteWaypoint] {
        guard coordinates.count > 2 else { return [] }
        
        var waypoints: [RouteWaypoint] = []
        var cumulativeDistance: Double = 0
        
        // Start waypoint
        waypoints.append(RouteWaypoint(
            coordinate: coordinates[0],
            instruction: "Start your run",
            type: .start,
            distanceFromStart: 0
        ))
        
        // Analyze route for significant turns and landmarks
        for i in 1..<coordinates.count-1 {
            let prevCoord = coordinates[i-1]
            let currentCoord = coordinates[i]
            let nextCoord = coordinates[i+1]
            
            // Calculate distance
            let segment = CLLocation(latitude: prevCoord.latitude, longitude: prevCoord.longitude)
                .distance(from: CLLocation(latitude: currentCoord.latitude, longitude: currentCoord.longitude))
            cumulativeDistance += segment
            
            // Detect significant turns
            if let turnDirection = detectSignificantTurn(from: prevCoord, through: currentCoord, to: nextCoord) {
                waypoints.append(RouteWaypoint(
                    coordinate: currentCoord,
                    instruction: turnDirection.description,
                    type: .turn(direction: turnDirection),
                    distanceFromStart: cumulativeDistance
                ))
            }
            
            // Add checkpoint waypoints every kilometer (or half mile)
            let checkpointInterval = runEngine.useMetric ? 1000.0 : 804.67 // 1km or 0.5mi
            if Int(cumulativeDistance / checkpointInterval) > Int((cumulativeDistance - segment) / checkpointInterval) {
                let distanceText = runEngine.useMetric ?
                    "\(Int(cumulativeDistance/1000)) km checkpoint" :
                    "\(String(format: "%.1f", cumulativeDistance/1609.34)) mile checkpoint"
                
                waypoints.append(RouteWaypoint(
                    coordinate: currentCoord,
                    instruction: "Reached \(distanceText)",
                    type: .checkpoint,
                    distanceFromStart: cumulativeDistance
                ))
            }
        }
        
        // Finish waypoint
        let finalDistance = cumulativeDistance + CLLocation(latitude: coordinates[coordinates.count-2].latitude, longitude: coordinates[coordinates.count-2].longitude)
            .distance(from: CLLocation(latitude: coordinates.last!.latitude, longitude: coordinates.last!.longitude))
        
        waypoints.append(RouteWaypoint(
            coordinate: coordinates.last!,
            instruction: "Finish your run",
            type: .finish,
            distanceFromStart: finalDistance
        ))
        
        return waypoints
    }

    public func detectSignificantTurn(from prev: CLLocationCoordinate2D, through current: CLLocationCoordinate2D, to next: CLLocationCoordinate2D) -> TurnDirection? {
        let bearing1 = calculateBearing(from: prev, to: current)
        let bearing2 = calculateBearing(from: current, to: next)
        
        var angleDiff = bearing2 - bearing1
        
        // Normalize angle difference
        while angleDiff > 180 { angleDiff -= 360 }
        while angleDiff < -180 { angleDiff += 360 }
        
        let absAngle = abs(angleDiff)
        
        // Only consider significant turns
        if absAngle < 30 { return nil }
        
        switch absAngle {
        case 30..<60:
            return angleDiff > 0 ? .right : .left
        case 60..<120:
            return angleDiff > 0 ? .right : .left
        case 120..<150:
            return angleDiff > 0 ? .sharpRight : .sharpLeft
        default:
            return .uTurn
        }
    }
    
    
    public func generateDetailedNavigationDirections(from waypoints: [RouteWaypoint]) -> [String] {
        var directions: [String] = []
        
        for (index, waypoint) in waypoints.enumerated() {
            switch waypoint.type {
            case .start:
                let totalDistance = formatDistance(waypoints.last?.distanceFromStart ?? 0)
                directions.append("Begin your \(totalDistance) route. Follow the blue path.")
                
            case .turn(let direction):
                let distanceFromStart = formatDistance(waypoint.distanceFromStart)
                if index < waypoints.count - 1 {
                    let nextWaypoint = waypoints[index + 1]
                    let distanceToNext = formatDistance(nextWaypoint.distanceFromStart - waypoint.distanceFromStart)
                    directions.append("\(direction.description), then continue for \(distanceToNext)")
                } else {
                    directions.append(direction.description)
                }
                
            case .landmark(let name):
                directions.append("Pass \(name)")
                
            case .checkpoint:
                let remaining = formatDistance((waypoints.last?.distanceFromStart ?? 0) - waypoint.distanceFromStart)
                directions.append("Checkpoint reached. \(remaining) remaining.")
                
            case .finish:
                directions.append("You have reached the finish line!")
            }
        }
        
        return directions
    }
    
    // MARK: - Smart Map Display

    public func addEnhancedRouteToMap(coordinates: [CLLocationCoordinate2D]) {
        // Remove existing overlays
        clearRouteOverlays()
        
        // Add full route as planned route (light blue, dashed)
        let plannedRoute = MKPolyline(coordinates: coordinates, count: coordinates.count)
        routeOverlay = plannedRoute
        mapView.addOverlay(plannedRoute)
        
        // Set up for progress tracking
        setupProgressTracking(coordinates: coordinates)
        
        // Zoom to show entire route initially
        zoomToFitRoute(coordinates: coordinates)
    }

    public func setupProgressTracking(coordinates: [CLLocationCoordinate2D]) {
        // This will be called as the user progresses through the route
        routeProgress = RouteProgress()
        routeProgress.remainingDistance = calculateTotalDistance(coordinates: coordinates)
    }

    // MARK: - Dynamic Route Progress Updates
    // Store waypoints when route is loaded (modify the loadPreSelectedRoute function)
    public func loadPreSelectedRoute(route: Route) {
        print("📍 Loading pre-selected route: \(route.name ?? "Unnamed")")
        
        // Set the route property for animations
        self.route = route
        
        // Convert Route coordinates to CLLocationCoordinate2D array
        var routeCoordinates: [CLLocationCoordinate2D] = []
        
        if let routePoints = route.routePoints, !routePoints.isEmpty {
            routeCoordinates = routePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        } else if let routePointsString = route.routePointsData, !routePointsString.isEmpty {
            // Parse JSON route data
            do {
                if let data = routePointsString.data(using: .utf8),
                   let points = try JSONSerialization.jsonObject(with: data) as? [[String: Double]] {
                    routeCoordinates = points.compactMap { point in
                        if let lat = point["lat"], let lon = point["lon"] {
                            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        }
            return nil
        }
                }
            } catch {
                print("Failed to parse route points: \(error)")
            }
        }
        
        // Fallback: create route if no coordinates
        if routeCoordinates.isEmpty {
            routeCoordinates = createFallbackRoute()
        }
        
        // Set up route in RoutePlanner
        routePlanner.routePolyline = routeCoordinates
        
        // Generate intelligent waypoints and store them
        currentWaypoints = generateIntelligentWaypoints(from: routeCoordinates)
        let directions = generateDetailedNavigationDirections(from: currentWaypoints)
        
        routePlanner.navigationDirections = directions
        routePlanner.navigationActive = true
        routePlanner.nextDirectionIndex = 0
        
        // Create annotations
        setupRouteAnnotations(coordinates: routeCoordinates, waypoints: currentWaypoints)
        
        // Add route to map with smart visual hierarchy
        addEnhancedRouteToMap(coordinates: routeCoordinates)
        
        // Initialize route progress tracking
        initializeRouteProgress(coordinates: routeCoordinates)
        
        // Set initial waypoint
        updateCurrentWaypoint()
        
        // Announce route loading
        announceRouteLoaded(route: route, waypoints: currentWaypoints)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
               self.updateNavigationPanel()
           }
           
           print("🗺️ Route loaded with navigation panel enabled")
        
        print("🗺️ Route loaded with \(currentWaypoints.count) waypoints and \(directions.count) directions")
        
    }
    

    public func updateRouteProgress(at currentLocation: CLLocation) {
        guard !routePlanner.routePolyline.isEmpty else { return }
        
        // Find closest point on route
        let closestPoint = findClosestPointOnRoute(to: currentLocation.coordinate)
        
        guard let routePoint = closestPoint else { return }
        
        // Check if user is on route
        let wasOffRoute = !isOnRoute
        isOnRoute = routePoint.distance < 50 // Within 50 meters
        routeDeviationDistance = routePoint.distance
        
        // Reset deviation announcement when back on route
        if isOnRoute && wasOffRoute {
            hasAnnouncedDeviation = false
            wasOnRouteLastCheck = true
            print("✅ Back on route - deviation announcements reset")
            
            // Optional: announce return to route
            if voiceGuidanceLevel == .comprehensive {
                announceMessage("Back on route")
            }
        }
        
        if isOnRoute {
            // Update progress
            updateRouteProgressOverlays(progressIndex: routePoint.index)
            updateNextWaypoint(progressIndex: routePoint.index)
            
            // Check for navigation announcements
            checkForNavigationAnnouncements(progressIndex: routePoint.index)
            
            wasOnRouteLastCheck = true
        } else {
            // Handle route deviation (will only announce once)
            handleRouteDeviation(currentLocation: currentLocation)
            wasOnRouteLastCheck = false
        }
    }
    
    public func updateNextWaypoint(progressIndex: Int) {
        guard !currentWaypoints.isEmpty else { return }
        
        // Calculate distance along route to current progress point
        let routeCoordinates = routePlanner.routePolyline
        guard progressIndex < routeCoordinates.count else { return }
        
        var distanceToProgress: Double = 0
        for i in 0..<progressIndex {
            let loc1 = CLLocation(latitude: routeCoordinates[i].latitude, longitude: routeCoordinates[i].longitude)
            let loc2 = CLLocation(latitude: routeCoordinates[i+1].latitude, longitude: routeCoordinates[i+1].longitude)
            distanceToProgress += loc1.distance(from: loc2)
        }
        
        // Find the next waypoint ahead of current progress
        var nextWaypointIndex = -1
        for (index, waypoint) in currentWaypoints.enumerated() {
            if waypoint.distanceFromStart > distanceToProgress {
                nextWaypointIndex = index
                break
            }
        }
        
        // Update current waypoint and navigation index
        if nextWaypointIndex >= 0 && nextWaypointIndex < currentWaypoints.count {
            currentRouteWaypoint = currentWaypoints[nextWaypointIndex]
            routePlanner.nextDirectionIndex = nextWaypointIndex
            
            // Calculate distance to next waypoint
            routeProgress.nextWaypointDistance = currentWaypoints[nextWaypointIndex].distanceFromStart - distanceToProgress
            } else {
            // No more waypoints ahead
            currentRouteWaypoint = nil
            routeProgress.nextWaypointDistance = 0
        }
        
        // Update overall route progress
        let totalRouteDistance = currentWaypoints.last?.distanceFromStart ?? 0
        routeProgress.completedDistance = distanceToProgress
        routeProgress.remainingDistance = max(0, totalRouteDistance - distanceToProgress)
        routeProgress.completionPercentage = totalRouteDistance > 0 ? (distanceToProgress / totalRouteDistance) * 100 : 0
    }


    public func updateRouteProgressOverlays(progressIndex: Int) {
        let coordinates = routePlanner.routePolyline
        
        // Remove old progress overlays
        if let progressOverlay = routeProgressOverlay {
            mapView.removeOverlay(progressOverlay)
        }
        if let remainingOverlay = routeRemainingOverlay {
            mapView.removeOverlay(remainingOverlay)
        }
        
        // Only create overlays if we have valid progress
        guard progressIndex >= 0 && progressIndex < coordinates.count else { return }
        
        // Create completed path (bright blue, solid)
        if progressIndex > 0 {
            let completedCoords = Array(coordinates[0...progressIndex])
            let completedPath = MKPolyline(coordinates: completedCoords, count: completedCoords.count)
            routeProgressOverlay = completedPath
            mapView.addOverlay(completedPath)
        }
        
        // Create remaining path (dimmed blue, dashed)
        if progressIndex < coordinates.count - 1 {
            let remainingCoords = Array(coordinates[progressIndex...])
            let remainingPath = MKPolyline(coordinates: remainingCoords, count: remainingCoords.count)
            routeRemainingOverlay = remainingPath
            mapView.addOverlay(remainingPath)
        }
        
        // Update route progress statistics
        updateRouteProgressStats(progressIndex: progressIndex)
    }

    public func updateRouteProgressStats(progressIndex: Int) {
        let coordinates = routePlanner.routePolyline
        guard progressIndex < coordinates.count else { return }
        
        // Calculate completed distance
        var completedDistance: Double = 0
        for i in 0..<min(progressIndex, coordinates.count - 1) {
            let loc1 = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            let loc2 = CLLocation(latitude: coordinates[i+1].latitude, longitude: coordinates[i+1].longitude)
            completedDistance += loc1.distance(from: loc2)
        }
        
        // Calculate remaining distance
        var remainingDistance: Double = 0
        for i in progressIndex..<coordinates.count - 1 {
            let loc1 = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            let loc2 = CLLocation(latitude: coordinates[i+1].latitude, longitude: coordinates[i+1].longitude)
            remainingDistance += loc1.distance(from: loc2)
        }
        
        // Update route progress
        let totalDistance = completedDistance + remainingDistance
        routeProgress.completedDistance = completedDistance
        routeProgress.remainingDistance = remainingDistance
        routeProgress.completionPercentage = totalDistance > 0 ? (completedDistance / totalDistance) * 100 : 0
        
        // Estimate time remaining based on current pace
        if runEngine.elapsedTime > 0 && completedDistance > 0 {
            let currentPace = runEngine.elapsedTime / completedDistance // seconds per meter
            routeProgress.estimatedTimeRemaining = remainingDistance * currentPace
        }
    }

    public func checkForNavigationAnnouncements(progressIndex: Int) {
        // Check if we're approaching the next waypoint
        guard let currentWaypoint = currentRouteWaypoint,
              routePlanner.nextDirectionIndex < routePlanner.navigationDirections.count else { return }
        
        let coordinates = routePlanner.routePolyline
        let currentLocation = CLLocation(latitude: coordinates[progressIndex].latitude,
                                       longitude: coordinates[progressIndex].longitude)
        let waypointLocation = CLLocation(latitude: currentWaypoint.coordinate.latitude,
                                        longitude: currentWaypoint.coordinate.longitude)
        
        let distanceToWaypoint = currentLocation.distance(from: waypointLocation)
        
        // Announce when approaching waypoint (100m before)
        if distanceToWaypoint < 100 && distanceToWaypoint > 80 {
            if voiceGuidanceLevel != .none {
                let direction = routePlanner.navigationDirections[routePlanner.nextDirectionIndex]
                announceMessage("In 100 meters, \(direction.lowercased())")
            }
        }
        
        // Execute direction when at waypoint (within 20m)
        if distanceToWaypoint < 20 {
            advanceToNextWaypoint()
        }
    }

    public func advanceToNextWaypoint() {
        routePlanner.nextDirectionIndex += 1
        
        if routePlanner.nextDirectionIndex < routePlanner.navigationDirections.count {
            let nextDirection = routePlanner.navigationDirections[routePlanner.nextDirectionIndex]
            if voiceGuidanceLevel != .none {
                announceMessage(nextDirection)
            }
            
            // Update current waypoint
            updateCurrentWaypoint()
            } else {
            // Route completed
            completeRouteNavigation()
        }
    }

    // MARK: - Route Deviation Handling

    public func handleRouteDeviation(currentLocation: CLLocation) {
        // Only announce deviation if it's significant and we haven't recently announced it
        if routeDeviationDistance > 100 && !hasAnnouncedDeviation && wasOnRouteLastCheck {
                if voiceGuidanceLevel != .none {
                    announceMessage("Heads up!...You're off the planned route...")
                    hasAnnouncedDeviation = true
                    print("🚨 Route deviation announced - will not repeat until back on route")
                }
            }
            
            // Update state for next check
            wasOnRouteLastCheck = false
    }
    
    public func announceStartOfRun() {
        let announcement = createRandomStartAnnouncement()
        announceMessage(announcement)
    }

    public func createRandomStartAnnouncement() -> String {
        // Get weather info
        let temperature = getCurrentTemperature()
        let weatherCondition = getCurrentWeatherCondition()
        
        // Different announcement themes
        let themes: [AnnouncementTheme] = [.aviation, .sportsCommentary, .missionControl, .classic]
        let selectedTheme = themes.randomElement() ?? .classic
        
        return generateAnnouncement(theme: selectedTheme, temperature: temperature, weatherCondition: weatherCondition)
    }

    enum AnnouncementTheme {
        case aviation
        case sportsCommentary
        case missionControl
        case classic
    }

    public func generateAnnouncement(theme: AnnouncementTheme, temperature: String, weatherCondition: String) -> String {
        switch theme {
        case .aviation:
            return generateAviationAnnouncement(temperature: temperature, weatherCondition: weatherCondition)
        case .sportsCommentary:
            return generateSportsAnnouncement(temperature: temperature, weatherCondition: weatherCondition)
        case .missionControl:
            return generateMissionControlAnnouncement(temperature: temperature, weatherCondition: weatherCondition)
        case .classic:
            return generateClassicAnnouncement(temperature: temperature, weatherCondition: weatherCondition)
        }
    }

    public func generateAviationAnnouncement(temperature: String, weatherCondition: String) -> String {
        let openings = [
            "Good morning, runner. We're cleared for takeoff.",
            "Captain speaking — all systems are green.",
            "Welcome aboard your session.",
            "This is your captain.",
            "Flight plan confirmed, runner ready for departure."
        ]
        
        let weatherPhrases = [
            "Skies are \(weatherCondition), \(temperature).",
            "Weather conditions are optimal at \(temperature).",
            "Temperature is \(temperature), conditions favorable.",
            "Current conditions: \(temperature) and \(weatherCondition)."
        ]
        
        let closings = [
            "Pace at your discretion. Enjoy the ride.",
            "Prepare for departure.",
            "Let's begin our journey.",
            "Route is wide open. Let's get moving.",
            "Cruising altitude depends on your legs today."
        ]
        
        let opening = openings.randomElement() ?? openings[0]
        let weather = weatherPhrases.randomElement() ?? weatherPhrases[0]
        let closing = closings.randomElement() ?? closings[0]
        
        return "\(opening) \(weather) \(closing)"
    }

    public func generateSportsAnnouncement(temperature: String, weatherCondition: String) -> String {
        let openings = [
            "And here we go — the run begins",
            "It's game time. The clock starts now",
            "Out on the course, a runner takes the line",
            "Session is live, and we're underway",
            "Time to see what you're made of"
        ]
        
        let weatherIntegrations = [
            "under \(weatherCondition) skies, \(temperature)",
            "with perfect conditions at \(temperature)",
            "in ideal \(temperature) weather",
            "as conditions remain \(weatherCondition) at \(temperature)"
        ]
        
        let closings = [
            "and every step writes the story.",
            "Let's see what this session brings.",
            "The course is yours, and the conditions? Prime.",
            "Heart set, pace rising.",
            "This runner is ready to make headlines."
        ]
        
        let opening = openings.randomElement() ?? openings[0]
        let weather = weatherIntegrations.randomElement() ?? weatherIntegrations[0]
        let closing = closings.randomElement() ?? closings[0]
        
        return "\(opening) \(weather), \(closing)"
    }

    public func generateMissionControlAnnouncement(temperature: String, weatherCondition: String) -> String {
        let openings = [
            "Mission Control to runner — we have green light for launch.",
            "Houston, we are go for surface operations.",
            "All systems nominal. Mission is a go.",
            "Mission Control here — telemetry looks good.",
            "Ground control to runner — you are cleared for take off."
        ]
        
        let weatherReports = [
            "Environmental conditions: \(temperature), \(weatherCondition).",
            "Surface conditions optimal at \(temperature).",
            "Weather tracking shows \(temperature) and \(weatherCondition).",
            "Atmospheric reading: \(temperature), visibility \(weatherCondition)."
        ]
        
        let closings = [
            "You are cleared for surface operations. Godspeed.",
            "All systems green. Begin your mission.",
            "GPS locked, heart rate stable. Let's explore.",
            "Mission parameters locked in. Good luck out there.",
            "Commence surface operations. Over and out."
        ]
        
        let opening = openings.randomElement() ?? openings[0]
        let weather = weatherReports.randomElement() ?? weatherReports[0]
        let closing = closings.randomElement() ?? closings[0]
        
        return "\(opening) \(weather) \(closing)"
    }

    public func generateClassicAnnouncement(temperature: String, weatherCondition: String) -> String {
        let motivational = [
            "Time to chase those goals.",
            "Let's make this run count.",
            "Your journey begins now.",
            "Ready to push your limits?",
            "Every step is progress."
        ]
        
        let weatherMention = "Current conditions: \(temperature) and \(weatherCondition)."
        let motivation = motivational.randomElement() ?? motivational[0]
        
        return "Starting your run. \(weatherMention) \(motivation)"
    }

    public func getCurrentTemperature() -> String {
        if let currentWeather = weatherService.currentWeather {
            let temperature = currentWeather.temperature
            
            if UserDefaults.standard.bool(forKey: "useMetric") {
                return "\(Int(temperature)) degrees Celsius"
            } else {
                let fahrenheit = (temperature * 9/5) + 32
                return "\(Int(fahrenheit)) degrees Fahrenheit"
            }
        }
        return "pleasant temperature"
    }

    public func getCurrentWeatherCondition() -> String {
        if let currentWeather = weatherService.currentWeather {
            // WeatherCondition is an enum, so we use a switch statement
            switch currentWeather.condition {
            case .clear:
                return "clear"
            case .cloudy:
                return "cloudy"
            case .partlyCloudy:
                return "partly cloudy"
            case .rainy:
                return "wet"
            case .snowy:
                return "snowy"
            case .stormy:
                return "stormy"
            case .foggy:
                return "misty"
            case .windy:
                return "breezy"
            case .unknown:
                return "calm"
            }
        }
        return "perfect"
    }
    
    // MARK: - Public Methods
    
    // This method is called from ModernRunTrackerViewController to set up a pre-selected trail
    public func setupWithRoute(_ route: Route) {
        print("📍 Setting up OutdoorRunViewController with pre-selected route: \(route.name ?? "Unnamed")")
        preSelectedRoute = route
        // Also set the route property for animations
        self.route = route
    }
    
    // MARK: - Additional UI Actions
    
    @objc public func startButtonTapped() {
        // Start run tracking
        runEngine.startRun(runType: runType)
        
        // If we have a selected route, start guidance
        if let selectedRoute = preSelectedRoute {
            print("Starting guidance for selected route: \(selectedRoute.name ?? "Unnamed")")
            runEngine.startGuidanceForRoute(selectedRoute)
        }
        
        // Update the status display
        updateStatusDisplay()
        
        // Notify watch that we've started running
        sendTrackingStatusToWatch()
        
        // Publish notification for other components
        NotificationCenter.default.post(name: .didStartWorkout, object: nil)
    }
    
    @objc public func pauseButtonTapped() {
        pauseRun()
    }
    
    @objc public func resumeButtonTapped() {
        resumeRun()
    }
    

    
    // MARK: - Watch Connectivity
    
    public func sendRouteToWatch() {
        guard let session = session, session.isReachable else {
            print("Watch is not reachable")
            return
        }
        
        // Prepare route data in a compact format
        var routeData: [String: Any] = [:]
        
        if !routePlanner.routePolyline.isEmpty {
            // For performance, simplify the route before sending to watch
            // Include only key points to reduce data transfer
            let simplifiedRoute = routePlanner.routePolyline
            
            // Create arrays of lat/lon values
            let latitudes = simplifiedRoute.map { $0.latitude }
            let longitudes = simplifiedRoute.map { $0.longitude }
            
            routeData["latitudes"] = latitudes
            routeData["longitudes"] = longitudes
            
            if let routeName = preSelectedRoute?.name {
                routeData["routeName"] = routeName
            }
            
            // Include distance and expected duration
            routeData["distance"] = routePlanner.routeDistance
            
            // Include type
            routeData["runType"] = runType.rawValue
        }
        
        // Include current run state if running
        if runEngine.runState == .running || runEngine.runState == .paused {
            routeData["runState"] = runEngine.runState == .running ? "running" : "paused"
            routeData["elapsedTime"] = runEngine.elapsedTime
            routeData["distance"] = runEngine.distance.value
            routeData["pace"] = runEngine.pace.value
        }
        
        // Send to watch
        session.sendMessage(routeData, replyHandler: nil) { error in
            print("Error sending route to watch: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Navigation Direction Generation

    public func generateNavigationDirections(for coordinates: [CLLocationCoordinate2D]) {
        guard coordinates.count > 2 else {
            // Not enough points for meaningful directions
            return
        }
        
        var directions: [String] = []
        
        // Generate more meaningful directions based on the route
        let totalDistance = calculateTotalDistance(coordinates: coordinates)
        let distanceText = formatDistance(totalDistance)
        
        // Better starting instruction
        directions.append("Follow the blue route for \(distanceText)")
        
        // Add waypoint-based directions if we have enough points
        if coordinates.count > 10 {
            let quarterPoint = coordinates.count / 4
            let halfPoint = coordinates.count / 2
            let threeQuarterPoint = (coordinates.count * 3) / 4
            
            // Quarter point instruction
            directions.append("Continue following the route, you're making good progress")
            
            // Halfway point instruction
            directions.append("You're halfway through the route, keep going")
            
            // Three-quarter point instruction
            directions.append("You're approaching the final stretch of the route")
        }
        
        // Better finish direction
        directions.append("You're approaching the end of your route")
        
        // Save to route planner
        routePlanner.navigationDirections = directions
        routePlanner.navigationActive = true
        routePlanner.nextDirectionIndex = 0
        
        print("🗺️ Generated \(directions.count) navigation directions")
        print("📍 First direction: \(directions[0])")
    }
    
    // Update the progress overlay on the map as user runs
    public func updateProgressOverlay() {
        guard !routePlanner.routePolyline.isEmpty,
              runEngine.runState == .running,
              !runEngine.locationList.isEmpty else {
            return
        }
        
        // Get the current run path from the engine
        let runPath = runEngine.locationList.map { $0.coordinate }
        
        // Create a polyline from the run path with a slightly different path
        // Add small offset to visually separate from the main run path when they overlap
        var offsetCoordinates: [CLLocationCoordinate2D] = []
        let offset = 0.000025 // Small offset for visual separation
        
        for coordinate in runPath {
            let offsetCoord = CLLocationCoordinate2D(
                latitude: coordinate.latitude + offset,
                longitude: coordinate.longitude - offset
            )
            offsetCoordinates.append(offsetCoord)
        }
        
        // Create polyline for progress
        let polyline = MKPolyline(coordinates: offsetCoordinates, count: offsetCoordinates.count)
        
        // Remove the old progress overlay if it exists
        if let existingOverlay = progressOverlay {
            mapView.removeOverlay(existingOverlay)
        }
        
        // Add the new progress overlay
        progressOverlay = polyline
        mapView.addOverlay(polyline)
        print("🗺️ Updated progress overlay with \(offsetCoordinates.count) points")
        
        // Update the metrics with distance along route if we have a planned route
        if !routePlanner.routePolyline.isEmpty {
            // Find closest point on route to current location
            if let currentLocation = runEngine.locationList.last,
               let closestPoint = findClosestPointOnRoute(to: currentLocation.coordinate) {
                
                // Calculate progress along route
                let progressIndex = closestPoint.index
                routeCompletionPercentage = Double(progressIndex) / Double(routePlanner.routePolyline.count - 1) * 100.0
                
                // Update the route completion in the hosting controller
                hostingController?.rootView.routeCompletionPercentage = routeCompletionPercentage
            }
        }
    }
    
 
    
    // Helper function to convert time strings (e.g. "10:30") to seconds
    public func timeStringToSeconds(_ timeString: String) -> TimeInterval? {
        let components = timeString.components(separatedBy: ":")
        
        if components.count == 2 {
            // Format: "MM:SS"
            guard let minutes = Double(components[0]),
                  let seconds = Double(components[1]) else {
                return nil
            }
            return (minutes * 60) + seconds
        } else if components.count == 3 {
            // Format: "HH:MM:SS"
            guard let hours = Double(components[0]),
                  let minutes = Double(components[1]),
                  let seconds = Double(components[2]) else {
                return nil
            }
            return (hours * 3600) + (minutes * 60) + seconds
        }
        
        return nil
    }
    
    // MARK: - Route Animation Methods
    public func offerRouteAnimation() {
        guard let _ = route?.routeCoordinates, route?.routeCoordinates.count ?? 0 > 0 else {
            print("No route coordinates available to animate")
            return
        }
        
        let alert = UIAlertController(
            title: "Preview Route",
            message: "Would you like to see an animation of this route?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Yes", style: .default) { [weak self] _ in
            self?.startRouteAnimation()
        })
        
        alert.addAction(UIAlertAction(title: "No", style: .cancel))
        
        present(alert, animated: true)
    }
    
    public func startRouteAnimation() {
        guard let coordinates = route?.routeCoordinates, coordinates.count > 0 else {
            print("No route coordinates available to animate")
            return
        }
        
        print("Starting route animation with \(coordinates.count) coordinates")
        
        // Stop any existing animation
        animationTimer?.invalidate()
        
        // Reset animation state
        routeCoordinateIndex = 0
        isAnimatingRoute = true
        
        // Create user avatar annotation if it doesn't exist
        if userAvatarAnnotation == nil {
            userAvatarAnnotation = MKPointAnnotation()
            userAvatarAnnotation?.title = "You"
            if let startCoordinate = coordinates.first {
                userAvatarAnnotation?.coordinate = startCoordinate
                mapView.addAnnotation(userAvatarAnnotation!)
            }
        }
        
        // Zoom to fit the route
        zoomToFitRoute()
        
        // Start animation timer
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            self?.animateNextStep()
        }
    }
    
    public func animateNextStep() {
        guard let coordinates = route?.routeCoordinates,
              isAnimatingRoute,
              routeCoordinateIndex < coordinates.count else {
            // End of animation
            animationTimer?.invalidate()
            isAnimatingRoute = false
            return
        }
        
        // Update avatar position
        userAvatarAnnotation?.coordinate = coordinates[routeCoordinateIndex]
        
        // Update progress
        let progress = Float(routeCoordinateIndex) / Float(coordinates.count - 1)
        routeCompletionPercentage = Double(progress * 100)
        
        // Increment index
        routeCoordinateIndex += 1
        
        // End animation when we reach the end
        if routeCoordinateIndex >= coordinates.count {
            animationTimer?.invalidate()
            isAnimatingRoute = false
            
            // Show completion message
            let alert = UIAlertController(
                title: "Route Preview Complete",
                message: "You've seen the entire route. Ready to start running?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Let's Go", style: .default))
            
            present(alert, animated: true)
        }
    }
    
    // Add toggleRunning method to handle start/pause
    func toggleRunning() {
        if runEngine.runState == .running {
            runEngine.pauseRun()
            isRunning = false
            isPaused = true
        } else if runEngine.runState == .paused {
            runEngine.resumeRun()
            isRunning = true
            isPaused = false
        } else {
            runEngine.startRun(runType: runType)
            isRunning = true
            isPaused = false
        }
        
        // Notify watch of state change
        sendTrackingStatusToWatch()
        
        // Force UI update
        objectWillChange.send()
    }
    
    // Add stopRun method to handle stopping the run
    public func showEndRunConfirmation() {
        // Prevent duplicate alerts
        guard runEngine.runState == .running || runEngine.runState == .paused else { return }
        
        // Check if an alert is already being presented
        if presentedViewController is UIAlertController {
            print("📱 Alert already showing, skipping duplicate")
            return
        }
        
        let alert = UIAlertController(
            title: "End Run?",
            message: "Are you sure you want to end this run?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "End Run", style: .destructive) { _ in
            self.runEngine.endRun()
            self.updateStatusDisplay()
            self.sendTrackingStatusToWatch()
            self.showSummary()
        })
        
        present(alert, animated: true)
    }
    

    
    // Add method to update milestone markers
    public func updateMilestoneMarkers(for location: CLLocation) {
        let distance = runEngine.distance.value
        let markerDistanceMeters = runEngine.useMetric ? 1000.0 : 1609.34 // 1km or 1mi
        
        // Calculate current milestone
        let currentMilestone = Int(distance / markerDistanceMeters)
        
        // Remove old milestone markers
        mapView.removeAnnotations(mileMarkers)
        mileMarkers.removeAll()
        
        // Add markers for each completed milestone - only if we've passed at least one milestone
        if currentMilestone >= 1 {
            for i in 1...currentMilestone {
                // Find location at milestone distance
                let milestoneDistance = Double(i) * markerDistanceMeters
                if let markerLocation = findLocationAtDistance(milestoneDistance) {
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = markerLocation.coordinate
                    annotation.title = runEngine.useMetric ? "\(i) km" : "\(i) mi"
                    
                    mileMarkers.append(annotation)
                    mapView.addAnnotation(annotation)
                }
            }
        }
        
        // Always add a start marker if we have at least one location
        if let startLocation = runEngine.locationList.first {
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = startLocation.coordinate
            startAnnotation.title = "Start"
            
            mileMarkers.append(startAnnotation)
            mapView.addAnnotation(startAnnotation)
        }
    }
    
    // Add method to handle home button tap
    @objc public func handleHomeButtonTap() {
        if isReturnRouteEnabled {
            // Disable return route
            disableReturnRouteFromPanel()
        } else {
            // Enable return route
            guard let currentLocation = locationManager.location else {
                announceMessage("Unable to get current location")
                return
            }
            
            homeLocation = currentLocation.coordinate  // Extract coordinate
            isReturnRouteEnabled = true
            isNavigatingReturnRoute = true
            
            // Use the optimal return route method
            createOptimalReturnRoute(from: currentLocation.coordinate)
            announceMessage("Generating optimal route back to where you started")
        }
    }
    
    public func createOptimalReturnRoute(from currentLocation: CLLocationCoordinate2D) {
        guard let homeLocation = homeLocation else { return }
        
        // Remove old return route if exists
        removeReturnRoute()
        
        // Show navigation panel immediately with loading message
        DispatchQueue.main.async {
            self.showNavigationPanel = true
            self.isShowingNavigationPanel = true
            self.currentNavigationInstruction = "Creating optimal return route..."
            self.currentReturnInstruction = "Creating optimal return route..."
        }
        
        // Calculate direct distance to home
        let currentLocationCL = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let homeLocationCL = CLLocation(latitude: homeLocation.latitude, longitude: homeLocation.longitude)
        let directDistance = currentLocationCL.distance(from: homeLocationCL)
        
        // Decide between direct route or following run path based on distance and complexity
        if directDistance < 500 || runEngine.locationList.count < 10 {
            // For short distances or simple runs, use direct route
            createDirectReturnRoute(from: currentLocation, to: homeLocation)
        } else {
            // For longer runs, create a simplified reverse path
            createReversedPathReturnRoute(from: currentLocation, to: homeLocation)
        }
    }

    public func createDirectReturnRoute(from currentLocation: CLLocationCoordinate2D, to homeLocation: CLLocationCoordinate2D) {
        // Create a clean, direct line with slight curvature for visual appeal
        var coordinates: [CLLocationCoordinate2D] = []
        
        // Add current location
        coordinates.append(currentLocation)
        
        // Add a slight curve midpoint for visual appeal (only if distance > 200m)
        let currentLocationCL = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let homeLocationCL = CLLocation(latitude: homeLocation.latitude, longitude: homeLocation.longitude)
        let distance = currentLocationCL.distance(from: homeLocationCL)
        
        if distance > 200 {
            // Calculate midpoint with slight offset for curve
            let midLatitude = (currentLocation.latitude + homeLocation.latitude) / 2
            let midLongitude = (currentLocation.longitude + homeLocation.longitude) / 2
            
            // Add small perpendicular offset for gentle curve
            let bearing = calculateBearing(from: currentLocation, to: homeLocation)
            let perpendicularBearing = (bearing + 90) * Double.pi / 180
            let curveOffset = min(0.0001, distance / 10000000) // Scale offset with distance
            
            let curvedMidpoint = CLLocationCoordinate2D(
                latitude: midLatitude + curveOffset * cos(perpendicularBearing),
                longitude: midLongitude + curveOffset * sin(perpendicularBearing)
            )
            
            coordinates.append(curvedMidpoint)
        }
        
        // Add destination
        coordinates.append(homeLocation)
        
        // Create polyline
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        returnRouteOverlay = polyline
        mapView.addOverlay(polyline)
        
        // Simple direction for direct route
        if voiceGuidanceLevel == .moderate || voiceGuidanceLevel == .comprehensive {
            let distanceText = formatDistance(distance)
            returnRouteDirections = ["Head directly towards your starting point, \(distanceText) away"]
            currentReturnDirectionIndex = 0
            isShowingNavigationPanel = true
            currentReturnInstruction = returnRouteDirections[0]
        }
        
        print("🗺️ Direct return route created - distance: \(Int(distance))m")
    }

    
    public func createReversedPathReturnRoute(from currentLocation: CLLocationCoordinate2D, to homeLocation: CLLocationCoordinate2D) {
        // Create a simplified version of the run path in reverse
        var returnCoordinates: [CLLocationCoordinate2D] = []
        
        // Start from current location
        returnCoordinates.append(currentLocation)
        
        // Find the closest point on the run path to current location
        var closestIndex = 0
        var closestDistance = Double.infinity
        let currentLocationCL = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        
        // Fix: Convert LocationData to CLLocation properly
        for (index, locationData) in runEngine.locationList.enumerated() {
            let locationCL = CLLocation(latitude: locationData.latitude, longitude: locationData.longitude)
            let distance = currentLocationCL.distance(from: locationCL)
            if distance < closestDistance {
                closestDistance = distance
                closestIndex = index
            }
        }
        
        // Create simplified path from closest point back to start
        // Use every 3rd-5th point to create a cleaner path
        let simplificationFactor = max(3, runEngine.locationList.count / 25) // Ensure we don't have too many points
        
        for i in stride(from: closestIndex, through: 0, by: -simplificationFactor) {
            let locationData = runEngine.locationList[i]
            let coordinate = CLLocationCoordinate2D(latitude: locationData.latitude, longitude: locationData.longitude)
            returnCoordinates.append(coordinate)
        }
        
        // Ensure we end at the exact home location
        if let lastCoordinate = returnCoordinates.last,
           lastCoordinate.latitude != homeLocation.latitude || lastCoordinate.longitude != homeLocation.longitude {
            returnCoordinates.append(homeLocation)
        }
        
        // Create polyline
        let polyline = MKPolyline(coordinates: returnCoordinates, count: returnCoordinates.count)
        returnRouteOverlay = polyline
        mapView.addOverlay(polyline)
        
        // Simple navigation for reversed path
        if voiceGuidanceLevel == .moderate || voiceGuidanceLevel == .comprehensive {
            let totalDistance = calculateTotalDistance(coordinates: returnCoordinates)
            let distanceText = formatDistance(totalDistance)
            returnRouteDirections = ["Follow the orange path back to your starting point, \(distanceText) total"]
            currentReturnDirectionIndex = 0
            isShowingNavigationPanel = true
            currentReturnInstruction = returnRouteDirections[0]
        }
        
        print("🗺️ Reversed path return route created with \(returnCoordinates.count) points")
    }

  
    
    public func removeReturnRoute() {
        // Remove overlay from map
        if let overlay = returnRouteOverlay {
            mapView.removeOverlay(overlay)
        }
        
        // Clear return route properties
                returnRouteOverlay = nil
        returnRoute = nil
        returnRouteDirections.removeAll()
        currentReturnDirectionIndex = 0
        
        // Clear navigation state
        isShowingNavigationPanel = false
        currentReturnInstruction = ""
        distanceToNextTurn = 0.0
        isNavigatingReturn = false
        returnNavigationStartTime = nil
        
        print("🗺️ Return route removed and state cleared")
    }
    
    public func checkReturnRouteProgress(at location: CLLocation) {
        guard let route = returnRoute,
              currentReturnDirectionIndex < returnRouteDirections.count,
              currentReturnDirectionIndex < route.steps.count else { return }
        
        let currentStep = route.steps[currentReturnDirectionIndex]
        
        // Check if we're close to the end of the current step
        if let stepEndCoordinate = currentStep.polyline.coordinates.last {
            let stepEndLocation = CLLocation(latitude: stepEndCoordinate.latitude,
                                           longitude: stepEndCoordinate.longitude)
            let distanceToStepEnd = location.distance(from: stepEndLocation)
            
            // Update distance to next turn
            distanceToNextTurn = distanceToStepEnd
            
            // If we're close to the end of the current step (within 30 meters)
            if distanceToStepEnd < 30 {
                currentReturnDirectionIndex += 1
                
                // Check if we have more directions
                if currentReturnDirectionIndex < returnRouteDirections.count {
                    let nextDirection = returnRouteDirections[currentReturnDirectionIndex]
                    currentReturnInstruction = nextDirection
                    
                    // Announce the next direction
                    if voiceGuidanceLevel == .moderate || voiceGuidanceLevel == .comprehensive {
                        announceMessage(nextDirection)
                    }
                } else {
                    // We've reached the destination
                    currentReturnInstruction = "You have arrived at your starting point"
                    isShowingNavigationPanel = false
                    
                    if voiceGuidanceLevel != .none {
                        announceMessage("You have arrived at your starting point. Return route complete.")
                    }
                    
                    // Auto-disable return route
                    isReturnRouteEnabled = false
                    removeReturnRoute()
                }
            }
        }else {
            // We've reached the destination
            currentReturnInstruction = "You have arrived at your starting point"
            isShowingNavigationPanel = false
            
            if voiceGuidanceLevel != .none {
                announceMessage("You have arrived at your starting point. Return route complete.")
            }
            
            // Auto-disable return route and update button state
            isReturnRouteEnabled = false
            removeReturnRoute()
            
            print("🗺️ Return route auto-completed - user reached destination")
        }
    }
    // Add method to show settings
    func showVoiceGuidanceSettings() {
        let settingsVC = UIHostingController(rootView: VoiceGuidanceSettingsView(viewModel: self))
        settingsVC.modalPresentationStyle = .pageSheet
        present(settingsVC, animated: true)
    }
    
    // Add method to save settings
    func saveVoiceGuidanceSettings() {
        UserDefaults.standard.set(voiceGuidanceLevel.rawValue, forKey: "voiceGuidanceLevel")
        UserDefaults.standard.set(announcementFrequency.rawValue, forKey: "announcementFrequency")
        UserDefaults.standard.set(includePaceGuidance, forKey: "includePaceGuidance")
        UserDefaults.standard.set(includeHeartRateGuidance, forKey: "includeHeartRateGuidance")
        UserDefaults.standard.set(includeNavigationGuidance, forKey: "includeNavigationGuidance")
        
        // Update announcement interval
        announcementInterval = announcementFrequency.interval
        
        // Announce settings update
        announceMessage("Voice guidance settings updated")
    }
    
    // Add method to load settings
    public func loadVoiceGuidanceSettings() {
        // Try to load from UserDefaults
        if let savedLevel = UserDefaults.standard.string(forKey: "voiceGuidanceLevel"),
           let level = VoiceGuidanceLevel(rawValue: savedLevel) {
            voiceGuidanceLevel = level
        } else {
            // Default to comprehensive
            voiceGuidanceLevel = .comprehensive
        }
        
        if let savedFrequency = UserDefaults.standard.string(forKey: "announcementFrequency"),
           let frequency = AnnouncementFrequency(rawValue: savedFrequency) {
            announcementFrequency = frequency
        } else {
            // Default to every 2 minutes for testing
            announcementFrequency = .every2Minutes
        }
        
        // Load toggle settings or set defaults
        isVoiceGuidanceEnabled = UserDefaults.standard.bool(forKey: "isVoiceGuidanceEnabled") 
        
        // FORCE ENABLE for testing
        isVoiceGuidanceEnabled = true
        
        includePaceGuidance = UserDefaults.standard.bool(forKey: "includePaceGuidance")
        includeHeartRateGuidance = UserDefaults.standard.bool(forKey: "includeHeartRateGuidance")
        includeNavigationGuidance = UserDefaults.standard.bool(forKey: "includeNavigationGuidance")
        
        // Ensure all guidance types are enabled for testing
        includePaceGuidance = true
        includeHeartRateGuidance = true
        includeNavigationGuidance = true
        
        // Load volume setting
        voiceGuidanceVolume = UserDefaults.standard.float(forKey: "voiceGuidanceVolume")
        
        // Set to full volume if not set
        if voiceGuidanceVolume <= 0 {
            voiceGuidanceVolume = 1.0
        }
        
        print("⚙️ Voice guidance settings loaded: enabled=\(isVoiceGuidanceEnabled), level=\(voiceGuidanceLevel), frequency=\(announcementFrequency)")
        
        // Save these forced settings back to UserDefaults for persistence
        UserDefaults.standard.set(true, forKey: "isVoiceGuidanceEnabled")
        UserDefaults.standard.set(voiceGuidanceLevel.rawValue, forKey: "voiceGuidanceLevel")
        UserDefaults.standard.set(announcementFrequency.rawValue, forKey: "announcementFrequency")
        UserDefaults.standard.set(1.0, forKey: "voiceGuidanceVolume")
        UserDefaults.standard.set(true, forKey: "includePaceGuidance")
        UserDefaults.standard.set(true, forKey: "includeHeartRateGuidance")
        UserDefaults.standard.set(true, forKey: "includeNavigationGuidance")
    }
    
    // Add this method
    public func setupMapView() {
        // Configure map view
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        
        // Explicitly set the delegate and verify
        mapView.delegate = self
        print("🗺️ Map delegate set: \(String(describing: mapView.delegate))")
        
        // Change map type to satellite for better contrast with path lines
        mapView.mapType = .satellite
        
        // Set up map style based on run type
        setupMapStyleForRunType()
        
        // Center map on user location if available
        if let location = locationManager.location {
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 500, // Closer zoom to see details better
                longitudinalMeters: 500
            )
            mapView.setRegion(region, animated: false)
        }
        
        // Add planned route if available
        if let route = preSelectedRoute {
            loadPreSelectedRoute(route: route)
        } else if !routePlanner.routePolyline.isEmpty {
            addPlannedRouteToMap()
        }
        
        // Log for debugging
        print("🗺️ Map view set up complete with map type: \(mapView.mapType.rawValue)")
    }
    
    // Add a timer specifically for voice announcements
    public func setupVoiceAnnouncementTimer() {
        // Create a timer that fires every 10 seconds to check for announcements
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self, 
                  self.isVoiceGuidanceEnabled, 
                  self.runEngine.runState == .running,
                  !self.isPaused else { return }
            
            self.checkForVoiceAnnouncement(at: self.runEngine.elapsedTime)
        }
       
            // Add pace feedback timer (every 2 minutes)
        Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isRunning && !self.isPaused {
                self.providePaceFeedback()
            }
        }
    }
    

    
    // Add property to track if we've done the test announcement
    public var announcementDone = false
    // Add the showStatisticsView property to the OutdoorRunViewController class
    @Published var showStatisticsViewFlag: Bool = true

    // MARK: - Update UI methods
    public func updateStatusDisplay() {
        // Update main UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Configure the tracker view if needed
            if self.trackerView == nil {
                self.setupTrackerView()
            }
            
            // Ensure metrics are visible when running
            if self.runEngine.runState != .notStarted {
                // Force statistic view to be shown
                self.showStatisticsViewFlag = true
                
                // Update tracker view to reflect this
                if let hostingController = self.hostingController {
                    hostingController.rootView = OutdoorRunTrackerView(
                        viewModel: self,
                        mapView: self.mapView
                    )
                }
            }
            
            // Update UI elements
            self.updateButtons()
            
            // Force SwiftUI metrics cards to refresh
            NotificationCenter.default.post(name: NSNotification.Name("MetricsDidUpdate"), object: nil)
        }
    }

    public func setupTrackerView() {
        // Create the SwiftUI view for the tracker
        let trackerView = OutdoorRunTrackerView(
            viewModel: self,
            mapView: self.mapView
        )
        
        // Create a hosting controller for the SwiftUI view
        self.hostingController = UIHostingController(rootView: trackerView)
        
        // Important: Add the hosting controller as a child view controller first
        hostingController?.willMove(toParent: self)
        addChild(hostingController!)
        
        self.trackerView = hostingController?.view
        
        if let trackerView = self.trackerView {
            // Configure the tracker view
            trackerView.translatesAutoresizingMaskIntoConstraints = false
            trackerView.backgroundColor = .clear
            
            // Add the tracker view to the view hierarchy
            view.addSubview(trackerView)
            
            // Setup constraints for the tracker view
            NSLayoutConstraint.activate([
                trackerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                trackerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                trackerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                trackerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
            // Complete the child view controller flow
            hostingController?.didMove(toParent: self)
        }
        
        // Setup notification observer for metrics updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMetricsUpdate),
            name: NSNotification.Name("MetricsDidUpdate"),
            object: nil
        )
    }

    @objc public func handleMetricsUpdate() {
        // Force SwiftUI to redraw metrics cards with the latest data
        if let hostingController = self.hostingController {
            // Recreate the view to force an update
            hostingController.rootView = OutdoorRunTrackerView(
                viewModel: self,
                mapView: self.mapView
            )
        }
        
        // If metrics have changed, notify the watch
        if runEngine.runState != .notStarted {
            sendTrackingStatusToWatch()
        }
    }

    // MARK: - Public Methods
    
    // MARK: - Run History Analysis
    public func populateRecentRunHistory() {
        // Check if we already have cached data
        if ![].isEmpty || ![].isEmpty {
            print("📊 Using cached run history")
            analyzeRunHistory()
            return
        }
        
        // Use your existing pattern to fetch run history
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let dispatchGroup = DispatchGroup()
            
            // Fetch outdoor runs using your existing method
            dispatchGroup.enter()
            self?.getRunningLogs { (runs, error) in
                defer { dispatchGroup.leave() }
                if let error = error {
                    print("Error fetching outdoor runs for pace analysis: \(error.localizedDescription)")
                }
                // runs are automatically cached in [] by getRunningLogs
            }
            
            // Fetch indoor runs using your existing method
            dispatchGroup.enter()
            self?.getTreadmillLogs { (runs, error) in
                defer { dispatchGroup.leave() }
                if let error = error {
                    print("Error fetching indoor runs for pace analysis: \(error.localizedDescription)")
                }
                // runs are automatically cached in [] by getTreadmillLogs
            }
            
            dispatchGroup.notify(queue: .main) {
                self?.analyzeRunHistory()
            }
        }
    }
    
    public func analyzeRunHistory() {
        let outdoorLogs: [RunLog] = []
        let indoorLogs: [IndoorRunLog] = []
        
        // Filter for same run type and recent runs (last 90 days)
        let calendar = Calendar.current
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        
        var relevantLogs: [RunLog] = []
        
        // Filter outdoor runs based on run type
        if runType != .treadmillRun {
            let filteredOutdoor = outdoorLogs.filter { log in
                guard let createdAt = log.createdAt, createdAt >= ninetyDaysAgo else { return false }
                // Add additional filtering based on run type if needed
                return true
            }
            relevantLogs.append(contentsOf: filteredOutdoor)
        }
        
        // Include indoor runs for treadmill run type
        if runType == .treadmillRun {
            let filteredIndoor = indoorLogs.filter { log in
                guard let createdAt = log.createdAt, createdAt >= ninetyDaysAgo else { return false }
                return true
            }
            // IndoorRunLog is a type alias for RunLog, so we can append directly
            relevantLogs.append(contentsOf: filteredIndoor)
        }
        
        guard !relevantLogs.isEmpty else {
            print("📊 No recent run history available for pace analysis")
            return
        }
        
        // Extract valid paces from your RunLog/IndoorRunLog objects
        var validPaces: [Double] = []
        
        for log in relevantLogs {
            if let runLog = log as? RunLog,
               let avgPaceString = runLog.avgPace,
               let distanceString = runLog.distance,
               let pace = parsePaceString(avgPaceString),
               let distance = parseDistanceString(distanceString),
               distance > 1.0 { // Only runs longer than 1 mile/km
                validPaces.append(pace)
            } else if let indoorLog = log as? IndoorRunLog,
                      let avgPaceString = indoorLog.avgPace,
                      let distanceString = indoorLog.distance,
                      let pace = parsePaceString(avgPaceString),
                      let distance = parseDistanceString(distanceString),
                      distance > 1.0 {
                validPaces.append(pace)
            }
        }
        
        if !validPaces.isEmpty {
            // Sort by most recent first (assuming paces array is in chronological order)
            let averagePace = validPaces.reduce(0, +) / Double(validPaces.count)
            let recentPaces = Array(validPaces.prefix(3))
            let recentPace = recentPaces.reduce(0, +) / Double(recentPaces.count)
            
            // Set ideal pace as weighted average (70% recent, 30% overall)
            let idealPace = (recentPace * 0.7) + (averagePace * 0.3)
            
            DispatchQueue.main.async { [weak self] in
                self?.targetPace = idealPace
                print("📊 Set ideal pace from history: \(idealPace) sec/mile from \(validPaces.count) runs")
            }
        }
        
        // Store run patterns for context
        self.historicalPaces = validPaces
        print("📊 Loaded \(validPaces.count) historical pace records")
    }
    
    // Enhanced pace feedback with context
    public func providePaceFeedback() {
        guard let targetPace = targetPace, targetPace > 0 else { return }
        
        let currentPace = runEngine.pace.value
        let paceDifference = currentPace - targetPace
        let pacePercentage = abs(paceDifference) / targetPace
        
        // Only provide feedback if significantly off pace (>10%)
        guard pacePercentage > 0.1 else { return }
        
        let now = Date()
        guard lastPaceAnnouncement == nil || now.timeIntervalSince(lastPaceAnnouncement!) > paceAnnouncementCooldown else { return }
        
        var feedback = ""
        if paceDifference > 0 {
            feedback = pacePercentage > 0.2 ? "You're running slower than your recent pace. Consider picking up the pace." : "You're slightly behind your usual pace."
        } else {
            feedback = pacePercentage > 0.2 ? "You're running faster than usual. Make sure you can maintain this pace." : "You're running slightly faster than your recent pace."
        }
        
        announceMessage(feedback)
        lastPaceAnnouncement = now
    }

    // Helper methods to parse your string formats
    public func parsePaceString(_ paceString: String) -> Double? {
        // Handle formats like "8:45" (minutes:seconds per mile/km)
        let components = paceString.split(separator: ":")
        guard components.count == 2,
              let minutes = Double(components[0]),
              let seconds = Double(components[1]) else {
            return nil
        }
        return (minutes * 60) + seconds // Convert to total seconds
    }

    public func parseDistanceString(_ distanceString: String) -> Double? {
        // Remove any non-numeric characters except decimal point
        let cleanedString = distanceString.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        return Double(cleanedString)
    }

    // Add the showSummary method
       func showSummary() {
           // Prevent multiple presentations
           guard !summaryShown else {
               print("🏁 Summary already shown, preventing duplicate")
               return
           }
           
           // Check if already presenting a view controller
           if presentedViewController != nil {
               print("🏁 Already presenting a view controller, preventing duplicate summary")
               return
           }
           
           summaryShown = true
           
           // Generate run log
           let runLog = runEngine.generateRunLog()
           
           // Dismiss back to ModernRunTrackerViewController first
           dismiss(animated: true) { [weak self] in
               // Notify delegate to show summary
               self?.delegate?.outdoorRunDidComplete(with: runLog)
           }
       }
       
       // Update dismissTracking method
       func dismissTracking() {
           if isRunning && !hasCompletedRun {
               // Show confirmation alert
               let alert = UIAlertController(
                   title: "End Workout?",
                   message: "Do you want to end your current workout?",
                   preferredStyle: .alert
               )
               
               alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
               alert.addAction(UIAlertAction(title: "End Workout", style: .destructive) { [weak self] _ in
                   self?.runEngine.endRun()
                   self?.dismiss(animated: true) { [weak self] in
                       self?.delegate?.outdoorRunWasCanceled()
                   }
               })
               
               present(alert, animated: true)
           } else {
               dismiss(animated: true) { [weak self] in
                   self?.delegate?.outdoorRunWasCanceled()
               }
           }
       }

    // Add the showStatisticsView method
    func showStatisticsView() {
        showStatisticsViewFlag = true
        
        // Update the UI to reflect this change
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Force metrics panel to be visible
            self.isShowingMetricsPanel = true
            
            // Notify the UI to update
            NotificationCenter.default.post(name: NSNotification.Name("MetricsDidUpdate"), object: nil)
            
            // Update tracker view to reflect changes
            if let hostingController = self.hostingController {
                hostingController.rootView = OutdoorRunTrackerView(
                    viewModel: self,
                    mapView: self.mapView
                )
            }
        }
    }

    // Add the updateButtons method
    public func updateButtons() {
        // Update the UI buttons based on the current run state
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch self.runEngine.runState {
            case .notStarted:
                self.isRunning = false
                self.isPaused = false
                
            case .running:
                self.isRunning = true
                self.isPaused = false
                
            case .paused:
                self.isRunning = false
                self.isPaused = true
                
            case .completed:
                self.isRunning = false
                self.isPaused = false
                self.hasCompletedRun = true
                
                // **CRITICAL FIX**: Only show summary ONCE using a flag
                if !self.announcementDone && !self.summaryShown {
                    self.announcementDone = true
                    self.summaryShown = true  // Add this new flag
                    
                    print("🏁 Run completed - showing summary (ONCE)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.showSummary()
                    }
                } else if self.summaryShown {
                    print("🏁 Summary already shown, skipping duplicate")
                }
            }
            
            // Notify the UI to update with the new state
            NotificationCenter.default.post(name: NSNotification.Name("RunStateDidChange"), object: nil)
            
            // Sync with watch
            self.sendTrackingStatusToWatch()
        }
    }

    // MARK: - Properties
    
    // History arrays for tracking and graphing
    public var cadenceHistory: [Double] = []
    // Add this property near the other flags (around line 5454)
    public var summaryShown = false
    
    // MARK: - UI Update Methods
    
    public func updateCadenceDisplay() {
        // This method will update any UI elements that display cadence
        // The main update happens through SwiftUI binding to the RunTrackingEngine
        
        // If you have any additional UI elements to update, do it here
        DispatchQueue.main.async { [weak self] in
            // Example: Update a label with the current cadence
            guard let self = self else { return }
            
            // Log for debugging
            if self.runEngine.cadence > 0 {
                print("📱 Updated cadence display: \(self.runEngine.cadence) spm")
            }
        }
    }
    
    // MARK: - Setup Methods
    
    public func setupRoutePlanner() {
        print("⚙️ Setting up route planner...")
        
        // Initialize or configure route planner properties if needed
        // Note: routePlanner is already initialized with RoutePlanner.shared in properties
        
        // Load any saved routes or configurations if necessary
        if let savedRoutes = UserDefaults.standard.data(forKey: "savedRoutes") {
            // Process saved routes data if needed
            print("Found saved routes data")
        }
        
        // Register for route plan notifications if needed
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRoutePlanUpdate(_:)),
            name: .didUpdateRoutePlan,
            object: nil
        )
        
        print("⚙️ Route planner setup complete")
    }
    
    @objc public func handleRoutePlanUpdate(_ notification: Notification) {
        // Handle route plan updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("Route plan was updated, refreshing map")
            self.refreshMapWithCurrentRoute()
        }
    }
    
    // Enhanced audio setup around line 4490
    public func setupAudioServices() {
        // Use enhanced audio configuration for realistic speech
        configureAudioSessionForRealisticSpeech()
        
        // Set up speech synthesizer with optimal settings
        speechSynthesizer.delegate = self
        speechSynthesizer.usesApplicationAudioSession = true
        
        // Initialize with the best available neural voice
        initializePremiumVoices()
        
        print("🔊 Enhanced speech services initialized")
    }



    public func preloadVoices() {
        DispatchQueue.global(qos: .utility).async {
            // Preload all available high-quality voices to reduce speech latency
            let voiceTypes = UserPreferences.VoiceType.allCases
            for voiceType in voiceTypes {
                _ = voiceType.bestAvailableVoice
            }
            
            DispatchQueue.main.async {
                print("🔊 Voice preloading completed")
            }
        }
    }
    
    public func setupAudioInterruptionHandling() {
        // Set up notification observer for audio session interruptions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )
    }
    
    @objc public func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .began {
            // Interruption began, handle accordingly
            print("Audio session interrupted")
        } else if type == .ended {
            // Interruption ended, resume audio if needed
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Resume audio playback if needed
                    audioPlayer?.play()
                }
            }
        }
    }

    // MARK: - Map Update Methods
    
    public func refreshMapWithCurrentRoute() {
        print("🗺️ Refreshing map with current route")
        
        // Remove existing route overlays and annotations
        clearRouteFromMap()
        
        // Add the updated route to the map
        if !routePlanner.routePolyline.isEmpty {
            // Create a polyline from the route coordinates
            let polyline = MKPolyline(coordinates: routePlanner.routePolyline, count: routePlanner.routePolyline.count)
            mapView.addOverlay(polyline, level: .aboveRoads)
            
            // Add annotations for start, end and waypoints
            for annotation in routePlanner.routeAnnotations {
                // Convert RouteAnnotation to RouteAnnotationMK before adding to map
                let mkAnnotation = RouteAnnotationMK(annotation: annotation)
                mapView.addAnnotation(mkAnnotation)
            }
            
            // If no annotations were provided, create basic start/end annotations
            if routePlanner.routeAnnotations.isEmpty, routePlanner.routePolyline.count >= 2 {
                let startCoord = routePlanner.routePolyline.first!
                let endCoord = routePlanner.routePolyline.last!
                
                let startAnnotation = RouteAnnotationMK(coordinate: startCoord, type: .start, title: "Start")
                let endAnnotation = RouteAnnotationMK(coordinate: endCoord, type: .end, title: "Finish")
                
                mapView.addAnnotation(startAnnotation)
                mapView.addAnnotation(endAnnotation)
            }
            
            // Zoom to show the entire route
            let region = regionForRoute(routePlanner.routePolyline)
            mapView.setRegion(region, animated: true)
        }
    }
    
    public func clearRouteFromMap() {
        // Remove all overlays (routes)
        let overlays = mapView.overlays
        mapView.removeOverlays(overlays)
        
        // Remove route-related annotations but keep user location
        let annotations = mapView.annotations.filter { annotation in
            // Keep user location annotation
            if annotation is MKUserLocation {
                return false
            }
            
            // Remove route annotations
            if let routeAnnotation = annotation as? RouteAnnotationMK {
                return true
            }
            
            return false
        }
        
        mapView.removeAnnotations(annotations)
    }
    
    public func regionForRoute(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            // Default region if no coordinates
            return MKCoordinateRegion(
                center: mapView.userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        // Calculate the bounding box
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        
        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        
        // Create a region with padding
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        // Add 15% padding to the span
        let latDelta = (maxLat - minLat) * 1.15
        let lonDelta = (maxLon - minLon) * 1.15
        
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.005), longitudeDelta: max(lonDelta, 0.005))
        )
    }

    // MARK: - Heart Rate Monitoring
    public func updateHeartRateDisplay() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Log heart rate updates for debugging
            if self.runEngine.heartRate > 0 {
                print("❤️ Heart rate updated: \(Int(self.runEngine.heartRate)) bpm")
            }
            
            // 🔧 FIX: Remove notification posting to prevent circular updates
            // REMOVED: NotificationCenter.default.post(name: .didReceiveHeartRateUpdate, ...)
            
            // Update heart rate zone calculation if needed
            self.updateHeartRateZone()
        }
    }
    
    public func updateHeartRateZone() {
        // Calculate heart rate zone based on max heart rate (simple formula: 220 - age)
        // For now, use a default age of 30 if not available
        let userAge = UserDefaults.standard.integer(forKey: "userAge") 
        let defaultAge = 30
        let age = userAge > 0 ? userAge : defaultAge
        
        let maxHeartRate = 220 - age
        let currentHeartRate = runEngine.heartRate
        
        // Calculate heart rate as percentage of max
        let hrPercentage = currentHeartRate / Double(maxHeartRate)
        
        // Determine zone based on percentage
        var zone = 0
        if hrPercentage < 0.6 {
            zone = 1      // Recovery: <60% of max HR
        } else if hrPercentage < 0.7 {
            zone = 2      // Aerobic: 60-70% of max HR
        } else if hrPercentage < 0.8 {
            zone = 3      // Endurance: 70-80% of max HR
        } else if hrPercentage < 0.9 {
            zone = 4      // Threshold: 80-90% of max HR
        } else {
            zone = 5      // Anaerobic: >90% of max HR
        }
        
        // Store the current zone for UI display or coaching
        currentHeartRateZone = zone
    }

    // Add a custom annotation for the current runner position
    public func updateRunnerAnnotation(at location: CLLocation) {
        // Remove existing current position annotation if it exists
        if let existingAnnotation = currentPositionAnnotation {
            mapView.removeAnnotation(existingAnnotation)
        }
        
        // Create a new annotation for the current position
        let annotation = MKPointAnnotation()
        annotation.coordinate = location.coordinate
        annotation.title = "Current"
        
        // Store reference and add to map
        currentPositionAnnotation = annotation
        mapView.addAnnotation(annotation)
    }

    // Make sure to add the property at the top of the class:
    // Properties for map path drawing
    public var currentPositionAnnotation: MKPointAnnotation?
    
    // Add timer properties
    public var uiTimer: Timer?
    public var lastSyncTime: Date?
    public var lastEngineTime: TimeInterval = 0
    public var timeBasePoint: Date = Date()
    public let syncInterval: TimeInterval = 3.0 // Sync with engine every 3 seconds
    public let timeIncrement: TimeInterval = 0.1 // How much to increment per timer tick
    public var targetTime: TimeInterval = 0 // Target time we're interpolating toward
    
    // Add properties to track external time updates and smoothly transition between them
    public var isTransitioningTime = false
    public var transitionStartTime: Date?
    public var transitionStartValue: TimeInterval = 0
    public var transitionTargetValue: TimeInterval = 0
    public let transitionDuration: TimeInterval = 1.0  // 1 second transition
    
    public func setupUITimer() {
        // Initial sync with engine
        syncTimeWithEngine(forceSync: true)
    }
    
    public func startUITimer() {
        // Cancel any existing timer
        uiTimer?.invalidate()
        
        // Set initial time values
        syncTimeWithEngine(forceSync: true)
        
        // Start UI timer that updates every 0.1 seconds for smooth display
        uiTimer = Timer(timeInterval: timeIncrement, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // If we're in a transition (handling external time update)
            if self.isTransitioningTime, let startTime = self.transitionStartTime {
                let elapsedTransition = Date().timeIntervalSince(startTime)
                
                // Calculate progress (0.0 to 1.0)
                let progress = min(elapsedTransition / self.transitionDuration, 1.0)
                
                if progress < 1.0 {
                    // Apply easing function (cubic ease-in-out) for smooth transition
                    let easedProgress = progress < 0.5 ?
                        4 * progress * progress * progress :
                        1 - pow(-2 * progress + 2, 3) / 2
                    
                    // Interpolate between start and target values
                    self.displayElapsedTime = self.transitionStartValue + 
                        (self.transitionTargetValue - self.transitionStartValue) * easedProgress
                } else {
                    // Transition complete
                    self.displayElapsedTime = self.transitionTargetValue
                    self.isTransitioningTime = false
                    print("⏱️ Time transition complete: \(String(format: "%.2f", self.displayElapsedTime))")
                }
                
                // Update UI
                DispatchQueue.main.async {
                    self.updateTimeDisplay()
                }
                return
            }
            
            // Normal time update logic when not transitioning
            if self.runEngine.runState == .running {
                // Use a consistent increment approach
                self.displayElapsedTime += self.timeIncrement
                
                // If we've drifted too far from engine time, gradually adjust
                if self.lastSyncTime != nil {
                    let timeSinceLastSync = Date().timeIntervalSince(self.timeBasePoint)
                    let projectedEngineTime = self.lastEngineTime + timeSinceLastSync
                    
                    // If drift is more than 0.2 seconds, adjust gradually
                    let drift = projectedEngineTime - self.displayElapsedTime
                    if abs(drift) > 0.2 {
                        // Apply 10% correction per tick to smooth the adjustment
                        self.displayElapsedTime += drift * 0.1
                    }
                    
                    // Force a sync periodically
                    if timeSinceLastSync >= self.syncInterval {
                        self.syncTimeWithEngine(forceSync: false)
                    }
                }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.updateTimeDisplay()
                }
            }
        }
        
        // Add timer to all necessary run loops for reliability
        RunLoop.main.add(uiTimer!, forMode: .common)
        RunLoop.main.add(uiTimer!, forMode: .tracking)
        print("🕒 UI Timer started for smooth elapsed time display")
    }
    
    public func pauseUITimer() {
        // Store the current time when pausing
        let pauseTime = Date()
        
        // Invalidate timer but keep the time values
        uiTimer?.invalidate()
        uiTimer = nil
        
        // Force a sync before pausing to ensure accurate time
        syncTimeWithEngine(forceSync: true)
        
        print("🕒 UI Timer paused at \(String(format: "%.2f", displayElapsedTime))s")
    }
    
    public func resumeUITimer() {
        // Sync with engine before resuming
        syncTimeWithEngine(forceSync: true)
        
        // Reset time base point to now
        timeBasePoint = Date()
        
        // Restart the timer
        startUITimer()
        
        print("🕒 UI Timer resumed at \(String(format: "%.2f", displayElapsedTime))s")
    }
    
    public func stopUITimer() {
        uiTimer?.invalidate()
        uiTimer = nil
        displayElapsedTime = 0
        lastSyncTime = nil
        print("🕒 UI Timer stopped")
    }
    
    public func syncTimeWithEngine(forceSync: Bool = false, fromExternal: Bool = false) {
        // Get the authoritative time from the engine
        let engineTime = self.runEngine.elapsedTime
        
        // If this is from an external source (like watch sync) with a large jump
        if fromExternal && abs(engineTime - displayElapsedTime) > 2.0 {
            // Start a smooth transition
            self.isTransitioningTime = true
            self.transitionStartTime = Date()
            self.transitionStartValue = displayElapsedTime
            self.transitionTargetValue = engineTime
            
            // Log the transition
            print("⏱️ Starting smooth transition from \(String(format: "%.2f", displayElapsedTime)) to \(String(format: "%.2f", engineTime)) over \(transitionDuration)s")
            
            // Still update base time for calculations
            self.timeBasePoint = Date()
            self.lastEngineTime = engineTime
            self.lastSyncTime = Date()
            return
        }
        
        // Normal sync logic for internal updates or small external changes
        if forceSync || abs(engineTime - lastEngineTime) > 0.05 {
            // Store sync point for interpolation
            self.timeBasePoint = Date()
            self.lastEngineTime = engineTime
            
            // If forced sync or large drift, update display time directly
            if forceSync || abs(engineTime - displayElapsedTime) > 1.0 {
                self.displayElapsedTime = engineTime
                print("⏱️ Forced sync: display time = \(String(format: "%.2f", displayElapsedTime))")
            }
            
            self.lastSyncTime = Date()
            print("⏱️ Synced UI time with engine: \(String(format: "%.2f", engineTime))")
        }
    }
    

    
    // Add a property for formatted time that SwiftUI can access
    @Published var formattedElapsedTime: String = "00:00"
    
    // Add a getter for elapsed time that SwiftUI can access
    var elapsedTime: TimeInterval {
        return displayElapsedTime
    }
    
    // Add this method to show toast messages
    public func showToast(message: String) {
        // Create a toast view
        let toastView = UIView()
        toastView.backgroundColor = UIColor(hex: "#212A3E").withAlphaComponent(0.9)
        toastView.layer.cornerRadius = 8
        toastView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add message label
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textColor = .white
        messageLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.textAlignment = .center
        
        // Add to view hierarchy
        toastView.addSubview(messageLabel)
        view.addSubview(toastView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: toastView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: toastView.trailingAnchor, constant: -16),
            messageLabel.topAnchor.constraint(equalTo: toastView.topAnchor, constant: 8),
            messageLabel.bottomAnchor.constraint(equalTo: toastView.bottomAnchor, constant: -8),
            
            toastView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            toastView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -32)
        ])
        
        // Animate in
        toastView.alpha = 0
        UIView.animate(withDuration: 0.3, animations: {
            toastView.alpha = 1
        }) { _ in
            // Animate out after delay
            UIView.animate(withDuration: 0.3, delay: 2.0, options: [], animations: {
                toastView.alpha = 0
            }) { _ in
                toastView.removeFromSuperview()
            }
        }
    }

    // Add safety properties for watch communication
    public var lastWatchErrorTime: TimeInterval = 0 
    public let minimumRetryInterval: TimeInterval = 5.0 // Don't retry failed watch communication for at least 5 seconds

    public func sendTrackingStatusToWatch() {
        // Skip if we've had a recent error to avoid blocking UI
        let currentTime = Date().timeIntervalSince1970
        if currentTime - lastWatchErrorTime < minimumRetryInterval {
            // Skip this update attempt if we've had a recent failure
            return
        }
        
        // Check if we need to throttle updates
        if currentTime - lastWatchUpdateTime < watchCommunicationInterval {
            // Skip update if we've sent one recently (within the communication interval)
            return
        }
        
        // Update the last update time
        lastWatchUpdateTime = currentTime
        
        // Check for WCSession activation
        guard WCSession.default.activationState == .activated else {
            print("📱 Cannot send tracking status: WCSession not activated")
            return
        }
        
        // Skip if watch is not reachable to avoid blocks
        if !WCSession.default.isReachable {
            print("📱 Watch not reachable - skipping update")
            // Notify run engine about unreachable state
            runEngine.handleWatchCommunicationError(
                NSError(domain: "com.do.runtracking", 
                        code: 1, 
                        userInfo: [NSLocalizedDescriptionKey: "Watch not reachable"])
            )
            return
        }
        
        // CRITICAL FIX: Check if metrics are properly initialized before sending
        // During handoff scenarios, don't send metrics until they're synchronized
        let hasValidMetrics = runEngine.elapsedTime > 0 || runEngine.distance.value > 0 || runEngine.runState == .running
        
        if !hasValidMetrics && runEngine.runState == .notStarted {
            print("📱 Skipping tracking status - metrics not yet initialized (elapsedTime: \(runEngine.elapsedTime), distance: \(runEngine.distance.value), state: \(runEngine.runState.rawValue))")
            return
        }
        
        // Create a compact metrics package with only essential data
        let metrics: [String: Any] = [
            "distance": runEngine.distance.value,
            "pace": runEngine.pace.value,
            "elapsedTime": runEngine.elapsedTime,
            "calories": runEngine.calories,
            "heartRate": runEngine.heartRate,
            "cadence": runEngine.cadence,
            "timestamp": currentTime
        ]
        
        // Create status message with workout state
        let status: [String: Any] = [
            "type": "trackingStatus",
            "runState": runEngine.runState.rawValue,
            "state": runEngine.runState == .running ? "inProgress" : runEngine.runState.rawValue,
            "metrics": metrics,
            "workoutActive": runEngine.runState == .running || runEngine.runState == .paused,
            "isIndoor": runEngine.isIndoorMode,
            "watchTracking": runEngine.isWatchTracking,
            "useImperialUnits": !UserPreferences.shared.useMetricSystem
        ]
        
        print("📱 Sending status to watch: state=\(runEngine.runState.rawValue), time=\(runEngine.elapsedTime)s, distance=\(runEngine.distance.value)m")
        
        // Use non-blocking communication with a safer approach
        DispatchQueue.global(qos: .utility).async {
            // Use an atomic flag to prevent multiple completions
            let operationCompleted = AtomicFlag()
            
            // Create a timeout timer with increased duration (1.0 second instead of 0.5)
            var timeoutTimer: Timer? = nil
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                // Only execute if this is the first completion
                if operationCompleted.testAndSet() {
                    print("⚠️ Watch communication timed out")
                    DispatchQueue.main.async {
                        self?.lastWatchErrorTime = Date().timeIntervalSince1970
                        // TODO: Consider notifying RunTrackingEngine about the timeout
                        // by calling: self?.runEngine.handleWatchCommunicationError()
                    }
                }
            }
            
            // Send the message
            WCSession.default.sendMessage(status, replyHandler: { [weak self] _ in
                // Only execute if this is the first completion
                if operationCompleted.testAndSet() {
                    // Success - cancel timeout
                    timeoutTimer?.invalidate()
                    print("📱 Watch acknowledged status update")
                }
            }, errorHandler: { [weak self] error in
                // Only execute if this is the first completion
                if operationCompleted.testAndSet() {
                    // Error - cancel timeout
                    timeoutTimer?.invalidate()
                    
                    // Record the error time on main thread
                    DispatchQueue.main.async {
                        self?.lastWatchErrorTime = Date().timeIntervalSince1970
                        print("⚠️ Error sending workout update to watch: \(error.localizedDescription)")
                    }
                }
            })
            
            // Let the runloop process the timer with increased duration (1.2 seconds instead of 0.6)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.2))
        }
        
        // Don't block the main thread - continue with UI updates regardless of watch status
    }
    
    
    // MARK: - Simplified Timer Methods

    /**
     * Sets up the simplified timer with the actual workout start date
     * - Parameter startDate: The actual start date from the watch or local start
     */
    public func setupSimplifiedTimer(startDate: Date) {
        self.workoutStartDate = startDate
        
        // Calculate initial elapsed time from the actual start date
        self.displayElapsedTime = Date().timeIntervalSince(startDate)
        
        // Update display immediately
        updateTimeDisplay()
        
        // Start simple 1-second timer
        startSimpleTimer()
        
        print("🕒 Simplified timer setup with start date: \(startDate), initial elapsed: \(String(format: "%.1f", displayElapsedTime))s")
    }

    /**
     * Starts the simple timer that increments elapsed time every second
     */
    public func startSimpleTimer() {
        // Cancel any existing timer
        simpleTimer?.invalidate()
        
        // Create new timer that fires every second
        simpleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Only increment when running
            if self.runEngine.runState == .running {
                self.displayElapsedTime += 1.0
                
                // Update display on main thread
                DispatchQueue.main.async {
                    self.updateTimeDisplay()
                }
            }
            // When paused, don't increment but keep timer running for potential resume
        }
        
        // Add to run loop for reliability
        if let timer = simpleTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        print("🕒 Simple timer started")
    }

    /**
     * Stops the simple timer and resets elapsed time
     */
    public func stopSimpleTimer() {
        simpleTimer?.invalidate()
        simpleTimer = nil
        displayElapsedTime = 0
        workoutStartDate = nil
        print("🕒 Simple timer stopped")
    }

    /**
     * Updates the formatted time display for the UI
     */
    public func updateTimeDisplay() {
        // Format time for display
        let hours = Int(displayElapsedTime) / 3600
        let minutes = (Int(displayElapsedTime) % 3600) / 60
        let seconds = Int(displayElapsedTime) % 60
        
        // Create formatted time string
        let formattedTime: String
        if hours > 0 {
            formattedTime = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            formattedTime = String(format: "%02d:%02d", minutes, seconds)
        }
        
        // Only update if the formatted time has changed
        if formattedTime != self.formattedElapsedTime {
            // Store for SwiftUI view access
            self.formattedElapsedTime = formattedTime
            
            // Force SwiftUI to update
            objectWillChange.send()
        }
    }
    
    // MARK: - Run Control Methods
    
    func pauseRun() {
        print("📱 🔴 PAUSE: Starting pause process")
        
        // CRITICAL: Pause the phone immediately regardless of watch connectivity
        // This ensures the phone stops tracking even if watch communication fails
        
        // Call engine's pauseRun first
        runEngine.pauseRun()
        
        // Stop the view controller's location manager immediately
        locationManager.stopUpdatingLocation()
        print("📱 🔴 PAUSE: Stopped phone location manager")
        
        // Stop the simplified timer immediately
        stopSimpleTimer()
        print("📱 🔴 PAUSE: Stopped simplified timer")
        
        // Update UI state immediately
        isRunning = false
        isPaused = true
        updateStatusDisplay()
        print("📱 🔴 PAUSE: Updated UI state")
        
        // Try to notify watch, but don't block if it fails
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            let session = WCSession.default
            if session.activationState == .activated && session.isPaired {
                // Create pause command
                let pauseCommand: [String: Any] = [
                    "type": "outdoorRunStateChange",
                    "command": "paused",
                    "isIndoor": false,
                    "timestamp": Date().timeIntervalSince1970,
                    "workoutId": self.runEngine.workoutId.uuidString
                ]
                
                print("📱 🔴 PAUSE: Attempting to notify watch")
                
                if session.isReachable {
                    // Try immediate message with short timeout
                    session.sendMessage(pauseCommand, replyHandler: { response in
                        print("📱 🔴 PAUSE: Watch acknowledged pause")
                    }, errorHandler: { error in
                        print("📱 🔴 PAUSE: Watch message failed: \(error.localizedDescription)")
                        // Fallback to application context
                        try? session.updateApplicationContext(pauseCommand)
                        print("📱 🔴 PAUSE: Sent via application context as fallback")
                    })
                } else {
                    print("📱 🔴 PAUSE: Watch not reachable, using application context")
                    try? session.updateApplicationContext(pauseCommand)
                }
            } else {
                print("📱 🔴 PAUSE: Watch not available (activation: \(session.activationState.rawValue), paired: \(session.isPaired))")
            }
        }
        
        print("📱 🔴 PAUSE: Phone pause completed successfully")
    }
    
    func resumeRun() {
        print("📱 🟢 RESUME: Starting resume process")
        
        // CRITICAL: Resume the phone immediately regardless of watch connectivity
        // This ensures the phone starts tracking even if watch communication fails
        
        // Call engine's resumeRun first
        runEngine.resumeRun()
        
        // Restart the view controller's location manager immediately
        locationManager.startUpdatingLocation()
        print("📱 🟢 RESUME: Started phone location manager")
        
        // Restart the simplified timer immediately
        startSimpleTimer()
        print("📱 🟢 RESUME: Started simplified timer")
        
        // Update UI state immediately
        isRunning = true
        isPaused = false
        updateStatusDisplay()
        print("📱 🟢 RESUME: Updated UI state")
        
        // Try to notify watch, but don't block if it fails
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            let session = WCSession.default
            if session.activationState == .activated && session.isPaired {
                // Create resume command
                let resumeCommand: [String: Any] = [
                    "type": "outdoorRunStateChange",
                    "command": "inProgress",
                    "isIndoor": false,
                    "timestamp": Date().timeIntervalSince1970,
                    "workoutId": self.runEngine.workoutId.uuidString
                ]
                
                print("📱 🟢 RESUME: Attempting to notify watch")
                
                if session.isReachable {
                    // Try immediate message with short timeout
                    session.sendMessage(resumeCommand, replyHandler: { response in
                        print("📱 🟢 RESUME: Watch acknowledged resume")
                    }, errorHandler: { error in
                        print("📱 🟢 RESUME: Watch message failed: \(error.localizedDescription)")
                        // Fallback to application context
                        try? session.updateApplicationContext(resumeCommand)
                        print("📱 🟢 RESUME: Sent via application context as fallback")
                    })
                } else {
                    print("📱 🟢 RESUME: Watch not reachable, using application context")
                    try? session.updateApplicationContext(resumeCommand)
                }
            } else {
                print("📱 🟢 RESUME: Watch not available (activation: \(session.activationState.rawValue), paired: \(session.isPaired))")
            }
        }
        
        print("📱 🟢 RESUME: Phone resume completed successfully")
    }
    
    // MARK: - Screen Lock Functionality
    
    /// Toggle screen lock state
       func toggleScreenLock() {
           DispatchQueue.main.async { [weak self] in
               guard let self = self else { return }
               
               withAnimation(.easeInOut(duration: 0.3)) {
                   self.isScreenLocked.toggle()
               }
               
               // Provide haptic feedback
               let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
               impactGenerator.impactOccurred()
               
               // Update overlay immediately without waiting for binding
               if self.isScreenLocked {
                   self.showScreenLockOverlay()
               } else {
                   self.hideScreenLockOverlay()
               }
           }
       }
    
    /// Show screen lock overlay to prevent accidental touches
    public func showScreenLockOverlay() {
        // Remove existing overlay first
        hideScreenLockOverlay()
        
        // Create overlay view that covers the entire screen
        screenLockOverlay = UIView(frame: view.bounds)
        screenLockOverlay?.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        screenLockOverlay?.alpha = 0
        screenLockOverlay?.translatesAutoresizingMaskIntoConstraints = false
        
        // Add lock icon and instructions
        let lockContainer = UIView()
        lockContainer.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        lockContainer.layer.cornerRadius = 20
        lockContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let lockIcon = UIImageView(image: UIImage(systemName: "lock.fill"))
        lockIcon.tintColor = .white
        lockIcon.contentMode = .scaleAspectFit
        lockIcon.translatesAutoresizingMaskIntoConstraints = false
        
        let lockLabel = UILabel()
        lockLabel.text = "Screen Locked"
        lockLabel.textColor = .white
        lockLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        lockLabel.textAlignment = .center
        lockLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let instructionLabel = UILabel()
        instructionLabel.text = "Triple-tap to unlock"
        instructionLabel.textColor = .lightGray
        instructionLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        instructionLabel.textAlignment = .center
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        lockContainer.addSubview(lockIcon)
        lockContainer.addSubview(lockLabel)
        lockContainer.addSubview(instructionLabel)
        screenLockOverlay?.addSubview(lockContainer)
        
        // Add gesture recognizer for unlocking
        let tripleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTripleTap))
        tripleTapGesture.numberOfTapsRequired = 3
        screenLockOverlay?.addGestureRecognizer(tripleTapGesture)
        
        guard let overlay = screenLockOverlay else { return }
        view.addSubview(overlay)
        
        // Set up constraints with safe force unwrapping
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            lockContainer.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            lockContainer.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            lockContainer.widthAnchor.constraint(equalToConstant: 200),
            lockContainer.heightAnchor.constraint(equalToConstant: 120),
            
            lockIcon.centerXAnchor.constraint(equalTo: lockContainer.centerXAnchor),
            lockIcon.topAnchor.constraint(equalTo: lockContainer.topAnchor, constant: 15),
            lockIcon.widthAnchor.constraint(equalToConstant: 30),
            lockIcon.heightAnchor.constraint(equalToConstant: 30),
            
            lockLabel.centerXAnchor.constraint(equalTo: lockContainer.centerXAnchor),
            lockLabel.topAnchor.constraint(equalTo: lockIcon.bottomAnchor, constant: 10),
            lockLabel.leadingAnchor.constraint(equalTo: lockContainer.leadingAnchor, constant: 10),
            lockLabel.trailingAnchor.constraint(equalTo: lockContainer.trailingAnchor, constant: -10),
            
            instructionLabel.centerXAnchor.constraint(equalTo: lockContainer.centerXAnchor),
            instructionLabel.topAnchor.constraint(equalTo: lockLabel.bottomAnchor, constant: 5),
            instructionLabel.leadingAnchor.constraint(equalTo: lockContainer.leadingAnchor, constant: 10),
            instructionLabel.trailingAnchor.constraint(equalTo: lockContainer.trailingAnchor, constant: -10)
        ])
        
        // Animate overlay appearance
        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1
        }
        
        // Show brief instruction banner
        showLockInstructionBanner()
    }
    
    /// Hide screen lock overlay
    public func hideScreenLockOverlay() {
        guard let overlay = screenLockOverlay else { return }
        
        UIView.animate(withDuration: 0.3, animations: {
            overlay.alpha = 0
        }) { _ in
            overlay.removeFromSuperview()
            self.screenLockOverlay = nil
        }
    }
    
    /// Handle triple tap to unlock screen
    @objc public func handleTripleTap() {
        toggleScreenLock()
        
        // Show unlock confirmation
        let unlockLabel = UILabel()
        unlockLabel.text = "✓ Screen Unlocked"
        unlockLabel.textColor = UIColor(Color(hex: "#4ADEAA"))
        unlockLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        unlockLabel.textAlignment = .center
        unlockLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        unlockLabel.layer.cornerRadius = 8
        unlockLabel.clipsToBounds = true
        unlockLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(unlockLabel)
        
        NSLayoutConstraint.activate([
            unlockLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            unlockLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            unlockLabel.widthAnchor.constraint(equalToConstant: 160),
            unlockLabel.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        // Remove after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            unlockLabel.removeFromSuperview()
        }
    }
    
    /// Show lock instruction banner
    public func showLockInstructionBanner() {
        let banner = UILabel()
        banner.text = "🔒 Screen is now locked. Triple-tap to unlock."
        banner.textColor = .white
        banner.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        banner.textAlignment = .center
        banner.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        banner.layer.cornerRadius = 8
        banner.clipsToBounds = true
        banner.alpha = 0
        banner.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(banner)
        
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            banner.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            banner.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            banner.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Animate in and out
        UIView.animate(withDuration: 0.3, animations: {
            banner.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 3.0, options: [], animations: {
                banner.alpha = 0
            }) { _ in
                banner.removeFromSuperview()
            }
        }
    }
    
    /// Setup screen lock state bindings with RunTrackingEngine
    public func setupScreenLockBindings() {
        // Note: We don't clear cancellables here since other bindings might be set up elsewhere
        // The deinit method will handle cleanup
        
        // One-way sync: ViewController -> RunTrackingEngine
        $isScreenLocked
            .removeDuplicates() // Prevent unnecessary updates
            .sink { [weak self] locked in
                guard let self = self else { return }
                // Only update if different to prevent cycles
                if self.runEngine.isScreenLocked != locked {
                    self.runEngine.isScreenLocked = locked
                }
            }
            .store(in: &cancellables)
        
        // One-way sync: RunTrackingEngine -> ViewController
        runEngine.$isScreenLocked
            .removeDuplicates() // Prevent unnecessary updates
            .receive(on: DispatchQueue.main) // Ensure UI updates on main thread
            .sink { [weak self] locked in
                guard let self = self else { return }
                // Only update if different to prevent cycles
                if self.isScreenLocked != locked {
                    self.isScreenLocked = locked
                    // Update UI based on lock state
                    if locked {
                        self.showScreenLockOverlay()
            } else {
                        self.hideScreenLockOverlay()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    
    // Add this deinit method to the OutdoorRunViewController class
    deinit {
        print("🗑️ OutdoorRunViewController deinit - cleaning up resources")
        
        // Clean up screen lock overlay
        hideScreenLockOverlay()
        
        // Cancel all Combine subscriptions
        cancellables.removeAll()
        
        // Stop location updates
        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
        
        // Stop any running timers
        animationTimer?.invalidate()
        animationTimer = nil
        
        // Clear map delegate to prevent crashes
        if let hostingController = hostingController {
            // Access the mapView through the hosting controller if possible
            // Note: This might need adjustment based on your exact view structure
        }
        
        // Clean up speech synthesizer
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        // Clean up audio session
        audioSession = nil
        audioEngine?.stop()
        audioEngine = nil
        audioPlayer?.stop()
        audioPlayer = nil
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
        // Clean up hosting controller
        if let hostingController = hostingController {
            hostingController.willMove(toParent: nil)
            hostingController.view.removeFromSuperview()
            hostingController.removeFromParent()
        }
        hostingController = nil
        
        // Clear other properties that might hold references
        route = nil
        homeLocation = nil
        returnRouteOverlay = nil
        routeOverlay = nil
        progressOverlay = nil
        mileMarkers.removeAll()
        userAvatarAnnotation = nil
        screenLockOverlay = nil
        
        // Clear announcement queue
        announcementQueue.removeAll()
        
        print("🗑️ OutdoorRunViewController cleanup completed")
    }
}

// MARK: - MKMapViewDelegate

extension OutdoorRunViewController {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // Handle user location with custom profile picture
        if annotation is MKUserLocation {
            let identifier = "UserLocationView"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
                annotationView?.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
            } else {
                annotationView?.annotation = annotation
            }
            
            // Create an outer shadow container that doesn't clip
            let shadowContainer = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
            shadowContainer.backgroundColor = .clear
            shadowContainer.layer.shadowColor = UIColor.black.cgColor
            shadowContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
            shadowContainer.layer.shadowRadius = 4
            shadowContainer.layer.shadowOpacity = 0.3
            
            // Profile image view in a perfect circle
            let profileImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
            profileImageView.contentMode = .scaleAspectFill
            profileImageView.layer.cornerRadius = 20
            profileImageView.clipsToBounds = true  // This ensures proper circular clipping
            profileImageView.layer.borderWidth = 3
            profileImageView.layer.borderColor = UIColor.white.cgColor

            // Get profile picture from GlobalVariables
            if let profilePicture = CurrentUserService.shared.user.profilePicture {
                profileImageView.image = profilePicture
            } else {
                // Use default profile picture
                profileImageView.image = UIImage(named: "Do_NoProfilePic_User")
            }
            
            // Add profile view to shadow container
            shadowContainer.addSubview(profileImageView)
            
            annotationView?.addSubview(shadowContainer)
            return annotationView
        }
        
        // Handle custom annotations
        let identifier = "CustomAnnotation"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
        
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
            } else {
            annotationView?.annotation = annotation
        }
        
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            
            if overlay === returnRouteOverlay {
                // Return route - Vibrant purple with dashed line
                renderer.strokeColor = UIColor.systemPurple.withAlphaComponent(0.9)
                renderer.lineWidth = 4
                renderer.lineDashPattern = [8, 4] // Dashed for clear distinction
                renderer.lineJoin = .round
                renderer.lineCap = .round
                
            } else if overlay === routeProgressOverlay {
                // Completed portion of planned route - solid gray
                renderer.strokeColor = UIColor.systemGray.withAlphaComponent(0.8)
                renderer.lineWidth = 4
                renderer.lineJoin = .round
                renderer.lineCap = .round
                
            } else if overlay === routeRemainingOverlay {
                // Remaining portion of planned route - bright solid blue
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(1.0)
                renderer.lineWidth = 4
                renderer.lineJoin = .round
                renderer.lineCap = .round
                
            } else if overlay === routeOverlay {
                // Full planned route (when no progress tracking) - bright solid blue
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(1.0)
                renderer.lineWidth = 4
                renderer.lineJoin = .round
                renderer.lineCap = .round
                
            } else if overlay === runPathOverlay {
                // Current run path - bright orange, solid
                renderer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.95)
                renderer.lineWidth = 5
                renderer.lineJoin = .round
                renderer.lineCap = .round
                
            } else {
                // Default styling for other overlays
                renderer.strokeColor = routeColor
                renderer.lineWidth = 4.0
                renderer.lineJoin = .round
                renderer.lineCap = .round
            }
            
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }

    // MARK: - Helper Functions

    public func calculateBearing(from startCoordinate: CLLocationCoordinate2D, to endCoordinate: CLLocationCoordinate2D) -> Double {
        let lat1 = startCoordinate.latitude * Double.pi / 180
        let lat2 = endCoordinate.latitude * Double.pi / 180
        let deltaLon = (endCoordinate.longitude - startCoordinate.longitude) * Double.pi / 180
        
        let x = sin(deltaLon) * cos(lat2)
        let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearing = atan2(x, y)
        return (bearing * 180 / Double.pi + 360).truncatingRemainder(dividingBy: 360)
    }

    public func calculateTotalDistance(coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count > 1 else { return 0 }
        
        var totalDistance: Double = 0
        for i in 0..<coordinates.count-1 {
            let location1 = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            let location2 = CLLocation(latitude: coordinates[i+1].latitude, longitude: coordinates[i+1].longitude)
            totalDistance += location1.distance(from: location2)
        }
        return totalDistance
    }

    public func findClosestPointOnRoute(to coordinate: CLLocationCoordinate2D) -> (index: Int, distance: Double)? {
        guard !routePlanner.routePolyline.isEmpty else { return nil }
        
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var closestIndex = 0
        var closestDistance = Double.infinity
        
        for (index, routeCoord) in routePlanner.routePolyline.enumerated() {
            let routeLocation = CLLocation(latitude: routeCoord.latitude, longitude: routeCoord.longitude)
            let distance = targetLocation.distance(from: routeLocation)
            
            if distance < closestDistance {
                closestDistance = distance
                closestIndex = index
            }
        }
        
        return (closestIndex, closestDistance)
    }

    public func clearRouteOverlays() {
        // Remove all route-related overlays
        [routeOverlay, routeProgressOverlay, routeRemainingOverlay].compactMap { $0 }.forEach { overlay in
            mapView.removeOverlay(overlay)
        }
        
        routeOverlay = nil
        routeProgressOverlay = nil
        routeRemainingOverlay = nil
    }

    public func announceRouteLoaded(route: Route, waypoints: [RouteWaypoint]) {
        guard voiceGuidanceLevel != .none else { return }
        
        let routeName = route.name ?? "selected route"
        let distance = formatDistance(waypoints.last?.distanceFromStart ?? 0)
        let waypointCount = waypoints.filter {
            if case .turn = $0.type { return true }
            return false
        }.count
        
        let turnInfo = waypointCount > 0 ? " with \(waypointCount) turn\(waypointCount == 1 ? "" : "s")" : ""
        
        announceMessage("Route loaded. \(distance) \(routeName)\(turnInfo). Ready to start.")
    }
}

// MARK: - WCSessionDelegate

extension OutdoorRunViewController: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isWatchConnected = activationState == .activated
            print("📱 WCSession activation completed: \(activationState.rawValue)")
            
            if let error = error {
                print("📱 WCSession activation error: \(error.localizedDescription)")
            }
            
            // If activated successfully, send current status to watch
            if activationState == .activated {
                self.sendTrackingStatusToWatch()
                
                // If we have a route, send it to the watch
                if !self.routePlanner.routePolyline.isEmpty {
                    self.sendRouteToWatch()
                }
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isWatchConnected = false
            print("📱 WCSession became inactive")
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isWatchConnected = false
            print("📱 WCSession deactivated")
        }
        
        // Reactivate session as per Apple's recommendation
        WCSession.default.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let wasConnected = self.isWatchConnected
            self.isWatchConnected = session.isReachable
            print("📱 WCSession reachability changed: \(session.isReachable)")
            
            // If watch becomes reachable after being unreachable, reset error state
            if session.isReachable && !wasConnected {
                print("📱 Watch connection recovered - resetting error state")
                self.lastWatchErrorTime = 0 // Clear error time to allow immediate communication
                self.sendTrackingStatusToWatch() // Send status immediately
            }
            // If watch becomes unreachable, ask RunTrackingEngine to evaluate primary sources
            else if !session.isReachable && wasConnected {
                print("📱 Watch became unreachable - evaluating primary data sources")
                self.runEngine.evaluatePrimarySource() 
            }
        }
    }
    

    
    // Add this method to the WCSessionDelegate extension around line 4950
func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
     print("📱 Received message from watch: \(message)")
    DispatchQueue.main.async { [weak self] in
        guard let self = self else { 
            replyHandler(["status": "error", "message": "view controller deallocated"])
            return 
        }
        
        print("📱 OutdoorRunViewController: Received message with reply handler: \(message)")
        
        // Handle run history request for pace zone calculation
        if let type = message["type"] as? String, type == "requestRunHistory" {
            print("📱 🚀 OutdoorRunViewController: HANDLING RUN HISTORY REQUEST")
            let limit = message["limit"] as? Int ?? 20
            self.handleRunHistoryRequest(limit: limit, replyHandler: replyHandler)
            return
        }
        
        // Check if this is an outdoor run state change command - forward to RunTrackingEngine
        if let type = message["type"] as? String, type == "outdoorRunStateChange" {
            print("📱 OutdoorRunViewController: Forwarding outdoorRunStateChange message to RunTrackingEngine")
            
            // Forward to RunTrackingEngine's message handler
            self.runEngine.session(session, didReceiveMessage: message, replyHandler: replyHandler)
            return
        }
        
        // Handle other message types that OutdoorRunViewController should process
        if let _ = message["requestWorkout"] as? Bool {
            // Watch is requesting active workout data
            self.sendActiveWorkoutToWatch(directReplyHandler: replyHandler)
            return
        }
        
        // Default response for unhandled messages
        let response: [String: Any] = [
            "status": "received",
            "timestamp": Date().timeIntervalSince1970
        ]
        replyHandler(response)
    }
}
    
  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
    print("📱 Received application context: \(applicationContext)")
    DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        
        // Check if this is an outdoor run state change command - forward to RunTrackingEngine
        if let type = applicationContext["type"] as? String, type == "outdoorRunStateChange" {
            print("📱 OutdoorRunViewController: Forwarding outdoorRunStateChange from application context to RunTrackingEngine")
            // Forward to RunTrackingEngine's application context handler
            self.runEngine.session(session, didReceiveApplicationContext: applicationContext)
            return
        }
        
        // Process application context from watch
        if let watchStatus = applicationContext["watchStatus"] as? [String: Any] {
            self.handleWatchStatus(watchStatus)
        }
    }
}
    
    // MARK: - Watch Communication Helper Methods
    
    public func handleWatchStatus(_ status: [String: Any]) {
        // Extract watch tracking status
        if let isWatchTracking = status["isTracking"] as? Bool {
            runEngine.isWatchTracking = isWatchTracking
            
            // If watch is tracking, update policy accordingly
            if isWatchTracking {
                metricsCoordinator?.updatePolicy(
                    isIndoor: runEngine.isIndoorMode,
                    hasGoodGPS: runEngine.hasGoodLocationData,
                    isWatchTracking: true
                )
            }
        }
    }
    
    /// Handle run history request from watch for pace zone calculation
    public func handleRunHistoryRequest(limit: Int, replyHandler: @escaping ([String: Any]) -> Void) {
        print("📱 🚀 OutdoorRunViewController: STARTING RUN HISTORY REQUEST HANDLER")
        print("📱 📊 Request limit: \(limit)")
        
        // Fetch both outdoor and indoor run history from server
        let group = DispatchGroup()
        var outdoorRuns: [Any] = []
        var indoorRuns: [Any] = []
        var fetchErrors: [Error] = []
        
        // Fetch outdoor runs
        group.enter()
        print("📱 🔄 OutdoorRunViewController: Starting outdoor runs fetch...")
        getRunningLogs { [weak self] logs, error in
            defer { group.leave() }
            
            if let error = error {
                print("📱 ❌ OutdoorRunViewController: Error fetching outdoor runs: \(error.localizedDescription)")
                fetchErrors.append(error)
            } else if let logs = logs {
                outdoorRuns = logs
                print("📱 ✅ OutdoorRunViewController: Successfully fetched \(logs.count) outdoor runs")
            } else {
                print("📱 ❌ OutdoorRunViewController: Failed to fetch outdoor runs - no data returned")
                fetchErrors.append(NSError(domain: "OutdoorRunViewController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch outdoor runs"]))
            }
        }
        
        // Fetch indoor runs
        group.enter()
        print("📱 🔄 OutdoorRunViewController: Starting indoor runs fetch...")
        getTreadmillLogs { [weak self] logs, error in
            defer { group.leave() }
            
            if let error = error {
                print("📱 ❌ OutdoorRunViewController: Error fetching indoor runs: \(error.localizedDescription)")
                fetchErrors.append(error)
            } else if let logs = logs {
                indoorRuns = logs
                print("📱 ✅ OutdoorRunViewController: Successfully fetched \(logs.count) indoor runs")
            } else {
                print("📱 ❌ OutdoorRunViewController: Failed to fetch indoor runs - no data returned")
                fetchErrors.append(NSError(domain: "OutdoorRunViewController", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch indoor runs"]))
            }
        }
        
        // Wait for both requests to complete
        group.notify(queue: .main) {
            print("📱 🔄 OutdoorRunViewController: BOTH DATABASE REQUESTS COMPLETED")
            print("📱 📊 FINAL RESULTS:")
            print("📱 📊 - Outdoor runs: \(outdoorRuns.count)")
            print("📱 📊 - Indoor runs: \(indoorRuns.count)")
            print("📱 📊 - Fetch errors: \(fetchErrors.count)")
            
            // If we have errors but no data, return error
            if !fetchErrors.isEmpty && outdoorRuns.isEmpty && indoorRuns.isEmpty {
                let errorMessage = fetchErrors.first?.localizedDescription ?? "Unknown error"
                print("📱 ❌ OutdoorRunViewController: NO DATA FETCHED AND ERRORS OCCURRED - Returning error")
                replyHandler(["status": "error", "message": errorMessage])
                return
            }
            
            // Process and send combined results
            var allRuns: [[String: Any]] = []
            
            // Convert outdoor runs to dictionary format
            for run in outdoorRuns {
                if let runDict = run as? [String: Any] {
                    var processedRun = runDict
                    processedRun["runType"] = "outdoor"
                    allRuns.append(processedRun)
                }
            }
            
            // Convert indoor runs to dictionary format
            for run in indoorRuns {
                if let runDict = run as? [String: Any] {
                    var processedRun = runDict
                    processedRun["runType"] = "indoor"
                    allRuns.append(processedRun)
                }
            }
            
            // Sort by creation date (most recent first) and limit results
            let sortedRuns = allRuns.sorted { (first, second) in
                let firstDate = first["createdAt"] as? Date ?? Date.distantPast
                let secondDate = second["createdAt"] as? Date ?? Date.distantPast
                return firstDate > secondDate
            }
            
            let limitedRuns = Array(sortedRuns.prefix(limit))
            
            let response: [String: Any] = [
                "status": "success",
                "runLogs": limitedRuns,
                "count": limitedRuns.count,
                "outdoorCount": outdoorRuns.count,
                "indoorCount": indoorRuns.count,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            print("📱 🚀 OutdoorRunViewController: SENDING FINAL RESPONSE TO WATCH")
            print("📱 📦 Response keys: \(response.keys.joined(separator: ", "))")
            print("📱 📊 Sending \(limitedRuns.count) combined run logs to watch")
            
            replyHandler(response)
        }
    }
    
    public func sendActiveWorkoutToWatch(replyTo message: [String: Any]? = nil, directReplyHandler: (([String: Any]) -> Void)? = nil) {
        var response: [String: Any] = [
            "dashboardMode": false,
            "isWatchTracking": runEngine.isWatchTracking
        ]
        
        // Add workout data if we're in an active workout
        if runEngine.runState != .notStarted {
            response["workoutActive"] = true
            response["workoutType"] = runType.rawValue
            response["runState"] = runEngine.runState.rawValue
            response["elapsedTime"] = runEngine.elapsedTime
            
            // Add metrics
            let metrics = metricsCoordinator?.prepareMetricsForSync() ?? [:]
            response["metrics"] = metrics
            
            // Add data about primary sources for metrics
            response["primaryMetricSources"] = [
                "distance": runEngine.isWatchTracking ? "watch" : "phone",
                "pace": runEngine.isWatchTracking ? "watch" : "phone",
                "hr": runEngine.isWatchTracking ? "watch" : "phone",
                "calories": runEngine.isWatchTracking ? "watch" : "phone"
            ]
        } else {
            response["workoutActive"] = false
        }
        
        // Send the response
        if let replyHandler = directReplyHandler {
            replyHandler(response)
        } else if let messageId = message?["messageId"] as? String {
            // Include message ID in response for the watch to match request/response
            response["responseId"] = messageId
            
            // Send response as a new message
            WCSession.default.sendMessage(response, replyHandler: nil) { error in
                print("❌ Error sending active workout response: \(error.localizedDescription)")
            }
        }
    }
    

    
    
    public func prepareWatchResponse() -> [String: Any] {
        var response: [String: Any] = [:]
        
        // Add current metrics
        response["metrics"] = metricsCoordinator?.prepareMetricsForSync() ?? [:]
        
        // Add current status
        response["isRunning"] = runEngine.runState == .running
        response["elapsedTime"] = runEngine.elapsedTime
        
        return response
    }
    
    // MARK: - WCSession Communication Methods
    // ... existing code ...
    
    // Implement WorkoutCommunicationDelegate method
    func receivedWorkoutRequest(replyHandler: @escaping ([String : Any]) -> Void) {
        print("📱 OutdoorRunViewController: Received workout request from watch")
        
        let isRunning = runEngine.runState == .running || runEngine.runState == .paused
        
        // Debug current state
        print("📱 OutdoorRunViewController DEBUG:")
        print("   - runEngine.runType: \(runEngine.runType)")
        print("   - runEngine.runState: \(runEngine.runState)")
        print("   - runEngine.isIndoorMode: \(runEngine.isIndoorMode)")
        print("   - isRunning: \(isRunning)")
        
        // Prepare response with current workout state
        var response: [String: Any] = [
            "status": "processed",
            "workoutActive": isRunning,
            "hasActiveWorkout": isRunning,
            "runState": runEngine.runState.rawValue,
            "state": isRunning ? "inProgress" : "notStarted",
            "workoutType": "outdoorRun",  // Explicitly set outdoor run type
            "runType": "outdoorRun",      // Explicitly set runType
            "isIndoor": false             // Add explicit outdoor flag
        ]
        
        // Add metrics if running
        if isRunning {
            response["distance"] = runEngine.distance.value
            response["elapsedTime"] = runEngine.elapsedTime
            response["pace"] = runEngine.pace.value
            response["calories"] = runEngine.calories
            response["heartRate"] = runEngine.heartRate
        }
        
        print("📱 OutdoorRunViewController: Sending workout status to watch: \(response)")
        replyHandler(response)
    }
    // ... existing code ...
}

// MARK: - AVSpeechSynthesizerDelegate
extension OutdoorRunViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
            print("🔊 Started speaking with voice: \(utterance.voice?.identifier ?? "unknown")")
        }
        
        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            print("🔊 Finished speaking")
            
            // Mark announcement as complete
            isAnnouncementInProgress = false
            
            // Process next message in queue with natural delay
            if !announcementQueue.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.processAnnouncementQueue()
                }
            }
            
            // Maintain audio session for speech quality
            maintainAudioSessionForSpeech()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            print("🔊 Speech cancelled")
            
            // Mark announcement as complete
            isAnnouncementInProgress = false
            
            // Process next message in queue
            if !announcementQueue.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.processAnnouncementQueue()
                }
            }
        }
        
        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
            // This can be used for real-time speech highlighting if needed
        }
        
        public func maintainAudioSessionForSpeech() {
            // Keep audio session active briefly after speech for better quality
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                
                // Only deactivate if no more announcements are queued
                if self.announcementQueue.isEmpty && !self.speechSynthesizer.isSpeaking {
                    do {
                        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                        print("🔊 Audio session deactivated")
                    } catch {
                        print("⚠️ Failed to deactivate audio session: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        public func cleanupAudioSessionIfNeeded() {
            // Only deactivate if no other audio is playing and we're not actively running
            do {
                let audioSession = AVAudioSession.sharedInstance()
                if !audioSession.isOtherAudioPlaying && announcementQueue.isEmpty {
                    try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                    print("🔊 Audio session deactivated")
                }
            } catch {
                print("⚠️ Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Audio Setup
    public func setupAudioSession() {
        do {
            print("⚙️ Setting up audio session...")
            
            // Configure the audio session for mixing with other apps
            audioSession = AVAudioSession.sharedInstance()
            try audioSession?.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers])
            try audioSession?.setActive(true)
            
            print("Audio session activated successfully")
            
            // Set up the audio engine for text-to-speech
            audioEngine = AVAudioEngine()
            
            // Configure speech synthesizer
            speechSynthesizer.delegate = self
            
            // Create a silent audio player - try different approaches
            createSilentAudioPlayer()
            
            print("⚙️ Audio session setup complete")
        } catch {
            print("❌ Failed to set up audio session: \(error.localizedDescription)")
        }
    }

    public func createSilentAudioPlayer() {
        print("Creating silent audio player...")
        
        // First approach: Try creating a sine wave
        createSineWavePlayer()
    }

    public func createSineWavePlayer() {
        // Create audio file in temp directory
        let tempDir = FileManager.default.temporaryDirectory
        let silentSoundURL = tempDir.appendingPathComponent("silentSound.wav")
        
        // Use consistent channel count of 2 for stereo format
        let channelCount: UInt32 = 2
        
        // Generate simple sine wave
        let sampleRate: Double = 44100.0
        let duration: Double = 1.0
        let frequency: Double = 440.0 // A4 note
        let amplitude: Double = 0.01
        
        // Calculate number of samples
        let samples = Int(sampleRate * duration)
        
        // Create data buffer for stereo audio (2 channels)
        var data = [Float](repeating: 0, count: samples * Int(channelCount))
        
        // Fill data with a very quiet sine wave for both channels
        for i in 0..<samples {
            let t = Double(i) / sampleRate
            let sample = Float(amplitude * sin(2.0 * .pi * frequency * t))
            
            // Fill both channels with the same value for stereo
            data[i * Int(channelCount)] = sample        // Left channel
            data[i * Int(channelCount) + 1] = sample    // Right channel
        }
        
        // Create an ExtAudioFile to save the data
        var audioFile: ExtAudioFileRef?
        
        // Define output format - ensure stereo format
        var format = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(channelCount * 4),  // 4 bytes per Float32 * 2 channels
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(channelCount * 4),   // 4 bytes per Float32 * 2 channels
            mChannelsPerFrame: channelCount,            // Stereo
            mBitsPerChannel: 32,
            mReserved: 0
        )
        
        // Create the output file
        var status = ExtAudioFileCreateWithURL(
            silentSoundURL as CFURL,
            kAudioFileWAVEType,
            &format,
            nil,
            AudioFileFlags.eraseFile.rawValue,
            &audioFile
        )
        
        guard status == noErr, let audioFile = audioFile else {
            print("❌ Failed to create audio file: \(status)")
            fallbackToResourceFile()
            return
        }
        
        // Set client format - ensure this matches the output format
        status = ExtAudioFileSetProperty(
            audioFile,
            kExtAudioFileProperty_ClientDataFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
            &format
        )
        
        guard status == noErr else {
            print("❌ Failed to set client format: \(status)")
            ExtAudioFileDispose(audioFile)
            fallbackToResourceFile()
            return
        }
        
        // FIXED: Properly create and set up AudioBufferList to avoid memory access issues
        let dataSize = UInt32(samples * Int(channelCount) * MemoryLayout<Float>.size)
        
        // Create properly sized buffer list
        var bufferList = AudioBufferList()
        bufferList.mNumberBuffers = 1
        
        // Ensure data is properly retained during the conversion
        data.withUnsafeMutableBytes { rawBufferPointer in
        var buffer = AudioBuffer()
            buffer.mNumberChannels = channelCount
            buffer.mDataByteSize = dataSize
            buffer.mData = rawBufferPointer.baseAddress
            
            // Assign the buffer to the buffer list
        bufferList.mBuffers = buffer
        
            // Write data to file - only do this inside the withUnsafeMutableBytes closure to ensure data remains valid
        status = ExtAudioFileWrite(audioFile, UInt32(samples), &bufferList)
        }
        
        guard status == noErr else {
            print("❌ Failed to write audio data: \(status)")
            ExtAudioFileDispose(audioFile)
            fallbackToResourceFile()
            return
        }
        
        // Close the file
        ExtAudioFileDispose(audioFile)
        
        // Try to create an audio player with the file
        do {
            // Configure audio session to match the stereo format we just created
            try audioSession?.setPreferredOutputNumberOfChannels(Int(channelCount))
            
            audioPlayer = try AVAudioPlayer(contentsOf: silentSoundURL)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0.01 // Very quiet but not completely silent
            audioPlayer?.prepareToPlay()
            audioPlayer?.play() // Start playing right away
            print("✅ Created and started sine wave audio player with \(channelCount) channels")
        } catch {
            print("❌ Failed to create audio player: \(error.localizedDescription)")
            fallbackToResourceFile()
        }
    }

    // Fallback method to try using a bundled audio file
    public func fallbackToResourceFile() {
        print("Trying fallback to bundled audio file...")
        
        // Look for a silence file in bundle
        if let silenceURL = Bundle.main.url(forResource: "silence", withExtension: "mp3") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: silenceURL)
                audioPlayer?.numberOfLoops = -1 // Loop indefinitely
                audioPlayer?.volume = 0.01 // Very quiet
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                print("✅ Using bundled silence.mp3 file for background audio")
            } catch {
                print("❌ Failed to create audio player from silence.mp3: \(error.localizedDescription)")
                createSimpleMemoryPlayer()
            }
        } else {
            print("❌ No silence.mp3 file found in bundle")
            createSimpleMemoryPlayer()
        }
    }

    // Last resort - create a very simple sound file in memory
    public func createSimpleMemoryPlayer() {
        print("Creating simple memory player as last resort...")
        
        // Use a safer approach with a standard stereo format
        let sampleRate = 44100.0
        let duration = 1.0
        
        // Always use stereo format (2 channels)
        let channelCount: UInt32 = 2
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount)!
        
        // Create an empty buffer with the right format
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("❌ Failed to create PCM buffer")
            return
        }
        
        // Fill the buffer with silence
        buffer.frameLength = frameCount
        
        // Create a player node and attach it to the engine
        let playerNode = AVAudioPlayerNode()
        audioEngine?.attach(playerNode)
        
        // Connect the player to the main mixer
        if let format = audioEngine?.mainMixerNode.outputFormat(forBus: 0) {
            audioEngine?.connect(playerNode, to: audioEngine!.mainMixerNode, format: format)
            
            print("✅ Connected player node with matching format: \(format.channelCount) channels")
        } else {
            return
        }
        
        // Start the engine
        do {
            try audioEngine?.start()
            // Schedule the buffer to loop
            playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
            playerNode.volume = 0.01
            playerNode.play()
            print("✅ Started audio engine with silent buffer")
        } catch {
            print("❌ Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    // Add a method to handle watch updates
    public func handleWatchMetrics(_ metrics: [String: Any]) {
        // Process watch metrics
        if let watchElapsedTime = metrics["elapsedTime"] as? TimeInterval, 
           watchElapsedTime > 0 {
            // Check if there's a significant time difference
            let timeDiff = abs(watchElapsedTime - displayElapsedTime)
            
            if timeDiff > 2.0 {
                // Significant time difference from watch, use smooth transition
                print("⏱️ Watch reported time \(String(format: "%.2f", watchElapsedTime)) differs from local time \(String(format: "%.2f", displayElapsedTime)) by \(String(format: "%.2f", timeDiff))s")
                
                // Update engine time
                if watchElapsedTime > runEngine.elapsedTime {
                    runEngine.elapsedTime = watchElapsedTime
                }
                
                // Use smooth transition for UI
                syncTimeWithEngine(forceSync: false, fromExternal: true)
            }
        }
        
        // Process all other metrics
        metricsCoordinator?.processWatchMetrics(metrics: metrics)
    }
}



// Add VoiceGuidanceSettingsView
struct VoiceGuidanceSettingsView: View {
    @ObservedObject var viewModel: OutdoorRunViewController
    @Environment(\.dismiss) public var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Voice Guidance Level")) {
                    Picker("Level", selection: $viewModel.voiceGuidanceLevel) {
                        ForEach(OutdoorRunViewController.VoiceGuidanceLevel.allCases, id: \.self) { level in
                            Text(level.rawValue)
                                .tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(viewModel.voiceGuidanceLevel.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Section(header: Text("Voice Type")) {
                    Picker("Voice", selection: Binding(
                        get: { UserPreferences.shared.preferredVoiceType },
                        set: { UserPreferences.shared.preferredVoiceType = $0 }
                    )) {
                        ForEach(UserPreferences.VoiceType.allCases, id: \.self) { voice in
                            Text(voice.displayName).tag(voice)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Announcement Frequency")) {
                    Picker("Frequency", selection: $viewModel.announcementFrequency) {
                        ForEach(OutdoorRunViewController.AnnouncementFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.rawValue)
                                .tag(frequency)
                        }
                    }
                }
                
                Section(header: Text("Guidance Options")) {
                    Toggle("Pace Guidance", isOn: $viewModel.includePaceGuidance)
                    Toggle("Heart Rate Guidance", isOn: $viewModel.includeHeartRateGuidance)
                    Toggle("Navigation Guidance", isOn: $viewModel.includeNavigationGuidance)
                }
                
                Section(header: Text("Volume")) {
                    HStack {
                        Image(systemName: "speaker.fill")
                        Slider(value: $viewModel.voiceGuidanceVolume, in: 0...1)
                        Image(systemName: "speaker.wave.3.fill")
                    }
                }
            }
            .navigationTitle("Voice Guidance Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.saveVoiceGuidanceSettings()
                        dismiss()
                    }
                }
            }
        }
    }
}

// Performance Card View - Enhanced with modern design and full tap interaction
struct PerformanceCard: View {
    @Binding var showPerformance: Bool
    let cardBackground: Color
    let cardCornerRadius: CGFloat
    let runEngine: RunTrackingEngine
    let targetPace: Double?
    let targetPaceSource: String
    @State public var isPressed = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - Now fully tappable
            performanceHeader
            
            if showPerformance {
                VStack(spacing: 20) {
                    // Running Metrics (Cadence, Vertical Oscillation, Ground Contact)
                    RunningMetricsView(runEngine: runEngine)
                    
                    // Pace Zone Graph
                    PaceZoneView(runEngine: runEngine, targetPace: targetPace, targetPaceSource: targetPaceSource)
                    
                    // Heart Rate Zone Graph
                    HeartRateZoneView(runEngine: runEngine)
                    
                    // Effort Score
                    EffortScoreView(runEngine: runEngine)
                    
                    // Split View
                    SplitTimesView(runEngine: runEngine)
                }
                .padding(.bottom, 16)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 1.05))
                ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(
                    LinearGradient(
                        colors: showPerformance ? [
                            Color(hex: "#1E293B").opacity(0.9),
                            Color(hex: "#0F172A").opacity(0.8)
                        ] : [
                            cardBackground.opacity(0.6),
                            cardBackground.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: showPerformance ? [
                                    Color.blue.opacity(0.3),
                                    Color.purple.opacity(0.2)
                                ] : [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: showPerformance ? 1.5 : 1
                        )
                )
                .shadow(
                    color: showPerformance ? 
                        Color.blue.opacity(0.1) : Color.black.opacity(0.15),
                    radius: showPerformance ? 12 : 6,
                    x: 0,
                    y: showPerformance ? 6 : 3
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showPerformance)
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showPerformance.toggle()
            }
            
            // Haptic feedback
            let impactGenerator = UIImpactFeedbackGenerator(style: .light)
            impactGenerator.impactOccurred()
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    // Performance header view - Enhanced design
    public var performanceHeader: some View {
        HStack(spacing: 12) {
            // Performance icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.8),
                                Color.purple.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
            Text("PERFORMANCE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(0.5)
                
                Text(showPerformance ? "Tap to collapse" : "Tap to expand")
                    .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
                    .opacity(0.8)
            }
            
            Spacer()
            
            // Enhanced chevron with rotation animation
                Image(systemName: showPerformance ? "chevron.up" : "chevron.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .rotationEffect(.degrees(showPerformance ? 180 : 0))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showPerformance)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle()) // Makes entire area tappable
        )
    }
}

// Pace Zone View Component - Enhanced
struct PaceZoneView: View {
    @ObservedObject var runEngine: RunTrackingEngine
    let targetPace: Double?
    let targetPaceSource: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "speedometer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.cyan)
                
                Text("PACE ZONE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(0.5)
                
                Spacer()
                
                Text(runEngine.formattedPace)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.cyan.opacity(0.15))
                    )
            }
            .padding(.horizontal, 20)
            
            // Target pace info
            if let targetPace = targetPace {
                HStack {
                    Text("Target:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text(formatPace(targetPace) + (targetPaceSource.hasPrefix("Default") ? " (default)" : " ") + runEngine.getPaceUnitString())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                    
                }
                .padding(.horizontal, 20)
                
                // Debug: Log target pace in view
                .onAppear {
                    print("🎯 PaceZoneView: Target pace = \(targetPace), Source = \(targetPaceSource)")
                }
            }
            
            VStack(spacing: 12) {
                // Enhanced pace zone graph
            paceZoneGraph
            
                // Zone labels with modern styling
            HStack {
                    zoneLabel("Too Slow", color: .red)
                Spacer()
                    zoneLabel("Target Zone", color: .green)
                Spacer()
                    zoneLabel("Too Fast", color: .red)
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    public func zoneLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color.opacity(0.8))
    }
    
    // Enhanced pace zone graph view
    public var paceZoneGraph: some View {
        GeometryReader { metrics in
            ZStack(alignment: .leading) {
                // Zone background with gradient
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.8), Color.red.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: (metrics.size.width - 4) * 0.25)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.8), Color.green.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: (metrics.size.width - 4) * 0.5)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.8), Color.red.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: (metrics.size.width - 4) * 0.25)
                }
                .frame(height: 24)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                // Current pace indicator with glow effect
                VStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .shadow(color: .white, radius: 4)
                    
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: 20)
                        .cornerRadius(1)
                }
                .offset(x: metrics.size.width * calculatePacePosition() - 4)
            }
        }
        .frame(height: 32)
        .onChange(of: runEngine.pace.value) { _ in
            // This will force the view to redraw when pace changes
            // No additional code needed as calculatePacePosition() will be called again
        }
        .padding(.horizontal, 20)
    }
    
    // Calculate pace position helper
    public func calculatePacePosition() -> CGFloat {
        guard let targetPace = targetPace, targetPace > 0 else {
            return 0.5 // Default to middle if no target pace
        }
        
        // Get current pace from runEngine, defaulting to target pace if not available
        let currentPace = runEngine.pace.value > 0 ? runEngine.pace.value : targetPace
        
        // Define zone boundaries as percentages of target pace
        // For pace, SMALLER is FASTER (better)
        let fastZoneThreshold = targetPace * 0.85  // 15% faster than target (smaller number)
        let slowZoneThreshold = targetPace * 1.15  // 15% slower than target (larger number)
        
        if currentPace <= fastZoneThreshold {
            // In fast zone (RIGHT side - better performance)
            let fastZonePosition = 1.0 - (currentPace / fastZoneThreshold)
            return 0.75 + (fastZonePosition * 0.25) // Fast zone is 75-100% of width (right side)
        } else if currentPace <= slowZoneThreshold {
            // In optimal zone (middle)
            let relativePosition = (slowZoneThreshold - currentPace) / (slowZoneThreshold - fastZoneThreshold)
            return 0.25 + (relativePosition * 0.5) // Optimal zone is 25-75% of width
        } else {
            // In slow zone (LEFT side - worse performance)
            let excessSlowness = currentPace - slowZoneThreshold
            let maxExcess = targetPace * 0.35 // Allow up to 35% slower for max left position
            let slowZonePosition = 1.0 - min(excessSlowness / maxExcess, 1.0)
            return slowZonePosition * 0.25 // Slow zone is 0-25% of width (left side)
        }
    }
    
    // Format pace in seconds to MM:SS format in user's preferred units
    public func formatPace(_ paceInSeconds: Double) -> String {
        // paceInSeconds is already in user's preferred units (sec/km or sec/mi)
        let minutes = Int(paceInSeconds) / 60
        let seconds = Int(paceInSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Heart Rate Zone View Component - Enhanced
struct HeartRateZoneView: View {
    let runEngine: RunTrackingEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.red)
                
                Text("HEART RATE ZONE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(0.5)
                
                Spacer()
                
                Text("\(Int(runEngine.heartRate)) bpm")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.red.opacity(0.15))
                    )
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                // Enhanced heart rate zone graph
            heartRateZoneGraph
            
                // Zone labels with modern styling
            HStack {
                    zoneLabel("Rest", color: .blue)
                Spacer()
                    zoneLabel("Fat Burn", color: .green)
                Spacer()
                    zoneLabel("Cardio", color: .orange)
                Spacer()
                    zoneLabel("Peak", color: .red)
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    public func zoneLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color.opacity(0.8))
    }
    
    // Enhanced heart rate zone graph view
    public var heartRateZoneGraph: some View {
        GeometryReader { metrics in
            ZStack(alignment: .leading) {
                // Zone background with gradients
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: (metrics.size.width - 6) * 0.25)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.8), Color.green.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: (metrics.size.width - 6) * 0.25)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.8), Color.orange.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: (metrics.size.width - 6) * 0.25)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.8), Color.red.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: (metrics.size.width - 6) * 0.25)
                }
                .frame(height: 24)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                // Heart rate indicator with pulse effect
                VStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .shadow(color: .red, radius: 4)
                    
                Rectangle()
                    .fill(Color.white)
                        .frame(width: 2, height: 20)
                        .cornerRadius(1)
            }
                .offset(x: metrics.size.width * calculateHeartRatePosition() - 4)
        }
        }
        .frame(height: 32)
        .padding(.horizontal, 20)
    }
    
    // Calculate heart rate position helper
    public func calculateHeartRatePosition() -> CGFloat {
        // Get current heart rate
        let currentHR = Double(runEngine.heartRate)
        
        // Use standard heart rate zones without requiring user age
        // Assuming zones as percentages of the display:
        // Rest: 0-25%, Fat Burn: 25-50%, Cardio: 50-75%, Peak: 75-100%
        
        if currentHR <= 0 {
            return 0.1 // Position near beginning if no data
        }
        
        // Map heart rate to position along the bar
        // Using common heart rate ranges: 50-180 bpm maps to full width
        let minHR = 50.0
        let maxHR = 180.0
        
        // Calculate normalized position
        let normalizedPosition = (currentHR - minHR) / (maxHR - minHR)
        return CGFloat(min(max(normalizedPosition, 0.0), 1.0))
    }
}

// Effort Score View Component
struct EffortScoreView: View {
    let runEngine: RunTrackingEngine
    
    // Calculate effort score based on heart rate and duration
    public var effortScore: Int {
        let heartRate = runEngine.heartRate
        let duration = runEngine.elapsedTime / 60.0 // convert to minutes
        
        if heartRate <= 0 || duration <= 0 {
            return 0
        }
        
        // Default age of 30 for max heart rate calculation
        let defaultAge = 30.0
        let maxHeartRate = 220.0 - defaultAge
        
        // Heart rate as percentage of max
        let hrPercentage = heartRate / maxHeartRate
        
        // Base score: 0-100 scale based on heart rate percentage
        var baseScore = Int(min(100, max(0, hrPercentage * 100)))
        
        // Duration modifier: scores increase with duration
        let durationFactor = min(2.0, 1.0 + (duration / 60.0)) // max 2x multiplier after 60 min
        
        // Adjust score based on duration
        baseScore = Int(Double(baseScore) * durationFactor * 0.8) // Scale down slightly to leave room for improvement
        
        // Bonus for consistent pace (if runningEfficiency > 70)
        if runEngine.runningEfficiency > 70 {
            baseScore += Int(min(20, (runEngine.runningEfficiency - 70) / 1.5))
        }
        
        return min(100, baseScore) // Cap at 100
    }
    
    public var effortLevel: String {
        let score = effortScore
        
        if score < 20 {
            return "Very Low"
        } else if score < 40 {
            return "Low"
        } else if score < 60 {
            return "Moderate"
        } else if score < 80 {
            return "High"
        } else {
            return "Elite"
        }
    }
    
    public var effortColor: Color {
        let score = effortScore
        
        if score < 20 {
            return Color.blue
        } else if score < 40 {
            return Color.green
        } else if score < 60 {
            return Color.yellow
        } else if score < 80 {
            return Color.orange
        } else {
            return Color.red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EFFORT SCORE")
                    .font(.footnote)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(effortScore)")
                    .font(.footnote)
                    .foregroundColor(.white)
            }
            
            // Effort progress bar
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 30)
                    .cornerRadius(8)
                
                // Filled portion
                Rectangle()
                    .fill(effortColor.opacity(0.8))
                    .frame(width: max(CGFloat(effortScore) / 100.0 * UIScreen.main.bounds.width - 32, 4), height: 30)
                    .cornerRadius(8)
                
                // Level text
                Text(effortLevel)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.leading, 12)
            }
        }
        .padding(.horizontal, 16)
    }
}

// Split Times View Component
struct SplitTimesView: View {
    let runEngine: RunTrackingEngine
    
    public var splitUnit: String {
        return runEngine.useMetric ? "km" : "mi"
    }
    
    public var splitUnitDistance: Double {
        return runEngine.useMetric ? 1000.0 : 1609.34 // meters in km or mile
    }
    
    public var splitsToShow: [SplitTime] {
        // Filter to the 3 most recent splits
        return Array(runEngine.splitTimes.suffix(3))
    }
    
    // Computed properties for split progress
    private var distanceValue: Double {
        runEngine.distance.value
    }
    
    private var completedSplits: Int {
        Int(distanceValue / splitUnitDistance)
    }
    
    private var currentProgress: Double {
        (distanceValue / splitUnitDistance) - Double(completedSplits)
    }
    
    // Starting index for split numbering
    private var splitStartIndex: Int {
        max(runEngine.splitTimes.count - splitsToShow.count, 0)
    }
    
    // Format split pace
    private func formatSplitPace(_ split: SplitTime) -> String {
        // Convert seconds per meter to minutes per km or minutes per mile
        let secondsPerMeter = split.pace
        let totalSeconds: Int
        
        if runEngine.useMetric {
            // Convert to seconds per km
            let secondsPerKm = secondsPerMeter * 1000.0
            totalSeconds = max(0, Int(secondsPerKm.rounded()))
        } else {
            // Convert to seconds per mile
            let secondsPerMile = secondsPerMeter * 1609.34
            totalSeconds = max(0, Int(secondsPerMile.rounded()))
        }
        
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SPLITS (\(splitUnit.uppercased()))")
                    .font(.footnote)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Current split progress
                Text(String(format: "%.0f%%", currentProgress * 100))
                    .font(.footnote)
                    .foregroundColor(.white)
            }
            
            if splitsToShow.isEmpty {
                // No splits yet
                HStack {
                    Spacer()
                    Text("Complete 1 \(splitUnit) to see split times")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(height: 30)
                .padding(.vertical, 8)
            } else {
                // Display splits
                VStack(spacing: 4) {
                    ForEach(Array(splitsToShow.enumerated()), id: \.element.id) { index, split in
                        HStack {
                            Text("Split \(splitStartIndex + index + 1)")
                                .font(.footnote)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text(formatSplitPace(split))
                                .font(.footnote)
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// Add this after SplitTimesView
// Running Metrics View for cadence, vertical oscillation, and ground contact
struct RunningMetricsView: View {
    let runEngine: RunTrackingEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                
            Text("RUNNING METRICS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(0.5)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Metrics Cards
            HStack(spacing: 16) {
                // Cadence
                metricCard(
                    title: "CADENCE",
                    value: "\(Int(runEngine.cadence))",
                    unit: "spm",
                    color: .orange,
                    icon: "metronome"
                )
                
                // Vertical Oscillation
                metricCard(
                    title: "VERT. OSC.",
                    value: String(format: "%.1f", runEngine.verticalOscillation.value),
                    unit: "cm",
                    color: .green,
                    icon: "arrow.up.and.down"
                )
                
                // Ground Contact
                metricCard(
                    title: "GROUND CONTACT",
                    value: "\(Int(runEngine.groundContactTime * 1000))",
                    unit: "ms",
                    color: .purple,
                    icon: "timer"
                )
            }
            .padding(.horizontal, 20)
        }
    }
    
    public func metricCard(
        title: String,
        value: String,
        unit: String,
        color: Color,
        icon: String
    ) -> some View {
        VStack(spacing: 8) {
            // Icon with colored background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 24, height: 24)
                
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(color)
            }
            
            // Title
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Value
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            // Unit
            Text(unit)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.2),
                                    color.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}



// Add the didStartWorkout notification name extension
extension NSNotification.Name {
    static let didStartWorkout = NSNotification.Name("didStartWorkout")
}

// Add an extension to RunTrackingEngine with the missing method
extension RunTrackingEngine {
    func startGuidanceForRoute(_ route: Route) {
        // Activate navigation for this route
        RoutePlanner.shared.navigationActive = true
        RoutePlanner.shared.nextDirectionIndex = 0
        
        print("Starting guidance for route: \(route.name ?? "Unnamed route")")
        
        // Generate navigation directions if needed
        if RoutePlanner.shared.navigationDirections.isEmpty {
            self.generateBasicDirectionsForRoute(route)
        }
        
        // Announce first direction if available and not muted
        if !RoutePlanner.shared.navigationDirections.isEmpty && !self.navigationAudioMuted {
            let firstDirection = "Route guidance activated. " + RoutePlanner.shared.navigationDirections[0]
            
            // Use an utterance for the announcement
            let utterance = AVSpeechUtterance(string: firstDirection)
            utterance.rate = 0.5
            utterance.volume = 1.0
            
            let synthesizer = AVSpeechSynthesizer()
            synthesizer.speak(utterance)
            
            // Also set as coach feedback
            self.coachFeedback = firstDirection
        }
    }
    
    public func generateBasicDirectionsForRoute(_ route: Route) {
        var directions: [String] = []
        
        // Start with basic instruction
        directions.append("Follow the planned route.")
        
        // For longer routes, add distance markers
        if route.distance > 2000 { // If longer than 2km
            // Add a midpoint direction
            directions.append("Continue on your planned route. You're halfway there!")
            
            // Add approaching end direction
            directions.append("You're approaching the end of your planned route.")
        }
        
        // Add final direction
        directions.append("You have reached the end of your planned route.")
        
        // Set the directions
        RoutePlanner.shared.navigationDirections = directions
        RoutePlanner.shared.nextDirectionIndex = 0
    }
}

// MARK: - WorkoutCommunicationDelegate
extension OutdoorRunViewController: WorkoutCommunicationDelegate {
    func didReceiveHeartRateUpdate(_ heartRate: Double) {
        print("❤️ Received heart rate update from watch: \(heartRate) BPM")
    
        
        // Update UI on main thread (but don't trigger the engine update)
       DispatchQueue.main.async { [weak self] in
           // Only update the display, not the engine data
           self?.updateHeartRateDisplay()
           
           // Add to history for graphs if the heart rate is valid
           if heartRate > 0 {
               self?.heartRateHistory.append(heartRate)
               // Keep a reasonable amount of data points for performance
               if self?.heartRateHistory.count ?? 0 > 100 {
                   self?.heartRateHistory.removeFirst()
               }
           }
       }
    }
    
    func didReceiveRunningWorkoutUpdate(_ update: [String: Any]) {
        print("📱 Received workout update from watch: \(update.keys.joined(separator: ", "))")
        
        // Handle distance updates from watch
        if let distance = update["distance"] as? Double {
            print("📏 Received distance update from watch: \(distance)m")
            runEngine.updateDistanceFromWatch(distance)
        }
        
        // Handle calories updates from watch
        if let calories = update["calories"] as? Double {
            print("🔥 Received calories update from watch: \(calories)")
            runEngine.updateCalories(calories)
        }
        
        // Handle heart rate updates from watch
        if let heartRate = update["heartRate"] as? Double {
            print("❤️ Received heart rate update from watch: \(heartRate)")
            runEngine.updateHeartRate(heartRate)
        }
        
        // Handle cadence updates from watch
        if let cadence = update["cadence"] as? Double {
            print("👟 Received cadence update from watch: \(cadence)")
            runEngine.updateCadence(cadence)
        }
        
        // Handle pace updates from watch (if we're using watch as the source)
        if let pace = update["pace"] as? Double {
            print("⏱️ Received pace update from watch: \(pace)")
            // Only update if we're configured to use the watch as the pace source
            // This typically won't be used since the phone calculates pace from distance
        }
        
        // Handle workout state updates
        if let state = update["state"] as? String {
            print("🏃 Received workout state update from watch: \(state)")
            switch state {
            case "active", "inProgress":
                if runEngine.runState == .notStarted {
                    // Start the run if not already started
                    startRun()
                } else if runEngine.runState == .paused {
                    // Resume the run if paused
                    resumeRun()
                }
            case "paused":
                if runEngine.runState == .running {
                    // Pause the run if running
                    pauseRun()
                }
            case "completed":
                if runEngine.runState == .running || runEngine.runState == .paused {
                    // End the run if running or paused
                    endRun()
                }
            default:
                break
            }
        }
    }
    
    // Implement all required methods from the protocol
    func didReceiveWorkoutUpdate(_ update: WorkoutPayload) {
        print("📱 Received workout update: \(update.type)")
    }
    
    func didReceiveSetUpdate(_ update: SetPayload) {
        print("📱 Received set update for exercise: \(update.exerciseId)")
    }
    
    func didReceiveTimerUpdate(_ update: TimerPayload) {
        print("📱 Received timer update: \(update.seconds)s, running: \(update.isRunning)")
    }
    
    func didReceiveSyncRequest(_ update: SyncPayload) {
        print("📱 Received sync request with timestamp: \(update.timestamp)")
    }
    
    func didReceiveWorkoutsUpdate(_ updates: [WorkoutPayload]) {
        print("📱 Received \(updates.count) workout updates")
    }
    
    func didReceiveSessionName(_ sessionName: String) {
        print("📱 Received session name: \(sessionName)")
    }
    
    func didReceiveWorkoutRequest() {
        print("📱 Received workout request")
    }
    
    func didReceiveTrackingStatusUpdate(isDashboardMode: Bool, isWatchTracking: Bool) {
        print("📱 Received tracking status update: isDashboardMode=\(isDashboardMode), isWatchTracking=\(isWatchTracking)")
    }
    
    func didReceiveActiveWorkoutUpdate(_ workout: [String: Any]) {
        print("📱 Received active workout update")
    }
    
    func currentWorkoutMetrics() -> [String: Any] {
        var metrics: [String: Any] = [:]
        let handler = WorkoutCommunicationHandler.shared
        let isAutoJoin = runEngine.isJoiningExistingWorkout
        
        // For completed state or auto-join, include all final metrics
        if runEngine.runState == .completed || isAutoJoin {
            metrics = [
                "distance": runEngine.distance.value,
                "pace": runEngine.pace.value,
                "heartRate": runEngine.heartRate,
                "calories": runEngine.calories,
                "cadence": runEngine.cadence,
                "elapsedTime": runEngine.elapsedTime,
                
                // Add final workout data
                "finalMetrics": [
                    "distance": runEngine.distance.value,
                    "duration": runEngine.elapsedTime,
                    "calories": runEngine.calories,
                    "heartRate": runEngine.heartRate,
                    "pace": runEngine.pace.value
                ],
                
                // Force workout state flags
                "workoutActive": false,
                "hasActiveWorkout": false,
                "forcedStateChange": true  // Signal this is a final state change
            ]
        } else {
            // During normal operation, respect authority
            if !handler.isPrimaryForDistance {
                metrics["distance"] = runEngine.distance.value
            }
            if !handler.isPrimaryForPace {
                metrics["pace"] = runEngine.pace.value
            }
            if !handler.isPrimaryForHeartRate {
                metrics["heartRate"] = runEngine.heartRate
            }
            if !handler.isPrimaryForCalories {
                metrics["calories"] = runEngine.calories
            }
            if !handler.isPrimaryForCadence {
                metrics["cadence"] = runEngine.cadence
            }
            
            // Always include elapsed time
            metrics["elapsedTime"] = runEngine.elapsedTime
            
            // Set workout status flags
            metrics["workoutActive"] = runEngine.runState == .running || runEngine.runState == .paused
            metrics["hasActiveWorkout"] = runEngine.runState != .notStarted
        }
        
        // Always include these metadata fields regardless of state
        metrics["runState"] = runEngine.runState.rawValue
        metrics["state"] = runEngine.runState.rawValue // Include both for compatibility
        metrics["isIndoor"] = runType == .treadmillRun
        metrics["runType"] = runType == .treadmillRun ? "treadmillRun" : "outdoorRun"
        metrics["workoutType"] = "run"
        metrics["timestamp"] = Date().timeIntervalSince1970
        metrics["id"] = runEngine.workoutId.uuidString
        
        // Add authority flags
        metrics["isPrimaryForDistance"] = !handler.isPrimaryForDistance
        metrics["isPrimaryForPace"] = !handler.isPrimaryForPace
        metrics["isPrimaryForHeartRate"] = !handler.isPrimaryForHeartRate
        metrics["isPrimaryForCalories"] = !handler.isPrimaryForCalories
        metrics["isPrimaryForCadence"] = !handler.isPrimaryForCadence
        
        // Add tracking status
        metrics["isDashboardMode"] = handler.isDashboardMode
        metrics["isWatchTracking"] = handler.isWatchTracking
        metrics["hasGoodLocationData"] = runEngine.hasGoodLocationData
        metrics["useImperialUnits"] = !runEngine.useMetric
        
        return metrics
    }
    
    func didUpdateWorkout(_ workout: RunningWorkout) {
        print("📱 Workout updated: \(workout.state)")
    }
    
    func didReceiveAudioFeedback(type: AudioFeedbackType) {
        // Handle audio feedback based on type
        switch type {
        case .startWorkout:
            announceMessage("Workout started")
        case .pauseWorkout:
            announceMessage("Workout paused")
        case .resumeWorkout:
            announceMessage("Workout resumed")
        case .endWorkout:
            // Skip the basic "Workout completed" announcement since we already have 
            // a detailed completion announcement in handleRunStateChange(.completed)
            print("🔇 Skipping basic completion announcement - detailed announcement already made")
        case .milestone:
            announceMessage("Milestone reached")
        case .paceAlert:
            announceMessage("Pace alert")
        case .heartRateAlert:
            announceMessage("Heart rate alert")
        case .custom(let message):
            announceMessage(message)
        }
    }
    
    func didReceiveCadenceUpdate(value: Double) {
        print("👟 Received cadence update: \(value) steps/min")
        runEngine.updateCadence(value)
        
        // Add to history for tracking if needed
        if value > 0 {
            cadenceHistory.append(value)
            // Keep a reasonable amount of data points for performance
            if cadenceHistory.count > 100 {
                cadenceHistory.removeFirst()
            }
            
            // Update UI if needed (for custom graphs or immediate feedback)
            updateCadenceDisplay()
        }
    }
}

// MARK: - Helper Classes

/// Thread-safe flag for atomic operations
class AtomicFlag {
    public var flag = false
    public let lock = NSLock()
    
    /// Tests current value and sets it to true atomically
    /// - Returns: The previous value before setting
    func testAndSet() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let oldValue = flag
        flag = true
        return !oldValue // Return true if this was the first set
    }
}

// MARK: - Performance Analysis Helper Methods

extension OutdoorRunTrackerView {
    
    /// Formats pace in minutes:seconds format
    public func formatPace(_ paceSeconds: Double) -> String {
        if paceSeconds <= 0 || paceSeconds.isInfinite || paceSeconds.isNaN {
            return "--:--"
        }
        
        let minutes = Int(paceSeconds) / 60
        let seconds = Int(paceSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Gets heart rate zone name based on BPM
    public func getHeartRateZoneName(_ heartRate: Double) -> String {
        if heartRate <= 0 {
            return "N/A"
        }
        
        // Basic heart rate zones (can be customized based on user's max HR)
        let maxHR = 220 - 30 // Assuming age 30, can be made dynamic
        let percentage = (heartRate / Double(maxHR)) * 100
        
        switch percentage {
        case 0..<50:
            return "Recovery"
        case 50..<60:
            return "Aerobic"
        case 60..<70:
            return "Aerobic"
        case 70..<80:
            return "Threshold"
        case 80..<90:
            return "VO2 Max"
        default:
            return "Max"
        }
    }
    
    /// Gets heart rate zone color based on BPM
    public func getHeartRateZoneColor(_ heartRate: Double) -> Color {
        if heartRate <= 0 {
            return .gray
        }
        
        let maxHR = 220 - 30 // Assuming age 30
        let percentage = (heartRate / Double(maxHR)) * 100
        
        switch percentage {
        case 0..<50:
            return .blue
        case 50..<60:
            return .green
        case 60..<70:
            return .yellow
        case 70..<80:
            return .orange
        case 80..<90:
            return .red
        default:
            return .purple
        }
    }
    
    /// Gets current performance status message
    /// Gets comprehensive performance coaching with recovery and fatigue analysis
       public func getPerformanceStatus() -> String? {
           return getComprehensiveCoaching()
       }
       
       /// Comprehensive coaching system analyzing performance, recovery, and fatigue
       public func getComprehensiveCoaching() -> String? {
           let currentPace = viewModel.runEngine.pace.value
           let heartRate = viewModel.runEngine.heartRate
           let elapsedTime = viewModel.runEngine.elapsedTime
           let distance = viewModel.runEngine.distance.value
           
           // Early data check
           guard currentPace > 0 && !currentPace.isInfinite else {
               return "🔥 Getting warmed up! Your running data is loading..."
           }
           
           // Analyze all performance factors
           let fatigueLevel = analyzeFatigueLevel()
           let heartRateStatus = analyzeHeartRateStatus()
           let paceStatus = analyzePacePerformance()
           let recoveryAdvice = getRecoveryAdvice()
           
           // Priority 1: Safety warnings (heart rate too high)
           if let criticalWarning = getCriticalHealthWarning() {
               return criticalWarning
           }
           
           // Priority 2: High fatigue warnings
           if fatigueLevel >= 0.8 {
               return getFatigueWarning()
           }
           
           // Priority 3: Heart rate coaching
           if let hrCoaching = heartRateStatus {
               return hrCoaching
           }
           
           // Priority 4: Pace coaching with fun personality
           if let paceCoaching = paceStatus {
               return paceCoaching
           }
           
           // Priority 5: Recovery and general tips
           return recoveryAdvice ?? getEncouragementMessage()
       }
    
    
    // MARK: - Comprehensive Coaching Analysis
    
    /// Analyzes fatigue level based on pace decline and heart rate elevation
    public func analyzeFatigueLevel() -> Double {
        let paceHistory = viewModel.paceHistory
        let heartRateHistory = viewModel.heartRateHistory
        let elapsedMinutes = viewModel.runEngine.elapsedTime / 60.0
        
        var fatigueScore: Double = 0.0
        
        // Pace decline analysis (40% weight)
        if paceHistory.count >= 10 {
            let recentPaces = Array(paceHistory.suffix(5))
            let earlyPaces = Array(paceHistory.prefix(5))
            
            if !earlyPaces.isEmpty && !recentPaces.isEmpty {
                let avgEarlyPace = earlyPaces.reduce(0, +) / Double(earlyPaces.count)
                let avgRecentPace = recentPaces.reduce(0, +) / Double(recentPaces.count)
                
                if avgEarlyPace > 0 {
                    let paceDecline = (avgRecentPace - avgEarlyPace) / avgEarlyPace
                    fatigueScore += max(0, paceDecline * 2.0) * 0.4 // Slower pace = higher fatigue
                }
            }
        }
        
        // Heart rate elevation analysis (35% weight)
        let currentHR = viewModel.runEngine.heartRate
        if currentHR > 0 {
            let maxHR = 220.0 - 30.0 // Age-adjusted, should be personalized
            let hrPercentage = currentHR / maxHR
            
            if hrPercentage > 0.85 {
                fatigueScore += (hrPercentage - 0.85) * 2.0 * 0.35
            }
        }
        
        // Duration factor (25% weight)
        if elapsedMinutes > 30 {
            let durationFactor = min((elapsedMinutes - 30) / 60.0, 1.0) // Max out at 90 minutes
            fatigueScore += durationFactor * 0.25
        }
        
        return min(fatigueScore, 1.0)
    }
    
    /// Analyzes heart rate for safety and performance coaching
    public func analyzeHeartRateStatus() -> String? {
        let heartRate = viewModel.runEngine.heartRate
        guard heartRate > 0 else { return nil }
        
        let maxHR = 220.0 - 30.0 // Should be personalized
        let percentage = (heartRate / maxHR) * 100
        let zone = getHeartRateZoneName(heartRate)
        
        switch percentage {
        case 0..<50:
            return "💙 Cruising in the comfort zone! Perfect for recovery runs."
        case 50..<60:
            return "💚 Sweet aerobic zone! Building that endurance engine! 🚂"
        case 60..<70:
            return "💛 Aerobic power! You're in the fitness-building zone! 💪"
        case 70..<80:
            return "🧡 Threshold warrior! This is where magic happens! ✨"
        case 80..<90:
            return "❤️ VO2 Max territory! You're flying! Don't stay here too long! 🚀"
        case 90..<95:
            return "🔴 Redline zone! Consider easing up to stay safe! ⚠️"
        default:
            return nil // Will trigger critical warning
        }
    }
    
    /// Analyzes pace performance with target comparison
    public func analyzePacePerformance() -> String? {
        guard let targetPace = viewModel.targetPace else {
            return "🎯 Running by feel today? Listen to your body! 💭"
        }
        
        let currentPace = viewModel.runEngine.pace.value
        let paceDifference = currentPace - targetPace
        let tolerance = targetPace * 0.05 // 5% tolerance
        
        if abs(paceDifference) <= tolerance {
            let messages = [
                "🎯 Bullseye! Your pacing is spot on! 🏹",
                "✨ Perfect rhythm! You're like a metronome! 🎵",
                "🔥 Nailed it! This is what consistency looks like! 💯",
                "⚡ Smooth operator! Keep this flow going! 🌊"
            ]
            return messages.randomElement()
        } else if paceDifference > tolerance {
            let slowBy = Int((paceDifference / targetPace) * 100)
            if slowBy > 15 {
                return "🐌 \(slowBy)% slower than target. Time to shift gears! ⚡"
            } else {
                return "🚶‍♂️ A bit behind pace. Let's pick it up gradually! 📈"
            }
        } else {
            let fastBy = Int((abs(paceDifference) / targetPace) * 100)
            if fastBy > 15 {
                return "🚀 Whoa! \(fastBy)% faster than target! Save some energy! 🔋"
            } else {
                return "🏃‍♂️ Feeling speedy! Just watch that you don't burn out! 🔥"
            }
        }
    }
    
    /// Provides critical health warnings for dangerous heart rate levels
    public func getCriticalHealthWarning() -> String? {
        let heartRate = viewModel.runEngine.heartRate
        guard heartRate > 0 else { return nil }
        
        let maxHR = 220.0 - 30.0
        let percentage = (heartRate / maxHR) * 100
        
        if percentage >= 95 {
            return "🚨 SLOW DOWN! Heart rate dangerously high! Take a walking break! 🚶‍♂️"
        }
        
        return nil
    }
    
    /// Provides fatigue-based warnings and recovery advice
    public func getFatigueWarning() -> String? {
        let messages = [
            "😴 Fatigue detected! Consider slowing down or taking a walk break! 🚶‍♂️",
            "⚡ Your body is working hard! Listen to it and ease up if needed! 💚",
            "🔋 Energy levels dropping! A walking recovery might help! 🌟",
            "💪 You're pushing limits! Remember, rest is part of training too! 😌"
        ]
        return messages.randomElement()
    }
    
    /// Provides recovery and wellness advice
    public func getRecoveryAdvice() -> String? {
        let elapsedMinutes = viewModel.runEngine.elapsedTime / 60.0
        let distance = viewModel.runEngine.distance.value
        
        // Long run advice
        if elapsedMinutes > 45 || distance > 5.0 {
            let recoveryTips = [
                "🥤 Remember to hydrate during longer runs! Your body needs fuel! 💧",
                "🧂 Consider electrolytes for runs this long! Salt is your friend! ⚡",
                "🍌 Long run fuel check! Got energy snacks? Your muscles will thank you! 💪",
                "❄️ Plan your post-run recovery! Ice bath or gentle stretching? 🧘‍♂️"
            ]
            return recoveryTips.randomElement()
        }
        
        // Weather and environmental advice (would need weather data)
        let currentHR = viewModel.runEngine.heartRate
        if currentHR > 0 {
            let maxHR = 220.0 - 30.0
            let percentage = (currentHR / maxHR) * 100
            
            if percentage > 80 && elapsedMinutes > 20 {
                return "🌡️ Hot day or pushing hard? Make sure to cool down gradually! 🧊"
            }
        }
        
        return nil
    }
    
    /// Provides encouraging messages with personality
    public func getEncouragementMessage() -> String? {
        let elapsedMinutes = viewModel.runEngine.elapsedTime / 60.0
        let distance = viewModel.runEngine.distance.value
        
        // Distance-based encouragement
        if distance >= 5.0 {
            let messages = [
                "🏃‍♂️ 5K+ club! You're officially awesome today! 🌟",
                "💪 Look at you go! Every step is building a stronger you! 🔥",
                "🎉 Distance goals crushing! You're unstoppable! 🚀"
            ]
            return messages.randomElement()
        }
        
        // Time-based encouragement
        if elapsedMinutes >= 30 {
            let messages = [
                "⏰ 30+ minutes of dedication! Your future self thanks you! 🙏",
                "🔥 Half hour strong! That's some serious commitment! 💯",
                "✨ Time flies when you're being amazing! Keep it up! 🌟"
            ]
            return messages.randomElement()
        }
        
        // General encouragement
        let generalMessages = [
            "🌟 Every step counts! You're building greatness! 💪",
            "💚 Your body is amazing! Feel that strength! ⚡",
            "🎵 Find your rhythm and ride the wave! 🌊",
            "🔥 Progress over perfection! You're doing great! ✨"
        ]
        
        return generalMessages.randomElement()
    }

}

// Add this protocol in OutdoorRunViewController.swift (or create a separate file)
protocol OutdoorRunViewControllerDelegate: AnyObject {
    func outdoorRunDidComplete(with runLog: RunLog?)
    func outdoorRunWasCanceled()
}

// Add message type enum
enum AnnouncementMessageType {
    case announcement  // Regular progress updates
    case coaching     // Tips and guidance
    case milestone    // Achievement celebrations
    case warning      // Pace corrections, alerts
}

// MARK: - WorkoutCommunicationHandlerDelegate
extension OutdoorRunViewController: WorkoutCommunicationHandlerDelegate {
    func workoutCommunicationHandler(_ handler: WorkoutCommunicationHandler, didReceiveMessage message: [String: Any]) {
        // Handle messages from watch
        if let type = message["type"] as? String {
            switch type {
            case "workoutUpdate":
                // Handle workout update from watch
                break
            default:
                break
            }
        }
    }
    
    func workoutCommunicationHandler(_ handler: WorkoutCommunicationHandler, didUpdateConnectionStatus isConnected: Bool) {
        DispatchQueue.main.async {
            // Update UI based on connection status
            print("📱 Watch connection status changed: \(isConnected)")
        }
    }
}



