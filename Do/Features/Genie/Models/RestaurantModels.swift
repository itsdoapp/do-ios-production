import Foundation
import CoreLocation

struct RestaurantInfo: Identifiable, Codable, Hashable {
    var id: String { restaurantId ?? name }
    let restaurantId: String?
    let name: String
    let address: String
    let type: RestaurantType?
    let distance: Double?
    let rating: Double?
    let latitude: Double?
    let longitude: Double?
}

struct MenuItem: Identifiable, Codable, Hashable {
    var id: String { menuItemId ?? name }
    let menuItemId: String?
    let name: String
    let description: String?
    let category: String?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let price: Double?
    let healthinessScore: Double?
    let imageUrl: String?
}

enum RestaurantType: String, Codable {
    case fastFood = "fast_food"
    case casualDining = "casual_dining"
    case fineDining = "fine_dining"
    case cafe = "cafe"
    case pizza = "pizza"
    case asian = "asian"
    case mexican = "mexican"
    case italian = "italian"
    case other = "other"
}

struct RestaurantEntry: Identifiable, Codable {
    let id: String
    let restaurantName: String
    let restaurantId: String?
    let restaurantType: RestaurantType?
    let location: RestaurantLocation?
    let menuItemName: String
    let menuItemId: String?
    let mealType: FoodMealType
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let servingSize: String?
    let price: Double?
    let rating: Int?
    let notes: String?
    let timestamp: Date
    let alternatives: [HealthierAlternative]?
    let homeRecipeSuggestion: HomeRecipeSuggestion?
    var imageUrl: String?
}

struct RestaurantLocation: Codable {
    let address: String
    let latitude: Double
    let longitude: Double
    let city: String?
    let state: String?
    let zipCode: String?
}

struct HealthierAlternative: Codable {
    let name: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let savings: Double
    let reason: String
}

struct HomeRecipeSuggestion: Codable {
    let recipeName: String
    let estimatedCalories: Double
    let estimatedCost: Double
    let savings: RecipeSavings
    let recipeId: String?
}

struct RecipeSavings: Codable {
    let calories: Double
    let cost: Double
}

struct RestaurantAnalytics: Codable {
    let period: AnalyticsPeriod
    let summary: AnalyticsSummary
    let topRestaurants: [TopRestaurant]
    let mealTypeDistribution: [String: Int]
    
    struct AnalyticsPeriod: Codable {
        let days: Int
        let startDate: Date
        let endDate: Date
    }
    
    struct AnalyticsSummary: Codable {
        let totalRestaurantMeals: Int
        let totalCalories: Double
        let averageCaloriesPerMeal: Double
        let totalSpent: Double
        let averageSpentPerMeal: Double
        let averageRating: Double?
    }
    
    struct TopRestaurant: Codable {
        let name: String
        let count: Int
        let percentage: Double
    }
}

struct RestaurantAnalyticsResponse: Codable {
    let success: Bool
    let data: RestaurantAnalyticsData?
    let error: String?
}

struct RestaurantAnalyticsData: Codable {
    let period: PeriodData
    let summary: SummaryData
    let topRestaurants: [TopRestaurantData]
    let mealTypeDistribution: [String: Int]
    let items: [RestaurantItemData]
}

struct PeriodData: Codable {
    let days: Int
    let startDate: String
    let endDate: String
}

struct SummaryData: Codable {
    let totalRestaurantMeals: Int
    let totalCalories: Double
    let averageCaloriesPerMeal: Double
    let totalSpent: Double
    let averageSpentPerMeal: Double
    let averageRating: Double?
}

struct TopRestaurantData: Codable {
    let name: String
    let count: Int
    let percentage: Double
}

struct RestaurantItemData: Codable {}


