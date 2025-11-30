import Foundation
import UIKit
import CoreGraphics

struct FoodDetectionResult: Identifiable {
    let id = UUID()
    let originalImage: UIImage
    let detectedFoods: [DetectedFood]
    let mealType: FoodMealType
    let totalCalories: Double
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let proteinPercentage: Double
    let carbsPercentage: Double
    let fatPercentage: Double
    let analysisDate: Date
}

struct DetectedFood: Identifiable {
    let id = UUID()
    let name: String
    let confidence: Double
    let boundingBox: CGRect
    let nutritionalInfo: NutritionalInfo
    
    /// Formatted confidence percentage string
    var confidenceFormatted: String {
        return String(format: "%.0f%%", confidence * 100)
    }
}

struct NutritionalInfo: Codable {
    let name: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let sodium: Double
    let vitamins: [String]?
    let minerals: [String]?
    let portion: String?
}

struct NutritionData: Codable {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

// MARK: - NutritionInfo (Simplified version for NutritionService)

/// Simplified nutritional information structure for compatibility with NutritionService
struct NutritionInfo {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let portion: String
    
    /// Initialize with basic nutrition values
    init(calories: Double, protein: Double, carbs: Double, fat: Double, portion: String) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.portion = portion
    }
    
    /// Initialize from NutritionalInfo (detailed version)
    init(from nutritionalInfo: NutritionalInfo) {
        self.calories = nutritionalInfo.calories
        self.protein = nutritionalInfo.protein
        self.carbs = nutritionalInfo.carbs
        self.fat = nutritionalInfo.fat
        self.portion = nutritionalInfo.portion ?? "100g"
    }
    
    /// Convert to NutritionalInfo
    func toNutritionalInfo(name: String = "") -> NutritionalInfo {
        return NutritionalInfo(
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: 0,
            sugar: 0,
            sodium: 0,
            vitamins: nil,
            minerals: nil,
            portion: portion
        )
    }
}

