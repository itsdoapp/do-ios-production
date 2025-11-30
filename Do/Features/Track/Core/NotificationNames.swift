//
//  NotificationNames.swift
//  Track Infrastructure
//
//  Notification name constants for Track infrastructure
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

extension Notification.Name {
    /// Notification sent to trigger direct category change
    /// UserInfo: ["index": Int] - The category index to switch to
    static let directCategorySelection = Notification.Name("DirectCategorySelection")
    
    /// Notification broadcast when category changes
    /// UserInfo: ["index": Int] - The new category index
    static let categoryDidChange = Notification.Name("CategoryDidChange")
}

// MARK: - UserDefaults Keys

extension UserDefaults {
    /// Key for storing the selected category index
    static let selectedCategoryIndexKey = "selectedCategoryIndex"
}

