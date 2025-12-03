//
//  WatchLocationManager.swift
//  Do Watch App
//
//  Location manager for watchOS workouts
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

#if os(watchOS)
import Foundation
import CoreLocation
import Combine

class WatchLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WatchLocationManager()
    
    private let locationManager = CLLocationManager()
    @Published var locationList: [CLLocation] = []
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    
    private var isTracking = false
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0 // Update every 5 meters
        locationManager.activityType = .fitness
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Public Methods
    
    func requestAuthorization() {
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func startTracking() {
        // Request authorization if not determined
        if authorizationStatus == .notDetermined {
            print("📍 Requesting location authorization...")
            requestAuthorization()
            // Will continue in locationManagerDidChangeAuthorization callback
            return
        }
        
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("⚠️ Location authorization not granted: \(authorizationStatus.rawValue)")
            return
        }
        
        if !isTracking {
            locationManager.startUpdatingLocation()
            isTracking = true
            locationList.removeAll()
            print("📍 Started location tracking")
        }
    }
    
    func stopTracking() {
        if isTracking {
            locationManager.stopUpdatingLocation()
            isTracking = false
            print("📍 Stopped location tracking")
        }
    }
    
    func clearLocations() {
        locationList.removeAll()
        print("📍 Cleared location list")
    }
    
    func getLocationListAsDictionary() -> [[String: Any]] {
        return locationList.map { location in
            [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "altitude": location.altitude,
                "horizontalAccuracy": location.horizontalAccuracy,
                "verticalAccuracy": location.verticalAccuracy,
                "course": location.course,
                "speed": location.speed,
                "timestamp": location.timestamp.timeIntervalSince1970
            ]
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = location
            
            // Only add locations with good accuracy
            if location.horizontalAccuracy > 0 && location.horizontalAccuracy < 50 {
                self.locationList.append(location)
                print("📍 Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude) (accuracy: \(location.horizontalAccuracy)m)")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            let oldStatus = self.authorizationStatus
            self.authorizationStatus = manager.authorizationStatus
            print("📍 Location authorization changed: \(oldStatus.rawValue) → \(manager.authorizationStatus.rawValue)")
            
            // If authorization was just granted and we're not tracking yet, start tracking
            if (oldStatus == .notDetermined || oldStatus == .denied || oldStatus == .restricted) &&
               (manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways) &&
               !self.isTracking {
                print("📍 Authorization granted, starting location tracking")
                self.startTracking()
            }
        }
    }
}
#endif
