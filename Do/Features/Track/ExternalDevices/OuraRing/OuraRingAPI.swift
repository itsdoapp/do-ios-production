//
//  OuraRingAPI.swift
//  Do
//
//  Oura API integration
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

class OuraRingAPI {
    static let shared = OuraRingAPI()
    
    private let baseURL = "https://api.ouraring.com/v2"
    private var accessToken: String?
    private let userDefaults = UserDefaults.standard
    private let tokenKey = "oura_access_token"
    
    private init() {
        accessToken = userDefaults.string(forKey: tokenKey)
    }
    
    func hasCredentials() -> Bool {
        return accessToken != nil || userDefaults.string(forKey: "oura_client_id") != nil
    }
    
    func authenticate() async throws {
        // OAuth flow would be implemented here
        // For now, check if token exists
        guard let token = accessToken else {
            throw DeviceError.authenticationRequired
        }
        
        // Validate token
        try await validateToken(token)
    }
    
    private func validateToken(_ token: String) async throws {
        // Make a test API call to validate token
        var request = URLRequest(url: URL(string: "\(baseURL)/userinfo")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DeviceError.authenticationRequired
        }
    }
    
    func getCurrentMetrics() async throws -> WorkoutMetrics {
        guard let token = accessToken else {
            throw DeviceError.authenticationRequired
        }
        
        // Fetch heart rate
        let heartRate = try await fetchHeartRate(token: token)
        
        // Fetch active calories
        let calories = try await fetchActiveCalories(token: token)
        
        var metrics = WorkoutMetrics()
        metrics.heartRate = heartRate
        metrics.calories = calories
        
        return metrics
    }
    
    private func fetchHeartRate(token: String) async throws -> Double {
        var request = URLRequest(url: URL(string: "\(baseURL)/usercollection/heartrate")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let latest = dataArray.first,
              let bpm = latest["bpm"] as? Double else {
            return 0
        }
        
        return bpm
    }
    
    private func fetchActiveCalories(token: String) async throws -> Double {
        var request = URLRequest(url: URL(string: "\(baseURL)/usercollection/active_calories")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let latest = dataArray.first,
              let activeCalories = latest["active_calories"] as? Double else {
            return 0
        }
        
        return activeCalories
    }
}

