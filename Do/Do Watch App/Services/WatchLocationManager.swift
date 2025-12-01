//
//  WatchLocationManager.swift
//  Do Watch App
//
//  Location tracking for watch workouts
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import CoreLocation
import Combine

// MARK: - Location Data Model

struct WatchLocationData: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let course: Double
    let speed: Double
    let timestamp: Date
    let heartRate: Double?
    let cadence: Double?
    
    init(from location: CLLocation, heartRate: Double? = nil, cadence: Double? = nil) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
        self.course = location.course
        self.speed = location.speed
        self.timestamp = location.timestamp
        self.heartRate = heartRate
        self.cadence = cadence
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude,
            "altitude": altitude,
            "horizontalAccuracy": horizontalAccuracy,
            "verticalAccuracy": verticalAccuracy,
            "course": course,
            "speed": speed,
            "timestamp": timestamp.timeIntervalSince1970
        ]
        if let hr = heartRate {
            dict["heartRate"] = hr
        }
        if let cad = cadence {
            dict["cadence"] = cad
        }
        return dict
    }
    
    func distance(from other: WatchLocationData) -> Double {
        let location1 = CLLocation(latitude: latitude, longitude: longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2)
    }
}

// MARK: - Watch Location Manager

@MainActor
class WatchLocationManager: NSObject, ObservableObject {
    static let shared = WatchLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var locationList: [WatchLocationData] = []
    @Published var isTracking = false
    
    private let locationManager = CLLocationManager()
    private var lastLocationUpdate: Date?
    private let minUpdateInterval: TimeInterval = 1.0 // Minimum 1 second between updates
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // Update every 5 meters
        locationManager.activityType = .fitness
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        guard authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Location Tracking
    
    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("⚠️ [WatchLocationManager] Cannot start tracking - authorization: \(authorizationStatus.rawValue)")
            requestAuthorization()
            return
        }
        
        guard !isTracking else {
            print("⚠️ [WatchLocationManager] Already tracking")
            return
        }
        
        print("📍 [WatchLocationManager] Starting location tracking")
        locationList.removeAll()
        isTracking = true
        locationManager.startUpdatingLocation()
    }
    
    func stopTracking() {
        guard isTracking else { return }
        
        print("📍 [WatchLocationManager] Stopping location tracking (collected \(locationList.count) locations)")
        locationManager.stopUpdatingLocation()
        isTracking = false
    }
    
    func clearLocations() {
        locationList.removeAll()
    }
    
    // MARK: - Location Access
    
    func getLocationList() -> [WatchLocationData] {
        return locationList
    }
    
    func getLocationListAsDictionary() -> [[String: Any]] {
        return locationList.map { $0.toDictionary() }
    }
}

// MARK: - CLLocationManagerDelegate

extension WatchLocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            print("📍 [WatchLocationManager] Authorization changed: \(manager.authorizationStatus.rawValue)")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Filter out invalid locations
        guard location.horizontalAccuracy > 0 && location.horizontalAccuracy < 100 else {
            print("⚠️ [WatchLocationManager] Invalid location accuracy: \(location.horizontalAccuracy)")
            return
        }
        
        Task { @MainActor in
            // Throttle updates
            let now = Date()
            if let lastUpdate = self.lastLocationUpdate,
               now.timeIntervalSince(lastUpdate) < self.minUpdateInterval {
                return
            }
            
            self.lastLocationUpdate = now
            self.currentLocation = location
            
            // Get current heart rate and cadence from HealthKit if available
            let heartRate: Double? = await HealthKitWorkoutManager.shared.getCurrentMetrics()?.heartRate
            let cadence: Double? = await HealthKitWorkoutManager.shared.getCurrentMetrics()?.cadence
            
            // Create location data
            let locationData = WatchLocationData(from: location, heartRate: heartRate, cadence: cadence)
            
            // Add to list if it's a new location
            if self.locationList.isEmpty {
                self.locationList = [locationData]
            } else if let lastLocation = self.locationList.last,
                      lastLocation.distance(from: locationData) > 2.0 { // Only add if moved > 2 meters
                self.locationList.append(locationData)
                print("📍 [WatchLocationManager] Added location #\(self.locationList.count): (\(location.coordinate.latitude), \(location.coordinate.longitude))")
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ [WatchLocationManager] Location error: \(error.localizedDescription)")
    }
}

