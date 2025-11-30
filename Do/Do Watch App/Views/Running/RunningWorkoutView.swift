//
//  RunningWorkoutView.swift
//  Do Watch App
//
//  Running workout interface
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import HealthKit
import CoreLocation

struct RunningWorkoutView: View {
    @EnvironmentObject var workoutCoordinator: WatchWorkoutCoordinator
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    
    @State private var metrics = WorkoutMetrics()
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var liveIndicatorOpacity: Double = 1.0
    
    var body: some View {
        ZStack {
            AmbientBackground(color: Color.brandOrange)
            
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "figure.run")
                        .font(.caption)
                        .foregroundColor(Color.brandOrange)
                    Text("RUNNING")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    Spacer()
                    if isRunning {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .opacity(liveIndicatorOpacity)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1).repeatForever()) {
                                    liveIndicatorOpacity = 0.2
                                }
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                
                // Hero Metric (Distance)
                HeroMetric(
                    value: metrics.formattedDistance().replacingOccurrences(of: " mi", with: "").replacingOccurrences(of: " km", with: ""),
                    unit: metrics.formattedDistance().contains("mi") ? "MILES" : "KILOMETERS",
                    color: Color.brandOrange
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
                    color: Color.brandOrange
                )
                .padding(.bottom, 8)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if let activeWorkout = workoutCoordinator.activeWorkout,
               activeWorkout.workoutType == .running {
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
        workoutCoordinator.startWorkout(type: .running)
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
        
        // Update elapsed time
        metrics.elapsedTime += 1.0
        
        // Update other metrics (would come from HealthKit in real implementation)
        // For now, simulate updates
        if metrics.distance > 0 {
            metrics.pace = metrics.elapsedTime / metrics.distance
        }
        
        // Sync to coordinator
        workoutCoordinator.updateMetrics(metrics)
    }
}
