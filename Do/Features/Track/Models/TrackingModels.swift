//
//  TrackingModels.swift
//  Do
//
//  Shared tracking models and types
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit
import UIKit

// MARK: - Split Time

/// Represents a split time for a workout segment
struct SplitTime: Identifiable, Codable {
    let id = UUID()
    let distance: Double // in meters
    let time: TimeInterval // in seconds
    let pace: Double // seconds per meter
    let timestamp: Date
    
    init(distance: Double, time: TimeInterval, pace: Double, timestamp: Date = Date()) {
        self.distance = distance
        self.time = time
        self.pace = pace
        self.timestamp = timestamp
    }
}

// MARK: - Map View Mode

/// Map display mode for workout tracking
enum MapViewMode: String, CaseIterable {
    case normal = "Normal"
    case satellite = "Satellite"
    case hybrid = "Hybrid"
    case terrain = "Terrain"
    case fullscreen = "Fullscreen"
    case minimized = "Minimized"
    case hidden = "Hidden"
    
    var mapType: MKMapType {
        switch self {
        case .normal: return .standard
        case .satellite: return .satellite
        case .hybrid: return .hybrid
        case .terrain: return .standard // Terrain not directly supported, use standard
        case .fullscreen, .minimized, .hidden: return .standard // Display modes use standard map type
        }
    }
}

// MARK: - Location Data

/// Location data point for tracking routes
struct LocationData {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let course: Double
    let speed: Double
    let distance: Double
    let timestamp: Date
    let heartRate: Double?
    let cadence: Double?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double, altitude: Double = 0, horizontalAccuracy: Double = 0, verticalAccuracy: Double = 0, course: Double = 0, speed: Double = 0, distance: Double = 0, timestamp: Date = Date(), heartRate: Double? = nil, cadence: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.course = course
        self.speed = speed
        self.distance = distance
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.cadence = cadence
    }
    
    /// Convenience initializer from CLLocation
    init(from location: CLLocation, heartRate: Double? = nil, cadence: Double? = nil) {
        self.init(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            course: location.course,
            speed: location.speed,
            distance: 0, // Distance will be calculated incrementally
            timestamp: location.timestamp,
            heartRate: heartRate,
            cadence: cadence
        )
    }
    
    /// Calculates the distance in meters from another LocationData point.
    func distance(from other: LocationData) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2)
    }
}

// MARK: - Route Annotation

/// Map annotation for route points
struct RouteAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType
    let title: String?
    
    enum AnnotationType {
        case start
        case end
        case currentLocation
        case waypoint
    }
    
    init(coordinate: CLLocationCoordinate2D, type: AnnotationType, title: String? = nil) {
        self.coordinate = coordinate
        self.type = type
        self.title = title
    }
}

// MARK: - Route Annotation MK (MKAnnotation-compatible)

/// MKAnnotation-compatible version of RouteAnnotation for use with MKMapView
class RouteAnnotationMK: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let type: RouteAnnotation.AnnotationType
    let title: String?
    
    var subtitle: String? {
        switch type {
        case .start: return "Start Point"
        case .end: return "Finish Point"
        case .currentLocation: return "Current Location"
        case .waypoint: return "Waypoint"
        }
    }
    
    init(coordinate: CLLocationCoordinate2D, type: RouteAnnotation.AnnotationType, title: String? = nil) {
        self.coordinate = coordinate
        self.type = type
        self.title = title
        super.init()
    }
    
    /// Convenience initializer from RouteAnnotation
    convenience init(annotation: RouteAnnotation) {
        self.init(coordinate: annotation.coordinate, type: annotation.type, title: annotation.title)
    }
}

// MARK: - Personal Record

/// Personal record achievement
struct PersonalRecord: Identifiable {
    var id = UUID()
    var type: String // "5K", "10K", "Half Marathon", "Fastest Pace", etc.
    var value: String
    var date: Date
    
    init(type: String, value: String, date: Date = Date()) {
        self.type = type
        self.value = value
        self.date = date
    }
}

// MARK: - Form Feedback

/// Running/hiking form analysis feedback
struct FormFeedback: Identifiable {
    var id = UUID()
    var cadenceFeedback: String?
    var strideLengthFeedback: String?
    var verticalOscillationFeedback: String?
    var groundContactTimeFeedback: String?
    var overallAssessment: String
    var improvementSuggestions: [String]
    
    init(cadenceFeedback: String? = nil, strideLengthFeedback: String? = nil, verticalOscillationFeedback: String? = nil, groundContactTimeFeedback: String? = nil, overallAssessment: String = "", improvementSuggestions: [String] = []) {
        self.cadenceFeedback = cadenceFeedback
        self.strideLengthFeedback = strideLengthFeedback
        self.verticalOscillationFeedback = verticalOscillationFeedback
        self.groundContactTimeFeedback = groundContactTimeFeedback
        self.overallAssessment = overallAssessment
        self.improvementSuggestions = improvementSuggestions
    }
}

// MARK: - AI Analysis Results

/// AI-powered workout analysis results
struct AIAnalysisResults: Identifiable {
    var id = UUID()
    var performanceScore: Double // 0.0 to 1.0
    var strengths: [String]
    var weaknesses: [String]
    var recommendations: [String]
    var predictedRecoveryTime: TimeInterval?
    var formFeedback: FormFeedback?
    var formEfficiency: Double? // 0-100% scale
    var fatigueLevel: Double? // 0-100 scale
    var recommendedRecoveryTime: TimeInterval? // Alias for predictedRecoveryTime
    var paceConsistency: Double? // 0-100% scale
    
    init(performanceScore: Double = 0.0, strengths: [String] = [], weaknesses: [String] = [], recommendations: [String] = [], predictedRecoveryTime: TimeInterval? = nil, formFeedback: FormFeedback? = nil, formEfficiency: Double? = nil, fatigueLevel: Double? = nil, recommendedRecoveryTime: TimeInterval? = nil, paceConsistency: Double? = nil) {
        self.performanceScore = performanceScore
        self.strengths = strengths
        self.weaknesses = weaknesses
        self.recommendations = recommendations
        self.predictedRecoveryTime = predictedRecoveryTime ?? recommendedRecoveryTime
        self.formFeedback = formFeedback
        self.formEfficiency = formEfficiency
        self.fatigueLevel = fatigueLevel
        self.recommendedRecoveryTime = recommendedRecoveryTime ?? predictedRecoveryTime
        self.paceConsistency = paceConsistency
    }
}

// MARK: - Environmental Conditions

/// Environmental conditions during workout
struct EnvironmentalConditions: Codable {
    var temperature: Double? // Celsius
    var humidity: Double? // Percentage
    var windSpeed: Double? // m/s
    var windDirection: Double? // Degrees
    var weatherCondition: String? // "sunny", "cloudy", "rainy", etc.
    var airQuality: Double? // AQI
    var pressure: Double? // hPa
    var elevation: Double? // meters
    
    init(temperature: Double? = nil, humidity: Double? = nil, windSpeed: Double? = nil, windDirection: Double? = nil, weatherCondition: String? = nil, airQuality: Double? = nil, pressure: Double? = nil, elevation: Double? = nil) {
        self.temperature = temperature
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.weatherCondition = weatherCondition
        self.airQuality = airQuality
        self.pressure = pressure
        self.elevation = elevation
    }
}

// MARK: - Heart Rate Zone Type

/// Heart rate zone type enum
enum HeartRateZoneType: String, Codable {
    case none = "none"
    case recovery = "recovery"
    case easy = "easy"
    case aerobic = "aerobic"
    case threshold = "threshold"
    case anaerobic = "anaerobic"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .recovery: return "Recovery"
        case .easy: return "Easy"
        case .aerobic: return "Aerobic"
        case .threshold: return "Threshold"
        case .anaerobic: return "Anaerobic"
        }
    }
    
    var zoneNumber: Int {
        switch self {
        case .none: return 0
        case .recovery: return 1
        case .easy: return 2
        case .aerobic: return 3
        case .threshold: return 4
        case .anaerobic: return 5
        }
    }
    
    var color: UIColor {
        switch self {
        case .none: return .gray
        case .recovery: return .systemBlue
        case .easy: return .systemGreen
        case .aerobic: return .systemYellow
        case .threshold: return .systemOrange
        case .anaerobic: return .systemRed
        }
    }
}

// MARK: - Heart Rate Zone

/// Heart rate zone information
struct HeartRateZone: Identifiable {
    var id = UUID()
    var zone: Int // 1-5
    var name: String
    var minBPM: Double
    var maxBPM: Double
    var timeInZone: TimeInterval
    var percentage: Double // Percentage of total time
    
    init(zone: Int, name: String, minBPM: Double, maxBPM: Double, timeInZone: TimeInterval = 0, percentage: Double = 0) {
        self.zone = zone
        self.name = name
        self.minBPM = minBPM
        self.maxBPM = maxBPM
        self.timeInZone = timeInZone
        self.percentage = percentage
    }
}

// MARK: - Audio Feedback Type

/// Types of audio feedback for workout tracking
enum AudioFeedbackType {
    case startWorkout
    case pauseWorkout
    case resumeWorkout
    case endWorkout
    case milestone
    case paceAlert
    case heartRateAlert
    case custom(String) // Custom message
    
    var description: String {
        switch self {
        case .startWorkout: return "Workout started"
        case .pauseWorkout: return "Workout paused"
        case .resumeWorkout: return "Workout resumed"
        case .endWorkout: return "Workout completed"
        case .milestone: return "Milestone reached"
        case .paceAlert: return "Pace alert"
        case .heartRateAlert: return "Heart rate alert"
        case .custom(let message): return message
        }
    }
}
