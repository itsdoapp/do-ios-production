import Foundation

// MARK: - Walking Type Enum
public enum WalkingType: String, CaseIterable, Identifiable {
    case outdoorWalk = "Outdoor Walk"
    case treadmillWalk = "Treadmill Walk"
    case trailWalk = "Trail Walk"
    case recoveryWalk = "Recovery Walk"
    case powerWalk = "Power Walk"
    case casualWalk = "Casual Walk"
    
    public var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .outdoorWalk: return "figure.walk"
        case .treadmillWalk: return "figure.walk.circle"
        case .trailWalk: return "mountain.2"
        case .recoveryWalk: return "heart"
        case .powerWalk: return "figure.walk.motion"
        case .casualWalk: return "figure.walk"
        }
    }
    
    var description: String {
        switch self {
        case .outdoorWalk:
            return "Standard outdoor walking on roads or paths"
        case .treadmillWalk:
            return "Indoor walking on a treadmill"
        case .trailWalk:
            return "Walking on nature trails and varied terrain"
        case .recoveryWalk:
            return "Easy pace walking for active recovery"
        case .powerWalk:
            return "Fast-paced walking for fitness"
        case .casualWalk:
            return "Leisurely walking for enjoyment"
        }
    }
    
    var motivationalMessage: String {
        switch self {
        case .outdoorWalk:
            return "Ready to explore the world on foot! 🚶‍♂️"
        case .treadmillWalk:
            return "Let's get those steps in! 💪"
        case .trailWalk:
            return "Adventure awaits in nature! 🚶‍♂️🌲"
        case .recoveryWalk:
            return "Every step helps you recover stronger! 💫"
        case .powerWalk:
            return "Time to power through! 🔥"
        case .casualWalk:
            return "Enjoy the journey! 🌟"
        }
    }
}

// MARK: - Indoor Walk Log
public struct IndoorWalkLog: Hashable, WalkingLogProtocol {
    
    public static func == (lhs: IndoorWalkLog, rhs: IndoorWalkLog) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var id: String?
    var duration: String?
    var distance: String?
    var avgPace: String?
    var createdAt: Date?
    var createdAtFormatted: String?
    var createdBy: String?
    var caloriesBurned: Double?
    var treadmillDataPoints: [TreadmillDataPoint]?
    var walkType: String?
    
    // New tracking fields
    var avgHeartRate: Double?
    var maxHeartRate: Double?
    var heartRateZones: [String: Double]?
    var avgCadence: Double?
    var avgIncline: Double?
    var maxIncline: Double?
    var avgSpeed: Double?
    var maxSpeed: Double?
    var notes: String?
    
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
            "treadmillDataPoints": treadmillDataPoints?.map { $0.toDictionary() } ?? [],
            "walkType": walkType ?? "treadmillWalk"
        ]
        
        // Add new fields only if they have values
        if let avgHeartRate = avgHeartRate {
            json["avgHeartRate"] = avgHeartRate
        }
        
        if let maxHeartRate = maxHeartRate {
            json["maxHeartRate"] = maxHeartRate
        }
        
        if let heartRateZones = heartRateZones {
            json["heartRateZones"] = heartRateZones
        }
        
        if let avgCadence = avgCadence {
            json["avgCadence"] = avgCadence
        }
        
        if let avgIncline = avgIncline {
            json["avgIncline"] = avgIncline
        }
        
        if let maxIncline = maxIncline {
            json["maxIncline"] = maxIncline
        }
        
        if let avgSpeed = avgSpeed {
            json["avgSpeed"] = avgSpeed
        }
        
        if let maxSpeed = maxSpeed {
            json["maxSpeed"] = maxSpeed
        }
        
        if let notes = notes {
            json["notes"] = notes
        }
        
        return json
    }
    
    static func fromJSON(json: [String: Any]) -> IndoorWalkLog? {
        let id = json["id"] as? String
        let duration = json["duration"] as? String
        let distance = json["distance"] as? String
        let avgPace = json["averagePace"] as? String
        let createdAt = json["createdAt"] as? Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        let formattedDate = dateFormatter.string(from: createdAt ?? Date())
        let createdAtFormatted = formattedDate
        let createdBy = json["createdBy"] as? String
        let caloriesBurned = json["caloriesBurned"] as? Double
        let treadmillDataPointsArray = json["treadmillDataPoints"] as? [[String : Any]]
        let treadmillDataPoints = treadmillDataPointsArray?.compactMap { TreadmillDataPoint.fromDictionary($0) }
        let walkType = json["walkType"] as? String
        
        // Parse new fields
        let avgHeartRate = json["avgHeartRate"] as? Double
        let maxHeartRate = json["maxHeartRate"] as? Double
        let heartRateZones = json["heartRateZones"] as? [String: Double]
        let avgCadence = json["avgCadence"] as? Double
        let avgIncline = json["avgIncline"] as? Double
        let maxIncline = json["maxIncline"] as? Double
        let avgSpeed = json["avgSpeed"] as? Double
        let maxSpeed = json["maxSpeed"] as? Double
        let notes = json["notes"] as? String

        return IndoorWalkLog(
            id: id,
            duration: duration,
            distance: distance,
            avgPace: avgPace,
            createdAt: createdAt,
            createdAtFormatted: createdAtFormatted,
            createdBy: createdBy,
            caloriesBurned: caloriesBurned,
            treadmillDataPoints: treadmillDataPoints,
            walkType: walkType,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            heartRateZones: heartRateZones,
            avgCadence: avgCadence,
            avgIncline: avgIncline,
            maxIncline: maxIncline,
            avgSpeed: avgSpeed,
            maxSpeed: maxSpeed,
            notes: notes
        )
    }
}

// MARK: - Walk Log
public struct WalkLog: Hashable, WalkingLogProtocol {
    
    public static func == (lhs: WalkLog, rhs: WalkLog) -> Bool {
        return lhs.id == rhs.id
    }
    
    var id: String?
    var duration: String?
    var distance: String?
    var coordinateArray: [[String: Any]]?
    var avgPace: String?
    var paceValues: [Double]?
    var createdAt: Date?
    var createdAtFormatted: String?
    var createdBy: String?
    var netElevation: String?
    var elevationGain: String?
    var elevationLoss: String?
    var caloriesBurned: Double?
    var locationData: [[String: Any]]?
    var walkType: String?
    
    // New tracking fields
    var avgHeartRate: Double?
    var maxHeartRate: Double?
    var heartRateZones: [String: Double]?
    var avgCadence: Double?
    var steps: Int?
    var maxSpeed: Double?
    var weather: String?
    var temperature: Double?
    var humidity: Double?
    var notes: String?
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        for dict in locationData ?? [] {
            for (key, value) in dict {
                hasher.combine(key)
                if let value = value as? Int {
                    hasher.combine(value)
                } else if let value = value as? String {
                    hasher.combine(value)
                } // Add more cases for other types if needed
            }
        }
    }
    
    func toJson() -> [String:Any] {
        var json: [String: Any] = [
            "id": id ?? "",
            "duration": duration ?? "",
            "distance": distance ?? "",
            "createdAtFormatted": createdAtFormatted ?? "",
            "avgPace": avgPace ?? "",
            "coordinateArray": coordinateArray ?? [],
            "paceValues": paceValues ?? [],
            "createdAt": createdAt ?? Date(),
            "createdBy": createdBy ?? UserIDHelper.shared.getCurrentUserID()!,
            "calories": caloriesBurned ?? 0.0,
            "netElevation": netElevation ?? 0,
            "elevationGain": elevationGain ?? "",
            "elevationLoss": elevationLoss ?? "",
            "locationData": locationData ?? [],
            "walkType": walkType ?? "outdoorWalk"
        ]
        
        // Add new fields only if they have values
        if let avgHeartRate = avgHeartRate {
            json["avgHeartRate"] = avgHeartRate
        }
        
        if let maxHeartRate = maxHeartRate {
            json["maxHeartRate"] = maxHeartRate
        }
        
        if let heartRateZones = heartRateZones {
            json["heartRateZones"] = heartRateZones
        }
        
        if let avgCadence = avgCadence {
            json["avgCadence"] = avgCadence
        }
        
        if let steps = steps {
            json["steps"] = steps
        }
        
        if let maxSpeed = maxSpeed {
            json["maxSpeed"] = maxSpeed
        }
        
        if let weather = weather {
            json["weather"] = weather
        }
        
        if let temperature = temperature {
            json["temperature"] = temperature
        }
        
        if let humidity = humidity {
            json["humidity"] = humidity
        }
        
        if let notes = notes {
            json["notes"] = notes
        }
        
        return json
    }
    
    static func fromJSON(json: [String: Any]) -> WalkLog? {
        let id = json["id"] as? String
        let duration = json["duration"] as? String
        let distance = json["distance"] as? String
        let coordinateArray = json["coordinateArray"] as? [[String: Any]]
        let avgPace = json["avgPace"] as? String
        let paceValues = json["paceValues"] as? [Double]
        let createdAt = json["createdAt"] as? Date
        let createdAtFormatted = json["createdAtFormatted"] as? String
        let createdBy = json["createdBy"] as? String
        let caloriesBurned = json["calories"] as? Double
        let netElevation = json["netElevation"] as? String
        let elevationGain = json["elevationGain"] as? String
        let elevationLoss = json["elevationLoss"] as? String
        let locationData = json["locationData"] as? [[String: Any]] ?? []
        let walkType = json["walkType"] as? String
        
        // Parse new fields
        let avgHeartRate = json["avgHeartRate"] as? Double
        let maxHeartRate = json["maxHeartRate"] as? Double
        let heartRateZones = json["heartRateZones"] as? [String: Double]
        let avgCadence = json["avgCadence"] as? Double
        let steps = json["steps"] as? Int
        let maxSpeed = json["maxSpeed"] as? Double
        let weather = json["weather"] as? String
        let temperature = json["temperature"] as? Double
        let humidity = json["humidity"] as? Double
        let notes = json["notes"] as? String

        return WalkLog(
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
            walkType: walkType,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            heartRateZones: heartRateZones,
            avgCadence: avgCadence,
            steps: steps,
            maxSpeed: maxSpeed,
            weather: weather,
            temperature: temperature,
            humidity: humidity,
            notes: notes
        )
    }
    
    static func fromJSONDashboard(json: [String: Any]) -> WalkLog? {
        let id = json["id"] as? String
        let duration = json["duration"] as? String
        let distance = json["distance"] as? String
        let coordinateArray = json["coordinateArray"] as? [[String: Any]]
        let avgPace = json["avgPace"] as? String
        let paceValues = json["paceValues"] as? [Double]
        let createdAt = json["createdAt"] as? Date
        let createdAtFormatted = json["createdAtFormatted"] as? String
        let createdBy = json["createdBy"] as? String
        let caloriesBurned = json["calories"] as? Double
        let netElevation = json["netElevation"] as? String
        let elevationGain = json["elevationGain"] as? String
        let elevationLoss = json["elevationLoss"] as? String
        let locationData = json["locationData"] as? [[String: Any]] ?? []
        let walkType = json["walkType"] as? String
        
        // Parse new fields
        let avgHeartRate = json["avgHeartRate"] as? Double
        let maxHeartRate = json["maxHeartRate"] as? Double
        let heartRateZones = json["heartRateZones"] as? [String: Double]
        let avgCadence = json["avgCadence"] as? Double
        let steps = json["steps"] as? Int
        let maxSpeed = json["maxSpeed"] as? Double
        let weather = json["weather"] as? String
        let temperature = json["temperature"] as? Double
        let humidity = json["humidity"] as? Double
        let notes = json["notes"] as? String

        return WalkLog(
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
            walkType: walkType,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            heartRateZones: heartRateZones,
            avgCadence: avgCadence,
            steps: steps,
            maxSpeed: maxSpeed,
            weather: weather,
            temperature: temperature,
            humidity: humidity,
            notes: notes
        )
    }
}

// MARK: - Walking Log Protocol
protocol WalkingLogProtocol {
    var id: String? { get }
    var duration: String? { get }
    var distance: String? { get }
    var avgPace: String? { get }
    var createdAt: Date? { get }
    var createdAtFormatted: String? { get }
    var createdBy: String? { get }
    var caloriesBurned: Double? { get }
}

 
