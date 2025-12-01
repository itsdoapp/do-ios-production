//
//  SportsWorkoutView.swift
//  Do Watch App
//
//  Sports workout interface
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import HealthKit
import WatchKit

struct SportsWorkoutView: View {
    @EnvironmentObject var workoutCoordinator: WatchWorkoutCoordinator
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var metrics = WorkoutMetrics()
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var selection: Int = 1
    @State private var showCountdown = false
    @State private var showCelebration = false
    @State private var celebrationMessage = ""
    @State private var workoutStartTime: Date?
    @State private var showCancelButton = true
    
    private let healthKitManager = HealthKitWorkoutManager.shared
    
    var body: some View {
        ZStack {
            AmbientBackground(color: .red, heartRate: metrics.heartRate)
            
            if showCountdown {
                IgnitionCountdownView(
                    workoutType: "Sports",
                    workoutColor: .red,
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
                    color: .red
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
                            color: .red,
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
                      activeWorkout.workoutType == .sports {
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
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "sportscourt")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red)
                }
                
                Text("SPORTS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 4)
            
            HeroMetric(
                value: metrics.formattedHeartRate().replacingOccurrences(of: " bpm", with: ""),
                unit: "BPM",
                color: .red
            )
            
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    StatBox(label: "TIME", value: metrics.formattedTime(), color: .white)
                    StatBox(label: "CALORIES", value: metrics.formattedCalories(), color: .orange)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private func actuallyStartWorkout() {
        workoutStartTime = Date()
        workoutCoordinator.startWorkout(type: .sports)
        healthKitManager.startWorkout(type: .sports)
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
        celebrationMessage = "Great Session!"
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
}
