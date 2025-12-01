//
//  DailyBricksWidgetViews.swift
//  Do Watch App
//
//  Widget views for all complication families
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import WidgetKit

// MARK: - Accessory Circular View

struct AccessoryCircularView: View {
    let summary: DailyBricksSummary?
    
    var body: some View {
        if let summary = summary {
            ZStack {
                // Progress ring
                Circle()
                    .trim(from: 0, to: CGFloat(summary.overallProgress))
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.969, green: 0.576, blue: 0.122),
                                Color(red: 0.969, green: 0.576, blue: 0.122).opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: summary.overallProgress)
                
                // Center text
                VStack(spacing: 1) {
                    Text("\(Int(summary.overallProgress * 100))%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(summary.completedCount)/6")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
        } else {
            // Loading/error state
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 40, height: 40)
                Text("--")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Accessory Rectangular View

struct AccessoryRectangularView: View {
    let summary: DailyBricksSummary?
    
    var body: some View {
        if let summary = summary {
            HStack(spacing: 8) {
                // Progress indicator
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Bricks")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(summary.completedCount)/6 Complete")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Percentage
                Text("\(Int(summary.overallProgress * 100))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.969, green: 0.576, blue: 0.122))
            }
        } else {
            HStack {
                Text("Daily Bricks")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                Text("--")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Accessory Inline View

struct AccessoryInlineView: View {
    let summary: DailyBricksSummary?
    
    var body: some View {
        if let summary = summary {
            HStack(spacing: 4) {
                Text("🧱")
                    .font(.system(size: 12))
                Text("\(summary.completedCount)/6")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text("•")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                Text("\(Int(summary.overallProgress * 100))%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
        } else {
            HStack(spacing: 4) {
                Text("🧱")
                Text("--")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Graphic Circular View

struct GraphicCircularView: View {
    let summary: DailyBricksSummary?
    
    var body: some View {
        if let summary = summary {
            ZStack {
                // Background circle
                Circle()
                    .fill(Color.black.opacity(0.2))
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: CGFloat(summary.overallProgress))
                    .stroke(
                        Color(red: 0.969, green: 0.576, blue: 0.122),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: summary.overallProgress)
                
                // Center content
                VStack(spacing: 4) {
                    Text("\(Int(summary.overallProgress * 100))%")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(summary.completedCount)/6")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
        } else {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.2))
                Text("--")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Graphic Rectangular View

struct GraphicRectangularView: View {
    let summary: DailyBricksSummary?
    
    var body: some View {
        if let summary = summary {
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack {
                    Text("Daily Bricks")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(summary.overallProgress * 100))%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.969, green: 0.576, blue: 0.122))
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.969, green: 0.576, blue: 0.122),
                                        Color(red: 0.969, green: 0.576, blue: 0.122).opacity(0.7)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(summary.overallProgress), height: 6)
                            .animation(.easeOut(duration: 0.5), value: summary.overallProgress)
                    }
                }
                .frame(height: 6)
                
                // Brick count
                Text("\(summary.completedCount) of 6 bricks complete")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
            }
            .padding(8)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Daily Bricks")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                Text("Loading...")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(8)
        }
    }
}

// MARK: - Graphic Extra Large View

struct GraphicExtraLargeView: View {
    let summary: DailyBricksSummary?
    
    var body: some View {
        if let summary = summary {
            ZStack {
                // Background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.black.opacity(0.3),
                                Color.black.opacity(0.1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: CGFloat(summary.overallProgress))
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.969, green: 0.576, blue: 0.122),
                                Color(red: 0.969, green: 0.576, blue: 0.122).opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: summary.overallProgress)
                
                // Center content
                VStack(spacing: 8) {
                    Text("\(Int(summary.overallProgress * 100))%")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(summary.completedCount)/6")
                        .font(.system(size: 32, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                    
                    Text("Bricks")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 0.969, green: 0.576, blue: 0.122))
                }
            }
        } else {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.2))
                VStack {
                    Text("--")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.gray)
                    Text("Loading")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

