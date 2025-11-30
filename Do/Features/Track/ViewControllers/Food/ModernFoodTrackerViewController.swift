//
//  ModernFoodTrackerViewController.swift
//  Do.
//
//  Created by Mikiyas Meseret on 3/26/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//


import SwiftUI
import UIKit
import CoreLocation
import MapKit
import HealthKit
import Combine
import WatchConnectivity
import Foundation



// MARK: - Main ModernFoodTracker View Controller

class ModernFoodTrackerViewController: UIViewController, ObservableObject, CategorySwitchable {
    
    // MARK: - Properties
    private var hostingController: UIHostingController<FoodTrackerView>?
    private let foodTracker = FoodTrackingEngine.shared
    private var cancellables = Set<AnyCancellable>()
    
    weak var categoryDelegate: CategorySelectionDelegate?
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFoodTracker()
        setupHostingController()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: - Setup Methods
    private func setupFoodTracker() {
        // Initialize the food tracker and set up the current user
        if CurrentUserService.shared.user.userID == nil {
            foodTracker.setCurrentUser()
        } else {
            foodTracker.currentUser = CurrentUserService.shared.user
        }
    }
    
    private func setupHostingController() {
        let foodTrackerView = FoodTrackerView(viewModel: self)
        hostingController = UIHostingController(rootView: foodTrackerView)
        
        if let hostingController = hostingController {
            addChild(hostingController)
            view.addSubview(hostingController.view)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            hostingController.didMove(toParent: self)
        }
    }
    
    // MARK: - Public Methods
    public func handleCategorySelection(_ index: Int) {
        categoryDelegate?.didSelectCategory(at: index)
    }
}

// MARK: - Main SwiftUI View
struct FoodTrackerView: View {
    @ObservedObject var viewModel: ModernFoodTrackerViewController
    @StateObject private var foodTracker = FoodTrackingEngine.shared
    
    // State properties
    @State private var selectedMealType: MealType = .breakfast
    @State private var showingFoodSearch = false
    @State private var showingNutritionInfo = false
    @State private var showingCategorySelector = false
    @State private var selectedCategoryIndex: Int = 6 // Default to Food (index 6)
    @State private var showAIFoodLogger = false
    @State private var showingBarcodeScanner = false
    @State private var showingMealTemplates = false
    @State private var showingSavedRecipes = false
    @State private var showingRestaurantMealLogging = false
    @State private var showingRestaurantAnalytics = false
    @State private var showingFoodDetail = false
    @State private var selectedFoodEntry: FoodEntry?
    @State private var showingMealsBreakdown = false
    @StateObject private var visionService = GenieVisionService.shared
    @StateObject private var foodService = FoodTrackingService.shared
    @StateObject private var waterService = WaterIntakeService.shared
    @StateObject private var restaurantService = RestaurantTrackingService.shared
    weak var categoryDelegate: CategorySelectionDelegate?
    
    // Water intake animation states
    @State private var waterButtonScale: [Int: CGFloat] = [:]
    @State private var showWaterCelebration = false
    @State private var showWaterExceeded = false
    @State private var waterRippleEffect = false
    @State private var previousIntake: Double = 0
    @State private var lastAddedAmount: Double = 0
    // Category data
    private let categoryTitles = ["Running", "Gym", "Cycling", "Hiking", "Walking", "Swimming", "Food", "Meditation", "Sports"]
    private let categoryIcons = ["figure.run", "figure.strengthtraining.traditional", "figure.outdoor.cycle", "figure.hiking", "figure.walk", "figure.pool.swim", "fork.knife", "sparkles", "sportscourt"]
    
    var body: some View {
        ZStack {
            // Background gradient for food
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "0F163E"),
                    Color(hex: "1A2148")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Compact header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Food Tracker")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Track your nutrition")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        // Category Button
                        Button(action: {
                            showingCategorySelector = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Food")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
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
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Meal type selector - more compact
                    mealTypeSelector()
                        .padding(.horizontal, 20)
                    
                    // Combined Nutrition & Water Card
                    combinedStatsCard()
                        .padding(.horizontal, 20)
                    
                    // Primary AI Camera Button
                    Button(action: {
                        showAIFoodLogger = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Snap Food with Genie")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .opacity(0.6)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
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
                    
                    // Quick Add Grid - 2 rows, 3 columns
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Add")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ], spacing: 10) {
                            compactQuickAddButton(icon: "keyboard", title: "Manual") {
                                showingFoodSearch = true
                            }
                            
                            compactQuickAddButton(icon: "barcode.viewfinder", title: "Barcode") {
                                showingBarcodeScanner = true
                            }
                            
                            compactQuickAddButton(icon: "square.stack", title: "Templates") {
                                showingMealTemplates = true
                            }
                            
                            compactQuickAddButton(icon: "bookmark.fill", title: "Recipes") {
                                showingSavedRecipes = true
                            }
                            
                            compactQuickAddButton(icon: "fork.knife.circle.fill", title: "Restaurant") {
                                showingRestaurantMealLogging = true
                            }
                            
                            compactQuickAddButton(icon: "chart.bar.fill", title: "Analytics") {
                                showingRestaurantAnalytics = true
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Today's Meals - more compact
                    if !foodService.todaysFoods.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Today's Meals")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button {
                                    showingMealsBreakdown = true
                                } label: {
                                    Text("View All")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color(hex: "F7931F"))
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(foodService.todaysFoods.prefix(8)) { entry in
                                        Button {
                                            selectedFoodEntry = entry
                                            showingFoodDetail = true
                                        } label: {
                                            compactFoodLogCard(entry: entry)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .sheet(isPresented: $showingCategorySelector) {
            CategorySelectorView(
                isPresented: $showingCategorySelector,
                selectedCategory: Binding(
                    get: { self.selectedCategoryIndex },
                    set: { newIndex in
                        print("🎯 CategorySelectorView selected index: \(newIndex)")
                        // Directly update UI state
                        self.selectedCategoryIndex = newIndex
                        // Close the sheet first
                        self.showingCategorySelector = false
                        // Use a delay before triggering the navigation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            // Call the delegate directly for navigation
                            viewModel.categoryDelegate?.didSelectCategory(at: newIndex)
                        }
                    }
                ),
                categories: Array(zip(categoryTitles, categoryIcons)).map { ($0.0, $0.1) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showAIFoodLogger) {
            FoodCameraView(
                onFoodLogged: {
                    Task {
                        await foodService.updateNutritionSummary()
                    }
                }
            )
        }
        .sheet(isPresented: $showingFoodSearch) {
            ManualFoodEntryView(mealType: mapMealType(selectedMealType)) {
                Task {
                    await foodService.updateNutritionSummary()
                }
            }
        }
        .sheet(isPresented: $showingBarcodeScanner) {
            BarcodeScannerView(
                mealType: mapMealType(selectedMealType),
                onFoodFound: { _ in
                    Task {
                        await foodService.updateNutritionSummary()
                    }
                }
            )
        }
        .sheet(isPresented: $showingMealTemplates) {
            MealTemplatesView { template in
                Task {
                    await foodService.updateNutritionSummary()
                }
            }
        }
        .sheet(isPresented: $showingSavedRecipes) {
            SavedRecipesView()
        }
        .sheet(isPresented: $showingRestaurantMealLogging) {
            RestaurantMealLoggingView {
                Task {
                    await foodService.updateNutritionSummary()
                }
            }
        }
        .sheet(item: $selectedFoodEntry) { entry in
            FoodDetailView(entry: entry)
        }
        .sheet(isPresented: $showingMealsBreakdown) {
            TodayMealsBreakdownView()
        }
        .sheet(isPresented: $showingRestaurantAnalytics) {
            RestaurantAnalyticsView()
        }
    }
    
    // MARK: - AI Food Logger Handlers
    
    private func analyzeFood(_ image: UIImage) {
        Task {
            do {
                guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
                let base64 = imageData.base64EncodedString()
                
                // Send to Genie for analysis
                let response = try await GenieAPIService.shared.queryWithImage(
                    "Analyze this food. Provide: food items, total calories, protein (g), carbs (g), fat (g), and nutritional insights.",
                    imageBase64: base64
                )
                
                // Log food and update learning
                logFood(analysis: response.response, image: image)
                
            } catch {
                print("Error analyzing food: \(error)")
            }
        }
    }
    
    private func logFood(analysis: String, image: UIImage) {
        // Save food log
        let foodLog: [String: Any] = [
            "userId": getCurrentUserId(),
            "analysis": analysis,
            "date": ISO8601DateFormatter().string(from: Date()),
            "mealType": selectedMealType.rawValue,
            "aiGenerated": true
        ]
        
        // Update user learning data
        Task {
            await GenieUserLearningService.shared.updateUserLearning(
                activity: "food",
                data: foodLog
            )
        }
        
        print("✅ Food logged: \(analysis)")
    }
    
    private func getCurrentUserId() -> String {
        return CurrentUserService.shared.user.userID ?? ""
    }
    
    private func mealTypeSelector() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MealType.allCases, id: \.self) { type in
                    mealTypeButton(type)
                }
            }
        }
    }
    
    private func mealTypeButton(_ type: MealType) -> some View {
        Button(action: {
            selectedMealType = type
        }) {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(selectedMealType == type ? .white : .white.opacity(0.5))
                
                Text(type.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(selectedMealType == type ? .white : .white.opacity(0.5))
            }
            .frame(width: 70, height: 70)
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
    
    private func compactQuickAddButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private func combinedStatsCard() -> some View {
        VStack(spacing: 16) {
            // Nutrition Summary - Compact
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's Nutrition")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                if let summary = foodService.nutritionSummary {
                    HStack(spacing: 0) {
                        compactNutritionMetric(
                            value: "\(Int(summary.totalCalories))",
                            label: "Cal",
                            icon: "flame.fill",
                            color: Color(hex: "F7931F")
                        )
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .frame(height: 40)
                        
                        compactNutritionMetric(
                            value: "\(Int(summary.totalProtein))g",
                            label: "Protein",
                            icon: "dumbbell.fill",
                            color: Color.blue
                        )
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .frame(height: 40)
                        
                        compactNutritionMetric(
                            value: "\(Int(summary.totalCarbs))g",
                            label: "Carbs",
                            icon: "leaf.fill",
                            color: Color.green
                        )
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .frame(height: 40)
                        
                        compactNutritionMetric(
                            value: "\(Int(summary.totalFat))g",
                            label: "Fat",
                            icon: "drop.fill",
                            color: Color.purple
                        )
                    }
                } else {
                    HStack(spacing: 0) {
                        compactNutritionMetric(value: "0", label: "Cal", icon: "flame.fill", color: Color(hex: "F7931F"))
                        Divider().background(Color.white.opacity(0.2)).frame(height: 40)
                        compactNutritionMetric(value: "0g", label: "Protein", icon: "dumbbell.fill", color: Color.blue)
                        Divider().background(Color.white.opacity(0.2)).frame(height: 40)
                        compactNutritionMetric(value: "0g", label: "Carbs", icon: "leaf.fill", color: Color.green)
                        Divider().background(Color.white.opacity(0.2)).frame(height: 40)
                        compactNutritionMetric(value: "0g", label: "Fat", icon: "drop.fill", color: Color.purple)
                    }
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
            
            // Water Intake - Enhanced with Animations
            ZStack {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Water Intake")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Animated intake display
                        HStack(spacing: 4) {
                            Text("\(Int(waterService.todayIntake))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(waterService.todayIntake >= waterService.dailyGoal ? Color.green : .white)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: waterService.todayIntake)
                            
                            Text("oz")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("/")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text("\(Int(waterService.dailyGoal))oz")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    // Enhanced progress bar with animation
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 8)
                            
                            // Progress fill with gradient
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: getWaterProgressColors(),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * min(waterService.getProgress(), 1.0), height: 8)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: waterService.todayIntake)
                                .overlay(
                                    // Ripple effect when water is added
                                    Circle()
                                        .fill(Color.white.opacity(0.3))
                                        .frame(width: waterRippleEffect ? 100 : 0, height: waterRippleEffect ? 100 : 0)
                                        .opacity(waterRippleEffect ? 0 : 1)
                                        .offset(x: geometry.size.width * min(waterService.getProgress(), 1.0))
                                        .animation(.easeOut(duration: 0.6), value: waterRippleEffect)
                                )
                            
                            // Goal marker
                            if waterService.todayIntake < waterService.dailyGoal {
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 4, height: 8)
                                    .offset(x: geometry.size.width - 2)
                            }
                        }
                    }
                    .frame(height: 8)
                    
                    // Completion/Exceeded message
                    if waterService.todayIntake >= waterService.dailyGoal {
                        HStack(spacing: 6) {
                            Image(systemName: waterService.todayIntake > waterService.dailyGoal ? "sparkles" : "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(waterService.todayIntake > waterService.dailyGoal ? Color.yellow : Color.green)
                                .scaleEffect(showWaterCelebration || showWaterExceeded ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6).repeatCount(3, autoreverses: true), value: showWaterCelebration || showWaterExceeded)
                            
                            Text(getWaterMessage())
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(waterService.todayIntake > waterService.dailyGoal ? Color.yellow : Color.green)
                        }
                        .transition(.opacity.combined(with: .scale))
                    }
                    
                    // Compact water buttons - 2 rows with animations
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            animatedWaterButton(amount: 8, label: "8oz", key: 8) {
                                await addWaterWithAnimation(amount: 8)
                            }
                            animatedWaterButton(amount: 16, label: "16oz", key: 16) {
                                await addWaterWithAnimation(amount: 16)
                            }
                        }
                        HStack(spacing: 8) {
                            animatedWaterButton(amount: 17, label: "500ml", key: 17) {
                                await addWaterWithAnimation(amount: 17)
                            }
                            animatedWaterButton(amount: 34, label: "1L", key: 34) {
                                await addWaterWithAnimation(amount: 34)
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            // Celebration glow effect
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: waterService.todayIntake >= waterService.dailyGoal ? 
                                            [Color.green.opacity(0.5), Color.cyan.opacity(0.3)] :
                                            [Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: waterService.todayIntake >= waterService.dailyGoal ? 2 : 0
                                )
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: showWaterCelebration || showWaterExceeded)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                // Celebration overlay
                if showWaterCelebration || showWaterExceeded {
                    WaterCelebrationOverlay(
                        isExceeded: showWaterExceeded,
                        message: getWaterMessage()
                    )
                }
            }
            .onAppear {
                previousIntake = waterService.todayIntake
            }
            .onChange(of: waterService.todayIntake) { newValue in
                handleWaterIntakeChange(newValue: newValue)
            }
        }
        .onAppear {
            Task {
                await foodService.updateNutritionSummary()
            }
        }
    }
    
    private func compactNutritionMetric(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
    
    private func mapMealType(_ mealType: MealType) -> FoodMealType {
        switch mealType {
        case .breakfast: return .breakfast
        case .lunch: return .lunch
        case .dinner: return .dinner
        case .snack: return .snack
        }
    }
    
    private func compactFoodLogCard(entry: FoodEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: entry.mealType.icon)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "F7931F"))
                
                Text(entry.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            Text("\(Int(entry.calories)) cal")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(10)
        .frame(width: 130)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - Water Intake Animations & Helpers
    
    private func addWaterWithAnimation(amount: Double) async {
        // Trigger button animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            waterButtonScale[Int(amount)] = 0.9
        }
        
        // Add water
        lastAddedAmount = amount
        previousIntake = waterService.todayIntake
        await waterService.addWater(amount: amount)
        
        // Reset button animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                waterButtonScale[Int(amount)] = 1.0
            }
        }
        
        // Trigger ripple effect
        withAnimation(.easeOut(duration: 0.6)) {
            waterRippleEffect = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            waterRippleEffect = false
        }
    }
    
    private func handleWaterIntakeChange(newValue: Double) {
        // Check if goal was reached
        if previousIntake < waterService.dailyGoal && newValue >= waterService.dailyGoal {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showWaterCelebration = true
            }
            
            // Hide celebration after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation {
                    showWaterCelebration = false
                }
            }
        }
        
        // Check if goal was exceeded
        if previousIntake <= waterService.dailyGoal && newValue > waterService.dailyGoal {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showWaterExceeded = true
            }
            
            // Hide exceeded message after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation {
                    showWaterExceeded = false
                }
            }
        }
        
        previousIntake = newValue
    }
    
    private func getWaterProgressColors() -> [Color] {
        if waterService.todayIntake >= waterService.dailyGoal {
            return [Color.green, Color.cyan, Color.blue]
        } else if waterService.todayIntake >= waterService.dailyGoal * 0.75 {
            return [Color.blue, Color.cyan]
        } else {
            return [Color.blue, Color.cyan]
        }
    }
    
    private func getWaterMessage() -> String {
        if waterService.todayIntake > waterService.dailyGoal {
            let excess = waterService.todayIntake - waterService.dailyGoal
            if excess > 16 {
                return "Hydration Master! You're \(Int(excess))oz over your goal! 💧✨"
            } else {
                return "Great job! You've exceeded your daily goal! 🌊"
            }
        } else if waterService.todayIntake >= waterService.dailyGoal {
            return "Daily goal achieved! You're well hydrated! 💧"
        } else {
            return ""
        }
    }
    
    private func animatedWaterButton(amount: Int, label: String, key: Int, action: @escaping () async -> Void) -> some View {
        Button(action: {
            Task {
                await action()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 12, weight: .medium))
                    .scaleEffect(waterButtonScale[key] ?? 1.0)
                
                Text("+\(amount)")
                    .font(.system(size: 13, weight: .semibold))
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.8)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.25),
                            Color.cyan.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Ripple effect overlay
                    if waterButtonScale[key] == 0.9 {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 200, height: 200)
                            .scaleEffect(waterButtonScale[key] ?? 1.0)
                            .opacity(0)
                            .animation(.easeOut(duration: 0.4), value: waterButtonScale[key])
                    }
                }
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(waterButtonScale[key] ?? 1.0)
        }
    }
    
    private func compactWaterButton(amount: Int, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 12, weight: .medium))
                Text("+\(amount)")
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.8)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.25),
                        Color.cyan.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
}

// MARK: - Water Celebration Overlay

struct WaterCelebrationOverlay: View {
    let isExceeded: Bool
    let message: String
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Animated icon
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    isExceeded ? Color.yellow.opacity(0.6) : Color.green.opacity(0.6),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(scale)
                        .opacity(opacity)
                    
                    // Main icon
                    Image(systemName: isExceeded ? "sparkles" : "checkmark.circle.fill")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(isExceeded ? .yellow : .green)
                        .scaleEffect(scale)
                        .rotationEffect(.degrees(rotation))
                        .shadow(color: (isExceeded ? Color.yellow : Color.green).opacity(0.8), radius: 20, x: 0, y: 0)
                    
                    // Particle effects
                    ForEach(0..<8) { index in
                        Circle()
                            .fill(isExceeded ? Color.yellow : Color.green)
                            .frame(width: 8, height: 8)
                            .offset(x: cos(Double(index) * .pi / 4) * 60, y: sin(Double(index) * .pi / 4) * 60)
                            .scaleEffect(scale)
                            .opacity(opacity * 0.8)
                    }
                }
                
                // Message
                Text(message)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .opacity(opacity)
                    .scaleEffect(scale)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

struct FoodLogCard: View {
    let entry: FoodEntry
    @StateObject private var foodService = FoodTrackingService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: entry.mealType.icon)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Text(entry.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            Text("\(Int(entry.calories)) cal")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding(12)
        .frame(width: 140)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}


// MARK: - Food Tracking Engine
class FoodTrackingEngine: ObservableObject {
    static let shared = FoodTrackingEngine()
    
    @Published var isTracking = false
    @Published var currentUser: UserModel?
    
    private init() {}
    
    func setCurrentUser() {
        // Use CurrentUserService instead of Parse
        if CurrentUserService.shared.user.userID != nil {
            self.currentUser = CurrentUserService.shared.user
        } else {
            // If user not loaded, try to load from UserIDHelper
            if let userId = UserIDHelper.shared.getCurrentUserID() {
                Task {
                    // Try to fetch user profile from AWS
                    if let userProfile = try? await UserProfileService.shared.fetchUserProfile(userId: userId) {
                        await MainActor.run {
                            self.currentUser = userProfile
                        }
                    } else {
                        // Fallback to CurrentUserService
                        await MainActor.run {
                            self.currentUser = CurrentUserService.shared.user
                        }
                    }
                }
            }
        }
    }
    
    func startTracking() {
        isTracking = true
        // Initialize tracking session
    }
    
    private func getImageFromURL(from input: String) async -> UIImage? {
        var image: UIImage? = nil
        let incomingString = input
        if (incomingString != "") {
            guard let url = URL(string: incomingString) else {
                print("Unable to create URL")
                return nil
            }
            
            do {
                let data = try Data(contentsOf: url, options: [])
                image = UIImage(data: data)
            } catch {
                print(error.localizedDescription)
            }
        }
        return image
    }
} 
