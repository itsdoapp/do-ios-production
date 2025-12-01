//
//  DailyBricksBrickwallView.swift
//  Do Watch App
//
//  Brickwall layout for Daily Bricks dashboard
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

struct DailyBricksBrickwallView: View {
    let summary: DailyBricksSummary?
    @State private var showExpanded: Bool = false
    @State private var cardScale: CGFloat = 0.98
    @State private var cardOpacity: Double = 0.0
    
    var body: some View {
        if let summary = summary {
            Button(action: {
                showExpanded = true
            }) {
                VStack(spacing: 10) {
                    // Premium Header with vibrant colors
                    HStack(alignment: .center) {
                        Text("DAILY BRICKS")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.5)
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                            .shadow(color: .white.opacity(0.2), radius: 0.5, x: 0, y: -0.25)
                        
                        Spacer()
                        
                        Text("\(Int(summary.overallProgress * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .tracking(0.3)
                            .foregroundColor(
                                summary.overallProgress > 0.8 
                                    ? Color(red: 0.298, green: 0.851, blue: 0.392) // Green for high progress
                                    : summary.overallProgress > 0.5
                                    ? Color(red: 1.0, green: 0.584, blue: 0.0) // Orange for medium
                                    : Color(red: 1.0, green: 0.231, blue: 0.188) // Red for low
                            )
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -0.5)
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                    
                    // Premium Brickwall Grid (2 rows x 3 columns)
                    VStack(spacing: 6) {
                        // Row 1: Move, Heart, Strength
                        HStack(spacing: 6) {
                            BrickTile(brick: summary.brick(for: .move))
                            BrickTile(brick: summary.brick(for: .heart))
                            BrickTile(brick: summary.brick(for: .strength))
                        }
                        
                        // Row 2: Recovery, Mind, Fuel
                        HStack(spacing: 6) {
                            BrickTile(brick: summary.brick(for: .recovery))
                            BrickTile(brick: summary.brick(for: .mind))
                            BrickTile(brick: summary.brick(for: .fuel))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        // Background with Do blue tint
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.059, green: 0.086, blue: 0.243).opacity(0.18), // Do blue
                                        Color(red: 0.059, green: 0.086, blue: 0.243).opacity(0.12), // Do blue
                                        Color.white.opacity(0.08),
                                        Color.white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // Inner border with Do blue and white (no gray)
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.059, green: 0.086, blue: 0.243).opacity(0.0), // Do blue transparent
                                        Color(red: 0.059, green: 0.086, blue: 0.243).opacity(0.15), // Do blue
                                        Color.white.opacity(0.12), // White highlight
                                        Color(red: 0.059, green: 0.086, blue: 0.243).opacity(0.0) // Do blue transparent
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                            .padding(1)
                        
                        // Outer border with Do blue and white (no gray)
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.059, green: 0.086, blue: 0.243).opacity(0.35), // Do blue
                                        Color(red: 0.059, green: 0.086, blue: 0.243).opacity(0.25), // Do blue
                                        Color.white.opacity(0.20), // White
                                        Color.white.opacity(0.12) // White
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                )
                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 5)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 3)
                .shadow(color: Color(red: 0.059, green: 0.086, blue: 0.243).opacity(0.2), radius: 14, x: 0, y: 6)
                .scaleEffect(cardScale)
                .opacity(cardOpacity)
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        cardScale = 1.0
                        cardOpacity = 1.0
                    }
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showExpanded) {
                DailyBricksExpandedView(summary: summary)
            }
        } else {
            // Premium Loading state with vibrant colors
            VStack(spacing: 10) {
                HStack(alignment: .center) {
                    Text("DAILY BRICKS")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                        .shadow(color: .white.opacity(0.2), radius: 0.5, x: 0, y: -0.25)
                    
                    Spacer()
                    
                    Text("--")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .tracking(0.3)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .padding(.horizontal, 6)
                .padding(.top, 2)
                
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        BrickTilePlaceholder()
                        BrickTilePlaceholder()
                        BrickTilePlaceholder()
                    }
                    HStack(spacing: 6) {
                        BrickTilePlaceholder()
                        BrickTilePlaceholder()
                        BrickTilePlaceholder()
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    // Background with Do blue tint
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.059, green: 0.086, blue: 0.243).opacity(0.18), // Do blue
                                    Color(red: 0.059, green: 0.086, blue: 0.243).opacity(0.12), // Do blue
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Inner border with Do blue and white (no gray)
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.059, green: 0.086, blue: 0.243).opacity(0.0), // Do blue transparent
                                    Color(red: 0.059, green: 0.086, blue: 0.243).opacity(0.15), // Do blue
                                    Color.white.opacity(0.12), // White highlight
                                    Color(red: 0.059, green: 0.086, blue: 0.243).opacity(0.0) // Do blue transparent
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                        .padding(1)
                    
                    // Outer border with Do blue and white (no gray)
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.059, green: 0.086, blue: 0.243).opacity(0.35), // Do blue
                                    Color(red: 0.059, green: 0.086, blue: 0.243).opacity(0.25), // Do blue
                                    Color.white.opacity(0.20), // White
                                    Color.white.opacity(0.12) // White
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            )
            .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 5)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 3)
            .shadow(color: Color(red: 0.059, green: 0.086, blue: 0.243).opacity(0.2), radius: 14, x: 0, y: 6)
        }
    }
}

// MARK: - Brick Tile

struct BrickTile: View {
    let brick: DailyBrickProgress?
    @State private var iconFloatOffset: CGFloat = 0.0
    @State private var progressAnimation: Double = 0.0
    
    // Unique animation delay based on brick type
    private var animationDelay: Double {
        guard let brick = brick else { return 0 }
        return Double(brick.type.id.hashValue % 100) / 100.0 * 1.5
    }
    
    var body: some View {
        if let brick = brick {
            VStack(spacing: 4) {
                // Premium Icon with floating animation
                ZStack {
                    // Outer glow for active bricks
                    if brick.progress > 0 {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        brick.type.color.opacity(0.2),
                                        brick.type.color.opacity(0.05),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 12,
                                    endRadius: 20
                                )
                            )
                            .frame(width: 32, height: 32)
                    }
                    
                    // Background circle with premium gradient
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: brick.progress > 0 ? [
                                    brick.type.color.opacity(0.25),
                                    brick.type.color.opacity(0.15),
                                    brick.type.color.opacity(0.08)
                                ] : [
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.06)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 14
                            )
                        )
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            brick.type.color.opacity(brick.progress > 0 ? 0.4 : 0.15),
                                            brick.type.color.opacity(brick.progress > 0 ? 0.25 : 0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(
                            color: brick.type.color.opacity(brick.progress > 0 ? 0.3 : 0),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                        .shadow(
                            color: Color.black.opacity(0.2),
                            radius: 2,
                            x: 0,
                            y: 1
                        )
                    
                    // Premium Progress ring with gradient
                    Circle()
                        .trim(from: 0, to: CGFloat(progressAnimation))
                        .stroke(
                            LinearGradient(
                                colors: [
                                    brick.type.color,
                                    brick.type.color.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 30, height: 30)
                        .rotationEffect(.degrees(-90))
                        .shadow(
                            color: brick.type.color.opacity(0.4),
                            radius: 3,
                            x: 0,
                            y: 1
                        )
                    
                    // Icon with floating animation
                    Image(systemName: brick.type.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(brick.isComplete ? Color.white : (brick.progress > 0 ? brick.type.color : brick.type.color.opacity(0.5)))
                        .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 0.5)
                        .offset(y: iconFloatOffset)
                }
                .onAppear {
                    // Animate progress
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                        progressAnimation = brick.progress
                    }
                    // Start floating animation
                    withAnimation(
                        Animation.easeInOut(duration: 2.5 + animationDelay)
                            .repeatForever(autoreverses: true)
                            .delay(animationDelay)
                    ) {
                        iconFloatOffset = -3.0
                    }
                }
                .onChange(of: brick.progress) { newValue in
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        progressAnimation = newValue
                    }
                }
                
                // Premium Progress indicator
                if brick.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundColor(brick.type.color)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                        .shadow(color: brick.type.color.opacity(0.5), radius: 2, x: 0, y: 1)
                } else if brick.progress > 0 {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    brick.type.color.opacity(0.8),
                                    brick.type.color.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 5, height: 5)
                        .shadow(color: brick.type.color.opacity(0.5), radius: 2, x: 0, y: 1)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            BrickTilePlaceholder()
        }
    }
}

// MARK: - Brick Tile Placeholder

struct BrickTilePlaceholder: View {
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.gray.opacity(0.15),
                            Color.gray.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
    }
}

