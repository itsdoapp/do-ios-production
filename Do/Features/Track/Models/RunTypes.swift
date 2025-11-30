//
//  RunTypes.swift
//  Do
//
//  Run type enumeration (iOS app)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

enum RunType: String, Codable, CaseIterable, Identifiable {
    case outdoorRun = "outdoorRun"
    case treadmillRun = "treadmillRun"
    case trailRun = "trailRun"
    case intervalTraining = "intervalTraining"
    case recoveryRun = "recoveryRun"
    case lapRun = "lapRun"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .outdoorRun: return "Outdoor Run"
        case .treadmillRun: return "Treadmill Run"
        case .trailRun: return "Trail Run"
        case .intervalTraining: return "Interval Training"
        case .recoveryRun: return "Recovery Run"
        case .lapRun: return "Lap Run"
        }
    }
    
    var icon: String {
        switch self {
        case .outdoorRun: return "figure.run"
        case .treadmillRun: return "figure.run.circle"
        case .trailRun: return "figure.hiking"
        case .intervalTraining: return "figure.run.square.stack"
        case .recoveryRun: return "figure.walk"
        case .lapRun: return "figure.run.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .outdoorRun: return "Standard outdoor running on roads or paths"
        case .treadmillRun: return "Indoor treadmill running workout"
        case .trailRun: return "Off-road running on trails and varied terrain"
        case .intervalTraining: return "High-intensity interval training with alternating speeds"
        case .recoveryRun: return "Easy-paced run for active recovery"
        case .lapRun: return "Track or lap-based running with consistent splits"
        }
    }
    
    var coachingTips: [String] {
        switch self {
        case .outdoorRun:
            return [
                "Maintain a steady pace throughout your run",
                "Focus on your breathing rhythm",
                "Keep your posture upright and relaxed",
                "Land on your midfoot for better efficiency"
            ]
        case .treadmillRun:
            return [
                "Start with a warm-up pace",
                "Use the incline feature for variety",
                "Focus on maintaining consistent pace",
                "Stay hydrated during indoor runs"
            ]
        case .trailRun:
            return [
                "Watch your footing on uneven terrain",
                "Use shorter strides on technical trails",
                "Keep your eyes ahead, not down",
                "Adjust pace for elevation changes"
            ]
        case .intervalTraining:
            return [
                "Warm up thoroughly before intervals",
                "Recover fully between intervals",
                "Focus on form during fast segments",
                "Cool down properly after training"
            ]
        case .recoveryRun:
            return [
                "Keep the pace easy and conversational",
                "Focus on recovery, not speed",
                "Listen to your body",
                "Use this time to work on form"
            ]
        case .lapRun:
            return [
                "Maintain consistent lap times",
                "Use the track markings for pacing",
                "Focus on smooth transitions",
                "Track your splits for improvement"
            ]
        }
    }
}

enum RunningWorkoutState: String, Codable {
    case notStarted = "notStarted"
    case inProgress = "inProgress"
    case paused = "paused"
    case completed = "completed"
    
    var isActive: Bool {
        return self == .inProgress || self == .paused
    }
}

