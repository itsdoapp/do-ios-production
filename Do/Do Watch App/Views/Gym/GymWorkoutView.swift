//
//  GymWorkoutView.swift
//  Do Watch App
//
//  Gym workout tracking interface for watch
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import HealthKit

struct GymWorkoutView: View {
    @EnvironmentObject var workoutCoordinator: WatchWorkoutCoordinator
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    
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
    
    @State private var showingSetInput = false
    @State private var setReps: Int = 0
    @State private var setWeight: Double = 0
    
    var body: some View {
        ZStack {
            AmbientBackground(color: .purple)
            
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption)
                        .foregroundColor(.purple)
                    Text(sessionName.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 4)
                
                // Hero (Time)
                HeroMetric(value: formatTime(elapsedTime), unit: "DURATION", color: .white)
                
                // Stats
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
                
                // Controls
                WorkoutControls(
                    isRunning: isTracking,
                    onPause: pauseWorkout,
                    onResume: startWorkout,
                    onStop: stopWorkout,
                    color: .purple,
                    customAction: logSet,
                    customIcon: "plus"
                )
                .padding(.bottom, 8)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingSetInput) {
            SetInputView(reps: $setReps, weight: $setWeight, onSave: {
                saveSet()
            })
        }
        .onAppear {
            requestWorkoutState()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startWorkout() {
        isTracking = true
        startTimer()
        
        let message: [String: Any] = [
            "type": "gymWorkoutStart",
            "sessionName": sessionName,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        connectivityManager.sendMessage(message)
    }
    
    private func pauseWorkout() {
        isTracking = false
        stopTimer()
        
        connectivityManager.sendMessage([
            "type": "gymWorkoutPause",
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    private func stopWorkout() {
        isTracking = false
        stopTimer()
        
        connectivityManager.sendMessage([
            "type": "gymWorkoutStop",
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    private func logSet() {
        showingSetInput = true
    }
    
    private func saveSet() {
        let setData: [String: Any] = [
            "type": "gymSetCompleted",
            "reps": setReps,
            "weight": setWeight,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        connectivityManager.sendMessage(setData)
        
        // Update local totals
        totalVolume += setWeight * Double(setReps)
        totalReps += setReps
        currentSet += 1
        
        // Reset input
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
                
                // Reps input
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
                
                // Weight input
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
