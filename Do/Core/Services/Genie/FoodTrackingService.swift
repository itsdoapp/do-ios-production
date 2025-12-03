//
//  FoodTrackingService.swift
//  Do
//
//  Enterprise-grade food tracking with database integration
//

import Foundation

@MainActor
class FoodTrackingService: ObservableObject {
    static let shared = FoodTrackingService()
    
    @Published var todaysFoods: [FoodEntry] = []
    @Published var nutritionSummary: DailyNutritionSummary?
    @Published var weeklyStats: FoodWeeklyStats?
    @Published var isLoading = false
    @Published var favoriteFoods: [FavoriteFood] = []
    
    private init() {
        loadTodaysFoods()
        loadFavorites()
    }
    
    // MARK: - Manual Food Logging
    
    func logFood(
        name: String,
        mealType: FoodMealType,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        servingSize: String? = nil,
        notes: String? = nil,
        source: FoodSource = .manual, // Source of the food entry (manual, ai, barcode)
        recipeId: String? = nil, // RELATIONSHIP: Reference to recipe if this came from a recipe
        mealPlanId: String? = nil, // RELATIONSHIP: Reference to meal plan if this came from a meal plan
        mealPlanMealId: String? = nil // RELATIONSHIP: Reference to specific meal in meal plan
    ) async throws {
        let entry = FoodEntry(
            id: UUID().uuidString,
            userId: getCurrentUserId(),
            name: name,
            mealType: mealType,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            servingSize: servingSize,
            notes: notes,
            timestamp: Date(),
            source: source
        )
        
        // Save locally
        todaysFoods.append(entry)
        saveToLocalStorage(entry)
        
        // Save to DynamoDB with relationship fields
        try await saveToDynamoDB(
            entry,
            recipeId: recipeId,
            mealPlanId: mealPlanId,
            mealPlanMealId: mealPlanMealId
        )
        
        // Update summary
        await updateNutritionSummary()
        
        // Update user learning
        await GenieUserLearningService.shared.updateUserLearning(
            activity: "food",
            data: entry.toDictionary()
        )
        
        print("✅ [Food] Logged: \(name) - \(calories) cal")
    }
    
    // MARK: - AI Food Logging
    
    func logFoodFromAI(analysis: String, mealType: FoodMealType, imageData: Data?) async throws {
        // Parse AI analysis
        let nutrition = parseAIAnalysis(analysis)
        
        let entry = FoodEntry(
            id: UUID().uuidString,
            userId: getCurrentUserId(),
            name: nutrition.name,
            mealType: mealType,
            calories: nutrition.calories,
            protein: nutrition.protein,
            carbs: nutrition.carbs,
            fat: nutrition.fat,
            servingSize: nutrition.servingSize,
            notes: analysis,
            timestamp: Date(),
            source: .ai,
            imageData: imageData
        )
        
        // Save locally
        todaysFoods.append(entry)
        saveToLocalStorage(entry)
        
        // Save to DynamoDB
        try await saveToDynamoDB(entry)
        
        // Update summary
        await updateNutritionSummary()
        
        // Update user learning
        await GenieUserLearningService.shared.updateUserLearning(
            activity: "food",
            data: entry.toDictionary()
        )
        
        print("✅ [Food AI] Logged: \(nutrition.name) - \(nutrition.calories) cal")
    }
    
    // MARK: - Delete Food Entry
    
    func deleteFoodEntry(id: String) async throws {
        // Remove from local storage
        var entries = loadAllFromLocalStorage()
        entries.removeAll { $0.id == id }
        
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: "foodEntries")
        }
        
        // Update today's foods
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        todaysFoods = entries.filter { calendar.isDate($0.timestamp, inSameDayAs: Date()) }
        
        // Delete from backend
        try await GenieAPIService.shared.deleteFoodEntry(id: id)
        
        // Update summary
        await updateNutritionSummary()
        
        print("✅ [Food] Deleted entry: \(id)")
    }
    
    // MARK: - History & Analytics
    
    func getFoodHistory(days: Int = 30) async throws -> [FoodEntry] {
        // Fetch from DynamoDB
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return try await fetchFromDynamoDB(startDate: startDate)
    }
    
    func getNutritionTrends(days: Int = 7) async throws -> FoodNutritionTrends {
        let history = try await getFoodHistory(days: days)
        return calculateTrends(from: history)
    }
    
    func getMealPatterns() async throws -> FoodMealPatterns {
        let history = try await getFoodHistory(days: 30)
        return analyzeMealPatterns(from: history)
    }
    
    // MARK: - Database Operations
    
    private func saveToDynamoDB(
        _ entry: FoodEntry,
        recipeId: String? = nil,
        mealPlanId: String? = nil,
        mealPlanMealId: String? = nil
    ) async throws {
        // Save to prod-food table via API
        let data = entry.toDictionary()
        await GenieUserLearningService.shared.updateUserLearning(
            activity: "food_detailed",
            data: data
        )
        
        // Save to backend with relationship fields
        try await GenieAPIService.shared.saveFoodLog(
            entry,
            recipeId: recipeId,
            mealPlanId: mealPlanId,
            mealPlanMealId: mealPlanMealId
        )
        print("✅ [Food] Saved to DynamoDB via API")
    }
    
    private func fetchFromDynamoDB(startDate: Date) async throws -> [FoodEntry] {
        // Updated to use prod-nutrition table with entryType filter
        // Calculate days from start date
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 30
        
        // Fetch from backend API
        do {
            let items = try await GenieAPIService.shared.getFoodHistory(days: days, limit: 200)
            
            // Convert backend items to FoodEntry
            // Updated to handle prod-nutrition table structure with entryType field
            let entries = items.compactMap { item -> FoodEntry? in
                // Check entryType - only process food entries
                if let entryType = item["entryType"] as? String, entryType != "food" {
                    return nil // Skip non-food entries (water, drinks, restaurants, etc.)
                }
                
                // Support both old format (mealId) and new format (nutritionId)
                let id = item["nutritionId"] as? String ?? item["mealId"] as? String
                guard let mealId = id,
                      let name = item["name"] as? String,
                      let mealTypeStr = item["mealType"] as? String,
                      let mealType = FoodMealType(rawValue: mealTypeStr.capitalized),
                      let calories = item["calories"] as? Double else {
                    return nil
                }
                
                // Parse timestamp - support both consumedAt and createdAt
                let timestampStr = item["consumedAt"] as? String ?? item["createdAt"] as? String
                guard let timestampStr = timestampStr,
                      let createdAt = ISO8601DateFormatter().date(from: timestampStr) else {
                    return nil
                }
                
                // Parse optional fields
                let protein = item["protein"] as? Double ?? 0
                let carbs = item["carbs"] as? Double ?? 0
                let fat = item["fat"] as? Double ?? 0
                let servingSize = item["servingSize"] as? String
                let notes = item["notes"] as? String
                let sourceStr = item["source"] as? String ?? "manual"
                let source = FoodSource(rawValue: sourceStr) ?? .manual
                
                return FoodEntry(
                    id: mealId,
                    userId: getCurrentUserId(),
                    name: name,
                    mealType: mealType,
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    servingSize: servingSize,
                    notes: notes,
                    timestamp: createdAt,
                    source: source,
                    imageData: nil
                )
            }
            
            // Filter by start date (backend may return slightly more)
            let filteredEntries = entries.filter { $0.timestamp >= startDate }
            
            // Merge with local storage and update cache
            await syncWithLocalStorage(entries: filteredEntries)
            
            print("✅ [Food] Fetched \(filteredEntries.count) entries from backend")
            return filteredEntries
            
        } catch {
            print("⚠️ [Food] Error fetching from backend: \(error), falling back to local storage")
            // Fallback to local storage on error
            return loadFromLocalStorage(startDate: startDate)
        }
    }
    
    private func syncWithLocalStorage(entries: [FoodEntry]) async {
        // Merge backend entries with local storage
        var localEntries = loadAllFromLocalStorage()
        
        // Create a set of entry IDs from backend
        let backendIds = Set(entries.map { $0.id })
        
        // Remove local entries that are now in backend (to avoid duplicates)
        localEntries = localEntries.filter { !backendIds.contains($0.id) }
        
        // Combine: backend entries first (more authoritative), then local-only entries
        let combined = entries + localEntries
        
        // Save updated list
        if let encoded = try? JSONEncoder().encode(combined) {
            UserDefaults.standard.set(encoded, forKey: "foodEntries")
        }
        
        // Update today's foods
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        todaysFoods = combined.filter { calendar.isDate($0.timestamp, inSameDayAs: Date()) }
    }
    
    // MARK: - Local Storage
    
    private func saveToLocalStorage(_ entry: FoodEntry) {
        var entries = loadAllFromLocalStorage()
        entries.insert(entry, at: 0)
        
        // Keep last 500 entries
        if entries.count > 500 {
            entries = Array(entries.prefix(500))
        }
        
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: "foodEntries")
        }
    }
    
    private func loadAllFromLocalStorage() -> [FoodEntry] {
        guard let data = UserDefaults.standard.data(forKey: "foodEntries"),
              let entries = try? JSONDecoder().decode([FoodEntry].self, from: data) else {
            return []
        }
        return entries
    }
    
    private func loadFromLocalStorage(startDate: Date) -> [FoodEntry] {
        let all = loadAllFromLocalStorage()
        return all.filter { $0.timestamp >= startDate }
    }
    
    private func loadTodaysFoods() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Load from local storage first for immediate UI update
        todaysFoods = loadFromLocalStorage(startDate: today)
        
        // Then refresh from backend in background
        Task {
            do {
                _ = try await fetchFromDynamoDB(startDate: today)
                // fetchFromDynamoDB already updates todaysFoods via syncWithLocalStorage
            } catch {
                print("⚠️ [Food] Failed to refresh from backend: \(error)")
            }
        }
    }
    
    // MARK: - Analytics
    
    func updateNutritionSummary() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todaysEntries = todaysFoods.filter { calendar.isDate($0.timestamp, inSameDayAs: Date()) }
        
        let totalCalories = todaysEntries.reduce(0) { $0 + $1.calories }
        let totalProtein = todaysEntries.reduce(0) { $0 + $1.protein }
        let totalCarbs = todaysEntries.reduce(0) { $0 + $1.carbs }
        let totalFat = todaysEntries.reduce(0) { $0 + $1.fat }
        
        nutritionSummary = DailyNutritionSummary(
            date: Date(),
            totalCalories: totalCalories,
            totalProtein: totalProtein,
            totalCarbs: totalCarbs,
            totalFat: totalFat,
            calorieGoal: 2000, // TODO: Get from user profile
            proteinGoal: 150,
            carbsGoal: 200,
            fatGoal: 65,
            mealsLogged: todaysEntries.count
        )
    }
    
    private func calculateTrends(from history: [FoodEntry]) -> FoodNutritionTrends {
        let groupedByDay = Dictionary(grouping: history) { entry in
            Calendar.current.startOfDay(for: entry.timestamp)
        }
        
        let dailyCalories = groupedByDay.map { date, entries in
            (date, entries.reduce(0) { $0 + $1.calories })
        }.sorted { $0.0 < $1.0 }
        
        let avgCalories = dailyCalories.isEmpty ? 0 : dailyCalories.reduce(0) { $0 + $1.1 } / Double(dailyCalories.count)
        
        return FoodNutritionTrends(
            averageCalories: avgCalories,
            averageProtein: history.reduce(0) { $0 + $1.protein } / Double(max(history.count, 1)),
            averageCarbs: history.reduce(0) { $0 + $1.carbs } / Double(max(history.count, 1)),
            averageFat: history.reduce(0) { $0 + $1.fat } / Double(max(history.count, 1)),
            dailyCalories: dailyCalories,
            consistency: calculateConsistency(from: groupedByDay)
        )
    }
    
    private func analyzeMealPatterns(from history: [FoodEntry]) -> FoodMealPatterns {
        let mealTypeCounts = Dictionary(grouping: history) { $0.mealType }
            .mapValues { $0.count }
        
        let commonFoods = Dictionary(grouping: history) { $0.name }
            .sorted { $0.value.count > $1.value.count }
            .prefix(10)
            .map { ($0.key, $0.value.count) }
        
        let avgMealsPerDay = Double(history.count) / 30.0
        
        return FoodMealPatterns(
            mealTypeDistribution: mealTypeCounts,
            commonFoods: commonFoods,
            averageMealsPerDay: avgMealsPerDay,
            mostSkippedMeal: mealTypeCounts.min(by: { $0.value < $1.value })?.key
        )
    }
    
    private func calculateConsistency(from groupedData: [Date: [FoodEntry]]) -> Double {
        let daysWithLogs = groupedData.count
        let totalDays = 7
        return Double(daysWithLogs) / Double(totalDays)
    }
    
    // MARK: - AI Analysis Parsing
    
    private func parseAIAnalysis(_ analysis: String) -> (name: String, calories: Double, protein: Double, carbs: Double, fat: Double, servingSize: String?) {
        // Extract nutrition info from AI response
        let lines = analysis.components(separatedBy: .newlines)
        
        var name = "Food Item"
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        var servingSize: String?
        
        for line in lines {
            let lower = line.lowercased()
            
            if lower.contains("calories") || lower.contains("kcal") {
                if let value = extractNumber(from: line) {
                    calories = value
                }
            }
            
            if lower.contains("protein") {
                if let value = extractNumber(from: line) {
                    protein = value
                }
            }
            
            if lower.contains("carb") {
                if let value = extractNumber(from: line) {
                    carbs = value
                }
            }
            
            if lower.contains("fat") && !lower.contains("saturated") {
                if let value = extractNumber(from: line) {
                    fat = value
                }
            }
            
            // Extract food name from first line
            if name == "Food Item" && !line.isEmpty && !lower.contains("analyze") {
                name = line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return (name, calories, protein, carbs, fat, servingSize)
    }
    
    private func extractNumber(from text: String) -> Double? {
        let pattern = #"(\d+\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return Double(text[range])
        }
        return nil
    }
    
    private func getCurrentUserId() -> String {
        return CurrentUserService.shared.userID ?? ""
    }
    
    // MARK: - Favorites Management
    
    func addFavorite(_ food: FoodEntry) {
        let favorite = FavoriteFood(
            id: UUID().uuidString,
            name: food.name,
            calories: food.calories,
            protein: food.protein,
            carbs: food.carbs,
            fat: food.fat,
            servingSize: food.servingSize,
            timestamp: Date()
        )
        
        // Check if already favorited
        if !favoriteFoods.contains(where: { $0.name.lowercased() == food.name.lowercased() }) {
            favoriteFoods.append(favorite)
            saveFavorites()
            print("✅ [Food] Added favorite: \(food.name)")
        }
    }
    
    func removeFavorite(_ food: FoodEntry) {
        favoriteFoods.removeAll { $0.name.lowercased() == food.name.lowercased() }
        saveFavorites()
        print("✅ [Food] Removed favorite: \(food.name)")
    }
    
    func isFavorite(_ food: FoodEntry) -> Bool {
        return favoriteFoods.contains { $0.name.lowercased() == food.name.lowercased() }
    }
    
    func toggleFavorite(_ food: FoodEntry) {
        if isFavorite(food) {
            removeFavorite(food)
        } else {
            addFavorite(food)
        }
    }
    
    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favoriteFoods) {
            UserDefaults.standard.set(encoded, forKey: "favoriteFoods")
        }
    }
    
    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: "favoriteFoods"),
              let favorites = try? JSONDecoder().decode([FavoriteFood].self, from: data) else {
            favoriteFoods = []
            return
        }
        favoriteFoods = favorites
    }
}

// MARK: - Models

struct FoodEntry: Identifiable, Codable {
    let id: String
    let userId: String
    let name: String
    let mealType: FoodMealType
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let servingSize: String?
    let notes: String?
    let timestamp: Date
    let source: FoodSource
    var imageData: Data?
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "userId": userId,
            "name": name,
            "mealType": mealType.rawValue,
            "calories": calories,
            "protein": protein,
            "carbs": carbs,
            "fat": fat,
            "servingSize": servingSize ?? "",
            "notes": notes ?? "",
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "source": source.rawValue
        ]
    }
}

enum FoodSource: String, Codable {
    case manual = "manual"
    case ai = "ai"
    case barcode = "barcode"
}

struct DailyNutritionSummary {
    let date: Date
    let totalCalories: Double
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let calorieGoal: Double
    let proteinGoal: Double
    let carbsGoal: Double
    let fatGoal: Double
    let mealsLogged: Int
    
    var calorieProgress: Double {
        return totalCalories / calorieGoal
    }
    
    var proteinProgress: Double {
        return totalProtein / proteinGoal
    }
}

struct FoodNutritionTrends {
    let averageCalories: Double
    let averageProtein: Double
    let averageCarbs: Double
    let averageFat: Double
    let dailyCalories: [(Date, Double)]
    let consistency: Double
}

struct FoodMealPatterns {
    let mealTypeDistribution: [FoodMealType: Int]
    let commonFoods: [(String, Int)]
    let averageMealsPerDay: Double
    let mostSkippedMeal: FoodMealType?
}

struct FoodWeeklyStats {
    let totalCalories: Double
    let totalProtein: Double
    let averageCaloriesPerDay: Double
    let daysLogged: Int
    let consistency: Double
}

struct FavoriteFood: Identifiable, Codable {
    let id: String
    let name: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let servingSize: String?
    let timestamp: Date
    
    func toFoodEntry(mealType: FoodMealType) -> FoodEntry {
        return FoodEntry(
            id: UUID().uuidString,
            userId: CurrentUserService.shared.userID ?? "",
            name: name,
            mealType: mealType,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            servingSize: servingSize,
            notes: nil,
            timestamp: Date(),
            source: .manual,
            imageData: nil
        )
    }
}

