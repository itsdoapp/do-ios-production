//
//  RestaurantTrackingService.swift
//  Do
//
//  Restaurant meal tracking service
//

import Foundation
import CoreLocation

@MainActor
class RestaurantTrackingService: ObservableObject {
    static let shared = RestaurantTrackingService()
    
    @Published var restaurantMeals: [RestaurantEntry] = []
    @Published var analytics: RestaurantAnalytics?
    @Published var isLoading = false
    
    private init() {}
    
    // MARK: - Restaurant Meal Logging
    
    func logRestaurantMeal(
        restaurantName: String,
        restaurantId: String? = nil,
        restaurantType: RestaurantType? = nil,
        location: RestaurantLocation? = nil,
        menuItemName: String,
        menuItemId: String? = nil,
        mealType: FoodMealType,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        servingSize: String? = nil,
        price: Double? = nil,
        rating: Int? = nil,
        notes: String? = nil,
        alternatives: [HealthierAlternative]? = nil,
        homeRecipeSuggestion: HomeRecipeSuggestion? = nil
    ) async throws {
        let entry = RestaurantEntry(
            id: UUID().uuidString,
            restaurantName: restaurantName,
            restaurantId: restaurantId,
            restaurantType: restaurantType,
            location: location,
            menuItemName: menuItemName,
            menuItemId: menuItemId,
            mealType: mealType,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            servingSize: servingSize,
            price: price,
            rating: rating,
            notes: notes,
            timestamp: Date(),
            alternatives: alternatives,
            homeRecipeSuggestion: homeRecipeSuggestion
        )
        
        // Save to backend
        try await GenieAPIService.shared.saveRestaurantMeal(entry)
        
        // Add to local list
        restaurantMeals.append(entry)
        
        // Refresh analytics
        await refreshAnalytics()
        
        print("✅ [Restaurant] Logged: \(menuItemName) from \(restaurantName) - \(calories) cal")
    }
    
    // MARK: - Analytics
    
    func refreshAnalytics(days: Int = 30) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            analytics = try await GenieAPIService.shared.getRestaurantAnalytics(days: days)
            print("✅ [Restaurant] Analytics refreshed")
        } catch {
            print("❌ [Restaurant] Error fetching analytics: \(error)")
        }
    }
    
    // MARK: - Find Nearby Restaurants (via Genie Agent)
    
    func findNearbyRestaurants(latitude: Double, longitude: Double, radius: Int = 1000, type: String? = nil) async throws -> [RestaurantInfo] {
        // Use Genie agent to search for nearby restaurants
        let query = """
        Find restaurants near me at coordinates \(latitude), \(longitude) within \(radius) meters.
        \(type != nil ? "Filter by type: \(type!)" : "")
        Return a list of restaurants with:
        - Name
        - Address
        - Type/cuisine
        - Distance
        - Rating if available
        """
        
        let response = try await GenieAPIService.shared.query(query)
        
        // Parse restaurant info from response
        // This will be enhanced when agent returns structured data
        return parseRestaurantsFromResponse(response.response)
    }
    
    // MARK: - Search Menu (via Genie Agent)
    
    func searchRestaurantMenu(restaurantName: String, query: String? = nil, dietaryPreferences: [String] = []) async throws -> [MenuItem] {
        var searchQuery = "Find menu items and nutrition information for \(restaurantName)"
        
        if let query = query, !query.isEmpty {
            searchQuery += ". Search for: \(query)"
        }
        
        if !dietaryPreferences.isEmpty {
            searchQuery += ". Dietary preferences: \(dietaryPreferences.joined(separator: ", "))"
        }
        
        searchQuery += """
        
        Return menu items with:
        - Item name
        - Calories
        - Protein, carbs, fat
        - Price if available
        - Healthiness score
        """
        
        let response = try await GenieAPIService.shared.query(searchQuery)
        
        // Parse menu items from response
        return parseMenuItemsFromResponse(response.response)
    }
    
    // MARK: - Helper Functions
    
    private func parseRestaurantsFromResponse(_ response: String) -> [RestaurantInfo] {
        // TODO: Parse structured response from agent
        // For now, return empty array
        return []
    }
    
    private func parseMenuItemsFromResponse(_ response: String) -> [MenuItem] {
        // TODO: Parse structured response from agent
        // For now, return empty array
        return []
    }
}
