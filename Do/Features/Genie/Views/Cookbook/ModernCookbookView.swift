//
//  ModernCookbookView.swift
//  Do
//
//  Impressive modern cookbook view
//

import SwiftUI

struct ModernCookbookView: View {
    @StateObject private var recipeStorage = RecipeStorageService.shared
    @State private var searchQuery = ""
    @State private var selectedCategory: RecipeCategory? = nil
    @State private var showingRecipeDetail: Recipe? = nil
    @State private var viewMode: ViewMode = .grid
    
    enum ViewMode {
        case grid
        case list
    }
    
    enum RecipeCategory: String, CaseIterable {
        case all = "All"
        case breakfast = "Breakfast"
        case lunch = "Lunch"
        case dinner = "Dinner"
        case snack = "Snack"
        case dessert = "Dessert"
        case healthy = "Healthy"
        case quick = "Quick"
    }
    
    var filteredRecipes: [Recipe] {
        var recipes = recipeStorage.savedRecipes
        
        // Filter by search
        if !searchQuery.isEmpty {
            recipes = recipes.filter { recipe in
                recipe.name.localizedCaseInsensitiveContains(searchQuery) ||
                recipe.description.localizedCaseInsensitiveContains(searchQuery) ||
                recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchQuery) }
            }
        }
        
        // Filter by category (if implemented in Recipe model)
        // For now, return all
        
        return recipes
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Futuristic gradient background
                LinearGradient(
                    colors: [
                        Color.brandBlue,
                        Color("1A2148"),
                        Color("1E2740")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with stats
                    headerView
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Search and filters
                    searchAndFiltersView
                        .padding(.horizontal)
                        .padding(.top, 16)
                    
                    // Content
                    if filteredRecipes.isEmpty {
                        emptyStateView
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                if viewMode == .grid {
                                    gridView
                                } else {
                                    listView
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("My Cookbook")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewMode = viewMode == .grid ? .list : .grid
                    }) {
                        Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(item: $showingRecipeDetail) { recipe in
                RecipeDetailView(recipe: recipe)
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("My Cookbook")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(recipeStorage.savedRecipes.count) saved recipes")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Stats cards
                HStack(spacing: 12) {
                    CookbookStatCard(
                        icon: "book.fill",
                        value: "\(recipeStorage.savedRecipes.count)",
                        label: "Recipes"
                    )
                }
            }
        }
    }
    
    // MARK: - Search and Filters
    
    private var searchAndFiltersView: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                
                TextField("Search recipes...", text: $searchQuery)
                    .foregroundColor(.white)
                
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            
            // Category filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(RecipeCategory.allCases, id: \.self) { category in
                        CategoryFilterButton(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Grid View
    
    private var gridView: some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
        
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(filteredRecipes) { recipe in
                ModernRecipeCard(recipe: recipe) {
                    showingRecipeDetail = recipe
                }
            }
        }
    }
    
    // MARK: - List View
    
    private var listView: some View {
        ForEach(filteredRecipes) { recipe in
            RecipeListRow(recipe: recipe) {
                showingRecipeDetail = recipe
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.3))
            
            Text(searchQuery.isEmpty ? "No Recipes Yet" : "No Recipes Found")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text(searchQuery.isEmpty ?
                 "Start saving recipes from Genie to build your cookbook" :
                 "Try a different search term")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Views

struct CookbookStatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color.brandOrange)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(width: 80)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct CategoryFilterButton: View {
    let category: ModernCookbookView.RecipeCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ?
                    Color.brandOrange :
                    Color.white.opacity(0.1)
                )
                .cornerRadius(20)
        }
    }
}

struct RecipeListRow: View {
    let recipe: Recipe
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Recipe image placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.brandOrange.opacity(0.3),
                                    Color("FF6B35").opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "fork.knife")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Recipe info
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    if !recipe.description.isEmpty {
                        Text(recipe.description)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                    
                    // Nutrition badges
                    if let calories = recipe.calories {
                        HStack(spacing: 8) {
                            NutritionBadge(label: "Cal", value: Int(calories))
                            if let protein = recipe.protein {
                                NutritionBadge(label: "P", value: Int(protein), unit: "g")
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

struct RecipeDetailView: View {
    let recipe: Recipe
    @Environment(\.dismiss) var dismiss
    @State private var selectedMealType: FoodMealType = .dinner
    @State private var showingTrackConfirmation = false
    @State private var showingGroceryList = false
    @State private var generatedGroceryList: GroceryList? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.brandBlue,
                        Color("1A2148")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Recipe header
                        recipeHeader
                            .padding(.horizontal)
                            .padding(.top)
                        
                        // Quick actions
                        quickActions
                            .padding(.horizontal)
                        
                        // Ingredients
                        ingredientsSection
                            .padding(.horizontal)
                        
                        // Instructions
                        instructionsSection
                            .padding(.horizontal)
                        
                        // Nutrition
                        nutritionSection
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle(recipe.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showingGroceryList) {
                if let list = generatedGroceryList {
                    GroceryListView(groceryList: list)
                }
            }
            .confirmationDialog("Track Recipe", isPresented: $showingTrackConfirmation) {
                ForEach(FoodMealType.allCases, id: \.self) { mealType in
                    Button(mealType.rawValue) {
                        trackRecipe(mealType: mealType)
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    
    private var recipeHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(recipe.name)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            if !recipe.description.isEmpty {
                Text(recipe.description)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(4)
            }
            
            // Recipe metadata
            HStack(spacing: 24) {
                if let servings = recipe.servings {
                    RecipeMeta(icon: "person.2.fill", text: "\(servings) servings")
                }
                if let prepTime = recipe.prepTime {
                    RecipeMeta(icon: "clock.fill", text: "\(prepTime) min prep")
                }
                if let cookTime = recipe.cookTime {
                    RecipeMeta(icon: "flame.fill", text: "\(cookTime) min cook")
                }
            }
        }
    }
    
    private var quickActions: some View {
        HStack(spacing: 12) {
            CookbookActionButton(
                icon: "checkmark.circle.fill",
                label: "Track",
                color: Color.brandOrange
            ) {
                showingTrackConfirmation = true
            }
            
            CookbookActionButton(
                icon: "list.bullet",
                label: "Grocery List",
                color: .blue
            ) {
                // Generate grocery list
            }
            
            CookbookActionButton(
                icon: "square.and.arrow.up",
                label: "Share",
                color: .green
            ) {
                // Share recipe
            }
        }
    }
    
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ingredients")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    IngredientRow(
                        number: index + 1,
                        ingredient: ingredient
                    )
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Instructions")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    InstructionStep(
                        number: index + 1,
                        instruction: step.instruction
                    )
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nutrition")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            if let calories = recipe.calories {
                NutritionGrid(
                    calories: calories,
                    protein: recipe.protein,
                    carbs: recipe.carbs,
                    fat: recipe.fat
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private func generateGroceryList() {
        // Generate grocery list from this recipe
        let groceryList = GroceryListService.shared.generateGroceryList(from: [recipe], name: "\(recipe.name) Grocery List")
        generatedGroceryList = groceryList
        showingGroceryList = true
    }
    
    private func trackRecipe(mealType: FoodMealType) {
        Task {
            do {
                let calories = Double(recipe.calories ?? 0)
                let protein = recipe.protein ?? 0
                let carbs = recipe.carbs ?? 0
                let fat = recipe.fat ?? 0
                
                // Get recipe ID from saved recipes (if available)
                let savedRecipes = RecipeStorageService.shared.savedRecipes
                let recipeId = savedRecipes.first(where: { $0.id == recipe.id })?.id.uuidString
                
                try await FoodTrackingService.shared.logFood(
                    name: recipe.name,
                    mealType: mealType,
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    servingSize: recipe.servings != nil ? "\(recipe.servings!) servings" : nil,
                    notes: "Recipe: \(recipe.name)",
                    recipeId: recipeId // RELATIONSHIP: Link to recipe
                )
                
                print("✅ [Cookbook] Tracked recipe: \(recipe.name)")
            } catch {
                print("❌ [Cookbook] Error tracking recipe: \(error)")
            }
        }
    }
}

// MARK: - Supporting Components

struct RecipeMeta: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: 14))
        }
        .foregroundColor(.white.opacity(0.7))
    }
}

struct CookbookActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.2))
            .cornerRadius(12)
        }
    }
}

struct IngredientRow: View {
    let number: Int
    let ingredient: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Number badge
            ZStack {
                Circle()
                    .fill(Color.brandOrange.opacity(0.2))
                    .frame(width: 28, height: 28)
                
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.brandOrange)
            }
            
            Text(ingredient)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let instruction: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step number
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.brandOrange,
                                Color("FF6B35")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Text("\(number)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(instruction)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
            
            Spacer()
        }
    }
}

struct NutritionGrid: View {
    let calories: Int
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    
    var body: some View {
        HStack(spacing: 12) {
            CookbookNutritionCard(
                label: "Calories",
                value: "\(calories)",
                icon: "flame.fill",
                color: .orange
            )
            
            if let protein = protein {
                CookbookNutritionCard(
                    label: "Protein",
                    value: "\(Int(protein))g",
                    icon: "chart.pie.fill",
                    color: .blue
                )
            }
            
            if let carbs = carbs {
                CookbookNutritionCard(
                    label: "Carbs",
                    value: "\(Int(carbs))g",
                    icon: "leaf.fill",
                    color: .green
                )
            }
            
            if let fat = fat {
                CookbookNutritionCard(
                    label: "Fat",
                    value: "\(Int(fat))g",
                    icon: "drop.fill",
                    color: .yellow
                )
            }
        }
    }
}

struct CookbookNutritionCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

