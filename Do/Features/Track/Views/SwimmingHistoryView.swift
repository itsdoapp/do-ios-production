//
//  SwimmingHistoryView.swift
//  Do
//
//  SwiftUI view for displaying swimming workout history
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

struct SwimmingHistoryView: View {
    @State private var swimRecords: [WorkoutHistoryService.SwimmingWorkoutRecord] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedRecord: WorkoutHistoryService.SwimmingWorkoutRecord?
    @State private var showingDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: 0x0F0F23),
                        Color(hex: 0x16213E),
                        Color(hex: 0x1A1A2E)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Error Loading History")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else if swimRecords.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.pool.swim")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        Text("No Swimming Workouts")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Text("Start tracking your swimming workouts to see them here")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(swimRecords, id: \.date) { record in
                                SwimRecordCard(record: record)
                                    .onTapGesture {
                                        selectedRecord = record
                                        showingDetail = true
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Swimming History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss handled by sheet
                    }
                }
            }
            .onAppear {
                loadSwimmingHistory()
            }
            .sheet(isPresented: $showingDetail) {
                if let record = selectedRecord {
                    SwimAnalysisView(record: record) {
                        showingDetail = false
                    }
                }
            }
        }
    }
    
    private func loadSwimmingHistory() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Fetch swimming workouts from ActivityService
                // Note: This is a placeholder - you'll need to implement the actual fetch method
                // For now, we'll use a mock or empty array
                let records: [WorkoutHistoryService.SwimmingWorkoutRecord] = []
                
                await MainActor.run {
                    self.swimRecords = records
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Swim Record Card

struct SwimRecordCard: View {
    let record: WorkoutHistoryService.SwimmingWorkoutRecord
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: record.date)
    }
    
    private var formattedDuration: String {
        let hours = Int(record.durationSec) / 3600
        let minutes = (Int(record.durationSec) % 3600) / 60
        let seconds = Int(record.durationSec) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private var formattedDistance: String {
        if record.distanceMeters >= 1000 {
            return String(format: "%.2f km", record.distanceMeters / 1000.0)
        } else {
            return String(format: "%.0f m", record.distanceMeters)
        }
    }
    
    private var formattedPace: String {
        guard record.avgPacePer100Sec > 0 else { return "--:--" }
        let minutes = Int(record.avgPacePer100Sec) / 60
        let seconds = Int(record.avgPacePer100Sec) % 60
        return String(format: "%d'%02d\"", minutes, seconds)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.stroke.capitalized)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 20) {
                MetricView(icon: "figure.pool.swim", value: formattedDistance, label: "Distance")
                MetricView(icon: "clock", value: formattedDuration, label: "Duration")
                MetricView(icon: "timer", value: formattedPace, label: "Pace/100m")
                MetricView(icon: "number", value: "\(record.laps)", label: "Laps")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}




