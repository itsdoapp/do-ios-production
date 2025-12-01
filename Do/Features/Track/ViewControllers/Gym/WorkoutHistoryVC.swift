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
    @State private var selectedType: LogType = .all
    
    enum HistoryFilter: String, CaseIterable {
        case all = "All"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case thisYear = "This Year"
    }
    
    enum LogType: String, CaseIterable {
        case all = "All"
        case sessions = "Sessions"
        case movements = "Movements"
        case plans = "Plans"
    }
    
    var filteredWorkouts: [WorkoutHistoryItem] {
        let calendar = Calendar.current
        let now = Date()
        
        var filtered = workouts
        
        // Filter by type
        switch selectedType {
        case .all:
            break
        case .sessions:
            filtered = filtered.filter { $0.logType == .session }
        case .movements:
            filtered = filtered.filter { $0.logType == .movement }
        case .plans:
            filtered = filtered.filter { $0.logType == .plan }
        }
        
        // Filter by date
        switch selectedFilter {
        case .all:
            return filtered
        case .thisWeek:
            return filtered.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }
        case .thisMonth:
            return filtered.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        case .thisYear:
            return filtered.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .year) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Type Picker
                Picker("Type", selection: $selectedType) {
                    ForEach(LogType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Date Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(HistoryFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.bottom, 8)
                
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
        
        isLoading = true
        var allWorkouts: [WorkoutHistoryItem] = []
        let dispatchGroup = DispatchGroup()
        
        // Load session logs with pagination
        dispatchGroup.enter()
        loadSessionLogs(userId: userId) { sessionItems in
            allWorkouts.append(contentsOf: sessionItems)
            dispatchGroup.leave()
        }
        
        // Load movement logs with pagination
        dispatchGroup.enter()
        loadMovementLogs(userId: userId) { movementItems in
            allWorkouts.append(contentsOf: movementItems)
            dispatchGroup.leave()
        }
        
        // Load plan logs with pagination
        dispatchGroup.enter()
        loadPlanLogs(userId: userId) { planItems in
            allWorkouts.append(contentsOf: planItems)
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            // Sort by date (most recent first)
            self.workouts = allWorkouts.sorted { $0.date > $1.date }
            self.isLoading = false
            print("✅ Loaded \(self.workouts.count) total workout logs (sessions: \(allWorkouts.filter { $0.logType == .session }.count), movements: \(allWorkouts.filter { $0.logType == .movement }.count), plans: \(allWorkouts.filter { $0.logType == .plan }.count))")
        }
    }
    
    private func loadSessionLogs(userId: String, completion: @escaping ([WorkoutHistoryItem]) -> Void) {
        var allItems: [WorkoutHistoryItem] = []
        var nextToken: String? = nil
        
        func fetchPage() {
            ActivityService.shared.getSessionLogs(
                userId: userId,
                limit: 100,
                nextToken: nextToken
            ) { result in
                switch result {
                case .success(let response):
                    if let logs = response.data?.logs {
                        let items = logs.compactMap { log -> WorkoutHistoryItem? in
                            let formatter = ISO8601DateFormatter()
                            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            guard let date = formatter.date(from: log.createdAt) else {
                                return nil
                            }
                            
                            return WorkoutHistoryItem(
                                id: log.id,
                                name: log.title ?? "Workout Session",
                                date: date,
                                duration: Int(log.duration ?? 0),
                                calories: log.calories.flatMap { $0 > 0 ? Int($0) : nil },
                                totalSets: log.totalSets,
                                logType: .session
                            )
                        }
                        allItems.append(contentsOf: items)
                        
                        if response.data?.hasMore == true, let token = response.data?.nextToken {
                            nextToken = token
                            fetchPage()
                        } else {
                            completion(allItems)
                        }
                    } else {
                        completion(allItems)
                    }
                case .failure(let error):
                    print("❌ Error loading session logs: \(error.localizedDescription)")
                    completion(allItems)
                }
            }
        }
        
        fetchPage()
    }
    
    private func loadMovementLogs(userId: String, completion: @escaping ([WorkoutHistoryItem]) -> Void) {
        var allItems: [WorkoutHistoryItem] = []
        var nextToken: String? = nil
        
        func fetchPage() {
            ActivityService.shared.getMovementLogs(
                userId: userId,
                limit: 100,
                nextToken: nextToken
            ) { result in
                switch result {
                case .success(let response):
                    if let logs = response.data?.logs {
                        let items = logs.compactMap { log -> WorkoutHistoryItem? in
                            let formatter = ISO8601DateFormatter()
                            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            guard let date = formatter.date(from: log.createdAt) else {
                                return nil
                            }
                            
                            // Get movement name from movementId or use default
                            let name = log.movementId ?? "Movement"
                            
                            return WorkoutHistoryItem(
                                id: log.id,
                                name: name,
                                date: date,
                                duration: Int(log.duration ?? 0),
                                calories: nil,
                                totalSets: log.totalSets,
                                logType: .movement
                            )
                        }
                        allItems.append(contentsOf: items)
                        
                        if response.data?.hasMore == true, let token = response.data?.nextToken {
                            nextToken = token
                            fetchPage()
                        } else {
                            completion(allItems)
                        }
                    } else {
                        completion(allItems)
                    }
                case .failure(let error):
                    print("❌ Error loading movement logs: \(error.localizedDescription)")
                    completion(allItems)
                }
            }
        }
        
        fetchPage()
    }
    
    private func loadPlanLogs(userId: String, completion: @escaping ([WorkoutHistoryItem]) -> Void) {
        var allItems: [WorkoutHistoryItem] = []
        var nextToken: String? = nil
        
        func fetchPage() {
            ActivityService.shared.getPlanLogs(
                userId: userId,
                limit: 100,
                nextToken: nextToken
            ) { result in
                switch result {
                case .success(let response):
                    if let logs = response.data?.logs {
                        let items = logs.compactMap { log -> WorkoutHistoryItem? in
                            let formatter = ISO8601DateFormatter()
                            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            guard let date = formatter.date(from: log.createdAt) else {
                                return nil
                            }
                            
                            // Get plan name from planId or use default
                            let name = log.planId ?? "Workout Plan"
                            
                            return WorkoutHistoryItem(
                                id: log.id,
                                name: name,
                                date: date,
                                duration: nil,
                                calories: nil,
                                totalSets: nil,
                                logType: .plan
                            )
                        }
                        allItems.append(contentsOf: items)
                        
                        if response.data?.hasMore == true, let token = response.data?.nextToken {
                            nextToken = token
                            fetchPage()
                        } else {
                            completion(allItems)
                        }
                    } else {
                        completion(allItems)
                    }
                case .failure(let error):
                    print("❌ Error loading plan logs: \(error.localizedDescription)")
                    completion(allItems)
                }
            }
        }
        
        fetchPage()
    }
}

enum WorkoutLogType {
    case session
    case movement
    case plan
}

struct WorkoutHistoryItem: Identifiable {
    let id: String
    let name: String
    let date: Date
    let duration: Int? // in seconds
    let calories: Int?
    let totalSets: Int?
    let logType: WorkoutLogType
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
                // Log type badge
                Text(workout.logType == .session ? "Session" : workout.logType == .movement ? "Movement" : "Plan")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(workout.logType == .session ? Color.blue.opacity(0.2) : workout.logType == .movement ? Color.green.opacity(0.2) : Color.purple.opacity(0.2))
                    .foregroundColor(workout.logType == .session ? .blue : workout.logType == .movement ? .green : .purple)
                    .cornerRadius(4)
                
                if let duration = workout.duration, duration > 0 {
                    Label(formatDuration(duration), systemImage: "clock")
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

