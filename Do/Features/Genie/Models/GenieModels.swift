//
//  GenieModels.swift
//  Do
//
//  Core models for Genie AI functionality
//

import Foundation

/// Context for Genie conversations
public enum GenieContext: Equatable {
    case general
    case workoutPlanning
    case workoutAnalysis
    case workoutExecution
    case workoutHistory
    case workoutRecommendations
    case nutritionAdvice
    case recoveryGuidance
    case formTechnique
    case environmentalContext
    case customContext(String)
    
    public var description: String {
        switch self {
        case .general:
            return "General fitness assistance"
        case .workoutPlanning:
            return "Planning a workout or training program"
        case .workoutAnalysis:
            return "Analyzing workout performance and providing insights"
        case .workoutExecution:
            return "Providing guidance during an active workout"
        case .workoutHistory:
            return "Providing insights based on workout history and trends"
        case .workoutRecommendations:
            return "Personalized workout recommendations based on your profile and history"
        case .nutritionAdvice:
            return "Providing nutrition advice and meal planning"
        case .recoveryGuidance:
            return "Providing recovery guidance and injury prevention"
        case .formTechnique:
            return "Providing form and technique guidance for exercises"
        case .environmentalContext:
            return "Environmental context and location-aware workout adaptations"
        case .customContext(let description):
            return description
        }
    }
    
    // Custom equatable implementation to handle the associated value in customContext
    public static func == (lhs: GenieContext, rhs: GenieContext) -> Bool {
        switch (lhs, rhs) {
        case (.general, .general),
             (.workoutPlanning, .workoutPlanning),
             (.workoutAnalysis, .workoutAnalysis),
             (.workoutExecution, .workoutExecution),
             (.workoutHistory, .workoutHistory),
             (.workoutRecommendations, .workoutRecommendations),
             (.nutritionAdvice, .nutritionAdvice),
             (.recoveryGuidance, .recoveryGuidance),
             (.formTechnique, .formTechnique),
             (.environmentalContext, .environmentalContext):
            return true
        case (.customContext(let lhsValue), .customContext(let rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
}

/// Types of workouts specifically for Genie's form analysis
public enum GenieWorkoutType: String, CaseIterable, Identifiable, Codable {
    case strength = "Strength Training"
    case cardio = "Cardio"
    case hiit = "HIIT"
    case yoga = "Yoga"
    case pilates = "Pilates"
    case cycling = "Cycling"
    case running = "Running"
    case swimming = "Swimming"
    case crossfit = "CrossFit"
    case calisthenics = "Calisthenics"
    case functionalTraining = "Functional Training"
    case olympicLifting = "Olympic Lifting"
    case powerlifting = "Powerlifting"
    case stretching = "Stretching"
    case walking = "Walking"
    case other = "Other"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .strength:
            return "dumbbell"
        case .cardio:
            return "heart"
        case .hiit:
            return "timer"
        case .yoga:
            return "figure.mind.and.body"
        case .pilates:
            return "figure.flexibility"
        case .cycling:
            return "bicycle"
        case .running:
            return "figure.run"
        case .swimming:
            return "figure.pool.swim"
        case .crossfit:
            return "figure.cross.training"
        case .calisthenics:
            return "figure.gymnastics"
        case .functionalTraining:
            return "figure.mixed.cardio"
        case .olympicLifting:
            return "figure.strengthtraining.traditional"
        case .powerlifting:
            return "figure.strengthtraining.functional"
        case .stretching:
            return "figure.cooldown"
        case .walking:
            return "figure.walk"
        case .other:
            return "figure.highintensity.intervaltraining"
        }
    }
}

/// Body areas for rehabilitation and injury prevention
public enum BodyArea: String, Codable, CaseIterable {
    case neck = "Neck"
    case shoulders = "Shoulders"
    case upperBack = "Upper Back"
    case lowerBack = "Lower Back"
    case elbows = "Elbows"
    case wrists = "Wrists"
    case hips = "Hips"
    case knees = "Knees"
    case ankles = "Ankles"
    case feet = "Feet"
    case core = "Core"
}

/// Coach specialties for Genie specific features
public enum GenieCoachSpecialty: String, Codable, CaseIterable {
    case strengthTraining = "Strength Training"
    case cardio = "Cardio"
    case weightLoss = "Weight Loss"
    case muscleGain = "Muscle Gain"
    case flexibility = "Flexibility"
    case endurance = "Endurance"
    case rehabilitation = "Rehabilitation"
    case nutrition = "Nutrition"
    case yoga = "Yoga"
    case powerlifting = "Powerlifting"
    case crossfit = "CrossFit"
    case bodybuilding = "Bodybuilding"
    case running = "Running"
    case swimming = "Swimming"
    case cycling = "Cycling"
    case seniors = "Senior Fitness"
    case youth = "Youth Training"
    case prenatal = "Prenatal Fitness"
    case postpartum = "Postpartum Fitness"
    case sportSpecific = "Sport-Specific Training"
}

/// Subscription tiers for Genie
public enum GenieTier {
    case free
    case basic
    case premium
    case ultimate
    
    public var monthlyFlows: Int {
        switch self {
        case .free:
            return 20
        case .basic:
            return 100
        case .premium:
            return 500
        case .ultimate:
            return 2000
        }
    }
    
    public var name: String {
        switch self {
        case .free:
            return "Free"
        case .basic:
            return "Basic"
        case .premium:
            return "Premium"
        case .ultimate:
            return "Ultimate"
        }
    }
    
    public var monthlyPrice: Decimal {
        switch self {
        case .free:
            return 0.00
        case .basic:
            return 4.99
        case .premium:
            return 9.99
        case .ultimate:
            return 19.99
        }
    }
}


