//
//  GymInsightsModels.swift
//  Do
//
//  Models for gym workout insights and recommendations
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

// MARK: - Workout Gap

/// Represents a gap in workout coverage (muscle groups not worked recently)
struct WorkoutGap: Identifiable {
    let id: String
    let category: String // e.g., "Chest", "Legs", "Back"
    let severity: GapSeverity
    let daysSinceLastWorkout: Int?
    let description: String
    let muscleGroups: [String]
    
    enum GapSeverity {
        case low
        case medium
        case high
        
        var displayName: String {
            switch self {
            case .low: return "Low Priority"
            case .medium: return "Medium Priority"
            case .high: return "High Priority"
            }
        }
    }
    
    init(id: String = UUID().uuidString,
         category: String,
         severity: GapSeverity,
         daysSinceLastWorkout: Int? = nil,
         description: String,
         muscleGroups: [String] = []) {
        self.id = id
        self.category = category
        self.severity = severity
        self.daysSinceLastWorkout = daysSinceLastWorkout
        self.description = description
        self.muscleGroups = muscleGroups
    }
}

// MARK: - Workout Recommendation

/// Represents a workout or exercise recommendation
struct WorkoutRecommendation: Identifiable {
    let id: String
    let title: String
    let description: String
    let category: String
    let priority: RecommendationPriority
    let targetMuscleGroups: [String]
    let estimatedDuration: TimeInterval?
    let difficulty: DifficultyLevel?
    let workoutId: String? // Reference to a specific workout template
    let sessionId: String? // Reference to a specific session template
    let exerciseIds: [String]? // References to specific exercises
    
    enum RecommendationPriority {
        case low
        case medium
        case high
        
        var displayName: String {
            switch self {
            case .low: return "Optional"
            case .medium: return "Recommended"
            case .high: return "Strongly Recommended"
            }
        }
    }
    
    enum DifficultyLevel: String {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
    }
    
    init(id: String = UUID().uuidString,
         title: String,
         description: String,
         category: String,
         priority: RecommendationPriority = .medium,
         targetMuscleGroups: [String] = [],
         estimatedDuration: TimeInterval? = nil,
         difficulty: DifficultyLevel? = nil,
         workoutId: String? = nil,
         sessionId: String? = nil,
         exerciseIds: [String]? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.priority = priority
        self.targetMuscleGroups = targetMuscleGroups
        self.estimatedDuration = estimatedDuration
        self.difficulty = difficulty
        self.workoutId = workoutId
        self.sessionId = sessionId
        self.exerciseIds = exerciseIds
    }
}

// MARK: - Participant Status

/// Status of a participant in a group workout or challenge
enum ParticipantStatus: String, Codable {
    case invited = "invited"
    case accepted = "accepted"
    case declined = "declined"
    case active = "active"
    case completed = "completed"
    case dropped = "dropped"
    
    var displayName: String {
        switch self {
        case .invited: return "Invited"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        case .active: return "Active"
        case .completed: return "Completed"
        case .dropped: return "Dropped Out"
        }
    }
    
    var icon: String {
        switch self {
        case .invited: return "envelope.fill"
        case .accepted: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        case .active: return "figure.run"
        case .completed: return "trophy.fill"
        case .dropped: return "person.fill.xmark"
        }
    }
}

// MARK: - Workout Participant

/// Represents a participant in a group workout
struct WorkoutParticipant: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let profileImageUrl: String?
    var status: ParticipantStatus
    let joinedAt: Date
    var lastActiveAt: Date?
    var completedWorkouts: Int
    var totalVolume: Double? // Total weight lifted
    
    init(id: String = UUID().uuidString,
         userId: String,
         username: String,
         profileImageUrl: String? = nil,
         status: ParticipantStatus = .invited,
         joinedAt: Date = Date(),
         lastActiveAt: Date? = nil,
         completedWorkouts: Int = 0,
         totalVolume: Double? = nil) {
        self.id = id
        self.userId = userId
        self.username = username
        self.profileImageUrl = profileImageUrl
        self.status = status
        self.joinedAt = joinedAt
        self.lastActiveAt = lastActiveAt
        self.completedWorkouts = completedWorkouts
        self.totalVolume = totalVolume
    }
}

// MARK: - Category Stats

/// Statistics for a workout category (e.g., Chest, Legs, Back)
struct CategoryStats: Codable {
    let category: String
    let workoutCount: Int
    let totalVolume: Double?
    let totalSets: Int?
    let totalReps: Int?
    let averageVolume: Double?
    let lastWorkoutDate: Date?
    let trend: Trend?
    
    enum Trend: String, Codable {
        case improving = "improving"
        case stable = "stable"
        case declining = "declining"
    }
    
    init(category: String,
         workoutCount: Int,
         totalVolume: Double? = nil,
         totalSets: Int? = nil,
         totalReps: Int? = nil,
         averageVolume: Double? = nil,
         lastWorkoutDate: Date? = nil,
         trend: Trend? = nil) {
        self.category = category
        self.workoutCount = workoutCount
        self.totalVolume = totalVolume
        self.totalSets = totalSets
        self.totalReps = totalReps
        self.averageVolume = averageVolume
        self.lastWorkoutDate = lastWorkoutDate
        self.trend = trend
    }
}

// MARK: - Workout Insights Generator

/// Generates workout insights based on workout history
class WorkoutInsightsGenerator {
    
    /// Analyze workout history and generate gaps
    static func analyzeGaps(workoutHistory: [String: Date]) -> [WorkoutGap] {
        var gaps: [WorkoutGap] = []
        let now = Date()
        let calendar = Calendar.current
        
        // Define major muscle group categories
        let categories = [
            "Chest": ["Chest", "Pectorals"],
            "Back": ["Back", "Lats", "Traps"],
            "Legs": ["Legs", "Quads", "Hamstrings", "Calves"],
            "Shoulders": ["Shoulders", "Delts"],
            "Arms": ["Biceps", "Triceps", "Forearms"],
            "Core": ["Abs", "Core", "Obliques"]
        ]
        
        for (category, muscleGroups) in categories {
            if let lastWorkout = workoutHistory[category] {
                let daysSince = calendar.dateComponents([.day], from: lastWorkout, to: now).day ?? 0
                
                if daysSince >= 7 {
                    let severity: WorkoutGap.GapSeverity = daysSince >= 14 ? .high : (daysSince >= 10 ? .medium : .low)
                    gaps.append(WorkoutGap(
                        category: category,
                        severity: severity,
                        daysSinceLastWorkout: daysSince,
                        description: "It's been \(daysSince) days since your last \(category.lowercased()) workout",
                        muscleGroups: muscleGroups
                    ))
                }
            } else {
                // Never worked
                gaps.append(WorkoutGap(
                    category: category,
                    severity: .high,
                    daysSinceLastWorkout: nil,
                    description: "You haven't tracked any \(category.lowercased()) workouts yet",
                    muscleGroups: muscleGroups
                ))
            }
        }
        
        return gaps.sorted { $0.severity.hashValue > $1.severity.hashValue }
    }
    
    /// Generate workout recommendations based on gaps
    static func generateRecommendations(from gaps: [WorkoutGap]) -> [WorkoutRecommendation] {
        var recommendations: [WorkoutRecommendation] = []
        
        for gap in gaps.prefix(3) { // Top 3 gaps
            let priority: WorkoutRecommendation.RecommendationPriority = {
                switch gap.severity {
                case .high: return .high
                case .medium: return .medium
                case .low: return .low
                }
            }()
            
            recommendations.append(WorkoutRecommendation(
                title: "\(gap.category) Workout",
                description: "Focus on your \(gap.category.lowercased()) with targeted exercises",
                category: gap.category,
                priority: priority,
                targetMuscleGroups: gap.muscleGroups,
                estimatedDuration: 45 * 60, // 45 minutes
                difficulty: .intermediate
            ))
        }
        
        return recommendations
    }
}

