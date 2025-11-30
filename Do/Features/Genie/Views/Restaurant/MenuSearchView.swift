//
//  MenuSearchView.swift
//  Do
//
//  Menu search interface
//

import SwiftUI

struct MenuSearchView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var restaurantService = RestaurantTrackingService.shared
    
    let restaurantName: String
    let onMenuItemSelected: (MenuItem) -> Void
    
    @State private var menuItems: [MenuItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var searchQuery = ""
    @State private var dietaryPreferences: [String] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color.brandBlue,
                        Color("1A2148")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(restaurantName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Menu Items")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.6))
                        
                        TextField("Search menu items...", text: $searchQuery)
                            .foregroundColor(.white)
                            .onSubmit {
                                searchMenu()
                            }
                        
                        if !searchQuery.isEmpty {
                            Button(action: {
                                searchQuery = ""
                                searchMenu()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Dietary Preferences
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["Healthy", "Low Calorie", "High Protein", "Vegetarian", "Vegan"], id: \.self) { pref in
                                Button(action: {
                                    if dietaryPreferences.contains(pref) {
                                        dietaryPreferences.removeAll { $0 == pref }
                                    } else {
                                        dietaryPreferences.append(pref)
                                    }
                                    searchMenu()
                                }) {
                                    Text(pref)
                                        .font(.system(size: 14))
                                        .foregroundColor(dietaryPreferences.contains(pref) ? .white : .white.opacity(0.7))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            dietaryPreferences.contains(pref) ?
                                            Color.brandOrange :
                                            Color.white.opacity(0.1)
                                        )
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                    
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                        Spacer()
                    } else if let error = errorMessage {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.red.opacity(0.7))
                            
                            Text(error)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button("Try Again") {
                                searchMenu()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Spacer()
                    } else if menuItems.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text("No menu items found")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Try searching for a specific item or cuisine")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(Array(menuItems.enumerated()), id: \.offset) { index, item in
                                    MenuItemDetailCard(item: item) {
                                        onMenuItemSelected(item)
                                        dismiss()
                                    }
                                }
                            }
                            .padding()
                        }
                    }
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
            .onAppear {
                if menuItems.isEmpty {
                    searchMenu()
                }
            }
        }
    }
    
    private func searchMenu() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let items = try await restaurantService.searchRestaurantMenu(
                    restaurantName: restaurantName,
                    query: searchQuery.isEmpty ? nil : searchQuery,
                    dietaryPreferences: dietaryPreferences
                )
                
                await MainActor.run {
                    menuItems = items
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to search menu: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

struct MenuItemDetailCard: View {
    let item: MenuItem
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(item.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if let price = item.price {
                        Text("$\(String(format: "%.2f", price))")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.brandOrange)
                    }
                }
                
                // Nutrition Info
                HStack(spacing: 16) {
                    MenuNutritionBadge(label: "Cal", value: Int(item.calories))
                    MenuNutritionBadge(label: "P", value: Int(item.protein), unit: "g")
                    MenuNutritionBadge(label: "C", value: Int(item.carbs), unit: "g")
                    MenuNutritionBadge(label: "F", value: Int(item.fat), unit: "g")
                }
                
                // Healthiness Score
                if let score = item.healthinessScore {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(score > 0.7 ? .green : score > 0.4 ? .yellow : .red)
                            .font(.system(size: 12))
                        
                        Text("Healthiness: \(Int(score * 100))%")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }
}

struct MenuNutritionBadge: View {
    let label: String
    let value: Int
    let unit: String
    
    init(label: String, value: Int, unit: String = "") {
        self.label = label
        self.value = value
        self.unit = unit
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
            Text("\(value)\(unit)")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white.opacity(0.8))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
}

