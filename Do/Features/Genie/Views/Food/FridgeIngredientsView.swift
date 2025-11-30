//
//  FridgeIngredientsView.swift
//  Do
//
//  View for editing and confirming fridge ingredients before generating meal suggestions
//

import SwiftUI

struct FridgeIngredientsView: View {
    @Environment(\.dismiss) private var dismiss
    let initialIngredients: [String]
    let capturedImage: UIImage?
    
    @State private var ingredients: [String] = []
    @State private var spices: [String] = []
    @State private var newIngredientText = ""
    @State private var newSpiceText = ""
    @State private var isGenerating = false
    @State private var showingMealSuggestions = false
    @State private var mealSuggestions: MealSuggestionsAction?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0F163E")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ingredients in Your Fridge")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Review and add any missing ingredients or spices")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        // Captured image preview
                        if let image = capturedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 150)
                                .clipped()
                                .cornerRadius(12)
                                .padding(.horizontal, 20)
                        }
                        
                        // Detected ingredients section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Detected Ingredients")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            if ingredients.isEmpty {
                                Text("No ingredients detected")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(ingredients.indices, id: \.self) { index in
                                        FridgeIngredientRow(
                                            text: ingredients[index],
                                            onRemove: {
                                                ingredients.remove(at: index)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                        )
                        .padding(.horizontal, 20)
                        
                        // Add ingredient section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Add Ingredient")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                TextField("Enter ingredient name...", text: $newIngredientText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .onSubmit {
                                        addIngredient()
                                    }
                                
                                Button(action: addIngredient) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(Color(hex: "F7931F"))
                                }
                                .disabled(newIngredientText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                        )
                        .padding(.horizontal, 20)
                        
                        // Spices/Seasonings section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Spices & Seasonings")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            if spices.isEmpty {
                                Text("Add common spices you have available")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(spices.indices, id: \.self) { index in
                                        FridgeIngredientRow(
                                            text: spices[index],
                                            onRemove: {
                                                spices.remove(at: index)
                                            }
                                        )
                                    }
                                }
                            }
                            
                            HStack(spacing: 12) {
                                TextField("Add spice...", text: $newSpiceText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .onSubmit {
                                        addSpice()
                                    }
                                
                                Button(action: addSpice) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(Color(hex: "F7931F"))
                                }
                                .disabled(newSpiceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                        )
                        .padding(.horizontal, 20)
                        
                        // Generate button
                        Button {
                            generateMealSuggestions()
                        } label: {
                            HStack {
                                if isGenerating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(isGenerating ? "Generating Suggestions..." : "Generate Meal Suggestions")
                            }
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "F7931F"), Color(hex: "FF6B35")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .disabled(isGenerating || (ingredients.isEmpty && spices.isEmpty))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .padding(.vertical)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            ingredients = initialIngredients
        }
        .sheet(isPresented: $showingMealSuggestions) {
            if let suggestions = mealSuggestions {
                MealSuggestionsView(suggestions: suggestions)
            }
        }
    }
    
    private func addIngredient() {
        let trimmed = newIngredientText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !ingredients.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
            ingredients.append(trimmed)
            newIngredientText = ""
        }
    }
    
    private func addSpice() {
        let trimmed = newSpiceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !spices.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
            spices.append(trimmed)
            newSpiceText = ""
        }
    }
    
    private func generateMealSuggestions() {
        guard !ingredients.isEmpty || !spices.isEmpty else { return }
        
        isGenerating = true
        
        Task {
            do {
                // Combine ingredients and spices
                var allItems = ingredients
                if !spices.isEmpty {
                    allItems.append(contentsOf: spices)
                }
                
                let ingredientsList = allItems.joined(separator: ", ")
                
                // Get conversation context
                let conversationId = GenieConversationManager.shared.currentConversationId ?? UUID().uuidString
                
                // Query backend for meal suggestions
                let query = "I have \(ingredientsList). What healthy meals can I make with these ingredients? Please provide recipes with step-by-step instructions."
                
                let response = try await GenieAPIService.shared.query(
                    query,
                    sessionId: conversationId
                )
                
                // Handle the response - check for meal_suggestions action
                await MainActor.run {
                    isGenerating = false
                    
                    // The backend should return a meal_suggestions action
                    // We'll let GenieActionHandler process it, but we can also parse it here
                    if let actions = response.actions,
                       let mealAction = actions.first(where: { $0.type == "meal_suggestions" }) {
                        // Parse meal suggestions
                        let suggestions = mealAction.data["suggestions"]?.arrayValue?.compactMap { $0 as? String } ?? []
                        let recipes = mealAction.data["recipes"]?.arrayValue?.compactMap { $0 as? String } ?? []
                        let analysis = mealAction.data["analysis"]?.stringValue ?? ""
                        
                        let parsedRecipes = Recipe.parseMultiple(from: suggestions, analysis: analysis)
                        
                        mealSuggestions = MealSuggestionsAction(
                            suggestions: suggestions,
                            recipes: parsedRecipes,
                            analysis: analysis
                        )
                        
                        // Also update GenieActionHandler
                        GenieActionHandler.shared.handleAction(mealAction)
                        
                        showingMealSuggestions = true
                    } else {
                        // Fallback: parse from text response
                        let parsedRecipes = Recipe.parseMultiple(from: [response.response], analysis: response.response)
                        mealSuggestions = MealSuggestionsAction(
                            suggestions: [response.response],
                            recipes: parsedRecipes,
                            analysis: response.response
                        )
                        showingMealSuggestions = true
                    }
                }
            } catch {
                print("❌ [FridgeIngredients] Error generating meal suggestions: \(error)")
                await MainActor.run {
                    isGenerating = false
                }
            }
        }
    }
}

// MARK: - Ingredient Row

struct FridgeIngredientRow: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundColor(Color(hex: "F7931F"))
            
            Text(text.capitalized)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

