//
//  WorkoutInterval.swift
//  Do Watch App
//
//  Custom workout intervals model (watchOS 9.0+)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Interval Type

enum IntervalType {
    case work
    case rest
    case recovery
}

// MARK: - Interval Target

struct IntervalTarget {
    var pace: Double? // Target pace in seconds per km/mile
    var heartRateZone: HeartRateZone? // Target heart rate zone
    var heartRate: Double? // Target heart rate in bpm
    var power: Double? // Target power in watts (for running)
    var duration: TimeInterval? // Target duration for this interval
    
    var hasTarget: Bool {
        pace != nil || heartRateZone != nil || heartRate != nil || power != nil
    }
}

// MARK: - Workout Interval

struct WorkoutInterval: Identifiable {
    let id: String
    var type: IntervalType
    var target: IntervalTarget
    var actualDuration: TimeInterval
    var completed: Bool
    
    var name: String {
        switch type {
        case .work: return "Work"
        case .rest: return "Rest"
        case .recovery: return "Recovery"
        }
    }
    
    init(
        id: String = UUID().uuidString,
        type: IntervalType,
        target: IntervalTarget = IntervalTarget(),
        actualDuration: TimeInterval = 0,
        completed: Bool = false
    ) {
        self.id = id
        self.type = type
        self.target = target
        self.actualDuration = actualDuration
        self.completed = completed
    }
}

// MARK: - Custom Workout Plan

struct CustomWorkoutPlan: Identifiable {
    let id: String
    var name: String
    var intervals: [WorkoutInterval]
    var totalDuration: TimeInterval
    var warmupDuration: TimeInterval
    var cooldownDuration: TimeInterval
    
    var totalIntervals: Int {
        intervals.count
    }
    
    var completedIntervals: Int {
        intervals.filter { $0.completed }.count
    }
    
    var progress: Double {
        guard totalIntervals > 0 else { return 0.0 }
        return Double(completedIntervals) / Double(totalIntervals)
    }
    
    init(
        id: String = UUID().uuidString,
        name: String,
        intervals: [WorkoutInterval] = [],
        totalDuration: TimeInterval = 0,
        warmupDuration: TimeInterval = 300, // 5 minutes default
        cooldownDuration: TimeInterval = 300 // 5 minutes default
    ) {
        self.id = id
        self.name = name
        self.intervals = intervals
        self.totalDuration = totalDuration
        self.warmupDuration = warmupDuration
        self.cooldownDuration = cooldownDuration
    }
}

