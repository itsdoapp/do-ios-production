//
//  Color+Brand.swift
//  Do
//

import SwiftUI

extension Color {
    /// Initialize Color from hex string (e.g., "F7931F" or "#F7931F")
    init(hex: String) {
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
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Initialize Color from hex integer (e.g., 0xF7931F or 0x0F0F23)
    init(hex: UInt32) {
        let r = Double((hex & 0xFF0000) >> 16) / 255.0
        let g = Double((hex & 0x00FF00) >> 8) / 255.0
        let b = Double(hex & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
    
    // Do. Brand Colors
    static let brandBlue = Color(red: 0.059, green: 0.086, blue: 0.243) // #0F163E
    static let brandOrange = Color(red: 0.969, green: 0.576, blue: 0.122) // #F7931F
    static let doOrange = brandOrange // Alias for compatibility
    
    // UI Colors
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.7, green: 0.7, blue: 0.7)
    static let textTertiary = Color(red: 0.5, green: 0.5, blue: 0.5)
    
    // Background Colors
    static let backgroundPrimary = brandBlue
    static let backgroundSecondary = Color(red: 0.1, green: 0.12, blue: 0.3)
    static let cardBackground = Color.white.opacity(0.08)
    
    // Accent Colors
    static let accentPrimary = brandOrange
    static let success = Color.green
    static let error = Color.red
    static let warning = Color.yellow
    
    // MARK: - Weather Gradient
    
    /// Returns a tuple of two colors for a weather gradient based on condition and hour
    /// - Parameters:
    ///   - condition: The weather condition
    ///   - hour: The current hour (0-23)
    /// - Returns: A tuple of (topColor, bottomColor)
    static func weatherGradient(for condition: WeatherCondition, hour: Int) -> (Color, Color) {
        let isNight = hour >= 19 || hour < 6
        let isDawn = hour >= 5 && hour < 9
        let isDusk = hour >= 17 && hour < 20
        
        switch condition {
        case .clear:
            if isNight {
                return (Color(hex: 0x1a1a2e), Color(hex: 0x16213e)) // Dark blue gradient
            } else if isDawn {
                return (Color(hex: 0xff9a56), Color(hex: 0xff6e88)) // Sunrise gradient
            } else if isDusk {
                return (Color(hex: 0xff6e88), Color(hex: 0xc471ed)) // Sunset gradient
            } else {
                return (Color(hex: 0x4facfe), Color(hex: 0x00f2fe)) // Clear sky blue
            }
        case .partlyCloudy:
            if isNight {
                return (Color(hex: 0x2c3e50), Color(hex: 0x34495e)) // Dark gray-blue
            } else {
                return (Color(hex: 0x74b9ff), Color(hex: 0x0984e3)) // Light blue with clouds
            }
        case .cloudy:
            if isNight {
                return (Color(hex: 0x2c3e50), Color(hex: 0x1a1a2e)) // Dark gray
            } else {
                return (Color(hex: 0x636e72), Color(hex: 0x2d3436)) // Gray
            }
        case .rainy:
            if isNight {
                return (Color(hex: 0x2c3e50), Color(hex: 0x1a1a2e)) // Dark blue-gray
            } else {
                return (Color(hex: 0x74b9ff), Color(hex: 0x0984e3)) // Rainy blue
            }
        case .stormy:
            return (Color(hex: 0x2d3436), Color(hex: 0x1a1a2e)) // Dark stormy
        case .snowy:
            if isNight {
                return (Color(hex: 0x636e72), Color(hex: 0x2d3436)) // Dark gray
            } else {
                return (Color(hex: 0xe0e0e0), Color(hex: 0xb0bec5)) // Light gray/white
            }
        case .foggy:
            return (Color(hex: 0x636e72), Color(hex: 0x2d3436)) // Gray fog
        case .windy:
            if isNight {
                return (Color(hex: 0x2c3e50), Color(hex: 0x1a1a2e)) // Dark
            } else {
                return (Color(hex: 0x74b9ff), Color(hex: 0x0984e3)) // Windy blue
            }
        case .unknown:
            return (Color(hex: 0x636e72), Color(hex: 0x2d3436)) // Default gray
        }
    }
}
