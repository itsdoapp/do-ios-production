//
//  ActivityLogModels.swift
//  Track Infrastructure
//
//  Extracted from Do./Util/Extensions.swift and Do./ViewControllers/Tracking/Walking/WalkingTypes.swift
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

// MARK: - Protocols

/// Protocol for running log types (similar to WalkingLogProtocol)
public protocol RunningLogProtocol {
    var id: String? { get }
    var duration: String? { get }
    var distance: String? { get }
    var avgPace: String? { get }
    var createdAt: Date? { get }
    var createdAtFormatted: String? { get }
    var createdBy: String? { get }
    var caloriesBurned: Double? { get }
}

// MARK: - RunLog

public struct RunLog: Hashable, RunningLogProtocol {
    public static func == (lhs: RunLog, rhs: RunLog) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        if let locationData = locationData {
            for dict in locationData {
                for (key, value) in dict {
                    hasher.combine(key)
                    if let value = value as? Int {
                        hasher.combine(value)
                    } else if let value = value as? String {
                        hasher.combine(value)
                    }
                }
            }
        }
    }
    
    // MARK: - Protocol-Required Properties (must be public)
    public var id: String?
    public var duration: String?
    public var distance: String?
    public var avgPace: String?
    public var paceValues: [Double]?
    public var createdAt: Date?
    public var createdAtFormatted: String?
    public var createdBy: String? // Cognito user ID (String, not PFUser)
    public var caloriesBurned: Double?
    
    // MARK: - Additional Properties
    // Type field: "indoor" or "outdoor"
    public var type: String? // "indoor" or "outdoor"
    
    // Run type: "outdoor_run", "treadmill", "indoor_track", etc.
    public var runType: String?
    
    // Outdoor-specific fields
    public var coordinateArray: [[String: Double]]? // Replaces [PFGeoPoint] - array of [latitude, longitude] dicts
    public var locationData: [[String: Any]]? // GPS route data
    public var netElevation: String?
    public var elevationGain: String?
    public var elevationLoss: String?
    
    // Indoor-specific fields
    public var treadmillDataPoints: [TreadmillDataPoint]? // Indoor run data points
    
    // Heart rate metrics
    public var avgHeartRate: Double?
    public var maxHeartRate: Double?
    public var heartRateZones: [String: Double]? // Heart rate zones with time spent in each zone (zone number as string key)
    
    // Advanced running metrics
    public var avgCadence: Double? // Average cadence (steps per minute)
    public var maxSpeed: Double? // Maximum speed (mph for outdoor, can be used for indoor too)
    public var avgSpeed: Double? // Average speed (mph - mainly for indoor runs)
    
    // Indoor-specific metrics
    public var avgIncline: Double? // Average incline percentage (for treadmill)
    public var maxIncline: Double? // Maximum incline percentage (for treadmill)
    
    // Route and weather data
    public var routeDataUrl: String? // S3 URL for full route data
    public var weather: String?
    public var temperature: Double?
    
    // Notes
    public var notes: String? // User notes about the run
    
    func toJson() -> [String: Any] {
        var json: [String: Any] = [
            "id": id ?? "",
            "duration": duration ?? "",
            "distance": distance ?? "",
            "createdAtFormatted": createdAtFormatted ?? "",
            "averagePace": avgPace ?? "",
            "createdAt": createdAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
            "createdBy": createdBy ?? "",
            "caloriesBurned": caloriesBurned ?? 0.0,
            "type": type ?? "outdoor",
            "runType": runType ?? ""
        ]
        
        // Add type-specific fields
        if type == "indoor" {
            json["treadmillDataPoints"] = treadmillDataPoints?.map { $0.toDictionary() } ?? []
        } else {
            json["coordinateArray"] = coordinateArray ?? []
            json["locationData"] = locationData ?? []
            json["netElevation"] = netElevation ?? ""
            json["elevationGain"] = elevationGain ?? ""
            json["elevationLoss"] = elevationLoss ?? ""
        }
        
        // Add common fields
        if let paceValues = paceValues { json["paceValues"] = paceValues }
        if let avgHeartRate = avgHeartRate { json["avgHeartRate"] = avgHeartRate }
        if let maxHeartRate = maxHeartRate { json["maxHeartRate"] = maxHeartRate }
        if let heartRateZones = heartRateZones { json["heartRateZones"] = heartRateZones }
        if let avgCadence = avgCadence { json["avgCadence"] = avgCadence }
        if let maxSpeed = maxSpeed { json["maxSpeed"] = maxSpeed }
        if let avgSpeed = avgSpeed { json["avgSpeed"] = avgSpeed }
        if let avgIncline = avgIncline { json["avgIncline"] = avgIncline }
        if let maxIncline = maxIncline { json["maxIncline"] = maxIncline }
        if let routeDataUrl = routeDataUrl { json["routeDataUrl"] = routeDataUrl }
        if let weather = weather { json["weather"] = weather }
        if let temperature = temperature { json["temperature"] = temperature }
        if let notes = notes { json["notes"] = notes }
        
        return json
    }
    
    static func fromJSON(json: [String: Any]) -> RunLog? {
        let id = json["id"] as? String
        let duration = json["duration"] as? String
        let distance = json["distance"] as? String
        let avgPace = json["averagePace"] as? String
        let paceValues = json["paceValues"] as? [Double]
        let createdAt = json["createdAt"] as? Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        let formattedDate = dateFormatter.string(from: createdAt ?? Date())
        let createdAtFormatted = formattedDate
        let createdBy = json["createdBy"] as? String
        let caloriesBurned = json["caloriesBurned"] as? Double
        let type = json["type"] as? String ?? "outdoor"
        let runType = json["runType"] as? String
        let avgHeartRate = json["avgHeartRate"] as? Double
        let maxHeartRate = json["maxHeartRate"] as? Double
        let heartRateZones = json["heartRateZones"] as? [String: Double]
        let avgCadence = json["avgCadence"] as? Double
        let maxSpeed = json["maxSpeed"] as? Double
        let avgSpeed = json["avgSpeed"] as? Double
        let avgIncline = json["avgIncline"] as? Double
        let maxIncline = json["maxIncline"] as? Double
        let routeDataUrl = json["routeDataUrl"] as? String
        let weather = json["weather"] as? String
        let temperature = json["temperature"] as? Double
        let notes = json["notes"] as? String
        
        // Type-specific parsing
        var treadmillDataPoints: [TreadmillDataPoint]? = nil
        var coordinateArray: [[String: Double]]? = nil
        var locationData: [[String: Any]]? = nil
        var netElevation: String? = nil
        var elevationGain: String? = nil
        var elevationLoss: String? = nil
        
        if type == "indoor" {
            let treadmillDataPointsArray = json["treadmillDataPoints"] as? [[String : Any]]
            treadmillDataPoints = treadmillDataPointsArray?.compactMap { TreadmillDataPoint.fromDictionary($0) }
        } else {
            // Handle coordinateArray - could be [PFGeoPoint] or [[String: Double]]
            if let coordArray = json["coordinateArray"] as? [[String: Double]] {
                coordinateArray = coordArray
            }
            locationData = json["locationData"] as? [[String: Any]] ?? []
            netElevation = json["netElevation"] as? String
            elevationGain = json["elevationGain"] as? String
            elevationLoss = json["elevationLoss"] as? String
        }

        var runLog = RunLog(
            id: id,
            duration: duration,
            distance: distance,
            avgPace: avgPace,
            paceValues: paceValues,
            createdAt: createdAt,
            createdAtFormatted: createdAtFormatted,
            createdBy: createdBy,
            caloriesBurned: caloriesBurned,
            type: type,
            runType: runType,
            coordinateArray: coordinateArray,
            locationData: locationData,
            netElevation: netElevation,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            treadmillDataPoints: treadmillDataPoints,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            heartRateZones: heartRateZones,
            avgCadence: avgCadence,
            maxSpeed: maxSpeed,
            avgSpeed: avgSpeed,
            avgIncline: avgIncline,
            maxIncline: maxIncline,
            routeDataUrl: routeDataUrl,
            weather: weather,
            temperature: temperature,
            notes: notes
        )
        return runLog
    }
    
    static func fromJSONDashboard(json: [String: Any]) -> RunLog? {
        let id = json["objectId"] as? String
        let duration = json["Duration"] as? String
        let distance = json["Distance"] as? String
        let avgPace = json["averagePace"] as? String
        let paceValues = json["paceValues"] as? [Double]
        let createdAt = json["createdAt"] as? Date
        let createdBy = json["createdBy"] as? String // Already a String from AWS
        let caloriesBurned = json["calories"] as? Double
        let netElevation = json["netElevation"] as? String
        let elevationGain = json["elevationGain"] as? String
        let elevationLoss = json["elevationLoss"] as? String
        let locationData = json["locationData"] as? [[String: Any]] ?? []
        let type = json["type"] as? String ?? "outdoor"
        let runType = json["runType"] as? String
        let avgHeartRate = json["avgHeartRate"] as? Double
        let maxHeartRate = json["maxHeartRate"] as? Double
        let heartRateZones = json["heartRateZones"] as? [String: Double]
        let avgCadence = json["avgCadence"] as? Double
        let maxSpeed = json["maxSpeed"] as? Double
        let avgSpeed = json["avgSpeed"] as? Double
        let avgIncline = json["avgIncline"] as? Double
        let maxIncline = json["maxIncline"] as? Double
        let routeDataUrl = json["routeDataUrl"] as? String
        let weather = json["weather"] as? String
        let temperature = json["temperature"] as? Double
        let notes = json["notes"] as? String
        
        var createdAtFormatted = ""
        if let createdAt = json["createdAt"] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            if let date = formatter.date(from: createdAt) {
                createdAtFormatted = date.timeAgoSinceDateForPost()
            }
        }
        
        // Type-specific parsing
        var treadmillDataPoints: [TreadmillDataPoint]? = nil
        var coordinateArray: [[String: Double]]? = nil
        
        if type == "indoor" {
            let treadmillDataPointsArray = json["treadmillDataPoints"] as? [[String : Any]]
            treadmillDataPoints = treadmillDataPointsArray?.compactMap { TreadmillDataPoint.fromDictionary($0) }
        } else {
            if let coordArray = json["coordinateArray"] as? [[String: Double]] {
                coordinateArray = coordArray
            }
        }
        
        var runLog = RunLog(
            id: id,
            duration: duration,
            distance: distance,
            avgPace: avgPace,
            paceValues: paceValues,
            createdAt: createdAt,
            createdAtFormatted: createdAtFormatted,
            createdBy: createdBy,
            caloriesBurned: caloriesBurned,
            type: type,
            runType: runType,
            coordinateArray: coordinateArray,
            locationData: locationData,
            netElevation: netElevation,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            treadmillDataPoints: treadmillDataPoints,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            heartRateZones: heartRateZones,
            avgCadence: avgCadence,
            maxSpeed: maxSpeed,
            avgSpeed: avgSpeed,
            avgIncline: avgIncline,
            maxIncline: maxIncline,
            routeDataUrl: routeDataUrl,
            weather: weather,
            temperature: temperature,
            notes: notes
        )
        return runLog
    }
    
    // Copy methods for backward compatibility
    mutating func copy(from log: RunLog) {
        id = log.id
        duration = log.duration
        distance = log.distance
        coordinateArray = log.coordinateArray
        avgPace = log.avgPace
        paceValues = log.paceValues
        createdAt = log.createdAt
        createdAtFormatted = log.createdAtFormatted
        createdBy = log.createdBy
        netElevation = log.netElevation
        elevationGain = log.elevationGain
        elevationLoss = log.elevationLoss
        caloriesBurned = log.caloriesBurned
        locationData = log.locationData
        type = log.type
        runType = log.runType
        treadmillDataPoints = log.treadmillDataPoints
        avgHeartRate = log.avgHeartRate
        maxHeartRate = log.maxHeartRate
        heartRateZones = log.heartRateZones
        avgCadence = log.avgCadence
        maxSpeed = log.maxSpeed
        avgSpeed = log.avgSpeed
        avgIncline = log.avgIncline
        maxIncline = log.maxIncline
        routeDataUrl = log.routeDataUrl
        weather = log.weather
        temperature = log.temperature
        notes = log.notes
    }
}

// Legacy type alias for backward compatibility
public typealias IndoorRunLog = RunLog

// MARK: - TreadmillDataPoint

public struct TreadmillDataPoint {
    public var timestamp: Date
    public var distance: Double
    public var heartRate: Double
    public var cadence: Double
    public var speed: Double
    public var pace: Double
    
    public init(timestamp: Date, distance: Double, heartRate: Double, cadence: Double, speed: Double, pace: Double) {
        self.timestamp = timestamp
        self.distance = distance
        self.heartRate = heartRate
        self.cadence = cadence
        self.speed = speed
        self.pace = pace
    }

    public func toDictionary() -> [String: Any] {
        return [
            "timestamp": timestamp.timeIntervalSince1970,
            "distance": distance,
            "heartRate": heartRate,
            "cadence": cadence,
            "speed": speed,
            "pace": pace
        ]
    }

    public static func fromDictionary(_ dict: [String: Any]) -> TreadmillDataPoint? {
        guard let timestamp = dict["timestamp"] as? TimeInterval,
              let distance = dict["distance"] as? Double,
              let heartRate = dict["heartRate"] as? Double,
              let cadence = dict["cadence"] as? Double,
              let speed = dict["speed"] as? Double,
              let pace = dict["pace"] as? Double else {
            return nil
        }
        return TreadmillDataPoint(
            timestamp: Date(timeIntervalSince1970: timestamp),
            distance: distance,
            heartRate: heartRate,
            cadence: cadence,
            speed: speed,
            pace: pace
        )
    }
}

// MARK: - BikeLog

public struct BikeLog: Hashable {
    public static func == (lhs: BikeLog, rhs: BikeLog) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        if let locationData = locationData {
            for dict in locationData {
                for (key, value) in dict {
                    hasher.combine(key)
                    if let value = value as? Int {
                        hasher.combine(value)
                    } else if let value = value as? String {
                        hasher.combine(value)
                    }
                }
            }
        }
    }
    
    var id: String?
    var duration: String?
    var distance: String?
    var avgPace: String?
    var paceValues: [Double]?
    var createdAt: Date?
    var createdAtFormatted: String?
    var createdBy: String? // Cognito user ID (String, not PFUser)
    var caloriesBurned: Double?
    
    // Type field: "indoor" or "outdoor"
    var type: String? // "indoor" or "outdoor"
    
    // Bike type: "outdoor_bike", "mountain_bike", "road_bike", "indoor", "stationary", etc.
    var bikeType: String?
    
    // Outdoor-specific fields
    var coordinateArray: [[String: Double]]? // Replaces [PFGeoPoint] - array of [latitude, longitude] dicts
    var locationData: [[String: Any]]? // GPS route data
    var netElevation: String?
    var elevationGain: String?
    var elevationLoss: String?
    
    // Indoor-specific fields
    var bikeDataPoints: [BikeDataPoint]? // Indoor bike data points
    
    // Common bike metrics
    var avgSpeed: Double?
    var maxSpeed: Double?
    var avgCadence: Double?
    var avgPower: Double?
    var cadence: Int?
    var power: Int?
    
    // Heart rate metrics
    var avgHeartRate: Double?
    var maxHeartRate: Double?
    
    // Route and weather data
    var routeDataUrl: String? // S3 URL for full route data
    var weather: String?
    var temperature: Double?
    
    func toJson() -> [String: Any] {
        var json: [String: Any] = [
            "id": id ?? "",
            "duration": duration ?? "",
            "distance": distance ?? "",
            "createdAtFormatted": createdAtFormatted ?? "",
            "averagePace": avgPace ?? "",
            "createdAt": createdAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
            "createdBy": createdBy ?? "",
            "caloriesBurned": caloriesBurned ?? 0.0,
            "type": type ?? "outdoor",
            "bikeType": bikeType ?? ""
        ]
        
        // Add type-specific fields
        if type == "indoor" {
            json["bikeDataPoints"] = bikeDataPoints?.map { $0.toDictionary() } ?? []
        } else {
            json["coordinateArray"] = coordinateArray ?? []
            json["locationData"] = locationData ?? []
            json["netElevation"] = netElevation ?? ""
            json["elevationGain"] = elevationGain ?? ""
            json["elevationLoss"] = elevationLoss ?? ""
        }
        
        // Add common metrics
        if let avgSpeed = avgSpeed { json["avgSpeed"] = avgSpeed }
        if let maxSpeed = maxSpeed { json["maxSpeed"] = maxSpeed }
        if let avgCadence = avgCadence { json["avgCadence"] = avgCadence }
        if let avgPower = avgPower { json["avgPower"] = avgPower }
        if let cadence = cadence { json["cadence"] = cadence }
        if let power = power { json["power"] = power }
        if let paceValues = paceValues { json["paceValues"] = paceValues }
        
        // Add heart rate metrics
        if let avgHeartRate = avgHeartRate { json["avgHeartRate"] = avgHeartRate }
        if let maxHeartRate = maxHeartRate { json["maxHeartRate"] = maxHeartRate }
        
        // Add route and weather data
        if let routeDataUrl = routeDataUrl { json["routeDataUrl"] = routeDataUrl }
        if let weather = weather { json["weather"] = weather }
        if let temperature = temperature { json["temperature"] = temperature }
        
        return json
    }
    
    static func fromJSON(json: [String: Any]) -> BikeLog? {
        let id = json["id"] as? String
        let duration = json["duration"] as? String
        let distance = json["distance"] as? String
        let avgPace = json["averagePace"] as? String
        let paceValues = json["paceValues"] as? [Double]
        let createdAt = json["createdAt"] as? Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        let formattedDate = dateFormatter.string(from: createdAt ?? Date())
        let createdAtFormatted = formattedDate
        let createdBy = json["createdBy"] as? String
        let caloriesBurned = json["caloriesBurned"] as? Double
        let type = json["type"] as? String ?? "outdoor"
        let bikeType = json["bikeType"] as? String
        
        // Type-specific parsing
        var bikeDataPoints: [BikeDataPoint]? = nil
        var coordinateArray: [[String: Double]]? = nil
        var locationData: [[String: Any]]? = nil
        var netElevation: String? = nil
        var elevationGain: String? = nil
        var elevationLoss: String? = nil
        
        if type == "indoor" {
            let bikeDataPointsArray = json["bikeDataPoints"] as? [[String : Any]]
            bikeDataPoints = bikeDataPointsArray?.compactMap { BikeDataPoint.fromDictionary($0) }
        } else {
            // Handle coordinateArray - could be [PFGeoPoint] or [[String: Double]]
            if let coordArray = json["coordinateArray"] as? [[String: Double]] {
                coordinateArray = coordArray
            }
            locationData = json["locationData"] as? [[String: Any]] ?? []
            netElevation = json["netElevation"] as? String
            elevationGain = json["elevationGain"] as? String
            elevationLoss = json["elevationLoss"] as? String
        }
        
        let avgSpeed = json["avgSpeed"] as? Double
        let maxSpeed = json["maxSpeed"] as? Double
        let avgCadence = json["avgCadence"] as? Double
        let avgPower = json["avgPower"] as? Double
        let cadence = json["cadence"] as? Int
        let power = json["power"] as? Int
        
        // Heart rate metrics
        let avgHeartRate = json["avgHeartRate"] as? Double
        let maxHeartRate = json["maxHeartRate"] as? Double
        
        // Route and weather data
        let routeDataUrl = json["routeDataUrl"] as? String
        let weather = json["weather"] as? String
        let temperature = json["temperature"] as? Double

        return BikeLog(
            id: id,
            duration: duration,
            distance: distance,
            avgPace: avgPace,
            paceValues: paceValues,
            createdAt: createdAt,
            createdAtFormatted: createdAtFormatted,
            createdBy: createdBy,
            caloriesBurned: caloriesBurned,
            type: type,
            bikeType: bikeType,
            coordinateArray: coordinateArray,
            locationData: locationData,
            netElevation: netElevation,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            bikeDataPoints: bikeDataPoints,
            avgSpeed: avgSpeed,
            maxSpeed: maxSpeed,
            avgCadence: avgCadence,
            avgPower: avgPower,
            cadence: cadence,
            power: power,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            routeDataUrl: routeDataUrl,
            weather: weather,
            temperature: temperature
        )
    }
}

// Legacy type aliases for backward compatibility
public typealias BikeRideLog = BikeLog
// Note: IndoorBikeLog is defined as a full struct in BikingTypes.swift
// Do not create a typealias here as it conflicts with the struct definition

// MARK: - BikeDataPoint

struct BikeDataPoint {
    var timestamp: Date
    var distance: Double
    var heartRate: Double
    var cadence: Double
    var speed: Double
    var pace: Double
    var power: Double? // Bike-specific
    var resistance: Double? // For stationary bikes

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "timestamp": timestamp.timeIntervalSince1970,
            "distance": distance,
            "heartRate": heartRate,
            "cadence": cadence,
            "speed": speed,
            "pace": pace
        ]
        if let power = power {
            dict["power"] = power
        }
        if let resistance = resistance {
            dict["resistance"] = resistance
        }
        return dict
    }

    static func fromDictionary(_ dict: [String: Any]) -> BikeDataPoint? {
        guard let timestamp = dict["timestamp"] as? TimeInterval,
              let distance = dict["distance"] as? Double,
              let heartRate = dict["heartRate"] as? Double,
              let cadence = dict["cadence"] as? Double,
              let speed = dict["speed"] as? Double,
              let pace = dict["pace"] as? Double else {
            return nil
        }
        return BikeDataPoint(
            timestamp: Date(timeIntervalSince1970: timestamp),
            distance: distance,
            heartRate: heartRate,
            cadence: cadence,
            speed: speed,
            pace: pace,
            power: dict["power"] as? Double,
            resistance: dict["resistance"] as? Double
        )
    }
}

// MARK: - HikeLog
// Note: Updated to remove PFUser dependencies - uses String for createdBy

public struct HikeLog: Hashable {
    public static func == (lhs: HikeLog, rhs: HikeLog) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        for dict in locationData ?? [] {
            for (key, value) in dict {
                hasher.combine(key)
                if let value = value as? Int {
                    hasher.combine(value)
                } else if let value = value as? String {
                    hasher.combine(value)
                }
            }
        }
    }
    
    var id: String?
    var duration: String?
    var distance: String?
    var coordinateArray: [[String: Double]]? // Updated from [PFGeoPoint] to [[String: Double]]
    var avgPace: String?
    var paceValues: [Double]?
    var createdAt: Date?
    var createdAtFormatted: String?
    var createdBy: String? // Updated from PFUser to String (Cognito user ID)
    var netElevation: String?
    var elevationGain: String?
    var elevationLoss: String?
    var caloriesBurned: Double?
    var locationData: [[String: Any]]?
    var routeDataUrl: String? // S3 URL for full route data
    
    func toJson() -> [String:Any] {
        return [
            "id": id ?? "",
            "duration": duration ?? "",
            "distance": distance ?? "",
            "createdAtFormatted": createdAtFormatted ?? "",
            "avgPace": avgPace ?? "",
            "coordinateArray": coordinateArray ?? [],
            "paceValues": paceValues ?? [],
            "createdAt": createdAt ?? Date(),
            "createdBy": createdBy ?? "",
            "calories": caloriesBurned ?? 0.0,
            "netElevation": netElevation ?? "",
            "elevationGain": elevationGain ?? "",
            "elevationLoss": elevationLoss ?? "",
            "locationData": locationData ?? [],
            "routeDataUrl": routeDataUrl ?? ""
        ]
    }
    
    static func fromJSON(json: [String: Any]) -> HikeLog? {
        let id = json["id"] as? String
        let duration = json["duration"] as? String
        let distance = json["distance"] as? String
        // Handle coordinateArray - could be [PFGeoPoint] or [[String: Double]]
        var coordinateArray: [[String: Double]]? = nil
        if let coordArray = json["coordinateArray"] as? [[String: Double]] {
            coordinateArray = coordArray
        }
        let avgPace = json["avgPace"] as? String
        let paceValues = json["paceValues"] as? [Double]
        let createdAt = json["createdAt"] as? Date
        let createdAtFormatted = json["createdAtFormatted"] as? String
        let createdBy = json["createdBy"] as? String // Updated to String
        let caloriesBurned = json["calories"] as? Double
        let netElevation = json["netElevation"] as? String
        let elevationGain = json["elevationGain"] as? String
        let elevationLoss = json["elevationLoss"] as? String
        let locationData = json["locationData"] as? [[String: Any]] ?? []
        let routeDataUrl = json["routeDataUrl"] as? String

        return HikeLog(
            id: id,
            duration: duration,
            distance: distance,
            coordinateArray: coordinateArray,
            avgPace: avgPace,
            paceValues: paceValues,
            createdAt: createdAt,
            createdAtFormatted: createdAtFormatted,
            createdBy: createdBy,
            netElevation: netElevation,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            caloriesBurned: caloriesBurned,
            locationData: locationData,
            routeDataUrl: routeDataUrl
        )
    }
    
    static func fromJSONDashboard(json: [String: Any]) -> HikeLog? {
        let id = json["objectId"] as? String
        let duration = json["Duration"] as? String
        let distance = json["Distance"] as? String
        // Handle coordinateArray
        var coordinateArray: [[String: Double]]? = nil
        if let coordArray = json["coordinateArray"] as? [[String: Double]] {
            coordinateArray = coordArray
        }
        let avgPace = json["averagePace"] as? String
        let paceValues = json["paceValues"] as? [Double]
        let createdAt = json["createdAt"] as? Date
        let createdBy = json["createdBy"] as? String // Updated to String
        let caloriesBurned = json["calories"] as? Double
        let netElevation = json["netElevation"] as? String
        let elevationGain = json["elevationGain"] as? String
        let elevationLoss = json["elevationLoss"] as? String
        let locationData = json["locationData"] as? [[String: Any]] ?? []
        let routeDataUrl = json["routeDataUrl"] as? String

        var createdAtFormatted = ""
        if let createdAt = json["createdAt"] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            if let date = formatter.date(from: createdAt) {
                createdAtFormatted = date.timeAgoSinceDateForPost()
            } else {
                print("Invalid date string")
            }
        }
        
        return HikeLog(
            id: id,
            duration: duration,
            distance: distance,
            coordinateArray: coordinateArray,
            avgPace: avgPace,
            paceValues: paceValues,
            createdAt: createdAt,
            createdAtFormatted: createdAtFormatted,
            createdBy: createdBy,
            netElevation: netElevation,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            caloriesBurned: caloriesBurned,
            locationData: locationData,
            routeDataUrl: routeDataUrl
        )
    }
}


