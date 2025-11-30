import Foundation

// MARK: - Grocery List Models

struct GroceryList: Identifiable, Codable {
    let id: String
    var name: String
    var createdAt: Date
    var items: [GroceryListItem]
    var estimatedCost: Double?
    var storeSuggestions: [String]?
    
    var totalItems: Int {
        items.count
    }
    
    var checkedItems: Int {
        items.filter { $0.isChecked }.count
    }

    var progress: Double {
        guard totalItems > 0 else { return 0 }
        return Double(checkedItems) / Double(totalItems)
    }
    
    var itemsByCategory: [GroceryFoodCategory: [GroceryListItem]] {
        Dictionary(grouping: items, by: { $0.ingredient.category })
    }
}

struct GroceryListItem: Identifiable, Codable {
    let id: String
    var ingredient: GroceryIngredient
    var isChecked: Bool
    var notes: String?
    var estimatedPrice: Double?
    
    mutating func toggleChecked() {
        isChecked.toggle()
    }
}

struct GroceryIngredient: Identifiable, Codable {
    let id: String
    var name: String
    var amount: Double
    var unit: String
    var category: GroceryFoodCategory
    var notes: String?
    var isOptional: Bool
    
    var displayText: String {
        let amountString = amount == 0 ? "" : String(format: "%.2f", amount).replacingOccurrences(of: ".00", with: "")
        let unitString = unit.isEmpty ? "" : " \(unit)"
        return "\(amountString)\(unitString) \(name)".trimmingCharacters(in: .whitespaces)
    }
}

enum GroceryFoodCategory: String, Codable, CaseIterable {
    case protein
    case carbohydrate
    case vegetable
    case fruit
    case dairy
    case grain
    case fat
    case beverage
    case other
}


