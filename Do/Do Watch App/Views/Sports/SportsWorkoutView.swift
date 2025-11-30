//
//  SportsWorkoutView.swift
//  Do Watch App
//
//  Sports workout interface
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import HealthKit
import CoreLocation

struct SportsWorkoutView: View {
    @EnvironmentObject var workoutCoordinator: WatchWorkoutCoordinator
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    
    @State private var metrics = WorkoutMetrics()
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var sportType: String = "Basketball"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Main metrics
                VStack(spacing: 8) {
                    Text(metrics.formattedTime())
                        .font(.system(size: 32, weight: .bold))
                    
                    Text(metrics.formattedDistance())
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.orange)
                }
                .padding()
                
                // Secondary metrics
                HStack(spacing: 20) {
                    VStack {
                        Text("HR")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(metrics.formattedHeartRate())
                            .font(.headline)
                    }
                    
                    VStack {
                        Text("CAL")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(metrics.formattedCalories())
                            .font(.headline)
                    }
                    
                    VStack {
                        Text("SPORT")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(sportType)
                            .font(.caption)
                            .fontWeight(.semibold)
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
        .navigationTitle("Sports")
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

