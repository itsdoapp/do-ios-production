//
//  DailyBricksView.swift
//  Do Watch App
//
//  Segmented circle view for daily bricks progress
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

// MARK: - Daily Bricks Progress View (for in-app display)

struct DailyBricksProgressView: View {
    let summary: DailyBricksSummary
    
    var body: some View {
        SegmentedCircleView(summary: summary, size: 100)
    }
}

// MARK: - Segmented Circle View

struct SegmentedCircleView: View {
    let summary: DailyBricksSummary
    let size: CGFloat
    @State private var showExpanded: Bool = false
    
    var body: some View {
        Button(action: {
            showExpanded = true
        }) {
            ZStack {
                // Background circle
                Circle()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: size, height: size)
                
                // Segments
                ForEach(summary.bricks) { brick in
                    SegmentView(
                        brick: brick,
                        size: size,
                        angleOffset: brick.type.angleOffset
                    )
                }
                
                // Center percentage
                VStack(spacing: 2) {
                    Text("\(Int(summary.overallProgress * 100))%")
                        .font(.system(size: size * 0.15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(summary.completedCount)/6")
                        .font(.system(size: size * 0.1, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showExpanded) {
            DailyBricksExpandedView(summary: summary)
        }
    }
}

// MARK: - Segment View

struct SegmentView: View {
    let brick: DailyBrickProgress
    let size: CGFloat
    let angleOffset: Double
    
    private var segmentAngle: Double { 60.0 } // 360 / 6 = 60 degrees per segment
    private var radius: CGFloat { size / 2 }
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // Progress fill segment with better rendering
                Path { path in
                    let startAngleRad = (angleOffset - segmentAngle / 2) * .pi / 180
                    let endAngleRad = (angleOffset + segmentAngle / 2) * .pi / 180
                    
                    let innerRadius = radius * 0.35
                    let outerRadius = radius * 0.95
                    let fillRadius = innerRadius + (outerRadius - innerRadius) * CGFloat(brick.progress)
                    
                    // Start at inner point
                    let innerStartX = center.x + innerRadius * cos(startAngleRad)
                    let innerStartY = center.y + innerRadius * sin(startAngleRad)
                    path.move(to: CGPoint(x: innerStartX, y: innerStartY))
                    
                    // Outer arc
                    path.addArc(
                        center: center,
                        radius: fillRadius,
                        startAngle: Angle(degrees: angleOffset - segmentAngle / 2),
                        endAngle: Angle(degrees: angleOffset + segmentAngle / 2),
                        clockwise: false
                    )
                    
                    // Inner arc (backwards)
                    path.addArc(
                        center: center,
                        radius: innerRadius,
                        startAngle: Angle(degrees: angleOffset + segmentAngle / 2),
                        endAngle: Angle(degrees: angleOffset - segmentAngle / 2),
                        clockwise: true
                    )
                    
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            brick.type.color.opacity(brick.progress > 0 ? 0.9 : 0.15),
                            brick.type.color.opacity(brick.progress > 0 ? 0.7 : 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Enhanced border with better line quality
                Path { path in
                    let innerRadius = radius * 0.35
                    let outerRadius = radius * 0.95
                    
                    // Outer arc
                    path.addArc(
                        center: center,
                        radius: outerRadius,
                        startAngle: Angle(degrees: angleOffset - segmentAngle / 2),
                        endAngle: Angle(degrees: angleOffset + segmentAngle / 2),
                        clockwise: false
                    )
                    
                    // Inner arc
                    path.addArc(
                        center: center,
                        radius: innerRadius,
                        startAngle: Angle(degrees: angleOffset + segmentAngle / 2),
                        endAngle: Angle(degrees: angleOffset - segmentAngle / 2),
                        clockwise: true
                    )
                    
                    path.closeSubpath()
                }
                .stroke(
                    brick.type.color.opacity(0.6),
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }
    }
}

// MARK: - Enhanced Segmented Circle (for expanded view)

struct EnhancedSegmentedCircleView: View {
    let summary: DailyBricksSummary
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Premium background circle with Apple-level depth and engraving
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.55),
                            Color.black.opacity(0.45),
                            Color.black.opacity(0.38),
                            Color.black.opacity(0.32)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    // Inner engraved border (subtle inset)
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .padding(1)
                )
                .overlay(
                    // Outer engraved border
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.10),
                                    Color.white.opacity(0.06),
                                    Color.white.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                )
                // Multiple shadow layers for depth (Apple-style)
                .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 6)
                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 3)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 1)
                // Inner shadow effect (embossed)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.03), lineWidth: 1)
                        .padding(3)
                )
            
            // Segments with better rendering and spacing
            ForEach(summary.bricks) { brick in
                EnhancedSegmentView(
                    brick: brick,
                    size: size,
                    angleOffset: brick.type.angleOffset
                )
            }
            
            // Premium center percentage with Apple-level typography refinement
            Text("\(Int(summary.overallProgress * 100))%")
                .font(.system(size: size * 0.14, weight: .bold, design: .rounded))
                .tracking(0.5) // Letter spacing for premium feel
                .foregroundColor(.white)
                // Multiple shadow layers for engraved text effect
                .shadow(color: .black.opacity(0.7), radius: 5, x: 0, y: 2.5)
                .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                .shadow(color: .white.opacity(0.15), radius: 1, x: 0, y: -0.5) // Inner highlight
                .shadow(color: .white.opacity(0.08), radius: 2, x: 0, y: -1) // Subtle glow
        }
    }
}

// MARK: - Enhanced Segment View (for expanded view)

struct EnhancedSegmentView: View {
    let brick: DailyBrickProgress
    let size: CGFloat
    let angleOffset: Double
    
    @State private var animatedProgress: Double = 0.0
    @State private var iconScale: CGFloat = 0.8
    @State private var arrowOpacity: Double = 0.0
    @State private var iconFloatOffset: CGFloat = 0.0
    
    // Unique animation delay based on brick type for organic feel
    private var animationDelay: Double {
        Double(brick.type.id.hashValue % 100) / 100.0 * 2.0 // 0-2 seconds delay
    }
    
    // Reduced segment angle to create padding between segments (60° -> 50° with 10° gap)
    private var segmentAngle: Double { 50.0 }
    private var gapAngle: Double { 10.0 } // Gap between segments
    private var radius: CGFloat { size / 2 }
    
    // Bigger donut hole - increased from 0.35 to 0.48
    private var innerRadius: CGFloat { radius * 0.48 }
    private var outerRadius: CGFloat { radius * 0.92 }
    
    // Determine if segment is "turned off" (no progress)
    private var isTurnedOff: Bool { brick.progress <= 0.0 }
    
    var body: some View {
        segmentContent
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    animatedProgress = brick.progress
                    iconScale = 1.0
                }
                // Show arrow immediately if there's progress, with a slight delay for polish
                if brick.progress > 0 {
                    withAnimation(.easeInOut(duration: 0.5).delay(0.2)) {
                        arrowOpacity = 1.0
                    }
                }
                // Start floating animation with unique delay for each icon
                withAnimation(
                    Animation.easeInOut(duration: 3.5 + Double(brick.type.id.hashValue % 100) / 100.0)
                        .repeatForever(autoreverses: true)
                        .delay(animationDelay)
                ) {
                    iconFloatOffset = -6.0 // Float up 6 points (smaller for circle icons)
                }
            }
            .onChange(of: brick.progress) { newValue in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    animatedProgress = newValue
                }
                // Update arrow visibility when progress changes
                if newValue > 0 && arrowOpacity < 1.0 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        arrowOpacity = 1.0
                    }
                } else if newValue <= 0 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        arrowOpacity = 0.0
                    }
                }
            }
    }
    
    private var segmentContent: some View {
    
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // Progress fill - fills along the arc from left to right (start angle to end angle)
                if animatedProgress > 0 {
                    Path { path in
                        let startAngle = angleOffset - segmentAngle / 2
                        let endAngle = angleOffset + segmentAngle / 2
                        // Calculate how far along the arc the progress goes
                        let progressEndAngle = startAngle + (endAngle - startAngle) * animatedProgress
                        
                        let startAngleRad = startAngle * .pi / 180
                        let progressEndAngleRad = progressEndAngle * .pi / 180
                        
                        // Start at inner edge
                        let innerStartX = center.x + innerRadius * cos(startAngleRad)
                        let innerStartY = center.y + innerRadius * sin(startAngleRad)
                        path.move(to: CGPoint(x: innerStartX, y: innerStartY))
                        
                        // Outer arc (progress fill along the arc)
                        path.addArc(
                            center: center,
                            radius: outerRadius,
                            startAngle: Angle(degrees: startAngle),
                            endAngle: Angle(degrees: progressEndAngle),
                            clockwise: false
                        )
                        
                        // Line back to inner edge
                        let innerEndX = center.x + innerRadius * cos(progressEndAngleRad)
                        let innerEndY = center.y + innerRadius * sin(progressEndAngleRad)
                        path.addLine(to: CGPoint(x: innerEndX, y: innerEndY))
                        
                        // Inner arc (backwards to close)
                        path.addArc(
                            center: center,
                            radius: innerRadius,
                            startAngle: Angle(degrees: progressEndAngle),
                            endAngle: Angle(degrees: startAngle),
                            clockwise: true
                        )
                        
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [
                                brick.type.color.opacity(0.98),
                                brick.type.color.opacity(0.92),
                                brick.type.color.opacity(0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: brick.type.color.opacity(0.5),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                    .shadow(
                        color: brick.type.color.opacity(0.2),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
                }
                
                // Premium segment border with engraved detail
                Path { path in
                    // Outer arc
                    path.addArc(
                        center: center,
                        radius: outerRadius,
                        startAngle: Angle(degrees: angleOffset - segmentAngle / 2),
                        endAngle: Angle(degrees: angleOffset + segmentAngle / 2),
                        clockwise: false
                    )
                    
                    // Inner arc
                    path.addArc(
                        center: center,
                        radius: innerRadius,
                        startAngle: Angle(degrees: angleOffset + segmentAngle / 2),
                        endAngle: Angle(degrees: angleOffset - segmentAngle / 2),
                        clockwise: true
                    )
                    
                    path.closeSubpath()
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            brick.type.color.opacity(isTurnedOff ? 0.1 : 0.75),
                            brick.type.color.opacity(isTurnedOff ? 0.08 : 0.6),
                            brick.type.color.opacity(isTurnedOff ? 0.06 : 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(
                        lineWidth: isTurnedOff ? 1.5 : 3.0,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                // Engraved border effect - inner highlight
                .overlay(
                    Path { path in
                        path.addArc(
                            center: center,
                            radius: outerRadius - 1,
                            startAngle: Angle(degrees: angleOffset - segmentAngle / 2),
                            endAngle: Angle(degrees: angleOffset + segmentAngle / 2),
                            clockwise: false
                        )
                    }
                    .stroke(
                        Color.white.opacity(isTurnedOff ? 0 : 0.08),
                        style: StrokeStyle(lineWidth: 0.5, lineCap: .round)
                    )
                )
                // Multiple shadow layers for depth
                .shadow(
                    color: brick.type.color.opacity(isTurnedOff ? 0 : 0.4),
                    radius: 3,
                    x: 0,
                    y: 1.5
                )
                .shadow(
                    color: brick.type.color.opacity(isTurnedOff ? 0 : 0.2),
                    radius: 6,
                    x: 0,
                    y: 3
                )
                .shadow(
                    color: Color.black.opacity(0.3),
                    radius: 2,
                    x: 0,
                    y: 1
                )
                
                // Background fill for untracked segments to show they're "turned off"
                // Uses segment color with low opacity to maintain color identity
                if isTurnedOff {
                    Path { path in
                        let startAngleRad = (angleOffset - segmentAngle / 2) * .pi / 180
                        let endAngleRad = (angleOffset + segmentAngle / 2) * .pi / 180
                        
                        let innerStartX = center.x + innerRadius * cos(startAngleRad)
                        let innerStartY = center.y + innerRadius * sin(startAngleRad)
                        path.move(to: CGPoint(x: innerStartX, y: innerStartY))
                        
                        path.addArc(
                            center: center,
                            radius: outerRadius,
                            startAngle: Angle(degrees: angleOffset - segmentAngle / 2),
                            endAngle: Angle(degrees: angleOffset + segmentAngle / 2),
                            clockwise: false
                        )
                        
                        path.addArc(
                            center: center,
                            radius: innerRadius,
                            startAngle: Angle(degrees: angleOffset + segmentAngle / 2),
                            endAngle: Angle(degrees: angleOffset - segmentAngle / 2),
                            clockwise: true
                        )
                        
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [
                                brick.type.color.opacity(0.18),
                                brick.type.color.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
                
                // Icon with premium background circle positioned at the center of the segment
                let iconRadius = (innerRadius + outerRadius) / 2
                let iconAngleRad = angleOffset * .pi / 180
                let iconX = center.x + iconRadius * cos(iconAngleRad)
                let iconY = center.y + iconRadius * sin(iconAngleRad)
                let iconSize = size * 0.08
                let iconBackgroundSize = iconSize * 1.8
                
                // Premium background circle for icon with engraved detail
                Circle()
                    .fill(
                        RadialGradient(
                            colors: isTurnedOff ? [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.08)
                            ] : [
                                Color.white.opacity(0.45),
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.28)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: iconBackgroundSize / 2
                        )
                    )
                    .frame(width: iconBackgroundSize, height: iconBackgroundSize)
                    .overlay(
                        // Inner engraved border
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isTurnedOff ? 0.05 : 0.12),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                            .padding(1)
                    )
                    .overlay(
                        // Outer engraved border
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        brick.type.color.opacity(isTurnedOff ? 0.2 : 0.65),
                                        brick.type.color.opacity(isTurnedOff ? 0.1 : 0.5),
                                        brick.type.color.opacity(isTurnedOff ? 0.08 : 0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isTurnedOff ? 1.5 : 2.0
                            )
                    )
                    // Multiple shadow layers for Apple-level depth
                    .shadow(
                        color: Color.black.opacity(0.5),
                        radius: 7,
                        x: 0,
                        y: 3.5
                    )
                    .shadow(
                        color: brick.type.color.opacity(isTurnedOff ? 0 : 0.35),
                        radius: 9,
                        x: 0,
                        y: 4.5
                    )
                    .shadow(
                        color: Color.black.opacity(0.3),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
                    // Inner glow
                    .overlay(
                        Circle()
                            .stroke(
                                brick.type.color.opacity(isTurnedOff ? 0 : 0.15),
                                lineWidth: 1
                            )
                            .padding(2)
                    )
                    .position(x: iconX, y: iconY + iconFloatOffset)
                    .scaleEffect(iconScale)
                
                // Icon with engraved text effect
                Image(systemName: brick.type.icon)
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(isTurnedOff ? brick.type.color.opacity(0.5) : Color.white)
                    .position(x: iconX, y: iconY + iconFloatOffset)
                    .scaleEffect(iconScale)
                    // Engraved text shadows (inner highlight + outer shadow)
                    .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 2.5)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .shadow(color: .white.opacity(isTurnedOff ? 0 : 0.2), radius: 1, x: 0, y: -0.5) // Inner highlight
                    .shadow(color: brick.type.color.opacity(isTurnedOff ? 0 : 0.6), radius: 5, x: 0, y: 2.5) // Color glow
                
                // Premium directional double chevron at the end of progress fill
                // Show arrow for any progress level (when there's progress)
                if animatedProgress > 0 {
                    // Calculate the angle where progress ends (right/end side of the fill)
                    let startAngle = angleOffset - segmentAngle / 2
                    let progressEndAngle = startAngle + (segmentAngle * animatedProgress)
                    let progressEndAngleRad = progressEndAngle * .pi / 180
                    
                    // Position arrow at outer radius, slightly outside for visibility
                    // This places it at the "end" of the progress fill (right side)
                    let arrowRadius = outerRadius + (size * 0.03)
                    let arrowX = center.x + arrowRadius * cos(progressEndAngleRad)
                    let arrowY = center.y + arrowRadius * sin(progressEndAngleRad)
                    let arrowSize = size * 0.052
                    
                    // Premium arrow background with subtle glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    brick.type.color.opacity(0.5),
                                    brick.type.color.opacity(0.3),
                                    brick.type.color.opacity(0.1)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: arrowSize * 1.2
                            )
                        )
                        .frame(width: arrowSize * 2.0, height: arrowSize * 2.0)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            brick.type.color.opacity(0.7),
                                            brick.type.color.opacity(0.5)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(
                            color: brick.type.color.opacity(0.6),
                            radius: 6,
                            x: 0,
                            y: 3
                        )
                        .shadow(
                            color: Color.black.opacity(0.4),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                        .position(x: arrowX, y: arrowY)
                        .opacity(arrowOpacity)
                        .scaleEffect(arrowOpacity)
                    
                    // Double chevron (<<) pointing in the direction progress is filling
                    // The arc fills counter-clockwise, so we want the arrow to point in that direction
                    // Position it so it clearly shows the fill is progressing forward
                    Image(systemName: "chevron.right.2")
                        .font(.system(size: arrowSize, weight: .bold))
                        .foregroundColor(Color.white)
                        // Rotate to point along the arc direction (counter-clockwise)
                        // The tangent to the circle at angle θ points at angle θ + 90° (counter-clockwise)
                        // We want it to point in the direction the progress is moving
                        .rotationEffect(.degrees(progressEndAngle + 90))
                        .position(x: arrowX, y: arrowY)
                        .opacity(arrowOpacity)
                        .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                        .shadow(color: brick.type.color.opacity(0.5), radius: 6, x: 0, y: 3)
                        // Add a subtle pulse animation when progress is active
                        .scaleEffect(arrowOpacity > 0.5 ? 1.0 : 0.9)
                }
            }
        }
    }
}

// MARK: - Expanded Detail View

struct DailyBricksExpandedView: View {
    let summary: DailyBricksSummary
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.9),
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header with Apple-level typography refinement
                        VStack(spacing: 8) {
                            Text("Daily Bricks")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .tracking(0.3) // Letter spacing
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                                .shadow(color: .white.opacity(0.1), radius: 1, x: 0, y: -0.5)
                            
                            Text("\(Int(summary.overallProgress * 100))% Complete")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .tracking(0.2)
                                .foregroundColor(.gray.opacity(0.85))
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                            
                            Text("\(summary.completedCount) of 6 bricks completed")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .tracking(0.1)
                                .foregroundColor(.gray.opacity(0.65))
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                        
                        // Enhanced Segmented Circle with better rendering
                        EnhancedSegmentedCircleView(summary: summary, size: 200)
                            .padding(.vertical, 12)
                        
                        // Individual Brick Details with improved design
                        VStack(spacing: 18) {
                            ForEach(summary.bricks) { brick in
                                EnhancedBrickDetailRow(brick: brick)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 24)
                    }
                    .padding(.vertical, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

// MARK: - Brick Detail Row

struct BrickDetailRow: View {
    let brick: DailyBrickProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: brick.type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(brick.type.color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(brick.type.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(brick.type.description)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(brick.progressPercentage)%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(brick.isComplete ? brick.type.color : .white)
                    
                    if brick.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(brick.type.color)
                    }
                }
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    // Progress Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(brick.type.color)
                        .frame(width: geometry.size.width * CGFloat(brick.progress), height: 6)
                }
            }
            .frame(height: 6)
            
            // Goal Info
            HStack {
                Text(brick.type.goalDescription)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(Int(brick.currentValue))\(brick.unit.isEmpty ? "" : " \(brick.unit)") / \(Int(brick.goalValue))\(brick.unit.isEmpty ? "" : " \(brick.unit)")")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Enhanced Brick Detail Row (for expanded view)

struct EnhancedBrickDetailRow: View {
    let brick: DailyBrickProgress
    @State private var progressAnimation: Double = 0.0
    @State private var cardScale: CGFloat = 0.95
    @State private var cardOpacity: Double = 0.0
    @State private var iconFloatOffset: CGFloat = 0.0
    
    // Unique animation delay based on brick type for organic feel
    private var animationDelay: Double {
        Double(brick.type.id.hashValue % 100) / 100.0 * 2.0 // 0-2 seconds delay
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Top section: Title from left, Icon on top right
            ZStack(alignment: .topLeading) {
                // Title starts from left - full width available
                Text(brick.type.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .tracking(0.2)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                    .shadow(color: .white.opacity(0.1), radius: 0.5, x: 0, y: -0.25)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 60) // Leave space for icon on right
                
                // Icon positioned on top right with floating animation
                HStack {
                    Spacer()
                    ZStack {
                        // Outer glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        brick.type.color.opacity(0.3),
                                        brick.type.color.opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 15,
                                    endRadius: 25
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        // Main background circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        brick.type.color.opacity(0.25),
                                        brick.type.color.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                brick.type.color.opacity(0.4),
                                                brick.type.color.opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(
                                color: brick.type.color.opacity(0.3),
                                radius: 6,
                                x: 0,
                                y: 3
                            )
                        
                        Image(systemName: brick.type.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(brick.type.color)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    .offset(y: iconFloatOffset)
                }
                .onAppear {
                    // Start floating animation with unique delay for each icon
                    withAnimation(
                        Animation.easeInOut(duration: 3.0 + Double(brick.type.id.hashValue % 100) / 100.0)
                            .repeatForever(autoreverses: true)
                            .delay(animationDelay)
                    ) {
                        iconFloatOffset = -8.0 // Float up 8 points
                    }
                }
            }
            
            // Description - full width below icon (no padding, uses entire card width)
            Text(brick.type.description)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .tracking(0.1)
                .foregroundColor(.gray.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
                .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Progress Bar section - with more spacing
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Premium background with engraved detail
                    RoundedRectangle(cornerRadius: 9)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.gray.opacity(0.22),
                                    Color.gray.opacity(0.18),
                                    Color.gray.opacity(0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 11)
                        .overlay(
                            // Inner engraved border
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(
                                    Color.white.opacity(0.06),
                                    lineWidth: 0.5
                                )
                                .padding(0.5)
                        )
                        .overlay(
                            // Outer engraved border
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.18),
                                            Color.white.opacity(0.08),
                                            Color.white.opacity(0.04)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.2
                                )
                        )
                        // Multiple shadow layers
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1.5)
                        .shadow(color: .black.opacity(0.2), radius: 1.5, x: 0, y: 0.5)
                    
                    // Animated Progress Fill with premium gradient and shine
                    RoundedRectangle(cornerRadius: 9)
                        .fill(
                            LinearGradient(
                                colors: [
                                    brick.type.color,
                                    brick.type.color.opacity(0.95),
                                    brick.type.color.opacity(0.9),
                                    brick.type.color.opacity(0.88)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(progressAnimation), height: 11)
                        // Multiple shadow layers for depth
                        .shadow(
                            color: brick.type.color.opacity(0.6),
                            radius: 5,
                            x: 0,
                            y: 2.5
                        )
                        .shadow(
                            color: brick.type.color.opacity(0.4),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                        .shadow(
                            color: brick.type.color.opacity(0.2),
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                        .overlay(
                            // Inner highlight (engraved effect)
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(
                                    Color.white.opacity(0.2),
                                    lineWidth: 0.5
                                )
                                .frame(width: geometry.size.width * CGFloat(progressAnimation), height: 11)
                                .padding(0.5)
                        )
                        .overlay(
                            // Premium shine effect
                            RoundedRectangle(cornerRadius: 9)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.35),
                                            Color.white.opacity(0.2),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: UnitPoint(x: 0.5, y: 0.4)
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(progressAnimation), height: 11)
                        )
                }
                }
                .frame(height: 11)
                .onAppear {
                    withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2)) {
                        progressAnimation = brick.progress
                    }
                }
                .onChange(of: brick.progress) { newValue in
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        progressAnimation = newValue
                    }
                }
            }
            
            // Bottom section: Goal Info + Percentage
            VStack(alignment: .leading, spacing: 12) {
                Text(brick.type.goalDescription)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .tracking(0.1)
                    .foregroundColor(.gray.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
                
                // Bottom row: Progress value and percentage
                HStack(alignment: .center) {
                    Text("\(Int(brick.currentValue))\(brick.unit.isEmpty ? "" : " \(brick.unit)") / \(Int(brick.goalValue))\(brick.unit.isEmpty ? "" : " \(brick.unit)")")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .tracking(0.1)
                        .foregroundColor(.gray.opacity(0.95))
                    
                    Spacer()
                    
                    // Percentage - smaller, moved to bottom
                    HStack(spacing: 6) {
                        Text("\(brick.progressPercentage)%")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .tracking(0.2)
                            .foregroundColor(brick.isComplete ? brick.type.color : .white)
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                            .shadow(color: .white.opacity(brick.isComplete ? 0.15 : 0.1), radius: 1, x: 0, y: -0.5)
                            .shadow(color: brick.type.color.opacity(brick.isComplete ? 0.3 : 0), radius: 3, x: 0, y: 1.5)
                        
                        // Complete badge if applicable
                        if brick.isComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(brick.type.color)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // Inner engraved border
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                        .padding(1)
                )
                .overlay(
                    // Outer engraved border
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.06),
                                    Color.white.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .overlay(
                    // Subtle color accent at top with gradient
                    RoundedRectangle(cornerRadius: 22)
                        .fill(
                            LinearGradient(
                                colors: [
                                    brick.type.color.opacity(0.18),
                                    brick.type.color.opacity(0.10),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.3)
                            )
                        )
                )
        )
        // Multiple shadow layers for Apple-level depth
        .shadow(color: .black.opacity(0.4), radius: 14, x: 0, y: 5)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 3)
        .shadow(color: brick.type.color.opacity(0.12), radius: 18, x: 0, y: 7)
        .shadow(color: brick.type.color.opacity(0.06), radius: 12, x: 0, y: 4)
        // Inner shadow effect
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.02), lineWidth: 1)
                .padding(2)
        )
        .scaleEffect(cardScale)
        .opacity(cardOpacity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
        }
    }
}

// MARK: - Color Extension (if not exists)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

