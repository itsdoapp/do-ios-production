//
//  CategorySelectionProtocols.swift
//  Track Infrastructure
//
//  Extracted from ModernRunTrackerViewController.swift
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit
import SwiftUI

// MARK: - Category Selection Delegate

/// Protocol for handling category selection across tracker views
protocol CategorySelectionDelegate: AnyObject {
    func didSelectCategory(at index: Int)
    
    /// Optional property to track the current selected category index
    var currentSelectedCategoryIndex: Int? { get }
}

/// Protocol that should be implemented by view controllers that support category switching
protocol CategorySwitchable {
    var categoryDelegate: CategorySelectionDelegate? { get set }
}

// MARK: - CategorySwitchable Extension

/// Helper extension that provides a default implementation for creating the category button in SwiftUI views
extension CategorySwitchable where Self: UIViewController {
    
    /// Creates a category button configuration with the specified icon and title
    func createCategoryButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.976, green: 0.576, blue: 0.125),
                        Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.8)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }
    
    /// Handles selection of a category
    func handleCategorySelection(_ index: Int) {
        categoryDelegate?.didSelectCategory(at: index)
    }
}

// MARK: - CategorySelectionDelegate Extension

// Provide a default implementation for the optional property
extension CategorySelectionDelegate {
    var currentSelectedCategoryIndex: Int? {
        return UserDefaults.standard.object(forKey: UserDefaults.selectedCategoryIndexKey) as? Int
    }
}

