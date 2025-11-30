import Foundation

// MARK: - Token Top-Up Packages

enum TokenTopUp: String, CaseIterable, Hashable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    
    var tokens: Int {
        switch self {
        case .small: return 50
        case .medium: return 150
        case .large: return 350
        }
    }
    
    var price: Double {
        switch self {
        case .small: return 4.99
        case .medium: return 9.99
        case .large: return 19.99
        }
    }
    
    var priceString: String {
        String(format: "$%.2f", price)
    }
    
    var bonusTokens: Int {
        switch self {
        case .small: return 0
        case .medium: return 20
        case .large: return 70
        }
    }
    
    var totalTokens: Int {
        tokens + bonusTokens
    }
    
    var savingsPercentage: Int? {
        switch self {
        case .small: return nil
        case .medium: return 15
        case .large: return 25
        }
    }
    
    var badge: String {
        switch self {
        case .small: return "Basic"
        case .medium: return "Good Value"
        case .large: return "Best Value"
        }
    }
    
    var description: String {
        switch self {
        case .small: return "Quick boost"
        case .medium: return "Good value"
        case .large: return "Best value"
        }
    }
    
    var name: String {
        switch self {
        case .small: return "Small Package"
        case .medium: return "Medium Package"
        case .large: return "Large Package"
        }
    }
    
    /// Price per token in dollars
    var pricePerToken: Double {
        guard totalTokens > 0 else { return 0 }
        return price / Double(totalTokens)
    }
}

// MARK: - Food Meal Type

enum FoodMealType: String, CaseIterable, Codable, Hashable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    
    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "star.fill"
        }
    }
    
    var color: String {
        switch self {
        case .breakfast: return "orange"
        case .lunch: return "yellow"
        case .dinner: return "blue"
        case .snack: return "purple"
        }
    }
}

// MARK: - Type Alias for Compatibility

/// Alias for FoodMealType used in food tracking views
typealias MealType = FoodMealType
