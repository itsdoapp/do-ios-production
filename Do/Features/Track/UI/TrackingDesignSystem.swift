//
//  TrackingDesignSystem.swift
//  Do
//
//  Centralized design system for activity tracking UI
//  Ensures consistency across all tracking views
//

import SwiftUI
import UIKit

// MARK: - Design System Constants

struct TrackingDesignSystem {
    
    // MARK: - Colors
    
    struct Colors {
        // Background Colors
        static let primaryBackground = Color(UIColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0))
        static let secondaryBackground = Color(UIColor(red: 0.12, green: 0.15, blue: 0.25, alpha: 0.9))
        static let cardBackground = Color(UIColor(red: 0.12, green: 0.15, blue: 0.25, alpha: 0.9))
        static let cardBackgroundDark = Color(UIColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 0.95))
        
        // Gradient Colors
        static let gradientStart = Color(UIColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 0.7))
        static let gradientEnd = Color(UIColor(red: 0.15, green: 0.20, blue: 0.35, alpha: 0.5))
        
        // Accent Colors
        static let brandOrange = Color(UIColor(red: 247/255, green: 147/255, blue: 31/255, alpha: 1.0))
        static let accentBlue = Color.blue
        static let accentGreen = Color.green
        static let accentPurple = Color.purple
        
        // Text Colors
        static let primaryText = Color.white
        static let secondaryText = Color.white.opacity(0.7)
        static let tertiaryText = Color.white.opacity(0.5)
        
        // Status Colors
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        
        // Meditation-Specific Colors
        struct Meditation {
            // Sleep meditation colors
            static let sleepStart = Color(hex: "9B87F5")
            static let sleepEnd = Color(hex: "6B5CE6")
            
            // Focus meditation colors
            static let focusStart = Color.brandOrange
            static let focusEnd = Color(hex: "FFB84D")
            
            // Stress meditation colors
            static let stressStart = Color(hex: "4ECDC4")
            static let stressEnd = Color(hex: "44A08D")
            
            // Breathing meditation colors
            static let breathingStart = Color(hex: "87CEEB")
            static let breathingEnd = Color(hex: "5F9EA0")
            
            // Gratitude meditation colors
            static let gratitudeStart = Color(hex: "FFD700")
            static let gratitudeEnd = Color(hex: "FFA500")
            
            // Performance meditation colors
            static let performanceStart = Color(hex: "FF6B6B")
            static let performanceEnd = Color(hex: "FF8E53")
            
            // Recovery meditation colors
            static let recoveryStart = Color(hex: "A8E6CF")
            static let recoveryEnd = Color(hex: "7FCDBB")
            
            // Default meditation colors
            static let defaultStart = Color(hex: "B19CD9")
            static let defaultEnd = Color(hex: "8B7FA8")
            
            // Helper to get gradient colors for a meditation category
            static func gradientColors(for category: String) -> [Color] {
                let lowerCategory = category.lowercased()
                if lowerCategory.contains("sleep") || lowerCategory.contains("sleep health") {
                    return [sleepStart, sleepEnd]
                } else if lowerCategory.contains("focus") || lowerCategory.contains("productivity") || lowerCategory.contains("work") {
                    return [focusStart, focusEnd]
                } else if lowerCategory.contains("stress") || lowerCategory.contains("anxiety") {
                    return [stressStart, stressEnd]
                } else if lowerCategory.contains("breathe") || lowerCategory.contains("breathing") {
                    return [breathingStart, breathingEnd]
                } else if lowerCategory.contains("gratitude") || lowerCategory.contains("happiness") {
                    return [gratitudeStart, gratitudeEnd]
                } else if lowerCategory.contains("performance") || lowerCategory.contains("energy") {
                    return [performanceStart, performanceEnd]
                } else if lowerCategory.contains("healing") || lowerCategory.contains("recovery") {
                    return [recoveryStart, recoveryEnd]
                } else {
                    return [defaultStart, defaultEnd]
                }
            }
        }
    }
    
    // MARK: - Spacing
    
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        
        // Section spacing
        static let sectionSpacing: CGFloat = 24
        static let cardPadding: CGFloat = 20
        static let cardInternalSpacing: CGFloat = 16
    }
    
    // MARK: - Corner Radius
    
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 24
        static let card: CGFloat = 16  // Standard card corner radius
        static let button: CGFloat = 12
    }
    
    // MARK: - Typography
    
    struct Typography {
        // Headers
        static let h1: Font = .system(size: 32, weight: .bold)
        static let h2: Font = .system(size: 24, weight: .bold)
        static let h3: Font = .system(size: 20, weight: .semibold)
        static let h4: Font = .system(size: 18, weight: .semibold)
        
        // Body
        static let body: Font = .system(size: 16, weight: .regular)
        static let bodyBold: Font = .system(size: 16, weight: .semibold)
        static let bodyMedium: Font = .system(size: 16, weight: .medium)
        
        // Small
        static let small: Font = .system(size: 14, weight: .regular)
        static let smallBold: Font = .system(size: 14, weight: .semibold)
        static let smallMedium: Font = .system(size: 14, weight: .medium)
        
        // Caption
        static let caption: Font = .system(size: 12, weight: .regular)
        static let captionBold: Font = .system(size: 12, weight: .semibold)
    }
    
    // MARK: - Shadows
    
    struct Shadows {
        static let small = Shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        static let medium = Shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        static let large = Shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
        
        struct Shadow {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
    }
    
    // MARK: - Animations
    
    struct Animations {
        static let spring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)
        static let springFast = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let easeInOut = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let easeInOutFast = SwiftUI.Animation.easeInOut(duration: 0.15)
    }
}

// MARK: - Reusable Card Style

struct TrackingCardStyle: ViewModifier {
    let cornerRadius: CGFloat
    let backgroundColor: Color
    let shadow: TrackingDesignSystem.Shadows.Shadow
    
    init(
        cornerRadius: CGFloat = TrackingDesignSystem.CornerRadius.card,
        backgroundColor: Color = TrackingDesignSystem.Colors.cardBackground,
        shadow: TrackingDesignSystem.Shadows.Shadow = TrackingDesignSystem.Shadows.medium
    ) {
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        self.shadow = shadow
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
            )
            .shadow(
                color: shadow.color,
                radius: shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
    }
}

extension View {
    func trackingCardStyle(
        cornerRadius: CGFloat = TrackingDesignSystem.CornerRadius.card,
        backgroundColor: Color = TrackingDesignSystem.Colors.cardBackground,
        shadow: TrackingDesignSystem.Shadows.Shadow = TrackingDesignSystem.Shadows.medium
    ) -> some View {
        modifier(TrackingCardStyle(
            cornerRadius: cornerRadius,
            backgroundColor: backgroundColor,
            shadow: shadow
        ))
    }
}

// MARK: - Standard Card Component

struct StandardTrackingCard<Content: View>: View {
    let cornerRadius: CGFloat
    let backgroundColor: Color
    let shadow: TrackingDesignSystem.Shadows.Shadow
    let content: Content
    
    init(
        cornerRadius: CGFloat = TrackingDesignSystem.CornerRadius.card,
        backgroundColor: Color = TrackingDesignSystem.Colors.cardBackground,
        shadow: TrackingDesignSystem.Shadows.Shadow = TrackingDesignSystem.Shadows.medium,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        self.shadow = shadow
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(TrackingDesignSystem.Spacing.cardPadding)
            .trackingCardStyle(
                cornerRadius: cornerRadius,
                backgroundColor: backgroundColor,
                shadow: shadow
            )
    }
}

