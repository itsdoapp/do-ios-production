//
//  WorkoutViewComponents.swift
//  Do Watch App
//
//  Shared UI components for workout views
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

// MARK: - Ambient Background
struct AmbientBackground: View {
    let color: Color
    var heartRate: Double? = nil
    
    @State private var pulseScale: CGFloat = 1.0
    
    var dynamicColor: Color {
        if let hr = heartRate {
            // Use HeartRateZoneService for zone calculation
            if let zone = HeartRateZoneService.shared.calculateZone(for: hr) {
                return zone.color
            }
            return .gray
        }
        return color
    }
    
    var animationDuration: Double {
        if let hr = heartRate, hr > 0 {
            // Pulse faster with higher HR (60bpm = 1s, 120bpm = 0.5s)
            return 60.0 / hr
        }
        return 4.0
    }
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            Circle()
                .fill(dynamicColor.opacity(0.15))
                .frame(width: 200, height: 200)
                .scaleEffect(pulseScale)
                .blur(radius: 30)
                .onAppear {
                    startAnimation()
                }
                .onChange(of: heartRate) { _ in
                    // Restart animation with new duration if HR changes significantly
                    startAnimation()
                }
        }
    }
    
    private func startAnimation() {
        withAnimation(.easeInOut(duration: animationDuration).repeatForever(autoreverses: true)) {
            pulseScale = 1.3
        }
    }
}

// MARK: - Stat Box (Enhanced)
struct StatBox: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Big Metric (Enhanced)
struct HeroMetric: View {
    let value: String
    let unit: String
    let color: Color
    
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: color.opacity(0.5), radius: 15, x: 0, y: 0)
                .scaleEffect(pulseScale)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .onAppear {
                    // Subtle pulse animation
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        pulseScale = 1.02
                    }
                }
            
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
                    .padding(.top, -4)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Controls
struct WorkoutControls: View {
    let isRunning: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let color: Color
    var customAction: (() -> Void)? = nil
    var customIcon: String? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            if isRunning {
                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .font(.title2)
                        .foregroundColor(.black)
                        .frame(width: 56, height: 56)
                        .background(color)
                        .clipShape(Circle())
                        .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
                }
            } else {
                Button(action: onResume) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .foregroundColor(.black)
                        .frame(width: 56, height: 56)
                        .background(Color.green)
                        .clipShape(Circle())
                        .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }
            
            if let customAction = customAction, let customIcon = customIcon {
                Button(action: customAction) {
                    Image(systemName: customIcon)
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.8))
                        .clipShape(Circle())
                }
            }
            
            Button(action: onStop) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.red.opacity(0.8))
                    .clipShape(Circle())
                    .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .buttonStyle(.plain) // Crucial for custom buttons in watchOS
    }
}
