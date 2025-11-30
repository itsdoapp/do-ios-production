//
//  MeditationModels.swift
//  Do
//
//  Meditation-related models for Genie
//

import Foundation

/// Meditation focus types
enum MeditationFocus: String, Codable, CaseIterable {
    case stress = "stress relief"
    case sleep = "better sleep"
    case focus = "mental clarity and focus"
    case anxiety = "anxiety reduction"
    case breathing = "breath awareness"
    case bodyScan = "body scan relaxation"
    case visualization = "positive visualization"
    case gratitude = "gratitude and appreciation"
    case energy = "energizing and motivation"
    case recovery = "post-workout recovery"
    
    var icon: String {
        switch self {
        case .stress: return "🌊"
        case .sleep: return "😴"
        case .focus: return "🎯"
        case .anxiety: return "🌸"
        case .breathing: return "💨"
        case .bodyScan: return "🧘"
        case .visualization: return "✨"
        case .gratitude: return "🙏"
        case .energy: return "⚡️"
        case .recovery: return "💪"
        }
    }
}

// MARK: - Meditation Script Models

struct MeditationScript: Codable {
    let duration: Int // minutes
    let focus: MeditationFocus
    let segments: [MeditationSegment]
}

struct MeditationSegment: Codable {
    let name: String
    let content: String
}

