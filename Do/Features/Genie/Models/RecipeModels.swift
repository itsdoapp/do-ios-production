import Foundation

// MARK: - Recipe Model

struct Recipe: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let ingredients: [String]
    let steps: [RecipeStep]
    let prepTime: Int? // in minutes
    let cookTime: Int? // in minutes
    let servings: Int?
    let calories: Int?
    let protein: Double? // in grams
    let carbs: Double? // in grams
    let fat: Double? // in grams
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        ingredients: [String],
        steps: [RecipeStep],
        prepTime: Int? = nil,
        cookTime: Int? = nil,
        servings: Int? = nil,
        calories: Int? = nil,
        protein: Double? = nil,
        carbs: Double? = nil,
        fat: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.ingredients = ingredients
        self.steps = steps
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.servings = servings
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
    
    var totalTime: Int {
        (prepTime ?? 0) + (cookTime ?? 0)
    }
    
    /// Check if recipe has any nutrition information
    var hasNutritionInfo: Bool {
        calories != nil || protein != nil || carbs != nil || fat != nil
    }
    
    // MARK: - Parsing
    
    /// Parse multiple recipes from text suggestions and analysis
    static func parseMultiple(from suggestions: [String], analysis: String) -> [Recipe] {
        var recipes: [Recipe] = []
        var seenNames = Set<String>()
        
        // Try to extract structured recipes from suggestions
        for suggestion in suggestions {
            let trimmed = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip if it's just a number or markdown formatting
            if trimmed.matches(pattern: "^\\d+\\.|^\\*\\*") {
                continue
            }
            
            // Try to parse as a recipe
            if let recipe = parseRecipe(from: trimmed, analysis: analysis) {
                let lowercasedName = recipe.name.lowercased()
                if !seenNames.contains(lowercasedName) {
                    seenNames.insert(lowercasedName)
                    recipes.append(recipe)
                }
            }
        }
        
        // If no structured recipes found, create simple recipes from suggestions
        if recipes.isEmpty {
            for suggestion in suggestions {
                let trimmed = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && !trimmed.matches(pattern: "^\\d+\\.|^\\*\\*") {
                    let recipe = Recipe(
                        name: trimmed,
                        description: "A delicious meal suggestion",
                        ingredients: extractIngredients(from: trimmed),
                        steps: []
                    )
                    let lowercasedName = recipe.name.lowercased()
                    if !seenNames.contains(lowercasedName) {
                        seenNames.insert(lowercasedName)
                        recipes.append(recipe)
                    }
                }
            }
        }
        
        return recipes
    }
    
    private static func parseRecipe(from text: String, analysis: String) -> Recipe? {
        // Simple parsing - look for recipe name and ingredients
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        guard !lines.isEmpty else { return nil }
        
        // First line is usually the recipe name
        let name = lines[0].replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^\\*\\*", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\*\\*$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        
        guard !name.isEmpty else { return nil }
        
        // Extract ingredients from remaining lines or from the text
        let ingredients = extractIngredients(from: text)
        
        // Extract steps
        let steps = extractSteps(from: text)
        
        return Recipe(
            name: name,
            description: analysis.isEmpty ? "A delicious recipe" : analysis,
            ingredients: ingredients,
            steps: steps
        )
    }
    
    private static func extractIngredients(from text: String) -> [String] {
        var ingredients: [String] = []
        
        // Look for ingredient patterns
        let patterns = [
            #"[-•]\s*([^,\n]+)"#,
            #"(\d+\s*(?:cup|tbsp|tsp|oz|g|lb|kg|ml|l|piece|pieces|clove|cloves)\s+[^,\n]+)"#,
            #"([A-Z][a-z]+(?:\s+[a-z]+)*)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if match.numberOfRanges > 1,
                       let range = Range(match.range(at: 1), in: text) {
                        let ingredient = String(text[range]).trimmingCharacters(in: .whitespaces)
                        if !ingredient.isEmpty && ingredient.count < 100 {
                            ingredients.append(ingredient)
                        }
                    }
                }
            }
        }
        
        return ingredients.isEmpty ? ["Ingredients to be determined"] : ingredients
    }
    
    private static func extractSteps(from text: String) -> [RecipeStep] {
        var steps: [RecipeStep] = []
        let lines = text.components(separatedBy: .newlines)
        
        var stepNumber = 1
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip empty lines, headers, and ingredient lists
            if trimmed.isEmpty || trimmed.matches(pattern: "^\\d+\\.|^\\*\\*|^[-•]") {
                continue
            }
            
            // Check if it looks like a step
            if trimmed.count > 10 && !trimmed.matches(pattern: "^[A-Z][^a-z]*$") {
                steps.append(RecipeStep(
                    number: stepNumber,
                    instruction: trimmed
                ))
                stepNumber += 1
            }
        }
        
        return steps
    }
}

// MARK: - Recipe Step Model

struct RecipeStep: Identifiable, Codable {
    let id: UUID
    let number: Int
    let instruction: String
    let duration: Int? // in minutes
    let temperature: String? // e.g., "350°F"
    
    init(
        id: UUID = UUID(),
        number: Int,
        instruction: String,
        duration: Int? = nil,
        temperature: String? = nil
    ) {
        self.id = id
        self.number = number
        self.instruction = instruction
        self.duration = duration
        self.temperature = temperature
    }
}

