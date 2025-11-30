//
//  SavedRecipesView.swift
//  Do
//
//  View for displaying and using saved recipes
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

struct SavedRecipesView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var recipeStorage = RecipeStorageService.shared
    @StateObject private var foodService = FoodTrackingService.shared
    
    @State private var searchText = ""
    @State private var selectedMealType: FoodMealType = .breakfast
    @State private var selectedRecipe: Recipe?
    @State private var showingRecipeDetail = false
    @State private var isLogging = false
    
    private var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return recipeStorage.savedRecipes
        }
        return recipeStorage.searchRecipes(query: searchText)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(hex: "0F163E")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Meal Type Selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(FoodMealType.allCases, id: \.self) { type in
                                Button(action: {
                                    selectedMealType = type
                                }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: type.icon)
                                            .font(.system(size: 20))
                                        
                                        Text(type.rawValue)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(selectedMealType == type ? .white : .white.opacity(0.5))
                                    .frame(width: 80, height: 80)
                                    .background(
                                        selectedMealType == type ?
                                        LinearGradient(
                                            colors: [Color(hex: "F7931F").opacity(0.3), Color(hex: "FF6B35").opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(selectedMealType == type ? Color(hex: "F7931F").opacity(0.5) : Color.clear, lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search recipes...", text: $searchText)
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    
                    // Recipes List
                    if filteredRecipes.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.3))
                            
                            Text(searchText.isEmpty ? "No Saved Recipes" : "No Recipes Found")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                            
                            if searchText.isEmpty {
                                Text("Save recipes from Genie to use them here")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredRecipes) { recipe in
                                    SavedRecipeCard(recipe: recipe) {
                                        logRecipe(recipe)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .navigationTitle("Saved Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .overlay {
                if isLogging {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            Text("Logging recipe...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(30)
                        .background(Color(hex: "1A2148"))
                        .cornerRadius(20)
                    }
                }
            }
        }
    }
    
    private func logRecipe(_ recipe: Recipe) {
        // Use calories if available, otherwise default to 0
        // Use nil-coalescing for protein, carbs, and fat (they're already Double?)
        let calories = recipe.calories ?? 0
        let protein = recipe.protein ?? 0
        let carbs = recipe.carbs ?? 0
        let fat = recipe.fat ?? 0
        
        // Log recipe with nutrition info
        Task {
            isLogging = true
            do {
                try await foodService.logFood(
                    name: recipe.name,
                    mealType: selectedMealType,
                    calories: Double(calories),
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    notes: "Recipe: \(recipe.description)",
                    source: .manual
                )
                await MainActor.run {
                    isLogging = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLogging = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct SavedRecipeCard: View {
    let recipe: Recipe
    let onLog: () -> Void
    
    var body: some View {
        Button(action: onLog) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        if !recipe.description.isEmpty {
                            Text(recipe.description)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(Color(hex: "F7931F"))
                        .font(.system(size: 24))
                }
                
                // Recipe Info
                HStack(spacing: 16) {
                    if let prepTime = recipe.prepTime {
                        RecipeInfoBadge(icon: "clock", text: "\(prepTime)m prep")
                    }
                    
                    if let cookTime = recipe.cookTime {
                        RecipeInfoBadge(icon: "flame", text: "\(cookTime)m cook")
                    }
                    
                    if let servings = recipe.servings {
                        RecipeInfoBadge(icon: "person.2", text: "\(servings) servings")
                    }
                }
                
                // Nutrition Info (if available)
                if recipe.hasNutritionInfo {
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    HStack(spacing: 20) {
                        if let calories = recipe.calories {
                            NutritionBadge(label: "Cal", value: "\(calories)", color: Color(hex: "F7931F"))
                        }
                        if let protein = recipe.protein {
                            NutritionBadge(label: "P", value: "\(Int(protein))g", color: .blue)
                        }
                        if let carbs = recipe.carbs {
                            NutritionBadge(label: "C", value: "\(Int(carbs))g", color: .green)
                        }
                        if let fat = recipe.fat {
                            NutritionBadge(label: "F", value: "\(Int(fat))g", color: .purple)
                        }
                    }
                }
                
                // Ingredients Preview
                if !recipe.ingredients.isEmpty {
                    Text("\(recipe.ingredients.count) ingredients")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecipeInfoBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.7))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
}

