//
//  GenieAPIService.swift
//  Do
//
//  Modern service for interacting with Genie backend
//

import Foundation
import Combine

// Import models from Genie feature
// Note: Models are in iOS/Do/Features/Genie/Models/
// These will need to be accessible from Core/Services

class GenieAPIService: ObservableObject {
    static let shared = GenieAPIService()
    
    private let baseURL = "https://nuexjddrx7.execute-api.us-east-1.amazonaws.com"
    
    // Custom URLSession with optimized timeout
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30 // Reduced from 90s to 30s for faster failure
        config.timeoutIntervalForResource = 60 // Reduced from 120s to 60s
        config.waitsForConnectivity = false // Don't wait for connectivity - fail fast
        config.requestCachePolicy = .reloadIgnoringLocalCacheData // Always fetch fresh data
        return URLSession(configuration: config)
    }()
    
    // Token balance cache (5 minute TTL)
    private var tokenBalanceCache: (balance: Int, timestamp: Date)?
    private let tokenBalanceCacheTTL: TimeInterval = 300 // 5 minutes
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Context Enrichment
    // The agent (LLM) decides what context it needs - we just provide minimal necessary info
    private func enrichQueryIfPossible(_ text: String) async -> String {
        // If caller already embeds [CONTEXT], do not re-wrap (preserve as-is)
        if text.contains("[CONTEXT]") { return text }
        
        // Provide minimal context: units preference, user name, and user insights
        let useImperial = UserPreferences.shared.useImperialUnits
        let unitsLine = "units: \(useImperial ? "imperial" : "metric")"
        
        // Get user name if available (avoid "null" in responses)
        let userName = UserIDHelper.shared.getCurrentUsername()
        var contextLines = [unitsLine]
        
        // Add user name if available (to avoid "Hey null" in responses)
        if let name = userName, !name.isEmpty {
            contextLines.append("user name: \(name)")
        }
        
        // Load user insights asynchronously (non-blocking, cached)
        // TODO: Implement GenieUserLearningService
        // let insightSummary = await GenieUserLearningService.shared.getInsightSummary()
        // if !insightSummary.isEmpty {
        //     contextLines.append("user context: \(insightSummary)")
        // }
        
        // Check for recipe-related queries before building final context
        let lowercasedText = text.lowercased()
        let isRecipeQuery = lowercasedText.contains("recipe") || lowercasedText.contains("saved recipe") || 
                           lowercasedText.contains("cookbook") || lowercasedText.contains("my recipes")
        
        // Add saved recipes context if query relates to recipes
        // TODO: Implement RecipeStorageService
        // if isRecipeQuery {
        //     let savedRecipes = await RecipeStorageService.shared.savedRecipes
        //     if !savedRecipes.isEmpty {
        //         let recipeNames = savedRecipes.map { $0.name }.joined(separator: ", ")
        //         contextLines.append("saved recipes: \(recipeNames)")
        //     }
        // }
        
        contextLines.append("policy: only use this user's data; do not invent values")
        
        let context = contextLines.joined(separator: "\n")
        
        // Enhance queries to better match backend expectations
        var enhancedText = text
        
        // Detect story requests and enhance query for better backend detection
        if (lowercasedText.contains("story") || lowercasedText.contains("tale")) &&
           (lowercasedText.contains("tell") || lowercasedText.contains("read") || lowercasedText.contains("give")) {
            if !lowercasedText.contains("bedtime") {
                enhancedText = "Tell me a bedtime story. \(text)"
            }
        }
        
        // Detect meditation requests and enhance query for better backend detection
        if lowercasedText.contains("meditate") || lowercasedText.contains("meditation") ||
           (lowercasedText.contains("help") && lowercasedText.contains("relax")) ||
           (lowercasedText.contains("mindful") && lowercasedText.contains("breath")) {
            if !lowercasedText.contains("meditation") && !lowercasedText.contains("meditate") {
                enhancedText = "Help me meditate. \(text)"
            }
        }
        
        // Detect meal/recipe queries that should provide multiple options
        let isMealQuery = lowercasedText.contains("dinner") || lowercasedText.contains("breakfast") || 
                         lowercasedText.contains("lunch") || lowercasedText.contains("meal") ||
                         lowercasedText.contains("recipe") || lowercasedText.contains("cook") ||
                         lowercasedText.contains("make") || lowercasedText.contains("prepare")
        
        let wantsOptions = lowercasedText.contains("idea") || lowercasedText.contains("option") ||
                          lowercasedText.contains("suggestion") || lowercasedText.contains("recommendation") ||
                          lowercasedText.contains("what can i") || lowercasedText.contains("what should i") ||
                          lowercasedText.contains("give me") || lowercasedText.contains("show me")
        
        let isSpecificQuery = lowercasedText.contains("how do i") || lowercasedText.contains("how to") ||
                            lowercasedText.contains("how can i") || lowercasedText.contains("recipe for") ||
                            lowercasedText.contains("make ") && (lowercasedText.contains("this") || lowercasedText.contains("that"))
        
        if isMealQuery && wantsOptions && !isSpecificQuery && 
           !lowercasedText.contains("multiple") && !lowercasedText.contains("several") && 
           !lowercasedText.contains("few") && !lowercasedText.contains(" 2 ") && 
           !lowercasedText.contains(" 3 ") && !lowercasedText.contains(" 4 ") && 
           !lowercasedText.contains(" 5 ") {
            enhancedText = "\(text) Please provide multiple options (at least 2-3 different recipes or meal ideas)."
        }
        
        let enriched = "[CONTEXT]\n" + context + "\n\n[QUESTION]\n" + enhancedText
        print("[Genie][API-Enrich] Sending query to agent with context - agent will decide what additional context is needed")
        print("[Genie][API-Enrich] Context: \(context)")
        if enhancedText != text {
            print("[Genie][API-Enrich] Enhanced query: \(enhancedText)")
        }
        return enriched
    }
    
    // MARK: - Query Genie
    
    func queryWithImage(_ text: String, imageBase64: String, sessionId: String = UUID().uuidString) async throws -> GenieQueryResponse {
        guard let url = URL(string: "\(baseURL)/query") else {
            throw GenieError.invalidURL
        }
        
        let enriched = await enrichQueryIfPossible(text)
        
        print("🧞 [API] Querying with image: \(url)")
        print("🧞 [API] Query text: \"\(enriched)\"")
        print("🧞 [API] Image size: \(imageBase64.count) bytes")
        
        // Check if query mentions restaurants - if so, include location if available
        let isRestaurantQuery = text.lowercased().contains("restaurant") || 
                                text.lowercased().contains("food nearby") || 
                                text.lowercased().contains("where to eat") ||
                                text.lowercased().contains("nearby food")
        
        var latitude: Double? = nil
        var longitude: Double? = nil
        
        if isRestaurantQuery, let location = LocationManager.shared.location {
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            print("🧞 [API] Restaurant query with image - including location: \(latitude ?? 0), \(longitude ?? 0)")
        }
        
        let token = try await getAuthToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // Longer timeout for image processing
        
        let body = GenieImageQueryRequest(query: enriched, sessionId: sessionId, image: imageBase64, isVoiceInput: false, latitude: latitude, longitude: longitude)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieError.invalidResponse
        }
        
        print("🧞 [API] Response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 402 {
            let upsellResponse = try JSONDecoder().decode(InsufficientTokensResponse.self, from: data)
            let upsellData = UpsellData(
                error: upsellResponse.error,
                required: upsellResponse.required,
                balance: upsellResponse.balance,
                queryType: upsellResponse.queryType,
                tier: upsellResponse.tier,
                upsell: upsellResponse.upsell
            )
            throw GenieError.insufficientTokens(upsellData)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GenieError.serverError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(GenieQueryResponse.self, from: data)
    }
    
    func queryWithVideo(_ text: String, frames: [String], sessionId: String = UUID().uuidString) async throws -> GenieQueryResponse {
        guard let url = URL(string: "\(baseURL)/query") else {
            throw GenieError.invalidURL
        }
        
        let enriched = await enrichQueryIfPossible(text)
        
        print("🧞 [API] Querying with video: \(url)")
        print("🧞 [API] Query text: \"\(enriched)\"")
        print("🧞 [API] Video frames: \(frames.count)")
        
        let token = try await getAuthToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180 // Even longer timeout for video processing
        
        let body = GenieVideoQueryRequest(query: enriched, sessionId: sessionId, frames: frames, isVoiceInput: false)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieError.invalidResponse
        }
        
        print("🧞 [API] Response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 402 {
            let upsellResponse = try JSONDecoder().decode(InsufficientTokensResponse.self, from: data)
            let upsellData = UpsellData(
                error: upsellResponse.error,
                required: upsellResponse.required,
                balance: upsellResponse.balance,
                queryType: upsellResponse.queryType,
                tier: upsellResponse.tier,
                upsell: upsellResponse.upsell
            )
            throw GenieError.insufficientTokens(upsellData)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GenieError.serverError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(GenieQueryResponse.self, from: data)
    }
    
    func query(_ text: String, sessionId: String = UUID().uuidString, isVoiceInput: Bool = false, conversationHistory: [ConversationMessage]? = nil) async throws -> GenieQueryResponse {
        guard let url = URL(string: "\(baseURL)/query") else {
            throw GenieError.invalidURL
        }
        
        let enriched = await enrichQueryIfPossible(text)
        
        // Check if query mentions restaurants - if so, include location if available
        let isRestaurantQuery = text.lowercased().contains("restaurant") || 
                                text.lowercased().contains("food nearby") || 
                                text.lowercased().contains("where to eat") ||
                                text.lowercased().contains("nearby food")
        
        var latitude: Double? = nil
        var longitude: Double? = nil
        
        if isRestaurantQuery, let location = LocationManager.shared.location {
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            print("🧞 [API] Restaurant query detected - including location: \(latitude ?? 0), \(longitude ?? 0)")
        }
        
        print("🧞 [API] Querying: \(url)")
        print("🧞 [API] Query text: \"\(enriched)\"")
        print("🧞 [API] Session ID: \(sessionId)")
        if isVoiceInput {
            print("🧞 [API] Voice input detected")
        }
        
        let token = try await getAuthToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = GenieQueryRequest(query: enriched, sessionId: sessionId, isVoiceInput: isVoiceInput, latitude: latitude, longitude: longitude, conversationHistory: conversationHistory)
        let requestBody = try JSONEncoder().encode(body)
        request.httpBody = requestBody
        
        // Log request body for debugging backend issues
        if let requestBodyString = String(data: requestBody, encoding: .utf8) {
            print("🧞 [API] Request body (first 500 chars): \(requestBodyString.prefix(500))")
        }
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("🧞 [API] ❌ Invalid HTTP response")
            throw GenieError.invalidResponse
        }
        
        print("🧞 [API] Response status: \(httpResponse.statusCode)")
        
        // Log response body for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            let responsePreview = jsonString.count > 500 ? String(jsonString.prefix(500)) + "..." : jsonString
            print("🧞 [API] Response body: \(responsePreview)")
        }
        
        // Enhanced error logging
        if httpResponse.statusCode == 500 {
            print("❌ [API] ⚠️ Backend 500 Internal Server Error")
            print("❌ [API] - URL: \(url)")
            print("❌ [API] - User ID: \(AWSCognitoAuth.shared.getCurrentUserId() ?? "unknown")")
        } else if httpResponse.statusCode == 503 {
            print("⚠️ [API] Service Unavailable (503)")
        }
        
        if httpResponse.statusCode == 402 {
            // Insufficient tokens - parse full upsell data
            let upsellResponse = try JSONDecoder().decode(InsufficientTokensResponse.self, from: data)
            let upsellData = UpsellData(
                error: upsellResponse.error,
                required: upsellResponse.required,
                balance: upsellResponse.balance,
                queryType: upsellResponse.queryType,
                tier: upsellResponse.tier,
                upsell: upsellResponse.upsell
            )
            throw GenieError.insufficientTokens(upsellData)
        }
        
        guard httpResponse.statusCode == 200 else {
            print("🧞 [API] ❌ Server error: \(httpResponse.statusCode)")
            throw GenieError.serverError(httpResponse.statusCode)
        }
        
        var genieResponse = try JSONDecoder().decode(GenieQueryResponse.self, from: data)
        
        // Try to parse structured analysis from response if present
        if genieResponse.structuredAnalysis == nil {
            if let structuredData = try? JSONDecoder().decode(StructuredAnalysis.self, from: Data(genieResponse.response.utf8)) {
                print("🧞 [API] ✅ Parsed structured analysis from response")
                genieResponse = GenieQueryResponse(
                    response: genieResponse.response,
                    tokensUsed: genieResponse.tokensUsed,
                    tokensRemaining: genieResponse.tokensRemaining,
                    tier: genieResponse.tier,
                    handler: genieResponse.handler,
                    balanceWarning: genieResponse.balanceWarning,
                    contextUsed: genieResponse.contextUsed,
                    thinking: genieResponse.thinking,
                    structuredAnalysis: structuredData,
                    actions: genieResponse.actions,
                    title: genieResponse.title
                )
            }
        }
        
        return genieResponse
    }
    
    // MARK: - Token Management
    
    func getTokenBalance(useCache: Bool = true) async throws -> TokenBalanceResponse {
        // Check cache first (if enabled and valid)
        if useCache, let cached = tokenBalanceCache, Date().timeIntervalSince(cached.timestamp) < tokenBalanceCacheTTL {
            print("🧞 [API] ✅ Using cached token balance: \(cached.balance)")
            return TokenBalanceResponse(
                balance: cached.balance,
                usage: nil,
                packages: nil,
                subscription: nil
            )
        }
        
        guard let url = URL(string: "\(baseURL)/tokens/balance") else {
            throw GenieError.invalidURL
        }
        
        print("🧞 [API] Getting token balance from: \(url)")
        
        let startTime = Date()
        let token = try await getAuthToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Add Parse user ID header so Lambda can find the correct balance
        // (tokens are stored under Parse user ID, not Cognito sub)
        if let userId = getCurrentUserIdForAPI() {
            print("🧞 [API] Adding X-User-Id header: \(userId)")
            request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        } else {
            print("🧞 [API] ⚠️ No user ID available for balance request")
        }
        
        request.timeoutInterval = 15 // 15 second timeout for balance requests
        
        let (data, response) = try await urlSession.data(for: request)
        
        let requestDuration = Date().timeIntervalSince(startTime)
        if requestDuration > 5.0 {
            print("⚠️ [API] Token balance request took \(String(format: "%.2f", requestDuration))s (slow)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieError.invalidResponse
        }
        
        print("🧞 [API] Balance response status: \(httpResponse.statusCode)")
        
        // Log raw response for debugging (only first 200 chars to avoid spam)
        if let jsonString = String(data: data, encoding: .utf8) {
            let preview = jsonString.count > 200 ? String(jsonString.prefix(200)) + "..." : jsonString
            print("🧞 [API] Balance response body: \(preview)")
            
            // Try to decode and log the actual balance
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let balance = json["balance"] as? Int {
                print("🧞 [API] ✅ Decoded balance from response: \(balance) tokens")
            }
        }
        
        // Check for auth errors before trying to decode
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                print("🧞 [API] ❌ Authentication failed - token may be invalid or expired")
                throw GenieError.notAuthenticated
            }
            print("🧞 [API] ❌ Server error: \(httpResponse.statusCode)")
            throw GenieError.serverError(httpResponse.statusCode)
        }
        
        let balanceResponse = try JSONDecoder().decode(TokenBalanceResponse.self, from: data)
        
        // Update cache
        tokenBalanceCache = (balance: balanceResponse.balance, timestamp: Date())
        
        return balanceResponse
    }
    
    /// Clear token balance cache (call after token purchase or usage)
    func clearTokenBalanceCache() {
        tokenBalanceCache = nil
        print("🧞 [API] Cleared token balance cache")
    }
    
    func initializeUser() async throws {
        guard let url = URL(string: "\(baseURL)/tokens/initialize") else {
            throw GenieError.invalidURL
        }
        
        let token = try await getAuthToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        _ = try await URLSession.shared.data(for: request)
    }
    
    // MARK: - Stripe Payment
    
    func createPaymentIntent(packageId: String) async throws -> PaymentIntentResponse {
        guard let url = URL(string: "\(baseURL)/tokens/purchase") else {
            throw GenieError.invalidURL
        }
        
        let token = try await getAuthToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Parse user ID header so Lambda can find the correct user
        // (tokens are stored under Parse user ID, not Cognito sub)
        if let userId = getCurrentUserIdForAPI() {
            print("🧞 [API] Adding X-User-Id header for payment intent: \(userId)")
            request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        } else {
            print("🧞 [API] ⚠️ No user ID available for payment intent request")
        }
        
        let body = ["packageId": packageId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("🧞 [API] Creating payment intent for package: \(packageId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🧞 [API] Payment intent response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorData["error"] as? String {
                    print("❌ [API] Payment intent error: \(errorMessage)")
                    throw GenieError.serverError(httpResponse.statusCode)
                } else if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ [API] Payment intent error response: \(errorString)")
                    throw GenieError.serverError(httpResponse.statusCode)
                } else {
                    throw GenieError.serverError(httpResponse.statusCode)
                }
            }
        }
        
        do {
            let paymentIntent = try JSONDecoder().decode(PaymentIntentResponse.self, from: data)
            print("✅ [API] Payment intent created successfully")
            return paymentIntent
        } catch {
            print("❌ [API] Failed to decode payment intent response: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ [API] Response body: \(responseString)")
            }
            throw GenieError.invalidResponse
        }
    }
    
    // MARK: - Meditation Tracking
    
    func saveMeditationSession(_ session: MeditationSessionData) async throws {
        guard let url = URL(string: "\(baseURL)/meditation/save") else {
            throw GenieError.invalidURL
        }
        
        let token = try await getAuthToken()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let requestBody = try encoder.encode(session)
        
        if let jsonString = String(data: requestBody, encoding: .utf8) {
            print("🧞 [API] Saving meditation session: \(jsonString)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let userId = getCurrentUserIdForAPI() {
            request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        }
        
        request.httpBody = requestBody
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("🧞 [API] ❌ Meditation save error (status \(httpResponse.statusCode)): \(errorString)")
            throw GenieError.serverError(httpResponse.statusCode)
        }
        
        print("✅ [API] Meditation session saved to prod")
    }
    
    // MARK: - Restaurant Tracking
    
    func saveRestaurantMeal(_ entry: RestaurantEntry) async throws {
        guard let url = URL(string: "\(baseURL)/restaurant/save") else {
            throw GenieError.invalidURL
        }
        
        let token = try await getAuthToken()
        
        // Convert RestaurantEntry to dictionary for API
        var requestBody: [String: Any] = [
            "id": entry.id,
            "restaurantName": entry.restaurantName,
            "menuItemName": entry.menuItemName,
            "mealType": entry.mealType.rawValue,
            "calories": entry.calories,
            "protein": entry.protein,
            "carbs": entry.carbs,
            "fat": entry.fat,
            "timestamp": ISO8601DateFormatter().string(from: entry.timestamp)
        ]
        
        if let restaurantId = entry.restaurantId {
            requestBody["restaurantId"] = restaurantId
        }
        
        if let restaurantType = entry.restaurantType {
            requestBody["restaurantType"] = restaurantType.rawValue
        }
        
        if let location = entry.location {
            requestBody["location"] = [
                "address": location.address,
                "latitude": location.latitude,
                "longitude": location.longitude,
                "city": location.city ?? "",
                "state": location.state ?? "",
                "zipCode": location.zipCode ?? ""
            ]
        }
        
        if let menuItemId = entry.menuItemId {
            requestBody["menuItemId"] = menuItemId
        }
        
        if let servingSize = entry.servingSize {
            requestBody["servingSize"] = servingSize
        }
        
        if let price = entry.price {
            requestBody["price"] = price
        }
        
        if let rating = entry.rating {
            requestBody["rating"] = rating
        }
        
        if let notes = entry.notes {
            requestBody["notes"] = notes
        }
        
        if let alternatives = entry.alternatives {
            requestBody["alternatives"] = alternatives.map { alt in
                [
                    "name": alt.name,
                    "calories": alt.calories,
                    "protein": alt.protein,
                    "carbs": alt.carbs,
                    "fat": alt.fat,
                    "savings": alt.savings,
                    "reason": alt.reason
                ]
            }
        }
        
        if let homeRecipe = entry.homeRecipeSuggestion {
            requestBody["homeRecipeSuggestion"] = [
                "recipeName": homeRecipe.recipeName,
                "estimatedCalories": homeRecipe.estimatedCalories,
                "estimatedCost": homeRecipe.estimatedCost,
                "savings": [
                    "calories": homeRecipe.savings.calories,
                    "cost": homeRecipe.savings.cost
                ],
                "recipeId": homeRecipe.recipeId ?? ""
            ]
        }
        
        if let imageUrl = entry.imageUrl {
            requestBody["imageUrl"] = imageUrl
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("🧞 [API] Saving restaurant meal: \(jsonString.prefix(200))...")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let userId = getCurrentUserIdForAPI() {
            request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        }
        
        request.httpBody = jsonData
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("🧞 [API] ❌ Restaurant meal save error (status \(httpResponse.statusCode)): \(errorString)")
            throw GenieError.serverError(httpResponse.statusCode)
        }
        
        print("✅ [API] Restaurant meal saved")
    }
    
    func getRestaurantAnalytics(days: Int = 30) async throws -> RestaurantAnalytics {
        guard let url = URL(string: "\(baseURL)/restaurant/analytics?days=\(days)") else {
            throw GenieError.invalidURL
        }
        
        let token = try await getAuthToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let userId = getCurrentUserIdForAPI() {
            request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        }
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("🧞 [API] ❌ Restaurant analytics error (status \(httpResponse.statusCode)): \(errorString)")
            throw GenieError.serverError(httpResponse.statusCode)
        }
        
        // Parse response - backend may return RestaurantAnalyticsResponse wrapper
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Try to decode as RestaurantAnalyticsResponse first
        if let responseWrapper = try? decoder.decode(RestaurantAnalyticsResponse.self, from: data),
           let analyticsData = responseWrapper.data {
            // Convert RestaurantAnalyticsData to RestaurantAnalytics
            let formatter = ISO8601DateFormatter()
            let startDate = formatter.date(from: analyticsData.period.startDate) ?? Date()
            let endDate = formatter.date(from: analyticsData.period.endDate) ?? Date()
            
            return RestaurantAnalytics(
                period: RestaurantAnalytics.AnalyticsPeriod(
                    days: analyticsData.period.days,
                    startDate: startDate,
                    endDate: endDate
                ),
                summary: RestaurantAnalytics.AnalyticsSummary(
                    totalRestaurantMeals: analyticsData.summary.totalRestaurantMeals,
                    totalCalories: analyticsData.summary.totalCalories,
                    averageCaloriesPerMeal: analyticsData.summary.averageCaloriesPerMeal,
                    totalSpent: analyticsData.summary.totalSpent,
                    averageSpentPerMeal: analyticsData.summary.averageSpentPerMeal,
                    averageRating: analyticsData.summary.averageRating
                ),
                topRestaurants: analyticsData.topRestaurants.map {
                    RestaurantAnalytics.TopRestaurant(
                        name: $0.name,
                        count: $0.count,
                        percentage: $0.percentage
                    )
                },
                mealTypeDistribution: analyticsData.mealTypeDistribution
            )
        } else {
            // Try direct RestaurantAnalytics decode
            return try decoder.decode(RestaurantAnalytics.self, from: data)
        }
    }
    
    // MARK: - Helpers
    
    private func getAuthToken() async throws -> String {
        // 1. Try Cognito ID token from AWSCognitoAuth (preferred)
        if var cognitoAuth = AWSCognitoAuth.shared.getIdToken(),
           !cognitoAuth.isEmpty {
            // Validate token before using it
            if let tokenInfo = validateJWTToken(cognitoAuth) {
                print("🧞 [API] Token validation:")
                print("   - Valid: \(tokenInfo.isValid)")
                print("   - Expired: \(tokenInfo.isExpired)")
                
                // If token is expired, try to refresh
                if tokenInfo.isExpired {
                    print("🧞 [API] ⚠️ Token is expired, attempting refresh...")
                    do {
                        try await AWSCognitoAuth.shared.refreshToken()
                        // Try again after refresh
                        if let refreshedToken = AWSCognitoAuth.shared.getIdToken(),
                           !refreshedToken.isEmpty {
                            print("🧞 [API] ✅ Token refreshed successfully")
                            // Validate refreshed token
                            if let refreshedInfo = validateJWTToken(refreshedToken), !refreshedInfo.isExpired {
                                return refreshedToken
                            }
                        }
                    } catch {
                        print("🧞 [API] ⚠️ Token refresh failed: \(error.localizedDescription)")
                        // Continue with original token if refresh fails
                    }
                }
            }
            
            print("🧞 [API] ✅ Using Cognito ID token from AWSCognitoAuth")
            return cognitoAuth
        }
        
        // 2. Try Cognito access token from UserDefaults (for API authorization)
        if let accessToken = UserDefaults.standard.string(forKey: "cognito_access_token"),
           !accessToken.isEmpty {
            print("🧞 [API] ✅ Using Cognito access token from UserDefaults")
            return accessToken
        }
        
        // 3. Try Cognito ID token from UserDefaults
        if let idToken = UserDefaults.standard.string(forKey: "cognito_id_token"),
           !idToken.isEmpty {
            print("🧞 [API] ✅ Using Cognito ID token from UserDefaults")
            return idToken
        }
        
        // No token found
        print("🧞 [API] ❌ No authentication token found")
        print("🧞 [API] 💡 Checked sources:")
        print("   - AWSCognitoAuth.getIdToken()")
        print("   - UserDefaults: cognito_access_token")
        print("   - UserDefaults: cognito_id_token")
        print("🧞 [API] 💡 User may need to sign in again")
        throw GenieError.notAuthenticated
    }
    
    /// Get current user ID for API calls (fallback for backend)
    private func getCurrentUserIdForAPI() -> String? {
        // 1. Try Parse user ID from Cognito custom attribute (backend expects this)
        if let parseUserId = AWSCognitoAuth.shared.getParseUserId(), !parseUserId.isEmpty {
            print("🧞 [API] Using Parse user ID from Cognito custom attribute: \(parseUserId)")
            return parseUserId
        }
        
        // 2. Try UserIDHelper
        if let userId = UserIDHelper.shared.getCurrentUserID(), !userId.isEmpty {
            print("🧞 [API] Using user ID from UserIDHelper: \(userId)")
            return userId
        }
        
        // 3. Try stored Cognito user ID
        if let userId = UserDefaults.standard.string(forKey: "cognito_user_id"),
           !userId.isEmpty {
            print("🧞 [API] Using stored user ID: \(userId)")
            return userId
        }
        
        print("🧞 [API] ⚠️ No user ID found for API calls")
        return nil
    }
    
    /// Validate JWT token and extract information
    private func validateJWTToken(_ token: String) -> (isValid: Bool, isExpired: Bool, issuer: String?, audience: String?, expirationDate: Date?)? {
        // JWT tokens have 3 parts: header.payload.signature
        let parts = token.split(separator: ".")
        guard parts.count == 3 else {
            print("🧞 [API] ⚠️ Invalid JWT format (expected 3 parts, got \(parts.count))")
            return nil
        }
        
        // Decode payload (second part)
        var base64 = String(parts[1])
        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 = base64.padding(toLength: base64.count + 4 - remainder, withPad: "=", startingAt: 0)
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("🧞 [API] ⚠️ Failed to decode JWT payload")
            return nil
        }
        
        // Extract expiration
        var expirationDate: Date?
        var isExpired = false
        if let exp = json["exp"] as? TimeInterval {
            expirationDate = Date(timeIntervalSince1970: exp)
            isExpired = expirationDate! < Date()
        }
        
        // Extract issuer
        let issuer = json["iss"] as? String
        
        // Extract audience (can be string or array)
        var audience: String?
        if let aud = json["aud"] as? String {
            audience = aud
        } else if let audArray = json["aud"] as? [String], !audArray.isEmpty {
            audience = audArray[0]
        }
        
        return (isValid: true, isExpired: isExpired, issuer: issuer, audience: audience, expirationDate: expirationDate)
    }
    
    // MARK: - Subscription
    
    func getSubscriptionStatus() async throws -> SubscriptionStatusResponse {
        guard let url = URL(string: "\(baseURL)/subscription/status") else {
            throw GenieError.invalidURL
        }
        let token = try await getAuthToken()
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(SubscriptionStatusResponse.self, from: data)
    }
    
    // Fetch subscription prices and Stripe price IDs from backend
    // TODO: Implement backend endpoint /subscriptions/prices that returns:
    // { tiers: [{ tier: "Athlete", monthlyPrice: 9.99, annualPrice: 99.90, monthlyPriceId: "price_xxx", annualPriceId: "price_yyy" }, ...] }
    func getSubscriptionPrices() async throws -> [SubscriptionTierPrice] {
        guard let url = URL(string: "\(baseURL)/subscriptions/prices") else {
            throw GenieError.invalidURL
        }
        let token = try await getAuthToken()
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            // If endpoint doesn't exist yet, return empty array (fallback to hardcoded prices)
            print("⚠️ [API] Subscription prices endpoint not available (status: \(httpResponse.statusCode)), using hardcoded prices")
            return []
        }
        
        return try JSONDecoder().decode([SubscriptionTierPrice].self, from: data)
    }
    
    // Create SetupIntent for Stripe PaymentSheet
    func createSetupIntent() async throws -> SetupIntentResponse {
        guard let url = URL(string: "\(baseURL)/subscriptions/setup-intent") else {
            throw GenieError.invalidURL
        }
        
        let token = try await getAuthToken()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieError.invalidResponse
        }
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🧞 [API] Setup intent response: \(httpResponse.statusCode) - \(jsonString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            print("🧞 [API] ❌ Setup intent failed with status: \(httpResponse.statusCode)")
            throw GenieError.serverError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(SetupIntentResponse.self, from: data)
    }
    
    // Create subscription with payment method ID (from Stripe PaymentSheet)
    func createSubscription(tier: String, priceId: String, paymentMethodId: String) async throws -> SubscriptionResponse {
        guard let url = URL(string: "\(baseURL)/subscriptions/create") else {
            throw GenieError.invalidURL
        }
        
        let token = try await getAuthToken()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "tier": tier,
            "priceId": priceId,
            "paymentMethodId": paymentMethodId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieError.invalidResponse
        }
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🧞 [API] Subscription response: \(httpResponse.statusCode) - \(jsonString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["error"] {
                print("🧞 [API] ❌ Subscription error: \(errorMessage)")
            }
            throw GenieError.serverError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(SubscriptionResponse.self, from: data)
    }
    
    func updateSubscriptionStatus(tier: String) async throws {
        guard let url = URL(string: "\(baseURL)/subscription/update") else {
            throw GenieError.invalidURL
        }
        let token = try await getAuthToken()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["tier": tier]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await URLSession.shared.data(for: request)
    }
    
    // Cancel subscription
    func cancelSubscription() async throws -> CancelSubscriptionResponse {
        guard let url = URL(string: "\(baseURL)/subscriptions/cancel") else {
            throw GenieError.invalidURL
        }
        
        let token = try await getAuthToken()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieError.invalidResponse
        }
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🧞 [API] Cancel subscription response: \(httpResponse.statusCode) - \(jsonString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["error"] {
                print("🧞 [API] ❌ Cancel subscription error: \(errorMessage)")
            }
            throw GenieError.serverError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(CancelSubscriptionResponse.self, from: data)
    }
    
    // MARK: - Meditation Library
    
    func getMeditationLibrary(category: String? = nil, duration: Int? = nil, technique: String? = nil, limit: Int = 50) async throws -> MeditationLibraryResponse {
        // Use Lambda Function URL directly (no auth needed for NONE auth type)
        let functionURL = UserDefaults.standard.string(forKey: "meditation_library_lambda_url") ?? "https://o3znju52m3kvgpok3ao36yzf6y0tsvhw.lambda-url.us-east-1.on.aws/"
        
        var components = URLComponents(string: functionURL)!
        
        var queryItems: [URLQueryItem] = []
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if let duration = duration {
            queryItems.append(URLQueryItem(name: "duration", value: String(duration)))
        }
        if let technique = technique {
            queryItems.append(URLQueryItem(name: "technique", value: technique))
        }
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw GenieError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // No auth header needed for NONE auth type Function URL
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GenieError.serverError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let libraryResponse = try decoder.decode(MeditationLibraryResponse.self, from: data)
        
        print("✅ [API] Retrieved \(libraryResponse.data.meditations.count) meditations from library")
        return libraryResponse
    }
    
    func getMeditationById(_ meditationId: String) async throws -> MeditationLibraryItem {
        guard let url = URL(string: "\(baseURL)/meditation-library/\(meditationId)") else {
            throw GenieError.invalidURL
        }
        
        let token = try await getAuthToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GenieError.serverError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let responseWrapper = try decoder.decode(MeditationByIdResponse.self, from: data)
        
        print("✅ [API] Retrieved meditation: \(meditationId)")
        return responseWrapper.data
    }
    
    // MARK: - Food Tracking
    
    func saveFoodLog(
        _ entry: FoodEntry,
        recipeId: String? = nil,
        mealPlanId: String? = nil,
        mealPlanMealId: String? = nil
    ) async throws {
        guard let url = URL(string: "\(baseURL)/nutrition/save") else {
            throw GenieError.invalidURL
        }
        
        let token = try await getAuthToken()
        
        // Convert FoodEntry to dictionary for API
        var requestBody: [String: Any] = [
            "nutritionId": entry.id,
            "entryType": "food",
            "name": entry.name,
            "mealType": entry.mealType.rawValue,
            "calories": entry.calories,
            "protein": entry.protein,
            "carbs": entry.carbs,
            "fat": entry.fat,
            "consumedAt": ISO8601DateFormatter().string(from: entry.timestamp),
            "source": entry.source.rawValue
        ]
        
        if let servingSize = entry.servingSize {
            requestBody["servingSize"] = servingSize
        }
        
        if let notes = entry.notes {
            requestBody["notes"] = notes
        }
        
        // Add relationship fields if provided
        if let recipeId = recipeId {
            requestBody["recipeId"] = recipeId
        }
        
        if let mealPlanId = mealPlanId {
            requestBody["mealPlanId"] = mealPlanId
        }
        
        if let mealPlanMealId = mealPlanMealId {
            requestBody["mealPlanMealId"] = mealPlanMealId
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let userId = getCurrentUserIdForAPI() {
            request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        }
        
        request.httpBody = jsonData
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("🧞 [API] ❌ Food log save error (status \(httpResponse.statusCode)): \(errorString)")
            throw GenieError.serverError(httpResponse.statusCode)
        }
        
        print("✅ [API] Food log saved")
    }
    
    func getFoodHistory(days: Int = 30, limit: Int = 200) async throws -> [[String: Any]] {
        guard let url = URL(string: "\(baseURL)/nutrition/history?days=\(days)&limit=\(limit)&entryType=food") else {
            throw GenieError.invalidURL
        }
        
        let token = try await getAuthToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let userId = getCurrentUserIdForAPI() {
            request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        }
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("🧞 [API] ❌ Food history error (status \(httpResponse.statusCode)): \(errorString)")
            throw GenieError.serverError(httpResponse.statusCode)
        }
        
        // Parse response - backend should return array of items
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Try direct array decode
            if let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return items
            }
            return []
        }
        
        // Try to get items from response
        if let items = json["items"] as? [[String: Any]] {
            return items
        } else if let items = json["data"] as? [[String: Any]] {
            return items
        } else if let items = json["entries"] as? [[String: Any]] {
            return items
        }
        
        return []
    }
    
    func deleteFoodEntry(id: String) async throws {
        guard let url = URL(string: "\(baseURL)/nutrition/\(id)") else {
            throw GenieError.invalidURL
        }
        
        let token = try await getAuthToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let userId = getCurrentUserIdForAPI() {
            request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        }
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenieError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("🧞 [API] ❌ Food entry delete error (status \(httpResponse.statusCode)): \(errorString)")
            throw GenieError.serverError(httpResponse.statusCode)
        }
        
        print("✅ [API] Food entry deleted")
    }
}

// MARK: - GenieError

enum GenieError: Error {
    case invalidURL
    case invalidResponse
    case notAuthenticated
    case serverError(Int)
    case insufficientTokens(UpsellData)
    case invalidRequest(String)
}

