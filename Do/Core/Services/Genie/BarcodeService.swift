//
//  BarcodeService.swift
//  Do
//
//  Service for looking up barcode information using Open Food Facts API
//

import Foundation

@MainActor
class BarcodeService: ObservableObject {
    static let shared = BarcodeService()
    
    private init() {}
    
    /// Look up product information by barcode using Open Food Facts API
    func lookupBarcode(_ code: String) async throws -> BarcodeProduct {
        // Open Food Facts API endpoint
        let urlString = "https://world.openfoodfacts.org/api/v2/product/\(code).json"
        
        guard let url = URL(string: urlString) else {
            throw BarcodeServiceError.invalidURL
        }
        
        print("🔍 [Barcode] Looking up barcode: \(code)")
        
        // Make API request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            print("❌ [Barcode] Network error: \(error.localizedDescription)")
            throw BarcodeServiceError.networkError(error)
        }
        
        // Check HTTP response
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 404 {
                throw BarcodeServiceError.productNotFound
            } else if httpResponse.statusCode != 200 {
                print("❌ [Barcode] API error: HTTP \(httpResponse.statusCode)")
                throw BarcodeServiceError.apiError(statusCode: httpResponse.statusCode)
            }
        }
        
        // Parse JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let productDict = json["product"] as? [String: Any] else {
            print("❌ [Barcode] Failed to parse API response")
            throw BarcodeServiceError.invalidResponse
        }
        
        // Extract product information
        let product = parseProduct(from: productDict, barcode: code)
        
        print("✅ [Barcode] Found product: \(product.productName ?? "Unknown")")
        
        return product
    }
    
    /// Search for alternative products by category/brand
    func findAlternatives(for product: BarcodeProduct, limit: Int = 5) async throws -> [BarcodeProduct] {
        // Build search query from product category and brand
        var searchTerms: [String] = []
        
        if let category = product.categories?.first {
            searchTerms.append(category)
        }
        
        // Search Open Food Facts for similar products
        var query = ""
        if let category = product.categories?.first {
            query = category.replacingOccurrences(of: " ", with: "%20")
        } else if let brand = product.brand {
            query = brand.replacingOccurrences(of: " ", with: "%20")
        } else {
            // No alternatives if we can't build a search query
            return []
        }
        
        // Open Food Facts search API
        let urlString = "https://world.openfoodfacts.org/cgi/search.pl?action=process&tagtype_0=categories&tag_contains_0=contains&tag_0=\(query)&page_size=\(limit + 5)&json=true&sort_by=popularity"
        
        guard let url = URL(string: urlString) else {
            return []
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let products = json["products"] as? [[String: Any]] else {
                return []
            }
            
            // Filter out the current product and parse alternatives
            let alternatives = products
                .filter { productDict in
                    let code = productDict["code"] as? String ?? ""
                    return code != product.barcode
                }
                .prefix(limit)
                .compactMap { productDict -> BarcodeProduct? in
                    let code = productDict["code"] as? String ?? ""
                    return parseProduct(from: productDict, barcode: code)
                }
            
            return Array(alternatives)
        } catch {
            print("⚠️ [Barcode] Error finding alternatives: \(error)")
            return []
        }
    }
    
    /// Analyze product and generate recommendations
    func analyzeProduct(_ product: BarcodeProduct, alternatives: [BarcodeProduct]) -> ProductAnalysis {
        var insights: [String] = []
        var recommendations: [String] = []
        var healthScore: Double = 0.5
        
        // Analyze nutrition
        if let nutrition = product.nutrition {
            // Check for high sugar
            if let sugars = nutrition.sugars, sugars > 20 {
                insights.append("High sugar content (\(Int(sugars))g per 100g)")
                recommendations.append("Consider products with less added sugar")
                healthScore -= 0.1
            }
            
            // Check for high sodium
            if let sodium = nutrition.sodium, sodium > 500 {
                insights.append("High sodium content (\(Int(sodium))mg per 100g)")
                recommendations.append("Look for low-sodium alternatives")
                healthScore -= 0.1
            }
            
            // Check for high saturated fat
            if let saturatedFat = nutrition.saturatedFat, saturatedFat > 10 {
                insights.append("High saturated fat (\(Int(saturatedFat))g per 100g)")
                recommendations.append("Choose products with healthier fats")
                healthScore -= 0.1
            }
            
            // Positive checks
            if let fiber = nutrition.fiber, fiber > 5 {
                insights.append("Good source of fiber (\(Int(fiber))g per 100g)")
                healthScore += 0.1
            }
            
            if nutrition.protein > 10 {
                insights.append("Good protein content (\(Int(nutrition.protein))g per 100g)")
                healthScore += 0.1
            }
            
            // Check for additives
            if let additives = product.additives, !additives.isEmpty {
                insights.append("Contains \(additives.count) additive(s)")
                if additives.count > 3 {
                    recommendations.append("Consider products with fewer additives")
                    healthScore -= 0.05
                }
            }
            
            // Check Nutri-Score if available
            if let nutriScore = product.nutriScore {
                switch nutriScore.uppercased() {
                case "A", "B":
                    insights.append("Good Nutri-Score: \(nutriScore)")
                    healthScore += 0.2
                case "C":
                    insights.append("Moderate Nutri-Score: \(nutriScore)")
                case "D", "E":
                    insights.append("Low Nutri-Score: \(nutriScore)")
                    recommendations.append("Look for products with better Nutri-Score (A or B)")
                    healthScore -= 0.2
                default:
                    break
                }
            }
        }
        
        // Compare with alternatives
        if !alternatives.isEmpty {
            let currentCalories = product.nutrition?.calories ?? 0
            let betterAlternatives = alternatives.filter { alt in
                if let altCalories = alt.nutrition?.calories, altCalories < currentCalories {
                    return true
                }
                return false
            }
            
            if !betterAlternatives.isEmpty {
                recommendations.append("Found \(betterAlternatives.count) lower-calorie alternative(s) - see below")
            }
        }
        
        // Default recommendations if none generated
        if recommendations.isEmpty && healthScore < 0.6 {
            recommendations.append("Consider checking the ingredients list for whole foods")
            recommendations.append("Look for products with minimal processing")
        }
        
        healthScore = max(0.0, min(1.0, healthScore))
        
        return ProductAnalysis(
            insights: insights,
            recommendations: recommendations,
            healthScore: healthScore,
            isHealthy: healthScore >= 0.6
        )
    }
    
    // MARK: - Private Helpers
    
    private func parseProduct(from productDict: [String: Any], barcode: String) -> BarcodeProduct {
        // Extract basic info
        let productName = productDict["product_name"] as? String ?? 
                         productDict["product_name_en"] as? String ??
                         productDict["abbreviated_product_name"] as? String
        
        let brand = productDict["brands"] as? String ??
                   (productDict["brands_tags"] as? [String])?.first
        
        // Extract categories
        let categories: [String]? = {
            if let categoriesStr = productDict["categories"] as? String {
                return categoriesStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            } else if let categoriesArray = productDict["categories_tags"] as? [String] {
                return categoriesArray
            }
            return nil
        }()
        
        // Extract nutrition
        let nutrition = parseNutrition(from: productDict)
        
        // Extract serving size
        let servingSize = productDict["serving_size"] as? String ??
                         productDict["quantity"] as? String
        
        // Extract image URL
        let imageUrl = productDict["image_url"] as? String ??
                         productDict["image_front_url"] as? String
        
        // Extract ingredients
        let ingredients: [String]? = {
            if let ingredientsText = productDict["ingredients_text"] as? String {
                return ingredientsText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            } else if let ingredientsArray = productDict["ingredients"] as? [[String: Any]] {
                return ingredientsArray.compactMap { $0["text"] as? String }
            }
            return nil
        }()
        
        // Extract additives
        let additives: [String]? = {
            if let additivesArray = productDict["additives_tags"] as? [String] {
                return additivesArray.map { $0.replacingOccurrences(of: "en:", with: "") }
            }
            return nil
        }()
        
        // Extract Nutri-Score
        let nutriScore = productDict["nutriscore_grade"] as? String
        
        // Extract nutrition facts per serving
        let nutritionPerServing = parseNutritionPerServing(from: productDict)
        
        return BarcodeProduct(
            barcode: barcode,
            productName: productName,
            brand: brand,
            categories: categories,
            nutrition: nutrition,
            nutritionPerServing: nutritionPerServing,
            servingSize: servingSize,
            imageUrl: imageUrl,
            ingredients: ingredients,
            additives: additives,
            nutriScore: nutriScore
        )
    }
    
    private func parseNutrition(from productDict: [String: Any]) -> ExtendedNutritionData? {
        // Try to get nutrition per 100g first
        guard let nutriments = productDict["nutriments"] as? [String: Any] else {
            return nil
        }
        
        let calories = (nutriments["energy-kcal_100g"] as? Double) ??
                      (nutriments["energy_100g"] as? Double).map { $0 / 4.184 } ?? // Convert kJ to kcal
                      0
        
        let protein = (nutriments["proteins_100g"] as? Double) ?? 0
        let carbs = (nutriments["carbohydrates_100g"] as? Double) ?? 0
        let fat = (nutriments["fat_100g"] as? Double) ?? 0
        let sugars = nutriments["sugars_100g"] as? Double
        let fiber = nutriments["fiber_100g"] as? Double
        let sodium = (nutriments["sodium_100g"] as? Double).map { $0 * 1000 } // Convert to mg
        let saturatedFat = nutriments["saturated-fat_100g"] as? Double
        
        // If we have at least calories, return nutrition data
        if calories > 0 {
            return ExtendedNutritionData(
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                sugars: sugars,
                fiber: fiber,
                sodium: sodium,
                saturatedFat: saturatedFat
            )
        }
        
        return nil
    }
    
    private func parseNutritionPerServing(from productDict: [String: Any]) -> NutritionData? {
        guard let nutriments = productDict["nutriments"] as? [String: Any] else {
            return nil
        }
        
        // Try to get per serving values
        let calories = (nutriments["energy-kcal_serving"] as? Double) ??
                      (nutriments["energy_serving"] as? Double).map { $0 / 4.184 } ??
                      (nutriments["energy-kcal"] as? Double) ??
                      0
        
        let protein = (nutriments["proteins_serving"] as? Double) ??
                     (nutriments["proteins"] as? Double) ?? 0
        let carbs = (nutriments["carbohydrates_serving"] as? Double) ??
                   (nutriments["carbohydrates"] as? Double) ?? 0
        let fat = (nutriments["fat_serving"] as? Double) ??
                 (nutriments["fat"] as? Double) ?? 0
        
        if calories > 0 {
            return NutritionData(
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat
            )
        }
        
        return nil
    }
}

// MARK: - Data Models

struct BarcodeProduct {
    let barcode: String
    let productName: String?
    let brand: String?
    let categories: [String]?
    let nutrition: ExtendedNutritionData? // Per 100g
    let nutritionPerServing: NutritionData? // Per serving
    let servingSize: String?
    let imageUrl: String?
    let ingredients: [String]?
    let additives: [String]?
    let nutriScore: String? // A, B, C, D, or E
}

struct ProductAnalysis {
    let insights: [String]
    let recommendations: [String]
    let healthScore: Double // 0.0 to 1.0
    let isHealthy: Bool
}

// MARK: - Extended Nutrition Data

struct ExtendedNutritionData {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let sugars: Double?
    let fiber: Double?
    let sodium: Double? // in mg
    let saturatedFat: Double?
    
    func toBasicNutrition() -> NutritionData {
        return NutritionData(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat
        )
    }
}

// MARK: - Error Types

enum BarcodeServiceError: LocalizedError {
    case invalidURL
    case productNotFound
    case invalidResponse
    case apiError(statusCode: Int)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid barcode lookup URL"
        case .productNotFound:
            return "Product not found in database"
        case .invalidResponse:
            return "Invalid response from barcode API"
        case .apiError(let statusCode):
            return "Barcode API error: HTTP \(statusCode)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

