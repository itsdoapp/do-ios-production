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
    
    var body: some View {
        ZStack {
            // Background circle with gradient
            Circle()
                .fill(characterBackgroundGradient)
                .frame(width: 80, height: 80)
            
            // Character illustration
            characterIllustration
                .offset(y: bounceOffset)
        }
        .onAppear {
            startBounceAnimation()
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
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            bounceOffset = -3
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
            return [Color(hex: "9B87F5").opacity(0.4), Color(hex: "6B5CE6").opacity(0.6)]
        case .focus:
            return [Color.brandOrange.opacity(0.4), Color(hex: "FFB84D").opacity(0.6)]
        case .stress:
            return [Color(hex: "4ECDC4").opacity(0.4), Color(hex: "44A08D").opacity(0.6)]
        case .breathing:
            return [Color(hex: "87CEEB").opacity(0.4), Color(hex: "5F9EA0").opacity(0.6)]
        case .gratitude:
            return [Color(hex: "FFD700").opacity(0.4), Color(hex: "FFA500").opacity(0.6)]
        case .performance:
            return [Color(hex: "FF6B6B").opacity(0.4), Color(hex: "FF8E53").opacity(0.6)]
        case .recovery:
            return [Color(hex: "A8E6CF").opacity(0.4), Color(hex: "7FCDBB").opacity(0.6)]
        case .default:
            return [Color(hex: "B19CD9").opacity(0.4), Color(hex: "8B7FA8").opacity(0.6)]
        }
    }
}

// MARK: - Character Illustrations

struct SleepCharacter: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 8, height: 3)
                    .offset(x: -8)
                Capsule()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 8, height: 3)
                    .offset(x: 8)
            }
            
            Capsule()
                .fill(Color.black.opacity(0.2))
                .frame(width: 12, height: 2)
                .offset(y: 8)
            
            Image(systemName: "moon.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "FFD700").opacity(0.8))
                .offset(y: -35)
        }
    }
}

struct FocusCharacter: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 10, height: 10)
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 10, height: 10)
            }
            
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 14, height: 3)
                .offset(y: 10)
            
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundColor(Color.brandOrange)
                .offset(y: -38)
        }
    }
}

struct StressReliefCharacter: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            HStack(spacing: 12) {
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 10, height: 3)
                    .rotationEffect(.degrees(-20))
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 10, height: 3)
                    .rotationEffect(.degrees(20))
            }
            
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 16, height: 3)
                .offset(y: 8)
            
            ForEach(0..<3) { index in
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 60 + CGFloat(index * 8))
            }
        }
    }
}

struct BreathingCharacter: View {
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
                .scaleEffect(scale)
            
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 8, height: 8)
            }
            
            Ellipse()
                .fill(Color.black.opacity(0.2))
                .frame(width: 12, height: 8)
                .offset(y: 10)
            
            ForEach(0..<2) { index in
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    .frame(width: 40 + CGFloat(index * 10))
                    .scaleEffect(scale)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                scale = 1.2
            }
        }
    }
}

struct GratitudeCharacter: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            HStack(spacing: 12) {
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 10, height: 3)
                    .rotationEffect(.degrees(-20))
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 10, height: 3)
                    .rotationEffect(.degrees(20))
            }
            
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 20, height: 4)
                .offset(y: 10)
            
            Image(systemName: "heart.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "FF6B6B"))
                .offset(y: -35)
        }
    }
}

struct PerformanceCharacter: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 10, height: 10)
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 10, height: 10)
            }
            
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 18, height: 3)
                .offset(y: 10)
            
            Image(systemName: "bolt.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "FFD700"))
                .offset(y: -38)
        }
    }
}

struct RecoveryCharacter: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            HStack(spacing: 12) {
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 8, height: 3)
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 8, height: 3)
            }
            
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 14, height: 3)
                .offset(y: 8)
            
            Image(systemName: "leaf.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "4ECDC4"))
                .offset(y: -35)
        }
    }
}

struct MindfulnessCharacter: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 9, height: 9)
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 9, height: 9)
            }
            
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 12, height: 2)
                .offset(y: 10)
            
            ForEach(0..<3) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: 8))
                    .foregroundColor(Color.white.opacity(0.6))
                    .offset(
                        x: cos(Double(index) * 2 * .pi / 3) * 25,
                        y: sin(Double(index) * 2 * .pi / 3) * 25
                    )
            }
        }
    }
}

// MARK: - Color Extensions


