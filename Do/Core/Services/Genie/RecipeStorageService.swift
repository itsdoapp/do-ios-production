//
//  RecipeStorageService.swift
//  Do
//
//  Service for saving and retrieving recipes
//

import Foundation
import SwiftUI

@MainActor
class RecipeStorageService: ObservableObject {
    static let shared = RecipeStorageService()
    
    @Published var savedRecipes: [Recipe] = []
    
    private let recipesKey = "savedRecipes"
    
    private init() {
        loadRecipes()
    }
    
    // MARK: - Save Recipe
    
    func saveRecipe(_ recipe: Recipe) {
        // Check for duplicates
        let isDuplicate = savedRecipes.contains { savedRecipe in
            savedRecipe.name.lowercased() == recipe.name.lowercased()
        }
        
        if isDuplicate {
            print("⚠️ [RecipeStorage] Recipe '\(recipe.name)' already saved")
            return
        }
        
        savedRecipes.append(recipe)
        persistRecipes()
        print("✅ [RecipeStorage] Saved recipe: \(recipe.name)")
    }
    
    func deleteRecipe(_ recipe: Recipe) {
        savedRecipes.removeAll { $0.id == recipe.id }
        persistRecipes()
        print("✅ [RecipeStorage] Deleted recipe: \(recipe.name)")
    }
    
    // MARK: - Persistence
    
    private func loadRecipes() {
        guard let data = UserDefaults.standard.data(forKey: recipesKey),
              let decoded = try? JSONDecoder().decode([RecipeCodable].self, from: data) else {
            savedRecipes = []
            return
        }
        
        savedRecipes = decoded.map { $0.toRecipe() }
        print("✅ [RecipeStorage] Loaded \(savedRecipes.count) saved recipes")
    }
    
    private func persistRecipes() {
        let codables = savedRecipes.map { RecipeCodable(from: $0) }
        if let encoded = try? JSONEncoder().encode(codables) {
            UserDefaults.standard.set(encoded, forKey: recipesKey)
        }
    }
    
    // MARK: - Search
    
    func searchRecipes(query: String) -> [Recipe] {
        let lowercased = query.lowercased()
        return savedRecipes.filter { recipe in
            recipe.name.lowercased().contains(lowercased) ||
            recipe.description.lowercased().contains(lowercased) ||
            recipe.ingredients.contains { $0.lowercased().contains(lowercased) }
        }
    }
}

// MARK: - Codable Wrapper for Recipe

struct RecipeCodable: Codable {
    let id: String
    let name: String
    let description: String
    let ingredients: [String]
    let steps: [RecipeStepCodable]
    let prepTime: Int?
    let cookTime: Int?
    let servings: Int?
    let calories: Int?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let savedAt: String
    
    init(from recipe: Recipe) {
        self.id = recipe.id.uuidString
        self.name = recipe.name
        self.description = recipe.description
        self.ingredients = recipe.ingredients
        self.steps = recipe.steps.map { RecipeStepCodable(from: $0) }
        self.prepTime = recipe.prepTime
        self.cookTime = recipe.cookTime
        self.servings = recipe.servings
        self.calories = recipe.calories
        self.protein = recipe.protein
        self.carbs = recipe.carbs
        self.fat = recipe.fat
        self.savedAt = ISO8601DateFormatter().string(from: Date())
    }
    
    func toRecipe() -> Recipe {
        Recipe(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            description: description,
            ingredients: ingredients,
            steps: steps.map { $0.toRecipeStep() },
            prepTime: prepTime,
            cookTime: cookTime,
            servings: servings,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat
        )
    }
}

struct RecipeStepCodable: Codable {
    let id: String
    let number: Int
    let instruction: String
    let duration: Int?
    let temperature: String?
    
    init(from step: RecipeStep) {
        self.id = step.id.uuidString
        self.number = step.number
        self.instruction = step.instruction
        self.duration = step.duration
        self.temperature = step.temperature
    }
    
    func toRecipeStep() -> RecipeStep {
        RecipeStep(
            id: UUID(uuidString: id) ?? UUID(),
            number: number,
            instruction: instruction,
            duration: duration,
            temperature: temperature
        )
    }
}




