//
//  GroceryListView.swift
//  Do
//
//  Modern grocery list view with impressive UI
//

import SwiftUI

struct GroceryListView: View {
    let groceryList: GroceryList
    @Environment(\.dismiss) var dismiss
    @State private var items: [GroceryListItem]
    @State private var showingShareSheet = false
    @State private var showingStoreSuggestions = false
    
    init(groceryList: GroceryList) {
        self.groceryList = groceryList
        _items = State(initialValue: groceryList.items)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Futuristic gradient background
                LinearGradient(
                    colors: [
                        Color.brandBlue,
                        Color("1A2148"),
                        Color("1E2740")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with progress
                        headerView
                            .padding(.horizontal)
                            .padding(.top)
                        
                        // Progress ring
                        progressRingView
                            .padding(.horizontal)
                        
                        // Store suggestions
                        if let stores = groceryList.storeSuggestions, !stores.isEmpty {
                            storeSuggestionsView(stores)
                                .padding(.horizontal)
                        }
                        
                        // Items by category
                        itemsByCategoryView
                            .padding(.horizontal)
                        
                        // Summary card
                        summaryCard
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Grocery List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { shareList() }) {
                            Label("Share List", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: { clearChecked() }) {
                            Label("Clear Checked", systemImage: "checkmark.circle")
                        }
                        
                        Button(role: .destructive, action: { deleteList() }) {
                            Label("Delete List", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(groceryList.name)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(items.count) items")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Completion badge
                if groceryList.progress == 1.0 {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.green)
                        Text("Complete")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }
    
    // MARK: - Progress Ring
    
    private var progressRingView: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 12)
                .frame(width: 120, height: 120)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: groceryList.progress)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.brandOrange,
                            Color("FF6B35"),
                            Color.brandOrange
                        ],
                        center: .center,
                        angle: .degrees(-90)
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: groceryList.progress)
            
            // Center text
            VStack(spacing: 4) {
                Text("\(Int(groceryList.progress * 100))%")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("\(groceryList.checkedItems)/\(groceryList.totalItems)")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Store Suggestions
    
    private func storeSuggestionsView(_ stores: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color.brandOrange)
                
                Text("Store Suggestions")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(stores, id: \.self) { store in
                        StoreCard(name: store)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Items by Category
    
    private var itemsByCategoryView: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(groceryList.itemsByCategory.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { category in
                if let categoryItems = groceryList.itemsByCategory[category] {
                    CategorySection(
                        category: category,
                        items: categoryItems,
                        onItemToggled: { itemId in
                            toggleItem(itemId)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Summary")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            HStack(spacing: 24) {
                SummaryStat(
                    icon: "cart.fill",
                    label: "Total Items",
                    value: "\(items.count)"
                )
                
                SummaryStat(
                    icon: "checkmark.circle.fill",
                    label: "Checked",
                    value: "\(groceryList.checkedItems)",
                    color: .green
                )
                
                if let cost = groceryList.estimatedCost {
                    SummaryStat(
                        icon: "dollarsign.circle.fill",
                        label: "Est. Cost",
                        value: "$\(String(format: "%.0f", cost))",
                        color: Color.brandOrange
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.brandOrange.opacity(0.3),
                                    Color("FF6B35").opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Actions
    
    private func toggleItem(_ itemId: String) {
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            items[index].toggleChecked()
        }
    }
    
    private func shareList() {
        showingShareSheet = true
    }
    
    private func clearChecked() {
        for index in items.indices {
            if items[index].isChecked {
                items[index].toggleChecked()
            }
        }
    }
    
    private func deleteList() {
        // Handle deletion
        dismiss()
    }
}

// MARK: - Supporting Views

struct CategorySection: View {
    let category: GroceryFoodCategory
    let items: [GroceryListItem]
    let onItemToggled: (String) -> Void
    
    var categoryIcon: String {
        switch category {
        case .protein: return "🥩"
        case .carbohydrate: return "🍞"
        case .vegetable: return "🥬"
        case .fruit: return "🍎"
        case .dairy: return "🥛"
        case .grain: return "🌾"
        case .fat: return "🥑"
        case .beverage: return "🥤"
        case .other: return "📦"
        }
    }
    
    var categoryColor: Color {
        switch category {
        case .protein: return .red
        case .carbohydrate: return .orange
        case .vegetable: return .green
        case .fruit: return .pink
        case .dairy: return .blue
        case .grain: return .yellow
        case .fat: return .purple
        case .beverage: return .cyan
        case .other: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(categoryIcon)
                    .font(.system(size: 24))
                
                Text(category.rawValue.capitalized)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(items.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor.opacity(0.2))
                    .cornerRadius(8)
            }
            
            VStack(spacing: 8) {
                ForEach(items) { item in
                    GroceryItemRow(item: item) {
                        onItemToggled(item.id)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(categoryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct GroceryItemRow: View {
    let item: GroceryListItem
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                // Checkbox
                ZStack {
                    Circle()
                        .fill(item.isChecked ? Color.brandOrange : Color.clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(item.isChecked ? Color.brandOrange : Color.white.opacity(0.3), lineWidth: 2)
                        )
                    
                    if item.isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Item info
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.ingredient.displayText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(item.isChecked ? .white.opacity(0.6) : .white)
                        .strikethrough(item.isChecked)
                    
                    if let price = item.estimatedPrice {
                        Text("~$\(String(format: "%.2f", price))")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Category icon
                Image(systemName: categoryIcon(for: item.ingredient.category))
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
    
    private func categoryIcon(for category: GroceryFoodCategory) -> String {
        switch category {
        case .protein: return "flame.fill"
        case .carbohydrate: return "leaf.fill"
        case .vegetable: return "carrot.fill"
        case .fruit: return "applelogo"
        case .dairy: return "drop.fill"
        case .grain: return "circle.grid.2x2.fill"
        case .fat: return "circle.fill"
        case .beverage: return "cup.and.saucer.fill"
        case .other: return "cube.fill"
        }
    }
}

struct StoreCard: View {
    let name: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "storefront.fill")
                .font(.system(size: 14))
                .foregroundColor(Color.brandOrange)
            
            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
    }
}

struct SummaryStat: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .white
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

