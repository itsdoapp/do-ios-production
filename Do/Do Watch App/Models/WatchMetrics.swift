//
//  WatchMetrics.swift
//  Do Watch App
//
//  Unified metrics structure
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

struct WorkoutMetrics: Codable {
    var distance: Double // in meters
    var elapsedTime: TimeInterval // in seconds
    var heartRate: Double // bpm
    var pace: Double // seconds per meter
    var calories: Double // kcal
    var cadence: Double? // steps/min or strides/min
    var elevationGain: Double? // meters
    var averagePace: Double? // seconds per meter
    var currentSpeed: Double? // meters per second
    
    init(distance: Double = 0,
         elapsedTime: TimeInterval = 0,
         heartRate: Double = 0,
         pace: Double = 0,
         calories: Double = 0,
         cadence: Double? = nil,
         elevationGain: Double? = nil,
         averagePace: Double? = nil,
         currentSpeed: Double? = nil) {
        self.distance = distance
        self.elapsedTime = elapsedTime
        self.heartRate = heartRate
        self.pace = pace
        self.calories = calories
        self.cadence = cadence
        self.elevationGain = elevationGain
        self.averagePace = averagePace
        self.currentSpeed = currentSpeed
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "distance": distance,
            "elapsedTime": elapsedTime,
            "heartRate": heartRate,
            "pace": pace,
            "calories": calories
        ]
        
        if let cadence = cadence {
            dict["cadence"] = cadence
        }
        if let elevationGain = elevationGain {
            dict["elevationGain"] = elevationGain
        }
        if let averagePace = averagePace {
            dict["averagePace"] = averagePace
        }
        if let currentSpeed = currentSpeed {
            dict["currentSpeed"] = currentSpeed
        }
        
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> WorkoutMetrics? {
        guard let distance = dict["distance"] as? Double,
              let elapsedTime = dict["elapsedTime"] as? TimeInterval,
              let heartRate = dict["heartRate"] as? Double,
              let pace = dict["pace"] as? Double,
              let calories = dict["calories"] as? Double else {
            return nil
        }
        
        return WorkoutMetrics(
            distance: distance,
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            pace: pace,
            calories: calories,
            cadence: dict["cadence"] as? Double,
            elevationGain: dict["elevationGain"] as? Double,
            averagePace: dict["averagePace"] as? Double,
            currentSpeed: dict["currentSpeed"] as? Double
        )
    }
    
    // MARK: - Formatting Helpers
    
    func formattedDistance(useImperial: Bool = false) -> String {
        if useImperial {
            let miles = distance / 1609.34
            return String(format: "%.2f mi", miles)
        } else {
            let km = distance / 1000.0
            return String(format: "%.2f km", km)
        }
    }
    
    func formattedTime() -> String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    func formattedPace(useImperial: Bool = false) -> String {
        guard pace > 0 else { return "--:--" }
        
        if useImperial {
            // Convert to min/mile
            let pacePerMile = pace * 1609.34
            let minutes = Int(pacePerMile) / 60
            let seconds = Int(pacePerMile) % 60
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            // Convert to min/km
            let pacePerKm = pace * 1000.0
            let minutes = Int(pacePerKm) / 60
            let seconds = Int(pacePerKm) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    func formattedHeartRate() -> String {
        return String(format: "%.0f bpm", heartRate)
    }
    
    func formattedCalories() -> String {
        return String(format: "%.0f kcal", calories)
    }
}

// MARK: - Metrics Source

enum MetricsSource: String, Codable {
    case phone = "phone"
    case watch = "watch"
    case oura = "oura"
    case garmin = "garmin"
    case fitbit = "fitbit"
    case healthKit = "healthKit"
    case merged = "merged"
}

struct MetricsWithSource {
    let metrics: WorkoutMetrics
    let source: MetricsSource
    let timestamp: Date
    let accuracy: Double? // 0.0 to 1.0, higher is better
    
    init(metrics: WorkoutMetrics, source: MetricsSource, timestamp: Date = Date(), accuracy: Double? = nil) {
        self.metrics = metrics
        self.source = source
        self.timestamp = timestamp
        self.accuracy = accuracy
    }
}

// MARK: - Metric Type

enum MetricType {
    case distance
    case pace
    case heartRate
    case cadence
    case calories
    case elevation
    case speed
}
