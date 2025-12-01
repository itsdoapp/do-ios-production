//
//  CelebrationView.swift
//  Do Watch App
//
//  Post-workout celebration animation
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

struct CelebrationView: View {
    let achievement: String
    let color: Color
    
    @State private var sparkles: [Sparkle] = []
    @State private var scale: CGFloat = 0.0
    @State private var rotation: Double = 0.0
    
    var body: some View {
        ZStack {
            // Sparkle particles
            ForEach(sparkles) { sparkle in
                Image(systemName: "sparkle")
                    .font(.system(size: sparkle.size))
                    .foregroundColor(sparkle.color)
                    .position(sparkle.position)
                    .opacity(sparkle.opacity)
            }
            
            // Achievement text
            VStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 40))
                    .foregroundColor(color)
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotation))
                    .shadow(color: color.opacity(0.6), radius: 15, x: 0, y: 0)
                
                Text(achievement)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(scale > 0.5 ? 1.0 : 0.0)
            }
        }
        .onAppear {
            generateSparkles()
            startAnimation()
        }
    }
    
    private func generateSparkles() {
        let center = CGPoint(x: 100, y: 100) // Watch screen center approximation
        for i in 0..<20 {
            let angle = Double(i) * (360.0 / 20.0) * .pi / 180.0
            let distance: CGFloat = 60 + CGFloat.random(in: 0...20)
            let position = CGPoint(
                x: center.x + cos(angle) * distance,
                y: center.y + sin(angle) * distance
            )
            
            sparkles.append(Sparkle(
                id: UUID(),
                position: position,
                targetPosition: CGPoint(
                    x: position.x + CGFloat.random(in: -30...30),
                    y: position.y + CGFloat.random(in: -30...30)
                ),
                size: CGFloat.random(in: 8...16),
                color: [color, .yellow, .orange, .pink].randomElement() ?? color,
                opacity: 1.0
            ))
        }
    }
    
    private func startAnimation() {
        // Trophy pop-in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            scale = 1.2
        }
        
        // Rotation
        withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: false)) {
            rotation = 360
        }
        
        // Sparkles fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for i in sparkles.indices {
                withAnimation(.easeOut(duration: 1.0).delay(Double(i) * 0.05)) {
                    sparkles[i].opacity = 0.0
                    sparkles[i].position = sparkles[i].targetPosition
                }
            }
        }
        
        // Scale back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                scale = 1.0
            }
        }
    }
}

struct Sparkle: Identifiable {
    let id: UUID
    var position: CGPoint
    let targetPosition: CGPoint
    let size: CGFloat
    let color: Color
    var opacity: Double
}
