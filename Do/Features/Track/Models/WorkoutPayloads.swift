//
//  WorkoutPayloads.swift
//  Do
//
//  Payload types for workout communication between watch and phone
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

// MARK: - Workout Communication Delegate Protocol

protocol WorkoutCommunicationDelegate: AnyObject {
    func didReceiveWorkoutUpdate(_ update: WorkoutPayload)
    func didReceiveSetUpdate(_ update: SetPayload)
    func didReceiveTimerUpdate(_ update: TimerPayload)
    func didReceiveSyncRequest(_ update: SyncPayload)
    func didReceiveWorkoutsUpdate(_ updates: [WorkoutPayload])
    func didReceiveSessionName(_ sessionName: String)
    func didReceiveWorkoutRequest()
    func didReceiveHeartRateUpdate(_ heartRate: Double)
    func didReceiveTrackingStatusUpdate(isDashboardMode: Bool, isWatchTracking: Bool)
    func didReceiveActiveWorkoutUpdate(_ workout: [String: Any])
}

// MARK: - Workout Payload

struct WorkoutPayload: Codable {
    let type: String // e.g., "workoutUpdate", "workoutStart", "workoutEnd"
    let workoutId: String?
    let workoutType: String? // "run", "bike", "hike", "walk", "gym"
    let state: String? // "running", "paused", "stopped"
    let metrics: WorkoutMetrics?
    let timestamp: TimeInterval
    
    init(type: String,
         workoutId: String? = nil,
         workoutType: String? = nil,
         state: String? = nil,
         metrics: WorkoutMetrics? = nil,
         timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.type = type
        self.workoutId = workoutId
        self.workoutType = workoutType
        self.state = state
        self.metrics = metrics
        self.timestamp = timestamp
    }
}

// MARK: - Set Payload

struct SetPayload: Codable {
    let exerciseId: String
    let exerciseName: String?
    let setId: String?
    let reps: Int?
    let weight: Double?
    let duration: TimeInterval?
    let completed: Bool
    let timestamp: TimeInterval
    
    init(exerciseId: String,
         exerciseName: String? = nil,
         setId: String? = nil,
         reps: Int? = nil,
         weight: Double? = nil,
         duration: TimeInterval? = nil,
         completed: Bool = false,
         timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.setId = setId
        self.reps = reps
        self.weight = weight
        self.duration = duration
        self.completed = completed
        self.timestamp = timestamp
    }
}

// MARK: - Timer Payload

struct TimerPayload: Codable {
    let seconds: TimeInterval
    let isRunning: Bool
    let timerType: String? // "rest", "work", "set"
    let timestamp: TimeInterval
    
    init(seconds: TimeInterval,
         isRunning: Bool,
         timerType: String? = nil,
         timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.seconds = seconds
        self.isRunning = isRunning
        self.timerType = timerType
        self.timestamp = timestamp
    }
}

// MARK: - Sync Payload

struct SyncPayload: Codable {
    let timestamp: TimeInterval
    let syncType: String? // "full", "incremental", "request"
    let workoutId: String?
    let requestedMetrics: [String]? // e.g., ["distance", "heartRate", "pace"]
    
    init(timestamp: TimeInterval = Date().timeIntervalSince1970,
         syncType: String? = nil,
         workoutId: String? = nil,
         requestedMetrics: [String]? = nil) {
        self.timestamp = timestamp
        self.syncType = syncType
        self.workoutId = workoutId
        self.requestedMetrics = requestedMetrics
    }
}
