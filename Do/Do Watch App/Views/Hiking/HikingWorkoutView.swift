//
//  HikingWorkoutView.swift
//  Do Watch App
//
//  Hiking workout interface
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import HealthKit
import WatchKit
import CoreLocation

struct HikingWorkoutView: View {
    @EnvironmentObject var workoutCoordinator: WatchWorkoutCoordinator
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @ObservedObject var settings = WatchSettingsManager.shared
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
    @ObservedObject private var locationManager = WatchLocationManager.shared
    
    var body: some View {
        ZStack {
            AmbientBackground(color: .brown, heartRate: metrics.heartRate)
            
            if showCountdown {
                IgnitionCountdownView(
                    workoutType: "Hiking",
                    workoutColor: .brown,
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
                    color: .brown
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
                            color: .brown,
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
                      activeWorkout.workoutType == .hiking {
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
                        .fill(Color.brown.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "figure.hiking")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.brown)
                }
                
                Text("HIKING")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 4)
            
            HeroMetric(
                value: formatDistance(metrics.distance),
                unit: settings.useMetric ? "KILOMETERS" : "MILES",
                color: .brown
            )
            
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    StatBox(label: "TIME", value: metrics.formattedTime(), color: .white)
                    StatBox(label: "PACE", value: formatPace(metrics.pace), color: .white)
                }
                
                HStack(spacing: 8) {
                    StatBox(label: "HEART RATE", value: metrics.formattedHeartRate(), color: .red)
                    StatBox(label: "CALORIES", value: metrics.formattedCalories(), color: .orange)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private func formatDistance(_ distanceInMeters: Double) -> String {
        if settings.useMetric {
            let km = distanceInMeters / 1000.0
            return String(format: "%.2f", km)
        } else {
            let miles = distanceInMeters * 0.000621371
            return String(format: "%.2f", miles)
        }
    }
    
    private func formatPace(_ paceInSecondsPerMeter: Double) -> String {
        guard paceInSecondsPerMeter > 0 && paceInSecondsPerMeter.isFinite else { return "--:--" }
        
        let pace: Double
        if settings.useMetric {
            pace = paceInSecondsPerMeter * 1000 / 60
        } else {
            pace = paceInSecondsPerMeter * 1609.34 / 60
        }
        
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func actuallyStartWorkout() {
        workoutStartTime = Date()
        workoutCoordinator.startWorkout(type: WorkoutType.hiking)
        healthKitManager.startWorkout(type: WorkoutType.hiking)
        isRunning = true
        startTimer()
        LiveMetricsSync.shared.startLiveSync()
        
        // Start location tracking
        locationManager.requestAuthorization()
        locationManager.startTracking()
        
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
            locationManager.stopTracking()
            locationManager.clearLocations()
            healthKitManager.cancelWorkout()
            workoutCoordinator.stopWorkout()
            isRunning = false
            stopTimer()
            LiveMetricsSync.shared.stopLiveSync()
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func stopWorkout() {
        celebrationMessage = "Great Hike!"
        showCelebration = true
    }
    
    private func completeWorkoutStop() {
        // Stop location tracking
        locationManager.stopTracking()
        
        // Send location data to phone before ending workout
        if !locationManager.locationList.isEmpty {
            sendLocationDataToPhone()
        }
        
        healthKitManager.endWorkout()
        workoutCoordinator.stopWorkout()
        isRunning = false
        stopTimer()
        LiveMetricsSync.shared.stopLiveSync()
        presentationMode.wrappedValue.dismiss()
    }
    
    private func sendLocationDataToPhone() {
        let locationData = locationManager.getLocationListAsDictionary()
        connectivityManager.sendMessage([
            "type": "workoutLocations",
            "workoutType": "hiking",
            "locations": locationData,
            "timestamp": Date().timeIntervalSince1970
        ])
        print("📍 [HikingWorkoutView] Sent \(locationData.count) locations to phone")
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
            metrics.elevationGain = healthKitMetrics.elevationGain
        } else {
            // Fallback: If HealthKit data not available yet, just increment time
            metrics.elapsedTime += 1.0
            if metrics.distance > 0 {
                metrics.pace = metrics.elapsedTime / metrics.distance
            }
        }
        
        workoutCoordinator.updateMetrics(metrics)
    }
}
