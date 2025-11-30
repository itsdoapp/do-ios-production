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
    
    // Brand colors
    private let brandOrange = Color(red: 0.969, green: 0.576, blue: 0.122)
    
    let workoutTypes: [(WorkoutType, String, String, Color)] = [
        (.meditation, "Meditation", "figure.mind.and.body", Color(hex: "9B87F5")),
        (.running, "Running", "figure.run", Color.brandOrange),
        (.biking, "Biking", "figure.outdoor.cycle", Color.green),
        (.hiking, "Hiking", "figure.hiking", Color.brown),
        (.walking, "Walking", "figure.walk", Color.blue),
        (.swimming, "Swimming", "figure.pool.swim", Color.cyan),
        (.sports, "Sports", "sportscourt", Color.red),
        (.gym, "Gym", "figure.strengthtraining.traditional", Color.purple)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if let activeWorkout = workoutCoordinator.activeWorkout {
                    // Active Workout View
                    VStack {
                        Text("Active Workout")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        NavigationLink(destination: workoutView(for: activeWorkout.workoutType), isActive: .constant(true)) {
                            EmptyView()
                        }
                        .hidden()
                        
                        NavigationLink(destination: workoutView(for: activeWorkout.workoutType)) {
                            WorkoutRowCard(
                                type: activeWorkout.workoutType,
                                name: "Return to Session",
                                icon: "play.circle.fill",
                                color: brandOrange,
                                isHighlighted: true
                            )
                        }
                        .buttonStyle(.plain)
                        .padding()
                    }
                } else {
                    // Workout List
                    ScrollView {
                        VStack(spacing: 12) {
                            // Header
                            Image("logo_45")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 26)
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                            
                            ForEach(workoutTypes.indices, id: \.self) { index in
                                let (type, name, icon, color) = workoutTypes[index]
                                
                                NavigationLink(destination: workoutView(for: type)) {
                                    WorkoutRowCard(
                                        type: type,
                                        name: name,
                                        icon: icon,
                                        color: color
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
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
        case .meditation:
            MeditationView()
        case .sports:
            SportsWorkoutView()
        case .gym:
            GymWorkoutView()
        }
    }
}

struct WorkoutRowCard: View {
    let type: WorkoutType
    let name: String
    let icon: String
    let color: Color
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon/Character Container
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                if type == .meditation {
                    MeditationCharacterView(category: "default")
                        .scaleEffect(0.55)
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundColor(color)
                }
            }
            
            // Text
            Text(name)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    isHighlighted ? color : color.opacity(0.3),
                    lineWidth: isHighlighted ? 2 : 1
                )
        )
    }
}
