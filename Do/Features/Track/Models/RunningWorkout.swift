//
//  RunningWorkout.swift
//  Do
//
//  Model for running workout state and data
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

/// Represents a running workout with its current state and metrics
struct RunningWorkout: Codable, Identifiable {
    let id: String
    var state: WorkoutState
    var distance: Double // in meters
    var elapsedTime: TimeInterval
    var pace: Double // seconds per meter
    var heartRate: Double // bpm
    var calories: Double // kcal
    var startTime: Date?
    var endTime: Date?
    var runType: RunType?
    
    init(
        id: String = UUID().uuidString,
        state: WorkoutState = .idle,
        distance: Double = 0,
        elapsedTime: TimeInterval = 0,
        pace: Double = 0,
        heartRate: Double = 0,
        calories: Double = 0,
        startTime: Date? = nil,
        endTime: Date? = nil,
        runType: RunType? = nil
    ) {
        self.id = id
        self.state = state
        self.distance = distance
        self.elapsedTime = elapsedTime
        self.pace = pace
        self.heartRate = heartRate
        self.calories = calories
        self.startTime = startTime
        self.endTime = endTime
        self.runType = runType
    }
}



