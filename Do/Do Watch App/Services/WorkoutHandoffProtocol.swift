//
//  WorkoutHandoffProtocol.swift
//  Do Watch App
//
//  Handoff message types and protocol definitions
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import WatchConnectivity

// MARK: - Handoff Message Types

enum HandoffDirection: String, Codable {
    case watchToPhone = "watchToPhone"
    case phoneToWatch = "phoneToWatch"
}

enum WorkoutType: String, Codable {
    case running = "running"
    case biking = "biking"
    case hiking = "hiking"
    case walking = "walking"
    case swimming = "swimming"
    case sports = "sports"
    case gym = "gym"
    case meditation = "meditation"
}

// MARK: - HealthKit Activity Type Conversion

#if os(watchOS)
import HealthKit

extension WorkoutType {
    /// Converts WorkoutType to HKWorkoutActivityType for HealthKit integration
    func toHKWorkoutActivityType() -> HKWorkoutActivityType {
        switch self {
        case .running:
            return HKWorkoutActivityType.running
        case .biking:
            return HKWorkoutActivityType.cycling
        case .hiking:
            return HKWorkoutActivityType.hiking
        case .walking:
            return HKWorkoutActivityType.walking
        case .swimming:
            return HKWorkoutActivityType.swimming
        case .sports:
            return HKWorkoutActivityType.traditionalStrengthTraining // Default for sports
        case .gym:
            return HKWorkoutActivityType.traditionalStrengthTraining
        case .meditation:
            return HKWorkoutActivityType.mindAndBody // Meditation uses mindAndBody in HealthKit
        }
    }
}
#endif

// MARK: - Handoff Message Structure

struct WorkoutHandoffMessage: Codable {
    let type: String
    let direction: HandoffDirection
    let workoutType: WorkoutType
    let workoutId: String
    let metrics: WorkoutMetrics
    let state: WorkoutState
    let timestamp: TimeInterval
    let startDate: Date
    
    enum CodingKeys: String, CodingKey {
        case type, direction, workoutType, workoutId, metrics, state, timestamp, startDate
    }
    
    init(type: String = "workoutHandoff",
         direction: HandoffDirection,
         workoutType: WorkoutType,
         workoutId: String,
         metrics: WorkoutMetrics,
         state: WorkoutState,
         timestamp: TimeInterval = Date().timeIntervalSince1970,
         startDate: Date = Date()) {
        self.type = type
        self.direction = direction
        self.workoutType = workoutType
        self.workoutId = workoutId
        self.metrics = metrics
        self.state = state
        self.timestamp = timestamp
        self.startDate = startDate
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "type": type,
            "direction": direction.rawValue,
            "workoutType": workoutType.rawValue,
            "workoutId": workoutId,
            "metrics": metrics.toDictionary(),
            "state": state.rawValue,
            "timestamp": timestamp,
            "startDate": startDate.timeIntervalSince1970
        ]
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> WorkoutHandoffMessage? {
        guard let directionStr = dict["direction"] as? String,
              let direction = HandoffDirection(rawValue: directionStr),
              let workoutTypeStr = dict["workoutType"] as? String,
              let workoutType = WorkoutType(rawValue: workoutTypeStr),
              let workoutId = dict["workoutId"] as? String,
              let metricsDict = dict["metrics"] as? [String: Any],
              let metrics = WorkoutMetrics.fromDictionary(metricsDict),
              let stateStr = dict["state"] as? String,
              let state = WorkoutState(rawValue: stateStr) else {
            return nil
        }
        
        let timestamp = dict["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970
        let startDateInterval = dict["startDate"] as? TimeInterval ?? timestamp
        let startDate = Date(timeIntervalSince1970: startDateInterval)
        
        return WorkoutHandoffMessage(
            direction: direction,
            workoutType: workoutType,
            workoutId: workoutId,
            metrics: metrics,
            state: state,
            timestamp: timestamp,
            startDate: startDate
        )
    }
}

// MARK: - Handoff Response

struct HandoffResponse: Codable {
    let accepted: Bool
    let reason: String?
    let workoutId: String?
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["accepted": accepted]
        if let reason = reason {
            dict["reason"] = reason
        }
        if let workoutId = workoutId {
            dict["workoutId"] = workoutId
        }
        return dict
    }
}

// MARK: - Handoff Conflict Resolution

enum HandoffConflictResolution: String, Codable {
    case acceptPhone = "acceptPhone"
    case acceptWatch = "acceptWatch"
    case merge = "merge"
    case reject = "reject"
}

struct HandoffConflict: Codable {
    let phoneWorkout: WorkoutHandoffMessage
    let watchWorkout: WorkoutHandoffMessage
    let resolution: HandoffConflictResolution
    
    func toDictionary() -> [String: Any] {
        return [
            "phoneWorkout": phoneWorkout.toDictionary(),
            "watchWorkout": watchWorkout.toDictionary(),
            "resolution": resolution.rawValue
        ]
    }
}

