//
//  SharedViews.swift
//  Do.
//
//  Shared SwiftUI views used across multiple trackers
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import MapKit

// MARK: - Run Settings View

struct RunSettingsView: View {
    @ObservedObject private var settingsManager = RunSettingsManager.shared
    @ObservedObject private var userPreferences = UserPreferences.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("General Preferences")) {
                    Toggle("Use Metric Units", isOn: $userPreferences.useMetricSystem)
                    
                    Picker("Voice Coach", selection: $userPreferences.preferredVoiceType) {
                        ForEach(UserPreferences.VoiceType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section(header: Text("Audio & Announcements")) {
                    Toggle("Announce Intervals", isOn: $settingsManager.currentSettings.announceIntervals)
                    Toggle("Play Audio Cues", isOn: $settingsManager.currentSettings.playAudioCues)
                    
                    Picker("Announcement Frequency", selection: $settingsManager.currentSettings.announcementFrequency) {
                        Text("Off").tag(AnnouncementFrequency.off)
                        Text("Every Kilometer").tag(AnnouncementFrequency.kilometer)
                        Text("Every Mile").tag(AnnouncementFrequency.mile)
                        Text("Every 2 Kilometers").tag(AnnouncementFrequency.twoKilometers)
                        Text("Every 5 Minutes").tag(AnnouncementFrequency.fiveMinutes)
                        Text("Every 10 Minutes").tag(AnnouncementFrequency.tenMinutes)
                    }
                }
                
                Section(header: Text("Display")) {
                    Toggle("Screen Always On", isOn: $settingsManager.currentSettings.screenAlwaysOn)
                    Toggle("Auto Lock Screen", isOn: $settingsManager.currentSettings.autoLockScreen)
                    Toggle("Show Heat Map", isOn: $settingsManager.currentSettings.showHeatMap)
                }
                
                Section(header: Text("Tracking")) {
                    Toggle("Track Elevation", isOn: $settingsManager.currentSettings.trackElevation)
                    Toggle("Record Heart Rate", isOn: $settingsManager.currentSettings.recordHeartRate)
                }
                
                Section(header: Text("Notifications")) {
                    Toggle("Vibrate on Milestones", isOn: $settingsManager.currentSettings.vibrateOnMilestones)
                }
            }
            .navigationTitle("Run Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onDisappear {
            settingsManager.saveSettings()
        }
    }
}

// MARK: - Find Routes View

struct FindRoutesView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var routePlanner = RoutePlanner.shared
    @StateObject private var locationManager = ModernLocationManager.shared
    @State private var searchText = ""
    @State private var selectedDistance: Double = 5.0 // km
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.opacity(0.9)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Search and filter section
                    VStack(spacing: 12) {
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            
                            TextField("Search for routes...", text: $searchText)
                                .foregroundColor(.white)
                                .accentColor(.blue)
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        
                        // Distance selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Target Distance: \(String(format: "%.1f", selectedDistance)) km")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            Slider(value: $selectedDistance, in: 1...20, step: 0.5)
                                .accentColor(.blue)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // Find routes button
                    Button(action: {
                        findRoutes()
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "location.magnifyingglass")
                                Text("Find Routes")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isLoading ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .disabled(isLoading)
                    
                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("Find Routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func findRoutes() {
        isLoading = true
        
        // Get current location
        guard let location = locationManager.location else {
            isLoading = false
            return
        }
        
        // Find nearby routes using RoutePlanner
        Task {
            // RoutePlanner will handle finding nearby trails
            // This is a placeholder - actual implementation depends on RoutePlanner API
            await MainActor.run {
                isLoading = false
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// MARK: - Route Preview View

struct RoutePreviewView: View {
    let trail: Trail
    let onSelectRoute: () -> Void
    let onDismiss: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Route header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(trail.name ?? "Unnamed Route")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if let description = trail.description {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    
                    // Route stats
                    HStack(spacing: 20) {
                        StatCard(
                            icon: "ruler",
                            value: String(format: "%.2f", trail.length),
                            label: "Distance (mi)"
                        )
                        
                        StatCard(
                            icon: "arrow.up.right",
                            value: String(format: "%.0f", trail.elevationGain),
                            label: "Elevation (ft)"
                        )
                        
                        StatCard(
                            icon: "figure.run",
                            value: difficultyText,
                            label: "Difficulty"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            onSelectRoute()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Select Route")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            onDismiss()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
            .background(Color.black.opacity(0.9))
            .navigationTitle("Route Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var difficultyText: String {
        switch trail.difficulty {
        case .easy: return "Easy"
        case .moderate: return "Moderate"
        case .difficult: return "Difficult"
        case .veryDifficult: return "Very Difficult"
        }
    }
}

// MARK: - Stat Card Helper

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - RunSettingsManager Extension

extension RunSettingsManager {
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(currentSettings) {
            UserDefaults.standard.set(encoded, forKey: "runSettings")
        }
    }
}

