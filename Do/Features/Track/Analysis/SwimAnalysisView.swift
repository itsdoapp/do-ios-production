//
//  SwimAnalysisView.swift
//  Do.
//
//  Created by Mikiyas Tadesse on 8/19/25.
//

import SwiftUI

struct SwimAnalysisView: View {
    let record: WorkoutHistoryService.SwimmingWorkoutRecord
    let onDismiss: () -> Void
    
    @State private var showingShare = false
    
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
            
            VStack(spacing: 16) {
                header
                summaryCards
                detailsList
                Spacer()
                shareButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
        .fullScreenCover(isPresented: $showingShare) {
            SwimShareTemplateHub(record: record) {
                showingShare = false
            }
        }
    }
    
    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Swim Analysis")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(dateString(record.date))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Button(action: { showingShare = true }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(title: "Distance", value: distanceDisplay())
            summaryCard(title: "Time", value: durationDisplay())
            summaryCard(title: "Pace", value: paceDisplay())
        }
    }
    
    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: 0x1E1E3F), Color(hex: 0x2A2A5A)]),
                startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    private var detailsList: some View {
        VStack(spacing: 10) {
            detailRow(label: "Stroke", value: record.stroke.capitalized)
            detailRow(label: "Laps", value: "\(record.laps)")
            detailRow(label: "Pool Length", value: poolLengthDisplay())
            if let hr = record.avgHeartRate {
                detailRow(label: "Avg HR", value: String(format: "%.0f bpm", hr))
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: 0x151530), Color(hex: 0x1C1C3F)]),
                startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.7))
                .font(.system(size: 14, weight: .medium))
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .font(.system(size: 15, weight: .semibold))
        }
    }
    
    private var shareButton: some View {
        Button(action: { showingShare = true }) {
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
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Formatting
    private func dateString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
    
    private func durationDisplay() -> String {
        let total = Int(record.durationSec)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
    
    private func paceDisplay() -> String {
        guard record.avgPacePer100Sec > 0 else { return "-" }
        let total = Int(record.avgPacePer100Sec)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d/100m", m, s)
    }
    
    private func distanceDisplay() -> String {
        return UserPreferences.shared.formatDistance(record.distanceMeters)
    }
    
    private func poolLengthDisplay() -> String {
        let meters = record.poolLengthMeters
        if meters.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f m", meters)
        }
        return String(format: "%.1f m", meters)
    }
}
