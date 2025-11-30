import Foundation

// MARK: - Workout Session

struct workoutSession: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var sessionId: String?
    var name: String?
    var description: String?
    var difficulty: String?
    var equipmentNeeded: [String]?
    var movementsInSession: [movement]?
    var duration: Int? // in minutes
    var calories: Int?
    var notes: String?
    var createdAt: Date?
    var userId: String?
    
    init() {
        self.id = UUID().uuidString
        self.movementsInSession = []
    }
    
    enum CodingKeys: String, CodingKey {
        case id, sessionId, name, description, difficulty
        case equipmentNeeded, movementsInSession, duration
        case calories, notes, createdAt, userId
    }
    
    // Hashable conformance - hash based on id
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Equatable conformance - compare by id
    static func == (lhs: workoutSession, rhs: workoutSession) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Movement

struct movement: Codable, Identifiable {
    var id: String = UUID().uuidString
    var movement1Name: String?
    var movement2Name: String?
    var isSingle: Bool = true
    var isTimed: Bool = false
    var category: String?
    var difficulty: String?
    var description: String?
    var equipmentsNeeded: [String]?
    var tags: [String]?
    var firstSectionSets: [set]?
    var secondSectionSets: [set]?
    var weavedSets: [set]?
    var videoUrl: String?
    var thumbnailUrl: String?
    
    init() {
        self.id = UUID().uuidString
        self.isSingle = true
        self.isTimed = false
    }
    
    enum CodingKeys: String, CodingKey {
        case id, movement1Name, movement2Name, isSingle, isTimed
        case category, difficulty, description, equipmentsNeeded, tags
        case firstSectionSets, secondSectionSets, weavedSets
        case videoUrl, thumbnailUrl
    }
}

// MARK: - Set

struct set: Codable, Identifiable {
    var id: String = UUID().uuidString
    var reps: Int?
    var weight: Double?
    var duration: Int? // in seconds
    var restPeriod: Int? // in seconds
    var distance: Double? // in meters
    var tempo: String? // e.g., "3-0-1-0"
    var notes: String?
    var completed: Bool = false
    
    init() {
        self.id = UUID().uuidString
        self.completed = false
    }
    
    enum CodingKeys: String, CodingKey {
        case id, reps, weight, duration, restPeriod
        case distance, tempo, notes, completed
    }
}

// MARK: - Workout Activity (for tracking completed workouts)

struct WorkoutActivity: Codable, Identifiable {
    var id: String
    var userId: String
    var sessionId: String?
    var sessionName: String
    var startTime: Date
    var endTime: Date?
    var duration: Int // in seconds
    var calories: Int?
    var movementsCompleted: Int?
    var totalSets: Int?
    var totalReps: Int?
    var totalWeight: Double? // in kg
    var notes: String?
    var difficulty: String?
    var equipment: [String]?
    
    // Stats
    var heartRateAvg: Int?
    var heartRateMax: Int?
    var distanceCovered: Double? // in meters
    
    // Metadata
    var createdAt: Date
    var updatedAt: Date
    var source: String? // "manual", "apple_health", "genie_generated"
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        sessionName: String,
        startTime: Date = Date(),
        duration: Int = 0
    ) {
        self.id = id
        self.userId = userId
        self.sessionName = sessionName
        self.startTime = startTime
        self.duration = duration
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "activityId"
        case userId, sessionId, sessionName, startTime, endTime, duration
        case calories, movementsCompleted, totalSets, totalReps, totalWeight
        case notes, difficulty, equipment
        case heartRateAvg, heartRateMax, distanceCovered
        case createdAt, updatedAt, source
    }
}

// MARK: - Meal Plan

struct MealPlan: Codable, Identifiable {
    var id: String
    var userId: String
    var name: String
    var description: String?
    var startDate: Date
    var endDate: Date
    var meals: [PlannedMeal]
    var goals: DietaryGoals?
    var isActive: Bool
    var createdBy: String? // "user", "genie", "nutritionist"
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        startDate: Date,
        endDate: Date,
        meals: [PlannedMeal] = [],
        isActive: Bool = true
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.meals = meals
        self.isActive = isActive
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "planId"
        case userId, name, description, startDate, endDate
        case meals, goals, isActive, createdBy
    }
}

struct PlannedMeal: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: Date
    var mealType: FoodMealType
    var recipeName: String?
    var recipeId: String?
    var foods: [String]? // List of food items
    var targetCalories: Int?
    var targetMacros: Macros?
    var notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id, date, mealType, recipeName, recipeId
        case foods, targetCalories, targetMacros, notes
    }
}

struct Macros: Codable {
    var protein: Double? // grams
    var carbs: Double? // grams
    var fat: Double? // grams
    
    var totalCalories: Int? {
        guard let p = protein, let c = carbs, let f = fat else { return nil }
        return Int((p * 4) + (c * 4) + (f * 9))
    }
}

struct DietaryGoals: Codable {
    var dailyCalories: Int?
    var dailyProtein: Double?
    var dailyCarbs: Double?
    var dailyFat: Double?
    var restrictions: [String]? // e.g., "vegetarian", "gluten-free"
    var preferences: [String]? // e.g., "high-protein", "low-carb"
}

