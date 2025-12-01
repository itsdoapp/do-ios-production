//
//  MeditationView.swift
//  Do Watch App
//
//  Meditation session interface
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import HealthKit
import WatchKit

struct MeditationView: View {
    @EnvironmentObject var workoutCoordinator: WatchWorkoutCoordinator
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var metrics = WorkoutMetrics()
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var pulseScale: CGFloat = 1.0
    @State private var breatheLabel: String = "BREATHE IN"
    @State private var breatheOpacity: Double = 0.0
    @State private var selection: Int = 1
    @State private var showCountdown = false
    @State private var showCelebration = false
    @State private var celebrationMessage = ""
    @State private var workoutStartTime: Date?
    @State private var showCancelButton = true
    
    private let brandOrange = Color(red: 0.969, green: 0.576, blue: 0.122)
    private let healthKitManager = HealthKitWorkoutManager.shared
    
    var body: some View {
        ZStack {
            if isRunning {
                Circle()
                    .fill(brandOrange.opacity(0.2))
                    .frame(width: 180, height: 180)
                    .scaleEffect(pulseScale)
                    .blur(radius: 20)
                    .onAppear {
                        startBreathingAnimation()
                    }
            } else {
                AmbientBackground(color: brandOrange, heartRate: metrics.heartRate)
            }
            
            if showCountdown {
                IgnitionCountdownView(
                    workoutType: "Meditation",
                    workoutColor: brandOrange,
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
                    color: brandOrange
                )
                .onAppear {
                    WKInterfaceDevice.current().play(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        showCelebration = false
                        completeWorkoutStop()
                    }
                }
            } else {
                TabView(selection: $selection) {
                    WorkoutControlsPage(
                        isRunning: isRunning,
                        onPause: pauseWorkout,
                        onResume: resumeWorkout,
                        onStop: stopWorkout,
                        color: brandOrange,
                        showCancel: showCancelButton && workoutStartTime != nil && Date().timeIntervalSince(workoutStartTime!) < 10,
                        onCancel: cancelWorkout
                    )
                    .tag(0)
                    
                    mindfulnessView
                        .tag(1)
                    
                    NowPlayingView()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if workoutCoordinator.activeWorkout == nil {
                showCountdown = true
            } else if let activeWorkout = workoutCoordinator.activeWorkout,
                      activeWorkout.workoutType == .meditation {
                metrics = activeWorkout.metrics
                isRunning = activeWorkout.state == .running
                if isRunning {
                    workoutStartTime = activeWorkout.startDate
                    startTimer()
                    startBreathingAnimation()
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
    
    private var mindfulnessView: some View {
        VStack(spacing: 12) {
            Text("MINDFULNESS")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .padding(.top, 8)
            
            Text(breatheLabel)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .opacity(isRunning ? breatheOpacity : 0)
                .padding(.bottom, 4)
            
            Text(metrics.formattedTime())
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: brandOrange.opacity(0.3), radius: 10, x: 0, y: 0)
            
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
            
            Spacer()
        }
    }
    
    private func actuallyStartWorkout() {
        workoutStartTime = Date()
        workoutCoordinator.startWorkout(type: .meditation)
        healthKitManager.startWorkout(type: .meditation)
        isRunning = true
        startTimer()
        startBreathingAnimation()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            showCancelButton = false
        }
    }
    
    private func resumeWorkout() {
        workoutCoordinator.resumeWorkout()
        healthKitManager.resumeWorkout()
        isRunning = true
        startTimer()
        startBreathingAnimation()
    }
    
    private func pauseWorkout() {
        workoutCoordinator.pauseWorkout()
        healthKitManager.pauseWorkout()
        isRunning = false
        pulseScale = 1.0
        breatheOpacity = 0.0
    }
    
    private func cancelWorkout() {
        if let startTime = workoutStartTime, Date().timeIntervalSince(startTime) < 10 {
            healthKitManager.cancelWorkout()
            workoutCoordinator.stopWorkout()
            isRunning = false
            stopTimer()
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func stopWorkout() {
        celebrationMessage = "Well Done!"
        showCelebration = true
    }
    
    private func completeWorkoutStop() {
        healthKitManager.endWorkout()
        workoutCoordinator.stopWorkout()
        isRunning = false
        stopTimer()
        presentationMode.wrappedValue.dismiss()
    }
    
    private func startBreathingAnimation() {
        guard isRunning else { return }
        
        withAnimation(.easeInOut(duration: 4)) {
            pulseScale = 1.4
            breatheLabel = "BREATHE IN"
            breatheOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            guard self.isRunning else { return }
            withAnimation(.easeInOut(duration: 4)) {
                self.pulseScale = 1.0
                self.breatheLabel = "BREATHE OUT"
                self.breatheOpacity = 0.8
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                if self.isRunning {
                    self.startBreathingAnimation()
                }
            }
        }
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
        
        // Get real metrics from HealthKit (mainly elapsed time for meditation)
        if let healthKitMetrics = healthKitManager.getCurrentMetrics() {
            metrics.elapsedTime = healthKitMetrics.elapsedTime
            metrics.heartRate = healthKitMetrics.heartRate
            metrics.calories = healthKitMetrics.calories
        } else {
            // Fallback: If HealthKit data not available yet, just increment time
            metrics.elapsedTime += 1.0
        }
        
        workoutCoordinator.updateMetrics(metrics)
    }
}
