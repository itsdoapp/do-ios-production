import Foundation

/// Lightweight suggestion generator for Genie quick prompts.
@MainActor
class GenieSuggestionService: ObservableObject {
    static let shared = GenieSuggestionService()
    
    @Published private(set) var suggestions: [String] = []
    
    private init() {}
    
    // Comprehensive list of 15 general suggestions
    private let allGeneralSuggestions: [String] = [
        "Give me a balanced workout for today",
        "What should I focus on this week?",
        "Summarize my recent progress",
        "Create a 4-day strength training plan",
        "Design a HIIT workout with minimal equipment",
        "Plan my meals for the week",
        "Analyze my last workout and suggest improvements",
        "Recommend a recovery routine for sore muscles",
        "Help me track my nutrition goals",
        "Create a meditation session for stress relief",
        "Suggest exercises for better posture",
        "Plan a cardio session under 30 minutes",
        "What muscle groups should I train today?",
        "Give me tips for better sleep",
        "Help me set fitness goals for this month"
    ]
    
    func loadSuggestions(for context: GenieContext) {
        switch context {
        case .general:
            // Randomly select 3 suggestions from the full list
            suggestions = Array(allGeneralSuggestions.shuffled().prefix(3))
        case .workoutPlanning:
            suggestions = [
                "Plan a 4-day strength split",
                "Design a HIIT session with minimal equipment",
                "Create a recovery day mobility flow"
            ]
        case .workoutAnalysis:
            suggestions = [
                "Analyze my last workout and suggest improvements",
                "How was my pacing on yesterday's run?",
                "What trends do you see in my lifting volume?"
            ]
        case .workoutExecution:
            suggestions = [
                "Coach me through kettlebell swings",
                "Give me cues for better squat form",
                "Keep time for EMOM intervals"
            ]
        case .workoutHistory:
            suggestions = [
                "How many workouts have I logged this month?",
                "Compare my current streak to last month",
                "What muscle groups have I neglected?"
            ]
        case .workoutRecommendations:
            suggestions = [
                "Suggest a workout using dumbbells only",
                "What should I do for active recovery tomorrow?",
                "Recommend a cardio session under 30 minutes"
            ]
        case .nutritionAdvice:
            suggestions = [
                "Build a 40/30/30 macro meal plan",
                "What should I eat post-workout today?",
                "Analyze my breakfast photo"
            ]
        case .recoveryGuidance:
            suggestions = [
                "Recommend a mobility routine for tight hips",
                "How should I recover after heavy deadlifts?",
                "Give me a sleep optimization checklist"
            ]
        case .formTechnique:
            suggestions = [
                "Coach me through proper deadlift setup",
                "How can I fix my knee cave on squats?",
                "Teach me breathing for heavy lifts"
            ]
        case .environmentalContext:
            suggestions = [
                "Adapt today's workout for limited equipment",
                "Plan an outdoor session using bodyweight only",
                "Recommend workouts for a hotel gym"
            ]
        case .customContext(let description):
            suggestions = [
                "What should I know about \(description.lowercased())?",
                "Create a plan tailored for \(description.lowercased())",
                "List quick wins related to \(description.lowercased())"
            ]
        }
    }
    
    func reset() {
        suggestions.removeAll()
    }
}


