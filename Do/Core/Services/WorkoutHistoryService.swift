//
//  WorkoutHistoryService.swift
//  Do
//
//  Service for saving workout history to AWS
//  Created for Track Infrastructure integration
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

/// Service for saving workout history (swimming, etc.) to AWS
class WorkoutHistoryService {
    
    // MARK: - Models
    
    /// Record of a swimming workout for analysis and display
    struct SwimmingWorkoutRecord {
        let date: Date
        let durationSec: TimeInterval
        let avgPacePer100Sec: Double
        let distanceMeters: Double
        let stroke: String
        let laps: Int
        let poolLengthMeters: Double
        let avgHeartRate: Double?
        
        init(
            date: Date,
            durationSec: TimeInterval,
            avgPacePer100Sec: Double,
            distanceMeters: Double,
            stroke: String,
            laps: Int,
            poolLengthMeters: Double,
            avgHeartRate: Double? = nil
        ) {
            self.date = date
            self.durationSec = durationSec
            self.avgPacePer100Sec = avgPacePer100Sec
            self.distanceMeters = distanceMeters
            self.stroke = stroke
            self.laps = laps
            self.poolLengthMeters = poolLengthMeters
            self.avgHeartRate = avgHeartRate
        }
    }
    
    // MARK: - Methods
    
    /// Save a swimming workout to AWS
    /// - Parameters:
    ///   - laps: Number of laps completed
    ///   - distanceMeters: Total distance in meters
    ///   - poolLengthMeters: Length of pool in meters
    ///   - durationSec: Duration in seconds
    ///   - avgPacePer100Sec: Average pace per 100m in seconds
    ///   - stroke: Stroke type (e.g., "freestyle")
    ///   - avgHeartRate: Average heart rate (optional)
    /// - Returns: Activity ID if successful
    /// - Throws: Error if save fails
    func saveSwimmingWorkout(
        laps: Int,
        distanceMeters: Double,
        poolLengthMeters: Double,
        durationSec: TimeInterval,
        avgPacePer100Sec: Double,
        stroke: String,
        avgHeartRate: Double? = nil
    ) async throws -> String {
        // Get current user ID
        guard let userId = UserIDHelper.shared.getCurrentUserID() else {
            throw WorkoutHistoryError.noUserID
        }
        
        // Use ActivityService to save swimming workout
        // Swimming workouts can be saved as activities with specific metadata
        return try await withCheckedThrowingContinuation { continuation in
            // Create activity data for swimming
            let activityData: [String: Any] = [
                "laps": laps,
                "distanceMeters": distanceMeters,
                "poolLengthMeters": poolLengthMeters,
                "avgPacePer100Sec": avgPacePer100Sec,
                "stroke": stroke,
                "avgHeartRate": avgHeartRate as Any,
                "activityType": "swimming"
            ]
            
            // Calculate distance in km for ActivityService
            let distanceKm = distanceMeters / 1000.0
            
            // Save using ActivityService (if it has a generic save method)
            // For now, we'll use a direct Lambda call similar to other activities
            let saveURL = "https://jhnf24qivfn74xv6korlm27nry0ebqlj.lambda-url.us-east-1.on.aws/"
            
            guard let url = URL(string: saveURL) else {
                continuation.resume(throwing: WorkoutHistoryError.invalidURL)
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Add Cognito token if available
            // Note: You may need to add authentication headers here
            
            let payload: [String: Any] = [
                "userId": userId,
                "activityType": "swimming",
                "duration": Int(durationSec),
                "distance": distanceKm,
                "calories": calculateSwimmingCalories(distanceMeters: distanceMeters, durationSec: durationSec),
                "activityData": activityData,
                "createdAt": ISO8601DateFormatter().string(from: Date())
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            } catch {
                continuation.resume(throwing: error)
                return
            }
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    continuation.resume(throwing: WorkoutHistoryError.httpError)
                    return
                }
                
                // Parse response to get activity ID
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let activityId = json["activityId"] as? String {
                    continuation.resume(returning: activityId)
                } else {
                    continuation.resume(returning: UUID().uuidString) // Fallback ID
                }
            }
            
            task.resume()
        }
    }
    
    /// Calculate estimated calories burned for swimming
    private func calculateSwimmingCalories(distanceMeters: Double, durationSec: TimeInterval) -> Double {
        // Rough estimate: ~10 calories per 100m for average swimmer
        let caloriesPer100m = 10.0
        return (distanceMeters / 100.0) * caloriesPer100m
    }
}

// MARK: - Errors

enum WorkoutHistoryError: Error {
    case noUserID
    case invalidURL
    case httpError
    case invalidResponse
    
    var localizedDescription: String {
        switch self {
        case .noUserID:
            return "No user ID available"
        case .invalidURL:
            return "Invalid URL"
        case .httpError:
            return "HTTP error occurred"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}

