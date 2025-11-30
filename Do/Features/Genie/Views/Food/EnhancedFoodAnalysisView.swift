//
//  EnhancedFoodAnalysisView.swift
//  Do
//
//  Enhanced food analysis view with editing, sharing, cookbook integration, and more
//

import SwiftUI
import UIKit

struct EnhancedFoodAnalysisView: View {
    let image: UIImage?
    let analysis: GenieQueryResponse
    let mealType: FoodMealType
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var parsedData: ParsedFoodData?
    @State private var editableFoodItems: [EditableFoodItem] = []
    @State private var editedNutrition: NutritionData?
    @State private var mealName: String = ""
    @State private var isSaving = false
    @State private var showingEditSheet = false
    @State private var showingShareSheet = false
    @State private var showingCookbookSheet = false
    @State private var showingRecipeSheet = false
    @State private var showingTrackAgain = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var isRecalculating = false
    @State private var shareImage: UIImage?
    
    // For recipe attachment
    @State private var attachedRecipe: Recipe?
    @State private var showingRecipeEditor = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Modern gradient background
                LinearGradient(
                    colors: [
                        Color(hex: "0F163E"),
                        Color(hex: "1A1F4A"),
                        Color(hex: "0F163E")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Food image with modern styling
                        if let image = image {
                            ModernFoodImageView(image: image)
                                .padding(.horizontal)
                        }
                        
                        // Parse data on appear
                        if parsedData == nil {
                            ProgressView()
                                .tint(Color(hex: "F7931F"))
                                .padding()
                        } else if let data = parsedData {
                            // Meal name input
                            MealNameInputCard(mealName: $mealName)
                                .padding(.horizontal)
                            
                            // Editable food items
                            EditableFoodItemsCard(
                                items: $editableFoodItems,
                                onAdd: addFoodItem,
                                onRemove: removeFoodItem,
                                onEdit: editFoodItem,
                                isRecalculating: $isRecalculating
                            )
                            .padding(.horizontal)
                            .onChange(of: editableFoodItems) { _ in
                                recalculateNutrition()
                            }
                            
                            // Nutrition card with recalculated values
                            if let nutrition = editedNutrition ?? data.nutrition {
                                EnhancedNutritionCardWithRecalc(
                                    nutrition: nutrition,
                                    servingSize: data.servingSize,
                                    confidence: data.confidence,
                                    isRecalculated: editedNutrition != nil
                                )
                                .padding(.horizontal)
                            }
                            
                            // Meal type badge
                            MealTypeBadge(mealType: data.detectedMealType ?? mealType)
                                .padding(.horizontal)
                            
                            // Insights card
                            if !data.insights.isEmpty {
                                InsightsCard(insights: data.insights)
                                    .padding(.horizontal)
                            }
                            
                            // Action buttons
                            ActionButtonsSection(
                                onEdit: { showingEditSheet = true },
                                onShare: { generateShareImage() },
                                onCookbook: { showingCookbookSheet = true },
                                onRecipe: { showingRecipeSheet = true },
                                onTrackAgain: { showingTrackAgain = true },
                                hasRecipe: attachedRecipe != nil
                            )
                            .padding(.horizontal)
                            
                            // Save button
                            ModernSaveButton(
                                isSaving: isSaving,
                                onSave: { saveFood(data: data) }
                            )
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Food Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                parseAnalysis()
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            FoodItemEditSheet(
                items: $editableFoodItems,
                onSave: {
                    recalculateNutrition()
                    showingEditSheet = false
                }
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            if let shareImage = shareImage {
                MealShareSheet(activityItems: [shareImage])
            }
        }
        .sheet(isPresented: $showingCookbookSheet) {
            AddToCookbookSheet(
                mealName: mealName.isEmpty ? (parsedData?.foodItems.joined(separator: ", ") ?? "Meal") : mealName,
                foodItems: editableFoodItems.map { $0.name },
                nutrition: editedNutrition ?? parsedData?.nutrition,
                image: image,
                onSave: { recipe in
                    attachedRecipe = recipe
                    showingCookbookSheet = false
                }
            )
        }
        .sheet(isPresented: $showingRecipeSheet) {
            RecipeAttachmentSheet(
                recipe: $attachedRecipe,
                onSave: {
                    showingRecipeSheet = false
                }
            )
        }
        .sheet(isPresented: $showingTrackAgain) {
            TrackAgainSheet(
                mealName: mealName.isEmpty ? (parsedData?.foodItems.joined(separator: ", ") ?? "Meal") : mealName,
                foodItems: editableFoodItems.map { $0.name },
                nutrition: editedNutrition ?? parsedData?.nutrition,
                mealType: parsedData?.detectedMealType ?? mealType,
                onTrack: {
                    saveFood(data: parsedData!)
                    showingTrackAgain = false
                }
            )
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Parsing
    
    private func parseAnalysis() {
        // Check if we have a nutrition_data action
        if let actions = analysis.actions,
           let nutritionAction = actions.first(where: { $0.type == "nutrition_data" }) {
            parseFromAction(nutritionAction)
        } else {
            // Parse from text response
            parseFromText(analysis.response)
        }
    }
    
    private func parseFromAction(_ action: GenieAction) {
        // Similar to original implementation but create editable items
        var parsedJsonData: [String: Any]?
        
        if let analysisString = action.data["analysis"]?.stringValue,
           let jsonData = analysisString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let dataDict = json["data"] as? [String: Any] {
            parsedJsonData = dataDict
        }
        
        let caloriesValue = parsedJsonData?["calories"] ?? action.data["calories"]?.value
        let macrosDict = parsedJsonData?["macros"] ?? action.data["macros"]?.value
        
        guard let calories = (caloriesValue as? Int) ?? (caloriesValue as? Double).map({ Int($0) }),
              let macrosData = macrosDict as? [String: Any] else {
            parseFromText(analysis.response)
            return
        }
        
        let protein = (macrosData["protein"] as? Double) ?? (macrosData["protein"] as? Int).map { Double($0) } ?? 0
        let carbs = (macrosData["carbs"] as? Double) ?? (macrosData["carbs"] as? Int).map { Double($0) } ?? 0
        let fat = (macrosData["fat"] as? Double) ?? (macrosData["fat"] as? Int).map { Double($0) } ?? 0
        
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
                        return str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : str.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    if let anyCodable = item as? AnyCodable, let str = anyCodable.stringValue {
                        return str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : str.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    return nil
                }
            }
            return []
        }()
        
        let servingSize = (parsedJsonData?["servingSize"] as? String) ?? action.data["servingSize"]?.stringValue
        
        let confidence: Double = {
            if let parsedConfidence = parsedJsonData?["confidence"] as? Double {
                return parsedConfidence
            } else if let parsedConfidence = parsedJsonData?["confidence"] as? Int {
                return Double(parsedConfidence)
            } else if let actionConfidence = action.data["confidence"]?.doubleValue {
                return actionConfidence
            }
            return 0.85
        }()
        
        let insights: [String] = {
            if let parsedInsights = parsedJsonData?["insights"] as? [String], !parsedInsights.isEmpty {
                return parsedInsights
            } else if let parsedInsights = parsedJsonData?["insights"] as? [Any] {
                return parsedInsights.compactMap { $0 as? String }
            } else if let actionInsights = action.data["insights"]?.arrayValue?.compactMap({ $0 as? String }), !actionInsights.isEmpty {
                return actionInsights
            } else {
                return []
            }
        }()
        
        let nutrition = NutritionData(
            calories: Double(calories),
            protein: protein,
            carbs: carbs,
            fat: fat
        )
        
        let detectedType = detectMealType(foods: foods, time: Date())
        
        if !foods.isEmpty && nutrition.calories > 0 {
            parsedData = ParsedFoodData(
                foodItems: foods,
                nutrition: nutrition,
                servingSize: servingSize,
                insights: insights,
                confidence: confidence,
                detectedMealType: detectedType
            )
            
            // Initialize editable items
            editableFoodItems = foods.map { EditableFoodItem(name: $0, portion: 1.0) }
            editedNutrition = nil
        }
    }
    
    private func parseFromText(_ text: String) {
        // Simplified - use original parsing logic
        let cleanedText = MarkdownFormatter.cleanMarkdown(text)
        let nutrition = parseNutrition(from: cleanedText)
        let foodItems = extractFoodItems(from: cleanedText)
        let servingSize = extractServingSize(from: cleanedText)
        let confidence = extractConfidence(from: cleanedText)
        let insights = extractInsights(from: cleanedText)
        let detectedMealType = detectMealType(foods: foodItems, time: Date())
        
        if !foodItems.isEmpty && nutrition != nil && nutrition!.calories > 0 {
            parsedData = ParsedFoodData(
                foodItems: foodItems,
                nutrition: nutrition,
                servingSize: servingSize,
                insights: insights,
                confidence: confidence,
                detectedMealType: detectedMealType
            )
            
            editableFoodItems = foodItems.map { EditableFoodItem(name: $0, portion: 1.0) }
            editedNutrition = nil
        }
    }
    
    // MARK: - Nutrition Recalculation
    
    private func recalculateNutrition() {
        guard !editableFoodItems.isEmpty else { return }
        
        isRecalculating = true
        
        Task {
            var totalCalories: Double = 0
            var totalProtein: Double = 0
            var totalCarbs: Double = 0
            var totalFat: Double = 0
            
            for item in editableFoodItems {
                do {
                    let nutritionInfo = try await NutritionService.shared.getNutritionInfo(for: item.name)
                    let multiplier = item.portion
                    totalCalories += nutritionInfo.calories * multiplier
                    totalProtein += nutritionInfo.protein * multiplier
                    totalCarbs += nutritionInfo.carbs * multiplier
                    totalFat += nutritionInfo.fat * multiplier
                } catch {
                    print("⚠️ [FoodAnalysis] Could not fetch nutrition for \(item.name): \(error)")
                    // Use original nutrition if available, divided by item count
                    if let originalNutrition = parsedData?.nutrition {
                        let perItem = originalNutrition.calories / Double(editableFoodItems.count)
                        totalCalories += perItem * item.portion
                        totalProtein += (originalNutrition.protein / Double(editableFoodItems.count)) * item.portion
                        totalCarbs += (originalNutrition.carbs / Double(editableFoodItems.count)) * item.portion
                        totalFat += (originalNutrition.fat / Double(editableFoodItems.count)) * item.portion
                    }
                }
            }
            
            await MainActor.run {
                editedNutrition = NutritionData(
                    calories: totalCalories,
                    protein: totalProtein,
                    carbs: totalCarbs,
                    fat: totalFat
                )
                isRecalculating = false
            }
        }
    }
    
    // MARK: - Food Item Management
    
    private func addFoodItem() {
        editableFoodItems.append(EditableFoodItem(name: "", portion: 1.0))
    }
    
    private func removeFoodItem(_ item: EditableFoodItem) {
        editableFoodItems.removeAll { $0.id == item.id }
    }
    
    private func editFoodItem(_ item: EditableFoodItem) {
        // Handled in edit sheet
    }
    
    // MARK: - Share
    
    private func generateShareImage() {
        // Create a shareable image of the meal analysis
        Task {
            let shareCard = ShareableMealCard(
                mealName: mealName.isEmpty ? (parsedData?.foodItems.joined(separator: ", ") ?? "Meal") : mealName,
                foodItems: editableFoodItems.map { $0.name },
                nutrition: editedNutrition ?? parsedData?.nutrition,
                image: image
            )
            
            let hostingController = UIHostingController(rootView: shareCard)
            hostingController.view.frame = CGRect(origin: .zero, size: CGSize(width: 400, height: 600))
            hostingController.view.backgroundColor = UIColor.white
            
            hostingController.view.setNeedsLayout()
            hostingController.view.layoutIfNeeded()
            
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 600))
            let uiImage = renderer.image { _ in
                hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
            }
            
            await MainActor.run {
                shareImage = uiImage
                showingShareSheet = true
            }
        }
    }
    
    // MARK: - Save
    
    private func saveFood(data: ParsedFoodData) {
        isSaving = true
        
        Task {
            do {
                guard let nutrition = editedNutrition ?? data.nutrition else {
                    await MainActor.run {
                        isSaving = false
                    }
                    return
                }
                
                let foodName = mealName.isEmpty ? (editableFoodItems.map { $0.name }.joined(separator: ", ")) : mealName
                let mealType = data.detectedMealType ?? mealType
                
                try await FoodTrackingService.shared.logFood(
                    name: foodName,
                    mealType: mealType,
                    calories: nutrition.calories,
                    protein: nutrition.protein,
                    carbs: nutrition.carbs,
                    fat: nutrition.fat,
                    servingSize: data.servingSize,
                    notes: data.insights.isEmpty ? analysis.response : data.insights.joined(separator: ". "),
                    source: .ai,
                    recipeId: attachedRecipe?.id.uuidString
                )
                
                // Save recipe if attached
                if let recipe = attachedRecipe {
                    RecipeStorageService.shared.saveRecipe(recipe)
                }
                
                await MainActor.run {
                    isSaving = false
                    onSave()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save food: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    // MARK: - Helper Functions (from original)
    
    private func parseNutrition(from text: String) -> NutritionData? {
        // Use original implementation
        var calories: Double?
        var protein: Double?
        var carbs: Double?
        var fat: Double?
        
        let caloriePatterns = [
            #"(\d+)\s*cal(?:ories)?(?:\s*\(kcal\))?(?:\s*per\s*serving)?"#,
            #"calories?[:\s]+(\d+)"#,
            #"total\s*calories?[:\s]+(\d+)"#,
            #"(\d+)\s*kcal"#
        ]
        for pattern in caloriePatterns {
            if let value = extractNumber(from: text, pattern: pattern) {
                calories = value
                break
            }
        }
        
        guard let calories = calories else { return nil }
        
        return NutritionData(
            calories: calories,
            protein: protein ?? 0,
            carbs: carbs ?? 0,
            fat: fat ?? 0
        )
    }
    
    private func extractFoodItems(from text: String) -> [String] {
        // Use original implementation
        var items: [String] = []
        let patterns = [
            #"(?:food\s*items?|contains?|i\s*can\s*see|detected):\s*([^\.]+)"#,
            #"([A-Z][a-z]+(?:\s+[a-z]+)*)\s*(?:with|and)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if match.numberOfRanges > 1,
                       let range = Range(match.range(at: 1), in: text) {
                        let item = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !item.isEmpty && item.count < 50 {
                            items.append(item)
                        }
                    }
                }
            }
        }
        
        return items
    }
    
    private func extractServingSize(from text: String) -> String? {
        let patterns = [
            #"serving\s*size[:\s]+([^\.]+)"#,
            #"approximately\s*([^\.]+\s*(?:cup|g|oz|ml|piece|slice|serving))"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return nil
    }
    
    private func extractConfidence(from text: String) -> Double {
        let lowerText = text.lowercased()
        if lowerText.contains("clearly") || lowerText.contains("definitely") || lowerText.contains("certain") {
            return 0.9
        }
        if lowerText.contains("approximately") || lowerText.contains("around") || lowerText.contains("estimated") {
            return 0.7
        }
        if lowerText.contains("uncertain") || lowerText.contains("unclear") {
            return 0.5
        }
        return 0.8
    }
    
    private func extractInsights(from text: String) -> [String] {
        // Simplified - use original if needed
        return []
    }
    
    private func detectMealType(foods: [String], time: Date) -> FoodMealType {
        let hour = Calendar.current.component(.hour, from: time)
        let lowerFoods = foods.joined(separator: " ").lowercased()
        
        if hour >= 5 && hour < 11 {
            return .breakfast
        } else if hour >= 11 && hour < 16 {
            return .lunch
        } else if hour >= 16 && hour < 22 {
            return .dinner
        }
        return .snack
    }
    
    private func extractNumber(from text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Double(text[range])
    }
}

// MARK: - Supporting Types

struct EditableFoodItem: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var portion: Double // Multiplier for serving size
    
    static func == (lhs: EditableFoodItem, rhs: EditableFoodItem) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.portion == rhs.portion
    }
}

// MARK: - ParsedFoodData

struct ParsedFoodData {
    let foodItems: [String]
    let nutrition: NutritionData?
    let servingSize: String?
    let insights: [String]
    let confidence: Double
    let detectedMealType: FoodMealType?
}

// MARK: - UI Components

struct ModernFoodImageView: View {
    let image: UIImage
    
    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 280)
                .clipped()
            
            // Gradient overlay
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

struct MealNameInputCard: View {
    @Binding var mealName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "pencil")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "F7931F"))
                Text("Meal Name")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            TextField("Name this meal...", text: $mealName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "F7931F").opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct EditableFoodItemsCard: View {
    @Binding var items: [EditableFoodItem]
    let onAdd: () -> Void
    let onRemove: (EditableFoodItem) -> Void
    let onEdit: (EditableFoodItem) -> Void
    @Binding var isRecalculating: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "fork.knife")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "F7931F"))
                Text("Food Items")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "F7931F"))
                }
            }
            
            if isRecalculating {
                HStack {
                    ProgressView()
                        .tint(Color(hex: "F7931F"))
                    Text("Recalculating nutrition...")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.vertical, 8)
            }
            
            ForEach($items) { $item in
                EditableFoodItemRow(
                    item: $item,
                    onRemove: { onRemove(item) },
                    onPortionChange: { _ in
                        // Portion is already updated via binding
                    }
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "F7931F").opacity(0.15),
                            Color(hex: "FF6B35").opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "F7931F").opacity(0.3), lineWidth: 1)
        )
    }
}

struct EditableFoodItemRow: View {
    @Binding var item: EditableFoodItem
    let onRemove: () -> Void
    let onPortionChange: (Double) -> Void
    
    @State private var editingName = false
    @State private var editedName: String = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // Food name
            if editingName {
                TextField("Food name", text: $editedName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    .onSubmit {
                        item.name = editedName
                        editingName = false
                    }
                    .onAppear {
                        editedName = item.name
                    }
            } else {
                Text(item.name.isEmpty ? "Tap to edit" : item.name.capitalized)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        editedName = item.name
                        editingName = true
                    }
            }
            
            // Portion stepper
            HStack(spacing: 8) {
                Button(action: {
                    if item.portion > 0.25 {
                        item.portion -= 0.25
                        onPortionChange(item.portion)
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(Color(hex: "F7931F"))
                }
                
                Text(String(format: "%.2fx", item.portion))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(minWidth: 50)
                
                Button(action: {
                    item.portion += 0.25
                    onPortionChange(item.portion)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Color(hex: "F7931F"))
                }
            }
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

struct ActionButtonsSection: View {
    let onEdit: () -> Void
    let onShare: () -> Void
    let onCookbook: () -> Void
    let onRecipe: () -> Void
    let onTrackAgain: () -> Void
    let hasRecipe: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                MealActionButton(icon: "pencil", title: "Edit", color: .blue, action: onEdit)
                MealActionButton(icon: "square.and.arrow.up", title: "Share", color: .green, action: onShare)
            }
            
            HStack(spacing: 12) {
                MealActionButton(icon: "bookmark.fill", title: "Cookbook", color: Color(hex: "F7931F"), action: onCookbook)
                MealActionButton(icon: hasRecipe ? "checkmark.circle.fill" : "doc.text", title: hasRecipe ? "Recipe" : "Add Recipe", color: .purple, action: onRecipe)
            }
            
            MealActionButton(icon: "arrow.clockwise", title: "Track Again", color: .orange, action: onTrackAgain)
                .frame(maxWidth: .infinity)
        }
    }
}

struct MealActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.5), lineWidth: 1)
                    )
            )
        }
    }
}

struct ModernSaveButton: View {
    let isSaving: Bool
    let onSave: () -> Void
    
    var body: some View {
        Button(action: onSave) {
            HStack {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text(isSaving ? "Saving..." : "Save Food Log")
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
            .cornerRadius(16)
            .shadow(color: Color(hex: "F7931F").opacity(0.4), radius: 20, x: 0, y: 10)
        }
        .disabled(isSaving)
    }
}

// Note: EnhancedNutritionCard is defined in FoodAnalysisView.swift
// We'll use a wrapper to add the isRecalculated functionality
struct EnhancedNutritionCardWithRecalc: View {
    let nutrition: NutritionData
    let servingSize: String?
    let confidence: Double
    let isRecalculated: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Use the base EnhancedNutritionCard
            EnhancedNutritionCard(
                nutrition: nutrition,
                servingSize: servingSize,
                confidence: confidence
            )
            
            // Add recalculated badge if needed
            if isRecalculated {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text("Recalculated")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}

// Note: MacroCard and InsightsCard are defined in FoodAnalysisView.swift and shared between both views

// Placeholder views for sheets (to be implemented)
struct FoodItemEditSheet: View {
    @Binding var items: [EditableFoodItem]
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(items) { item in
                    Text(item.name)
                }
            }
            .navigationTitle("Edit Food Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddToCookbookSheet: View {
    let mealName: String
    let foodItems: [String]
    let nutrition: NutritionData?
    let image: UIImage?
    let onSave: (Recipe) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var recipeName: String = ""
    @State private var recipeDescription: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Recipe Details") {
                    TextField("Recipe Name", text: $recipeName)
                    TextField("Description", text: $recipeDescription, axis: .vertical)
                }
                
                Section("Ingredients") {
                    ForEach(foodItems, id: \.self) { item in
                        Text(item)
                    }
                }
            }
            .navigationTitle("Add to Cookbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let recipe = Recipe(
                            name: recipeName.isEmpty ? mealName : recipeName,
                            description: recipeDescription.isEmpty ? "A delicious meal" : recipeDescription,
                            ingredients: foodItems,
                            steps: [],
                            calories: nutrition.map { Int($0.calories) }
                        )
                        onSave(recipe)
                        dismiss()
                    }
                }
            }
            .onAppear {
                recipeName = mealName
            }
        }
    }
}

struct RecipeAttachmentSheet: View {
    @Binding var recipe: Recipe?
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recipeStorage = RecipeStorageService.shared
    
    var body: some View {
        NavigationView {
            List {
                ForEach(recipeStorage.savedRecipes) { savedRecipe in
                    Button(action: {
                        recipe = savedRecipe
                        onSave()
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(savedRecipe.name)
                                    .font(.headline)
                                Text(savedRecipe.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if recipe?.id == savedRecipe.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Attach Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TrackAgainSheet: View {
    let mealName: String
    let foodItems: [String]
    let nutrition: NutritionData?
    let mealType: FoodMealType
    let onTrack: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMealType: FoodMealType
    
    init(mealName: String, foodItems: [String], nutrition: NutritionData?, mealType: FoodMealType, onTrack: @escaping () -> Void) {
        self.mealName = mealName
        self.foodItems = foodItems
        self.nutrition = nutrition
        self.mealType = mealType
        self.onTrack = onTrack
        _selectedMealType = State(initialValue: mealType)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Meal Details") {
                    Text(mealName)
                    Picker("Meal Type", selection: $selectedMealType) {
                        ForEach([FoodMealType.breakfast, .lunch, .dinner, .snack], id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
                
                Section("Nutrition") {
                    if let nutrition = nutrition {
                        Text("Calories: \(Int(nutrition.calories))")
                        Text("Protein: \(Int(nutrition.protein))g")
                        Text("Carbs: \(Int(nutrition.carbs))g")
                        Text("Fat: \(Int(nutrition.fat))g")
                    }
                }
            }
            .navigationTitle("Track Again")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Track") {
                        onTrack()
                    }
                }
            }
            .onAppear {
                selectedMealType = mealType
            }
        }
    }
}

struct ShareableMealCard: View {
    let mealName: String
    let foodItems: [String]
    let nutrition: NutritionData?
    let image: UIImage?
    
    var body: some View {
        VStack(spacing: 20) {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(16)
            }
            
            Text(mealName)
                .font(.system(size: 24, weight: .bold))
            
            if let nutrition = nutrition {
                VStack(spacing: 8) {
                    Text("\(Int(nutrition.calories)) Calories")
                        .font(.system(size: 32, weight: .bold))
                    Text("P: \(Int(nutrition.protein))g • C: \(Int(nutrition.carbs))g • F: \(Int(nutrition.fat))g")
                        .font(.system(size: 16))
                }
            }
        }
        .padding()
        .frame(width: 400, height: 600)
        .background(Color.white)
    }
}

// Note: ShareSheet should be defined in a shared location or use UIActivityViewController directly
// For now, we'll use a local implementation with a different name to avoid conflicts
struct MealShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

