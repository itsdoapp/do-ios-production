//
//  MealTemplatesView.swift
//  Do
//
//  Meal templates view for quick food logging
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

struct MealTemplatesView: View {
    let onTemplateSelected: (MealTemplate) -> Void
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var foodService = FoodTrackingService.shared
    
    @State private var searchText = ""
    @State private var selectedMealType: FoodMealType = .breakfast
    
    // Predefined meal templates
    private let mealTemplates: [MealTemplate] = [
        // Breakfast Templates
        MealTemplate(name: "Classic Breakfast", mealType: .breakfast, foods: [
            FoodItem(name: "Scrambled Eggs", calories: 200, protein: 14, carbs: 2, fat: 15),
            FoodItem(name: "Whole Wheat Toast", calories: 80, protein: 3, carbs: 15, fat: 1),
            FoodItem(name: "Orange Juice", calories: 110, protein: 2, carbs: 26, fat: 0)
        ]),
        MealTemplate(name: "Oatmeal Bowl", mealType: .breakfast, foods: [
            FoodItem(name: "Oatmeal", calories: 150, protein: 5, carbs: 27, fat: 3),
            FoodItem(name: "Banana", calories: 105, protein: 1, carbs: 27, fat: 0),
            FoodItem(name: "Almonds", calories: 164, protein: 6, carbs: 6, fat: 14)
        ]),
        MealTemplate(name: "Yogurt Parfait", mealType: .breakfast, foods: [
            FoodItem(name: "Greek Yogurt", calories: 100, protein: 17, carbs: 6, fat: 0),
            FoodItem(name: "Granola", calories: 120, protein: 3, carbs: 22, fat: 3),
            FoodItem(name: "Blueberries", calories: 40, protein: 0, carbs: 10, fat: 0)
        ]),
        
        // Lunch Templates
        MealTemplate(name: "Grilled Chicken Salad", mealType: .lunch, foods: [
            FoodItem(name: "Grilled Chicken Breast", calories: 231, protein: 43, carbs: 0, fat: 5),
            FoodItem(name: "Mixed Greens", calories: 20, protein: 2, carbs: 3, fat: 0),
            FoodItem(name: "Olive Oil Dressing", calories: 120, protein: 0, carbs: 0, fat: 14)
        ]),
        MealTemplate(name: "Turkey Sandwich", mealType: .lunch, foods: [
            FoodItem(name: "Whole Wheat Bread", calories: 160, protein: 6, carbs: 30, fat: 2),
            FoodItem(name: "Turkey Slices", calories: 90, protein: 18, carbs: 1, fat: 1),
            FoodItem(name: "Lettuce & Tomato", calories: 10, protein: 0, carbs: 2, fat: 0)
        ]),
        MealTemplate(name: "Quinoa Bowl", mealType: .lunch, foods: [
            FoodItem(name: "Quinoa", calories: 222, protein: 8, carbs: 39, fat: 4),
            FoodItem(name: "Black Beans", calories: 227, protein: 15, carbs: 41, fat: 1),
            FoodItem(name: "Avocado", calories: 234, protein: 3, carbs: 12, fat: 21)
        ]),
        
        // Dinner Templates
        MealTemplate(name: "Salmon & Vegetables", mealType: .dinner, foods: [
            FoodItem(name: "Salmon Fillet", calories: 206, protein: 22, carbs: 0, fat: 12),
            FoodItem(name: "Broccoli", calories: 55, protein: 4, carbs: 11, fat: 0),
            FoodItem(name: "Brown Rice", calories: 216, protein: 5, carbs: 45, fat: 2)
        ]),
        MealTemplate(name: "Pasta Primavera", mealType: .dinner, foods: [
            FoodItem(name: "Whole Wheat Pasta", calories: 174, protein: 7, carbs: 37, fat: 1),
            FoodItem(name: "Mixed Vegetables", calories: 50, protein: 2, carbs: 10, fat: 0),
            FoodItem(name: "Olive Oil", calories: 120, protein: 0, carbs: 0, fat: 14)
        ]),
        MealTemplate(name: "Chicken Stir Fry", mealType: .dinner, foods: [
            FoodItem(name: "Chicken Breast", calories: 231, protein: 43, carbs: 0, fat: 5),
            FoodItem(name: "Mixed Vegetables", calories: 50, protein: 2, carbs: 10, fat: 0),
            FoodItem(name: "Brown Rice", calories: 216, protein: 5, carbs: 45, fat: 2)
        ]),
        
        // Snack Templates
        MealTemplate(name: "Apple & Peanut Butter", mealType: .snack, foods: [
            FoodItem(name: "Apple", calories: 95, protein: 0, carbs: 25, fat: 0),
            FoodItem(name: "Peanut Butter", calories: 188, protein: 8, carbs: 6, fat: 16)
        ]),
        MealTemplate(name: "Protein Shake", mealType: .snack, foods: [
            FoodItem(name: "Protein Powder", calories: 120, protein: 24, carbs: 3, fat: 1),
            FoodItem(name: "Almond Milk", calories: 30, protein: 1, carbs: 1, fat: 2.5)
        ]),
        MealTemplate(name: "Trail Mix", mealType: .snack, foods: [
            FoodItem(name: "Almonds", calories: 164, protein: 6, carbs: 6, fat: 14),
            FoodItem(name: "Raisins", calories: 130, protein: 1, carbs: 34, fat: 0),
            FoodItem(name: "Dark Chocolate", calories: 150, protein: 2, carbs: 15, fat: 9)
        ])
    ]
    
    private var filteredTemplates: [MealTemplate] {
        let filtered = mealTemplates.filter { template in
            template.mealType == selectedMealType
        }
        
        if searchText.isEmpty {
            return filtered
        }
        
        return filtered.filter { template in
            template.name.localizedCaseInsensitiveContains(searchText) ||
            template.foods.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
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
                        
                        TextField("Search templates...", text: $searchText)
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    
                    // Templates List
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredTemplates) { template in
                                MealTemplateCard(template: template) {
                                    selectTemplate(template)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Meal Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func selectTemplate(_ template: MealTemplate) {
        Task {
            // Log all foods in the template
            for food in template.foods {
                do {
                    try await foodService.logFood(
                        name: food.name,
                        mealType: template.mealType,
                        calories: food.calories,
                        protein: food.protein,
                        carbs: food.carbs,
                        fat: food.fat,
                        source: .manual
                    )
                } catch {
                    print("Error logging food from template: \(error)")
                }
            }
            
            await MainActor.run {
                onTemplateSelected(template)
                dismiss()
            }
        }
    }
}

// MARK: - Models

struct MealTemplate: Identifiable {
    let id = UUID()
    let name: String
    let mealType: FoodMealType
    let foods: [FoodItem]
    
    var totalCalories: Double {
        foods.reduce(0) { $0 + $1.calories }
    }
    
    var totalProtein: Double {
        foods.reduce(0) { $0 + $1.protein }
    }
    
    var totalCarbs: Double {
        foods.reduce(0) { $0 + $1.carbs }
    }
    
    var totalFat: Double {
        foods.reduce(0) { $0 + $1.fat }
    }
}

struct FoodItem {
    let name: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

// MARK: - Supporting Views

struct MealTemplateCard: View {
    let template: MealTemplate
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text(template.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(Color(hex: "F7931F"))
                }
                
                // Foods List
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(template.foods, id: \.name) { food in
                        HStack {
                            Circle()
                                .fill(Color(hex: "F7931F").opacity(0.3))
                                .frame(width: 6, height: 6)
                            
                            Text(food.name)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("\(Int(food.calories)) cal")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // Nutrition Summary
                HStack(spacing: 20) {
                    NutritionBadge(label: "Cal", value: "\(Int(template.totalCalories))", color: Color(hex: "F7931F"))
                    NutritionBadge(label: "P", value: "\(Int(template.totalProtein))g", color: .blue)
                    NutritionBadge(label: "C", value: "\(Int(template.totalCarbs))g", color: .green)
                    NutritionBadge(label: "F", value: "\(Int(template.totalFat))g", color: .purple)
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

