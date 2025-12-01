//
//  DailyBricksModels.swift
//  Do
//
//  Model for the 6 daily "bricks" tracking system (for iOS Widget)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Daily Brick Types

enum DailyBrickType: String, CaseIterable, Identifiable {
    case move = "move"
    case heart = "heart"
    case strength = "strength"
    case recovery = "recovery"
    case mind = "mind"
    case fuel = "fuel"
    
    var id: String { rawValue }
    
    var name: String {
        switch self {
        case .move: return "Move"
        case .heart: return "Heart"
        case .strength: return "Strength"
        case .recovery: return "Recovery"
        case .mind: return "Mind"
        case .fuel: return "Fuel"
        }
    }
    
    var icon: String {
        switch self {
        case .move: return "figure.run"
        case .heart: return "heart.fill"
        case .strength: return "figure.strengthtraining.traditional"
        case .recovery: return "figure.yoga"
        case .mind: return "brain.head.profile"
        case .fuel: return "leaf.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .move: return Color(red: 0.969, green: 0.576, blue: 0.122) // Orange
        case .heart: return Color.red
        case .strength: return Color.purple
        case .recovery: return Color.blue
        case .mind: return Color(red: 0.608, green: 0.529, blue: 0.961) // Indigo #9B87F5
        case .fuel: return Color.green
        }
    }
    
    var description: String {
        switch self {
        case .move: return "Did you move intentionally today? Any workout counts."
        case .heart: return "Did you challenge your heart? Cardio intensity matters."
        case .strength: return "Did you challenge your muscles? Strength work builds you."
        case .recovery: return "Did you balance it out? Recovery and rest are essential."
        case .mind: return "Did you take care of your mind? Mental wellness matters."
        case .fuel: return "Did you consume something good? Nutrition fuels your body."
        }
    }
    
    var goalDescription: String {
        switch self {
        case .move: return "Goal: 20 minutes of any workout"
        case .heart: return "Goal: 30 minutes of cardio"
        case .strength: return "Goal: 1 strength session or 20 minutes"
        case .recovery: return "Goal: Rest day or recovery activity"
        case .mind: return "Goal: 10 minutes of meditation"
        case .fuel: return "Goal: 3 healthy meals or water goal"
        }
    }
    
    // Angle offset for positioning in circle (0° = top, clockwise)
    var angleOffset: Double {
        switch self {
        case .move: return -90.0 // Top
        case .heart: return -30.0 // Top-right
        case .strength: return 30.0 // Bottom-right
        case .recovery: return 90.0 // Bottom
        case .mind: return 150.0 // Bottom-left
        case .fuel: return -150.0 // Top-left
        }
    }
}

// MARK: - Daily Brick Progress

struct DailyBrickProgress: Identifiable {
    let id: String
    let type: DailyBrickType
    var progress: Double // 0.0 to 1.0 (0% to 100%)
    var currentValue: Double
    var goalValue: Double
    var unit: String
    
    var progressPercentage: Int {
        Int(progress * 100)
    }
    
    var isComplete: Bool {
        progress >= 1.0
    }
    
    init(type: DailyBrickType, progress: Double, currentValue: Double, goalValue: Double, unit: String = "") {
        self.id = type.rawValue
        self.type = type
        self.progress = min(1.0, max(0.0, progress)) // Clamp 0-1
        self.currentValue = currentValue
        self.goalValue = goalValue
        self.unit = unit
    }
}

// MARK: - Daily Bricks Summary

struct DailyBricksSummary {
    let bricks: [DailyBrickProgress]
    let overallProgress: Double // Average of all 6
    let completedCount: Int
    let date: Date
    
    init(bricks: [DailyBrickProgress], date: Date = Date()) {
        self.bricks = bricks
        self.date = date
        self.overallProgress = bricks.isEmpty ? 0.0 : bricks.map { $0.progress }.reduce(0, +) / Double(bricks.count)
        self.completedCount = bricks.filter { $0.isComplete }.count
    }
    
    func brick(for type: DailyBrickType) -> DailyBrickProgress? {
        bricks.first { $0.type == type }
    }
}

