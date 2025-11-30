//
//  CategorySelectorView.swift
//  Track Infrastructure
//
//  Copied from Do./ViewControllers/Tracking/CategorySelectorView.swift
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

struct CategorySelectorView: View {
    @Binding var isPresented: Bool
    @Binding var selectedCategory: Int
    let categories: [(name: String, icon: String)]
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation {
                        isPresented = false
                    }
                }
            
            VStack(spacing: 0) {
                // Bottom sheet handle
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                
                // Header with current category
                HStack(spacing: 20) {
                    // Left arrow
                    Button(action: {
                        withAnimation {
                            let newIndex = (selectedCategory - 1 + categories.count) % categories.count
                            // This will trigger the binding's setter which will call the delegate
                            selectedCategory = newIndex
                            // Close the sheet after a short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isPresented = false
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    // Current category
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 1.0, green: 0.8, blue: 0.0),
                                            Color(red: 1.0, green: 0.4, blue: 0.0)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: categories[selectedCategory].icon)
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        
                        Text(categories[selectedCategory].name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    // Right arrow
                    Button(action: {
                        withAnimation {
                            let newIndex = (selectedCategory + 1) % categories.count
                            // This will trigger the binding's setter which will call the delegate
                            selectedCategory = newIndex
                            // Close the sheet after a short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isPresented = false
                            }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 20)
                
                // Categories grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(Array(categories.enumerated()), id: \.offset) { index, category in
                            CategoryCard(
                                name: category.name,
                                icon: category.icon,
                                isSelected: index == selectedCategory
                            )
                            .onTapGesture {
                                withAnimation {
                                    selectedCategory = index
                                    isPresented = false
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.1, green: 0.1, blue: 0.2),
                                Color(red: 0.05, green: 0.05, blue: 0.1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .frame(maxHeight: UIScreen.main.bounds.height * 0.8)
            .transition(.move(edge: .bottom))
        }
    }
}

struct CategoryCard: View {
    let name: String
    let icon: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.8, blue: 0.0),
                                Color(red: 1.0, green: 0.4, blue: 0.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            
            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
        )
    }
}

// Preview provider for development
struct CategorySelectorView_Previews: PreviewProvider {
    static var previews: some View {
        CategorySelectorView(
            isPresented: .constant(true),
            selectedCategory: .constant(0),
            categories: [
                ("Running", "figure.run"),
                ("Gym", "dumbbell.fill"),
                ("Cycling", "bicycle"),
                ("Hiking", "figure.hiking"),
                ("Food", "fork.knife"),
                ("Meditation", "sparkles"),
                ("Sports", "sportscourt"),
                ("Walking", "figure.walk"),
                ("Swimming", "figure.pool.swim")
            ]
        )
    }
}

