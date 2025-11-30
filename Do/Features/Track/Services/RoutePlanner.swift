//
//  RoutePlanner.swift
//  Do.
//
//  Created by Mikiyas Meseret on 3/12/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//


import Foundation
import MapKit
import Combine
import AVFoundation

// MARK: - Notification Names
extension NSNotification.Name {
    static let routesDidChange = NSNotification.Name("RoutesDidChange")
    static let didUpdateNearbyTrails = NSNotification.Name("didUpdateNearbyTrails")
}

// MARK: - Custom Search Result

/// Custom search result class to replace MKLocalSearchCompletion which has read-only properties
class SearchResult: Identifiable {
    let id = UUID()
    var title: String
    var subtitle: String
    var mapItem: MKMapItem
    
    init(title: String, subtitle: String, mapItem: MKMapItem) {
        self.title = title
        self.subtitle = subtitle
        self.mapItem = mapItem
    }
}

// Route types for different activities
enum ActivityRouteType: String {
    case biking = "biking"
    case running = "running"
    case hiking = "hiking"
    case walking = "walking"
    case returnRoute = "returnRoute"
}

// Alias for backward compatibility
typealias RouteType = ActivityRouteType

// Route shape types for route generation
enum RouteShape {
    case loop
    case outAndBack
    case pointToPoint
}

// MARK: - Shared Trail Cache
/// Centralized cache for trails that can be shared across all activity types
class SharedTrailCache {
    static let shared = SharedTrailCache()
    
    // Cache structure: location key -> (trails, timestamp)
    private var cache: [String: (trails: [Trail], timestamp: Date, location: CLLocationCoordinate2D)] = [:]
    private let cacheExpirationInterval: TimeInterval = 600 // 10 minutes
    private let cacheDistanceThreshold: CLLocationDistance = 1000 // 1km - refetch if moved this far
    private let cacheLock = NSLock()
    
    private init() {}
    
    /// Generate a cache key based on rounded coordinates
    func generateCacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        // Round to 2 decimal places (~1.1km resolution)
        let roundedLat = round(coordinate.latitude * 100) / 100
        let roundedLon = round(coordinate.longitude * 100) / 100
        return "\(roundedLat),\(roundedLon)"
    }
    
    /// Check if we have valid cached trails for a location
    func getCachedTrails(for coordinate: CLLocationCoordinate2D) -> [Trail]? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        let key = generateCacheKey(for: coordinate)
        
        guard let cached = cache[key] else {
            print("📦 Cache miss - no trails for location key: \(key)")
            return nil
        }
        
        // Check if cache is still valid (time-based)
        let age = Date().timeIntervalSince(cached.timestamp)
        guard age < cacheExpirationInterval else {
            print("📦 Cache expired - trails are \(Int(age))s old (max: \(Int(cacheExpirationInterval))s)")
            cache.removeValue(forKey: key)
            return nil
        }
        
        // Check if location hasn't moved too far
        let cachedLocation = CLLocation(latitude: cached.location.latitude, longitude: cached.location.longitude)
        let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = currentLocation.distance(from: cachedLocation)
        
        guard distance < cacheDistanceThreshold else {
            print("📦 Cache invalid - moved \(Int(distance))m from cached location (max: \(Int(cacheDistanceThreshold))m)")
            return nil
        }
        
        print("📦 Cache HIT - returning \(cached.trails.count) trails (age: \(Int(age))s, distance: \(Int(distance))m)")
        return cached.trails
    }
    
    /// Store trails in cache for a location
    func cacheTrails(_ trails: [Trail], for coordinate: CLLocationCoordinate2D) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        let key = generateCacheKey(for: coordinate)
        cache[key] = (trails: trails, timestamp: Date(), location: coordinate)
        print("📦 Cached \(trails.count) trails for location key: \(key)")
    }
    
    /// Clear all cached trails
    func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        cache.removeAll()
        print("📦 Cache cleared")
    }
    
    /// Filter cached trails for specific activity type
    func filterTrailsForActivity(_ trails: [Trail], activityType: ActivityRouteType) -> [Trail] {
        return trails.filter { trail in
            switch activityType {
            case .running:
                // Running can use: footpaths, tracks, trails
                return (trail.trailType?.contains("footway") ?? false) || 
                       (trail.trailType?.contains("path") ?? false) || 
                       (trail.trailType?.contains("track") ?? false) ||
                       (trail.trailType?.contains("cycleway") ?? false) // Many cycleways allow running
                
            case .walking:
                // Walking can use most trail types
                return (trail.trailType?.contains("footway") ?? false) || 
                       (trail.trailType?.contains("path") ?? false) || 
                       (trail.trailType?.contains("track") ?? false) ||
                       (trail.trailType?.contains("cycleway") ?? false) ||
                       (trail.trailType?.contains("steps") ?? false) ||
                       (trail.trailType?.contains("pedestrian") ?? false)
                
            case .biking:
                // Biking uses cycleways and suitable paths
                return (trail.trailType?.contains("cycleway") ?? false) || 
                       (trail.trailType?.contains("path") ?? false) || 
                       (trail.trailType?.contains("track") ?? false)
                
            case .hiking:
                // Hiking prefers natural trails
                return (trail.trailType?.contains("footway") ?? false) || 
                       (trail.trailType?.contains("path") ?? false) || 
                       (trail.trailType?.contains("track") ?? false)
                
            case .returnRoute:
                return true // Return routes can use any trail
            }
        }
    }
}

class RoutePlanner: ObservableObject {
    // Singleton instance
    static let shared = RoutePlanner()
    
    // Add a counter for debugging
    private var fetchCounter: Int = 0
    
    // Add a flag to track if a fetch is in progress
    var isFetchingTrails = false
    private let fetchQueue = DispatchQueue(label: "com.dois.trailFetchQueue")
    
    // Published properties for SwiftUI binding
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    @Published var routePolyline: [CLLocationCoordinate2D] = []
    @Published var searchResults: [SearchResult] = []
    @Published var routeAnnotations: [RouteAnnotation] = []
    @Published var useMetric: Bool = true
    @Published var isGeneratingRoute: Bool = false
    @Published var routeDistance: Double = 0.0 // In meters
    @Published var routeElevationGain: Double = 0.0 // In meters
    @Published var navigationActive: Bool = false
    @Published var navigationDirections: [String] = []
    @Published var nextDirectionIndex: Int = 0
    @Published var nearbyTrails: [Trail] = []
    
    // Add timestamp tracking
    private var lastTrailLoadTime: Date?
    private let minTimeBetweenLoads: TimeInterval = 5.0 // 5 seconds minimum between loads
    
    // Private properties
    private let searchCompleter = MKLocalSearchCompleter()
    public var startLocation: CLLocationCoordinate2D?
    private var currentRoute: MKRoute?
    private var cancellables = Set<AnyCancellable>()
    private let locationManager = ModernLocationManager.shared
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // Initialize the route planner
    public init() {
        searchCompleter.resultTypes = .pointOfInterest
        
        // When the location changes, update the region
        locationManager.$location
            .compactMap { $0 }
            .sink { [weak self] location in
                guard let self = self else { return }
                
                // If we don't have a start location, use the current one
                if self.startLocation == nil {
                    self.startLocation = location.coordinate
                    self.region.center = location.coordinate
                }
                
                // If navigation is active, check if we need to give directions
                if self.navigationActive {
                    self.checkNavigationProgress(currentLocation: location)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Search for locations based on query string
    func searchLocations(query: String) {
        searchCompleter.queryFragment = query
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let self = self, let response = response else {
                print("Search error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Create search results directly from map items
            let results = response.mapItems.map { mapItem in
                SearchResult(
                    title: mapItem.name ?? "",
                    subtitle: mapItem.placemark.title ?? "",
                    mapItem: mapItem
                )
            }
            
            self.searchResults = results
        }
    }
    
    /// Select a route by name
    func selectRoute(name: String) {
        // Find a saved route with this name or create a new one
        print("Selecting route: \(name)")
        
        // This is a simple implementation - you would typically load a saved route from storage
        // For now, we'll just update the UI to reflect that a route was selected
        
        guard let currentLocation = locationManager.location?.coordinate else {
            print("No current location available")
            return
        }
        
        // Create a simple route - in a real app, this would load from storage
        let targetCoord = CLLocationCoordinate2D(
            latitude: currentLocation.latitude + 0.01,
            longitude: currentLocation.longitude + 0.01
        )
        
        // Get directions between points
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: currentLocation))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: targetCoord))
        request.transportType = .walking
        
        isGeneratingRoute = true
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self, let route = response?.routes.first else {
                print("Route calculation error: \(error?.localizedDescription ?? "Unknown error")")
                self?.isGeneratingRoute = false
                return
            }
            
            self.isGeneratingRoute = false
            self.currentRoute = route
            
            // Update UI with route info
            self.routePolyline = route.polyline.coordinates
            self.routeDistance = route.distance
            self.routeElevationGain = 0 // Would calculate from elevation data
            
            // Add annotations
            self.routeAnnotations = [
                RouteAnnotation(coordinate: currentLocation, type: .start, title: "Start"),
                RouteAnnotation(coordinate: targetCoord, type: .end, title: "End")
            ]
            
            // Center the map on the route
            let region = MKCoordinateRegion(
                center: currentLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            self.region = region
        }
    }
    
    /// Select a location from search results
    func selectLocation(_ result: SearchResult) {
        // Use the mapItem directly
        let firstItem = result.mapItem
        
        // Update the region to center on the selected location
        self.region = MKCoordinateRegion(
            center: firstItem.placemark.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        // Set the start location
        self.startLocation = firstItem.placemark.coordinate
        
        // Create an annotation for the start point
        self.updateAnnotations()
    }
    
    /// Generate a route based on shape type and target distance
    func generateRoute(type: RouteShape, targetDistance: Double, useMetric: Bool) {
        guard let startLocation = startLocation ?? locationManager.location?.coordinate else {
            print("Cannot generate route: No start location")
            return
        }
        
        isGeneratingRoute = true
        
        // Convert target distance to meters
        let targetDistanceMeters = useMetric
            ? targetDistance * 1000 // km to meters
            : targetDistance * 1609.34 // miles to meters
        
        // Clear existing route
        routePolyline = []
        routeAnnotations = []
        
        // Generate route based on shape type
        switch type {
        case .loop:
            generateLoopRoute(startLocation: startLocation, targetDistance: targetDistanceMeters)
        case .outAndBack:
            generateOutAndBackRoute(startLocation: startLocation, targetDistance: targetDistanceMeters)
        case .pointToPoint:
            generatePointToPointRoute(startLocation: startLocation, targetDistance: targetDistanceMeters)
        }
    }
    
    /// Clear the current route
    func clearRoute() {
        routePolyline = []
        routeAnnotations = []
        currentRoute = nil
        navigationActive = false
        navigationDirections = []
        nextDirectionIndex = 0
    }
    
    /// Save the current route for use in the run
    func saveRoute() {
        // This method would save the route to be used during the run
        // For now we'll just keep the current route active
        
        // In a real implementation, we might save to UserDefaults or a database
    }
    
    /// Navigate back to the start point
    func navigateBackToStart() {
        guard let currentLocation = locationManager.location?.coordinate,
              let startLocation = self.startLocation else {
            return
        }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: currentLocation))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: startLocation))
        request.transportType = .walking
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self, let route = response?.routes.first else {
                print("Route calculation error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            self.currentRoute = route
            self.routePolyline = route.polyline.coordinates
            self.routeDistance = route.distance
            
            // Create annotations for the route
            self.routeAnnotations = [
                RouteAnnotation(
                    coordinate: currentLocation,
                    type: .currentLocation,
                    title: "Current Location"
                ),
                RouteAnnotation(
                    coordinate: startLocation,
                    type: .end,
                    title: "Starting Point"
                )
            ]
            
            // Extract directions and activate navigation
            self.navigationDirections = route.steps.map { $0.instructions }
            self.nextDirectionIndex = 0
            self.navigationActive = true
            
            // Announce the first direction
            if !self.navigationDirections.isEmpty {
                self.announceDirection(self.navigationDirections[0])
            }
        }
    }
    
    /// Center the map view on the user's current location
    func centerOnUser() {
        if let userLocation = locationManager.location?.coordinate {
            // Update the region to center on the user's location
            self.region = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func generateLoopRoute(startLocation: CLLocationCoordinate2D, targetDistance: Double) {
        // For a loop, we'll pick 3-5 random points around the start location
        // and create a route that goes through them and back to start
        
        let numPoints = Int.random(in: 3...5)
        var waypoints: [CLLocationCoordinate2D] = []
        
        // Create random points in different directions from start
        for i in 0..<numPoints {
            let angle = Double(i) * (2 * Double.pi / Double(numPoints))
            let distance = targetDistance / Double(numPoints + 1)
            
            // Calculate point using bearing and distance
            let lat1 = startLocation.latitude * Double.pi / 180
            let lon1 = startLocation.longitude * Double.pi / 180
            let angularDistance = distance / 6371000 // Earth radius in meters
            
            let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(angle))
            let lon2 = lon1 + atan2(sin(angle) * sin(angularDistance) * cos(lat1), cos(angularDistance) - sin(lat1) * sin(lat2))
            
            let point = CLLocationCoordinate2D(
                latitude: lat2 * 180 / Double.pi,
                longitude: lon2 * 180 / Double.pi
            )
            
            waypoints.append(point)
        }
        
        // Create a route through these waypoints
        createRouteWithWaypoints(start: startLocation, waypoints: waypoints, end: startLocation)
    }
    
    private func generateOutAndBackRoute(startLocation: CLLocationCoordinate2D, targetDistance: Double) {
        // For out and back, we'll pick a destination point at about half the target distance
        // and then return to the start
        
        let halfDistance = targetDistance / 2
        
        // Pick a random direction
        let angle = Double.random(in: 0...(2 * Double.pi))
        
        // Calculate endpoint using bearing and distance
        let lat1 = startLocation.latitude * Double.pi / 180
        let lon1 = startLocation.longitude * Double.pi / 180
        let angularDistance = halfDistance / 6371000 // Earth radius in meters
        
        let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(angle))
        let lon2 = lon1 + atan2(sin(angle) * sin(angularDistance) * cos(lat1), cos(angularDistance) - sin(lat1) * sin(lat2))
        
        let turnaroundPoint = CLLocationCoordinate2D(
            latitude: lat2 * 180 / Double.pi,
            longitude: lon2 * 180 / Double.pi
        )
        
        // Create a route to the endpoint and back
        createRouteWithWaypoints(start: startLocation, waypoints: [turnaroundPoint], end: startLocation)
    }
    
    private func generatePointToPointRoute(startLocation: CLLocationCoordinate2D, targetDistance: Double) {
        // For point to point, we'll pick a destination at the target distance
        
        // Pick a random direction
        let angle = Double.random(in: 0...(2 * Double.pi))
        
        // Calculate endpoint using bearing and distance
        let lat1 = startLocation.latitude * Double.pi / 180
        let lon1 = startLocation.longitude * Double.pi / 180
        let angularDistance = targetDistance / 6371000 // Earth radius in meters
        
        let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(angle))
        let lon2 = lon1 + atan2(sin(angle) * sin(angularDistance) * cos(lat1), cos(angularDistance) - sin(lat1) * sin(lat2))
        
        let endpoint = CLLocationCoordinate2D(
            latitude: lat2 * 180 / Double.pi,
            longitude: lon2 * 180 / Double.pi
        )
        
        // Create a route to the endpoint
        createRouteWithWaypoints(start: startLocation, waypoints: [], end: endpoint)
    }
    
    private func createRouteWithWaypoints(start: CLLocationCoordinate2D, waypoints: [CLLocationCoordinate2D], end: CLLocationCoordinate2D) {
        // Create a directions request
        let request = MKDirections.Request()
        
        // Add the waypoints
        var locations = [start] + waypoints + [end]
        
        // Break this down into segments to avoid MKDirections limitations
        var routeSegments: [MKRoute] = []
        
        func processNextSegment(index: Int) {
            // If we've processed all segments, combine them
            if index >= locations.count - 1 {
                // We've processed all segments
                combineRouteSegments(routeSegments)
                return
            }
            
            let segmentRequest = MKDirections.Request()
            segmentRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: locations[index]))
            segmentRequest.destination = MKMapItem(placemark: MKPlacemark(coordinate: locations[index + 1]))
            segmentRequest.transportType = .walking
            
            let directions = MKDirections(request: segmentRequest)
            directions.calculate { [weak self] response, error in
                guard let self = self, let route = response?.routes.first else {
                    print("Route calculation error: \(error?.localizedDescription ?? "Unknown error")")
                    self?.isGeneratingRoute = false
                    return
                }
                
                routeSegments.append(route)
                processNextSegment(index: index + 1)
            }
        }
        
        // Start processing segments
        processNextSegment(index: 0)
    }
    
    private func combineRouteSegments(_ segments: [MKRoute]) {
        guard !segments.isEmpty else {
            isGeneratingRoute = false
            return
        }
        
        // Combine all segment polylines
        var combinedCoordinates: [CLLocationCoordinate2D] = []
        var totalDistance: Double = 0
        var totalElevationGain: Double = 0
        
        for segment in segments {
            combinedCoordinates.append(contentsOf: segment.polyline.coordinates)
            totalDistance += segment.distance
            
            // In a real implementation, we would calculate elevation gain
            // For now, let's estimate it as 1% of distance
            totalElevationGain += segment.distance * 0.01
        }
        
        // Update the route properties
        self.routePolyline = combinedCoordinates
        self.routeDistance = totalDistance
        self.routeElevationGain = totalElevationGain
        
        // Update annotations
        updateAnnotations()
        
        isGeneratingRoute = false
    }
    
    // MARK: - Helper Methods
    
    // Helper to compare coordinates
    private func areCoordinatesEqual(_ coord1: CLLocationCoordinate2D, _ coord2: CLLocationCoordinate2D) -> Bool {
        return coord1 == coord2
    }
    
    private func updateAnnotations() {
        guard let startLocation = startLocation, !routePolyline.isEmpty else {
            return
        }
        
        var annotations: [RouteAnnotation] = []
        
        // Add start annotation
        annotations.append(RouteAnnotation(
            coordinate: startLocation,
            type: .start,
            title: "Start"
        ))
        
        // Add end annotation
        if let endLocation = routePolyline.last, endLocation != startLocation {
            annotations.append(RouteAnnotation(
                coordinate: endLocation,
                type: .end,
                title: "Finish"
            ))
        }
        
        // Add distance marker annotations at regular intervals
        if routeDistance > 1000 { // For routes longer than 1km
            // Calculate the route
            var cumulativeDistance: Double = 0
            var lastMileMarker: Double = 0
            let markerInterval: Double = useMetric ? 1000 : 1609.34 // 1km or 1 mile
            
            // List to store the points where we'll add markers
            var markerPoints: [(coordinate: CLLocationCoordinate2D, distance: Double)] = []
            
            // Calculate distance along the route
            for i in 1..<routePolyline.count {
                let lastPoint = CLLocation(latitude: routePolyline[i-1].latitude, longitude: routePolyline[i-1].longitude)
                let currentPoint = CLLocation(latitude: routePolyline[i].latitude, longitude: routePolyline[i].longitude)
                let segmentDistance = lastPoint.distance(from: currentPoint)
                
                cumulativeDistance += segmentDistance
                
                // Check if we've reached a new mile/km marker
                if cumulativeDistance >= lastMileMarker + markerInterval {
                    // Calculate how many markers we crossed in this segment
                    let markersToAdd = Int((cumulativeDistance - lastMileMarker) / markerInterval)
                    
                    for j in 1...markersToAdd {
                        let markerDistance = lastMileMarker + Double(j) * markerInterval
                        
                        // Make sure we don't exceed the total distance
                        if markerDistance <= routeDistance {
                            // For this marker, interpolate between the two points
                            let progress = (markerDistance - (cumulativeDistance - segmentDistance)) / segmentDistance
                            let lat = lastPoint.coordinate.latitude + progress * (currentPoint.coordinate.latitude - lastPoint.coordinate.latitude)
                            let lon = lastPoint.coordinate.longitude + progress * (currentPoint.coordinate.longitude - lastPoint.coordinate.longitude)
                            
                            let markerCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                            markerPoints.append((markerCoordinate, markerDistance))
                            
                            lastMileMarker = markerDistance
                        }
                    }
                }
            }
            
            // Add marker annotations
            for (index, marker) in markerPoints.enumerated() {
                let markerNumber = index + 1
                let formattedDistance = useMetric ? 
                    String(format: "%.1f km", marker.distance / 1000) : 
                    String(format: "%.1f mi", marker.distance / 1609.34)
                
                annotations.append(RouteAnnotation(
                    coordinate: marker.coordinate,
                    type: .waypoint,
                    title: "\(markerNumber): \(formattedDistance)"
                ))
            }
        }
        
        self.routeAnnotations = annotations
    }
    
    private func calculateSegmentDistance(from startIndex: Int, to endIndex: Int) -> Double {
        guard startIndex < routePolyline.count, endIndex < routePolyline.count, startIndex < endIndex else {
            return 0
        }
        
        var distance: Double = 0
        
        for i in startIndex..<endIndex {
            let start = CLLocation(latitude: routePolyline[i].latitude, longitude: routePolyline[i].longitude)
            let end = CLLocation(latitude: routePolyline[i+1].latitude, longitude: routePolyline[i+1].longitude)
            
            distance += start.distance(from: end)
        }
        
        return distance
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if useMetric {
            if distance >= 1000 {
                return String(format: "%.1f km", distance / 1000)
            } else {
                return String(format: "%.0f m", distance)
            }
        } else {
            let miles = distance / 1609.34
            if miles >= 0.1 {
                return String(format: "%.1f mi", miles)
            } else {
                return String(format: "%.0f ft", distance * 3.28084)
            }
        }
    }
    
    public func checkNavigationProgress(currentLocation: CLLocation) {
        guard navigationActive, 
              nextDirectionIndex < navigationDirections.count,
              let route = currentRoute else { return }
        
        // Calculate where we are on the route
        let routeCoords = route.polyline.coordinates
        
        // Find the closest point on the route to our current location
        var closestIndex = 0
        var closestDistance = Double.greatestFiniteMagnitude
        
        for (index, coordinate) in routeCoords.enumerated() {
            let routePoint = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = currentLocation.distance(from: routePoint)
            
            if distance < closestDistance {
                closestDistance = distance
                closestIndex = index
            }
        }
        
        // Check if we're close to a step change
        if let step = route.steps[safe: nextDirectionIndex],
           let stepEndCoordinate = step.polyline.coordinates.last {
            
            let stepEndLocation = CLLocation(latitude: stepEndCoordinate.latitude, longitude: stepEndCoordinate.longitude)
            let distanceToStepEnd = currentLocation.distance(from: stepEndLocation)
            
            // If we're close to the end of the current step
            if distanceToStepEnd < 20 { // Within 20 meters
                nextDirectionIndex += 1
                
                // Announce the next direction if available
                if nextDirectionIndex < navigationDirections.count {
                    announceDirection(navigationDirections[nextDirectionIndex])
                } else if nextDirectionIndex == navigationDirections.count {
                    // We've reached the end of the route
                    announceDirection("You have reached your destination.")
                    navigationActive = false
                }
            }
        }
    }
    
    private func announceDirection(_ direction: String) {
        // Check if audio guidance is muted in the RunTrackingEngine
        let runEngine = RunTrackingEngine.shared
        let isMuted = (runEngine as? RunTrackingEngine)?.navigationAudioMuted ?? false
        
        // Only speak if not muted
        if !isMuted {
            let speechUtterance = AVSpeechUtterance(string: direction)
            speechUtterance.rate = 0.5
            speechUtterance.volume = 1.0
            
            speechSynthesizer.speak(speechUtterance)
        }
        
        // Even if muted, we'll still update the visual guidance
    }
    
    // MARK: - Unit Conversion Utilities
    
    /// Convert distance from meters to display units (km or miles)
    func convertDistanceToDisplayUnits(_ distanceInMeters: Double) -> Double {
        return useMetric ? distanceInMeters / 1000.0 : distanceInMeters / 1609.34
    }
    
    /// Convert distance from display units (km or miles) to meters
    func convertDisplayUnitsToMeters(_ distance: Double) -> Double {
        return useMetric ? distance * 1000.0 : distance * 1609.34
    }
    
    /// Convert elevation from meters to display units (m or ft)
    func convertElevationToDisplayUnits(_ elevationInMeters: Double) -> Double {
        return useMetric ? elevationInMeters : elevationInMeters * 3.28084
    }
    
    /// Get the current display unit string for distance
    func getDistanceUnitString() -> String {
        return useMetric ? "km" : "mi"
    }
    
    /// Get the current display unit string for elevation
    func getElevationUnitString() -> String {
        return useMetric ? "m" : "ft"
    }
    
    /// Get the current display unit string for pace
    func getPaceUnitString() -> String {
        return useMetric ? "min/km" : "min/mi"
    }
    
    // MARK: - Trail Finding Methods for Different Activities
    
    /// Find bike-friendly trails using OpenStreetMap data
    func findBikeFriendlyTrails(radius: Double = 10000, completion: ((Bool) -> Void)? = nil) {
        guard let userLocation = locationManager.location?.coordinate else {
            print("Cannot find trails: location unknown")
            DispatchQueue.main.async {
                completion?(false)
            }
            return
        }
        
        isGeneratingRoute = true
        
        // Simplified query focused on cycling infrastructure
        let query = """
        [out:json][timeout:30];
        (
          // Bike-specific infrastructure
          way["highway"="cycleway"](around:\(radius),\(userLocation.latitude),\(userLocation.longitude));
          way["bicycle"="designated"](around:\(radius),\(userLocation.latitude),\(userLocation.longitude));
          
          // Bike-friendly paths
          way["highway"="path"]["bicycle"="yes"](around:\(radius),\(userLocation.latitude),\(userLocation.longitude));
          
          // Named paths and parks
          way["leisure"="park"]["name"](around:\(radius),\(userLocation.latitude),\(userLocation.longitude));
        );
        out body 15;
        >;
        out skel qt 15;
        """
        
        getTrailsFromOverpass(query: query, activityType: .biking) { success in
            completion?(success)
        }
    }
    
    /// Find hiking trails using OpenStreetMap data
    func findHikingTrails(radius: Double = 10000, completion: ((Bool) -> Void)? = nil) {
        findTrailsForActivity(.hiking, radius: radius, completion: completion)
    }
    
    /// Find walking paths using OpenStreetMap data
    func findWalkingTrails(radius: Double = 3000, limit: Int = 10, completion: ((Bool) -> Void)? = nil) {
        findTrailsForActivity(.walking, radius: radius, completion: completion)
    }
    
    /// Find running trails near the user's current location
    func findRunningTrails(completion: ((Bool) -> Void)? = nil) {
        findTrailsForActivity(.running, completion: completion)
    }
    
    /// Unified trail fetching with smart caching across all activity types
    private func findTrailsForActivity(_ activityType: ActivityRouteType, radius: Double = 10000, completion: ((Bool) -> Void)? = nil) {
        // Use a serial queue to ensure only one fetch happens at a time
        fetchQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            
            // Check if a fetch is already in progress
            if self.isFetchingTrails {
                print("🔄 Skipping trail fetch - another fetch is already in progress")
                DispatchQueue.main.async {
                    completion?(!self.nearbyTrails.isEmpty)
                    if !self.nearbyTrails.isEmpty {
                        NotificationCenter.default.post(
                            name: .routesDidChange,
                            object: self,
                            userInfo: ["trails": self.nearbyTrails, "timestamp": Date(), "skipRefresh": true]
                        )
                    }
                }
                return
            }

            // Increment and log the fetch counter
            self.fetchCounter += 1
            print("🔢 Trail fetch #\(self.fetchCounter) for \(activityType.rawValue) started")
            
            // CRITICAL: Check location FIRST, but try cached location as fallback
            var userLocation: CLLocationCoordinate2D?
            
            if let currentLocation = self.locationManager.location?.coordinate {
                userLocation = currentLocation
            } else if let cachedLat = UserDefaults.standard.object(forKey: "lastKnownLatitude") as? Double,
                      let cachedLon = UserDefaults.standard.object(forKey: "lastKnownLongitude") as? Double {
                // Use cached location as fallback
                userLocation = CLLocationCoordinate2D(latitude: cachedLat, longitude: cachedLon)
                print("📍 Using cached location for routes: \(cachedLat), \(cachedLon)")
            }
            
            guard let userLocation = userLocation else {
                print("⚠️ Cannot find trails: No location available (checking for cached routes)")
                // Check if we have any cached routes we can show
                if !self.nearbyTrails.isEmpty {
                    print("✓ Found \(self.nearbyTrails.count) cached routes to display")
                    DispatchQueue.main.async { completion?(true) }
                } else {
                    DispatchQueue.main.async { completion?(false) }
                }
                return
            }
            
            print("📍 Location: \(userLocation.latitude), \(userLocation.longitude)")
            
            // CHECK SHARED CACHE FIRST
            if let cachedTrails = SharedTrailCache.shared.getCachedTrails(for: userLocation) {
                print("✅ Using cached trails for \(activityType.rawValue)")
                
                // Filter cached trails for this specific activity type
                let filteredTrails = SharedTrailCache.shared.filterTrailsForActivity(cachedTrails, activityType: activityType)
                print("📦 Filtered \(filteredTrails.count) trails for \(activityType.rawValue) from \(cachedTrails.count) cached trails")
                
                DispatchQueue.main.async {
                    self.setTrails(filteredTrails)
                    self.lastTrailLoadTime = Date()
                    completion?(true)
                }
                return
            }
            
            print("📥 Fetching fresh trails for location (no valid cache)")
            
            // Set flag to indicate a fetch is in progress
            self.isFetchingTrails = true
            
            // Safety timeout: Reset flag after 30 seconds if something goes wrong
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 30) { [weak self] in
                guard let self = self, self.isFetchingTrails else { return }
                print("⏰ Trail fetch timed out after 30s - resetting flag")
                self.isFetchingTrails = false
            }
            
            // Make sure we start with a clean slate
            DispatchQueue.main.async {
                self.clearTrails()
                self.isGeneratingRoute = true
            }
            
            // Create an Overpass query for running paths and trails
            // Use a smaller initial radius to reduce timeouts; expand later if needed
            let lat = userLocation.latitude
            let lon = userLocation.longitude
            let query = """
            [out:json][timeout:25];
            (
              // Get various amenities that are suitable for running
              way(around:1000,\(lat),\(lon))[highway=footway];
              way(around:1000,\(lat),\(lon))[highway=path];
              way(around:1000,\(lat),\(lon))[highway=pedestrian];
              way(around:1000,\(lat),\(lon))[highway=track];
              way(around:1000,\(lat),\(lon))[highway=bridleway];
              
              // Get running/hiking trails specifically
              way(around:1000,\(lat),\(lon))[route=hiking];
              way(around:1000,\(lat),\(lon))[route=foot];
              way(around:1000,\(lat),\(lon))[route=running];
              
              // Get other suitable paths
              way(around:1000,\(lat),\(lon))[leisure=park];
              way(around:1000,\(lat),\(lon))[leisure=sports_centre];
              way(around:1000,\(lat),\(lon))[leisure=fitness_centre];
            );
            (._;>;);
            out body;
            """
            
            self.getTrailsFromOverpass(query: query, activityType: .running) { success in
                // Reset fetch flag when done
                self.isFetchingTrails = false
                completion?(success)
            }
        }
    }
    
    // Updated method to be more selective with way processing
    private func getTrailsFromOverpass(query: String, activityType: ActivityRouteType, completion: @escaping (Bool) -> Void) {
        // Prefer mirror-based POST immediately to avoid provider GET slowness
        let sanitizedQuery = query
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        self.retryOverpassViaMirrors(query: sanitizedQuery, activityType: activityType, completion: completion)
        return
        
        #if false
        // Implementation omitted as per original code
        #endif
    }

    // Mirror-based retry using POST and gzip
    private func retryOverpassViaMirrors(query: String, activityType: ActivityRouteType, completion: @escaping (Bool) -> Void) {
        let mirrors = [
            "https://overpass.kumi.systems/api/interpreter",
            "https://lz4.overpass-api.de/api/interpreter",
            "https://overpass-api.de/api/interpreter"
        ]
        guard let body = ("data=" + (query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")).data(using: .utf8) else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isGeneratingRoute = false
                self.isFetchingTrails = false
                completion(false)
            }
            return
        }
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 45
        let session = URLSession(configuration: config)

        func attempt(_ idx: Int) {
            if idx >= mirrors.count {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isGeneratingRoute = false
                    self.isFetchingTrails = false
                    completion(false)
                }
                return
            }
            guard let url = URL(string: mirrors[idx]) else { attempt(idx + 1); return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = 25
            req.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
            req.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
            req.httpBody = body
            session.dataTask(with: req) { [weak self] data, response, error in
                guard let self = self else { return }
                if let error = error {
                    print("❌ Overpass mirror error: \(error.localizedDescription)")
                    attempt(idx + 1)
                    return
                }
                guard let data = data else { attempt(idx + 1); return }
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(OverpassResponse.self, from: data)
                    var nodeCoordinates: [Int: CLLocationCoordinate2D] = [:]
                    for element in response.elements where element.type == "node" {
                        if let id = element.id, let lat = element.lat, let lon = element.lon {
                            nodeCoordinates[id] = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        }
                    }
                    let allWays = response.elements.filter { $0.type == "way" }
                    let namedWays = allWays.filter { $0.tags?["name"] != nil }
                    let unnamedWays = allWays.filter { $0.tags?["name"] == nil }
                    let maxWaysToProcess = 30
                    let remainingSlots = min(maxWaysToProcess, allWays.count) - namedWays.count
                    let waysToProcess = (namedWays + Array(unnamedWays.prefix(max(0, remainingSlots))))
                    let processingGroup = DispatchGroup()
                    var processedTrails: [Trail] = []
                    let trailProcessingQueue = DispatchQueue(label: "com.dois.trailProcessing.mirror")
                    for way in waysToProcess {
                        guard let id = way.id, let nodes = way.nodes else { continue }
                        var coordinates: [CLLocationCoordinate2D] = []
                        for nodeId in nodes { if let c = nodeCoordinates[nodeId] { coordinates.append(c) } }
                        guard coordinates.count > 1 else { continue }
                        processingGroup.enter()
                        trailProcessingQueue.async { [weak self] in
                            self?.processTrail(wayPoints: coordinates, tags: way.tags, activityType: activityType, id: String(id)) { trail in
                                if let trail = trail { processedTrails.append(trail) }
                                processingGroup.leave()
                            }
                        }
                    }
                    processingGroup.notify(queue: .main) { [weak self] in
                        guard let self = self else { return }
                        // Deduplicate and set trails for UI
                        let unique = Dictionary(grouping: processedTrails, by: { $0.id }).compactMap { $0.value.first }
                        self.setTrails(unique)
                        self.isGeneratingRoute = false
                        self.isFetchingTrails = false
                        completion(true)
                    }
                } catch {
                    print("❌ Overpass mirror decode failed: \(error)")
                    attempt(idx + 1)
                }
            }.resume()
        }
        attempt(0)
    }
    
    // Update processTrail to return a Trail object instead of modifying self
    private func processTrail(wayPoints: [CLLocationCoordinate2D], tags: [String: String]?, activityType: ActivityRouteType, id: String, completion: @escaping (Trail?) -> Void) {
        // Wrap the completion handler in a main queue dispatch to ensure it runs on the main thread
        let wrappedCompletion: (Trail?) -> Void = { [weak self] trail in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Notify SwiftUI that we're about to change the model
                self.objectWillChange.send()
                
                // Execute the original completion handler
                completion(trail)
                
                // Notify SwiftUI that we changed the model
                self.objectWillChange.send()
            }
        }
        
        guard let tags = tags else {
            wrappedCompletion(nil)
            return
        }
        
        // Extract trail name with better fallback options
        let name: String
        if let explicitName = tags["name"] {
            name = explicitName
        } else if let nameEn = tags["name:en"] {
            name = nameEn
        } else if let highway = tags["highway"] {
            name = "\(highway.capitalized) \(Int.random(in: 100...999))"
        } else {
            name = "Trail \(Int.random(in: 100...999))"
        }
        
        // Calculate approximate length
        var totalDistance: CLLocationDistance = 0.0
        
        if wayPoints.count > 1 {
            for i in 0..<(wayPoints.count - 1) {
                let start = CLLocation(latitude: wayPoints[i].latitude, longitude: wayPoints[i].longitude)
                let end = CLLocation(latitude: wayPoints[i + 1].latitude, longitude: wayPoints[i + 1].longitude)
                totalDistance += start.distance(from: end)
            }
        }
        
        // Convert meters to miles
        let lengthInMiles = totalDistance / 1609.34
        
        // Skip extremely short trails
        if lengthInMiles < 0.1 {
            // Be more selective - only accept short trails that have actual names
            if tags["name"] == nil || lengthInMiles < 0.05 {
                wrappedCompletion(nil)
                return
            }
        }
        
        // Create trail object
        // Use a fixed elevation gain estimation
        let elevationGain = lengthInMiles * 50.0  // ~50 feet per mile as estimate
        let rating = Double.random(in: 3.5...5.0) // Most trails rated well
        
        // Extract any useful metadata
        let description = tags["description"] ?? (tags["name:en"] ?? "A scenic \(activityType.rawValue) route")
        
        // Enhanced trail type classification
        let trailType = determineTrailType(from: tags, activityType: activityType)
        print("🏷️ Trail classification: '\(name)' -> \(trailType) (tags: \(tags))")
        
        // Determine difficulty based on tags or use default
        let difficulty: TrailDifficulty
        if let sac = tags["sac_scale"] {
            if sac.contains("demanding") || sac.contains("difficult") {
                difficulty = .difficult
            } else if sac.contains("mountain") || sac.contains("alpine") {
                difficulty = .veryDifficult
            } else {
                difficulty = .moderate
            }
        } else if let osmTag = tags["difficulty"] {
            if osmTag.contains("easy") {
                difficulty = .easy
            } else if osmTag.contains("hard") || osmTag.contains("difficult") {
                difficulty = .difficult
            } else {
                difficulty = .moderate
            }
        } else if elevationGain > lengthInMiles * 200 {
            // High elevation gain relative to distance
            difficulty = .difficult
        } else if elevationGain > lengthInMiles * 100 {
            difficulty = .moderate
        } else {
            difficulty = .easy
        }
        
        // Create the trail
        let newTrail = Trail(
            id: id,
            name: name,
            difficulty: difficulty,
            length: lengthInMiles,
            elevationGain: elevationGain,
            rating: rating,
            coordinates: wayPoints.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) },
            description: description,
            estimatedDuration: nil, // Add an appropriate value if available
            trailType: trailType
        )
        
        wrappedCompletion(newTrail)
    }
    
    // MARK: - Trail Type Classification
    
    private func determineTrailType(from tags: [String: String], activityType: ActivityRouteType) -> String {
        // Check for multi-use indicators
        if let access = tags["access"], access.contains("shared") || access.contains("multi") {
            return "multi-use"
        }
        
        // Check for leisure/recreation areas (parks, sports centers, etc.)
        if let leisure = tags["leisure"] {
            switch leisure {
            case "park", "playground", "garden":
                return "multi-use" // Parks are typically multi-use
            case "sports_centre", "fitness_centre", "stadium":
                return "multi-use" // Sports facilities are multi-use
            case "track":
                return "running"
            case "pitch", "court":
                return "multi-use" // Sports courts can be used for various activities
            default:
                break
            }
        }
        
        // Check for specific activity types
        if let bicycle = tags["bicycle"], bicycle == "yes" || bicycle == "designated" {
            if let foot = tags["foot"], foot == "yes" || foot == "designated" {
                return "multi-use"
            }
            return "cycling"
        }
        
        if let foot = tags["foot"], foot == "yes" || foot == "designated" {
            if let bicycle = tags["bicycle"], bicycle == "yes" || bicycle == "designated" {
                return "multi-use"
            }
            return "walking"
        }
        
        // Check highway type
        if let highway = tags["highway"] {
            switch highway {
            case "cycleway":
                return "cycling"
            case "footway", "pedestrian":
                return "walking"
            case "path":
                // Paths can be multi-use, check for additional tags
                if let bicycle = tags["bicycle"], bicycle == "yes" {
                    return "multi-use"
                }
                return "hiking"
            case "track":
                return "running"
            default:
                break
            }
        }
        
        // Check route type
        if let route = tags["route"] {
            switch route {
            case "bicycle":
                return "cycling"
            case "hiking":
                return "hiking"
            case "running":
                return "running"
            case "walking":
                return "walking"
            default:
                break
            }
        }
        
        // Check for sport facilities
        if let sport = tags["sport"] {
            let sports = sport.lowercased()
            if sports.contains("running") || sports.contains("track") {
                return "running"
            } else if sports.contains("cycling") || sports.contains("bike") {
                return "cycling"
            } else if sports.contains("hiking") || sports.contains("climbing") {
                return "hiking"
            } else {
                // Multi-sport facilities
                return "multi-use"
            }
        }
        
        // Fallback to activity type
        return activityType.rawValue
    }
    
    /// Clears all existing trails
    func clearTrails() {
        print("🧹 Cleared all trails")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.nearbyTrails = []
            self.objectWillChange.send()
        }
    }
    
    /// Sets the trails to a specific filtered list
    @MainActor
    func setTrails(_ trails: [Trail]) {
        // Make a fresh copy of the trails array
        let freshTrails = Array(trails)
        
        // Print what we're about to do
        print("🔄 RoutePlanner: Setting \(freshTrails.count) trails")
        
        // Update trails on main thread
        self.nearbyTrails = freshTrails
        self.objectWillChange.send()
        
        // Post notification for UI updates
        print("📢 Posting .routesDidChange notification from setTrails with \(freshTrails.count) trails")
        NotificationCenter.default.post(
            name: .routesDidChange,
            object: self,
            userInfo: [
                "trails": freshTrails,
                "timestamp": Date(),
                "forceUIUpdate": true,
                "refreshUI": true
            ]
        )
        
        print("✓ Routes loaded - \(freshTrails.count) routes available [FROM setTrails]")
    }
}

// MARK: - Extensions


extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
        
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        
        return coords
    }
}

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// Extension to make CLLocationCoordinate2D comparable
extension CLLocationCoordinate2D: Equatable {
    public static func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// For parsing elevation API responses
struct ElevationResponse: Codable {
    let results: [ElevationResult]
}

struct ElevationResult: Codable {
    let latitude: Double
    let longitude: Double
    let elevation: Double
}

// For parsing OpenStreetMap data via Overpass API
struct OverpassResponse: Codable {
    let elements: [OverpassElement]
}

struct OverpassElement: Codable {
    let id: Int?
    let type: String
    let lat: Double?
    let lon: Double?
    let tags: [String: String]?
    let nodes: [Int]?
}

struct Trail: Identifiable, Equatable {
    let id: String
    let name: String
    let difficulty: TrailDifficulty
    let length: Double // in miles
    var elevationGain: Double // in feet
    let rating: Double // 0-5 scale
    let coordinates: [Coordinate]
    let description: String?
    let estimatedDuration: TimeInterval?
    let trailType: String?
    
    // Simplified initializer for basic trails
    init(id: String = UUID().uuidString,
         name: String,
         difficulty: TrailDifficulty,
         length: Double,
         elevationGain: Double,
         rating: Double = 4.0,
         coordinates: [Coordinate] = [],
         description: String? = nil,
         estimatedDuration: TimeInterval? = nil,
         trailType: String? = nil) {
        
        self.id = id
        self.name = name
        self.difficulty = difficulty
        self.length = length
        self.elevationGain = elevationGain
        self.rating = rating
        self.coordinates = coordinates
        self.description = description
        self.estimatedDuration = estimatedDuration
        self.trailType = trailType
    }
    
    // Equatable implementation
    static func == (lhs: Trail, rhs: Trail) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name
    }
}

// Trail difficulty levels
enum TrailDifficulty: String, Codable {
    case easy
    case moderate
    case difficult
    case veryDifficult
}

// Simple coordinate type that can be stored in our Trail model
struct Coordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}


   




