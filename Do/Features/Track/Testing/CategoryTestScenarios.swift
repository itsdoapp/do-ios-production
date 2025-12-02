//
//  CategoryTestScenarios.swift
//  Do
//
//  Test scenarios and expected results for each tracking category
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

class CategoryTestScenarios {
    static let shared = CategoryTestScenarios()
    
    private init() {}
    
    // MARK: - Expected Metrics by Category
    
    func expectedMetrics(for category: String) -> [String] {
        switch category.lowercased() {
        case "running":
            return ["distance", "elapsedTime", "pace", "calories", "heartRate", "elevationGain", "cadence", "strideLength"]
        case "gym":
            return ["elapsedTime", "totalCalories", "heartRate", "totalVolume", "totalReps", "sets"]
        case "cycling":
            return ["distance", "elapsedTime", "pace", "calories", "heartRate", "elevationGain", "cadence"]
        case "hiking":
            return ["distance", "elapsedTime", "pace", "calories", "heartRate", "elevationGain", "cadence"]
        case "walking":
            return ["distance", "elapsedTime", "pace", "calories", "heartRate", "elevationGain", "cadence", "steps"]
        case "swimming":
            return ["laps", "distanceMeters", "elapsedTime", "pacePer100mSec", "heartRate", "strokeType"]
        case "food":
            return ["calories", "protein", "carbs", "fat", "mealType", "timestamp"]
        case "meditation":
            return ["duration", "type", "guided", "notes", "rating", "heartRate"]
        case "sports":
            return ["distance", "elapsedTime", "calories", "heartRate", "elevationGain", "sportType"]
        default:
            return []
        }
    }
    
    // MARK: - Expected Coordination by Category
    
    func expectedCoordination(for category: String, scenario: String) -> [ExpectedCoordination] {
        let isIndoor = scenario.lowercased().contains("indoor") || scenario.lowercased().contains("phone only")
        let isOutdoor = scenario.lowercased().contains("outdoor") || scenario.lowercased().contains("both")
        
        switch category.lowercased() {
        case "running":
            if isOutdoor {
                return [
                    ExpectedCoordination(metric: "distance", primaryDevice: "phone", reason: "GPS-based outdoor tracking"),
                    ExpectedCoordination(metric: "pace", primaryDevice: "phone", reason: "Calculated from GPS distance"),
                    ExpectedCoordination(metric: "heartRate", primaryDevice: "watch", reason: "Watch has better HR sensors"),
                    ExpectedCoordination(metric: "cadence", primaryDevice: "watch", reason: "Watch better for step detection")
                ]
            } else {
                return [
                    ExpectedCoordination(metric: "distance", primaryDevice: "watch", reason: "Indoor tracking, no GPS"),
                    ExpectedCoordination(metric: "heartRate", primaryDevice: "watch", reason: "Watch has better HR sensors"),
                    ExpectedCoordination(metric: "cadence", primaryDevice: "watch", reason: "Watch better for step detection")
                ]
            }
        case "gym":
            return [
                ExpectedCoordination(metric: "heartRate", primaryDevice: "watch", reason: "Watch has better HR sensors"),
                ExpectedCoordination(metric: "calories", primaryDevice: "watch", reason: "Watch better for calorie estimation")
            ]
        case "cycling":
            if isOutdoor {
                return [
                    ExpectedCoordination(metric: "distance", primaryDevice: "phone", reason: "GPS-based outdoor tracking"),
                    ExpectedCoordination(metric: "pace", primaryDevice: "phone", reason: "Calculated from GPS distance"),
                    ExpectedCoordination(metric: "heartRate", primaryDevice: "watch", reason: "Watch has better HR sensors"),
                    ExpectedCoordination(metric: "cadence", primaryDevice: "watch", reason: "Watch better for cadence")
                ]
            } else {
                return [
                    ExpectedCoordination(metric: "distance", primaryDevice: "watch", reason: "Indoor tracking, no GPS"),
                    ExpectedCoordination(metric: "heartRate", primaryDevice: "watch", reason: "Watch has better HR sensors")
                ]
            }
        case "hiking":
            return [
                ExpectedCoordination(metric: "distance", primaryDevice: "phone", reason: "GPS-based tracking"),
                ExpectedCoordination(metric: "elevationGain", primaryDevice: "phone", reason: "GPS-based elevation"),
                ExpectedCoordination(metric: "heartRate", primaryDevice: "watch", reason: "Watch has better HR sensors")
            ]
        case "walking":
            if isOutdoor {
                return [
                    ExpectedCoordination(metric: "distance", primaryDevice: "phone", reason: "GPS-based outdoor tracking"),
                    ExpectedCoordination(metric: "steps", primaryDevice: "watch", reason: "Watch better for step counting"),
                    ExpectedCoordination(metric: "heartRate", primaryDevice: "watch", reason: "Watch has better HR sensors")
                ]
            } else {
                return [
                    ExpectedCoordination(metric: "distance", primaryDevice: "watch", reason: "Indoor tracking, no GPS"),
                    ExpectedCoordination(metric: "steps", primaryDevice: "watch", reason: "Watch better for step counting"),
                    ExpectedCoordination(metric: "heartRate", primaryDevice: "watch", reason: "Watch has better HR sensors")
                ]
            }
        case "swimming":
            return [
                ExpectedCoordination(metric: "distance", primaryDevice: "watch", reason: "GPS doesn't work underwater"),
                ExpectedCoordination(metric: "heartRate", primaryDevice: "watch", reason: "Watch has better HR sensors"),
                ExpectedCoordination(metric: "calories", primaryDevice: "watch", reason: "Watch better for calorie estimation")
            ]
        case "food":
            return [] // Food doesn't have device coordination, but syncs to AppGroup
        case "meditation":
            return [
                ExpectedCoordination(metric: "heartRate", primaryDevice: "watch", reason: "Watch has better HR sensors")
            ]
        case "sports":
            if isOutdoor {
                return [
                    ExpectedCoordination(metric: "distance", primaryDevice: "phone", reason: "GPS-based outdoor tracking"),
                    ExpectedCoordination(metric: "heartRate", primaryDevice: "watch", reason: "Watch has better HR sensors")
                ]
            } else {
                return [
                    ExpectedCoordination(metric: "distance", primaryDevice: "watch", reason: "Indoor tracking, no GPS"),
                    ExpectedCoordination(metric: "heartRate", primaryDevice: "watch", reason: "Watch has better HR sensors")
                ]
            }
        default:
            return []
        }
    }
    
    // MARK: - Expected Sync Frequency
    
    func expectedSyncFrequency(for category: String) -> TimeInterval {
        // All categories should sync approximately every 2 seconds
        return 2.0
    }
    
    // MARK: - Get Expected Results
    
    func getExpectedResults(for category: String, scenario: String) -> ExpectedResults {
        return ExpectedResults(
            category: category,
            requiredMetrics: expectedMetrics(for: category),
            expectedCoordination: expectedCoordination(for: category, scenario: scenario),
            syncFrequency: expectedSyncFrequency(for: category)
        )
    }
}

