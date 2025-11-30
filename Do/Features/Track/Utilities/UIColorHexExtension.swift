//
//  UIColorHexExtension.swift
//  Track Infrastructure
//
//  Extracted from Do./Util/Extensions.swift
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit

// MARK: - UIViewController Extension

extension UIViewController {
    /// Convert hex color value to UIColor
    /// - Parameter rgbValue: Hex color value (e.g., 0x0F163E)
    /// - Returns: UIColor instance
    func uicolorFromHex(rgbValue: UInt32) -> UIColor {
        let red = CGFloat((rgbValue & 0xFF0000) >> 16) / 256.0
        let green = CGFloat((rgbValue & 0xFF00) >> 8) / 256.0
        let blue = CGFloat(rgbValue & 0xFF) / 256.0
        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

// MARK: - UIColor Extension

extension UIColor {
    /// Initialize UIColor from hex string (e.g., "#0F1A45" or "0F1A45")
    /// - Parameter hex: Hex color string with or without # prefix
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
    
    /// Initialize UIColor from hex integer (e.g., 0x0F163E or 0xF7931F)
    /// - Parameter hex: Hex color value as UInt32
    convenience init(hex: UInt32) {
        let r = CGFloat((hex & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((hex & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(hex & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
    
    /// Convert hex color value to UIColor
    /// - Parameter rgbValue: Hex color value (e.g., 0x0F163E)
    /// - Returns: UIColor instance
    func uicolorFromHex(rgbValue: UInt32) -> UIColor {
        let red = CGFloat((rgbValue & 0xFF0000) >> 16) / 256.0
        let green = CGFloat((rgbValue & 0xFF00) >> 8) / 256.0
        let blue = CGFloat(rgbValue & 0xFF) / 256.0
        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

// MARK: - UIView Extension

extension UIView {
    /// Convert hex color value to UIColor
    /// - Parameter rgbValue: Hex color value (e.g., 0x0F163E)
    /// - Returns: UIColor instance
    func uicolorFromHex(rgbValue: UInt32) -> UIColor {
        let red = CGFloat((rgbValue & 0xFF0000) >> 16) / 256.0
        let green = CGFloat((rgbValue & 0xFF00) >> 8) / 256.0
        let blue = CGFloat(rgbValue & 0xFF) / 256.0
        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

