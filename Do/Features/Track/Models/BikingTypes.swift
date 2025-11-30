import Foundation

// MARK: - Bike Type Enum
public enum BikeType: String, CaseIterable, Identifiable {
    case outdoorBike = "Outdoor Bike"
    case mountainBike = "Mountain Bike"
    case roadBike = "Road Bike"
    case trailBike = "Trail Bike"
    case casualBike = "Casual Bike"
    case indoorBike = "Indoor Bike"
    case stationaryBike = "Stationary Bike"
    case electricBike = "E-Bike"
    
    public var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .outdoorBike: return "bicycle"
        case .mountainBike: return "figure.outdoor.cycle"
        case .roadBike: return "bicycle.circle"
        case .trailBike: return "mountain.2"
        case .casualBike: return "bicycle"
        case .indoorBike: return "figure.indoor.cycle"
        case .stationaryBike: return "figure.indoor.cycle"
        case .electricBike: return "bolt.bicycle"
        }
    }
    
    var description: String {
        switch self {
        case .outdoorBike:
            return "Standard outdoor cycling on roads or paths"
        case .mountainBike:
            return "Off-road cycling on trails and varied terrain"
        case .roadBike:
            return "Fast-paced cycling on paved roads"
        case .trailBike:
            return "Trail cycling on natural paths and trails"
        case .casualBike:
            return "Casual, relaxed cycling for leisure"
        case .indoorBike:
            return "Indoor cycling workout"
        case .stationaryBike:
            return "Stationary bike training"
        case .electricBike:
            return "Electric-assisted cycling"
        }
    }
    
    var motivationalMessage: String {
        switch self {
        case .outdoorBike:
            return "Ready to ride! 🚴‍♂️"
        case .mountainBike:
            return "Adventure awaits on the trails! 🚵‍♂️🌲"
        case .roadBike:
            return "Let's hit the road! 🚴‍♂️💨"
        case .trailBike:
            return "Time to explore the trails! 🚵‍♂️🌲"
        case .casualBike:
            return "Enjoy a relaxing ride! 🚴‍♂️😊"
        case .indoorBike:
            return "Time to crush this indoor ride! 💪"
        case .stationaryBike:
            return "Let's get those miles in! 🔥"
        case .electricBike:
            return "Powered ride ahead! ⚡🚴‍♂️"
        }
    }
    
    var apiType: String {
        switch self {
        case .outdoorBike: return "outdoor_bike"
        case .mountainBike: return "mountain_bike"
        case .roadBike: return "road_bike"
        case .trailBike: return "trail_bike"
        case .casualBike: return "casual_bike"
        case .indoorBike: return "indoor"
        case .stationaryBike: return "stationary"
        case .electricBike: return "electric_bike"
        }
    }
    
    var coachingTips: [String] {
        switch self {
        case .outdoorBike:
            return [
                "Maintain a steady cadence throughout your ride",
                "Focus on smooth pedaling technique",
                "Keep your body relaxed and aerodynamic",
                "Stay hydrated and fuel regularly"
            ]
        case .mountainBike:
            return [
                "Keep your weight centered over the bike",
                "Use your body to absorb bumps and obstacles",
                "Look ahead, not down at your front wheel",
                "Brake before turns, not during"
            ]
        case .roadBike:
            return [
                "Maintain an aerodynamic position",
                "Keep a consistent cadence around 80-100 RPM",
                "Use your gears efficiently on hills",
                "Stay alert and visible to traffic"
            ]
        case .trailBike:
            return [
                "Adjust your speed for trail conditions",
                "Use your body weight to navigate obstacles",
                "Keep your eyes on the trail ahead",
                "Maintain momentum through technical sections"
            ]
        case .casualBike:
            return [
                "Enjoy the ride at a comfortable pace",
                "Focus on enjoying the scenery",
                "Take breaks when needed",
                "Stay aware of your surroundings"
            ]
        case .indoorBike:
            return [
                "Start with a proper warm-up",
                "Maintain good posture throughout",
                "Focus on consistent cadence",
                "Stay hydrated during your workout"
            ]
        case .stationaryBike:
            return [
                "Adjust resistance for your fitness level",
                "Maintain proper form and posture",
                "Use interval training for variety",
                "Track your progress over time"
            ]
        case .electricBike:
            return [
                "Use assist levels appropriately",
                "Still pedal actively for exercise",
                "Be mindful of battery usage",
                "Enjoy the extended range"
            ]
        }
    }
}

// MARK: - Indoor Bike Log
public struct IndoorBikeLog: Hashable {
    
    public static func == (lhs: IndoorBikeLog, rhs: IndoorBikeLog) -> Bool {
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
    var bikeDataPoints: [BikeDataPoint]?
    var bikeType: String?
    var avgSpeed: Double?
    var maxSpeed: Double?
    var avgCadence: Double?
    var avgPower: Double?
    var maxPower: Double?
    var avgHeartRate: Double?
    var maxHeartRate: Double?
    
    // Weather and mood data
    var weatherTemp: Double?
    var weatherConditions: String?
    var weatherIcon: String?
    var mood: String?
    
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
            "type": "indoor",
            "bikeType": bikeType ?? "indoor"
        ]
        
        // Add bike data points
        if let bikeDataPoints = bikeDataPoints {
            json["bikeDataPoints"] = bikeDataPoints.map { $0.toDictionary() }
        }
        
        // Add optional metrics
        if let avgSpeed = avgSpeed { json["avgSpeed"] = avgSpeed }
        if let maxSpeed = maxSpeed { json["maxSpeed"] = maxSpeed }
        if let avgCadence = avgCadence { json["avgCadence"] = avgCadence }
        if let avgPower = avgPower { json["avgPower"] = avgPower }
        if let maxPower = maxPower { json["maxPower"] = maxPower }
        if let avgHeartRate = avgHeartRate { json["avgHeartRate"] = avgHeartRate }
        if let maxHeartRate = maxHeartRate { json["maxHeartRate"] = maxHeartRate }
        if let weatherTemp = weatherTemp { json["weatherTemp"] = weatherTemp }
        if let weatherConditions = weatherConditions { json["weatherConditions"] = weatherConditions }
        if let weatherIcon = weatherIcon { json["weatherIcon"] = weatherIcon }
        if let mood = mood { json["mood"] = mood }
        
        return json
    }
    
    static func fromJSON(json: [String: Any]) -> IndoorBikeLog? {
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
        let bikeType = json["bikeType"] as? String
        
        // Parse bike data points
        var bikeDataPoints: [BikeDataPoint]? = nil
        if let bikeDataPointsArray = json["bikeDataPoints"] as? [[String: Any]] {
            bikeDataPoints = bikeDataPointsArray.compactMap { BikeDataPoint.fromDictionary($0) }
        }
        
        // Optional metrics
        let avgSpeed = json["avgSpeed"] as? Double
        let maxSpeed = json["maxSpeed"] as? Double
        let avgCadence = json["avgCadence"] as? Double
        let avgPower = json["avgPower"] as? Double
        let maxPower = json["maxPower"] as? Double
        let avgHeartRate = json["avgHeartRate"] as? Double
        let maxHeartRate = json["maxHeartRate"] as? Double
        
        // Weather and mood
        let weatherTemp = json["weatherTemp"] as? Double
        let weatherConditions = json["weatherConditions"] as? String
        let weatherIcon = json["weatherIcon"] as? String
        let mood = json["mood"] as? String
        
        return IndoorBikeLog(
            id: id,
            duration: duration,
            distance: distance,
            avgPace: avgPace,
            createdAt: createdAt,
            createdAtFormatted: createdAtFormatted,
            createdBy: createdBy,
            caloriesBurned: caloriesBurned,
            bikeDataPoints: bikeDataPoints,
            bikeType: bikeType,
            avgSpeed: avgSpeed,
            maxSpeed: maxSpeed,
            avgCadence: avgCadence,
            avgPower: avgPower,
            maxPower: maxPower,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            weatherTemp: weatherTemp,
            weatherConditions: weatherConditions,
            weatherIcon: weatherIcon,
            mood: mood
        )
    }
}

