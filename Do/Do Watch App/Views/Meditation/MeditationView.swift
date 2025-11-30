//
//  MeditationView.swift
//  Do Watch App
//
//  Meditation session interface
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import HealthKit

struct MeditationView: View {
    @EnvironmentObject var workoutCoordinator: WatchWorkoutCoordinator
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    
    @State private var metrics = WorkoutMetrics()
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var pulseScale: CGFloat = 1.0
    
    // Brand colors
    private let brandOrange = Color(red: 0.969, green: 0.576, blue: 0.122)
    
    var body: some View {
        ZStack {
            // Ambient Background Animation
            if isRunning {
                Circle()
                    .fill(brandOrange.opacity(0.15))
                    .frame(width: 200, height: 200)
                    .scaleEffect(pulseScale)
                    .blur(radius: 20)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                            pulseScale = 1.3
                        }
                    }
            }
            
            ScrollView {
                VStack(spacing: 12) {
                    // Header with Character
                    VStack(spacing: 4) {
                        MeditationCharacterView(category: "default")
                            .scaleEffect(0.9)
                            .padding(.top, 8)
                        
                        Text(metrics.formattedTime())
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: brandOrange.opacity(0.3), radius: 10, x: 0, y: 0)
                    }
                    
                    // Heart Rate
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text("HEART RATE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        
                        Text(metrics.formattedHeartRate())
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 4)
                    
                    // Control buttons
                    HStack(spacing: 24) {
                        if isRunning {
                            Button(action: pauseWorkout) {
                                Image(systemName: "pause.fill")
                                    .font(.title2)
                                    .foregroundColor(.black)
                                    .frame(width: 56, height: 56)
                                    .background(brandOrange)
                                    .clipShape(Circle())
                                    .shadow(color: brandOrange.opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                        } else {
                            Button(action: startWorkout) {
                                Image(systemName: "play.fill")
                                    .font(.title2)
                                    .foregroundColor(.black)
                                    .frame(width: 56, height: 56)
                                    .background(Color.green)
                                    .clipShape(Circle())
                                    .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                        }
                        
                        Button(action: stopWorkout) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.red.opacity(0.8))
                                .clipShape(Circle())
                                .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Mindfulness")
        .onAppear {
            if let activeWorkout = workoutCoordinator.activeWorkout,
               activeWorkout.workoutType == .meditation {
                metrics = activeWorkout.metrics
                isRunning = activeWorkout.state == .running
                startTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startWorkout() {
        workoutCoordinator.startWorkout(type: .meditation)
        isRunning = true
        startTimer()
    }
    
    private func pauseWorkout() {
        workoutCoordinator.pauseWorkout()
        isRunning = false
    }
    
    private func stopWorkout() {
        workoutCoordinator.stopWorkout()
        isRunning = false
        stopTimer()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateMetrics()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateMetrics() {
        guard isRunning else { return }
        metrics.elapsedTime += 1.0
        workoutCoordinator.updateMetrics(metrics)
    }
}
