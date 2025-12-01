//
//  WatchTabs.swift
//  Do Watch App
//
//  Additional tab views for workout sessions (Controls, Media, Weather)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import WatchKit

// MARK: - Controls Page (Left Screen) - Modern Redesign
struct WorkoutControlsPage: View {
    let isRunning: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let color: Color
    var showCancel: Bool = false
    var onCancel: (() -> Void)? = nil
    
    @State private var pauseScale: CGFloat = 1.0
    @State private var stopScale: CGFloat = 1.0
    @State private var cancelScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("CONTROLS")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(0.5)
            }
            .padding(.top, 12)
            .padding(.bottom, 20)
            
            Spacer()
            
            // Pause / Resume Button - Large, prominent
            ControlButton(
                icon: isRunning ? "pause.fill" : "play.fill",
                label: isRunning ? "PAUSE" : "RESUME",
                color: Color(red: 1.0, green: 0.8, blue: 0.0), // Bright yellow
                scale: $pauseScale
            ) {
                WKInterfaceDevice.current().play(.click)
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    pauseScale = 0.92
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    pauseScale = 1.0
                    if isRunning {
                        onPause()
                    } else {
                        onResume()
                    }
                }
            }
            .padding(.bottom, 16)
            
            // End Workout Button
            ControlButton(
                icon: "stop.fill",
                label: "END",
                color: Color.red,
                scale: $stopScale
            ) {
                WKInterfaceDevice.current().play(.failure)
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    stopScale = 0.92
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    stopScale = 1.0
                    onStop()
                }
            }
            .padding(.bottom, showCancel ? 12 : 0)
            
            // Cancel Button (Conditional - first 10 seconds)
            if showCancel, let onCancel = onCancel {
                ControlButton(
                    icon: "xmark.circle.fill",
                    label: "CANCEL",
                    color: Color.gray.opacity(0.7),
                    scale: $cancelScale,
                    isSecondary: true
                ) {
                    WKInterfaceDevice.current().play(.stop)
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        cancelScale = 0.92
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        cancelScale = 1.0
                        onCancel()
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
    }
}

struct ControlButton: View {
    let icon: String
    let label: String
    let color: Color
    @Binding var scale: CGFloat
    var isSecondary: Bool = false
    
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(isSecondary ? 0.2 : 0.25))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: isSecondary ? 14 : 16, weight: .semibold))
                        .foregroundColor(color)
                }
                
                // Label
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(0.5)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: isSecondary
                                ? [
                                    Color.white.opacity(0.06),
                                    Color.white.opacity(0.04)
                                ]
                                : [
                                    color.opacity(0.15),
                                    color.opacity(0.08)
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                color.opacity(isSecondary ? 0.2 : 0.3),
                                lineWidth: isSecondary ? 1 : 1.5
                            )
                    )
            )
            .scaleEffect(scale)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Now Playing Page (Right Screen) - Enhanced
struct NowPlayingView: View {
    @State private var isRotating = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Now Playing")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .padding(.top)
            
            Spacer()
            
            // Enhanced music icon with rotation
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "music.note.list")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                    .onAppear {
                        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                            isRotating = true
                        }
                    }
            }
            
            Text("Control music on iPhone")
                .font(.system(size: 12, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            Spacer()
        }
    }
}
