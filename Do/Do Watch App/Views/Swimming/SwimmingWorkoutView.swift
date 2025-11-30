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
        ScrollView {
            VStack(spacing: 16) {
                // Main metrics
                VStack(spacing: 8) {
                    Text(metrics.formattedTime())
                        .font(.system(size: 32, weight: .bold))
                    
                    Text(formatDistance(metrics.distance))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.orange)
                }
                .padding()
                
                // Secondary metrics
                HStack(spacing: 20) {
                    VStack {
                        Text("LAPS")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(laps)")
                            .font(.headline)
                    }
                    
                    VStack {
                        Text("HR")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(metrics.formattedHeartRate())
                            .font(.headline)
                    }
                    
                    VStack {
                        Text("PACE")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(formatPacePer100m(metrics.pace))
                            .font(.headline)
                    }
                }
                .padding()
                
                // Control buttons
                HStack(spacing: 20) {
                    if isRunning {
                        Button(action: pauseWorkout) {
                            Image(systemName: "pause.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.orange)
                                .clipShape(Circle())
                        }
                    } else {
                        Button(action: startWorkout) {
                            Image(systemName: "play.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.green)
                                .clipShape(Circle())
                        }
                    }
                    
                    Button(action: logLap) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    
                    Button(action: stopWorkout) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Swimming")
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

