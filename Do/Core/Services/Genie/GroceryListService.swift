//
//  GroceryListService.swift
//  Do
//
//  Service for generating grocery lists from recipes and meal plans
//

import Foundation

@MainActor
class GroceryListService: ObservableObject {
    static let shared = GroceryListService()
    
    @Published var savedGroceryLists: [GroceryList] = []
    
    private init() {
        loadGroceryLists()
    }
    
    // MARK: - Generate Grocery List from Recipes
    
    /// Generate a grocery list from one or more recipes
    /// Relationship: Recipes → Ingredients → GroceryList
    func generateGroceryList(from recipes: [Recipe], name: String = "Grocery List") -> GroceryList {
        var allIngredients: [String: (amount: Double, unit: String, category: GroceryFoodCategory)] = [:]
        
        // Aggregate ingredients from all recipes
        for recipe in recipes {
            for ingredientString in recipe.ingredients {
                // Parse ingredient string (e.g., "200g chicken breast" or "1 cup rice")
                let parsed = parseIngredientString(ingredientString)
                let key = parsed.name.lowercased()
                
                if let existing = allIngredients[key] {
                    // Combine amounts if same ingredient
                    allIngredients[key] = (
                        amount: existing.amount + parsed.amount,
                        unit: existing.unit, // Keep first unit
                        category: parsed.category
                    )
                } else {
                    allIngredients[key] = (parsed.amount, parsed.unit, parsed.category)
                }
            }
        }
        
        // Convert to GroceryListItems
        let items = allIngredients.map { (name, info) in
            GroceryListItem(
                id: UUID().uuidString,
                ingredient: GroceryIngredient(
                    id: UUID().uuidString,
                    name: name.capitalized,
                    amount: info.amount,
                    unit: info.unit,
                    category: info.category,
                    notes: nil,
                    isOptional: false
                ),
                isChecked: false,
                notes: nil,
                estimatedPrice: nil
            )
        }
        
        return GroceryList(
            id: UUID().uuidString,
            name: name,
            createdAt: Date(),
            items: Array(items),
            estimatedCost: nil,
            storeSuggestions: nil
        )
    }
    
    /// Generate grocery list from meal plan
    /// Relationship: MealPlan → Recipes → Ingredients → GroceryList
    func generateGroceryList(from mealPlan: MealPlanAction) -> GroceryList? {
        guard let plan = mealPlan.plan else { return nil }
        
        // Extract recipe names from meal plan meals
        // Note: MealPlanMeal only has name, not full Recipe
        // We'd need to look up recipes by name from RecipeStorageService
        let recipeNames = plan.meals.map { $0.name }
        
        // Load recipes from storage
        let recipes = recipeNames.compactMap { name in
            RecipeStorageService.shared.savedRecipes.first { $0.name == name }
        }
        
        if recipes.isEmpty {
            // Fallback: create simple grocery list from meal names
            let items = plan.meals.map { meal in
                GroceryListItem(
                    id: UUID().uuidString,
                    ingredient: GroceryIngredient(
                        id: UUID().uuidString,
                        name: meal.name,
                        amount: 1.0,
                        unit: "serving",
                        category: .other,
                        notes: nil,
                        isOptional: false
                    ),
                    isChecked: false,
                    notes: nil,
                    estimatedPrice: nil
                )
            }
            
            return GroceryList(
                id: UUID().uuidString,
                name: "Meal Plan Grocery List",
                createdAt: Date(),
                items: items,
                estimatedCost: nil,
                storeSuggestions: nil
            )
        }
        
        return generateGroceryList(from: recipes, name: "Meal Plan Grocery List")
    }
    
    // MARK: - Save/Load
    
    func saveGroceryList(_ list: GroceryList) {
        savedGroceryLists.append(list)
        persistGroceryLists()
    }
    
    func deleteGroceryList(_ list: GroceryList) {
        savedGroceryLists.removeAll { $0.id == list.id }
        persistGroceryLists()
    }
    
    private func loadGroceryLists() {
        guard let data = UserDefaults.standard.data(forKey: "savedGroceryLists"),
              let lists = try? JSONDecoder().decode([GroceryList].self, from: data) else {
            savedGroceryLists = []
            return
        }
        savedGroceryLists = lists
    }
    
    private func persistGroceryLists() {
        if let encoded = try? JSONEncoder().encode(savedGroceryLists) {
            UserDefaults.standard.set(encoded, forKey: "savedGroceryLists")
        }
    }
    
    // MARK: - Helper: Parse Ingredient String
    
    private func parseIngredientString(_ ingredient: String) -> (name: String, amount: Double, unit: String, category: GroceryFoodCategory) {
        let cleaned = ingredient.trimmingCharacters(in: .whitespaces)
        let parts = cleaned.components(separatedBy: .whitespaces)
        
        var amount: Double = 1.0
        var unit: String = "item"
        var name: String = cleaned
        var category: GroceryFoodCategory = .other
        
        // Try to extract amount and unit from beginning (e.g., "200g", "1 cup", "2 tbsp")
        if parts.count >= 2, let parsedAmount = Double(parts[0]) {
            amount = parsedAmount
            unit = parts[1]
            name = parts.dropFirst(2).joined(separator: " ")
        } else if parts.count >= 1, let parsedAmount = Double(parts[0]) {
            amount = parsedAmount
            if parts.count > 1 {
                unit = parts[1]
                name = parts.dropFirst(2).joined(separator: " ")
            } else {
                name = parts.dropFirst(1).joined(separator: " ")
            }
        }
        
        // Infer category from name
        let lowerName = name.lowercased()
        if lowerName.contains("chicken") || lowerName.contains("beef") || lowerName.contains("pork") || lowerName.contains("fish") || lowerName.contains("turkey") || lowerName.contains("egg") {
            category = .protein
        } else if lowerName.contains("rice") || lowerName.contains("pasta") || lowerName.contains("bread") || lowerName.contains("potato") {
            category = .carbohydrate
        } else if lowerName.contains("broccoli") || lowerName.contains("spinach") || lowerName.contains("lettuce") || lowerName.contains("carrot") {
            category = .vegetable
        } else if lowerName.contains("apple") || lowerName.contains("banana") || lowerName.contains("berry") || lowerName.contains("orange") {
            category = .fruit
        } else if lowerName.contains("milk") || lowerName.contains("cheese") || lowerName.contains("yogurt") {
            category = .dairy
        } else if lowerName.contains("oil") || lowerName.contains("butter") || lowerName.contains("avocado") {
            category = .fat
        }
        
        return (name, amount, unit, category)
    }
}


