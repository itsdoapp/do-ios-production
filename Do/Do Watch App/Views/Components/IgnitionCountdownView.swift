//
//  IgnitionCountdownView.swift
//  Do Watch App
//
//  Rocket launch countdown transition
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import WatchKit

struct IgnitionCountdownView: View {
    let workoutType: String
    let workoutColor: Color
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    @State private var countdown: Int = 3
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    @State private var backgroundPulse: CGFloat = 1.0
    @State private var countdownTimer: Timer?
    
    var body: some View {
        ZStack {
            // Pulsing background
            Circle()
                .fill(workoutColor.opacity(0.3))
                .frame(width: 200, height: 200)
                .scaleEffect(backgroundPulse)
                .blur(radius: 40)
            
            VStack(spacing: 16) {
                // Countdown number
                if countdown > 0 {
                    Text("\(countdown)")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .shadow(color: workoutColor.opacity(0.8), radius: 20, x: 0, y: 0)
                } else {
                    Text("GO!")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(workoutColor)
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .shadow(color: workoutColor.opacity(0.8), radius: 20, x: 0, y: 0)
                }
                
                Text(workoutType.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                    .opacity(opacity)
                
                // Cancel button
                Button(action: {
                    // Stop the countdown timer
                    countdownTimer?.invalidate()
                    countdownTimer = nil
                    WKInterfaceDevice.current().play(.click)
                    onCancel()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Cancel")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.3))
                            .overlay(
                                Capsule()
                                    .stroke(Color.red.opacity(0.6), lineWidth: 1.5)
                            )
                    )
                }
                .buttonStyle(.plain)
                .opacity(opacity)
                .padding(.top, 8)
            }
        }
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            stopCountdown()
        }
    }
    
    private func startCountdown() {
        // Initial pulse
        withAnimation(.easeOut(duration: 0.3)) {
            scale = 1.2
            opacity = 1.0
            backgroundPulse = 1.5
        }
        
        // Countdown loop - store timer reference so we can cancel it
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [ self] timer in
           
            if countdown > 0 {
                // Haptic feedback
                WKInterfaceDevice.current().play(.click)
                
                // Shrink and fade
                withAnimation(.easeIn(duration: 0.2)) {
                    scale = 0.3
                    opacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    countdown -= 1
                    
                    if countdown > 0 {
                        // Pop in next number
                        scale = 0.5
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            scale = 1.2
                            opacity = 1.0
                            backgroundPulse = 1.5
                        }
                    } else {
                        // GO!
                        WKInterfaceDevice.current().play(.success)
                        scale = 0.5
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                            scale = 1.3
                            opacity = 1.0
                            backgroundPulse = 2.0
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            timer.invalidate()
                            self.countdownTimer = nil
                            onComplete()
                        }
                    }
                }
            }
        }
    }
    
    // Clean up timer when view disappears
    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
}
