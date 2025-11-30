//
//  MealSuggestionsView.swift
//  Do
//
//  Display meal suggestions with step-by-step recipe following
//

import SwiftUI

struct MealSuggestionsView: View {
    let suggestions: MealSuggestionsAction
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRecipe: Recipe?
    @State private var showRecipeSteps = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.brandBlue
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Meal Suggestions")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Based on your available ingredients")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        // Recipes (prioritize structured recipes)
                        if !suggestions.recipes.isEmpty {
                            // If only one recipe, show it expanded immediately
                            if suggestions.recipes.count == 1, let singleRecipe = suggestions.recipes.first {
                                SingleRecipeExpandedView(recipe: singleRecipe)
                                    .padding(.horizontal, 20)
                            } else {
                                // Multiple recipes - show as cards
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Recipes")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                    
                                    ForEach(suggestions.recipes) { recipe in
                                        ModernRecipeCard(recipe: recipe) {
                                            selectedRecipe = recipe
                                            showRecipeSteps = true
                                        }
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                        
                        // Quick suggestions (if no structured recipes)
                        if suggestions.recipes.isEmpty && !suggestions.suggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Quick Suggestions")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                
                                ForEach(Array(suggestions.suggestions.enumerated()), id: \.offset) { index, suggestion in
                                    SuggestionCard(text: suggestion, index: index + 1)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .fullScreenCover(isPresented: $showRecipeSteps) {
                if let recipe = selectedRecipe {
                    RecipeStepView(recipe: recipe)
                }
            }
        }
    }
}

// MARK: - Modern Recipe Card

struct ModernRecipeCard: View {
    let recipe: Recipe
    let onTap: () -> Void
    @StateObject private var recipeStorage = RecipeStorageService.shared
    @State private var showSaveConfirmation = false
    
    private var isSaved: Bool {
        recipeStorage.savedRecipes.contains { $0.id == recipe.id }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            if !recipe.description.isEmpty {
                                Text(recipe.description)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(2)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.brandOrange)
                    }
                
                // Ingredients preview
                if !recipe.ingredients.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                        Text("\(recipe.ingredients.count) ingredients")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                        
                        if !recipe.steps.isEmpty {
                            Text("•")
                                .foregroundColor(.white.opacity(0.4))
                            Text("\(recipe.steps.count) steps")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                
                    // Nutrition info if available
                    if recipe.hasNutritionInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            // Primary macros (calories, protein, carbs, fat)
                            HStack(spacing: 8) {
                                if let calories = recipe.calories {
                                    NutritionBadge(label: "Cal", value: calories)
                                }
                                if let protein = recipe.protein {
                                    NutritionBadge(label: "Protein", value: Int(protein), unit: "g")
                                }
                                if let carbs = recipe.carbs {
                                    NutritionBadge(label: "Carbs", value: Int(carbs), unit: "g")
                                }
                                if let fat = recipe.fat {
                                    NutritionBadge(label: "Fat", value: Int(fat), unit: "g")
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            
            // Save button
            HStack {
                Button(action: {
                    if isSaved {
                        recipeStorage.deleteRecipe(recipe)
                    } else {
                        recipeStorage.saveRecipe(recipe)
                        showSaveConfirmation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showSaveConfirmation = false
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 14, weight: .medium))
                        Text(isSaved ? "Saved" : "Save Recipe")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(isSaved ? Color.brandOrange : .white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSaved ? Color.brandOrange.opacity(0.2) : Color.white.opacity(0.1))
                    )
                }
                
                if showSaveConfirmation {
                    Text("Saved!")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.brandOrange)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSaved ? Color.brandOrange.opacity(0.5) : Color.white.opacity(0.15), lineWidth: isSaved ? 2 : 1)
                )
        )
        .padding(.horizontal, 20)
        .buttonStyle(.plain)
    }
}

// MARK: - Suggestion Card

struct SuggestionCard: View {
    let text: String
    let index: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.brandOrange)
                .frame(width: 28, height: 28)
                .background(Color.brandOrange.opacity(0.2))
                .cornerRadius(14)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Single Recipe Expanded View

struct SingleRecipeExpandedView: View {
    let recipe: Recipe
    @StateObject private var recipeStorage = RecipeStorageService.shared
    @State private var showTrackRecipe = false
    @State private var selectedMealType: FoodMealType = .dinner
    
    private var isSaved: Bool {
        recipeStorage.savedRecipes.contains { $0.id == recipe.id }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Recipe header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(recipe.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        if isSaved {
                            recipeStorage.deleteRecipe(recipe)
                        } else {
                            recipeStorage.saveRecipe(recipe)
                        }
                    }) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 20))
                            .foregroundColor(isSaved ? Color.brandOrange : .white.opacity(0.7))
                    }
                }
                
                if !recipe.description.isEmpty {
                    Text(recipe.description)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Ingredients
            if !recipe.ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ingredients")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(recipe.ingredients, id: \.self) { ingredient in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.brandOrange)
                                    .frame(width: 6, height: 6)
                                Text(ingredient)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.9))
                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                }
            }
            
            // Steps
            if !recipe.steps.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Instructions")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(recipe.steps) { step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(step.number)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color.brandOrange)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        Circle()
                                            .fill(Color.brandOrange.opacity(0.2))
                                    )
                                
                                Text(step.instruction)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                }
            }
            
            // Nutrition info
            if recipe.hasNutritionInfo {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nutrition")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        if let calories = recipe.calories {
                            NutritionBadge(label: "Cal", value: calories)
                        }
                        if let protein = recipe.protein {
                            NutritionBadge(label: "Protein", value: Int(protein), unit: "g")
                        }
                        if let carbs = recipe.carbs {
                            NutritionBadge(label: "Carbs", value: Int(carbs), unit: "g")
                        }
                        if let fat = recipe.fat {
                            NutritionBadge(label: "Fat", value: Int(fat), unit: "g")
                        }
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    showTrackRecipe = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Track Recipe")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.brandOrange)
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .confirmationDialog("Track Recipe", isPresented: $showTrackRecipe) {
            Button("Breakfast") {
                selectedMealType = .breakfast
                trackRecipe()
            }
            Button("Lunch") {
                selectedMealType = .lunch
                trackRecipe()
            }
            Button("Dinner") {
                selectedMealType = .dinner
                trackRecipe()
            }
            Button("Snack") {
                selectedMealType = .snack
                trackRecipe()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Select meal type to track this recipe")
        }
    }
    
    private func trackRecipe() {
        Task {
            do {
                let calories = Double(recipe.calories ?? 0)
                let protein = recipe.protein ?? 0
                let carbs = recipe.carbs ?? 0
                let fat = recipe.fat ?? 0
                
                try await FoodTrackingService.shared.logFood(
                    name: recipe.name,
                    mealType: selectedMealType,
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    servingSize: recipe.servings != nil ? "\(recipe.servings!) servings" : nil,
                    notes: "Recipe: \(recipe.name)"
                )
                
                await MainActor.run {
                    showTrackRecipe = false
                }
            } catch {
                print("❌ [Recipe] Error tracking recipe: \(error)")
            }
        }
    }
}

// MARK: - Recipe Step View (Step-by-Step Following)

struct RecipeStepView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @State private var currentStepIndex = 0
    @State private var isWakeWordActive = false
    @StateObject private var wakeWordService = RecipeWakeWordService.shared
    @StateObject private var recipeStorage = RecipeStorageService.shared
    @State private var showSaveConfirmation = false
    @State private var showTrackRecipe = false
    @State private var selectedMealType: FoodMealType = .lunch
    
    private var isSaved: Bool {
        recipeStorage.savedRecipes.contains { $0.id == recipe.id }
    }
    
    var currentStep: RecipeStep? {
        guard currentStepIndex < recipe.steps.count else { return nil }
        return recipe.steps[currentStepIndex]
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.brandBlue
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Current step (large, centered)
                    if let step = currentStep {
                        ScrollView {
                            VStack(spacing: 24) {
                                // Step number indicator
                                ZStack {
                                    Circle()
                                        .fill(Color.brandOrange.opacity(0.2))
                                        .frame(width: 80, height: 80)
                                    
                                    Text("\(step.number)")
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(Color.brandOrange)
                                }
                                .padding(.top, 40)
                                
                                // Step instruction
                                Text(step.instruction)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(6)
                                    .padding(.horizontal, 32)
                                
                                // Progress indicator
                                HStack(spacing: 8) {
                                    ForEach(0..<recipe.steps.count, id: \.self) { index in
                                        Rectangle()
                                            .fill(index <= currentStepIndex ? Color.brandOrange : Color.white.opacity(0.2))
                                            .frame(height: 4)
                                            .cornerRadius(2)
                                    }
                                }
                                .padding(.horizontal, 32)
                                .padding(.top, 8)
                                
                                // Ingredients list (if available)
                                if !recipe.ingredients.isEmpty && currentStepIndex == 0 {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Ingredients")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                        
                                        ForEach(recipe.ingredients, id: \.self) { ingredient in
                                            HStack(spacing: 12) {
                                                Image(systemName: "circle.fill")
                                                    .font(.system(size: 6))
                                                    .foregroundColor(Color.brandOrange)
                                                Text(ingredient)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.white.opacity(0.9))
                                                Spacer()
                                            }
                                        }
                                    }
                                    .padding(20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.1))
                                    )
                                    .padding(.horizontal, 32)
                                    .padding(.top, 16)
                                }
                            }
                            .padding(.bottom, 120) // Space for controls
                        }
                    }
                    
                    // Bottom controls
                    VStack(spacing: 16) {
                        // Wake word toggle
                        HStack {
                            Image(systemName: isWakeWordActive ? "mic.fill" : "mic.slash.fill")
                                .foregroundColor(isWakeWordActive ? Color.brandOrange : .white.opacity(0.6))
                            Text(isWakeWordActive ? "Wake word active - say 'Genie'" : "Enable wake word")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )
                        .onTapGesture {
                            toggleWakeWord()
                        }
                        
                        // Navigation buttons
                        HStack(spacing: 16) {
                            // Previous step
                            Button(action: previousStep) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("Previous")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.15))
                                )
                            }
                            .disabled(currentStepIndex == 0)
                            .opacity(currentStepIndex == 0 ? 0.5 : 1.0)
                            
                            // Next step / Complete
                            Button(action: nextStep) {
            HStack {
                                    Text(currentStepIndex >= recipe.steps.count - 1 ? "Complete" : "Next")
                                    if currentStepIndex < recipe.steps.count - 1 {
                                        Image(systemName: "chevron.right")
                                    }
                                }
                    .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.brandOrange)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        Color.brandBlue
                            .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
            }
            
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Save recipe button
                        Button(action: {
                            if isSaved {
                                recipeStorage.deleteRecipe(recipe)
                            } else {
                                recipeStorage.saveRecipe(recipe)
                                showSaveConfirmation = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    showSaveConfirmation = false
                                }
                            }
                        }) {
                            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 18))
                                .foregroundColor(isSaved ? Color.brandOrange : .white.opacity(0.7))
                        }
                        
                        // Track recipe button
                        Button(action: {
                            showTrackRecipe = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Text("\(currentStepIndex + 1) of \(recipe.steps.count)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .confirmationDialog("Track Recipe", isPresented: $showTrackRecipe) {
                Button("Breakfast") {
                    selectedMealType = .breakfast
                    trackRecipe()
                }
                Button("Lunch") {
                    selectedMealType = .lunch
                    trackRecipe()
                }
                Button("Dinner") {
                    selectedMealType = .dinner
                    trackRecipe()
                }
                Button("Snack") {
                    selectedMealType = .snack
                    trackRecipe()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Select meal type to track this recipe")
            }
            .onAppear {
                wakeWordService.onWakeWordDetected = { command in
                    let lowercased = command.lowercased()
                    
                    if lowercased.contains("next") || lowercased.contains("continue") {
                        nextStep()
                    } else if lowercased.contains("previous") || lowercased.contains("back") || lowercased.contains("repeat") {
                        previousStep()
                    } else if lowercased.contains("recipe") || lowercased.contains("what") {
                        // Speak current step
                        if let step = currentStep {
                            GenieVoiceService.shared.speak(step.instruction)
                        }
                    } else if lowercased.contains("how much") || lowercased.contains("how many") {
                        // Speak ingredient amounts
                        if let step = currentStep {
                            GenieVoiceService.shared.speak(step.instruction)
                        }
                    }
                }
            }
            .onDisappear {
                wakeWordService.stopListening()
                wakeWordService.onWakeWordDetected = nil
            }
        }
    }
    
    private func nextStep() {
        if currentStepIndex < recipe.steps.count - 1 {
            withAnimation(.spring(response: 0.3)) {
                currentStepIndex += 1
            }
        } else {
            // Recipe complete
            dismiss()
        }
    }
    
    private func previousStep() {
        if currentStepIndex > 0 {
            withAnimation(.spring(response: 0.3)) {
                currentStepIndex -= 1
            }
        }
    }
    
    private func toggleWakeWord() {
        if isWakeWordActive {
            wakeWordService.stopListening()
            isWakeWordActive = false
        } else {
            wakeWordService.startListening(for: recipe)
            isWakeWordActive = true
        }
    }
    
    private func trackRecipe() {
        Task {
            do {
                let calories = Double(recipe.calories ?? 0)
                let protein = recipe.protein ?? 0
                let carbs = recipe.carbs ?? 0
                let fat = recipe.fat ?? 0
                
                try await FoodTrackingService.shared.logFood(
                    name: recipe.name,
                    mealType: selectedMealType,
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    servingSize: recipe.servings != nil ? "\(recipe.servings!) servings" : nil,
                    notes: "Recipe: \(recipe.name)"
                )
                
                await MainActor.run {
                    showTrackRecipe = false
                    // Show success feedback
                    GenieVoiceService.shared.speak("Recipe tracked successfully")
                }
            } catch {
                print("❌ [Recipe] Error tracking recipe: \(error)")
            }
        }
    }
}

// MARK: - Recipe Wake Word Service

@MainActor
class RecipeWakeWordService: ObservableObject {
    static let shared = RecipeWakeWordService()
    
    var onWakeWordDetected: ((String) -> Void)?
    private var currentRecipe: Recipe?
    private var isListening = false
    private var listeningTask: Task<Void, Never>?
    private let voiceService = GenieVoiceService.shared
    
    private init() {
        // Observe voice service for partial results to detect wake word
    }
    
    func startListening(for recipe: Recipe) {
        guard !isListening else { return }
        currentRecipe = recipe
        isListening = true
        
        listeningTask = Task {
            await startContinuousListening()
        }
    }
    
    func stopListening() {
        isListening = false
        listeningTask?.cancel()
        listeningTask = nil
        voiceService.stopListening()
    }
    
    private func startContinuousListening() async {
        while isListening && !Task.isCancelled {
            do {
                // Listen for wake word - use shorter timeout for responsiveness
                let text = try await voiceService.startListening()
                guard isListening && !Task.isCancelled else { return }
                
                let lowercased = text.lowercased()
                
                // Check for wake word "Genie"
                if lowercased.contains("genie") {
                    // Extract command after wake word
                    if let genieRange = lowercased.range(of: "genie") {
                        let afterGenie = String(lowercased[genieRange.upperBound...])
                        let command = afterGenie.trimmingCharacters(in: .whitespaces)
                        
                        if !command.isEmpty {
                            await MainActor.run {
                                onWakeWordDetected?(command)
                            }
                        } else {
                            // Just "Genie" - default to reading current step
                            await MainActor.run {
                                onWakeWordDetected?("what's next")
                            }
                        }
                    }
                }
                
                // Small delay before listening again to prevent rapid re-triggers
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            } catch {
                guard isListening && !Task.isCancelled else { return }
                print("❌ [WakeWord] Error: \(error)")
                // Wait before retrying
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
            }
        }
    }
}
