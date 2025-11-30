//
//  BarcodeAnalysisView.swift
//  Do
//
//  Beautiful view for displaying barcode scan analysis with brand, alternatives, and recommendations
//

import SwiftUI

struct BarcodeAnalysisView: View {
    let barcode: String
    let analysis: GenieQueryResponse
    let mealType: FoodMealType
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var parsedData: ParsedBarcodeData?
    @State private var isSaving = false
    @State private var showingQuestionInput = false
    @State private var questionText = ""
    @State private var isProcessingQuestion = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0F163E")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Barcode badge
                        HStack {
                            Image(systemName: "barcode")
                                .font(.system(size: 14))
                            Text("Barcode: \(barcode)")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // Parse data on appear
                        if parsedData == nil {
                            ProgressView()
                                .tint(.white)
                                .padding()
                        } else if let data = parsedData {
                            // Check if we have valid data
                            let hasValidData = !data.foodItems.isEmpty &&
                                             data.nutrition != nil &&
                                             data.nutrition!.calories > 0
                            
                            if hasValidData {
                                // Product name and brand
                                ProductHeaderCard(
                                    productName: data.productName ?? data.foodItems.first ?? "Scanned Product",
                                    brand: data.brand
                                )
                                .padding(.horizontal)
                                
                                // Meal type badge
                                MealTypeBadge(mealType: data.detectedMealType ?? mealType)
                                    .padding(.horizontal)
                                
                                // Main nutrition card
                                if data.nutrition != nil {
                                    EnhancedNutritionCard(
                                        nutrition: data.nutrition!,
                                        servingSize: data.servingSize,
                                        confidence: data.confidence
                                    )
                                    .padding(.horizontal)
                                }
                                
                                // Insights card
                                if !data.insights.isEmpty {
                                    InsightsCard(insights: data.insights)
                                        .padding(.horizontal)
                                }
                                
                                // Alternatives card
                                if !data.alternatives.isEmpty {
                                    AlternativesCard(alternatives: data.alternatives)
                                        .padding(.horizontal)
                                }
                                
                                // Recommendations card
                                if !data.recommendations.isEmpty {
                                    RecommendationsCard(recommendations: data.recommendations)
                                        .padding(.horizontal)
                                }
                                
                                // Low confidence warning
                                if data.confidence < 0.7 {
                                    LowConfidenceCard(
                                        confidence: data.confidence,
                                        onAddDetails: {
                                            showingQuestionInput = true
                                        },
                                        onAskQuestion: {
                                            showingQuestionInput = true
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                                
                                // Save button
                                Button {
                                    saveFood(data: data)
                                } label: {
                                    HStack {
                                        if isSaving {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "checkmark.circle.fill")
                                        }
                                        Text(isSaving ? "Saving..." : "Save to Log")
                                    }
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: [Color(hex: "F7931F"), Color(hex: "FF6B35")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                }
                                .disabled(isSaving)
                                .padding(.horizontal)
                            } else {
                                // Empty state
                                EmptyFoodStateView()
                                    .padding(.horizontal)
                                    .padding(.vertical, 40)
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Product Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "F7931F"))
                }
            }
        }
        .onAppear {
            parseAnalysis()
        }
        .sheet(isPresented: $showingQuestionInput) {
            QuestionInputSheet(
                questionText: $questionText,
                isProcessing: $isProcessingQuestion,
                onSubmit: { question in
                    Task {
                        await processQuestion(question)
                    }
                }
            )
        }
    }
    
    private func parseAnalysis() {
        // Check for nutrition_data action
        guard let actions = analysis.actions,
              let action = actions.first(where: { $0.type == "nutrition_data" }) else {
            // Fallback to text parsing
            parseFromText(analysis.response)
            return
        }
        
        parseFromAction(action)
    }
    
    private func parseFromAction(_ action: GenieAction) {
        // Check if analysis field contains nested JSON
        var parsedJsonData: [String: Any]? = nil
        if let analysisString = action.data["analysis"]?.stringValue,
           let jsonData = analysisString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let dataDict = json["data"] as? [String: Any] {
            parsedJsonData = dataDict
        }
        
        // Extract macros
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        
        if let macros = parsedJsonData?["macros"] as? [String: Any] {
            protein = (macros["protein"] as? Double) ?? (macros["protein"] as? Int).map { Double($0) } ?? 0
            carbs = (macros["carbs"] as? Double) ?? (macros["carbs"] as? Int).map { Double($0) } ?? 0
            fat = (macros["fat"] as? Double) ?? (macros["fat"] as? Int).map { Double($0) } ?? 0
        } else if let macrosDict = action.data["macros"]?.dictValue {
            // dictValue returns [String: Any], so we need to cast the values
            protein = (macrosDict["protein"] as? Double) ?? (macrosDict["protein"] as? Int).map { Double($0) } ?? 0
            carbs = (macrosDict["carbs"] as? Double) ?? (macrosDict["carbs"] as? Int).map { Double($0) } ?? 0
            fat = (macrosDict["fat"] as? Double) ?? (macrosDict["fat"] as? Int).map { Double($0) } ?? 0
        } else if let macrosAnyCodable = action.data["macros"]?.value as? [String: AnyCodable] {
            // Handle case where macros is [String: AnyCodable]
            protein = macrosAnyCodable["protein"]?.doubleValue ?? macrosAnyCodable["protein"]?.intValue.map { Double($0) } ?? 0
            carbs = macrosAnyCodable["carbs"]?.doubleValue ?? macrosAnyCodable["carbs"]?.intValue.map { Double($0) } ?? 0
            fat = macrosAnyCodable["fat"]?.doubleValue ?? macrosAnyCodable["fat"]?.intValue.map { Double($0) } ?? 0
        }
        
        calories = (parsedJsonData?["calories"] as? Double) ?? 
                   (parsedJsonData?["calories"] as? Int).map { Double($0) } ??
                   action.data["calories"]?.doubleValue ??
                   action.data["calories"]?.intValue.map { Double($0) } ?? 0
        
        // Extract foods
        let foodsArray = parsedJsonData?["foods"] ?? action.data["foods"]?.value
        let foods: [String] = {
            if let foodsArray = foodsArray as? [Any] {
                return foodsArray.compactMap { item -> String? in
                    if let str = item as? String {
                        return str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : str.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    return nil
                }
            } else if let foodsArray = action.data["foods"]?.arrayValue {
                return foodsArray.compactMap { item -> String? in
                    if let str = item as? String {
                        let cleaned = str.trimmingCharacters(in: .whitespacesAndNewlines)
                        return cleaned.isEmpty ? nil : cleaned
                    }
                    if let anyCodable = item as? AnyCodable, let str = anyCodable.stringValue {
                        let cleaned = str.trimmingCharacters(in: .whitespacesAndNewlines)
                        return cleaned.isEmpty ? nil : cleaned
                    }
                    return nil
                }
            }
            return []
        }()
        
        // Extract product name and brand
        let productName = (parsedJsonData?["productName"] as? String) ?? action.data["productName"]?.stringValue
        let brand = (parsedJsonData?["brand"] as? String) ?? action.data["brand"]?.stringValue
        
        // Extract serving size
        let servingSize = (parsedJsonData?["servingSize"] as? String) ?? action.data["servingSize"]?.stringValue
        
        // Extract confidence
        var confidence: Double = {
            if let parsedConfidence = parsedJsonData?["confidence"] as? Double {
                return parsedConfidence
            } else if let parsedConfidence = parsedJsonData?["confidence"] as? Int {
                return Double(parsedConfidence)
            } else if let actionConfidence = action.data["confidence"]?.doubleValue {
                return actionConfidence
            }
            return 0.85
        }()
        
        if confidence > 1.0 {
            confidence = confidence / 100.0
        }
        confidence = max(0.0, min(1.0, confidence))
        
        // Extract insights
        let insights: [String] = {
            if let parsedInsights = parsedJsonData?["insights"] as? [String], !parsedInsights.isEmpty {
                return parsedInsights
            } else if let parsedInsights = parsedJsonData?["insights"] as? [Any] {
                return parsedInsights.compactMap { $0 as? String }
            } else if let actionInsights = action.data["insights"]?.arrayValue?.compactMap({ $0 as? String }), !actionInsights.isEmpty {
                return actionInsights
            }
            return []
        }()
        
        // Extract alternatives
        let alternatives: [ProductAlternative] = {
            if let alternativesArray = parsedJsonData?["alternatives"] as? [[String: Any]] {
                return alternativesArray.compactMap { altDict -> ProductAlternative? in
                    guard let name = altDict["name"] as? String else { return nil }
                    let brand = altDict["brand"] as? String
                    let calories = (altDict["calories"] as? Double) ?? (altDict["calories"] as? Int).map { Double($0) } ?? 0
                    let protein = (altDict["protein"] as? Double) ?? (altDict["protein"] as? Int).map { Double($0) } ?? 0
                    let carbs = (altDict["carbs"] as? Double) ?? (altDict["carbs"] as? Int).map { Double($0) } ?? 0
                    let fat = (altDict["fat"] as? Double) ?? (altDict["fat"] as? Int).map { Double($0) } ?? 0
                    let reason = altDict["reason"] as? String
                    let savings = altDict["savings"] as? String
                    
                    return ProductAlternative(
                        name: name,
                        brand: brand,
                        calories: calories,
                        protein: protein,
                        carbs: carbs,
                        fat: fat,
                        reason: reason,
                        savings: savings
                    )
                }
            } else if let alternativesArray = action.data["alternatives"]?.arrayValue {
                return alternativesArray.compactMap { item -> ProductAlternative? in
                    // Try [String: AnyCodable] first
                    if let altDict = item as? [String: AnyCodable] {
                        guard let name = altDict["name"]?.stringValue else { return nil }
                        
                        let brand = altDict["brand"]?.stringValue
                        let calories = altDict["calories"]?.doubleValue ?? altDict["calories"]?.intValue.map { Double($0) } ?? 0
                        let protein = altDict["protein"]?.doubleValue ?? altDict["protein"]?.intValue.map { Double($0) } ?? 0
                        let carbs = altDict["carbs"]?.doubleValue ?? altDict["carbs"]?.intValue.map { Double($0) } ?? 0
                        let fat = altDict["fat"]?.doubleValue ?? altDict["fat"]?.intValue.map { Double($0) } ?? 0
                        let reason = altDict["reason"]?.stringValue
                        let savings = altDict["savings"]?.stringValue
                        
                        return ProductAlternative(
                            name: name,
                            brand: brand,
                            calories: calories,
                            protein: protein,
                            carbs: carbs,
                            fat: fat,
                            reason: reason,
                            savings: savings
                        )
                    }
                    // Fallback to [String: Any]
                    else if let altDict = item as? [String: Any] {
                        guard let name = altDict["name"] as? String else { return nil }
                        
                        let brand = altDict["brand"] as? String
                        let calories = (altDict["calories"] as? Double) ?? (altDict["calories"] as? Int).map { Double($0) } ?? 0
                        let protein = (altDict["protein"] as? Double) ?? (altDict["protein"] as? Int).map { Double($0) } ?? 0
                        let carbs = (altDict["carbs"] as? Double) ?? (altDict["carbs"] as? Int).map { Double($0) } ?? 0
                        let fat = (altDict["fat"] as? Double) ?? (altDict["fat"] as? Int).map { Double($0) } ?? 0
                        let reason = altDict["reason"] as? String
                        let savings = altDict["savings"] as? String
                        
                        return ProductAlternative(
                            name: name,
                            brand: brand,
                            calories: calories,
                            protein: protein,
                            carbs: carbs,
                            fat: fat,
                            reason: reason,
                            savings: savings
                        )
                    }
                    return nil
                }
            }
            return []
        }()
        
        // Extract recommendations
        let recommendations: [String] = {
            if let parsedRecs = parsedJsonData?["recommendations"] as? [String], !parsedRecs.isEmpty {
                return parsedRecs
            } else if let parsedRecs = parsedJsonData?["recommendations"] as? [Any] {
                return parsedRecs.compactMap { $0 as? String }
            } else if let actionRecs = action.data["recommendations"]?.arrayValue?.compactMap({ $0 as? String }), !actionRecs.isEmpty {
                return actionRecs
            }
            return []
        }()
        
        let nutrition = NutritionData(
            calories: Double(calories),
            protein: protein,
            carbs: carbs,
            fat: fat
        )
        
        // Detect meal type
        let detectedType = detectMealType(foods: foods, time: Date())
        
        // Only create parsedData if we have valid food data
        if !foods.isEmpty && nutrition.calories > 0 {
            parsedData = ParsedBarcodeData(
                foodItems: foods,
                productName: productName,
                brand: brand,
                nutrition: nutrition,
                servingSize: servingSize,
                insights: insights,
                alternatives: alternatives,
                recommendations: recommendations,
                confidence: confidence,
                detectedMealType: detectedType
            )
        }
    }
    
    private func parseFromText(_ text: String) {
        // Fallback text parsing (similar to FoodAnalysisView)
        let cleanedText = MarkdownFormatter.cleanMarkdown(text)
        
        // Extract nutrition
        let nutrition = parseNutrition(from: cleanedText)
        
        // Extract food items
        let foodItems = extractFoodItems(from: cleanedText)
        
        // Extract serving size
        let servingSize = extractServingSize(from: cleanedText)
        
        // Extract confidence
        let confidence = extractConfidence(from: cleanedText)
        
        // Extract insights
        let insights = extractInsights(from: cleanedText)
        
        // Detect meal type
        let detectedType = detectMealType(foods: foodItems, time: Date())
        
        if !foodItems.isEmpty && nutrition.calories > 0 {
            parsedData = ParsedBarcodeData(
                foodItems: foodItems,
                productName: foodItems.first,
                brand: nil,
                nutrition: nutrition,
                servingSize: servingSize,
                insights: insights,
                alternatives: [],
                recommendations: [],
                confidence: confidence,
                detectedMealType: detectedType
            )
        }
    }
    
    // MARK: - Helper Functions
    
    private func parseNutrition(from text: String) -> NutritionData {
        let caloriePattern = #"(\d+(?:\.\d+)?)\s*cal"#
        let calories = extractNumber(from: text, pattern: caloriePattern) ?? 0
        
        let proteinPattern = #"(\d+(?:\.\d+)?)\s*g\s*(?:pro|protein)"#
        let protein = extractNumber(from: text, pattern: proteinPattern) ?? 0
        
        let carbPattern = #"(\d+(?:\.\d+)?)\s*g\s*(?:car|carbs|carbohydrate)"#
        let carbs = extractNumber(from: text, pattern: carbPattern) ?? 0
        
        let fatPattern = #"(\d+(?:\.\d+)?)\s*g\s*(?:fat)"#
        let fat = extractNumber(from: text, pattern: fatPattern) ?? 0
        
        return NutritionData(calories: calories, protein: protein, carbs: carbs, fat: fat)
    }
    
    private func extractNumber(from text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Double(text[range])
    }
    
    private func extractFoodItems(from text: String) -> [String] {
        // Look for patterns like "contains X", "X and Y", etc.
        var items: [String] = []
        
        // Try to find product name
        let patterns = [
            #"product[:\s]+([A-Z][a-zA-Z\s]+)"#,
            #"([A-Z][a-zA-Z\s]+)\s+contains"#,
            #"([A-Z][a-zA-Z\s]+)\s+has"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let item = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !item.isEmpty {
                    items.append(item)
                    break
                }
            }
        }
        
        return items.isEmpty ? ["Scanned Product"] : items
    }
    
    private func extractServingSize(from text: String) -> String? {
        let patterns = [
            #"serving[:\s]+([^\.]+)"#,
            #"per\s+([^\.]+?)(?:\.|$)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
    
    private func extractConfidence(from text: String) -> Double {
        let lowercased = text.lowercased()
        if lowercased.contains("approximately") || lowercased.contains("around") || lowercased.contains("estimated") {
            return 0.6
        } else if lowercased.contains("exact") || lowercased.contains("precise") {
            return 0.95
        }
        return 0.75
    }
    
    private func extractInsights(from text: String) -> [String] {
        var insights: [String] = []
        
        // Look for bullet points or numbered lists
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") ||
               trimmed.range(of: #"^\d+[\.\)]"#, options: .regularExpression) != nil {
                let insight = trimmed
                    .replacingOccurrences(of: #"^[•\-\*\d+\.\)]\s*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !insight.isEmpty && insight.count > 10 {
                    insights.append(insight)
                }
            }
        }
        
        return insights
    }
    
    private func detectMealType(foods: [String], time: Date) -> FoodMealType {
        let hour = Calendar.current.component(.hour, from: time)
        let foodString = foods.joined(separator: " ").lowercased()
        
        // Check for snack keywords first
        let snackKeywords = ["snack", "chip", "candy", "cookie", "cracker", "bar", "granola", "trail mix", "nuts", "fruit", "apple", "banana", "orange", "grape", "grapes"]
        if snackKeywords.contains(where: { foodString.contains($0) }) {
            return .snack
        }
        
        if hour >= 5 && hour < 11 {
            return .breakfast
        } else if hour >= 11 && hour < 15 {
            return .lunch
        } else if hour >= 15 && hour < 21 {
            return .dinner
        } else {
            return .snack
        }
    }
    
    private func saveFood(data: ParsedBarcodeData) {
        isSaving = true
        
        Task {
            do {
                let foodName = data.productName ?? data.foodItems.first ?? "Scanned Product"
                let brandSuffix = data.brand != nil ? " (\(data.brand!))" : ""
                let fullName = "\(foodName)\(brandSuffix)"
                
                try await FoodTrackingService.shared.logFood(
                    name: fullName,
                    mealType: data.detectedMealType ?? mealType,
                    calories: data.nutrition?.calories ?? 0,
                    protein: data.nutrition?.protein ?? 0,
                    carbs: data.nutrition?.carbs ?? 0,
                    fat: data.nutrition?.fat ?? 0,
                    servingSize: data.servingSize,
                    notes: "Barcode: \(barcode)",
                    source: .barcode // Mark as barcode-scanned food
                )
                
                await MainActor.run {
                    isSaving = false
                    onSave()
                    dismiss()
                }
            } catch {
                print("❌ [Barcode] Error saving: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
    
    private func processQuestion(_ question: String) async {
        isProcessingQuestion = true
        defer { isProcessingQuestion = false }
        
        // TODO: Implement question processing similar to FoodAnalysisView
        // For now, just dismiss
        await MainActor.run {
            showingQuestionInput = false
        }
    }
}

// MARK: - Data Models

struct ParsedBarcodeData {
    let foodItems: [String]
    let productName: String?
    let brand: String?
    let nutrition: NutritionData?
    let servingSize: String?
    let insights: [String]
    let alternatives: [ProductAlternative]
    let recommendations: [String]
    let confidence: Double
    let detectedMealType: FoodMealType?
}

struct ProductAlternative: Identifiable {
    let id = UUID()
    let name: String
    let brand: String?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let reason: String?
    let savings: String?
}

// MARK: - UI Components

struct ProductHeaderCard: View {
    let productName: String
    let brand: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(productName)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            if let brand = brand {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 12))
                    Text(brand)
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct AlternativesCard: View {
    let alternatives: [ProductAlternative]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 16, weight: .semibold))
                Text("Healthier Alternatives")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            
            ForEach(alternatives) { alternative in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(alternative.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if let brand = alternative.brand {
                            Text(brand)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    if let reason = alternative.reason {
                        Text(reason)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    HStack(spacing: 12) {
                        NutritionBadge(label: "Cal", value: Int(alternative.calories))
                        NutritionBadge(label: "P", value: Int(alternative.protein), unit: "g")
                        NutritionBadge(label: "C", value: Int(alternative.carbs), unit: "g")
                        NutritionBadge(label: "F", value: Int(alternative.fat), unit: "g")
                    }
                    
                    if let savings = alternative.savings {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                            Text(savings)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Color(hex: "4CAF50"))
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct RecommendationsCard: View {
    let recommendations: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Recommendations")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            
            ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "F7931F"))
                        .frame(width: 24, height: 24)
                        .background(Color(hex: "F7931F").opacity(0.2))
                        .clipShape(Circle())
                    
                    Text(recommendation)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Missing Components

struct MealTypeBadge: View {
    let mealType: FoodMealType
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: mealTypeIcon)
                .font(.system(size: 14))
            Text(mealType.rawValue)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "F7931F").opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "F7931F"), lineWidth: 1)
        )
    }
    
    private var mealTypeIcon: String {
        switch mealType {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "leaf.fill"
        }
    }
}

struct EnhancedNutritionCard: View {
    let nutrition: NutritionData
    let servingSize: String?
    let confidence: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Nutrition Facts")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                if confidence < 1.0 {
                    Text("\(Int(confidence * 100))%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            .foregroundColor(.white)
            
            // Serving size
            if let servingSize = servingSize {
                Text("Serving Size: \(servingSize)")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Calories
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(nutrition.calories))")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color(hex: "F7931F"))
                Text("Calories")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.vertical, 8)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Macros
            VStack(spacing: 12) {
                macroRow(label: "Protein", value: nutrition.protein, unit: "g", color: Color(hex: "4CAF50"))
                macroRow(label: "Carbs", value: nutrition.carbs, unit: "g", color: Color(hex: "2196F3"))
                macroRow(label: "Fat", value: nutrition.fat, unit: "g", color: Color(hex: "FF9800"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func macroRow(label: String, value: Double, unit: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            Spacer()
            Text("\(String(format: "%.1f", value)) \(unit)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

struct InsightsCard: View {
    let insights: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Insights")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            
            ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                HStack(alignment: .top, spacing: 10) {
                    Text("•")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "F7931F"))
                    Text(insight)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct EmptyFoodStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Product Data Found")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text("We couldn't find nutrition information for this product. Try scanning again or search manually.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

