//
//  SwimmingWorkoutView.swift
//  Do Watch App
//
//  Swimming workout interface
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import HealthKit

struct SwimmingWorkoutView: View {
    @EnvironmentObject var workoutCoordinator: WatchWorkoutCoordinator
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    
    @State private var metrics = WorkoutMetrics()
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var laps: Int = 0
    @State private var poolLength: Double = 25.0 // meters
    
    var body: some View {
        ZStack {
            AmbientBackground(color: .cyan)
            
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "figure.pool.swim")
                        .font(.caption)
                        .foregroundColor(.cyan)
                    Text("SWIMMING")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 4)
                
                // Hero (Laps)
                HeroMetric(value: "\(laps)", unit: "LAPS", color: .white)
                
                // Stats Grid
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        StatBox(label: "DISTANCE", value: formatDistance(metrics.distance), color: .cyan)
                        StatBox(label: "TIME", value: metrics.formattedTime(), color: .white)
                    }
                    
                    HStack(spacing: 8) {
                        StatBox(label: "HEART RATE", value: metrics.formattedHeartRate(), color: .red)
                        StatBox(label: "PACE/100m", value: formatPacePer100m(metrics.pace), color: .cyan)
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
                    color: .cyan,
                    customAction: logLap,
                    customIcon: "plus"
                )
                .padding(.bottom, 8)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if let activeWorkout = workoutCoordinator.activeWorkout,
               activeWorkout.workoutType == .swimming {
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
        workoutCoordinator.startWorkout(type: .swimming)
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
    
    private func logLap() {
        laps += 1
        metrics.distance += poolLength
        
        let message: [String: Any] = [
            "type": "swimLapCompleted",
            "laps": laps,
            "distance": metrics.distance,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        connectivityManager.sendMessage(message)
        workoutCoordinator.updateMetrics(metrics)
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
    
    private func formatDistance(_ distance: Double) -> String {
        return String(format: "%.0f m", distance)
    }
    
    private func formatPacePer100m(_ pace: Double) -> String {
        guard pace > 0 else { return "--:--" }
        let pacePer100m = pace * 100.0
        let minutes = Int(pacePer100m) / 60
        let seconds = Int(pacePer100m) % 60
        return String(format: "%d'%02d\"", minutes, seconds)
    }
}
