//
//  WorkoutState.swift
//  Do
//
//  Workout state enumeration (iOS app)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

enum WorkoutState: String, Codable {
    case idle = "idle"
    case starting = "starting"
    case running = "running"
    case paused = "paused"
    case stopping = "stopping"
    case stopped = "stopped"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .starting: return "Starting"
        case .running: return "Running"
        case .paused: return "Paused"
        case .stopping: return "Stopping"
        case .stopped: return "Stopped"
        case .completed: return "Completed"
        }
    }
    
    var canStart: Bool {
        return self == .idle || self == .stopped
    }
    
    var canPause: Bool {
        return self == .running
    }
    
    var canResume: Bool {
        return self == .paused
    }
    
    var canStop: Bool {
        return self == .running || self == .paused
    }
    
    var isActive: Bool {
        return self == .running || self == .paused
    }
}



