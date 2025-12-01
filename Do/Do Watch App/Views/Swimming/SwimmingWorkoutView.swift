//
//  SwimmingWorkoutView.swift
//  Do Watch App
//
//  Swimming workout interface
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import HealthKit
import WatchKit

struct SwimmingWorkoutView: View {
    @EnvironmentObject var workoutCoordinator: WatchWorkoutCoordinator
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var metrics = WorkoutMetrics()
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var laps: Int = 0
    @State private var poolLength: Double = 25.0
    @State private var selection: Int = 1
    @State private var showCountdown = false
    @State private var showCelebration = false
    @State private var celebrationMessage = ""
    @State private var workoutStartTime: Date?
    @State private var showCancelButton = true
    
    private let healthKitManager = HealthKitWorkoutManager.shared
    
    var body: some View {
        ZStack {
            AmbientBackground(color: .cyan, heartRate: metrics.heartRate)
            
            if showCountdown {
                IgnitionCountdownView(
                    workoutType: "Swimming",
                    workoutColor: .cyan,
                    onComplete: {
                        showCountdown = false
                        actuallyStartWorkout()
                    },
                    onCancel: {
                        showCountdown = false
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            } else if showCelebration {
                CelebrationView(
                    achievement: celebrationMessage,
                    color: .cyan
                )
                .onAppear {
                    WKInterfaceDevice.current().play(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        showCelebration = false
                        completeWorkoutStop()
                    }
                }
            } else {
                ZStack {
                    TabView(selection: $selection) {
                        WorkoutControlsPage(
                            isRunning: isRunning,
                            onPause: pauseWorkout,
                            onResume: resumeWorkout,
                            onStop: stopWorkout,
                            color: .cyan,
                            showCancel: showCancelButton && workoutStartTime != nil && Date().timeIntervalSince(workoutStartTime!) < 10,
                            onCancel: cancelWorkout
                        )
                        .tag(0)
                        
                        metricsView
                            .tag(1)
                        
                        NowPlayingView()
                            .tag(2)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if workoutCoordinator.activeWorkout == nil {
                showCountdown = true
            } else if let activeWorkout = workoutCoordinator.activeWorkout,
                      activeWorkout.workoutType == .swimming {
                metrics = activeWorkout.metrics
                isRunning = activeWorkout.state == .running
                if isRunning {
                    workoutStartTime = activeWorkout.startDate
                    startTimer()
                    DispatchQueue.main.asyncAfter(deadline: .now() + max(0, 10 - Date().timeIntervalSince(activeWorkout.startDate))) {
                        showCancelButton = false
                    }
                }
            }
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private var metricsView: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "figure.pool.swim")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.cyan)
                }
                
                Text("SWIMMING")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 4)
            
            HeroMetric(value: "\(laps)", unit: "LAPS", color: .cyan)
            
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
        }
    }
    
    private func actuallyStartWorkout() {
        workoutStartTime = Date()
        workoutCoordinator.startWorkout(type: .swimming)
        healthKitManager.startWorkout(type: .swimming)
        isRunning = true
        startTimer()
        LiveMetricsSync.shared.startLiveSync()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            showCancelButton = false
        }
    }
    
    private func resumeWorkout() {
        workoutCoordinator.resumeWorkout()
        healthKitManager.resumeWorkout()
        isRunning = true
        startTimer()
    }
    
    private func pauseWorkout() {
        workoutCoordinator.pauseWorkout()
        healthKitManager.pauseWorkout()
        isRunning = false
    }
    
    private func cancelWorkout() {
        if let startTime = workoutStartTime, Date().timeIntervalSince(startTime) < 10 {
            healthKitManager.cancelWorkout()
            workoutCoordinator.stopWorkout()
            isRunning = false
            stopTimer()
            LiveMetricsSync.shared.stopLiveSync()
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func stopWorkout() {
        celebrationMessage = "Great Swim!"
        showCelebration = true
    }
    
    private func completeWorkoutStop() {
        healthKitManager.endWorkout()
        workoutCoordinator.stopWorkout()
        isRunning = false
        stopTimer()
        LiveMetricsSync.shared.stopLiveSync()
        presentationMode.wrappedValue.dismiss()
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
        
        // Get real metrics from HealthKit
        if let healthKitMetrics = healthKitManager.getCurrentMetrics() {
            metrics.distance = healthKitMetrics.distance
            metrics.elapsedTime = healthKitMetrics.elapsedTime
            metrics.heartRate = healthKitMetrics.heartRate
            metrics.calories = healthKitMetrics.calories
            metrics.pace = healthKitMetrics.pace
        } else {
            // Fallback: If HealthKit data not available yet, just increment time
            metrics.elapsedTime += 1.0
        }
        
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
