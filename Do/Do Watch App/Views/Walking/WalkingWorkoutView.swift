//
//  WalkingWorkoutView.swift
//  Do Watch App
//
//  Walking workout interface
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import HealthKit

struct WalkingWorkoutView: View {
    @EnvironmentObject var workoutCoordinator: WatchWorkoutCoordinator
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    
    @State private var metrics = WorkoutMetrics()
    @State private var isRunning = false
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            AmbientBackground(color: .blue)
            
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "figure.walk")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("WALKING")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 4)
                
                // Hero (Distance)
                HeroMetric(
                    value: metrics.formattedDistance().replacingOccurrences(of: " mi", with: "").replacingOccurrences(of: " km", with: ""),
                    unit: metrics.formattedDistance().contains("mi") ? "MILES" : "KILOMETERS",
                    color: .blue
                )
                
                // Stats Grid
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        StatBox(label: "TIME", value: metrics.formattedTime(), color: .white)
                        StatBox(label: "PACE", value: metrics.formattedPace(), color: .white)
                    }
                    
                    HStack(spacing: 8) {
                        StatBox(label: "HEART RATE", value: metrics.formattedHeartRate(), color: .red)
                        StatBox(label: "CALORIES", value: metrics.formattedCalories(), color: .orange)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Controls
                WorkoutControls(
                    isRunning: isRunning,
                    onPause: pauseWorkout,
                    onResume: startWorkout,
                    onStop: stopWorkout,
                    color: .blue
                )
                .padding(.bottom, 8)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if let activeWorkout = workoutCoordinator.activeWorkout,
               activeWorkout.workoutType == .walking {
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
        workoutCoordinator.startWorkout(type: .walking)
        isRunning = true
        startTimer()
        LiveMetricsSync.shared.startLiveSync()
    }
    
    private func pauseWorkout() {
        workoutCoordinator.pauseWorkout()
        isRunning = false
    }
    
    private func stopWorkout() {
        workoutCoordinator.stopWorkout()
        isRunning = false
        stopTimer()
        LiveMetricsSync.shared.stopLiveSync()
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
        if metrics.distance > 0 {
            metrics.pace = metrics.elapsedTime / metrics.distance
        }
        workoutCoordinator.updateMetrics(metrics)
    }
}
