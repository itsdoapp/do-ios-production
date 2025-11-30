import Foundation
import UIKit
import Vision
import CoreML

/// Service for analyzing food images and providing nutritional information
class FoodImageAnalysisService {
    // MARK: - Singleton
    
    static let shared = FoodImageAnalysisService()
    
    // MARK: - Properties
    
    /// Food detection model
    private var foodDetectionModel: VNCoreMLModel?
    
    /// Nutritional database
    private var nutritionalDatabase: [String: NutritionalInfo] = [:]
    
    // MARK: - Init
    
    private init() {
        setupFoodDetectionModel()
        loadNutritionalDatabase()
    }
    
    // MARK: - Setup
    
    /// Setup the Core ML food detection model
    private func setupFoodDetectionModel() {
        // In a real app, this would load an actual trained food detection model
        // For now, we'll simulate the model's behavior
        
        // For a real implementation, you would do something like:
        // if let modelURL = Bundle.main.url(forResource: "FoodClassifier", withExtension: "mlmodelc") {
        //     do {
        //         let model = try MLModel(contentsOf: modelURL)
        //         foodDetectionModel = try VNCoreMLModel(for: model)
        //     } catch {
        //         print("Error loading food detection model: \(error.localizedDescription)")
        //     }
        // }
    }
    
    /// Load the nutritional database
    private func loadNutritionalDatabase() {
        // In a real app, this would load from a JSON file or API
        // For now, we'll populate with some common foods
        
        nutritionalDatabase = [
            "apple": NutritionalInfo(
                name: "Apple",
                calories: 52,
                protein: 0.3,
                carbs: 14.0,
                fat: 0.2,
                fiber: 2.4,
                sugar: 10.3,
                sodium: 1.0,
                vitamins: ["Vitamin C", "Vitamin A"],
                minerals: ["Potassium", "Calcium"],
                portion: "1 medium (182g)"
            ),
            "banana": NutritionalInfo(
                name: "Banana",
                calories: 89,
                protein: 1.1,
                carbs: 22.8,
                fat: 0.3,
                fiber: 2.6,
                sugar: 12.2,
                sodium: 1.0,
                vitamins: ["Vitamin C", "Vitamin B6"],
                minerals: ["Potassium", "Magnesium"],
                portion: "1 medium (118g)"
            ),
            "broccoli": NutritionalInfo(
                name: "Broccoli",
                calories: 31,
                protein: 2.6,
                carbs: 6.0,
                fat: 0.3,
                fiber: 2.4,
                sugar: 1.7,
                sodium: 30.0,
                vitamins: ["Vitamin C", "Vitamin K", "Folate"],
                minerals: ["Potassium", "Calcium"],
                portion: "1 cup chopped (91g)"
            ),
            "chicken breast": NutritionalInfo(
                name: "Chicken Breast",
                calories: 165,
                protein: 31.0,
                carbs: 0.0,
                fat: 3.6,
                fiber: 0.0,
                sugar: 0.0,
                sodium: 74.0,
                vitamins: ["Vitamin B6", "Vitamin B12"],
                minerals: ["Phosphorus", "Selenium"],
                portion: "100g (cooked)"
            ),
            "salmon": NutritionalInfo(
                name: "Salmon",
                calories: 206,
                protein: 22.0,
                carbs: 0.0,
                fat: 13.0,
                fiber: 0.0,
                sugar: 0.0,
                sodium: 59.0,
                vitamins: ["Vitamin D", "Vitamin B12"],
                minerals: ["Potassium", "Selenium"],
                portion: "100g (cooked)"
            ),
            "rice": NutritionalInfo(
                name: "White Rice",
                calories: 130,
                protein: 2.7,
                carbs: 28.0,
                fat: 0.3,
                fiber: 0.4,
                sugar: 0.1,
                sodium: 1.0,
                vitamins: ["Vitamin B6"],
                minerals: ["Manganese", "Magnesium"],
                portion: "100g (cooked)"
            ),
            "pasta": NutritionalInfo(
                name: "Pasta",
                calories: 131,
                protein: 5.0,
                carbs: 25.0,
                fat: 1.1,
                fiber: 1.2,
                sugar: 0.7,
                sodium: 1.0,
                vitamins: ["Vitamin B1", "Vitamin B2"],
                minerals: ["Iron", "Selenium"],
                portion: "100g (cooked)"
            ),
            "bread": NutritionalInfo(
                name: "Whole Grain Bread",
                calories: 69,
                protein: 3.6,
                carbs: 12.0,
                fat: 1.0,
                fiber: 1.9,
                sugar: 1.4,
                sodium: 160.0,
                vitamins: ["Vitamin B1", "Vitamin B3"],
                minerals: ["Iron", "Magnesium"],
                portion: "1 slice (28g)"
            ),
            "eggs": NutritionalInfo(
                name: "Eggs",
                calories: 78,
                protein: 6.3,
                carbs: 0.6,
                fat: 5.3,
                fiber: 0.0,
                sugar: 0.6,
                sodium: 62.0,
                vitamins: ["Vitamin A", "Vitamin D", "Vitamin B12"],
                minerals: ["Iron", "Selenium"],
                portion: "1 large egg (50g)"
            ),
            "avocado": NutritionalInfo(
                name: "Avocado",
                calories: 160,
                protein: 2.0,
                carbs: 8.5,
                fat: 14.7,
                fiber: 6.7,
                sugar: 0.7,
                sodium: 7.0,
                vitamins: ["Vitamin K", "Vitamin C", "Vitamin E"],
                minerals: ["Potassium", "Folate"],
                portion: "1/2 avocado (68g)"
            ),
            "spinach": NutritionalInfo(
                name: "Spinach",
                calories: 23,
                protein: 2.9,
                carbs: 3.6,
                fat: 0.4,
                fiber: 2.2,
                sugar: 0.4,
                sodium: 79.0,
                vitamins: ["Vitamin K", "Vitamin A", "Vitamin C"],
                minerals: ["Iron", "Calcium"],
                portion: "100g (raw)"
            ),
            "almonds": NutritionalInfo(
                name: "Almonds",
                calories: 161,
                protein: 6.0,
                carbs: 6.0,
                fat: 14.0,
                fiber: 3.5,
                sugar: 1.2,
                sodium: 1.0,
                vitamins: ["Vitamin E"],
                minerals: ["Magnesium", "Phosphorus"],
                portion: "1 oz (28g)"
            ),
            "yogurt": NutritionalInfo(
                name: "Greek Yogurt",
                calories: 59,
                protein: 10.0,
                carbs: 3.6,
                fat: 0.4,
                fiber: 0.0,
                sugar: 3.6,
                sodium: 36.0,
                vitamins: ["Vitamin B12", "Riboflavin"],
                minerals: ["Calcium", "Phosphorus"],
                portion: "100g (plain, nonfat)"
            )
        ]
    }
    
    // MARK: - Public Methods
    
    /// Analyze a food image and return detection results
    /// - Parameters:
    ///   - image: The image to analyze
    ///   - progressHandler: Optional handler to report progress (0.0-1.0)
    ///   - completion: Completion handler with results or error
    func analyzeFoodImage(_ image: UIImage, progressHandler: ((Double) -> Void)? = nil, completion: @escaping (Result< FoodDetectionResult, Error>) -> Void) {
        // In a real app, this would use Vision and CoreML to analyze the image
        // For now, we'll simulate the process with a random result
        
        // Start progress
        progressHandler?(0.0)
        
        // Simulate analysis delay
        DispatchQueue.global().async {
            // Simulate progress updates
            for i in 1...5 {
                DispatchQueue.main.async {
                    progressHandler?(Double(i) * 0.2)
                }
                Thread.sleep(forTimeInterval: 0.3)
            }
            
            // Generate a mock result
            self.generateMockDetectionResult(for: image) { result in
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            }
        }
    }
    
    /// Get detailed nutritional information for a food
    /// - Parameter foodName: The name of the food
    /// - Returns: Detailed nutritional information if available
    func getNutritionalInfo(for foodName: String) -> NutritionalInfo? {
        // Convert to lowercase and look up in database
        let lowercaseName = foodName.lowercased()
        
        // Try direct lookup first
        if let info = nutritionalDatabase[lowercaseName] {
            return info
        }
        
        // If no direct match, try partial matches
        for (key, info) in nutritionalDatabase {
            if lowercaseName.contains(key) || key.contains(lowercaseName) {
                return info
            }
        }
        
        return nil
    }
    
    /// Get nutritional recommendations based on detected foods
    /// - Parameter detectionResult: The food detection result
    /// - Returns: A string with nutritional recommendations
    func getNutritionalRecommendations(for detectionResult: FoodDetectionResult) -> String {
        // In a real app, this would analyze the nutritional profile
        // and provide personalized recommendations
        
        // For now, we'll provide some basic recommendations based on food categories
        
        if detectionResult.detectedFoods.isEmpty {
            return "No foods detected to provide recommendations."
        }
        
        var recommendations = ["Based on your meal:"]
        
        // Check for vegetables
        let hasVegetables = detectionResult.detectedFoods.contains { food in
            ["broccoli", "spinach", "vegetables", "salad"].contains { food.name.lowercased().contains($0) }
        }
        
        if !hasVegetables {
            recommendations.append("• Consider adding more vegetables to your meal for increased fiber and micronutrients.")
        }
        
        // Check for protein
        let hasProtein = detectionResult.detectedFoods.contains { food in
            ["chicken", "beef", "fish", "salmon", "eggs", "tofu", "beans", "lentils"].contains { food.name.lowercased().contains($0) }
        }
        
        if !hasProtein {
            recommendations.append("• Add a source of protein like chicken, fish, eggs, or beans for muscle recovery and satiety.")
        }
        
        // Check total calories
        if detectionResult.totalCalories > 800 {
            recommendations.append("• This meal is relatively high in calories. Consider portion control or balancing with lighter meals throughout the day.")
        }
        
        // Check carbs
        let highCarbs = detectionResult.detectedFoods.contains { food in
            ["pasta", "rice", "bread", "potato"].contains { food.name.lowercased().contains($0) }
        }
        
        if highCarbs {
            recommendations.append("• Consider whole grain options for sustained energy and more nutrients.")
        }
        
        // Check fat content
        if detectionResult.totalFat > 25 {
            recommendations.append("• This meal contains a significant amount of fat. Focus on healthy sources like avocados, nuts, and olive oil.")
        }
        
        // If the meal seems balanced
        if recommendations.count <= 1 {
            recommendations.append("• Your meal appears to be well-balanced. Keep up the good work!")
        }
        
        return recommendations.joined(separator: "\n")
    }
    
    // MARK: - Helper Methods
    
    /// Generate a mock detection result (for development)
    /// - Parameters:
    ///   - image: The original image
    ///   - completion: Completion handler with the mock result
    private func generateMockDetectionResult(for image: UIImage, completion: @escaping ( FoodDetectionResult) -> Void) {
        // For demo purposes, we'll randomly select 1-3 foods from our database
        let foodCount = Int.random(in: 1...3)
        var detectedFoods: [DetectedFood] = []
        
        let allFoods = Array(nutritionalDatabase.values)
        let randomFoods = allFoods.shuffled().prefix(foodCount)
        
        var totalCalories: Double = 0
        var totalProtein: Double = 0
        var totalCarbs: Double = 0
        var totalFat: Double = 0
        
        for (index, food) in randomFoods.enumerated() {
            // Create confidence level (75-95%)
            let confidence = Double.random(in: 0.75...0.95)
            
            // Create portion size variation (0.5-1.5x standard)
            let portionMultiplier = Double.random(in: 0.5...1.5)
            
            // Calculate nutritional totals based on portion
            let calories = food.calories * portionMultiplier
            let protein = food.protein * portionMultiplier
            let carbs = food.carbs * portionMultiplier
            let fat = food.fat * portionMultiplier
            
            // Accumulate totals
            totalCalories += calories
            totalProtein += protein
            totalCarbs += carbs
            totalFat += fat
            
            // Add detected food
            let detected = DetectedFood(
                name: food.name,
                confidence: confidence,
                boundingBox: CGRect(x: 0.1 * Double(index), y: 0.1 * Double(index), width: 0.3, height: 0.3),
                nutritionalInfo: NutritionalInfo(
                    name: food.name,
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    fiber: food.fiber * portionMultiplier,
                    sugar: food.sugar * portionMultiplier,
                    sodium: food.sodium * portionMultiplier,
                    vitamins: food.vitamins,
                    minerals: food.minerals,
                    portion: "Estimated \(String(format: "%.1f", portionMultiplier))x \(food.portion)"
                )
            )
            
            detectedFoods.append(detected)
        }
        
        // Create meal type based on time of day
        let hour = Calendar.current.component(.hour, from: Date())
        let mealType: FoodMealType
        
        if hour >= 5 && hour < 11 {
            mealType = .breakfast
        } else if hour >= 11 && hour < 15 {
            mealType = .lunch
        } else if hour >= 15 && hour < 21 {
            mealType = .dinner
        } else {
            mealType = .snack
        }
        
        // Calculate diet composition percentages
        let totalCaloriesFromMacros = (totalProtein * 4) + (totalCarbs * 4) + (totalFat * 9)
        let proteinPercentage = totalCaloriesFromMacros > 0 ? (totalProtein * 4 / totalCaloriesFromMacros) * 100 : 0
        let carbsPercentage = totalCaloriesFromMacros > 0 ? (totalCarbs * 4 / totalCaloriesFromMacros) * 100 : 0
        let fatPercentage = totalCaloriesFromMacros > 0 ? (totalFat * 9 / totalCaloriesFromMacros) * 100 : 0
        
        // Create the result
        let result = FoodDetectionResult(
            originalImage: image,
            detectedFoods: detectedFoods,
            mealType: mealType,
            totalCalories: totalCalories,
            totalProtein: totalProtein,
            totalCarbs: totalCarbs,
            totalFat: totalFat,
            proteinPercentage: proteinPercentage,
            carbsPercentage: carbsPercentage,
            fatPercentage: fatPercentage,
            analysisDate: Date()
        )
        
        completion(result)
    }
}
