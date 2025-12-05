//
//  SwimShareTemplateHub.swift
//  Do
//
//  Share template hub for swimming workouts
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

struct SwimShareTemplateHub: View {
    let record: WorkoutHistoryService.SwimmingWorkoutRecord
    let onDismiss: () -> Void
    
    @State private var selectedTemplate: ShareTemplate = .modern
    
    enum ShareTemplate: String, CaseIterable {
        case modern = "Modern"
        case classic = "Classic"
        case minimal = "Minimal"
    }
    
    var body: some View {
        ZStack {
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
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Share Swim")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Template selector
                Picker("Template", selection: $selectedTemplate) {
                    ForEach(ShareTemplate.allCases, id: \.self) { template in
                        Text(template.rawValue).tag(template)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Share content
                ScrollView {
                    switch selectedTemplate {
                    case .modern:
                        ModernSwimShareView(record: record)
                    case .classic:
                        ClassicSwimShareView(record: record)
                    case .minimal:
                        MinimalSwimShareView(record: record)
                    }
                }
                .padding(.top, 20)
                
                // Share button
                Button(action: {
                    shareWorkout()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: 0x3B82F6), Color(hex: 0x60A5FA)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
    
    private func shareWorkout() {
        // Create share text
        let distance = UserPreferences.shared.formatDistance(record.distanceMeters)
        let duration = formatDuration(record.durationSec)
        let pace = formatPace(record.avgPacePer100Sec)
        
        let shareText = """
        🏊‍♂️ Swim Workout
        
        Distance: \(distance)
        Time: \(duration)
        Pace: \(pace)
        Stroke: \(record.stroke.capitalized)
        Laps: \(record.laps)
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
    
    private func formatPace(_ secondsPer100m: Double) -> String {
        guard secondsPer100m > 0 else { return "-" }
        let total = Int(secondsPer100m)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d/100m", m, s)
    }
}

// MARK: - Share Template Views

struct ModernSwimShareView: View {
    let record: WorkoutHistoryService.SwimmingWorkoutRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Profile and date
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if let profileImage = CurrentUserService.shared.user.profilePicture {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                    }
                    
                    Text("@\(CurrentUserService.shared.userName?.lowercased() ?? "swimmer")")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                Text(formatDate(record.date))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Swim Workout")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            
            // Stats grid
            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    statItem(icon: "figure.pool.swim", value: UserPreferences.shared.formatDistance(record.distanceMeters), label: "DISTANCE", color: Color(hex: 0x5AC8FA))
                    statItem(icon: "clock", value: formatDuration(record.durationSec), label: "TIME", color: Color(hex: 0xFF9500))
                    statItem(icon: "speedometer", value: formatPace(record.avgPacePer100Sec), label: "PACE", color: Color(hex: 0x4CD964))
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                HStack(spacing: 0) {
                    statItem(icon: "flame.fill", value: "\(Int(calculateCalories()))", label: "CALORIES", color: Color(hex: 0xFF3B30))
                    statItem(icon: "heart.fill", value: record.avgHeartRate != nil ? "\(Int(record.avgHeartRate!)) bpm" : "-- bpm", label: "AVG HR", color: Color(hex: 0xFF375F))
                    statItem(icon: "repeat", value: "\(record.laps)", label: "LAPS", color: Color(hex: 0x34C759))
                }
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
            )
            .padding(.horizontal)
        }
        .padding(.vertical, 20)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
    
    private func formatPace(_ secondsPer100m: Double) -> String {
        guard secondsPer100m > 0 else { return "-" }
        let total = Int(secondsPer100m)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d/100m", m, s)
    }
    
    private func calculateCalories() -> Double {
        // Rough estimate: ~10 calories per 100m
        return (record.distanceMeters / 100.0) * 10.0
    }
    
    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

struct ClassicSwimShareView: View {
    let record: WorkoutHistoryService.SwimmingWorkoutRecord
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Swim Workout")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                detailRow(label: "Distance", value: UserPreferences.shared.formatDistance(record.distanceMeters))
                detailRow(label: "Time", value: formatDuration(record.durationSec))
                detailRow(label: "Pace", value: formatPace(record.avgPacePer100Sec))
                detailRow(label: "Stroke", value: record.stroke.capitalized)
                detailRow(label: "Laps", value: "\(record.laps)")
                if let hr = record.avgHeartRate {
                    detailRow(label: "Avg Heart Rate", value: "\(Int(hr)) bpm")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )
        }
        .padding()
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
    
    private func formatPace(_ secondsPer100m: Double) -> String {
        guard secondsPer100m > 0 else { return "-" }
        let total = Int(secondsPer100m)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d/100m", m, s)
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.semibold)
        }
    }
}

struct MinimalSwimShareView: View {
    let record: WorkoutHistoryService.SwimmingWorkoutRecord
    
    var body: some View {
        VStack(spacing: 12) {
            Text("🏊‍♂️")
                .font(.system(size: 48))
            
            Text(UserPreferences.shared.formatDistance(record.distanceMeters))
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text(formatDuration(record.durationSec))
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding()
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}








