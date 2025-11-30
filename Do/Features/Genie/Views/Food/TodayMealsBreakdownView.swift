//
//  TodayMealsBreakdownView.swift
//  Do
//
//  View showing today's meals breakdown
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

struct TodayMealsBreakdownView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var foodService = FoodTrackingService.shared
    
    private var mealsByType: [FoodMealType: [FoodEntry]] {
        Dictionary(grouping: foodService.todaysFoods) { $0.mealType }
    }
    
    private var totalCalories: Double {
        foodService.todaysFoods.reduce(0) { $0 + $1.calories }
    }
    
    private var totalProtein: Double {
        foodService.todaysFoods.reduce(0) { $0 + $1.protein }
    }
    
    private var totalCarbs: Double {
        foodService.todaysFoods.reduce(0) { $0 + $1.carbs }
    }
    
    private var totalFat: Double {
        foodService.todaysFoods.reduce(0) { $0 + $1.fat }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(hex: "0F163E")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Summary Card
                        VStack(spacing: 16) {
                            Text("Today's Summary")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            // Total Nutrition
                            HStack(spacing: 0) {
                                NutritionSummaryBadge(
                                    value: "\(Int(totalCalories))",
                                    label: "Cal",
                                    icon: "flame.fill",
                                    color: Color(hex: "F7931F")
                                )
                                
                                Divider()
                                    .background(Color.white.opacity(0.2))
                                    .frame(height: 50)
                                
                                NutritionSummaryBadge(
                                    value: "\(Int(totalProtein))g",
                                    label: "Protein",
                                    icon: "dumbbell.fill",
                                    color: .blue
                                )
                                
                                Divider()
                                    .background(Color.white.opacity(0.2))
                                    .frame(height: 50)
                                
                                NutritionSummaryBadge(
                                    value: "\(Int(totalCarbs))g",
                                    label: "Carbs",
                                    icon: "leaf.fill",
                                    color: .green
                                )
                                
                                Divider()
                                    .background(Color.white.opacity(0.2))
                                    .frame(height: 50)
                                
                                NutritionSummaryBadge(
                                    value: "\(Int(totalFat))g",
                                    label: "Fat",
                                    icon: "drop.fill",
                                    color: .purple
                                )
                            }
                            
                            // Progress (if summary available)
                            if let summary = foodService.nutritionSummary {
                                VStack(spacing: 12) {
                                    ProgressBar(
                                        label: "Calories",
                                        current: totalCalories,
                                        goal: summary.calorieGoal,
                                        color: Color(hex: "F7931F")
                                    )
                                    
                                    ProgressBar(
                                        label: "Protein",
                                        current: totalProtein,
                                        goal: summary.proteinGoal,
                                        color: .blue
                                    )
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        
                        // Meals by Type
                        ForEach(FoodMealType.allCases, id: \.self) { mealType in
                            if let meals = mealsByType[mealType], !meals.isEmpty {
                                TodayMealsMealTypeSection(mealType: mealType, meals: meals)
                            }
                        }
                        
                        // Empty State
                        if foodService.todaysFoods.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.3))
                                
                                Text("No meals logged today")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text("Start logging your meals to see them here")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .padding(.vertical, 60)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Today's Meals")
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
}

// MARK: - Supporting Views

struct NutritionSummaryBadge: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProgressBar: View {
    let label: String
    let current: Double
    let goal: Double
    let color: Color
    
    private var progress: Double {
        min(current / goal, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text("\(Int(current)) / \(Int(goal))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    // Progress
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

struct TodayMealsMealTypeSection: View {
    let mealType: FoodMealType
    let meals: [FoodEntry]
    
    private var totalCalories: Double {
        meals.reduce(0) { $0 + $1.calories }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: mealType.icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "F7931F"))
                
                Text(mealType.rawValue)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(totalCalories)) cal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Meals List
            VStack(spacing: 12) {
                ForEach(meals) { meal in
                    MealRow(meal: meal)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct MealRow: View {
    let meal: FoodEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                HStack(spacing: 12) {
                    if meal.protein > 0 {
                        Text("P: \(Int(meal.protein))g")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    if meal.carbs > 0 {
                        Text("C: \(Int(meal.carbs))g")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    if meal.fat > 0 {
                        Text("F: \(Int(meal.fat))g")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            
            Spacer()
            
            Text("\(Int(meal.calories)) cal")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "F7931F"))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

