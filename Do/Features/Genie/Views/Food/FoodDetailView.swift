//
//  FoodDetailView.swift
//  Do
//
//  Detail view for a food entry
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

struct FoodDetailView: View {
    let entry: FoodEntry
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var foodService = FoodTrackingService.shared
    
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(hex: "0F163E")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: entry.mealType.icon)
                                    .font(.system(size: 28))
                                    .foregroundColor(Color(hex: "F7931F"))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.name)
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text(entry.mealType.rawValue)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                
                                Spacer()
                            }
                            
                            // Timestamp
                            HStack {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Text(formatTimestamp(entry.timestamp))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
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
                        
                        // Nutrition Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Nutrition Information")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            VStack(spacing: 12) {
                                NutritionDetailRow(
                                    label: "Calories",
                                    value: "\(Int(entry.calories))",
                                    icon: "flame.fill",
                                    color: Color(hex: "F7931F")
                                )
                                
                                NutritionDetailRow(
                                    label: "Protein",
                                    value: "\(Int(entry.protein))g",
                                    icon: "dumbbell.fill",
                                    color: .blue
                                )
                                
                                NutritionDetailRow(
                                    label: "Carbs",
                                    value: "\(Int(entry.carbs))g",
                                    icon: "leaf.fill",
                                    color: .green
                                )
                                
                                NutritionDetailRow(
                                    label: "Fat",
                                    value: "\(Int(entry.fat))g",
                                    icon: "drop.fill",
                                    color: .purple
                                )
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
                        
                        // Additional Info
                        if let servingSize = entry.servingSize, !servingSize.isEmpty {
                            InfoRow(label: "Serving Size", value: servingSize)
                        }
                        
                        if let notes = entry.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text(notes)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
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
                        
                        // Source Badge
                        HStack {
                            Image(systemName: sourceIcon(entry.source))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("Logged via \(entry.source.rawValue.capitalized)")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 20)
                        
                        // Delete Button
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Entry")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.red.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Food Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Delete Food Entry", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteEntry()
                }
            } message: {
                Text("Are you sure you want to delete this food entry? This action cannot be undone.")
            }
            .overlay {
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            Text("Deleting...")
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
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func sourceIcon(_ source: FoodSource) -> String {
        switch source {
        case .manual: return "keyboard"
        case .ai: return "sparkles"
        case .barcode: return "barcode.viewfinder"
        }
    }
    
    private func deleteEntry() {
        isDeleting = true
        
        Task {
            // Remove from local storage
            await MainActor.run {
                foodService.todaysFoods.removeAll { $0.id == entry.id }
            }
            
            // TODO: Delete from DynamoDB if needed
            // await foodService.deleteFoodEntry(entry.id)
            
            await MainActor.run {
                isDeleting = false
                dismiss()
            }
        }
    }
}

// MARK: - Supporting Views

struct NutritionDetailRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 18))
                .frame(width: 30)
            
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
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



