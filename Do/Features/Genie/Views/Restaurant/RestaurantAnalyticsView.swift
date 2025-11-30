//
//  RestaurantAnalyticsView.swift
//  Do
//
//  Restaurant analytics dashboard
//

import SwiftUI
import Charts

struct RestaurantAnalyticsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var restaurantService = RestaurantTrackingService.shared
    
    @State private var analytics: RestaurantAnalytics?
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var selectedDays = 30
    
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
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                } else if let error = errorMessage {
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
                            loadAnalytics()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if let analytics = analytics {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Restaurant Analytics")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Last \(selectedDays) days")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top)
                            
                            // Time Period Selector
                            HStack(spacing: 12) {
                                ForEach([7, 30, 90], id: \.self) { days in
                                    Button(action: {
                                        selectedDays = days
                                        loadAnalytics()
                                    }) {
                                        Text("\(days)d")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(selectedDays == days ? .white : .white.opacity(0.6))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                selectedDays == days ?
                                                Color.brandOrange :
                                                Color.white.opacity(0.1)
                                            )
                                            .cornerRadius(20)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Summary Cards
                            VStack(spacing: 12) {
                                SummaryCard(
                                    title: "Total Meals",
                                    value: "\(analytics.summary.totalRestaurantMeals)",
                                    icon: "fork.knife",
                                    color: Color.brandOrange
                                )
                                
                                HStack(spacing: 12) {
                                    SummaryCard(
                                        title: "Avg Calories",
                                        value: "\(Int(analytics.summary.averageCaloriesPerMeal))",
                                        icon: "flame.fill",
                                        color: .orange
                                    )
                                    
                                    SummaryCard(
                                        title: "Total Spent",
                                        value: "$\(String(format: "%.0f", analytics.summary.totalSpent))",
                                        icon: "dollarsign.circle.fill",
                                        color: .green
                                    )
                                }
                                
                                if let rating = analytics.summary.averageRating {
                                    SummaryCard(
                                        title: "Avg Rating",
                                        value: String(format: "%.1f", rating),
                                        icon: "star.fill",
                                        color: Color.brandOrange
                                    )
                                }
                            }
                            .padding(.horizontal)
                            
                            // Top Restaurants
                            if !analytics.topRestaurants.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Top Restaurants")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                    
                                    ForEach(analytics.topRestaurants.prefix(5), id: \.name) { restaurant in
                                        TopRestaurantCard(restaurant: restaurant)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // Meal Type Distribution
                            if !analytics.mealTypeDistribution.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Meal Type Distribution")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                    
                                    VStack(spacing: 12) {
                                        ForEach(Array(analytics.mealTypeDistribution.keys.sorted()), id: \.self) { mealType in
                                            if let count = analytics.mealTypeDistribution[mealType] {
                                                MealTypeDistributionRow(
                                                    mealType: mealType.capitalized,
                                                    count: count,
                                                    total: analytics.summary.totalRestaurantMeals
                                                )
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            // Insights
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Insights")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                
                                RestaurantInsightCard(
                                    title: "Eating Out Frequency",
                                    message: "You've eaten out \(analytics.summary.totalRestaurantMeals) times in the last \(selectedDays) days. That's about \(String(format: "%.1f", Double(analytics.summary.totalRestaurantMeals) / Double(selectedDays))) times per day."
                                )
                                
                                if analytics.summary.averageCaloriesPerMeal > 600 {
                                    RestaurantInsightCard(
                                        title: "High Calorie Meals",
                                        message: "Your average restaurant meal has \(Int(analytics.summary.averageCaloriesPerMeal)) calories. Consider choosing lighter options or sharing meals.",
                                        type: .warning
                                    )
                                }
                                
                                if analytics.summary.totalSpent > 300 {
                                    RestaurantInsightCard(
                                        title: "Spending",
                                        message: "You've spent $\(String(format: "%.0f", analytics.summary.totalSpent)) on restaurant meals. Consider meal prepping to save money.",
                                        type: .info
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("No restaurant data yet")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Start logging restaurant meals to see analytics")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
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
                if analytics == nil {
                    loadAnalytics()
                }
            }
        }
    }
    
    private func loadAnalytics() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                await restaurantService.refreshAnalytics(days: selectedDays)
                
                await MainActor.run {
                    analytics = restaurantService.analytics
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load analytics: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

struct TopRestaurantCard: View {
    let restaurant: RestaurantAnalytics.TopRestaurant
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            ZStack {
                Circle()
                    .fill(Color.brandOrange.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text("#")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.brandOrange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("\(restaurant.count) visits • \(String(format: "%.0f", restaurant.percentage))%")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct MealTypeDistributionRow: View {
    let mealType: String
    let count: Int
    let total: Int
    
    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mealType)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(count) • \(String(format: "%.0f", percentage * 100))%")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.brandOrange,
                                    Color.brandOrange.opacity(0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct RestaurantInsightCard: View {
    let title: String
    let message: String
    let type: InsightType
    
    enum InsightType {
        case info
        case warning
        case success
    }
    
    init(title: String, message: String, type: InsightType = .info) {
        self.title = title
        self.message = message
        self.type = type
    }
    
    var icon: String {
        switch type {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }
    
    var color: Color {
        switch type {
        case .info: return .blue
        case .warning: return .orange
        case .success: return .green
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

