//
//  RestaurantMealLoggingView.swift
//  Do
//
//  Restaurant meal logging UI
//

import SwiftUI
import CoreLocation

struct RestaurantMealLoggingView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var restaurantService = RestaurantTrackingService.shared
    @StateObject private var locationManager = RestaurantLocationManager()
    
    @State private var restaurantName = ""
    @State private var menuItemName = ""
    @State private var selectedMealType: FoodMealType = .dinner
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var servingSize: String = ""
    @State private var price: String = ""
    @State private var rating: Int? = nil
    @State private var notes: String = ""
    
    @State private var isSearchingRestaurant = false
    @State private var isSearchingMenu = false
    @State private var showingNearbyRestaurants = false
    @State private var showingMenuSearch = false
    @State private var selectedRestaurant: RestaurantInfo? = nil
    @State private var selectedMenuItem: MenuItem? = nil
    
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    let onMealLogged: (() -> Void)?
    
    init(onMealLogged: (() -> Void)? = nil) {
        self.onMealLogged = onMealLogged
    }
    
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
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Log Restaurant Meal")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Track your dining out meals")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Quick Actions
                        VStack(spacing: 12) {
                            Button(action: {
                                showingNearbyRestaurants = true
                            }) {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 20))
                                    Text("Find Nearby Restaurants")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color.brandOrange,
                                            Color.brandOrange.opacity(0.8)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                            }
                            
                            if !restaurantName.isEmpty {
                                Button(action: {
                                    showingMenuSearch = true
                                }) {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 20))
                                        Text("Search Menu at \(restaurantName)")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Restaurant Info
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Restaurant Information")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            TextField("Restaurant Name", text: $restaurantName)
                                .textFieldStyle(ModernTextFieldStyle())
                            
                            if let restaurant = selectedRestaurant {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(restaurant.address)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    if let distance = restaurant.distance {
                                        Text("\(Int(distance))m away")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Menu Item
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Menu Item")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            TextField("Menu Item Name", text: $menuItemName)
                                .textFieldStyle(ModernTextFieldStyle())
                            
                            if let menuItem = selectedMenuItem {
                                MenuItemCard(item: menuItem) {
                                    selectedMenuItem = nil
                                    menuItemName = menuItem.name
                                    calories = String(format: "%.0f", menuItem.calories)
                                    protein = String(format: "%.1f", menuItem.protein)
                                    carbs = String(format: "%.1f", menuItem.carbs)
                                    fat = String(format: "%.1f", menuItem.fat)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Meal Type
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Meal Type")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                ForEach(FoodMealType.allCases, id: \.self) { type in
                                    Button(action: {
                                        selectedMealType = type
                                    }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: type.icon)
                                                .font(.system(size: 20))
                                            Text(type.rawValue)
                                                .font(.system(size: 12))
                                        }
                                        .foregroundColor(selectedMealType == type ? .white : .white.opacity(0.6))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(selectedMealType == type ? Color.brandOrange.opacity(0.3) : Color.white.opacity(0.05))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Nutrition Info
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Nutrition Information")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                RestaurantNutritionInputField(label: "Calories", value: $calories, placeholder: "0")
                                RestaurantNutritionInputField(label: "Protein (g)", value: $protein, placeholder: "0")
                            }
                            
                            HStack(spacing: 12) {
                                RestaurantNutritionInputField(label: "Carbs (g)", value: $carbs, placeholder: "0")
                                RestaurantNutritionInputField(label: "Fat (g)", value: $fat, placeholder: "0")
                            }
                            
                            TextField("Serving Size (optional)", text: $servingSize)
                                .textFieldStyle(ModernTextFieldStyle())
                        }
                        .padding(.horizontal)
                        
                        // Price & Rating
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                TextField("Price $ (optional)", text: $price)
                                    .textFieldStyle(ModernTextFieldStyle())
                                    .keyboardType(.decimalPad)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Rating")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    HStack(spacing: 4) {
                                        ForEach(1...5, id: \.self) { star in
                                            Button(action: {
                                                rating = star
                                            }) {
                                                Image(systemName: star <= (rating ?? 0) ? "star.fill" : "star")
                                                    .foregroundColor(star <= (rating ?? 0) ? Color.brandOrange : .white.opacity(0.3))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Notes
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Notes (optional)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            TextField("Add any notes about this meal...", text: $notes, axis: .vertical)
                                .textFieldStyle(ModernTextFieldStyle())
                                .lineLimit(3...6)
                        }
                        .padding(.horizontal)
                        
                        // Save Button
                        Button(action: saveMeal) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                }
                                Text(isLoading ? "Saving..." : "Save Meal")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color.brandOrange,
                                        Color.brandOrange.opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .disabled(isLoading || !isFormValid)
                            .opacity(isFormValid ? 1.0 : 0.5)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                    }
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
        .sheet(isPresented: $showingNearbyRestaurants) {
            NearbyRestaurantsView(
                onRestaurantSelected: { restaurant in
                    selectedRestaurant = restaurant
                    restaurantName = restaurant.name
                    showingNearbyRestaurants = false
                }
            )
        }
        .sheet(isPresented: $showingMenuSearch) {
            MenuSearchView(
                restaurantName: restaurantName,
                onMenuItemSelected: { item in
                    selectedMenuItem = item
                    showingMenuSearch = false
                }
            )
        }
    }
    
    private var isFormValid: Bool {
        !restaurantName.isEmpty &&
        !menuItemName.isEmpty &&
        !calories.isEmpty &&
        Double(calories) != nil
    }
    
    private func saveMeal() {
        guard let caloriesValue = Double(calories),
              let proteinValue = Double(protein.isEmpty ? "0" : protein),
              let carbsValue = Double(carbs.isEmpty ? "0" : carbs),
              let fatValue = Double(fat.isEmpty ? "0" : fat) else {
            errorMessage = "Please enter valid nutrition values"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let location: RestaurantLocation? = {
            if let restaurant = selectedRestaurant,
               let lat = restaurant.latitude,
               let lon = restaurant.longitude {
                return RestaurantLocation(
                    address: restaurant.address,
                    latitude: lat,
                    longitude: lon,
                    city: nil,
                    state: nil,
                    zipCode: nil
                )
            }
            return nil
        }()
        
        let priceValue = price.isEmpty ? nil : Double(price)
        
        Task {
            do {
                try await restaurantService.logRestaurantMeal(
                    restaurantName: restaurantName,
                    restaurantId: selectedRestaurant != nil ? "restaurant-\(UUID().uuidString)" : nil,
                    restaurantType: nil,
                    location: location,
                    menuItemName: menuItemName,
                    menuItemId: selectedMenuItem != nil ? "menu-\(UUID().uuidString)" : nil,
                    mealType: selectedMealType,
                    calories: caloriesValue,
                    protein: proteinValue,
                    carbs: carbsValue,
                    fat: fatValue,
                    servingSize: servingSize.isEmpty ? nil : servingSize,
                    price: priceValue,
                    rating: rating,
                    notes: notes.isEmpty ? nil : notes
                )
                
                await MainActor.run {
                    isLoading = false
                    onMealLogged?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to save meal: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .foregroundColor(.white)
    }
}

struct RestaurantNutritionInputField: View {
    let label: String
    @Binding var value: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            TextField(placeholder, text: $value)
                .keyboardType(.decimalPad)
                .textFieldStyle(ModernTextFieldStyle())
        }
    }
}

struct MenuItemCard: View {
    let item: MenuItem
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack(spacing: 12) {
                    Text("\(Int(item.calories)) cal")
                    Text("\(Int(item.protein))g protein")
                }
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Location Manager

class RestaurantLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        manager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}

