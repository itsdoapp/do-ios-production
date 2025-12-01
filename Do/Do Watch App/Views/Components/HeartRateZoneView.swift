//
//  HeartRateZoneView.swift
//  Do Watch App
//
//  Heart rate zone display component (watchOS 9.0+)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

// MARK: - Heart Rate Zone Indicator

struct HeartRateZoneIndicator: View {
    let currentZone: HeartRateZone?
    let heartRate: Double
    
    var body: some View {
        VStack(spacing: 8) {
            // Zone Bar Visualization
            HStack(spacing: 2) {
                ForEach(HeartRateZone.allCases) { zone in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            currentZone == zone
                                ? zone.color
                                : zone.color.opacity(0.25)
                        )
                        .frame(height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(
                                    currentZone == zone
                                        ? Color.white.opacity(0.3)
                                        : Color.clear,
                                    lineWidth: currentZone == zone ? 1.5 : 0
                                )
                        )
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
            )
            
            // Zone Info
            HStack(spacing: 8) {
                if let zone = currentZone {
                    // Zone Badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(zone.color)
                            .frame(width: 6, height: 6)
                        
                        Text(zone.name.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(zone.color.opacity(0.2))
                            .overlay(
                                Capsule()
                                    .stroke(zone.color.opacity(0.4), lineWidth: 1)
                            )
                    )
                } else {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 6, height: 6)
                        
                        Text("--")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                
                Spacer()
                
                // Heart Rate
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.red)
                    
                    Text("\(Int(heartRate))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("BPM")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

// MARK: - Heart Rate Zone Ring

struct HeartRateZoneRing: View {
    let zone: HeartRateZone
    let progress: Double // 0.0 to 1.0
    let isActive: Bool
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(zone.color.opacity(0.2), lineWidth: 3)
                .frame(width: 40, height: 40)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(zone.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))
            
            // Active indicator
            if isActive {
                Circle()
                    .fill(zone.color)
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - Zone Summary View

struct HeartRateZoneSummaryView: View {
    let zoneSummary: (totalTime: TimeInterval, zones: [HeartRateZone: TimeInterval])
    @ObservedObject var zoneService = HeartRateZoneService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HEART RATE ZONES")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
            
            ForEach(HeartRateZone.allCases) { zone in
                let timeInZone = zoneSummary.zones[zone] ?? 0
                let percentage = zoneSummary.totalTime > 0 ? (timeInZone / zoneSummary.totalTime) * 100 : 0
                
                HStack {
                    // Zone indicator
                    Circle()
                        .fill(zone.color)
                        .frame(width: 6, height: 6)
                    
                    Text(zone.name)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Time and percentage
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(formatTime(timeInZone))
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("\(Int(percentage))%")
                            .font(.system(size: 8, weight: .regular, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

