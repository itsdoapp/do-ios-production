//
//  SportsWorkoutView.swift
//  Do Watch App
//
//  Sports workout interface
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import HealthKit

struct SportsWorkoutView: View {
    @EnvironmentObject var workoutCoordinator: WatchWorkoutCoordinator
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    
    @State private var metrics = WorkoutMetrics()
    @State private var isRunning = false
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            AmbientBackground(color: .red)
            
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "sportscourt")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text("SPORTS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 4)
                
                // Hero (Heart Rate)
                HeroMetric(value: metrics.formattedHeartRate().replacingOccurrences(of: " bpm", with: ""), unit: "BPM", color: .red)
                
                // Stats Grid
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        StatBox(label: "TIME", value: metrics.formattedTime(), color: .white)
                        StatBox(label: "CALORIES", value: metrics.formattedCalories(), color: .orange)
                    }
                    
                    // Placeholder for other metrics if available, e.g., Points or Steps
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Controls
                WorkoutControls(
                    isRunning: isRunning,
                    onPause: pauseWorkout,
                    onResume: startWorkout,
                    onStop: stopWorkout,
                    color: .red
                )
                .padding(.bottom, 8)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if let activeWorkout = workoutCoordinator.activeWorkout,
               activeWorkout.workoutType == .sports {
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
        workoutCoordinator.startWorkout(type: .sports)
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
        workoutCoordinator.updateMetrics(metrics)
    }
}
