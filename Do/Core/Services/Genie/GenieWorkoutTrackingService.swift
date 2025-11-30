//
//  GenieWorkoutTrackingService.swift
//  Do
//
//  Workout tracking service for Genie-generated workouts
//

import Foundation
import CoreLocation

@MainActor
class GenieWorkoutTrackingService: ObservableObject {
    static let shared = GenieWorkoutTrackingService()
    
    @Published var activeWorkout: TrackedWorkout?
    @Published var workoutHistory: [TrackedWorkout] = []
    @Published var isTracking = false
    
    private var startTime: Date?
    private var sets: [WorkoutSet] = []
    
    private init() {
        loadHistory()
    }
    
    // MARK: - Workout Creation from Equipment
    
    func createWorkoutFromEquipment(_ equipment: Equipment, selectedWorkout: EquipmentWorkout) -> TrackedWorkout {
        let workout = TrackedWorkout(
            id: UUID().uuidString,
            name: selectedWorkout.name,
            category: determineCategory(for: selectedWorkout),
            equipment: equipment.name,
            muscleGroups: selectedWorkout.muscleGroups,
            targetSets: selectedWorkout.sets,
            targetReps: selectedWorkout.reps,
            instructions: selectedWorkout.instructions,
            difficulty: selectedWorkout.difficulty,
            startTime: nil,
            endTime: nil,
            sets: [],
            notes: nil
        )
        
        return workout
    }
    
    // MARK: - Workout Tracking
    
    func startWorkout(_ workout: TrackedWorkout) {
        activeWorkout = workout
        startTime = Date()
        sets = []
        isTracking = true
        
        var updatedWorkout = workout
        updatedWorkout.startTime = startTime
        activeWorkout = updatedWorkout
        
        print("🏋️ [Tracking] Started workout: \(workout.name)")
    }
    
    func logSet(reps: Int, weight: Double?, duration: TimeInterval?, notes: String?) {
        guard var workout = activeWorkout else { return }
        
        let set = WorkoutSet(
            setNumber: sets.count + 1,
            reps: reps,
            weight: weight,
            duration: duration,
            timestamp: Date(),
            notes: notes
        )
        
        sets.append(set)
        workout.sets = sets
        activeWorkout = workout
        
        print("🏋️ [Tracking] Logged set \(set.setNumber): \(reps) reps" + (weight != nil ? " @ \(weight!)lbs" : ""))
    }
    
    func completeWorkout(notes: String? = nil) {
        guard var workout = activeWorkout else { return }
        
        workout.endTime = Date()
        workout.sets = sets
        workout.notes = notes
        
        // Calculate total volume if applicable
        if let totalVolume = calculateTotalVolume(sets: sets) {
            workout.totalVolume = totalVolume
        }
        
        // Save to history
        saveWorkout(workout)
        
        // Save to DynamoDB
        Task {
            await saveToDynamoDB(workout)
        }
        
        // Reset active workout
        activeWorkout = nil
        startTime = nil
        sets = []
        isTracking = false
        
        print("🏋️ [Tracking] Completed workout: \(workout.name)")
    }
    
    func cancelWorkout() {
        activeWorkout = nil
        startTime = nil
        sets = []
        isTracking = false
        
        print("🏋️ [Tracking] Cancelled workout")
    }
    
    // MARK: - Category Determination
    
    private func determineCategory(for workout: EquipmentWorkout) -> WorkoutCategory {
        let name = workout.name.lowercased()
        let muscles = workout.muscleGroups.map { $0.lowercased() }
        
        // Check existing categories
        if name.contains("run") || name.contains("treadmill") {
            return .run
        }
        
        if name.contains("bike") || name.contains("cycling") {
            return .bike
        }
        
        if name.contains("swim") {
            return .swim
        }
        
        if name.contains("hike") || name.contains("walk") {
            return .hike
        }
        
        // Determine by muscle groups
        if muscles.contains("legs") || muscles.contains("quads") || muscles.contains("hamstrings") {
            return .legs
        }
        
        if muscles.contains("chest") {
            return .chest
        }
        
        if muscles.contains("back") {
            return .back
        }
        
        if muscles.contains("shoulders") {
            return .shoulders
        }
        
        if muscles.contains("arms") || muscles.contains("biceps") || muscles.contains("triceps") {
            return .arms
        }
        
        if muscles.contains("core") || muscles.contains("abs") {
            return .core
        }
        
        // Default to strength
        return .strength
    }
    
    // MARK: - History & Analytics
    
    func getWorkoutHistory(category: WorkoutCategory? = nil, limit: Int = 50) -> [TrackedWorkout] {
        var filtered = workoutHistory
        
        if let category = category {
            filtered = filtered.filter { $0.category == category }
        }
        
        return Array(filtered.prefix(limit))
    }
    
    func getWorkoutStats(category: WorkoutCategory) -> StrengthWorkoutStats {
        let categoryWorkouts = workoutHistory.filter { $0.category == category }
        
        let totalWorkouts = categoryWorkouts.count
        let totalSets = categoryWorkouts.reduce(0) { $0 + $1.sets.count }
        let totalReps = categoryWorkouts.reduce(0) { sum, workout in
            sum + workout.sets.reduce(0) { $0 + $1.reps }
        }
        
        let totalVolume = categoryWorkouts.reduce(0.0) { sum, workout in
            sum + (workout.totalVolume ?? 0)
        }
        
        let avgDuration: TimeInterval? = {
            let workoutsWithDuration = categoryWorkouts.compactMap { workout -> TimeInterval? in
                guard let start = workout.startTime, let end = workout.endTime else { return nil }
                return end.timeIntervalSince(start)
            }
            
            guard !workoutsWithDuration.isEmpty else { return nil }
            return workoutsWithDuration.reduce(0, +) / Double(workoutsWithDuration.count)
        }()
        
        return StrengthWorkoutStats(
            category: category,
            totalWorkouts: totalWorkouts,
            totalSets: totalSets,
            totalReps: totalReps,
            totalVolume: totalVolume,
            averageDuration: avgDuration,
            lastWorkout: categoryWorkouts.first?.endTime
        )
    }
    
    // MARK: - Persistence
    
    private func saveWorkout(_ workout: TrackedWorkout) {
        workoutHistory.insert(workout, at: 0)
        
        // Keep only last 200 workouts in memory
        if workoutHistory.count > 200 {
            workoutHistory = Array(workoutHistory.prefix(200))
        }
        
        saveHistory()
    }
    
    private func saveHistory() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let encoded = try? encoder.encode(workoutHistory) {
            UserDefaults.standard.set(encoded, forKey: "genieWorkoutHistory")
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: "genieWorkoutHistory") else { return }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let decoded = try? decoder.decode([TrackedWorkout].self, from: data) {
            workoutHistory = decoded
        }
    }
    
    // MARK: - DynamoDB Integration
    
    private func saveToDynamoDB(_ workout: TrackedWorkout) async {
        // Save to appropriate DynamoDB table based on category
        // This integrates with existing workout tracking system
        
        guard let userId = getCurrentUserId() else { return }
        
        let tableName = getTableName(for: workout.category)
        
        // Convert to DynamoDB format
        let item = workoutToDynamoDBItem(workout, userId: userId)
        
        // TODO: Implement actual DynamoDB save
        print("🏋️ [DynamoDB] Would save to table: \(tableName)")
        print("🏋️ [DynamoDB] Item: \(item)")
    }
    
    private func getTableName(for category: WorkoutCategory) -> String {
        switch category {
        case .run:
            return "prod-runs"
        case .bike:
            return "prod-bike-workouts"
        case .swim:
            return "prod-swim-workouts"
        case .hike:
            return "prod-hike-workouts"
        default:
            return "prod-strength-workouts"
        }
    }
    
    private func workoutToDynamoDBItem(_ workout: TrackedWorkout, userId: String) -> [String: Any] {
        var item: [String: Any] = [
            "workoutId": workout.id,
            "userId": userId,
            "name": workout.name,
            "category": workout.category.rawValue,
            "createdAt": ISO8601DateFormatter().string(from: workout.startTime ?? Date())
        ]
        
        if let equipment = workout.equipment {
            item["equipment"] = equipment
        }
        
        if let startTime = workout.startTime {
            item["startTime"] = ISO8601DateFormatter().string(from: startTime)
        }
        
        if let endTime = workout.endTime {
            item["endTime"] = ISO8601DateFormatter().string(from: endTime)
            
            if let start = workout.startTime {
                item["duration"] = endTime.timeIntervalSince(start)
            }
        }
        
        item["sets"] = workout.sets.map { set in
            var setDict: [String: Any] = [
                "setNumber": set.setNumber,
                "reps": set.reps
            ]
            if let weight = set.weight {
                setDict["weight"] = weight
            }
            if let duration = set.duration {
                setDict["duration"] = duration
            }
            return setDict
        }
        
        if let volume = workout.totalVolume {
            item["totalVolume"] = volume
        }
        
        item["muscleGroups"] = workout.muscleGroups
        
        return item
    }
    
    private func getCurrentUserId() -> String? {
        // Get from UserDefaults or Cognito
        return UserDefaults.standard.string(forKey: "cognito_user_id")
    }
    
    // MARK: - Helper Methods
    
    private func calculateTotalVolume(sets: [WorkoutSet]) -> Double? {
        let setsWithWeight = sets.compactMap { set -> Double? in
            guard let weight = set.weight else { return nil }
            return weight * Double(set.reps)
        }
        
        guard !setsWithWeight.isEmpty else { return nil }
        return setsWithWeight.reduce(0, +)
    }
}

// MARK: - Models

struct TrackedWorkout: Identifiable, Codable {
    let id: String
    let name: String
    let category: WorkoutCategory
    var equipment: String?
    let muscleGroups: [String]
    let targetSets: Int
    let targetReps: String
    let instructions: [String]
    let difficulty: String
    var startTime: Date?
    var endTime: Date?
    var sets: [WorkoutSet]
    var totalVolume: Double?
    var notes: String?
}

struct WorkoutSet: Codable {
    let setNumber: Int
    let reps: Int
    let weight: Double? // in lbs or kg
    let duration: TimeInterval? // for timed exercises
    let timestamp: Date
    var notes: String?
}

enum WorkoutCategory: String, Codable, CaseIterable {
    case run = "run"
    case bike = "bike"
    case swim = "swim"
    case hike = "hike"
    case walk = "walk"
    case strength = "strength"
    case legs = "legs"
    case chest = "chest"
    case back = "back"
    case shoulders = "shoulders"
    case arms = "arms"
    case core = "core"
    case cardio = "cardio"
    case flexibility = "flexibility"
    case sports = "sports"
    
    var icon: String {
        switch self {
        case .run: return "🏃"
        case .bike: return "🚴"
        case .swim: return "🏊"
        case .hike: return "🥾"
        case .walk: return "🚶"
        case .strength: return "💪"
        case .legs: return "🦵"
        case .chest: return "💪"
        case .back: return "🔙"
        case .shoulders: return "💪"
        case .arms: return "💪"
        case .core: return "🎯"
        case .cardio: return "❤️"
        case .flexibility: return "🧘"
        case .sports: return "⚽️"
        }
    }
    
    var displayName: String {
        switch self {
        case .run: return "Running"
        case .bike: return "Cycling"
        case .swim: return "Swimming"
        case .hike: return "Hiking"
        case .walk: return "Walking"
        case .strength: return "Strength Training"
        case .legs: return "Leg Workout"
        case .chest: return "Chest Workout"
        case .back: return "Back Workout"
        case .shoulders: return "Shoulder Workout"
        case .arms: return "Arm Workout"
        case .core: return "Core Workout"
        case .cardio: return "Cardio"
        case .flexibility: return "Flexibility"
        case .sports: return "Sports"
        }
    }
}

struct StrengthWorkoutStats {
    let category: WorkoutCategory
    let totalWorkouts: Int
    let totalSets: Int
    let totalReps: Int
    let totalVolume: Double
    let averageDuration: TimeInterval?
    let lastWorkout: Date?
}
