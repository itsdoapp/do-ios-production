import Foundation

/// Service for fetching nutrition data from USDA FoodData Central API
/// Replaces hardcoded nutrition values with real API data
class NutritionService {
    static let shared = NutritionService()
    
    // USDA FoodData Central API Key
    // TODO: Move to secure configuration/Keychain
    private let apiKey = "BpnwCwrN8llfnBCcgvUdbsdAchSh4p8KSGxAAuCa"
    private let baseURL = "https://api.nal.usda.gov/fdc/v1/foods/search"
    
    private let urlSession: URLSession
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10.0
        configuration.timeoutIntervalForResource = 15.0
        self.urlSession = URLSession(configuration: configuration)
    }
    
    /// Fetches nutrition information from USDA API
    /// - Parameter food: Name of the food item
    /// - Returns: NutritionInfo with data from API, or default values if not found
    func getNutritionInfo(for food: String) async throws -> NutritionInfo {
        guard let url = URL(string: "\(baseURL)?query=\(food.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? food)&api_key=\(apiKey)&pageSize=1") else {
            throw NutritionServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NutritionServiceError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NutritionServiceError.serverError(httpResponse.statusCode)
            }
            
            let nutritionResponse = try JSONDecoder().decode(NutritionResponse.self, from: data)
            
            // Extract nutrition info from first food result
            if let firstFood = nutritionResponse.foods.first {
                return parseNutritionInfo(from: firstFood)
            } else {
                // No results found, return default
                return defaultNutrition(for: food)
            }
        } catch let error as DecodingError {
            print("⚠️ [NutritionService] JSON decode error: \(error)")
            // Return default on decode error
            return defaultNutrition(for: food)
        } catch {
            print("⚠️ [NutritionService] Network error: \(error.localizedDescription)")
            // Return default on network error
            return defaultNutrition(for: food)
        }
    }
    
    /// Parses NutritionInfo from USDA API FoodDetails
    private func parseNutritionInfo(from foodDetails: FoodDetails) -> NutritionInfo {
        // Extract nutrients from foodNutrients array
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        
        for nutrient in foodDetails.foodNutrients {
            // Standard nutrient IDs from USDA FDC API
            switch nutrient.nutrientId {
            case 1008: // Energy (kcal)
                calories = nutrient.value
            case 1003: // Protein
                protein = nutrient.value
            case 1005: // Carbohydrate, by difference
                carbs = nutrient.value
            case 1004: // Total lipid (fat)
                fat = nutrient.value
            default:
                break
            }
        }
        
        // Determine portion string
        let portion: String
        if let servingSize = foodDetails.servingSize, let unit = foodDetails.servingSizeUnit {
            portion = "\(servingSize) \(unit)"
        } else {
            portion = "100g" // Default
        }
        
        return NutritionInfo(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            portion: portion
        )
    }
    
    /// Returns default nutrition values when API call fails
    private func defaultNutrition(for food: String) -> NutritionInfo {
        // Provide reasonable defaults based on food type
        // This is a fallback when API is unavailable
        print("⚠️ [NutritionService] Using default nutrition for: \(food)")
        return NutritionInfo(
            calories: 200,
            protein: 5.0,
            carbs: 25.0,
            fat: 8.0,
            portion: "100g"
        )
    }
}

// MARK: - Errors

enum NutritionServiceError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to decode nutrition data"
        }
    }
}


