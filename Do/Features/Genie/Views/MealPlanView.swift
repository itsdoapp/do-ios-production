//
//  MealPlanView.swift
//  Do
//
//  Display meal plans created by Genie
//

import SwiftUI
import Foundation

struct MealPlanView: View {
    let mealPlan: MealPlanAction
    @Environment(\.dismiss) private var dismiss
    @StateObject private var foodTrackingService = FoodTrackingService.shared
    @State private var selectedDay: Int = 0
    @State private var showingSaveConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.brandBlue
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Meal Plan")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("\(mealPlan.duration) day plan")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        
                        // Meal plan display
                        if let plan = mealPlan.plan, !plan.meals.isEmpty {
                            mealPlanContent(plan)
                        } else {
                            // Fallback to text
                            VStack(alignment: .leading, spacing: 12) {
                                Text(mealPlan.planText)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Action buttons
                        actionButtons
                    }
                    .padding(.vertical)
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
        }
        .alert("Meal Plan Saved", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The meal plan has been saved to your food tracker.")
        }
    }
    
    @ViewBuilder
    private func mealPlanContent(_ plan: MealPlanData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(plan.meals.enumerated()), id: \.offset) { index, meal in
                MealCard(meal: meal)
            }
        }
        .padding(.horizontal)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: saveMealPlan) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save to Food Tracker")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.brandOrange, Color("FF6B35")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
    
    private func saveMealPlan() {
        guard let plan = mealPlan.plan else { return }
        
        Task {
            // Save meal plan using MealPlanTrackingService
            // This will save to prod-nutrition table with entryType: "meal_plan"
            do {
                try await MealPlanTrackingService.shared.saveMealPlan(
                    planName: "Genie Meal Plan - \(mealPlan.duration) days",
                    duration: mealPlan.duration,
                    startDate: Date(),
                    meals: plan.meals,
                    planText: mealPlan.planText
                )
                
                await MainActor.run {
                    showingSaveConfirmation = true
                }
            } catch {
                print("❌ [MealPlan] Error saving meal plan: \(error)")
                
                // Fallback: save individual meals
                for meal in plan.meals {
                    let mealType = FoodMealType(rawValue: meal.mealType) ?? .breakfast
                    
                    do {
                        try await foodTrackingService.logFood(
                            name: meal.name,
                            mealType: mealType,
                            calories: meal.calories,
                            protein: meal.protein,
                            carbs: meal.carbs,
                            fat: meal.fat,
                            notes: "From Genie meal plan"
                        )
                    } catch {
                        print("❌ [MealPlan] Error saving meal \(meal.name): \(error)")
                    }
                }
                
                await MainActor.run {
                    showingSaveConfirmation = true
                }
            }
        }
    }
}

struct MealCard: View {
    let meal: MealPlanMeal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: mealTypeIcon)
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                
                Text(meal.mealType.capitalized)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            Text(meal.name)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.9))
            
            // Nutrition info
            HStack(spacing: 16) {
                NutritionBadge(label: "Cal", value: Int(meal.calories))
                NutritionBadge(label: "P", value: Int(meal.protein), unit: "g")
                NutritionBadge(label: "C", value: Int(meal.carbs), unit: "g")
                NutritionBadge(label: "F", value: Int(meal.fat), unit: "g")
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var mealTypeIcon: String {
        switch meal.mealType.lowercased() {
        case "breakfast": return "sunrise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.stars.fill"
        case "snack": return "leaf.fill"
        default: return "fork.knife"
        }
    }
}


