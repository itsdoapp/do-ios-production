//
//  EnhancedMealPlanView.swift
//  Do
//
//  Impressive modern meal plan view
//

import SwiftUI
import Foundation

struct EnhancedMealPlanView: View {
    let mealPlan: MealPlanAction
    @Environment(\.dismiss) private var dismiss
    @StateObject private var foodTrackingService = FoodTrackingService.shared
    @State private var selectedDay: Int = 0
    @State private var showingSaveConfirmation = false
    @State private var showingGroceryList = false
    @State private var generatedGroceryList: GroceryList? = nil
    @State private var isSaving = false
    
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
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Hero header
                        heroHeader
                            .padding(.horizontal)
                            .padding(.top)
                        
                        // Quick stats
                        quickStats
                            .padding(.horizontal)
                        
                        // Day selector
                        if mealPlan.duration > 1 {
                            daySelector
                                .padding(.horizontal)
                        }
                        
                        // Meal plan content
                        if let plan = mealPlan.plan, !plan.meals.isEmpty {
                            mealPlanContent(plan)
                                .padding(.horizontal)
                        } else {
                            // Fallback to text
                            textPlanView
                                .padding(.horizontal)
                        }
                        
                        // Action buttons
                        actionButtons
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Meal Plan Saved", isPresented: $showingSaveConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The meal plan has been saved to your food tracker.")
            }
            .sheet(isPresented: $showingGroceryList) {
                if let list = generatedGroceryList {
                    GroceryListView(groceryList: list)
                }
            }
        }
    }
    
    // MARK: - Hero Header
    
    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Meal Plan")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(mealPlan.duration) day plan")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Plan badge
                ZStack {
                    Circle()
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
                        .frame(width: 80, height: 80)
                    
                    VStack(spacing: 4) {
                        Text("\(mealPlan.duration)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        Text("days")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Stats
    
    private var quickStats: some View {
        HStack(spacing: 12) {
            if let plan = mealPlan.plan {
                MealPlanStatCard(
                    icon: "fork.knife",
                    value: "\(plan.meals.count)",
                    label: "Meals",
                    color: Color.brandOrange
                )
                
                MealPlanStatCard(
                    icon: "flame.fill",
                    value: "\(Int(totalCalories(plan)))",
                    label: "Total Cal",
                    color: .orange
                )
                
                MealPlanStatCard(
                    icon: "chart.pie.fill",
                    value: "\(Int(totalProtein(plan)))g",
                    label: "Protein",
                    color: .blue
                )
            }
        }
    }
    
    // MARK: - Day Selector
    
    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<mealPlan.duration, id: \.self) { day in
                    DayButton(
                        day: day + 1,
                        isSelected: selectedDay == day
                    ) {
                        selectedDay = day
                    }
                }
            }
        }
    }
    
    // MARK: - Meal Plan Content
    
    @ViewBuilder
    private func mealPlanContent(_ plan: MealPlanData) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Group meals by meal type
            let mealsByType = Dictionary(grouping: plan.meals) { $0.mealType }
            
            ForEach(Array(mealsByType.keys.sorted(by: mealTypeOrder)), id: \.self) { mealType in
                if let meals = mealsByType[mealType] {
                    MealPlanMealTypeSection(
                        mealType: mealType,
                        meals: meals
                    )
                }
            }
        }
    }
    
    private func mealTypeOrder(_ type1: String, _ type2: String) -> Bool {
        let order = ["breakfast", "lunch", "dinner", "snack"]
        let index1 = order.firstIndex(of: type1.lowercased()) ?? 999
        let index2 = order.firstIndex(of: type2.lowercased()) ?? 999
        return index1 < index2
    }
    
    // MARK: - Text Plan View
    
    private var textPlanView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(mealPlan.planText)
                .foregroundColor(.white)
                .padding()
                .background(Color(white: 1.0, opacity: 0.1))
                .cornerRadius(12)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Save button
            Button(action: saveMealPlan) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                    }
                    Text(isSaving ? "Saving..." : "Save to Food Tracker")
                        .font(.system(size: 18, weight: .semibold))
                }
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
                .cornerRadius(16)
                .disabled(isSaving)
            }
            
            // Grocery list button
            if let plan = mealPlan.plan, !plan.meals.isEmpty {
                Button(action: {
                    generateGroceryList()
                }) {
                    HStack {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 20))
                        Text("Generate Grocery List")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(white: 1.0, opacity: 0.1))
                    .cornerRadius(16)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func totalCalories(_ plan: MealPlanData) -> Double {
        plan.meals.reduce(0) { $0 + $1.calories }
    }
    
    private func totalProtein(_ plan: MealPlanData) -> Double {
        plan.meals.reduce(0) { $0 + $1.protein }
    }
    
    private func saveMealPlan() {
        guard let plan = mealPlan.plan else { return }
        
        isSaving = true
        
        Task {
            // Save meal plan using MealPlanTrackingService
            do {
                try await MealPlanTrackingService.shared.saveMealPlan(
                    planName: "Genie Meal Plan - \(mealPlan.duration) days",
                    duration: mealPlan.duration,
                    startDate: Date(),
                    meals: plan.meals,
                    planText: mealPlan.planText
                )
                
                await MainActor.run {
                    isSaving = false
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
                    isSaving = false
                    showingSaveConfirmation = true
                }
            }
        }
    }
    
    private func generateGroceryList() {
        guard let plan = mealPlan.plan else { return }
        
        // Generate grocery list from meal plan
        if let groceryList = GroceryListService.shared.generateGroceryList(from: mealPlan) {
            generatedGroceryList = groceryList
            showingGroceryList = true
        }
    }
}

// MARK: - Supporting Views

struct MealPlanStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

struct DayButton: View {
    let day: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Day \(day)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ?
                    Color.brandOrange :
                    Color(white: 1.0, opacity: 0.1)
                )
                .cornerRadius(20)
        }
    }
}

struct MealPlanMealTypeSection: View {
    let mealType: String
    let meals: [MealPlanMeal]
    
    var mealTypeIcon: String {
        switch mealType.lowercased() {
        case "breakfast": return "sunrise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.stars.fill"
        case "snack": return "leaf.fill"
        default: return "fork.knife"
        }
    }
    
    var mealTypeColor: Color {
        switch mealType.lowercased() {
        case "breakfast": return .orange
        case "lunch": return .yellow
        case "dinner": return .purple
        case "snack": return .green
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: mealTypeIcon)
                    .font(.system(size: 20))
                    .foregroundColor(mealTypeColor)
                
                Text(mealType.capitalized)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(meals.count) meal\(meals.count > 1 ? "s" : "")")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            VStack(spacing: 12) {
                ForEach(Array(meals.enumerated()), id: \.offset) { index, meal in
                    EnhancedMealCard(meal: meal, index: index + 1)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(mealTypeColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct EnhancedMealCard: View {
    let meal: MealPlanMeal
    let index: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Number badge
            ZStack {
                Circle()
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
                
                Text("\(index)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Meal info
            VStack(alignment: .leading, spacing: 8) {
                Text(meal.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                // Nutrition badges
                HStack(spacing: 8) {
                    NutritionBadge(label: "Cal", value: Int(meal.calories))
                    NutritionBadge(label: "P", value: Int(meal.protein), unit: "g")
                    NutritionBadge(label: "C", value: Int(meal.carbs), unit: "g")
                    NutritionBadge(label: "F", value: Int(meal.fat), unit: "g")
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}


