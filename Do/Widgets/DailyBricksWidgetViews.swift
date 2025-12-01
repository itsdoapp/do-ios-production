//
//  DailyBricksWidgetViews.swift
//  Do
//
//  Widget views for iOS Daily Bricks widget
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI
import WidgetKit

// MARK: - Small Widget View

struct SmallBricksView: View {
    let entry: DailyBricksEntry
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.08),
                    Color(red: 0.1, green: 0.1, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            if entry.isLoading {
                ProgressView()
                    .tint(.white)
            } else if let error = entry.error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Error")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            } else if let summary = entry.summary {
                VStack(spacing: 10) {
                    // Modern progress ring with integrated text
                    ZStack {
                        // Background ring - subtle
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 3.5)
                        
                        // Progress ring - sleek gradient
                        Circle()
                            .trim(from: 0, to: summary.overallProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.6, blue: 0.2),
                                        Color(red: 1.0, green: 0.4, blue: 0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .shadow(color: Color.orange.opacity(0.3), radius: 2, x: 0, y: 0)
                        
                        // Center text - modern typography
                        VStack(spacing: 2) {
                            Text("\(summary.completedCount)")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("/6")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .frame(width: 76, height: 76)
                    
                    // Label
                    Text("Daily Bricks")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                        .tracking(0.5)
                        .lineLimit(1)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.5))
                    Text("No Data")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .widgetBackground()
    }
}

// MARK: - Medium Widget View

struct MediumBricksView: View {
    let entry: DailyBricksEntry
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.08),
                    Color(red: 0.1, green: 0.1, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            if entry.isLoading {
                ProgressView()
                    .tint(.white)
            } else if let error = entry.error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            } else if let summary = entry.summary {
                HStack(spacing: 14) {
                    // Modern compact progress ring
                    VStack(spacing: 4) {
                        ZStack {
                            // Background ring
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 3)
                            
                            // Progress ring
                            Circle()
                                .trim(from: 0, to: summary.overallProgress)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.6, blue: 0.2),
                                            Color(red: 1.0, green: 0.4, blue: 0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                            
                            // Center text
                            VStack(spacing: 0) {
                                Text("\(summary.completedCount)")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("/6")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .frame(width: 56, height: 56)
                    }
                    
                    // Brick grid (2x3) - tighter spacing
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            BrickIconView(brick: summary.brick(for: .move))
                            BrickIconView(brick: summary.brick(for: .heart))
                            BrickIconView(brick: summary.brick(for: .strength))
                        }
                        HStack(spacing: 6) {
                            BrickIconView(brick: summary.brick(for: .recovery))
                            BrickIconView(brick: summary.brick(for: .mind))
                            BrickIconView(brick: summary.brick(for: .fuel))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.5))
                    Text("No Data")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .widgetBackground()
    }
}

// MARK: - Large Widget View

struct LargeBricksView: View {
    let entry: DailyBricksEntry
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.08),
                    Color(red: 0.1, green: 0.1, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            if entry.isLoading {
                ProgressView()
                    .tint(.white)
            } else if let error = entry.error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Error")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } else if let summary = entry.summary {
                VStack(spacing: 12) {
                    // Sleep app style header - minimal and clean
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Daily Bricks")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(0.5)
                            
                            // Hero number - large and bold
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(summary.completedCount)")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text("/6")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        
                        Spacer()
                        
                        // Minimal progress ring
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 2)
                                .frame(width: 32, height: 32)
                            
                            Circle()
                                .trim(from: 0, to: summary.overallProgress)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.6, blue: 0.2),
                                            Color(red: 1.0, green: 0.4, blue: 0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                                )
                                .frame(width: 32, height: 32)
                                .rotationEffect(.degrees(-90))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    
                    // Sleep app style grid - clean and spacious
                    VStack(spacing: 10) {
                        ForEach(Array(DailyBrickType.allCases.chunked(into: 2)), id: \.self) { row in
                            HStack(spacing: 10) {
                                ForEach(row) { type in
                                    if let brick = summary.brick(for: type) {
                                        CompactBrickCard(brick: brick)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.5))
                    Text("No Data")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
        .widgetBackground()
    }
}

// Helper extension for chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Widget Background Helper (iOS 16+ compatibility)

extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(.fill.tertiary, for: .widget)
        } else {
            // iOS 16: Background is already provided by the ZStack gradient
            self
        }
    }
}

// MARK: - Brick Icon View (for medium widget - modern design)

struct BrickIconView: View {
    let brick: DailyBrickProgress?
    
    var body: some View {
        ZStack {
            // Background with progress ring
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(brick?.type.color.opacity(brick?.isComplete == true ? 0.2 : 0.08) ?? Color.white.opacity(0.08))
                    .frame(width: 36, height: 36)
                
                // Progress ring for incomplete bricks
                if let brick = brick, !brick.isComplete {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            brick.type.color.opacity(0.4),
                            lineWidth: 2
                        )
                        .frame(width: 36, height: 36)
                        .mask(
                            RoundedRectangle(cornerRadius: 8)
                                .frame(width: 36, height: 36)
                        )
                }
            }
            
            if let brick = brick {
                Image(systemName: brick.type.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(brick.isComplete ? brick.type.color : Color.white.opacity(0.7))
                
                // Checkmark indicator
                if brick.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(brick.type.color)
                        .background(Circle().fill(Color.white).frame(width: 8, height: 8))
                        .offset(x: 12, y: -12)
                }
            } else {
                Image(systemName: "square")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
    }
}

// MARK: - Sleep App Style Brick Card (for large widget)

struct CompactBrickCard: View {
    let brick: DailyBrickProgress
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon with subtle background - minimal
            ZStack {
                Circle()
                    .fill(brick.type.color.opacity(brick.isComplete ? 0.15 : 0.06))
                    .frame(width: 32, height: 32)
                
                Image(systemName: brick.type.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(brick.isComplete ? brick.type.color : Color.white.opacity(0.7))
                
                // Minimal checkmark
                if brick.isComplete {
                    Circle()
                        .fill(brick.type.color)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 5, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 10, y: -10)
                }
            }
            
            // Hero number - Sleep app style (large and bold)
            if brick.isComplete {
                // Completion checkmark - large and colorful
                Text("✓")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(brick.type.color)
            } else {
                // Large percentage number
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(brick.progressPercentage)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("%")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            // Minimal label - very subtle
            Text(brick.type.name)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .tracking(0.2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            brick.isComplete ? brick.type.color.opacity(0.2) : Color.white.opacity(0.06),
                            lineWidth: 0.5
                        )
                )
        )
    }
}

// MARK: - Brick Row View (legacy - for reference)

struct BrickRowView: View {
    let brick: DailyBrickProgress
    
    var body: some View {
        HStack(spacing: 10) {
            // Icon
            ZStack {
                Circle()
                    .fill(brick.type.color.opacity(brick.isComplete ? 0.3 : 0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: brick.type.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(brick.isComplete ? brick.type.color : Color.white.opacity(0.7))
            }
            
            // Name and progress
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(brick.type.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    
                    Spacer()
                    
                    if brick.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(brick.type.color)
                    } else {
                        Text("\(brick.progressPercentage)%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 3)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [brick.type.color, brick.type.color.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * brick.progress, height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.vertical, 6)
    }
}

