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
        ScrollView {
            VStack(spacing: 12) {
                // Session name
                Text(sessionName)
                    .font(.headline)
                    .foregroundColor(.orange)
                
                // Time
                Text(formatTime(elapsedTime))
                    .font(.system(size: 24, weight: .bold))
                
                // Stats row
                HStack(spacing: 16) {
                    VStack {
                        Text("VOLUME")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(formatVolume(totalVolume))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    VStack {
                        Text("REPS")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("\(totalReps)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    VStack {
                        Text("HR")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("\(Int(heartRate))")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.vertical, 8)
                
                // Current movement
                if let movement = currentMovement {
                    VStack(spacing: 4) {
                        Text("CURRENT")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(movement)
                            .font(.caption)
                            .fontWeight(.semibold)
                        if currentSet > 0 {
                            Text("Set \(currentSet)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                
                // Control buttons
                HStack(spacing: 20) {
                    if isTracking {
                        Button(action: pauseWorkout) {
                            Image(systemName: "pause.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.orange)
                                .clipShape(Circle())
                        }
                    } else {
                        Button(action: startWorkout) {
                            Image(systemName: "play.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.green)
                                .clipShape(Circle())
                        }
                    }
                    
                    Button(action: logSet) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    
                    Button(action: stopWorkout) {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Gym")
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
        VStack(spacing: 16) {
            Text("Log Set")
                .font(.headline)
            
            // Reps input
            VStack {
                Text("Reps")
                    .font(.caption)
                Stepper(value: $reps, in: 0...100) {
                    Text("\(reps)")
                        .font(.title2)
                }
            }
            
            // Weight input
            VStack {
                Text("Weight (lbs)")
                    .font(.caption)
                Stepper(value: $weight, in: 0...1000, step: 5) {
                    Text("\(Int(weight))")
                        .font(.title2)
                }
            }
            
            Button("Save") {
                onSave()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

