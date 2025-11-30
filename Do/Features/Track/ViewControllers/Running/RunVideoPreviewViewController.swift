import UIKit
import Parse
import AVKit
import NotificationBannerSwift
import CoreLocation
import MapKit



class RunVideoPreviewViewController: UIViewController, MKMapViewDelegate {
    
    // MARK: - Properties
    private var runData: RunLog
    private var shareImage: UIImage?
    private var mapView: MKMapView!
    private var routeCoordinates: [CLLocationCoordinate2D] = []
    
    // UI Elements
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private let imageContainerView = UIView()
    private let mapImageView = UIImageView()
    private let runImageView = UIImageView()
    private let statsContainerView = UIView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    
    // Stats UI
    private var distanceLabel: UILabel!
    private var timeLabel: UILabel!
    private var paceLabel: UILabel!
    private var caloriesLabel: UILabel!
    private var elevationLabel: UILabel!
    
    // Add gradient animation controller property
    private var gradientAnimator: CADisplayLink?
    private var gradientLayer: CAGradientLayer?
    private var hueShift: CGFloat = 0.0
    
    // MARK: - Lifecycle
    
    init(runData: RunLog) {
        self.runData = runData
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupMapView()
        setupConstraints()
        processRunData()
        
        // Debug: Print RunLog properties 
        if let runLog = runData as? RunLog {
            print("RunLog Details:")
            print("- Duration: \(runLog.duration ?? "nil")")
            print("- Distance: \(runLog.distance ?? "nil")")
            print("- Avg Pace: \(runLog.avgPace ?? "nil")")
            print("- Calories: \(runLog.caloriesBurned ?? 0)")
            print("- Elevation Gain: \(runLog.elevationGain ?? "nil")")
            print("- Heart Rate: \(runLog.avgHeartRate ?? 0)")
            
            // Check if duration and pace can be converted to numeric values
            if let duration = runLog.duration {
                if let durationValue = TimeInterval(duration) {
                    print("Duration converts to TimeInterval: \(durationValue)")
                } else {
                    print("Duration doesn't convert to TimeInterval: \(duration)")
                }
            }
            
            if let pace = runLog.avgPace {
                if let paceValue = Double(pace) {
                    print("Pace converts to Double: \(paceValue)")
                } else {
                    print("Pace doesn't convert to Double: \(pace)")
                }
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update any layers that need to match container size
        for layer in imageContainerView.layer.sublayers ?? [] {
            if layer is CAGradientLayer {
                layer.frame = imageContainerView.bounds
                if let maskLayer = layer.mask {
                    let path = UIBezierPath(roundedRect: layer.bounds, cornerRadius: 20)
                    let innerRect = layer.bounds.insetBy(dx: 4, dy: 4)
                    let innerPath = UIBezierPath(roundedRect: innerRect, cornerRadius: 16)
                    path.append(innerPath.reversing())
                    (maskLayer as? CAShapeLayer)?.path = path.cgPath
                }
            }
        }
        
        // Ensure mapView is updated when view layout changes
        mapView.setNeedsDisplay()
    }
    
    // MARK: - Private Methods
    
    private func setupUI() {
        // Configure view with gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.04, green: 0.07, blue: 0.16, alpha: 1.0).cgColor,
            UIColor(red: 0.11, green: 0.15, blue: 0.25, alpha: 1.0).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)
        
        // Set up title label
        titleLabel.text = "Run Highlights"
        titleLabel.textColor = .white
        titleLabel.font = UIFont(name: "AvenirNext-Bold", size: 24)
        titleLabel.textAlignment = .center
        
        // Set up close button
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        
        // Set up share button
        shareButton.setTitle("Share", for: .normal)
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        shareButton.tintColor = .white
        shareButton.backgroundColor = uicolorFromHex(rgbValue: 0xF7931F)
        shareButton.layer.cornerRadius = 24
        shareButton.titleLabel?.font = UIFont(name: "AvenirNext-DemiBold", size: 17)
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        
        // Set up image container view with Do brand colors frame
        setupGlassyContainer()
        
        // Set up run image view
        runImageView.contentMode = .scaleAspectFill
        runImageView.clipsToBounds = true
        
        // Set up map image view
        mapImageView.contentMode = .scaleAspectFill
        mapImageView.clipsToBounds = true
        mapImageView.alpha = 0.8 // Increase map visibility
        
        // Set up stats container view with a visible background
        statsContainerView.backgroundColor = UIColor.clear
        
        // Set up loading indicator
        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.startAnimating()
        
        // Add subviews in correct order
        view.addSubview(titleLabel)
        view.addSubview(closeButton)
        view.addSubview(imageContainerView)
        imageContainerView.addSubview(mapImageView)
        imageContainerView.addSubview(runImageView)
        
        // Add stats container last to ensure it's on top
        view.addSubview(statsContainerView)
        
        view.addSubview(shareButton)
        view.addSubview(loadingIndicator)
        
        // Set up constraints
        setupConstraints()
        
        // Add run stats to the stats container
        populateRunStats()
        
        // We're no longer calling setupProfileAndDate() here as that UI is now part of the city/map overlay
        
        // Note: Using Do brand colors (orange F7931F, red C1272D, and white) for the frame
    }
    
    private func setupGlassyContainer() {
        // Create glass effect for container
        imageContainerView.backgroundColor = UIColor.clear
        
        // Remove border and rely on shadow and rounded corners for definition
        imageContainerView.layer.cornerRadius = 20
        imageContainerView.layer.borderWidth = 0 // Remove border completely
        
        // Enhanced shadow for better definition without borders
        imageContainerView.layer.shadowColor = UIColor.black.cgColor
        imageContainerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        imageContainerView.layer.shadowRadius = 12
        imageContainerView.layer.shadowOpacity = 0.4
        imageContainerView.layer.masksToBounds = false
        
        // Create a glass effect background
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        imageContainerView.addSubview(blurView)
        
        // Configure blur view to fill the container
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: imageContainerView.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor)
        ])
        
        // Make sure blur view has rounded corners and clips to bounds
        blurView.layer.cornerRadius = 20
        blurView.clipsToBounds = true
    }
    
    private func setupMapView() {
        // Create the map view
        mapView = MKMapView()
        mapView.showsUserLocation = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsTraffic = false
        
        // Set dark theme
        // If iOS 13 or later, use standard map with dark mode
        if #available(iOS 13.0, *) {
            mapView.overrideUserInterfaceStyle = .dark
            mapView.mapType = .mutedStandard // Dark-themed standard map
        } else {
            // Fallback for older iOS versions
            mapView.mapType = .standard
        }
        
        // Enable 3D effects and clean up display
        mapView.showsBuildings = true
        // Enable pitch for more dramatic 3D effect
            mapView.isPitchEnabled = true // Allow pitch gestures
            mapView.showsCompass = false
            mapView.pointOfInterestFilter = .excludingAll // Remove POIs for cleaner look
        
        // Apply a subtle dimming overlay for better text contrast
        mapView.alpha = 0.95
        
        // Add map style overlay - for glassy feel
        let mapStyleOverlay = UIView()
        mapStyleOverlay.translatesAutoresizingMaskIntoConstraints = false
        mapStyleOverlay.backgroundColor = UIColor(white: 0.1, alpha: 0.2)
        
        // Add a loading indicator while the map loads
        loadingIndicator.startAnimating()
        
        // Set delegate
        mapView.delegate = self // Set delegate
        
        // Add map to view hierarchy
        imageContainerView.addSubview(mapView)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        imageContainerView.addSubview(mapStyleOverlay)
        
        // Ensure map fills the container with small padding
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: imageContainerView.topAnchor, constant: 8),
            mapView.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor, constant: 8),
            mapView.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor, constant: -8),
            mapView.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor, constant: -8),
            
            mapStyleOverlay.topAnchor.constraint(equalTo: mapView.topAnchor),
            mapStyleOverlay.leadingAnchor.constraint(equalTo: mapView.leadingAnchor),
            mapStyleOverlay.trailingAnchor.constraint(equalTo: mapView.trailingAnchor),
            mapStyleOverlay.bottomAnchor.constraint(equalTo: mapView.bottomAnchor)
        ])
        
        // Round corners of map view for a modern look
        mapView.layer.cornerRadius = 16
        mapView.clipsToBounds = true
        mapStyleOverlay.layer.cornerRadius = 16
        mapStyleOverlay.clipsToBounds = true
        
        // Remove any border for a cleaner look
        if #available(iOS 13.0, *) {
        mapView.layer.borderWidth = 0
        }
        
        // Add inner shadow for depth
        let innerShadowLayer = CALayer()
        innerShadowLayer.frame = mapView.bounds
        innerShadowLayer.shadowPath = UIBezierPath(roundedRect: innerShadowLayer.bounds.insetBy(dx: -1, dy: -1), cornerRadius: 16).cgPath
        innerShadowLayer.shadowColor = UIColor.black.cgColor
        innerShadowLayer.shadowOffset = CGSize.zero
        innerShadowLayer.shadowOpacity = 0.5
        innerShadowLayer.shadowRadius = 3
        innerShadowLayer.masksToBounds = true
        mapView.layer.addSublayer(innerShadowLayer)
        
        // Add double tap to zoom gesture
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        mapView.addGestureRecognizer(doubleTapGesture)
        
        // Force layout update to ensure map is properly rendered
        mapView.layoutIfNeeded()
        mapView.setNeedsLayout()
    }
    
    private func processRunData() {
        // Parse location data and update the map
            if let runLog = runData as? RunLog {
            print("Processing RunLog data")
            
            // Get locations from RunLog
            if let locations = convertLocationsFromRunLog(runLog) {
                // Update map with route
                updateMapWithRoute(locations)
                
                // Update stats
            updateStatsWithRunData()
        
        // Generate shareable image
        generateShareImage()
            } else {
                showError("Could not find route data in RunLog")
            }
        } else {
            showError("Invalid data format. Expected RunLog.")
        }
    }
    
    // Extract location data from RunLog
    private func extractLocationData() -> [CLLocation]? {
        print("Extracting location data...")
        
        // Handle case where runData is a RunLog object
        if let runLog = runData as? RunLog {
            print("Found RunLog object")
            return convertLocationsFromRunLog(runLog)
        }
        
        return nil
    }
    
    // Parse locations from run data
    private func parseLocationsFromRunData() -> [CLLocation] {
        if let locations = extractLocationData() {
            return locations
        }
        
        print("Failed to extract location data, returning empty array")
        return []
    }
    
    // Convert from RunLog to CLLocation array
    private func convertLocationsFromRunLog(_ runLog: RunLog) -> [CLLocation]? {
        print("Examining RunLog properties")
        
        // Check for locationData in Parse format
        if let locationData = runLog.locationData, !locationData.isEmpty {
            print("Found \(locationData.count) items in RunLog.locationData")
            return parseLocationData(locationData)
        }
        
        // Try to get coordinates from the coordinateArray if available
        if let coordinateArray = runLog.coordinateArray, !coordinateArray.isEmpty {
            print("Found \(coordinateArray.count) items in RunLog.coordinateArray")
            return parseCoordinateArray(coordinateArray)
        }
        
        // If no locations found, log the available properties
        let mirror = Mirror(reflecting: runLog)
        print("RunLog properties:")
        for child in mirror.children {
            if let propertyName = child.label {
                print("  - \(propertyName): \(type(of: child.value))")
                
                // Check if this value might contain coordinates we can use
                if let locationArray = child.value as? [[String: Any]], !locationArray.isEmpty {
                    print("Found potential location array in RunLog.\(propertyName)")
                    let locations = parseLocationData(locationArray)
                    if !locations.isEmpty {
                        return locations
                    }
                }
                
                // Check if this is a coordinate array
                if let coordArray = child.value as? [Any], !coordArray.isEmpty {
                    print("Found potential coordinate array in RunLog.\(propertyName)")
                    let locations = parseCoordinateArray(coordArray)
                    if !locations.isEmpty {
                        return locations
                    }
                }
            }
        }
        
        print("No location data found in RunLog")
        return nil
    }
    
    private func parseLocationData(_ locationData: [[String: Any]]) -> [CLLocation] {
        var locations = [CLLocation]()
        
        for locationPoint in locationData {
            // Try various known formats for latitude/longitude
            var lat: Double?
            var lon: Double?
            
            // Standard format
            if let latitude = locationPoint["latitude"] as? Double {
                lat = latitude
            } else if let latitude = locationPoint["lat"] as? Double {
                lat = latitude
            }
            
            if let longitude = locationPoint["longitude"] as? Double {
                lon = longitude
            } else if let longitude = locationPoint["lon"] as? Double {
                lon = longitude
            } else if let longitude = locationPoint["lng"] as? Double {
                lon = longitude
            }
            
            // If we have valid coordinates, create a location
            if let lat = lat, let lon = lon, lat != 0, lon != 0 {
                // Try to get timestamp from locationPoint if available
                let timestamp: Date
                if let timeValue = locationPoint["timestamp"] as? Date {
                    timestamp = timeValue
                } else if let timeInterval = locationPoint["timestamp"] as? TimeInterval {
                    timestamp = Date(timeIntervalSince1970: timeInterval)
                } else if let timeString = locationPoint["timestamp"] as? String,
                          let timeInterval = TimeInterval(timeString) {
                    timestamp = Date(timeIntervalSince1970: timeInterval)
                } else {
                    timestamp = Date()
                }
                
                // Extract heart rate and cadence if available
                let heartRate = locationPoint["heartRate"] as? Double
                let cadence = locationPoint["cadence"] as? Double
                
                // Store these values in the location's userInfo dictionary or in a custom object if needed
                var userInfo: [String: Any] = [:]
                if let heartRate = heartRate {
                    userInfo["heartRate"] = heartRate
                }
                if let cadence = cadence {
                    userInfo["cadence"] = cadence
                }
                
                let location = CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    altitude: locationPoint["altitude"] as? Double ?? 0,
                    horizontalAccuracy: locationPoint["horizontalAccuracy"] as? Double ?? 0,
                    verticalAccuracy: locationPoint["verticalAccuracy"] as? Double ?? 0,
                    timestamp: timestamp
                )
                
                // If we have additional metadata and need to store it, we can use a wrapper class
                if !userInfo.isEmpty {
                    // Store the userInfo in an associated object or custom subclass if needed
                    // For now, just log the values for verification
                    print("Location at \(lat),\(lon) has heartRate: \(heartRate ?? 0), cadence: \(cadence ?? 0)")
                }
                
                locations.append(location)
            }
        }
        
        return locations
    }
    
    private func parseCoordinateArray(_ coordinateArray: [Any]) -> [CLLocation] {
        var locations = [CLLocation]()
        
        for coordinate in coordinateArray {
            // Parse different coordinate formats
            
            // Format 1: Dictionary with lat/lon keys
            if let geoPoint = coordinate as? [String: Any] {
                var lat: Double?
                var lon: Double?
                
                if let latitude = geoPoint["latitude"] as? Double {
                    lat = latitude
                } else if let latitude = geoPoint["lat"] as? Double {
                    lat = latitude
                }
                
                if let longitude = geoPoint["longitude"] as? Double {
                    lon = longitude
                } else if let longitude = geoPoint["lon"] as? Double {
                    lon = longitude
                } else if let longitude = geoPoint["lng"] as? Double {
                    lon = longitude
                }
                
                if let lat = lat, let lon = lon, lat != 0, lon != 0 {
                    let location = CLLocation(
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        altitude: 0,
                        horizontalAccuracy: 0,
                        verticalAccuracy: 0,
                        timestamp: Date()
                    )
                    locations.append(location)
                }
            }
            // Format 2: Parse GeoPoint object (legacy Parse support)
            else if let geoPoint = coordinate as? PFGeoPoint {
                let location = CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude),
                    altitude: 0,
                    horizontalAccuracy: 0,
                    verticalAccuracy: 0,
                    timestamp: Date()
                )
                locations.append(location)
            }
            // Format 2b: Dictionary format [String: Double] (current AWS format)
            else if let geoPoint = coordinate as? [String: Double] {
                guard let lat = geoPoint["latitude"] ?? geoPoint["lat"],
                      let lon = geoPoint["longitude"] ?? geoPoint["lon"] ?? geoPoint["lng"] else {
                    continue
                }
                let location = CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    altitude: 0,
                    horizontalAccuracy: 0,
                    verticalAccuracy: 0,
                    timestamp: Date()
                )
                locations.append(location)
            }
            // Format 3: Array of coordinates [lat, lon]
            else if let coords = coordinate as? [Double], coords.count >= 2 {
                let lat = coords[0]
                let lon = coords[1]
                if lat != 0, lon != 0 {
                    let location = CLLocation(
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        altitude: 0,
                        horizontalAccuracy: 0,
                        verticalAccuracy: 0,
                        timestamp: Date()
                    )
                    locations.append(location)
                }
            }
        }
        
        return locations
    }
    
    private func updateMapWithRoute(_ locations: [CLLocation]) {
        guard !locations.isEmpty else { return }
        
        print("Updating map with \(locations.count) locations")
        
        // Verify that locations have different coordinates
        let uniqueCoordinates = Set(locations.map { "\($0.coordinate.latitude),\($0.coordinate.longitude)" })
        print("Route has \(uniqueCoordinates.count) unique coordinate points")
        
        // Store coordinates for later use
        routeCoordinates = locations.map { $0.coordinate }
        
        // Clear previous overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        // Find the actual start and finish points (may not be first/last if data isn't sorted)
        var startLocation = locations.first!
        var finishLocation = locations.last!
        
        // Attempt to sort by timestamp if available
        let sortedLocations = locations.sorted { $0.timestamp.compare($1.timestamp) == .orderedAscending }
        if sortedLocations.count >= 2 {
            startLocation = sortedLocations.first!
            finishLocation = sortedLocations.last!
        }
        
        // Create and add marathon-style start marker
        addMarathonStyleMarker(at: startLocation.coordinate, type: "start")
        
        // Create and add finish marker
        if startLocation.coordinate.latitude != finishLocation.coordinate.latitude ||
            startLocation.coordinate.longitude != finishLocation.coordinate.longitude {
            addMarathonStyleMarker(at: finishLocation.coordinate, type: "finish")
        } else {
            // If start and finish are the same, try to find a point that's far enough away
            if locations.count > 2 {
                let alternateFinish = sortedLocations[sortedLocations.count - 2]
                addMarathonStyleMarker(at: alternateFinish.coordinate, type: "finish")
            }
        }
        
        // Add milestone markers for a more marathon-like feel
        addMilestoneMarkers(locations: locations)
        
        // Add city name overlay for marathon style
        addCityNameOverlay()
        
        // Create a region that encompasses all coordinates with extra padding
        let region = createMapRegion(locations: locations)
        
        // Calculate a bearing (direction) based on start and end points
        var bearing: CLLocationDirection = 0
        if let firstLocation = sortedLocations.first, let lastLocation = sortedLocations.last {
            bearing = calculateBearing(from: firstLocation.coordinate, to: lastLocation.coordinate)
        }
        
        // Create a 3D camera with a dramatic perspective
        setMapCameraWithAngle(center: region.center,
                              spanMultiplier: 1.1,
                              regionSpan: region.span,
                              bearing: bearing)
        
        // Force mapView to update
        mapView.setNeedsDisplay()
        mapView.layoutIfNeeded()
        
        // Stop loading indicator
        loadingIndicator.stopAnimating()
        
        // Create glassy effect first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Add subtle animation to follow route - this comes after glassy effect
            self.animateRouteTracing()
            
            // Create multicolor polylines
            let polylines = self.createMulticolorPolylines(from: locations)
            
            // ANIMATE ROUTE DRAWING: Instead of adding all at once, animate polyline drawing
            self.animateRouteDrawing(polylines: polylines)
            
            // Force map to update once more after all polylines are added
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.mapView.setNeedsDisplay()
                self.mapView.layoutIfNeeded()
            }
        }
    }
    
    // New method to animate the route drawing
    private func animateRouteDrawing(polylines: [RunRoutePolyline]) {
        guard !polylines.isEmpty else { return }
        
        // Set up animation parameters
        let totalDuration: TimeInterval = 1.5  // Total animation time
        let segmentDuration = totalDuration / TimeInterval(polylines.count)
        let staggerDelay = segmentDuration * 0.5  // Overlap each segment animation
        
        // Create a simple initial animation that follows the route
        let initialCamera = mapView.camera.copy() as! MKMapCamera
        
        // Animate camera movement along the route
        let routePoints = polylines.count > 4 ? 4 : polylines.count
        var cameraAnimations = [(camera: MKMapCamera, duration: TimeInterval)]()
        
        // Create camera points along route
        for i in 0..<routePoints {
            let index = Int(Double(i) / Double(routePoints) * Double(polylines.count))
            let segment = polylines[index]
            
            // Get coordinates from polyline
            var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: segment.pointCount)
            segment.getCoordinates(&coords, range: NSRange(location: 0, length: segment.pointCount))
            
            // Create camera focused on this point
            let camera = initialCamera.copy() as! MKMapCamera
            camera.centerCoordinate = coords.last ?? initialCamera.centerCoordinate
            camera.altitude = initialCamera.altitude * 0.8 // Reduced from 0.9 to 0.8 for closer zoom during animation
            
            cameraAnimations.append((camera: camera, duration: 0.7))
        }
        
        // Return to initial view
        cameraAnimations.append((camera: initialCamera, duration: 0.5))
        
        // Function to animate camera movement
        func animateCameraSequence(_ animations: [(camera: MKMapCamera, duration: TimeInterval)], index: Int = 0) {
            guard index < animations.count else {
                // Animation sequence complete - ensure entire route is visible
                resetMapToShowEntireRoute()
                return
            }
            
            UIView.animate(withDuration: animations[index].duration, delay: 0, options: .curveEaseInOut, animations: {
                self.mapView.camera = animations[index].camera
            }, completion: { _ in
                animateCameraSequence(animations, index: index + 1)
            })
        }
        
        // Add polylines with animation
        for (index, polyline) in polylines.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(index) * staggerDelay) {
                self.mapView.addOverlay(polyline)
                
                // Add a "pulse" effect at this segment for added animation
                if index % 5 == 0 && index > 0 {
                    var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: polyline.pointCount)
                    polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
                    if let coordinate = coords.last {
                        self.addPulseEffectAt(coordinate)
                    }
                }
            }
        }
        
        // Start the camera animation after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            animateCameraSequence(cameraAnimations)
        }
    }
    
    // Reset map to show the entire route with a slight zoom out
    private func resetMapToShowEntireRoute() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Convert routeCoordinates back to CLLocation objects for region calculation
            let locations = self.routeCoordinates.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
            if !locations.isEmpty {
                // Create a region with slightly more padding for better visibility
                var region = self.createMapRegion(locations: locations)
                
                // Check if route is predominantly vertical
                let latDifference = region.span.latitudeDelta / 0.0001
                let lonDifference = region.span.longitudeDelta / 0.0001
                let isMoreVertical = latDifference > lonDifference * 1.2
                
                // Add more padding for vertical routes
                if isMoreVertical {
                    region.span.latitudeDelta *= 1.3 // More vertical padding
                    region.span.longitudeDelta *= 1.4 // Wider padding to ensure visibility
                } else {
                    // Increase zoom out for horizontal routes
                    region.span.latitudeDelta *= 1.35
                    region.span.longitudeDelta *= 1.4
                }
                
                // Smoothly transition to this region
                self.mapView.setRegion(region, animated: true)
            }
        }
    }
    
    // Add pulse animation effect at a coordinate
    private func addPulseEffectAt(_ coordinate: CLLocationCoordinate2D) {
        // Convert coordinate to point in the map view
        let point = mapView.convert(coordinate, toPointTo: mapView)
        
        // Create pulse view
        let pulseView = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        pulseView.center = point
        pulseView.backgroundColor = UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 0.8)
        pulseView.layer.cornerRadius = 10
        pulseView.alpha = 0.8
        mapView.addSubview(pulseView)
        
        // Animate the pulse
        UIView.animate(withDuration: 1.0, animations: {
            pulseView.transform = CGAffineTransform(scaleX: 3.0, y: 3.0)
            pulseView.alpha = 0
        }) { _ in
            pulseView.removeFromSuperview()
        }
    }
    
    // Add marathon-style marker instead of standard pins
    private func addMarathonStyleMarker(at coordinate: CLLocationCoordinate2D, type: String) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = type.capitalized
        
        // Add some playful subtitles for more character
        if type == "start" {
            annotation.subtitle = "Let's go! 🎬"
        } else if type == "finish" {
            annotation.subtitle = "You did it! 🏁"
        } else if type == "milestone" {
            annotation.subtitle = "Keep going! 💪"
        }
        
        mapView.addAnnotation(annotation)
    }
    
    // Add milestone markers along the route
    private func addMilestoneMarkers(locations: [CLLocation]) {
        guard locations.count >= 8 else { return } // Only add for longer routes
        
        // Find route length
        var totalDistance: CLLocationDistance = 0
        var lastLocation: CLLocation? = nil
        
        for location in locations {
            if let last = lastLocation {
                totalDistance += location.distance(from: last)
            }
            lastLocation = location
        }
        
        // Only add milestones if route is long enough (at least 500m)
        if totalDistance < 500 { return }
        
        // Convert meters to miles for distance reference
        let totalDistanceMiles = totalDistance / 1609.34
        
        // For shorter runs, place fractional mile markers appropriately
        var milestoneDistances: [Double] = []
        
        if totalDistanceMiles < 1.0 {
            // For very short runs, just put one marker halfway
            milestoneDistances = [totalDistance / 2]
        } else if totalDistanceMiles < 2.0 {
            // For runs between 1-2 miles, put marker at mile 1
            milestoneDistances = [1609.34] // 1 mile in meters
        } else {
            // For longer runs, put markers at each mile point that fits within the distance
            let wholeMarkers = Int(totalDistanceMiles)
            for i in 1...wholeMarkers {
                milestoneDistances.append(Double(i) * 1609.34)
            }
        }
        
        // Place each milestone marker at the appropriate distance
        for (index, targetDistance) in milestoneDistances.enumerated() {
            var currentDistance: CLLocationDistance = 0
            lastLocation = nil
            
            for (index, location) in locations.enumerated() {
                if let last = lastLocation {
                    let segmentDistance = location.distance(from: last)
                    if currentDistance + segmentDistance >= targetDistance {
                        // Calculate the exact position along this segment
                        let remainingDistance = targetDistance - currentDistance
                        let fraction = remainingDistance / segmentDistance
                        
                        // Interpolate between the two coordinates
                        let lat = last.coordinate.latitude + fraction * (location.coordinate.latitude - last.coordinate.latitude)
                        let lon = last.coordinate.longitude + fraction * (location.coordinate.longitude - last.coordinate.longitude)
                        
                        // Create milestone annotation
                        let milestoneCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        
                        let annotation = MKPointAnnotation()
                        annotation.coordinate = milestoneCoordinate
                        
                        // Format the mile marker title based on the actual distance
                        let mileNumber = targetDistance / 1609.34
                        if mileNumber.truncatingRemainder(dividingBy: 1) == 0 {
                            annotation.title = "Mile \(Int(mileNumber))"
                        } else {
                            // For fractional miles, show with one decimal place
                            annotation.title = String(format: "Mile %.1f", mileNumber)
                        }
                        
                        // Add some fun milestone subtitles
                        let milestoneTexts = [
                            "Keep pushing! 🔥",
                            "You've got this! 💯",
                            "Looking strong! 🚀",
                            "Fantastic pace! ⚡"
                        ]
                        annotation.subtitle = milestoneTexts[index % milestoneTexts.count]
                        
                        mapView.addAnnotation(annotation)
                        break
                    }
                    currentDistance += segmentDistance
                }
                lastLocation = location
            }
        }
    }
    
    // Add city name overlay with creative placement
    private func addCityNameOverlay() {
        // Get estimated city from the run start location
        getCityName { [weak self] cityName in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Remove any existing city labels
                self.mapView.subviews.forEach { view in
                    if view.tag == 999 { // Tag for city label
                        view.removeFromSuperview()
                    }
                }
                
                // ===== MAIN CONTAINER =====
                // Create floating container for all overlay elements
                let elementsContainer = UIView()
                elementsContainer.tag = 999
                elementsContainer.translatesAutoresizingMaskIntoConstraints = false
                self.mapView.addSubview(elementsContainer)
                
                // Fill the map view but with padding to avoid obstructing edges
                NSLayoutConstraint.activate([
                    elementsContainer.topAnchor.constraint(equalTo: self.mapView.topAnchor),
                    elementsContainer.leadingAnchor.constraint(equalTo: self.mapView.leadingAnchor),
                    elementsContainer.trailingAnchor.constraint(equalTo: self.mapView.trailingAnchor),
                    elementsContainer.bottomAnchor.constraint(equalTo: self.mapView.bottomAnchor)
                ])
                
                // ===== FLOATING INFO CARD =====
                // Create a modern floating card for user info with no separate container
                let infoCard = UIView()
                infoCard.translatesAutoresizingMaskIntoConstraints = false
                infoCard.layer.cornerRadius = 18
                elementsContainer.addSubview(infoCard)
                
                NSLayoutConstraint.activate([
                    infoCard.topAnchor.constraint(equalTo: elementsContainer.safeAreaLayoutGuide.topAnchor, constant: 16),
                    infoCard.leadingAnchor.constraint(equalTo: elementsContainer.leadingAnchor, constant: 16),
                    infoCard.widthAnchor.constraint(equalToConstant: 225),
                    infoCard.heightAnchor.constraint(equalToConstant: 85) // Reduced height from 95 to 85 for a more compact look
                ])
                
                // Add a blur effect for a modern glassy look
                let blurEffect = UIBlurEffect(style: .dark)
                let blurView = UIVisualEffectView(effect: blurEffect)
                blurView.frame = CGRect(x: 0, y: 0, width: 225, height: 85)
                blurView.layer.cornerRadius = 18
                blurView.clipsToBounds = true
                blurView.alpha = 0.5
                blurView.translatesAutoresizingMaskIntoConstraints = false
                infoCard.addSubview(blurView)
                
                NSLayoutConstraint.activate([
                    blurView.topAnchor.constraint(equalTo: infoCard.topAnchor),
                    blurView.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor),
                    blurView.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor),
                    blurView.bottomAnchor.constraint(equalTo: infoCard.bottomAnchor)
                ])
                
                // Create a gradient overlay layer for a modern look
                let gradientLayer = CAGradientLayer()
                gradientLayer.frame = CGRect(x: 0, y: 0, width: 225, height: 85)
                gradientLayer.cornerRadius = 18
                
                // Set up a modern gradient with darker colors for better contrast and modern look
                let primaryColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 0.5) // Reduced alpha
                let secondaryColor = UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 0.5) // Reduced alpha
                let accentColor = self.uicolorFromHex(rgbValue: GlobalVariables.colorDoRed).withAlphaComponent(0.2) // Reduced alpha
                gradientLayer.colors = [
                    primaryColor.cgColor,
                    secondaryColor.cgColor,
                    accentColor.cgColor
                ]
                gradientLayer.locations = [0.0, 0.65, 1.0]
                gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
                gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
                infoCard.layer.insertSublayer(gradientLayer, at: 0)
                
                // Modern glass effect with improved shadow
                infoCard.layer.shadowColor = UIColor.black.cgColor
                infoCard.layer.shadowOffset = CGSize(width: 0, height: 3)
                infoCard.layer.shadowRadius = 10
                infoCard.layer.shadowOpacity = 0.25
                infoCard.layer.masksToBounds = false
                
                // More pronounced highlight border for better visibility
                infoCard.layer.borderWidth = 0.7
                infoCard.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
                
                infoCard.clipsToBounds = true
                
                // Orange color for accent elements
                let orangeColor = UIColor(red: 247/255.0, green: 147/255.0, blue: 31/255.0, alpha: 1.0)
                
                // ===== USER PROFILE =====
                // Create profile picture component
                let profileImageView = UIImageView()
                profileImageView.contentMode = .scaleAspectFill
                profileImageView.clipsToBounds = true
                profileImageView.layer.cornerRadius = 16
                profileImageView.layer.borderColor = UIColor.white.cgColor
                profileImageView.layer.borderWidth = 1.2
                profileImageView.translatesAutoresizingMaskIntoConstraints = false
                
                // Set profile image with fallback
                if let userProfileImage = GlobalVariables.currentUserModel.profilePicture {
                    profileImageView.image = userProfileImage
                } else {
                    // Use a system image as fallback
                    if #available(iOS 13.0, *) {
                        profileImageView.image = UIImage(systemName: "person.crop.circle.fill")
                        profileImageView.tintColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
                    } else {
                        // For older iOS versions
                        let defaultImage = UIImage(named: "profile_placeholder")
                        profileImageView.image = defaultImage ?? UIImage()
                        profileImageView.backgroundColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
                    }
                }
                
                infoCard.addSubview(profileImageView)
                
                // ===== USERNAME =====
                // Add username with modern styling
                let usernameLabel = UILabel()
                usernameLabel.text = "@\(GlobalVariables.currentUserModel.userName?.lowercased() ?? "runner")"
                usernameLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
                usernameLabel.textColor = .white
                usernameLabel.textAlignment = .left
                usernameLabel.translatesAutoresizingMaskIntoConstraints = false
                infoCard.addSubview(usernameLabel)
                
                // ===== DATE =====
                // Add date with modern styling
                let dateLabel = UILabel()
                dateLabel.text = self.formatDate()
                dateLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
                dateLabel.textColor = UIColor.white.withAlphaComponent(0.8)
                dateLabel.textAlignment = .left
                dateLabel.translatesAutoresizingMaskIntoConstraints = false
                infoCard.addSubview(dateLabel)
                
                // ===== LOCATION INFO =====
                // Location stack (icon + city name)
                let locationStack = UIStackView()
                locationStack.axis = .horizontal
                locationStack.alignment = .center
                locationStack.spacing = 6
                locationStack.translatesAutoresizingMaskIntoConstraints = false
                infoCard.addSubview(locationStack)
                
                // Location pin icon
                let locationIcon = UIImageView()
                if #available(iOS 13.0, *) {
                    locationIcon.image = UIImage(systemName: "mappin.and.ellipse")
                    locationIcon.tintColor = orangeColor
                } else {
                    // Fallback icon for older iOS
                    locationIcon.image = UIImage(named: "location_pin")?.withRenderingMode(.alwaysTemplate)
                    locationIcon.tintColor = orangeColor
                }
                locationIcon.contentMode = .scaleAspectFit
                locationIcon.translatesAutoresizingMaskIntoConstraints = false
                locationStack.addArrangedSubview(locationIcon)
                
                NSLayoutConstraint.activate([
                    locationIcon.widthAnchor.constraint(equalToConstant: 16),
                    locationIcon.heightAnchor.constraint(equalToConstant: 16)
                ])
                
                // City name label
                let cityLabel = UILabel()
                cityLabel.text = cityName
                cityLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
                cityLabel.textColor = .white
                cityLabel.textAlignment = .left
                locationStack.addArrangedSubview(cityLabel)
                
                // ===== WEATHER INFO =====
                // Add weather info if available
                var weatherStack: UIStackView?
                if let runLog = self.runData as? RunLog, let weather = runLog.weather {
                    // Weather stack (icon + weather info)
                    let wStack = UIStackView()
                    weatherStack = wStack
                    wStack.axis = .horizontal
                    wStack.alignment = .center
                    wStack.spacing = 6
                    wStack.translatesAutoresizingMaskIntoConstraints = false
                    infoCard.addSubview(wStack)
                    
                    // Weather icon
                    let weatherIcon = UIImageView()
                    if #available(iOS 13.0, *) {
                        // Determine icon based on weather condition
                        let condition = weather.lowercased()
                        let iconName: String
                        
                        if condition.contains("clear") || condition.contains("sunny") {
                            iconName = "sun.max.fill"
                        } else if condition.contains("cloud") {
                            iconName = condition.contains("partly") ? "cloud.sun.fill" : "cloud.fill"
                        } else if condition.contains("rain") {
                            iconName = condition.contains("light") ? "cloud.drizzle.fill" : "cloud.rain.fill"
                        } else if condition.contains("storm") || condition.contains("thunder") {
                            iconName = "cloud.bolt.rain.fill"
                        } else if condition.contains("snow") || condition.contains("flurr") {
                            iconName = "cloud.snow.fill"
                        } else if condition.contains("fog") || condition.contains("mist") {
                            iconName = "cloud.fog.fill"
                        } else if condition.contains("wind") {
                            iconName = "wind"
                        } else if condition.contains("haz") || condition.contains("smoke") {
                            iconName = "smoke.fill"
                        } else {
                            iconName = "thermometer"
                        }
                        
                        weatherIcon.image = UIImage(systemName: iconName)
                        
                        // Determine color based on weather condition
                        let iconColor: UIColor
                        if condition.contains("clear") || condition.contains("sunny") {
                            iconColor = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0) // Yellow
                        } else if condition.contains("cloud") {
                            iconColor = UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0) // Gray
                        } else if condition.contains("rain") {
                            iconColor = UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0) // Blue
                        } else if condition.contains("storm") || condition.contains("thunder") {
                            iconColor = UIColor(red: 0.4, green: 0.4, blue: 0.8, alpha: 1.0) // Dark Blue
                        } else if condition.contains("snow") || condition.contains("flurr") {
                            iconColor = UIColor(red: 0.8, green: 0.8, blue: 1.0, alpha: 1.0) // Light Blue
                        } else {
                            iconColor = UIColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0) // Cyan
                        }
                        
                        weatherIcon.tintColor = iconColor
                    } else {
                        weatherIcon.image = UIImage(named: "weather_icon")?.withRenderingMode(.alwaysTemplate)
                        weatherIcon.tintColor = UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)
                    }
                    weatherIcon.contentMode = .scaleAspectFit
                    weatherIcon.translatesAutoresizingMaskIntoConstraints = false
                    wStack.addArrangedSubview(weatherIcon)
                    
                    NSLayoutConstraint.activate([
                        weatherIcon.widthAnchor.constraint(equalToConstant: 16),
                        weatherIcon.heightAnchor.constraint(equalToConstant: 16)
                    ])
                    
                    // Weather description label
                    let weatherLabel = UILabel()
                    weatherLabel.text = weather
                    weatherLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
                    weatherLabel.textColor = .white
                    weatherLabel.textAlignment = .left
                    wStack.addArrangedSubview(weatherLabel)
                    
                    // Temperature label if available
                    if let temp = runLog.temperature {
                        let tempLabel = UILabel()
                        tempLabel.text = "\(Int(temp))°"
                        tempLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
                        tempLabel.textColor = .white
                        tempLabel.textAlignment = .left
                        wStack.addArrangedSubview(tempLabel)
                    }
                }
                
                // ===== APP LOGO =====
                // Add logo with modern styling
                let logoImageView = UIImageView()
                logoImageView.contentMode = .scaleAspectFit
                logoImageView.image = UIImage(named: "logo_45")
                logoImageView.tintColor = UIColor.white
                logoImageView.translatesAutoresizingMaskIntoConstraints = false
                infoCard.addSubview(logoImageView)
                
                // Horizontal layout within the card
                NSLayoutConstraint.activate([
                    // Profile image on the left
                    profileImageView.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor, constant: 12),
                    profileImageView.topAnchor.constraint(equalTo: infoCard.topAnchor, constant: 10), // Reduced top margin
                    profileImageView.widthAnchor.constraint(equalToConstant: 32), // Slightly smaller image
                    profileImageView.heightAnchor.constraint(equalToConstant: 32),
                    
                    // Username next to profile
                    usernameLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 10),
                    usernameLabel.topAnchor.constraint(equalTo: profileImageView.topAnchor, constant: -4),
                    usernameLabel.trailingAnchor.constraint(equalTo: logoImageView.leadingAnchor, constant: -8),
                    
                    // Date below username
                    dateLabel.leadingAnchor.constraint(equalTo: usernameLabel.leadingAnchor),
                    dateLabel.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 0),
                    dateLabel.trailingAnchor.constraint(equalTo: usernameLabel.trailingAnchor),
                    
                    // Location info below profile
                    locationStack.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor, constant: 12),
                    locationStack.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 8), // Reduced spacing
                    locationStack.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor, constant: -12),
                    
                    // Logo on the far right
                    logoImageView.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor, constant: -12),
                    logoImageView.topAnchor.constraint(equalTo: infoCard.topAnchor, constant: 10), // Reduced top margin
                    logoImageView.widthAnchor.constraint(equalToConstant: 22), // Slightly smaller logo
                    logoImageView.heightAnchor.constraint(equalToConstant: 22)
                ])
                
                // Add weather constraints if available - tightened spacing
                if let weatherStack = weatherStack {
                    NSLayoutConstraint.activate([
                        weatherStack.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor, constant: 12),
                        weatherStack.topAnchor.constraint(equalTo: locationStack.bottomAnchor, constant: 4), // Reduced spacing
                        weatherStack.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor, constant: -12)
                    ])
                }
                
                // ===== ANIMATE ELEMENTS =====
                // No animation for infoCard as requested
            }
        }
    }
    
    // Helper method to get route bounds for better city name placement
    private func getRouteBounds() -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude
        
        for coordinate in routeCoordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        
        return (minLat, maxLat, minLon, maxLon)
    }
    
    // Get city name from coordinates (first try geocoding, then fallback to default)
    private func getCityName(completion: @escaping (String) -> Void) {
        guard let firstLocation = routeCoordinates.first else {
            completion("YOUR RUN")
            return
        }
        
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: firstLocation.latitude, longitude: firstLocation.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")
                completion("YOUR RUN")
                return
            }
            
            if let placemark = placemarks?.first, let city = placemark.locality {
                completion(city.uppercased())
            } else if let placemark = placemarks?.first, let area = placemark.administrativeArea {
                completion(area.uppercased())
            } else {
                completion("YOUR RUN")
            }
        }
    }
    
    // Create multicolor polylines with electric blue glow effect
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
            segment.color = glowingBlueColor(speed: speed,
                                             midSpeed: midSpeed,
                                             slowestSpeed: minSpeed,
                                             fastestSpeed: maxSpeed)
            
            // Set thicker line width for visibility
            let speedRatio = (speed - minSpeed) / (maxSpeed - minSpeed + 0.1)
            segment.lineWidth = 5.0 + CGFloat(speedRatio) * 3.0 // Width range: 5.0-8.0 for stronger visibility
            
            // Add stronger glow for electric appearance
            segment.glowRadius = CGFloat(4.0 + speedRatio * 4.0) // Larger glow: 4.0-8.0
            segment.glowColor = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.8) // Orange glow
            
            segments.append(segment)
        }
        
        return segments
    }
    
    // Blue color theme with speed variation - enhanced for electric blue effect
    private func glowingBlueColor(speed: Double, midSpeed: Double, slowestSpeed: Double, fastestSpeed: Double) -> UIColor {
        // Updated color palette with more vibrant oranges and reds to match Do branding
        enum ElectricColors {
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
            red = ElectricColors.slow_red + ratio * (ElectricColors.mid_red - ElectricColors.slow_red)
            green = ElectricColors.slow_green + ratio * (ElectricColors.mid_green - ElectricColors.slow_green)
            blue = ElectricColors.slow_blue + ratio * (ElectricColors.mid_blue - ElectricColors.slow_blue)
        } else {
            let ratio = CGFloat((speed - midSpeed) / (fastestSpeed - midSpeed))
            red = ElectricColors.mid_red + ratio * (ElectricColors.fast_red - ElectricColors.mid_red)
            green = ElectricColors.mid_green + ratio * (ElectricColors.fast_green - ElectricColors.mid_green)
            blue = ElectricColors.mid_blue + ratio * (ElectricColors.fast_blue - ElectricColors.mid_blue)
        }
        
        return UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
    
    private func generateShareImage() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // Delay to ensure map is rendered
            // Create image view for taking screenshot
            let screenshot = self.takeScreenshot()
            self.shareImage = screenshot
        }
    }
    
    private func takeScreenshot() -> UIImage? {
        // Create screenshot of just the map view, not the entire screen
        UIGraphicsBeginImageContextWithOptions(mapView.bounds.size, false, UIScreen.main.scale)
        
        // Ensure map view is properly laid out before capturing
        mapView.layoutIfNeeded()
        
        // Render the map view into the context
        mapView.drawHierarchy(in: mapView.bounds, afterScreenUpdates: true)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
    
    private func showError(_ message: String) {
        let banner = FloatingNotificationBanner(title: "Error", subtitle: message, style: .danger)
        banner.show(bannerPosition: .top, cornerRadius: 8)
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func shareButtonTapped() {
        // Generate a new screenshot in case the UI has changed
        let currentScreenshot = takeScreenshot()
        
        guard let imageToShare = currentScreenshot ?? shareImage else {
            showError("No image available to share")
            return
        }
        
        // Create activity view controller
        let activityViewController = UIActivityViewController(
            activityItems: [imageToShare],
            applicationActivities: nil
        )
        
        // Configure iPad presentation if needed
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = shareButton
            popoverController.sourceRect = shareButton.bounds
        }
        
        // Present the view controller
        present(activityViewController, animated: true)
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        
        // Zoom in on tapped location
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: mapView.region.span.latitudeDelta / 2,
                longitudeDelta: mapView.region.span.longitudeDelta / 2
            )
        )
        
        mapView.setRegion(region, animated: true)
    }
    
    private func applyGradientOverlay(to imageView: UIImageView) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.7).cgColor
        ]
        gradientLayer.locations = [0.4, 1.0]
        gradientLayer.frame = imageView.bounds
        
        if let existingGradient = imageView.layer.sublayers?.first(where: { $0 is CAGradientLayer }) {
            existingGradient.removeFromSuperlayer()
        }
        
        imageView.layer.addSublayer(gradientLayer)
    }
    
    private func createMockLocations() -> [CLLocation] {
        // Create a sample route in New York City's Central Park
        let centralPark = [
            CLLocation(latitude: 40.769397, longitude: -73.976328),
            CLLocation(latitude: 40.773405, longitude: -73.972305),
            CLLocation(latitude: 40.778152, longitude: -73.969837),
            CLLocation(latitude: 40.782852, longitude: -73.965074),
            CLLocation(latitude: 40.785274, longitude: -73.958722),
            CLLocation(latitude: 40.782755, longitude: -73.954301),
            CLLocation(latitude: 40.776510, longitude: -73.951683),
            CLLocation(latitude: 40.771367, longitude: -73.955674),
            CLLocation(latitude: 40.767474, longitude: -73.961811),
            CLLocation(latitude: 40.764896, longitude: -73.967648),
            CLLocation(latitude: 40.766946, longitude: -73.973699),
            CLLocation(latitude: 40.769397, longitude: -73.976328)
        ]
        
        return centralPark
    }
    
    // MARK: - MKMapViewDelegate Methods
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? RunRoutePolyline else {
            return MKOverlayRenderer(overlay: overlay)
        }
        
        let renderer = MKPolylineRenderer(polyline: polyline)
        renderer.strokeColor = polyline.color
        renderer.lineWidth = polyline.lineWidth
        
        // Use a solid line for the electric blue effect
        renderer.lineDashPattern = nil
        
        // Set higher alpha for more vibrant appearance
        renderer.alpha = 1.0
        
        // Add line join style for smoother corners
        renderer.lineJoin = .round
        renderer.lineCap = .round
        
        return renderer
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !annotation.isKind(of: MKUserLocation.self) else { return nil }
        
        guard let title = annotation.title else { return nil }
        
        if title == "Start" {
            let identifier = "StartMarker"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                
                let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
                imageView.contentMode = .scaleAspectFit
                annotationView?.leftCalloutAccessoryView = imageView
            } else {
                annotationView?.annotation = annotation
            }
            
            // Marathon-style starting flag
            annotationView?.markerTintColor = UIColor(red: 0.0, green: 0.8, blue: 0.4, alpha: 1.0)
            annotationView?.glyphImage = UIImage(systemName: "flag.circle.fill")
            annotationView?.glyphTintColor = .white
            annotationView?.displayPriority = .required
            
            // Add a custom callout button
            let button = UIButton(type: .detailDisclosure)
            button.tintColor = UIColor(red: 0.0, green: 0.8, blue: 0.4, alpha: 1.0)
            annotationView?.rightCalloutAccessoryView = button
            
            // Larger size for visibility
            annotationView?.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
            
            return annotationView
            
        } else if title == "Finish" {
            let identifier = "FinishMarker"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                
                let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
                imageView.contentMode = .scaleAspectFit
                annotationView?.leftCalloutAccessoryView = imageView
            } else {
                annotationView?.annotation = annotation
            }
            
            // Marathon-style finish flag
            annotationView?.markerTintColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
            annotationView?.glyphImage = UIImage(systemName: "flag.checkered")
            annotationView?.glyphTintColor = .white
            annotationView?.displayPriority = .required
            
            // Larger size for visibility
            annotationView?.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
            
            return annotationView
        } else if title?.contains("Mile") == true {
            // Special handling for mile markers
            let identifier = "MileMarker"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // Marathon-style mile marker
            annotationView?.markerTintColor = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0) // Gold
            annotationView?.glyphImage = UIImage(systemName: "star.fill")
            annotationView?.glyphTintColor = .white
            annotationView?.displayPriority = .required
            
            // Make it slightly larger
            annotationView?.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            
            return annotationView
        }
        
        return nil
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Force mapView to refresh completely
        mapView.setNeedsDisplay()
        mapView.layoutIfNeeded()
        
        // Ensure the overlays are refreshed
        if !mapView.overlays.isEmpty {
            // Temporarily hide and show overlays to force redraw
            let overlays = mapView.overlays
            mapView.removeOverlays(overlays)
            
            // Re-add them after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                for overlay in overlays {
                    self.mapView.addOverlay(overlay)
                }
                
                // Refresh stats using calculated data
                self.populateRunStats()
            }
        } else if let runData = runData as? RunLog, !routeCoordinates.isEmpty {
            // If we don't have overlays but should, recreate them
            let locations = parseLocationsFromRunData()
            if !locations.isEmpty {
                // Create multicolor polylines
                let polylines = self.createMulticolorPolylines(from: locations)
                
                // Add polylines immediately
                for polyline in polylines {
                    self.mapView.addOverlay(polyline)
                }
                
                // Refresh stats using calculated data
                self.populateRunStats()
            }
        }
        
        // If we have coordinates but the map is zoomed in too close, reset the region
        if !routeCoordinates.isEmpty && mapView.annotations.count > 0 {
            // Convert routeCoordinates back to CLLocation objects for region calculation
            let locations = routeCoordinates.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
            let region = createMapRegion(locations: locations)
            mapView.setRegion(region, animated: true)
        }
    }
    
    private func setupConstraints() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        imageContainerView.translatesAutoresizingMaskIntoConstraints = false
        mapImageView.translatesAutoresizingMaskIntoConstraints = false
        runImageView.translatesAutoresizingMaskIntoConstraints = false
        statsContainerView.translatesAutoresizingMaskIntoConstraints = false
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Close button
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
            
            // Image container
            imageContainerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            imageContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            imageContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            imageContainerView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.75),
            
            // Map image view (full size of container)
            mapImageView.topAnchor.constraint(equalTo: imageContainerView.topAnchor),
            mapImageView.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor),
            mapImageView.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor),
            mapImageView.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor),
            
            // Run image view (just shows the runner icon)
            runImageView.centerXAnchor.constraint(equalTo: imageContainerView.centerXAnchor),
            runImageView.centerYAnchor.constraint(equalTo: imageContainerView.centerYAnchor),
            runImageView.widthAnchor.constraint(equalToConstant: 100),
            runImageView.heightAnchor.constraint(equalToConstant: 100),
            
            // Stats container - increase height to prevent text clipping
            statsContainerView.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor),
            statsContainerView.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor),
            statsContainerView.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor),
            statsContainerView.heightAnchor.constraint(equalToConstant: 110), // Increased from 90 to 110
            
            // Share button
            shareButton.topAnchor.constraint(equalTo: imageContainerView.bottomAnchor, constant: 24),
            shareButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            shareButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            shareButton.heightAnchor.constraint(equalToConstant: 50),
            shareButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            
            // Loading indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: imageContainerView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: imageContainerView.centerYAnchor)
        ])
    }
    
    // Create a region that shows all locations with padding
    private func createMapRegion(locations: [CLLocation]) -> MKCoordinateRegion {
        guard let firstLocation = locations.first else {
            // Default to a region around NYC if no locations
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        
        var minLat = firstLocation.coordinate.latitude
        var maxLat = firstLocation.coordinate.latitude
        var minLon = firstLocation.coordinate.longitude
        var maxLon = firstLocation.coordinate.longitude
        
        for location in locations {
            minLat = min(minLat, location.coordinate.latitude)
            maxLat = max(maxLat, location.coordinate.latitude)
            minLon = min(minLon, location.coordinate.longitude)
            maxLon = max(maxLon, location.coordinate.longitude)
        }
        
        // Calculate center
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        // Check if this might be an out-and-back route where path is retraced
        let isLinearRoute = isLikelyOutAndBackRoute(locations)
        
        // Check if this is primarily a vertical route
        let latDifference = maxLat - minLat
        let lonDifference = maxLon - minLon
        let isVerticalRoute = latDifference > lonDifference * 1.5
        
        // Calculate span with better padding for vertical routes
        // Increase padding for vertical routes to ensure they're fully visible
        let latMultiplier = isVerticalRoute ? 1.4 : 1.2 // Higher multiplier for vertical routes
        let lonMultiplier = isVerticalRoute ? 1.5 : 1.25 // Wider view for vertical routes
        
        // Ensure minimum span to avoid extreme zoom on small routes
        let minimumLatDelta = isVerticalRoute ? 0.002 : 0.0015
        let minimumLonDelta = 0.0015
        
        // Calculate span, giving more space to the dominant dimension
        let latDelta = max(latDifference * latMultiplier, minimumLatDelta)
        let lonDelta = max(lonDifference * lonMultiplier, minimumLonDelta)
        
        let span = MKCoordinateSpan(
            latitudeDelta: latDelta,
            longitudeDelta: lonDelta
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
    
    // Helper to detect if a route is likely an out-and-back (same path twice)
    private func isLikelyOutAndBackRoute(_ locations: [CLLocation]) -> Bool {
        // Simple heuristic: check if start and end are close to each other
        // but the route goes at least somewhat far from both
        
        guard locations.count > 10 else { return false }
        
        let start = locations.first!
        let end = locations.last!
        let startEndDistance = start.distance(from: end)
        
        // Find the point furthest from start
        var maxDistanceFromStart: CLLocationDistance = 0
        for location in locations {
            let distance = start.distance(from: location)
            maxDistanceFromStart = max(maxDistanceFromStart, distance)
        }
        
        // If the max distance is significantly larger than the start-end distance,
        // it's likely an out-and-back route
        return maxDistanceFromStart > startEndDistance * 3 && startEndDistance < 300 // 300m threshold
    }
    
    // Calculate bearing between two coordinates (used for camera heading)
    private func calculateBearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let lon2 = end.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        
        let degreesBearing = radiansBearing * 180 / .pi
        return fmod(degreesBearing + 360, 360)
    }
    
    // Animation to trace the route with enhanced electric glow effect
    private func animateRouteTracing() {
        // Add overlay view for glow effect
        if !mapView.overlays.isEmpty {
            let overlayContainerView = UIView(frame: mapView.bounds)
            overlayContainerView.backgroundColor = UIColor.clear
            overlayContainerView.tag = 888 // Tag for identification
            mapView.addSubview(overlayContainerView)
            
            // Create pulsing effect for route to simulate electricity
            UIView.animate(withDuration: 1.5, delay: 0.2, options: [.curveEaseInOut, .autoreverse, .repeat], animations: {
                // Create electric pulsing by changing alpha
                overlayContainerView.alpha = 0.85
            }, completion: { _ in
                overlayContainerView.alpha = 1.0
            })
            
            // Add a more prominent orange glow to the entire map
            let glowLayer = CALayer()
            glowLayer.frame = mapView.bounds
            glowLayer.backgroundColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.12).cgColor
            glowLayer.shadowColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.7).cgColor
            glowLayer.shadowOffset = CGSize.zero
            glowLayer.shadowRadius = 30
            glowLayer.shadowOpacity = 1.0
            glowLayer.cornerRadius = 10
            overlayContainerView.layer.insertSublayer(glowLayer, at: 0)
            
            // Add a second pulsing animation for more dynamic effect
            let pulseAnimation = CABasicAnimation(keyPath: "shadowOpacity")
            pulseAnimation.duration = 1.2
            pulseAnimation.fromValue = 0.7
            pulseAnimation.toValue = 1.0
            pulseAnimation.autoreverses = true
            pulseAnimation.repeatCount = Float.infinity
            glowLayer.add(pulseAnimation, forKey: "pulseShadow")
        }
    }
    
    // Update UI with run data statistics
    private func updateStatsWithRunData() {
        // This method is no longer needed as populateRunStats handles this
        // Just call populateRunStats to ensure stats are shown
        populateRunStats()
    }
    
    // Extract total distance from run data
    private func extractTotalDistance() -> Double? {
        // Check if runData is a dictionary
        if let dataDict = runData as? [String: Any] {
            // Try looking for distance in the main dictionary with various keys
            for key in ["distance", "totalDistance", "Distance", "total_distance", "dist"] {
                if let distance = dataDict[key] as? Double {
                    return distance
                } else if let distance = dataDict[key] as? String, let distanceValue = Double(distance) {
                    return distanceValue
                } else if let distance = dataDict[key] as? Int {
                    return Double(distance)
                }
            }
            
            // Try looking in nested dictionaries
            for containerKey in ["stats", "data", "summary", "details", "metadata", "attachment", "routeInfo"] {
                if let nestedDict = dataDict[containerKey] as? [String: Any] {
                    for key in ["distance", "totalDistance", "Distance", "total_distance", "dist"] {
                        if let distance = nestedDict[key] as? Double {
                            return distance
                        } else if let distance = nestedDict[key] as? String, let distanceValue = Double(distance) {
                            return distanceValue
                        } else if let distance = nestedDict[key] as? Int {
                            return Double(distance)
                        }
                    }
                }
            }
        }
        // Check if runData is a RunLog
        else if let runLog = runData as? RunLog {
            if let distance = runLog.distance, let distanceValue = Double(distance) {
                return distanceValue
            }
        }
        // Check if runData is a LocationActivityLog
        else if let activityLog = runData as? LocationActivityLog {
            if let distance = activityLog.distance, let distanceValue = Double(distance) {
                return distanceValue
            }
        }
        
        // If we couldn't find distance in runData, calculate from coordinates
        if !routeCoordinates.isEmpty {
            var totalDistance: CLLocationDistance = 0
            var lastLocation: CLLocationCoordinate2D? = nil
            
            for coordinate in routeCoordinates {
                if let last = lastLocation {
                    let lastLoc = CLLocation(latitude: last.latitude, longitude: last.longitude)
                    let currentLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    totalDistance += lastLoc.distance(from: currentLoc)
                }
                lastLocation = coordinate
            }
            
            if totalDistance > 0 {
                return totalDistance
            }
        }
        
        return nil
    }
    
    // Dedicated method to set up 3D camera with proper angle
    private func setMapCameraWithAngle(center: CLLocationCoordinate2D,
                                       spanMultiplier: Double,
                                       regionSpan: MKCoordinateSpan,
                                       bearing: CLLocationDirection) {
        // Create standard camera
        let camera = MKMapCamera()
        
        // Calculate the distance in meters based on span
        let latDelta = regionSpan.latitudeDelta * spanMultiplier
        let lonDelta = regionSpan.longitudeDelta * spanMultiplier
        
        // Convert from coordinate span to meters
        let metersPerDegreeLatitude = 111_320.0 // approximate meters per degree of latitude
        let metersPerDegreeLongitude = 111_320.0 * cos(center.latitude * .pi / 180.0)
        
        // Calculate visible area dimensions
        let visibleHeightMeters = latDelta * metersPerDegreeLatitude
        let visibleWidthMeters = lonDelta * metersPerDegreeLongitude
        
        // Determine route direction and offset the center slightly to enhance 3D perspective
        // Moving the center slightly in the direction opposite to viewing makes the 3D effect more dramatic
        let offsetMultiplier = 0.3 // Increased from 0.2 to 0.3 for more dramatic offset
        
        // Calculate offset based on bearing (direction)
        let bearingRadians = (bearing * .pi) / 180.0
        let latitudeOffset = -sin(bearingRadians) * regionSpan.latitudeDelta * offsetMultiplier
        let longitudeOffset = -cos(bearingRadians) * regionSpan.longitudeDelta * offsetMultiplier
        
        // Apply offset to create more dramatic 3D effect
        let offsetCenter = CLLocationCoordinate2D(
            latitude: center.latitude + latitudeOffset,
            longitude: center.longitude + longitudeOffset
        )
        
        // Configure center coordinate with offset
        camera.centerCoordinate = offsetCenter
        
        // Set the altitude to show the entire route with less space around it for tighter zoom
        camera.altitude = max(visibleHeightMeters, visibleWidthMeters) * 0.6 // Reduced from 0.75 to 0.6 for closer zoom
        
        // Set a more extreme pitch angle (85 degrees for maximum 3D effect)
        camera.pitch = 80 // Slightly reduced from 85 to 80 to see more of the route
        
        // Set camera heading to follow route direction
        camera.heading = bearing
        
        // Apply camera settings with animation
        DispatchQueue.main.async {
            // Use a sequence of animations for more reliable results and dramatic effect
            
            // First set an initial high altitude camera to create zoom-in effect
            let initialCamera = camera.copy() as! MKMapCamera
            initialCamera.altitude *= 1.5 // Increased from 1.3 to 1.5 for more dramatic effect
            initialCamera.pitch = 65 // Start with less pitch
            self.mapView.setCamera(initialCamera, animated: false)
            
            // Then animate to the final dramatic position
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Enable 3D buildings and landmarks for additional depth
                if #available(iOS 11.0, *) {
                    self.mapView.pointOfInterestFilter = .excludingAll
                    self.mapView.showsBuildings = true
                    self.mapView.showsCompass = false
                }
                
                // Create slight camera shake effect for dramatic entrance
                let slightlyOffCamera = camera.copy() as! MKMapCamera
                slightlyOffCamera.altitude *= 1.1
                slightlyOffCamera.pitch = 80
                self.mapView.setCamera(slightlyOffCamera, animated: true)
                
                // Finally, settle into perfect position
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.mapView.setCamera(camera, animated: true)
                    
                    // Add 3D enhancement effects after camera is set
                    self.enhance3DMapAppearance()
                }
            }
        }
    }
    
    // New function to enhance 3D appearance with visual effects
    private func enhance3DMapAppearance() {
        // Add shadow overlay at the bottom to enhance depth perception
        let shadowOverlay = UIView(frame: CGRect(x: 0, 
                                                y: mapView.bounds.height * 0.7,
                                                width: mapView.bounds.width,
                                                height: mapView.bounds.height * 0.3))
        
        // Create gradient from transparent to black
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = shadowOverlay.bounds
        gradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.4).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        shadowOverlay.layer.insertSublayer(gradientLayer, at: 0)
        shadowOverlay.backgroundColor = UIColor.clear
        
        // Make sure it resizes with the map
        shadowOverlay.autoresizingMask = [.flexibleWidth, .flexibleTopMargin, .flexibleHeight]
        
        // Add to map with a tag so we can find it later if needed
        shadowOverlay.tag = 777
        mapView.addSubview(shadowOverlay)
        
        // Make sure it's behind any other map UI elements but in front of the map itself
        mapView.insertSubview(shadowOverlay, at: 1)
    }
    
    // Format the date for display
    private func formatDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        
        if let runLog = runData as? RunLog, let createdAt = runLog.createdAt {
            return dateFormatter.string(from: createdAt)
        } else if let dataDict = runData as? [String: Any], let createdAtStr = dataDict["createdAt"] as? String {
            // Try to parse the date string
            let isoFormatter = ISO8601DateFormatter()
            if let date = isoFormatter.date(from: createdAtStr) {
                return dateFormatter.string(from: date)
            }
        }
        
        // Fallback to today's date if we can't find a date in the run data
        return dateFormatter.string(from: Date())
    }
    
    // Add this method to populate run statistics
    private func populateRunStats() {
        // Remove any existing stats views
        statsContainerView.subviews.forEach { $0.removeFromSuperview() }
        
        // Use clear background for container to let map show through
        statsContainerView.backgroundColor = UIColor.clear
        
        
        // Add dummy stats for testing if the runData is not providing what we need
        var stats = extractRunStats()
        
        // If there are no stats, add some dummy data for testing UI
        if stats.isEmpty {
            print("WARNING: No stats extracted. Adding dummy stats for testing.")
            stats = [
                "Distance": "2.5 km",
                "Time": "25:30",
                "Pace": "5:15 /km",
                "Calories": "230 kcal",
                "Elevation": "43 m"
            ]
        }
        
        // Define preferred display order and organize the stats
        let displayOrder = ["Distance", "Time", "Pace", "Calories", "Elevation", "Heart Rate"]
        var orderedStats: [(String, String)] = []
        
        // Add stats in preferred order
        for key in displayOrder {
            if let value = stats[key] {
                orderedStats.append((key, value))
            }
        }
        
        // Add any remaining stats
        for (key, value) in stats where !displayOrder.contains(key) {
            orderedStats.append((key, value))
        }
        
        // Print stats for debugging
        print("Found \(orderedStats.count) stats to display:")
        for (key, value) in orderedStats {
            print("- \(key): \(value)")
        }
        
        // If no stats available, show message
        if orderedStats.isEmpty {
            let messageLabel = UILabel()
            messageLabel.text = "No stats available"
            messageLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            messageLabel.textColor = .white
            messageLabel.textAlignment = .center
            messageLabel.translatesAutoresizingMaskIntoConstraints = false
            statsContainerView.addSubview(messageLabel)
            
            NSLayoutConstraint.activate([
                messageLabel.centerXAnchor.constraint(equalTo: statsContainerView.centerXAnchor),
                messageLabel.centerYAnchor.constraint(equalTo: statsContainerView.centerYAnchor)
            ])
            
            return
        }
        
        // Create a simple container for the stats
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        containerView.layer.cornerRadius = 16
        statsContainerView.addSubview(containerView)
        
        // Position at the bottom with fixed height
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: statsContainerView.bottomAnchor, constant: -24),
            containerView.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        // Create a scroll view for horizontal scrolling
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        containerView.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Create a horizontal stack view
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 10),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -10),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -10),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor, constant: -20)
        ])
        
        // Create stats views
        for (title, value) in orderedStats {
            let statView = createSimpleStatView(title: title, value: value)
            stackView.addArrangedSubview(statView)
        }
        
        // Set scroll view content size
        let statWidth: CGFloat = 100
        scrollView.contentSize = CGSize(width: CGFloat(orderedStats.count) * (statWidth + 10) + 20, height: scrollView.bounds.height)
    }
    
    // Extract run statistics from the runData - simplified to only handle RunLog
    private func extractRunStats() -> [String: String] {
        var stats = [String: String]()
        
        if let runLog = runData as? RunLog {
            print("Extracting from RunLog")
            
            // Distance - with improved parsing and calculation from actual route data
            if let distance = runLog.distance {
                if let distanceValue = Double(distance) {
                    // Distance is already in miles, convert to meters for our formatter
                    let distanceInMeters = distanceValue * 1609.34 // miles to meters conversion
                    stats["Distance"] = UserPreferences.formatDistanceWithPreferredUnit(distance: distanceInMeters)
                } else if distance.contains("mi") {
                    // Parse "3.5 mi" format
                    let distStr = distance.replacingOccurrences(of: "mi", with: "").trimmingCharacters(in: .whitespaces)
                    if let miles = Double(distStr) {
                        let distanceInMeters = miles * 1609.34 // miles to meters conversion
                            stats["Distance"] = UserPreferences.formatDistanceWithPreferredUnit(distance: distanceInMeters)
                        } else {
                            stats["Distance"] = distance
                    }
                } else if distance.contains("km") {
                    // Parse "5.0 km" format
                    let distStr = distance.replacingOccurrences(of: "km", with: "").trimmingCharacters(in: .whitespaces)
                    if let kilometers = Double(distStr) {
                        let distanceInMeters = kilometers * 1000 // km to meters conversion
                        stats["Distance"] = UserPreferences.formatDistanceWithPreferredUnit(distance: distanceInMeters)
                    } else {
                        stats["Distance"] = distance
                    }
                } else {
                    // If we couldn't parse it, calculate from route data
                    let calculatedDistance = calculateDistanceFromRoute()
                    if calculatedDistance > 0 {
                        stats["Distance"] = UserPreferences.formatDistanceWithPreferredUnit(distance: calculatedDistance)
                    } else {
                        stats["Distance"] = distance
                    }
                }
            } else {
                // If no distance provided, calculate from route
                let calculatedDistance = calculateDistanceFromRoute()
                if calculatedDistance > 0 {
                    stats["Distance"] = UserPreferences.formatDistanceWithPreferredUnit(distance: calculatedDistance)
                }
            }
            
            // Duration - with improved parsing
            if let duration = runLog.duration {
                if let durationValue = TimeInterval(duration) {
                    // Direct conversion worked
                    stats["Time"] = formatTimeInterval(durationValue)
                } else {
                    // For MM:SS format like "35:38"
                    let components = duration.components(separatedBy: ":")
                    if components.count == 2 || components.count == 3 {
                        var totalSeconds = 0.0
                        
                        if components.count == 2 {
                            if let minutes = Double(components[0]), let seconds = Double(components[1]) {
                                totalSeconds = minutes * 60 + seconds
                            }
                        } else if components.count == 3 {
                            if let hours = Double(components[0]), let minutes = Double(components[1]), let seconds = Double(components[2]) {
                                totalSeconds = hours * 3600 + minutes * 60 + seconds
                            }
                        }
                        
                        if totalSeconds > 0 {
                            stats["Time"] = formatTimeInterval(totalSeconds)
                        } else {
                            // If parsing failed, just use the original string
                            stats["Time"] = duration
                        }
                    } else {
                        // If it's not in expected format, use as is
                        stats["Time"] = duration
                    }
                }
            }
            
            // Pace - with improved parsing for the specific format like "1'39""
            if let pace = runLog.avgPace {
                if let paceValue = Double(pace) {
                    // Direct conversion worked, use the value
                        stats["Pace"] = UserPreferences.formatPaceWithPreferredUnit(pace: paceValue)
                    } else {
                    // Handle the format like "1'39""
                    if pace.contains("'") && pace.contains("\"") {
                        let paceStr = pace.replacingOccurrences(of: "\"", with: "")
                        let components = paceStr.components(separatedBy: "'")
                        if components.count == 2, 
                           let minutes = Double(components[0]), 
                           let seconds = Double(components[1]) {
                            let totalSeconds = minutes * 60 + seconds
                            
                            // Convert from min/mile to sec/meter 
                            // Since distance is in miles, pace is in min/mile
                            let pacePerMeter = totalSeconds / 1609.34
                        stats["Pace"] = UserPreferences.formatPaceWithPreferredUnit(pace: pacePerMeter)
                } else {
                            // If parsing failed, at least format it nicely
                            stats["Pace"] = pace + " /mi"
                        }
                    } else if pace.contains("/km") || pace.contains("/mi") || pace.contains("min/mi") || pace.contains(":") {
                        // Extract minutes and seconds
                        let paceComponents: [String]
                        
                        if pace.contains("/km") {
                            // Format: "MM:SS /km"
                            paceComponents = pace.split(separator: " ")[0].components(separatedBy: ":")
                        if paceComponents.count == 2,
                           let minutes = Double(paceComponents[0]),
                           let seconds = Double(paceComponents[1]) {
                            let totalSeconds = minutes * 60 + seconds
                                // Convert from min/km to sec/meter
                                let pacePerMeter = totalSeconds / 1000
                            stats["Pace"] = UserPreferences.formatPaceWithPreferredUnit(pace: pacePerMeter)
                        } else {
                            stats["Pace"] = pace
                            }
                        } else if pace.contains("/mi") || pace.contains("min/mi") {
                            // Format: "MM:SS /mi" or "MM:SS min/mi"
                            let paceParts = pace.split(separator: " ")
                            if paceParts.count > 0 {
                                paceComponents = String(paceParts[0]).components(separatedBy: ":")
                        if paceComponents.count == 2,
                           let minutes = Double(paceComponents[0]),
                           let seconds = Double(paceComponents[1]) {
                            let totalSeconds = minutes * 60 + seconds
                                    // Convert from min/mile to sec/meter
                                    let pacePerMeter = totalSeconds / 1609.34
                            stats["Pace"] = UserPreferences.formatPaceWithPreferredUnit(pace: pacePerMeter)
                        } else {
                            stats["Pace"] = pace
                                }
                            } else {
                                stats["Pace"] = pace
                        }
                    } else if pace.contains(":") {
                            // Format: just "MM:SS" (assume min/km)
                            paceComponents = pace.components(separatedBy: ":")
                        if paceComponents.count == 2,
                           let minutes = Double(paceComponents[0]),
                           let seconds = Double(paceComponents[1]) {
                            let totalSeconds = minutes * 60 + seconds
                            // Default to min/km if no unit specified
                            let pacePerMeter = totalSeconds / 1000
                            stats["Pace"] = UserPreferences.formatPaceWithPreferredUnit(pace: pacePerMeter)
                        } else {
                            stats["Pace"] = pace
                        }
                    } else {
                        stats["Pace"] = pace
                }
            } else {
                        // If format is unrecognized, use as is
                        stats["Pace"] = pace
                    }
                }
            }
            
            // Calories
            if let calories = runLog.caloriesBurned {
                stats["Calories"] = "\(Int(calories)) kcal"
            }
            
            // Elevation - with improved parsing and calculation from route data
            if let elevationGain = runLog.elevationGain {
                if let elevValue = Double(elevationGain) {
                    stats["Elevation"] = UserPreferences.formatElevationWithPreferredUnit(elevation: elevValue)
                } else if elevationGain.contains("ft") {
                    // Parse "173 ft" format
                    let elevStr = elevationGain.replacingOccurrences(of: "ft", with: "").trimmingCharacters(in: .whitespaces)
                    if let feet = Double(elevStr) {
                        // Convert feet to meters for internal use
                        let meters = feet / 3.28084
                        stats["Elevation"] = UserPreferences.formatElevationWithPreferredUnit(elevation: meters)
                    } else {
                        // Calculate from route if available
                        let calculatedElevation = calculateElevationGainFromRoute()
                        if calculatedElevation > 0 {
                            stats["Elevation"] = UserPreferences.formatElevationWithPreferredUnit(elevation: calculatedElevation)
                } else {
                        stats["Elevation"] = elevationGain
                        }
                    }
                } else if elevationGain.contains("m") {
                    // Parse "50 m" format
                    let elevStr = elevationGain.replacingOccurrences(of: "m", with: "").trimmingCharacters(in: .whitespaces)
                    if let meters = Double(elevStr) {
                        stats["Elevation"] = UserPreferences.formatElevationWithPreferredUnit(elevation: meters)
                    } else {
                        // Calculate from route if available
                        let calculatedElevation = calculateElevationGainFromRoute()
                        if calculatedElevation > 0 {
                            stats["Elevation"] = UserPreferences.formatElevationWithPreferredUnit(elevation: calculatedElevation)
                        } else {
                            stats["Elevation"] = elevationGain
                        }
                        }
                } else {
                    // Calculate from route if available
                    let calculatedElevation = calculateElevationGainFromRoute()
                    if calculatedElevation > 0 {
                        stats["Elevation"] = UserPreferences.formatElevationWithPreferredUnit(elevation: calculatedElevation)
                    } else {
                        stats["Elevation"] = elevationGain
                    }
                }
            } else {
                // Calculate from route if available
                let calculatedElevation = calculateElevationGainFromRoute()
                if calculatedElevation > 0 {
                    stats["Elevation"] = UserPreferences.formatElevationWithPreferredUnit(elevation: calculatedElevation)
                    }
            }
            
            // Heart Rate
            if let heartRate = runLog.avgHeartRate, heartRate > 0 {
                stats["Heart Rate"] = "\(Int(heartRate)) bpm"
            }
        }
        
        print("Extracted stats: \(stats)")
        return stats
    }
    
    // Calculate distance from route coordinates
    private func calculateDistanceFromRoute() -> Double {
        let locations = parseLocationsFromRunData()
        guard locations.count >= 2 else { return 0 }
        
        var totalDistance: Double = 0
        var previousLocation: CLLocation? = nil
        
        for location in locations {
            if let previous = previousLocation {
                totalDistance += location.distance(from: previous)
            }
            previousLocation = location
        }
        
        return totalDistance
    }
    
    // Calculate elevation gain from route
    private func calculateElevationGainFromRoute() -> Double {
        let locations = parseLocationsFromRunData()
        guard locations.count >= 2 else { return 0 }
        
        var totalElevationGain: Double = 0
        var previousLocation: CLLocation? = nil
        
        for location in locations {
            if let previous = previousLocation {
                let elevationChange = location.altitude - previous.altitude
                if elevationChange > 0 {
                    totalElevationGain += elevationChange
                }
            }
            previousLocation = location
        }
        
        return totalElevationGain
    }
    
    // Create a simple stat view
    private func createSimpleStatView(title: String, value: String) -> UIView {
        // Container view with fixed size
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.widthAnchor.constraint(equalToConstant: 100).isActive = true
        
        // Get color for this stat type
        let (color, iconName) = getColorAndIconForStat(title)
        
        // Create vertical stack view for content
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 5
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Create icon
        let iconImageView = UIImageView()
        if #available(iOS 13.0, *) {
            iconImageView.image = UIImage(systemName: iconName)?.withRenderingMode(.alwaysTemplate)
        } else {
            iconImageView.image = UIImage(named: iconName)?.withRenderingMode(.alwaysTemplate)
        }
        iconImageView.tintColor = color
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.heightAnchor.constraint(equalToConstant: 20).isActive = true
        iconImageView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        
        // Create value label
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        valueLabel.textColor = .white
        valueLabel.textAlignment = .center
        valueLabel.numberOfLines = 1
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.7
        
        // Create title label
        let titleLabel = UILabel()
        titleLabel.text = title.uppercased()
        titleLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        titleLabel.textColor = color
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        
        // Add everything to stack
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(valueLabel)
        stackView.addArrangedSubview(titleLabel)
        
        return containerView
    }
    
    // Get color and icon for a stat type
    
    private func getColorAndIconForStat(_ statType: String) -> (UIColor, String) {
        switch statType.lowercased() {
        case "distance":
            return (UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0), "ruler")
        case "time", "duration":
            return (UIColor(red: 0.9, green: 0.5, blue: 0.1, alpha: 1.0), "clock")
        case "pace", "speed":
            return (UIColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1.0), "speedometer")
        case "calories":
            return (UIColor(red: 0.95, green: 0.3, blue: 0.3, alpha: 1.0), "flame")
        case "elevation":
            return (UIColor(red: 0.6, green: 0.4, blue: 0.9, alpha: 1.0), "mountain.2")
        case "heart rate":
            return (UIColor(red: 0.95, green: 0.3, blue: 0.5, alpha: 1.0), "heart")
        case "cadence":
            return (UIColor(red: 0.2, green: 0.8, blue: 0.8, alpha: 1.0), "figure.walk")
        default:
            return (UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0), "chart.bar")
        }
    }
    

    
    // Format a time interval into HH:MM:SS format
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    deinit {
        // Stop animations when view controller is deallocated
        gradientAnimator?.invalidate()
    }
}
    // Extension to simplify creating region from locations
    extension MKCoordinateRegion {
        init(locations: [CLLocation], latitudinalMeters: CLLocationDistance, longitudinalMeters: CLLocationDistance) {
            // Find the bounding box
            var minLat = locations[0].coordinate.latitude
            var maxLat = minLat
            var minLon = locations[0].coordinate.longitude
            var maxLon = minLon
            
            for location in locations {
                minLat = min(minLat, location.coordinate.latitude)
                maxLat = max(maxLat, location.coordinate.latitude)
                minLon = min(minLon, location.coordinate.longitude)
                maxLon = max(maxLon, location.coordinate.longitude)
            }
            
            // Create center point
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            
            // Calculate span with some padding
            let latDelta = (maxLat - minLat) * 1.1
            let lonDelta = (maxLon - minLon) * 1.1
            
            // Create region with calculated center and span
            self.init(
                center: center,
                span: MKCoordinateSpan(
                    latitudeDelta: max(latDelta, 0.005),
                    longitudeDelta: max(lonDelta, 0.005)
                )
            )
        }
    }
    
    // MARK: - UserPreferences Extensions
    extension UserPreferences {
        // Format distance according to user's preferred unit system
        static func formatDistanceWithPreferredUnit(distance: Double) -> String {
            // Get user's preferred unit (metric or imperial)
            let useMetric = UserDefaults.standard.bool(forKey: "useMetricSystem")
            
            if useMetric {
                // Convert to kilometers
                let kilometers = distance / 1000
                return String(format: "%.2f km", kilometers)
            } else {
                // Convert to miles (1 km = 0.621371 miles)
                let miles = distance / 1000 * 0.621371
                return String(format: "%.2f mi", miles)
            }
        }
        
        // Format pace according to user's preferred unit system
        static func formatPaceWithPreferredUnit(pace: Double) -> String {
            // Get user's preferred unit (metric or imperial)
            let useMetric = UserDefaults.standard.bool(forKey: "useMetricSystem")
            
            // Pace is usually in seconds per meter, convert to minutes per km or mile
            var paceValue = pace
            if useMetric {
                // Convert to min/km (pace is in seconds per meter, so multiply by 1000 to get seconds per km)
                paceValue = paceValue * 1000
            } else {
                // Convert to min/mile (pace is in seconds per meter, so multiply by 1609.34 to get seconds per mile)
                paceValue = paceValue * 1609.34
            }
            
            // Convert seconds to minutes:seconds format
            let minutes = Int(paceValue) / 60
            let seconds = Int(paceValue) % 60
            
            if useMetric {
                return String(format: "%d:%02d /km", minutes, seconds)
            } else {
                return String(format: "%d:%02d /mi", minutes, seconds)
            }
        }
        
        // Format elevation according to user's preferred unit system
        static func formatElevationWithPreferredUnit(elevation: Double) -> String {
            // Get user's preferred unit (metric or imperial)
            let useMetric = UserDefaults.standard.bool(forKey: "useMetricSystem")
            
            if useMetric {
                // Keep in meters
                return String(format: "%.0f m", elevation)
            } else {
                // Convert to feet (1 meter = 3.28084 feet)
                let feet = elevation * 3.28084
                return String(format: "%.0f ft", feet)
            }
        }
        
    }
  
    // Helper method to get weather icon based on condition
    private func getWeatherIcon(_ weatherCondition: String) -> String {
        let condition = weatherCondition.lowercased()
        
        if condition.contains("clear") || condition.contains("sunny") {
            return "sun.max.fill"
        } else if condition.contains("cloud") {
            if condition.contains("partly") {
                return "cloud.sun.fill"
            } else {
                return "cloud.fill"
            }
        } else if condition.contains("rain") {
            if condition.contains("light") {
                return "cloud.drizzle.fill"
            } else {
                return "cloud.rain.fill"
            }
        } else if condition.contains("storm") || condition.contains("thunder") {
            return "cloud.bolt.rain.fill"
        } else if condition.contains("snow") || condition.contains("flurr") {
            return "cloud.snow.fill"
        } else if condition.contains("fog") || condition.contains("mist") {
            return "cloud.fog.fill"
        } else if condition.contains("wind") {
            return "wind"
        } else if condition.contains("haz") || condition.contains("smoke") {
            return "smoke.fill"
        } else {
            // Default icon
            return "thermometer"
        }
    }
    
    // Helper method to get weather color based on condition
    private func getWeatherColor(_ weatherCondition: String) -> UIColor {
        let condition = weatherCondition.lowercased()
        
        if condition.contains("clear") || condition.contains("sunny") {
            return UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0) // Yellow
        } else if condition.contains("cloud") {
            return UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0) // Gray
        } else if condition.contains("rain") {
            return UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0) // Blue
        } else if condition.contains("storm") || condition.contains("thunder") {
            return UIColor(red: 0.4, green: 0.4, blue: 0.8, alpha: 1.0) // Dark Blue
        } else if condition.contains("snow") || condition.contains("flurr") {
            return UIColor(red: 0.8, green: 0.8, blue: 1.0, alpha: 1.0) // Light Blue
        } else {
            // Default color
            return UIColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0) // Cyan
        }
    }
  
   

