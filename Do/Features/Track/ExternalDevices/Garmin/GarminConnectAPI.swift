//
//  GarminConnectAPI.swift
//  Do
//
//  Garmin Connect API integration
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

class GarminConnectAPI {
    static let shared = GarminConnectAPI()
    
    private let baseURL = "https://connectapi.garmin.com"
    private var accessToken: String?
    private let userDefaults = UserDefaults.standard
    private let tokenKey = "garmin_access_token"
    
    private init() {
        accessToken = userDefaults.string(forKey: tokenKey)
    }
    
    func hasCredentials() -> Bool {
        return accessToken != nil || userDefaults.string(forKey: "garmin_consumer_key") != nil
    }
    
    func authenticate() async throws {
        guard let token = accessToken else {
            throw DeviceError.authenticationRequired
        }
        
        try await validateToken(token)
    }
    
    private func validateToken(_ token: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/wellness-api/rest/user/id")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DeviceError.authenticationRequired
        }
    }
    
    func getCurrentWorkoutMetrics() async throws -> WorkoutMetrics {
        guard let token = accessToken else {
            throw DeviceError.authenticationRequired
        }
        
        // Fetch current activity
        let activity = try await getCurrentActivity(token: token)
        
        var metrics = WorkoutMetrics()
        metrics.distance = activity.distance
        metrics.elapsedTime = activity.duration
        metrics.heartRate = activity.heartRate
        metrics.calories = activity.calories
        metrics.cadence = activity.cadence
        metrics.elevationGain = activity.elevationGain
        
        if metrics.distance > 0 && metrics.elapsedTime > 0 {
            metrics.pace = metrics.elapsedTime / metrics.distance
        }
        
        return metrics
    }
    
    private func getCurrentActivity(token: String) async throws -> GarminActivity {
        var request = URLRequest(url: URL(string: "\(baseURL)/activity-service/activity/current")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DeviceError.connectionFailed
        }
        
        return GarminActivity(from: json)
    }
}

struct GarminActivity {
    let distance: Double
    let duration: TimeInterval
    let heartRate: Double
    let calories: Double
    let cadence: Double?
    let elevationGain: Double?
    
    init(from json: [String: Any]) {
        distance = (json["distance"] as? Double ?? 0) * 1000 // Convert km to meters
        duration = json["duration"] as? TimeInterval ?? 0
        heartRate = json["heartRate"] as? Double ?? 0
        calories = json["calories"] as? Double ?? 0
        cadence = json["cadence"] as? Double
        elevationGain = json["elevationGain"] as? Double
    }
}

