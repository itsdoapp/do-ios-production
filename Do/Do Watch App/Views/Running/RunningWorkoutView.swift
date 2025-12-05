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
import WatchKit
import Combine

struct RunningWorkoutView: View {
    @EnvironmentObject var workoutCoordinator: WatchWorkoutCoordinator
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @ObservedObject var settings = WatchSettingsManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var metrics = WorkoutMetrics()
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var liveIndicatorOpacity: Double = 1.0
    @State private var selection: Int = 1 // Default to center tab (Metrics)
    @State private var showIndoorOutdoorSelection = false
    @State private var showCountdown = false
    @State private var showCelebration = false
    @State private var celebrationMessage = ""
    @State private var averagePace: Double = 0.0 // Track average pace for ghost pacer
    @State private var workoutStartTime: Date?
    @State private var showCancelButton = true
    @State private var isIndoor: Bool = false // Track indoor/outdoor mode
    
    // watchOS 9.0+ Services
    private let healthKitManager = HealthKitWorkoutManager.shared
    @ObservedObject private var heartRateZoneService = HeartRateZoneService.shared
    @ObservedObject private var advancedMetricsService = AdvancedWorkoutMetricsService.shared
    @ObservedObject private var zoneAlertService = ZoneAlertService.shared
    @ObservedObject private var intervalService = CustomWorkoutIntervalService.shared
    @ObservedObject private var locationManager = WatchLocationManager.shared
    @State private var showAdvancedMetrics = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ZStack {
            // Heart-rate aware background
            AmbientBackground(color: Color.brandOrange, heartRate: metrics.heartRate)
            
            if showIndoorOutdoorSelection {
                // Indoor/Outdoor Selection
                IndoorOutdoorSelectionView(
                    isIndoor: $isIndoor,
                    onStart: {
                        showIndoorOutdoorSelection = false
                        showCountdown = true
                    },
                    onCancel: {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            } else if showCountdown {
                // Ignition Countdown
                IgnitionCountdownView(
                    workoutType: "Running",
                    workoutColor: Color.brandOrange,
                    onComplete: {
                        showCountdown = false
                        actuallyStartWorkout()
                    },
                    onCancel: {
                        showCountdown = false
                        showIndoorOutdoorSelection = true
                    }
                )
            } else if showCelebration {
                // Celebration View
                CelebrationView(
                    achievement: celebrationMessage,
                    color: Color.brandOrange
                )
                .onAppear {
                    // Haptic celebration
                    WKInterfaceDevice.current().play(.success)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        showCelebration = false
                        // Complete workout stop after celebration
                        completeWorkoutStop()
                    }
                }
            } else {
                ZStack {
                    TabView(selection: $selection) {
                        // Left Page: Controls
                        WorkoutControlsPage(
                            isRunning: isRunning,
                            onPause: pauseWorkout,
                            onResume: resumeWorkout,
                            onStop: stopWorkout,
                            color: Color.brandOrange
                        )
                        .tag(0)
                        
                        // Center Page: Metrics
                        metricsView
                            .tag(1)
                        
                        // Right Page: Now Playing
                        NowPlayingView()
                            .tag(2)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    
                    // Zone Alerts Overlay (watchOS 9.0+)
                    if !zoneAlertService.activeAlerts.isEmpty {
                        VStack {
                            Spacer()
                            ForEach(zoneAlertService.activeAlerts) { alert in
                                ZoneAlertBanner(alert: alert)
                                    .padding(.horizontal)
                                    .padding(.bottom, 4)
                            }
                        }
                    }
                    
                    // Cancel button (first 10 seconds)
                    if showCancelButton, let startTime = workoutStartTime, Date().timeIntervalSince(startTime) < 10 {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button(action: {
                                    WKInterfaceDevice.current().play(.click)
                                    cancelWorkout()
                                }) {
                                    Text("Cancel")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.15))
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 8)
                                .padding(.bottom, 8)
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Auto-start workout when view appears
            if workoutCoordinator.activeWorkout == nil {
                // Check if we received indoor mode from phone
                checkForIndoorModeFromPhone()
                // Show indoor/outdoor selection first
                showIndoorOutdoorSelection = true
            } else if let activeWorkout = workoutCoordinator.activeWorkout,
                      activeWorkout.workoutType == .running {
                metrics = activeWorkout.metrics
                isRunning = activeWorkout.state == .running
                if isRunning {
                    workoutStartTime = activeWorkout.startDate
                    startTimer()
                    // Hide cancel button after 10 seconds
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
    
    // Extracted Metrics View
    private var metricsView: some View {
        VStack(spacing: 8) {
            // Header with enhanced icon
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.brandOrange.opacity(0.2))
                        .frame(width: 20, height: 20)
                    
                    Image(systemName: isIndoor ? "figure.run.circle" : "figure.run")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.brandOrange)
                }
                
                Text(isIndoor ? "INDOOR RUN" : "OUTDOOR RUN")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                
                Spacer()
                
                if isRunning {
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .opacity(liveIndicatorOpacity)
                        
                        Circle()
                            .stroke(Color.green.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 12, height: 12)
                            .scaleEffect(liveIndicatorOpacity < 0.5 ? 1.5 : 1.0)
                            .opacity(liveIndicatorOpacity)
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1).repeatForever()) {
                            liveIndicatorOpacity = 0.2
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 2)
            
            // Hero Metric (Distance)
            HeroMetric(
                value: formatDistance(metrics.distance),
                unit: settings.useMetric ? "KM" : "MI",
                color: Color.brandOrange
            )
            
            // Ghost Pacer (if we have pace data)
            if isRunning && metrics.pace > 0 && averagePace > 0 {
                GhostPacerView(
                    currentPace: metrics.pace,
                    averagePace: averagePace,
                    color: Color.brandOrange
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
            }
            
            // Stats Grid
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    StatBox(label: "TIME", value: metrics.formattedTime(), color: .white)
                    StatBox(label: "PACE", value: formatPace(metrics.pace), color: .white)
                }
                
                HStack(spacing: 6) {
                    StatBox(label: "HR", value: metrics.formattedHeartRate(), color: .red)
                    StatBox(label: "CAL", value: metrics.formattedCalories(), color: .orange)
                }
            }
            .padding(.horizontal, 12)
            
            // Heart Rate Zone Indicator (watchOS 9.0+)
            if isRunning && metrics.heartRate > 0 {
                HeartRateZoneIndicator(
                    currentZone: heartRateZoneService.currentZone,
                    heartRate: metrics.heartRate
                )
                .padding(.horizontal, 12)
                .onChange(of: metrics.heartRate) { newHR in
                    healthKitManager.updateHeartRateZone(heartRate: newHR)
                }
            }
            
            // Advanced Metrics Toggle (watchOS 9.0+)
            if advancedMetricsService.currentMetrics.hasAnyMetrics {
                Button(action: {
                    showAdvancedMetrics.toggle()
                    WKInterfaceDevice.current().play(.click)
                }) {
                    HStack {
                        Text("ADVANCED")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                        Spacer()
                        Image(systemName: showAdvancedMetrics ? "chevron.up" : "chevron.down")
                            .font(.system(size: 7))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                
                if showAdvancedMetrics {
                    AdvancedMetricsView(metrics: advancedMetricsService.currentMetrics)
                        .padding(.horizontal, 12)
                        .transition(.opacity)
                }
            }
            
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
    
    private func checkForIndoorModeFromPhone() {
        // Check if phone sent indoor mode info
        // This would be set via WatchConnectivity when handoff occurs
        // For now, default to outdoor
        isIndoor = false
        
        // Listen for indoor mode messages from phone
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RunningWorkoutStateChanged"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let isIndoor = userInfo["isIndoor"] as? Bool {
                self.isIndoor = isIndoor
            }
        }
    }
    
    private func formatPace(_ paceInSecondsPerMeter: Double) -> String {
        guard paceInSecondsPerMeter > 0 && paceInSecondsPerMeter.isFinite else { return "--:--" }
        
        let pace: Double
        if settings.useMetric {
             // min/km
            pace = paceInSecondsPerMeter * 1000 / 60
        } else {
             // min/mi
            pace = paceInSecondsPerMeter * 1609.34 / 60
        }
        
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func actuallyStartWorkout() {
        workoutStartTime = Date()
        workoutCoordinator.startWorkout(type: WorkoutType.running)
        healthKitManager.startWorkout(type: WorkoutType.running, isIndoor: isIndoor) // Start HealthKit tracking with location type
        isRunning = true
        startTimer()
        LiveMetricsSync.shared.startLiveSync()
        
        // Start location tracking for outdoor runs
        if !isIndoor {
            locationManager.requestAuthorization()
            locationManager.startTracking()
        }
        
        // Notify phone about indoor/outdoor mode
        connectivityManager.sendMessage([
            "type": "runningWorkoutStart",
            "isIndoor": isIndoor,
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // Hide cancel button after 10 seconds
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
        // Cancel workout if less than 10 seconds
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
        // Check for personal best (simplified - in real app, compare to stored records)
        let finalPace = metrics.pace
        if finalPace > 0 && (averagePace == 0 || finalPace < averagePace * 0.95) {
            // Personal best detected (5% faster than average)
            celebrationMessage = "PERSONAL BEST!"
            showCelebration = true
        } else {
            // Normal completion
            completeWorkoutStop()
        }
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
            "workoutType": "running",
            "locations": locationData,
            "timestamp": Date().timeIntervalSince1970
        ])
        print("📍 [RunningWorkoutView] Sent \(locationData.count) locations to phone")
    }
    
    private func startTimer() {
        // Observe HealthKit metrics updates (published every second)
        healthKitManager.$currentMetrics
            .compactMap { $0 }
            .sink { [self] healthKitMetrics in
                guard self.isRunning else { return }
                // Update metrics with real HealthKit data
                self.metrics = healthKitMetrics
                
                // Update average pace
                if self.metrics.pace > 0 {
                    if self.averagePace == 0 {
                        self.averagePace = self.metrics.pace
                    } else {
                        self.averagePace = (self.averagePace * 0.9) + (self.metrics.pace * 0.1)
                    }
                }
                
                // Update heart rate zone (watchOS 9.0+)
                if self.metrics.heartRate > 0 {
                    self.healthKitManager.updateHeartRateZone(heartRate: self.metrics.heartRate)
                }
                
                // Sync to coordinator
                self.workoutCoordinator.updateMetrics(self.metrics)
            }
            .store(in: &cancellables)
        
        // Fallback timer for UI updates (in case HealthKit is slow to start)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            guard self.isRunning else { return }
            // If HealthKit hasn't updated yet, at least update elapsed time
            if self.metrics.elapsedTime == 0 {
                self.metrics.elapsedTime += 1.0
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
    }
    
}
