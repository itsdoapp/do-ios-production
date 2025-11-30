import Foundation

// MARK: - USDA FoodData Central API Response Models

struct NutritionResponse: Codable {
    let foods: [FoodDetails]
}

struct FoodDetails: Codable {
    let fdcId: Int
    let description: String
    let foodNutrients: [Nutrient]
    let servingSize: Double?
    let servingSizeUnit: String?
    
    enum CodingKeys: String, CodingKey {
        case fdcId
        case description
        case foodNutrients
        case servingSize = "servingSize"
        case servingSizeUnit = "servingSizeUnit"
    }
}

struct Nutrient: Codable {
    let nutrientId: Int
    let nutrientName: String
    let value: Double
    let unitName: String
}


