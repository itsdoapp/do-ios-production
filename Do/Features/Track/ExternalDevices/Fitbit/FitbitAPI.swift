//
//  FitbitAPI.swift
//  Do
//
//  Fitbit API integration
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

class FitbitAPI {
    static let shared = FitbitAPI()
    
    private let baseURL = "https://api.fitbit.com/1"
    private var accessToken: String?
    private let userDefaults = UserDefaults.standard
    private let tokenKey = "fitbit_access_token"
    
    private init() {
        accessToken = userDefaults.string(forKey: tokenKey)
    }
    
    func hasCredentials() -> Bool {
        return accessToken != nil || userDefaults.string(forKey: "fitbit_client_id") != nil
    }
    
    func authenticate() async throws {
        guard let token = accessToken else {
            throw DeviceError.authenticationRequired
        }
        
        try await validateToken(token)
    }
    
    private func validateToken(_ token: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/user/-/profile.json")!)
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
        
        // Fetch heart rate
        let heartRate = try await fetchHeartRate(token: token)
        
        // Fetch active calories
        let calories = try await fetchActiveCalories(token: token)
        
        // Fetch distance (from activities)
        let distance = try await fetchDistance(token: token)
        
        var metrics = WorkoutMetrics()
        metrics.heartRate = heartRate
        metrics.calories = calories
        metrics.distance = distance
        
        return metrics
    }
    
    private func fetchHeartRate(token: String) async throws -> Double {
        let today = DateFormatter.fitbitDateFormatter.string(from: Date())
        var request = URLRequest(url: URL(string: "\(baseURL)/user/-/activities/heart/date/\(today)/1d.json")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let activities = json["activities-heart"] as? [[String: Any]],
              let latest = activities.first,
              let value = latest["value"] as? [String: Any],
              let restingHeartRate = value["restingHeartRate"] as? Double else {
            return 0
        }
        
        return restingHeartRate
    }
    
    private func fetchActiveCalories(token: String) async throws -> Double {
        let today = DateFormatter.fitbitDateFormatter.string(from: Date())
        var request = URLRequest(url: URL(string: "\(baseURL)/user/-/activities/calories/date/\(today)/1d.json")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let latest = json.first,
              let value = latest["value"] as? String,
              let calories = Double(value) else {
            return 0
        }
        
        return calories
    }
    
    private func fetchDistance(token: String) async throws -> Double {
        let today = DateFormatter.fitbitDateFormatter.string(from: Date())
        var request = URLRequest(url: URL(string: "\(baseURL)/user/-/activities/distance/date/\(today)/1d.json")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let latest = json.first,
              let value = latest["value"] as? String,
              let distanceKm = Double(value) else {
            return 0
        }
        
        return distanceKm * 1000 // Convert km to meters
    }
}

extension DateFormatter {
    static let fitbitDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

