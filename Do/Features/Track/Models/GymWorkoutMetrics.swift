//
//  GymWorkoutMetrics.swift
//  Do
//
//  Gym-specific workout metrics (iOS app)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

struct GymWorkoutMetrics: Codable {
    var elapsedTime: TimeInterval
    var totalCalories: Double
    var totalVolume: Double // Total weight lifted (weight * reps for all sets)
    var totalReps: Int
    var totalSets: Int
    var heartRate: Double
    var heartRateAvg: Double?
    var heartRateMax: Double?
    var movementsCompleted: Int
    var currentMovement: String?
    var currentSet: Int
    
    init(elapsedTime: TimeInterval = 0,
         totalCalories: Double = 0,
         totalVolume: Double = 0,
         totalReps: Int = 0,
         totalSets: Int = 0,
         heartRate: Double = 0,
         heartRateAvg: Double? = nil,
         heartRateMax: Double? = nil,
         movementsCompleted: Int = 0,
         currentMovement: String? = nil,
         currentSet: Int = 0) {
        self.elapsedTime = elapsedTime
        self.totalCalories = totalCalories
        self.totalVolume = totalVolume
        self.totalReps = totalReps
        self.totalSets = totalSets
        self.heartRate = heartRate
        self.heartRateAvg = heartRateAvg
        self.heartRateMax = heartRateMax
        self.movementsCompleted = movementsCompleted
        self.currentMovement = currentMovement
        self.currentSet = currentSet
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "elapsedTime": elapsedTime,
            "totalCalories": totalCalories,
            "totalVolume": totalVolume,
            "totalReps": totalReps,
            "totalSets": totalSets,
            "heartRate": heartRate,
            "movementsCompleted": movementsCompleted,
            "currentSet": currentSet
        ]
        
        if let heartRateAvg = heartRateAvg {
            dict["heartRateAvg"] = heartRateAvg
        }
        if let heartRateMax = heartRateMax {
            dict["heartRateMax"] = heartRateMax
        }
        if let currentMovement = currentMovement {
            dict["currentMovement"] = currentMovement
        }
        
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> GymWorkoutMetrics? {
        guard let elapsedTime = dict["elapsedTime"] as? TimeInterval,
              let totalCalories = dict["totalCalories"] as? Double,
              let totalVolume = dict["totalVolume"] as? Double,
              let totalReps = dict["totalReps"] as? Int,
              let totalSets = dict["totalSets"] as? Int,
              let heartRate = dict["heartRate"] as? Double,
              let movementsCompleted = dict["movementsCompleted"] as? Int,
              let currentSet = dict["currentSet"] as? Int else {
            return nil
        }
        
        return GymWorkoutMetrics(
            elapsedTime: elapsedTime,
            totalCalories: totalCalories,
            totalVolume: totalVolume,
            totalReps: totalReps,
            totalSets: totalSets,
            heartRate: heartRate,
            heartRateAvg: dict["heartRateAvg"] as? Double,
            heartRateMax: dict["heartRateMax"] as? Double,
            movementsCompleted: movementsCompleted,
            currentMovement: dict["currentMovement"] as? String,
            currentSet: currentSet
        )
    }
    
    // MARK: - Formatting Helpers
    
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
    
    func formattedVolume(useMetric: Bool = false) -> String {
        if useMetric {
            // Convert lbs to kg
            let kg = totalVolume * 0.453592
            if kg >= 1000 {
                return String(format: "%.1f t", kg / 1000.0)
            } else {
                return String(format: "%.1f kg", kg)
            }
        } else {
            if totalVolume >= 2000 {
                return String(format: "%.1f t", totalVolume / 2000.0)
            } else {
                return String(format: "%.0f lbs", totalVolume)
            }
        }
    }
    
    func formattedCalories() -> String {
        return String(format: "%.0f kcal", totalCalories)
    }
}



