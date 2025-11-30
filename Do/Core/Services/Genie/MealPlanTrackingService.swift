//
//  MealPlanTrackingService.swift
//  Do
//
//  Meal plan tracking service - saves meal plans to prod-nutrition table
//

import Foundation

@MainActor
class MealPlanTrackingService: ObservableObject {
    static let shared = MealPlanTrackingService()
    
    private init() {}
    
    // MARK: - Save Meal Plan
    
    /// Save a meal plan to the prod-nutrition table
    func saveMealPlan(
        planName: String,
        duration: Int,
        startDate: Date,
        meals: [MealPlanMeal],
        planText: String? = nil
    ) async throws {
        let endDate = Calendar.current.date(byAdding: .day, value: duration - 1, to: startDate) ?? startDate
        
        // Calculate totals
        let totalCalories = meals.reduce(0) { $0 + $1.calories }
        let totalProtein = meals.reduce(0) { $0 + $1.protein }
        let totalCarbs = meals.reduce(0) { $0 + $1.carbs }
        let totalFat = meals.reduce(0) { $0 + $1.fat }
        
        // Create meal plan entry structure
        let mealsData = meals.map { meal in
            [
                "date": ISO8601DateFormatter().string(from: startDate), // Use start date for all meals (can be enhanced)
                "mealType": meal.mealType,
                "recipeId": nil as String?,
                "recipeName": meal.name,
                "calories": meal.calories,
                "protein": meal.protein,
                "carbs": meal.carbs,
                "fat": meal.fat,
                "isCompleted": false
            ] as [String: Any]
        }
        
        // Save to backend via Genie API
        // Note: We'll need to add a meal plan endpoint, or save it as a recipe entry type
        // For now, we'll save individual meals and create a reference
        
        let nutritionId = UUID().uuidString
        let now = Date()
        
        // Create meal plan entry in prod-nutrition table
        // Using entryType: "meal_plan"
        let mealPlanEntry: [String: Any] = [
            "nutritionId": nutritionId,
            "entryType": "meal_plan",
            "consumedAt": ISO8601DateFormatter().string(from: startDate),
            "createdAt": ISO8601DateFormatter().string(from: now),
            "source": "genie",
            "planName": planName,
            "startDate": ISO8601DateFormatter().string(from: startDate),
            "endDate": ISO8601DateFormatter().string(from: endDate),
            "meals": mealsData,
            "totalCalories": totalCalories,
            "totalProtein": totalProtein,
            "totalCarbs": totalCarbs,
            "totalFat": totalFat,
            "planText": planText ?? ""
        ]
        
        // Save via Genie API (we'll need to add this endpoint)
        // For now, save individual meals and store plan metadata
        print("📋 [MealPlan] Saving meal plan: \(planName) with \(meals.count) meals")
        
        // Save each meal individually as food entries
        // This ensures they appear in the food tracker
        for meal in meals {
            let mealType = FoodMealType(rawValue: meal.mealType) ?? .breakfast
            
            do {
                try await FoodTrackingService.shared.logFood(
                    name: meal.name,
                    mealType: mealType,
                    calories: meal.calories,
                    protein: meal.protein,
                    carbs: meal.carbs,
                    fat: meal.fat,
                    notes: "From meal plan: \(planName)"
                )
            } catch {
                print("❌ [MealPlan] Error saving meal \(meal.name): \(error)")
            }
        }
        
        // Store meal plan metadata locally for reference
        saveMealPlanMetadata(mealPlanEntry)
        
        print("✅ [MealPlan] Meal plan saved: \(planName)")
    }
    
    // MARK: - Load Meal Plans
    
    func loadMealPlans() async throws -> [[String: Any]] {
        // Load from local storage for now
        // In the future, load from prod-nutrition table with entryType: "meal_plan"
        return loadMealPlanMetadata()
    }
    
    // MARK: - Private Helpers
    
    private func saveMealPlanMetadata(_ entry: [String: Any]) {
        var plans = loadMealPlanMetadata()
        plans.append(entry)
        
        if let data = try? JSONSerialization.data(withJSONObject: plans) {
            UserDefaults.standard.set(data, forKey: "savedMealPlans")
        }
    }
    
    private func loadMealPlanMetadata() -> [[String: Any]] {
        guard let data = UserDefaults.standard.data(forKey: "savedMealPlans"),
              let plans = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return plans
    }
}


