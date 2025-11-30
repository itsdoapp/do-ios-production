//
//  WorkoutListView.swift
//  Do Watch App
//
//  Main workout selection screen
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

struct WorkoutListView: View {
    @EnvironmentObject var workoutCoordinator: WatchWorkoutCoordinator
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    
    @State private var selectedWorkoutType: WorkoutType?
    
    let workoutTypes: [(WorkoutType, String, String)] = [
        (.running, "Running", "figure.run"),
        (.biking, "Biking", "figure.outdoor.cycle"),
        (.hiking, "Hiking", "figure.hiking"),
        (.walking, "Walking", "figure.walk"),
        (.swimming, "Swimming", "figure.pool.swim"),
        (.sports, "Sports", "sportscourt"),
        (.gym, "Gym", "figure.strengthtraining.traditional")
    ]
    
    var body: some View {
        NavigationView {
            List {
                if let activeWorkout = workoutCoordinator.activeWorkout {
                    Section {
                        NavigationLink(destination: workoutView(for: activeWorkout.workoutType)) {
                            HStack {
                                Image(systemName: iconForWorkoutType(activeWorkout.workoutType))
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading) {
                                    Text("Active Workout")
                                        .font(.headline)
                                    Text(activeWorkout.workoutType.rawValue.capitalized)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Text(activeWorkout.metrics.formattedTime())
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                
                Section("Start Workout") {
                    ForEach(workoutTypes, id: \.0) { workoutType, name, icon in
                        NavigationLink(destination: workoutView(for: workoutType)) {
                            HStack {
                                Image(systemName: icon)
                                    .foregroundColor(.blue)
                                Text(name)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
        }
    }
    
    @ViewBuilder
    private func workoutView(for type: WorkoutType) -> some View {
        switch type {
        case .running:
            RunningWorkoutView()
        case .biking:
            BikingWorkoutView()
        case .hiking:
            HikingWorkoutView()
        case .walking:
            WalkingWorkoutView()
        case .swimming:
            SwimmingWorkoutView()
        case .sports:
            SportsWorkoutView()
        case .gym:
            GymWorkoutView()
        }
    }
    
    private func iconForWorkoutType(_ type: WorkoutType) -> String {
        switch type {
        case .running: return "figure.run"
        case .biking: return "figure.outdoor.cycle"
        case .hiking: return "figure.hiking"
        case .walking: return "figure.walk"
        case .swimming: return "figure.pool.swim"
        case .sports: return "sportscourt"
        case .gym: return "figure.strengthtraining.traditional"
        }
    }
}

