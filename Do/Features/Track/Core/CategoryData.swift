//
//  CategoryData.swift
//  Track Infrastructure
//
//  Category definitions for Track infrastructure
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

/// Category data structure for Track infrastructure
struct CategoryData {
    /// Category titles in order
    static let titles = ["Running", "Gym", "Cycling", "Hiking", "Walking", "Swimming", "Food", "Meditation", "Sports"]
    
    /// Category icon names in order (SF Symbols)
    static let icons = ["figure.run", "figure.strengthtraining.traditional", "figure.outdoor.cycle", "figure.hiking", "figure.walk", "figure.pool.swim", "fork.knife", "sparkles", "sportscourt"]
    
    /// Number of categories
    static let count = titles.count
    
    /// Get category title for index
    static func title(for index: Int) -> String? {
        guard index >= 0 && index < titles.count else { return nil }
        return titles[index]
    }
    
    /// Get category icon for index
    static func icon(for index: Int) -> String? {
        guard index >= 0 && index < icons.count else { return nil }
        return icons[index]
    }
    
    /// Get category tuple (title, icon) for index
    static func category(for index: Int) -> (title: String, icon: String)? {
        guard let title = title(for: index),
              let icon = icon(for: index) else { return nil }
        return (title, icon)
    }
}

