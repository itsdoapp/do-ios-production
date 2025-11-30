//
//  WorkoutHistoryVC.swift
//  Do.
//
//  Created by Mikiyas Meseret on 3/26/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import UIKit
import SwiftUI

/// View controller for displaying workout history
class WorkoutHistoryVC: UIViewController {
    
    private var hostingController: UIHostingController<WorkoutHistoryView>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let historyView = WorkoutHistoryView()
        
        let hostingController = UIHostingController(rootView: historyView)
        self.hostingController = hostingController
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
    }
}

// MARK: - SwiftUI Workout History View

struct WorkoutHistoryView: View {
    @State private var workouts: [WorkoutHistoryItem] = []
    @State private var isLoading = true
    @State private var selectedFilter: HistoryFilter = .all
    
    enum HistoryFilter: String, CaseIterable {
        case all = "All"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case thisYear = "This Year"
    }
    
    var filteredWorkouts: [WorkoutHistoryItem] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedFilter {
        case .all:
            return workouts
        case .thisWeek:
            return workouts.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }
        case .thisMonth:
            return workouts.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        case .thisYear:
            return workouts.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .year) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(HistoryFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredWorkouts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No workouts found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Start tracking workouts to see your history here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredWorkouts) { workout in
                        WorkoutHistoryRow(workout: workout)
                    }
                }
            }
            .navigationTitle("Workout History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss handled by parent
                    }
                }
            }
            .onAppear {
                loadWorkoutHistory()
            }
        }
    }
    
    private func loadWorkoutHistory() {
        guard let userId = CurrentUserService.shared.userID else {
            isLoading = false
            return
        }
        
        // Load workout history from ActivityService using getSessionLogs
        ActivityService.shared.getSessionLogs(userId: userId, limit: 100) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let response):
                    if let logs = response.data?.logs {
                        workouts = logs.compactMap { log -> WorkoutHistoryItem? in
                            // Parse date from createdAt string
                            let formatter = ISO8601DateFormatter()
                            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            guard let date = formatter.date(from: log.createdAt) else {
                                return nil
                            }
                            
                            // Get log ID
                            let logId = log.id
                            
                            // Get session name or use default
                            let name = log.title ?? "Workout"
                            
                            // Get duration (in seconds)
                            let duration = Int(log.duration ?? 0)
                            
                            // Get calories
                            let calories = log.calories.flatMap { $0 > 0 ? Int($0) : nil }
                            
                            // Get total sets
                            let totalSets = log.totalSets
                            
                            return WorkoutHistoryItem(
                                id: logId,
                                name: name,
                                date: date,
                                duration: duration,
                                calories: calories,
                                totalSets: totalSets
                            )
                        }
                        .sorted { $0.date > $1.date } // Most recent first
                    }
                case .failure(let error):
                    print("❌ Error loading workout history: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct WorkoutHistoryItem: Identifiable {
    let id: String
    let name: String
    let date: Date
    let duration: Int // in seconds
    let calories: Int?
    let totalSets: Int?
}

struct WorkoutHistoryRow: View {
    let workout: WorkoutHistoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workout.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(formatDate(workout.date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                if workout.duration > 0 {
                    Label(formatDuration(workout.duration), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let calories = workout.calories, calories > 0 {
                    Label("\(calories) cal", systemImage: "flame")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let sets = workout.totalSets, sets > 0 {
                    Label("\(sets) sets", systemImage: "list.bullet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

