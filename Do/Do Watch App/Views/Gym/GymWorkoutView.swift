//
//  GymWorkoutView.swift
//  Do Watch App
//
//  Gym workout tracking interface for watch
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import HealthKit
import WatchKit

struct GymWorkoutView: View {
    @EnvironmentObject var workoutCoordinator: WatchWorkoutCoordinator
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var sessionName: String = "Gym Workout"
    @State private var elapsedTime: TimeInterval = 0
    @State private var totalCalories: Double = 0
    @State private var totalVolume: Double = 0
    @State private var totalReps: Int = 0
    @State private var heartRate: Double = 0
    @State private var currentMovement: String?
    @State private var currentSet: Int = 0
    @State private var isTracking = false
    @State private var timer: Timer?
    @State private var selection: Int = 1
    @State private var showCountdown = false
    @State private var showCelebration = false
    @State private var celebrationMessage = ""
    @State private var workoutStartTime: Date?
    @State private var showCancelButton = true
    
    @State private var showingSetInput = false
    @State private var setReps: Int = 0
    @State private var setWeight: Double = 0
    @State private var isOpenTraining: Bool = false // Track if this is open training mode
    
    private let healthKitManager = HealthKitWorkoutManager.shared
    
    var body: some View {
        ZStack {
            AmbientBackground(color: .purple, heartRate: heartRate)
            
            if showCountdown {
                IgnitionCountdownView(
                    workoutType: "Gym",
                    workoutColor: .purple,
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
                    color: .purple
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
                    gymControlsPage
                        .tag(0)
                    
                    metricsView
                        .tag(1)
                    
                    NowPlayingView()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingSetInput) {
            SetInputView(reps: $setReps, weight: $setWeight, onSave: {
                saveSet()
            })
        }
        .onAppear {
            if workoutCoordinator.activeWorkout == nil {
                // Check if we received open training mode from phone
                checkForOpenTrainingFromPhone()
                showCountdown = true
            } else {
                requestWorkoutState()
            }
            
            // Listen for set updates from phone
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("GymSetCompleted"),
                object: nil,
                queue: .main
            ) { [ self] notification in
                if let userInfo = notification.userInfo,
                   let reps = userInfo["reps"] as? Int,
                   let weight = userInfo["weight"] as? Double {
                    self.totalReps += reps
                    self.totalVolume += weight * Double(reps)
                    self.currentSet += 1
                }
            }
            
            // Listen for gym workout state updates
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("GymWorkoutStateChanged"),
                object: nil,
                queue: .main
            ) { [ self] notification in
                if let userInfo = notification.userInfo {
                    if let elapsed = userInfo["elapsedTime"] as? TimeInterval {
                        self.elapsedTime = elapsed
                    }
                    if let volume = userInfo["totalVolume"] as? Double {
                        self.totalVolume = volume
                    }
                    if let reps = userInfo["totalReps"] as? Int {
                        self.totalReps = reps
                    }
                    if let hr = userInfo["heartRate"] as? Double {
                        self.heartRate = hr
                    }
                    if let movement = userInfo["currentMovement"] as? String {
                        self.currentMovement = movement
                    }
                }
            }
            
            // Listen for sets updates from phone
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("GymSetsUpdate"),
                object: nil,
                queue: .main
            ) { [self] notification in
                if let userInfo = notification.userInfo {
                    if let volume = userInfo["totalVolume"] as? Double {
                        self.totalVolume = volume
                    }
                    if let reps = userInfo["totalReps"] as? Int {
                        self.totalReps = reps
                    }
                }
            }
            
            // Listen for real-time metrics updates
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("GymMetricsUpdate"),
                object: nil,
                queue: .main
            ) { [self] notification in
                if let userInfo = notification.userInfo {
                    if let elapsed = userInfo["elapsedTime"] as? TimeInterval {
                        self.elapsedTime = elapsed
                    }
                    if let volume = userInfo["totalVolume"] as? Double {
                        self.totalVolume = volume
                    }
                    if let reps = userInfo["totalReps"] as? Int {
                        self.totalReps = reps
                    }
                    if let hr = userInfo["heartRate"] as? Double {
                        self.heartRate = hr
                    }
                }
            }
        }
        .onDisappear {
            stopTimer()
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("GymSetCompleted"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("GymWorkoutStateChanged"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("GymSetsUpdate"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("GymMetricsUpdate"), object: nil)
        }
    }
    
    private var gymControlsPage: some View {
        VStack(spacing: 12) {
            Spacer()
            
            // Cancel button (first 10 seconds)
            if showCancelButton && workoutStartTime != nil && Date().timeIntervalSince(workoutStartTime!) < 10 {
                Button(action: cancelWorkout) {
                    VStack {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                        Text("Cancel")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(25)
                }
                .buttonStyle(.plain)
            }
            
            // Log Set Button
            Button(action: logSet) {
                VStack {
                    Image(systemName: "plus")
                        .font(.title2)
                    Text("Log Set")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.purple.opacity(0.3))
                .cornerRadius(25)
            }
            .buttonStyle(.plain)
            
            // Pause / Resume Button
            Button(action: {
                if isTracking {
                    pauseWorkout()
                } else {
                    resumeWorkout()
                }
            }) {
                VStack {
                    Image(systemName: isTracking ? "pause.fill" : "play.fill")
                        .font(.title2)
                    Text(isTracking ? "Pause" : "Resume")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(25)
            }
            .buttonStyle(.plain)
            
            // End Workout Button
            Button(action: stopWorkout) {
                VStack {
                    Image(systemName: "xmark")
                        .font(.title2)
                    Text("End")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.red.opacity(0.2))
                .cornerRadius(25)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var metricsView: some View {
            VStack(spacing: 12) {
                HStack {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.purple)
                }
                
                    Text(sessionName.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 4)
                
                HeroMetric(value: formatTime(elapsedTime), unit: "DURATION", color: .white)
                
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        StatBox(label: "VOLUME", value: formatVolume(totalVolume), color: .purple)
                        StatBox(label: "SETS", value: "\(currentSet)", color: .purple)
                    }
                    
                    HStack(spacing: 8) {
                        StatBox(label: "REPS", value: "\(totalReps)", color: .white)
                        StatBox(label: "HEART RATE", value: "\(Int(heartRate))", color: .red)
                    }
                }
                .padding(.horizontal)
                
                if let movement = currentMovement {
                    Text(movement.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                        .padding(.top, 4)
                }
                
                Spacer()
        }
    }
    
    private func actuallyStartWorkout() {
        workoutStartTime = Date()
        
        // Update session name if open training
        if isOpenTraining {
            sessionName = "Open Training"
        }
        
        workoutCoordinator.startWorkout(type: WorkoutType.gym)
        healthKitManager.startWorkout(type: WorkoutType.gym) // Gym workouts are always indoor
        isTracking = true
        startTimer()
        
        let message: [String: Any] = [
            "type": "gymWorkoutStart",
            "sessionName": sessionName,
            "isOpenTraining": isOpenTraining,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        connectivityManager.sendMessage(message)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            showCancelButton = false
        }
    }
    
    private func resumeWorkout() {
        workoutCoordinator.resumeWorkout()
        healthKitManager.resumeWorkout()
        isTracking = true
        startTimer()
    }
    
    private func pauseWorkout() {
        workoutCoordinator.pauseWorkout()
        healthKitManager.pauseWorkout()
        isTracking = false
        stopTimer()
        
        connectivityManager.sendMessage([
            "type": "gymWorkoutPause",
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    private func cancelWorkout() {
        if let startTime = workoutStartTime, Date().timeIntervalSince(startTime) < 10 {
            healthKitManager.cancelWorkout()
            workoutCoordinator.stopWorkout()
            isTracking = false
            stopTimer()
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func stopWorkout() {
        celebrationMessage = "Great Workout!"
        showCelebration = true
    }
    
    private func completeWorkoutStop() {
        healthKitManager.endWorkout()
        workoutCoordinator.stopWorkout()
        isTracking = false
        stopTimer()
        
        connectivityManager.sendMessage([
            "type": "gymWorkoutStop",
            "timestamp": Date().timeIntervalSince1970
        ])
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func logSet() {
        showingSetInput = true
    }
    
    private func saveSet() {
        let setData: [String: Any] = [
            "type": "gymSetCompleted",
            "movementId": currentMovement ?? "openTraining",
            "movementName": currentMovement ?? "Open Training",
            "reps": setReps,
            "weight": setWeight,
            "duration": 0, // For rep-based sets
            "timestamp": Date().timeIntervalSince1970
        ]
        
        connectivityManager.sendMessage(setData)
        
        totalVolume += setWeight * Double(setReps)
        totalReps += setReps
        currentSet += 1
        
        setReps = 0
        setWeight = 0
        showingSetInput = false
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1.0
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func requestWorkoutState() {
        connectivityManager.sendMessage(["request": "gymWorkoutState"]) { response in
            DispatchQueue.main.async {
                if let isTracking = response["isTracking"] as? Bool {
                    self.isTracking = isTracking
                }
                if let elapsedTime = response["elapsedTime"] as? TimeInterval {
                    self.elapsedTime = elapsedTime
                }
                if let totalVolume = response["totalVolume"] as? Double {
                    self.totalVolume = totalVolume
                }
                if let totalReps = response["totalReps"] as? Int {
                    self.totalReps = totalReps
                }
                if let heartRate = response["heartRate"] as? Double {
                    self.heartRate = heartRate
                }
                if let currentMovement = response["currentMovement"] as? String {
                    self.currentMovement = currentMovement
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 2000 {
            return String(format: "%.1ft", volume / 2000.0)
        } else {
            return String(format: "%.0flbs", volume)
        }
    }
    
    private func checkForOpenTrainingFromPhone() {
        // Check if phone sent open training info
        // This would be set via WatchConnectivity when handoff occurs
        // For now, default to false (structured workout)
        isOpenTraining = false
        
        // Listen for open training messages
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("GymWorkoutStateChanged"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let isOpenTraining = userInfo["isOpenTraining"] as? Bool {
                self.isOpenTraining = isOpenTraining
                if isOpenTraining {
                    self.sessionName = "Open Training"
                }
            }
        }
    }
}

// MARK: - Set Input View

struct SetInputView: View {
    @Binding var reps: Int
    @Binding var weight: Double
    var onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Log Set")
                    .font(.headline)
                    .foregroundColor(.purple)
                
                VStack {
                    Text("REPS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    Stepper(value: $reps, in: 0...100) {
                        Text("\(reps)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
                
                VStack {
                    Text("WEIGHT (LBS)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    Stepper(value: $weight, in: 0...1000, step: 5) {
                        Text("\(Int(weight))")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
                
                Button(action: {
                    onSave()
                    dismiss()
                }) {
                    Text("SAVE SET")
                        .fontWeight(.bold)
                }
                .tint(.purple)
                .padding(.top, 8)
            }
        }
    }
}
