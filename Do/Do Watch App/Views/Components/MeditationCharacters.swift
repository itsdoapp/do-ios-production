//
//  MeditationCharacters.swift
//  Do Watch App
//
//  Character illustrations for meditation and workouts
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

// MARK: - Character View

struct MeditationCharacterView: View {
    let category: String
    @State private var bounceOffset: CGFloat = 0
    @State private var glowIntensity: Double = 0.5
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Outer glow effect
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            characterType.glowColor.opacity(glowIntensity),
                            characterType.glowColor.opacity(0)
                        ]),
                        center: .center,
                        startRadius: 30,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 100)
                .blur(radius: 8)
                .scaleEffect(scale)
            
            // Background circle with enhanced gradient and shadow
            Circle()
                .fill(characterBackgroundGradient)
                .frame(width: 80, height: 80)
                .shadow(color: characterType.glowColor.opacity(0.4), radius: 12, x: 0, y: 4)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
            
            // Character illustration
            characterIllustration
                .offset(y: bounceOffset)
        }
        .onAppear {
            startBounceAnimation()
            startGlowAnimation()
        }
    }
    
    private var characterIllustration: some View {
        Group {
            switch characterType {
            case .sleep:
                SleepCharacter()
            case .focus:
                FocusCharacter()
            case .stress:
                StressReliefCharacter()
            case .breathing:
                BreathingCharacter()
            case .gratitude:
                GratitudeCharacter()
            case .performance:
                PerformanceCharacter()
            case .recovery:
                RecoveryCharacter()
            case .default:
                MindfulnessCharacter()
            }
        }
    }
    
    private var characterType: MeditationCharacterType {
        let lowerCategory = category.lowercased()
        if lowerCategory.contains("sleep") {
            return .sleep
        } else if lowerCategory.contains("focus") || lowerCategory.contains("productivity") {
            return .focus
        } else if lowerCategory.contains("stress") || lowerCategory.contains("anxiety") {
            return .stress
        } else if lowerCategory.contains("breathe") {
            return .breathing
        } else if lowerCategory.contains("gratitude") || lowerCategory.contains("happiness") {
            return .gratitude
        } else if lowerCategory.contains("performance") || lowerCategory.contains("energy") {
            return .performance
        } else if lowerCategory.contains("healing") || lowerCategory.contains("recovery") {
            return .recovery
        }
        return .default
    }
    
    private var characterBackgroundGradient: LinearGradient {
        let colors = characterType.colors
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func startBounceAnimation() {
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            bounceOffset = -4
        }
    }
    
    private func startGlowAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowIntensity = 0.8
        }
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            scale = 1.1
        }
    }
}

enum MeditationCharacterType {
    case sleep
    case focus
    case stress
    case breathing
    case gratitude
    case performance
    case recovery
    case `default`
    
    var colors: [Color] {
        switch self {
        case .sleep:
            return [Color(hex: "9B87F5").opacity(0.5), Color(hex: "6B5CE6").opacity(0.7)]
        case .focus:
            return [Color.brandOrange.opacity(0.5), Color(hex: "FFB84D").opacity(0.7)]
        case .stress:
            return [Color(hex: "4ECDC4").opacity(0.5), Color(hex: "44A08D").opacity(0.7)]
        case .breathing:
            return [Color(hex: "87CEEB").opacity(0.5), Color(hex: "5F9EA0").opacity(0.7)]
        case .gratitude:
            return [Color(hex: "FFD700").opacity(0.5), Color(hex: "FFA500").opacity(0.7)]
        case .performance:
            return [Color(hex: "FF6B6B").opacity(0.5), Color(hex: "FF8E53").opacity(0.7)]
        case .recovery:
            return [Color(hex: "A8E6CF").opacity(0.5), Color(hex: "7FCDBB").opacity(0.7)]
        case .default:
            return [Color(hex: "B19CD9").opacity(0.5), Color(hex: "8B7FA8").opacity(0.7)]
        }
    }
    
    var glowColor: Color {
        switch self {
        case .sleep:
            return Color(hex: "9B87F5")
        case .focus:
            return Color.brandOrange
        case .stress:
            return Color(hex: "4ECDC4")
        case .breathing:
            return Color(hex: "87CEEB")
        case .gratitude:
            return Color(hex: "FFD700")
        case .performance:
            return Color(hex: "FF6B6B")
        case .recovery:
            return Color(hex: "A8E6CF")
        case .default:
            return Color(hex: "B19CD9")
        }
    }
}

// MARK: - Character Illustrations

struct SleepCharacter: View {
    @State private var moonGlow: Double = 0.6
    
    var body: some View {
        ZStack {
            // Face with subtle gradient
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.85)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Eyes
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 8, height: 3)
                    .offset(x: -8)
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 8, height: 3)
                    .offset(x: 8)
            }
            
            // Mouth
            Capsule()
                .fill(Color.black.opacity(0.25))
                .frame(width: 12, height: 2)
                .offset(y: 8)
            
            // Moon icon with glow animation
            Image(systemName: "moon.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "FFD700"))
                .offset(y: -35)
                .shadow(color: Color(hex: "FFD700").opacity(moonGlow), radius: 6, x: 0, y: 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                moonGlow = 1.0
            }
        }
    }
}

struct FocusCharacter: View {
    @State private var bulbGlow: Double = 0.7
    
    var body: some View {
        ZStack {
            // Face with gradient
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.85)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Eyes
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: 10, height: 10)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: 10, height: 10)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            
            // Mouth
            Capsule()
                .fill(Color.black.opacity(0.35))
                .frame(width: 14, height: 3)
                .offset(y: 10)
            
            // Lightbulb with animated glow
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundColor(Color.brandOrange)
                .offset(y: -38)
                .shadow(color: Color.brandOrange.opacity(bulbGlow), radius: 8, x: 0, y: 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                bulbGlow = 1.0
            }
        }
    }
}

struct StressReliefCharacter: View {
    @State private var waveScale: [CGFloat] = [1.0, 1.0, 1.0]
    
    var body: some View {
        ZStack {
            // Face with gradient
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.85)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Eyes (closed, relaxed)
            HStack(spacing: 12) {
                Capsule()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 10, height: 3)
                    .rotationEffect(.degrees(-20))
                Capsule()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 10, height: 3)
                    .rotationEffect(.degrees(20))
            }
            
            // Smile
            Capsule()
                .fill(Color.black.opacity(0.35))
                .frame(width: 16, height: 3)
                .offset(y: 8)
            
            // Calming waves with animation
            ForEach(0..<3) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 60 + CGFloat(index * 8))
                    .scaleEffect(waveScale[index])
            }
        }
        .onAppear {
            for index in 0..<3 {
                withAnimation(
                    .easeInOut(duration: 2.0 + Double(index) * 0.3)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.2)
                ) {
                    waveScale[index] = 1.15
                }
            }
        }
    }
}

struct BreathingCharacter: View {
    @State private var scale: CGFloat = 1.0
    @State private var breathOpacity: Double = 0.5
    
    var body: some View {
        ZStack {
            // Face with breathing animation
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.85)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .scaleEffect(scale)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Eyes
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            
            // Mouth (breathing)
            Ellipse()
                .fill(Color.black.opacity(0.25))
                .frame(width: 12, height: 8)
                .offset(y: 10)
                .scaleEffect(x: 1.0, y: scale * 0.8)
            
            // Breathing circles with smooth animation
            ForEach(0..<2) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(breathOpacity),
                                Color.white.opacity(breathOpacity * 0.5)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 40 + CGFloat(index * 10))
                    .scaleEffect(scale)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                scale = 1.25
            }
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                breathOpacity = 0.8
            }
        }
    }
}

struct GratitudeCharacter: View {
    @State private var heartScale: CGFloat = 1.0
    @State private var heartGlow: Double = 0.7
    
    var body: some View {
        ZStack {
            // Face with gradient
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.85)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Eyes (happy)
            HStack(spacing: 12) {
                Capsule()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 10, height: 3)
                    .rotationEffect(.degrees(-20))
                Capsule()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 10, height: 3)
                    .rotationEffect(.degrees(20))
            }
            
            // Big smile
            Capsule()
                .fill(Color.black.opacity(0.35))
                .frame(width: 20, height: 4)
                .offset(y: 10)
            
            // Heart with pulsing animation
            Image(systemName: "heart.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "FF6B6B"))
                .offset(y: -35)
                .scaleEffect(heartScale)
                .shadow(color: Color(hex: "FF6B6B").opacity(heartGlow), radius: 6, x: 0, y: 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                heartScale = 1.15
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                heartGlow = 1.0
            }
        }
    }
}

struct PerformanceCharacter: View {
    @State private var boltRotation: Double = 0
    @State private var boltGlow: Double = 0.7
    
    var body: some View {
        ZStack {
            // Face with gradient
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.85)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Eyes
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: 10, height: 10)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: 10, height: 10)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            
            // Mouth
            Capsule()
                .fill(Color.black.opacity(0.35))
                .frame(width: 18, height: 3)
                .offset(y: 10)
            
            // Bolt with animated glow and rotation
            Image(systemName: "bolt.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "FFD700"))
                .offset(y: -38)
                .rotationEffect(.degrees(boltRotation))
                .shadow(color: Color(hex: "FFD700").opacity(boltGlow), radius: 8, x: 0, y: 0)
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                boltRotation = 360
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                boltGlow = 1.0
            }
        }
    }
}

struct RecoveryCharacter: View {
    @State private var leafRotation: Double = -15
    @State private var leafGlow: Double = 0.6
    
    var body: some View {
        ZStack {
            // Face with gradient
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.85)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Eyes
            HStack(spacing: 12) {
                Capsule()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 8, height: 3)
                Capsule()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 8, height: 3)
            }
            
            // Mouth
            Capsule()
                .fill(Color.black.opacity(0.35))
                .frame(width: 14, height: 3)
                .offset(y: 8)
            
            // Leaf with gentle sway animation
            Image(systemName: "leaf.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "4ECDC4"))
                .offset(y: -35)
                .rotationEffect(.degrees(leafRotation))
                .shadow(color: Color(hex: "4ECDC4").opacity(leafGlow), radius: 6, x: 0, y: 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                leafRotation = 15
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                leafGlow = 0.9
            }
        }
    }
}

struct MindfulnessCharacter: View {
    @State private var sparkleOpacity: [Double] = [0.6, 0.6, 0.6]
    @State private var sparkleScale: [CGFloat] = [1.0, 1.0, 1.0]
    
    var body: some View {
        ZStack {
            // Face with gradient
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.85)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Eyes
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 9, height: 9)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 9, height: 9)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            
            // Mouth
            Capsule()
                .fill(Color.black.opacity(0.35))
                .frame(width: 12, height: 2)
                .offset(y: 10)
            
            // Sparkles with twinkling animation
            ForEach(0..<3) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: 8))
                    .foregroundColor(Color.white.opacity(sparkleOpacity[index]))
                    .offset(
                        x: cos(Double(index) * 2 * .pi / 3) * 25,
                        y: sin(Double(index) * 2 * .pi / 3) * 25
                    )
                    .scaleEffect(sparkleScale[index])
            }
        }
        .onAppear {
            for index in 0..<3 {
                withAnimation(
                    .easeInOut(duration: 1.5 + Double(index) * 0.3)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.4)
                ) {
                    sparkleOpacity[index] = 1.0
                    sparkleScale[index] = 1.3
                }
            }
        }
    }
}

// MARK: - Color Extensions




