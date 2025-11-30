//
//  WatchWorkoutSession.swift
//  Do Watch App
//
//  Represents active workout session
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

struct WatchWorkoutSession: Codable, Identifiable {
    let id: String
    let workoutType: WorkoutType
    var state: WorkoutState
    var metrics: WorkoutMetrics
    let startDate: Date
    var lastUpdateDate: Date
    var deviceSource: MetricsSource
    
    init(id: String = UUID().uuidString,
         workoutType: WorkoutType,
         state: WorkoutState = .idle,
         metrics: WorkoutMetrics = WorkoutMetrics(),
         startDate: Date = Date(),
         lastUpdateDate: Date = Date(),
         deviceSource: MetricsSource = .watch) {
        self.id = id
        self.workoutType = workoutType
        self.state = state
        self.metrics = metrics
        self.startDate = startDate
        self.lastUpdateDate = lastUpdateDate
        self.deviceSource = deviceSource
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "workoutType": workoutType.rawValue,
            "state": state.rawValue,
            "metrics": metrics.toDictionary(),
            "startDate": startDate.timeIntervalSince1970,
            "lastUpdateDate": lastUpdateDate.timeIntervalSince1970,
            "deviceSource": deviceSource.rawValue
        ]
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> WatchWorkoutSession? {
        guard let id = dict["id"] as? String,
              let workoutTypeStr = dict["workoutType"] as? String,
              let workoutType = WorkoutType(rawValue: workoutTypeStr),
              let stateStr = dict["state"] as? String,
              let state = WorkoutState(rawValue: stateStr),
              let metricsDict = dict["metrics"] as? [String: Any],
              let metrics = WorkoutMetrics.fromDictionary(metricsDict) else {
            return nil
        }
        
        let startDateInterval = dict["startDate"] as? TimeInterval ?? Date().timeIntervalSince1970
        let lastUpdateInterval = dict["lastUpdateDate"] as? TimeInterval ?? Date().timeIntervalSince1970
        let deviceSourceStr = dict["deviceSource"] as? String ?? MetricsSource.watch.rawValue
        
        return WatchWorkoutSession(
            id: id,
            workoutType: workoutType,
            state: state,
            metrics: metrics,
            startDate: Date(timeIntervalSince1970: startDateInterval),
            lastUpdateDate: Date(timeIntervalSince1970: lastUpdateInterval),
            deviceSource: MetricsSource(rawValue: deviceSourceStr) ?? .watch
        )
    }
    
    var duration: TimeInterval {
        return lastUpdateDate.timeIntervalSince(startDate)
    }
    
    var isActive: Bool {
        return state.isActive
    }
}

