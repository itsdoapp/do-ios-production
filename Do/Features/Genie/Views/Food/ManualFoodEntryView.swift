//
//  ManualFoodEntryView.swift
//  Do
//
//  Manual food entry view for logging food items
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

struct ManualFoodEntryView: View {
    let mealType: FoodMealType
    let onFoodLogged: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var foodService = FoodTrackingService.shared
    
    @State private var foodName = ""
    @State private var calories: Double = 0
    @State private var protein: Double = 0
    @State private var carbs: Double = 0
    @State private var fat: Double = 0
    @State private var servingSize = ""
    @State private var notes = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(hex: "0F163E")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Meal Type Header
                        HStack {
                            Image(systemName: mealType.icon)
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: "F7931F"))
                            
                            Text(mealType.rawValue)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Food Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Food Name")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            
                            TextField("Enter food name", text: $foodName)
                                .textFieldStyle(ManualEntryTextFieldStyle())
                        }
                        .padding(.horizontal, 20)
                        
                        // Nutrition Info
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Nutrition Information")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            // Calories
                            ManualFoodNutritionInputField(
                                label: "Calories",
                                value: $calories,
                                icon: "flame.fill",
                                color: Color(hex: "F7931F")
                            )
                            
                            // Protein
                            ManualFoodNutritionInputField(
                                label: "Protein (g)",
                                value: $protein,
                                icon: "dumbbell.fill",
                                color: .blue
                            )
                            
                            // Carbs
                            ManualFoodNutritionInputField(
                                label: "Carbs (g)",
                                value: $carbs,
                                icon: "leaf.fill",
                                color: .green
                            )
                            
                            // Fat
                            ManualFoodNutritionInputField(
                                label: "Fat (g)",
                                value: $fat,
                                icon: "drop.fill",
                                color: .purple
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Serving Size
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Serving Size (optional)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            
                            TextField("e.g., 1 cup, 100g", text: $servingSize)
                                .textFieldStyle(ManualEntryTextFieldStyle())
                        }
                        .padding(.horizontal, 20)
                        
                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes (optional)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            
                            TextEditor(text: $notes)
                                .frame(height: 100)
                                .padding(12)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // Save Button
                        Button(action: {
                            saveFood()
                        }) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Log Food")
                                }
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "F7931F"),
                                        Color(hex: "FF6B35")
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color(hex: "F7931F").opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .disabled(isSaving || foodName.isEmpty || calories <= 0)
                        .opacity((foodName.isEmpty || calories <= 0) ? 0.5 : 1.0)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveFood() {
        guard !foodName.isEmpty, calories > 0 else { return }
        
        isSaving = true
        
        Task {
            do {
                try await foodService.logFood(
                    name: foodName,
                    mealType: mealType,
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    servingSize: servingSize.isEmpty ? nil : servingSize,
                    notes: notes.isEmpty ? nil : notes,
                    source: .manual
                )
                
                await MainActor.run {
                    isSaving = false
                    onFoodLogged()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ManualEntryTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

struct ManualFoodNutritionInputField: View {
    let label: String
    @Binding var value: Double
    let icon: String
    let color: Color
    
    @State private var textValue: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16))
                
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            TextField("0", text: $textValue)
                .keyboardType(.decimalPad)
                .textFieldStyle(ManualEntryTextFieldStyle())
                .onChange(of: textValue) { newValue in
                    value = Double(newValue) ?? 0
                }
                .onAppear {
                    textValue = value > 0 ? String(format: "%.1f", value) : ""
                }
        }
        .padding(.horizontal, 20)
    }
}

