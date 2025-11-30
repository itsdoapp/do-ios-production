//
//  IntroView.swift
//  Do
//

import SwiftUI

struct IntroView: View {
    @State private var balloonPosition: CGPoint = CGPoint(x: 0, y: -200)
    @State private var showBars: [Bool] = [false, false, false]
    @State private var showBalloon: Bool = false
    @State private var balloonScale: CGFloat = 1.5
    @State private var balloonRotation: Double = 0
    @State private var barWiggle: [Double] = [0, 0, 0]
    @State private var navigateToLogin: Bool = false
    @State private var isDeflating: Bool = false
    @State private var barsFrame: CGRect = .zero
    @State private var barScaleY: [CGFloat] = [1.0, 1.0, 1.0]
    @State private var showTagline: Bool = false
    @State private var showTaglineAccent: Bool = false
    @State private var showTag1: Bool = false
    @State private var showTag2: Bool = false
    @State private var showTagDot: Bool = false
    
    // Logo dimensions (scaled 3.5x for better visibility)
    private let scale: CGFloat = 3.5
    private let barWidth: CGFloat = 8
    private let barSpacing: CGFloat = 4
    private let dotSize: CGFloat = 8
    
    // Bar heights - stair pattern (short, medium, tall)
    private let barHeights: [CGFloat] = [20, 28, 36]
    
    // Bar colors - red, white, orange
    private let barColors: [Color] = [
        Color(red: 0.95, green: 0.26, blue: 0.21), // Red
        Color.white,                                  // White
        Color.brandOrange                            // Orange
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.brandBlue
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // Logo animation - Staircase
                    HStack(alignment: .bottom, spacing: barSpacing * scale) {
                        ForEach(0..<3) { index in
                            RoundedRectangle(cornerRadius: 3 * scale)
                                .fill(barColors[index])
                                .frame(width: barWidth * scale, height: barHeights[index] * scale)
                                .opacity(showBars[index] ? 1.0 : 0.0)
                                .scaleEffect(showBars[index] ? 1.0 : 0.3, anchor: .bottom)
                                .rotationEffect(.degrees(barWiggle[index]))
                                .scaleEffect(x: 1.0, y: barScaleY[index], anchor: .bottom)
                                .shadow(color: barColors[index].opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear {
                                barsFrame = geo.frame(in: .named("introSpace"))
                            }
                        }
                    )
                    .padding(.bottom, 40)

                    // Tagline (staged reveal): "Bit by bit." (first), " Do by Do" (second), final dot
                    ZStack {
                        HStack(spacing: 0) {
                            Text("Bit by bit.")
                                .font(.system(size: 22, weight: .bold))
                                .kerning(0.2)
                                .foregroundColor(.white)
                                .opacity(showTag1 ? 1.0 : 0.0)
                                .offset(y: showTag1 ? 0 : 12)
                                .scaleEffect(showTag1 ? 1.0 : 0.94)
                                .animation(.easeOut(duration: 0.10), value: showTag1)
                            Text(" Do by Do")
                                .font(.system(size: 22, weight: .bold))
                                .kerning(0.2)
                                .foregroundColor(Color.brandOrange)
                                .opacity(showTag2 ? 1.0 : 0.0)
                                .offset(y: showTag2 ? 0 : 12)
                                .scaleEffect(showTag2 ? 1.0 : 0.94)
                                .animation(.easeOut(duration: 0.10), value: showTag2)
                            Text(".")
                                .font(.system(size: 22, weight: .bold))
                                .kerning(0.2)
                                .foregroundColor(Color.brandOrange)
                                .opacity(showTagDot ? 1.0 : 0.0)
                                .offset(y: showTagDot ? 0 : 12)
                                .scaleEffect(showTagDot ? 1.0 : 0.94)
                                .animation(.easeOut(duration: 0.10), value: showTagDot)
                        }
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                        .opacity(showTagline ? 1.0 : 0.0)
                        .offset(y: showTagline ? 0 : 14)
                        .scaleEffect(showTagline ? 1.0 : 0.94)
                        .animation(.easeOut(duration: 0.10), value: showTagline)
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                }
                
                // Deflating orange dot
                if showBalloon {
                    Circle()
                        .fill(Color.brandOrange)
                        .frame(width: dotSize * scale * balloonScale, height: dotSize * scale * balloonScale)
                        .shadow(color: Color.brandOrange.opacity(0.6), radius: 10, x: 0, y: 0)
                        .position(balloonPosition)
                }
            }
            .coordinateSpace(name: "introSpace")
            .onAppear {
                startAnimation(in: geometry.size)
            }
        }
        .fullScreenCover(isPresented: $navigateToLogin) {
            LoginView()
        }
    }
    
    private func startAnimation(in size: CGSize) {
        // Pop in bars one by one
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                    showBars[i] = true
                }
                
                // Little wiggle
                withAnimation(.easeInOut(duration: 0.2).delay(0.1)) {
                    barWiggle[i] = 5
                }
                withAnimation(.easeInOut(duration: 0.2).delay(0.3)) {
                    barWiggle[i] = 0
                }
            }
        }
        
        // Show balloon at ground level
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Wait for barsFrame to be set by GeometryReader
            if barsFrame == .zero {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showBalloon = true
                    positionBallAtGround(in: size)
                    startClimb()
                }
            } else {
                showBalloon = true
                positionBallAtGround(in: size)
                startClimb()
            }
        }
    }
    
    private func positionBallAtGround(in size: CGSize) {
        // Compute bars edges in local coordinates
        let barsBottom = barsFrame.maxY
        let barsLeft = barsFrame.minX

        // Position ball at ground level, to the LEFT of bars (fully visible)
        // Ball bottom should sit exactly on barsBottom; X left by radius+gap
        let ballRadius = (dotSize * scale) / 2
        let groundY = barsBottom - ballRadius
        let leftGap: CGFloat = 8
        let groundX = max(ballRadius, barsLeft - ballRadius - leftGap)

        // Clamp within the GeometryReader bounds
        let clampedX = max(ballRadius, min(groundX, size.width - ballRadius))
        let clampedY = max(ballRadius, min(groundY, size.height - ballRadius))

        balloonPosition = CGPoint(x: clampedX, y: clampedY)
        balloonScale = 1.0
    }
    
    // Start climbing: bounce onto bar 0, then 1, then 2, finish above last bar
    func startClimb() {
        // Ensure barsFrame is available
        guard barsFrame != .zero else { return }
        
        let barsBottom = barsFrame.maxY
        let barsLeft = barsFrame.minX
        // Compute bar centers (x) and tops (topY)
        let barPositions: [(x: CGFloat, topY: CGFloat, bottomY: CGFloat)] = [
            (barsLeft + (barWidth * scale / 2),            barsBottom - barHeights[0] * scale, barsBottom),
            (barsLeft + barWidth * scale + barSpacing * scale + (barWidth * scale / 2),
                                                         barsBottom - barHeights[1] * scale, barsBottom),
            ((barsLeft + (barWidth * scale + barSpacing * scale) * 2) + (barWidth * scale / 2),
                                                         barsBottom - barHeights[2] * scale, barsBottom)
        ]
        
        // First hop: two-phase arc from ground (current position) to first bar landing
        let ballRadius = (dotSize * scale) / 2
        let startX = balloonPosition.x
        let startY = balloonPosition.y
        let targetX = barPositions[0].x
        let firstLandingY = barPositions[0].topY - ballRadius
        let midX = (startX + targetX) / 2
        let arcPeakY = min(startY, firstLandingY) - 60

        // Phase 1: rise to peak (faster)
        withAnimation(Animation.timingCurve(0.42, 0.0, 0.58, 1.0, duration: 0.16)) {
            balloonPosition = CGPoint(x: midX, y: arcPeakY)
            balloonScale = 0.95
        }
        // Phase 2: descend to land on first bar (faster)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(Animation.timingCurve(0.2, 0.0, 0.8, 1.0, duration: 0.16)) {
                balloonPosition = CGPoint(x: targetX, y: firstLandingY)
                balloonScale = 1.0
            }
            // Trigger impact/bounce sequence for stair 0, which will continue the climb
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                climbStairs(barPositions: barPositions, currentStair: 0)
            }
        }
    }
    
    private func flyAroundAndLand(in size: CGSize) {
        // Use actual bars frame from GeometryReader
        // The frame gives us the bounding box of all bars
        let barsBottom = barsFrame.maxY  
        let barsLeft = barsFrame.minX
        
        // Calculate each bar's TOP position
        let barPositions: [(x: CGFloat, topY: CGFloat, bottomY: CGFloat)] = [
            (barsLeft + (barWidth * scale / 2), barsBottom - barHeights[0] * scale, barsBottom),
            (barsLeft + barWidth * scale + barSpacing * scale + (barWidth * scale / 2), barsBottom - barHeights[1] * scale, barsBottom),
            (barsLeft + (barWidth * scale + barSpacing * scale) * 2 + (barWidth * scale / 2), barsBottom - barHeights[2] * scale, barsBottom)
        ]
        
        // Start at ground level - ball BOTTOM should be AT bars bottom
        // Ball center = barsBottom - ballRadius
        let ballRadius = (dotSize * scale) / 2
        let groundY = barsBottom - ballRadius
        balloonPosition = CGPoint(x: barPositions[0].x - 60, y: groundY)
        balloonScale = 1.2
        
        // Roll in from left
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.5)) {
                balloonPosition = CGPoint(x: barPositions[0].x - 20, y: groundY)
                balloonScale = 1.0
            }
        }
        
        // Start climbing stairs
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            climbStairs(barPositions: barPositions, currentStair: 0)
        }
    }
    
    private func climbStairs(barPositions: [(x: CGFloat, topY: CGFloat, bottomY: CGFloat)], currentStair: Int) {
        guard currentStair < 3 else {
            // Navigate to login after climbing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                navigateToLogin = true
            }
            return
        }
        
        let delay: TimeInterval = 0.0
        
        // Calculate landing position - ball BOTTOM sits ON bar TOP
        // Ball center = barTop - ballRadius (so ball bottom = barTop)
        let barTopY = barPositions[currentStair].topY
        let ballRadius = (dotSize * scale) / 2
        let landingY = barTopY - ballRadius
        
        // Fall and land on bar top
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeIn(duration: 0.14)) {
                balloonPosition = CGPoint(x: barPositions[currentStair].x, y: landingY)
                balloonScale = 1.0
            }
            // Tagline staged reveals tied to first and second landings
            if currentStair == 0 {
                withAnimation(.easeOut(duration: 0.10)) {
                    showTagline = true
                    showTag1 = true
                }
            } else if currentStair == 1 {
                withAnimation(.easeOut(duration: 0.10)) {
                    showTag2 = true
                }
            }
        }
        
        // Impact squash + bar compress
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.16) {
            withAnimation(.easeOut(duration: 0.06)) {
                balloonScale = 1.3
            }
            
            // Bar squishes (compress vertically)
            withAnimation(.easeOut(duration: 0.06)) {
                barScaleY[currentStair] = 0.90
            }
        }
        
        // Bounce back to normal
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.24) {
            withAnimation(.easeOut(duration: 0.08)) {
                balloonScale = 1.0
            }
            
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 10)) {
                barWiggle[currentStair] = 0
            }
        }
        
        // Bounce to next stair or finish
        if currentStair < 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.30) {
                // Calculate two-phase arc to next bar (sine-like)
                let nextIdx = currentStair + 1
                let startX = barPositions[currentStair].x
                let endX = barPositions[nextIdx].x
                let midX = (startX + endX) / 2
                let nextBarTopY = barPositions[nextIdx].topY
                let nextBallRadius = (dotSize * scale) / 2
                let nextLandingY = nextBarTopY - nextBallRadius
                let arcPeakY = min(landingY, nextLandingY) - 60

                // Phase 1: up to peak (faster)
                withAnimation(Animation.timingCurve(0.42, 0.0, 0.58, 1.0, duration: 0.14)) {
                    balloonPosition = CGPoint(x: midX, y: arcPeakY)
                    balloonScale = 0.95
                    // Bar expands upward while ball rises (mirror motion)
                    barScaleY[currentStair] = 1.04
                }
                // Phase 2: down to next landing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    withAnimation(Animation.timingCurve(0.2, 0.0, 0.8, 1.0, duration: 0.14)) {
                        balloonPosition = CGPoint(x: endX, y: nextLandingY)
                        balloonScale = 1.0
                        // Bar settles back to normal as ball leaves
                        barScaleY[currentStair] = 1.0
                    }
                    // Trigger next stair after landing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                        climbStairs(barPositions: barPositions, currentStair: nextIdx)
                    }
                }
            }
        } else {
            // Final: believable bounces on last bar, then slide to RIGHT with same spacing
            let lastIdx = 2
            let lastTopY = barPositions[lastIdx].topY
            let ballRadius = (dotSize * scale) / 2
            let settleY = lastTopY - ballRadius

            // First rebound (largest)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.14) {
                withAnimation(.interpolatingSpring(stiffness: 250, damping: 18)) {
                    balloonPosition.y = settleY - 26
                    // Bar expands upward while ball rises
                    barScaleY[lastIdx] = 1.06
                }
            }
            // Fall back to settle
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.28) {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 16)) {
                    balloonPosition.y = settleY
                    barScaleY[lastIdx] = 1.0
                }
            }
            // Final small bounce that travels to the RIGHT-final position (arc), synced with bar
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.40) {
                let lastCenterX = barPositions[lastIdx].x
                let halfBar = (barWidth * scale) / 2
                let rightGap: CGFloat = 8
                let finalX = lastCenterX + halfBar + rightGap + ballRadius
                let midX = (lastCenterX + finalX) / 2
                let peakY = settleY - 22
                // Phase 1: rise toward peak and mid X
                withAnimation(Animation.timingCurve(0.42, 0.0, 0.58, 1.0, duration: 0.14)) {
                    balloonPosition = CGPoint(x: midX, y: peakY)
                    barScaleY[lastIdx] = 1.05
                }
                // Phase 2: descend to final X, settleY
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    withAnimation(Animation.timingCurve(0.2, 0.0, 0.8, 1.0, duration: 0.14)) {
                        balloonPosition = CGPoint(x: finalX, y: settleY)
                        barScaleY[lastIdx] = 1.0
                        balloonScale = 1.0
                    }
                    // Reveal final dot at the end
                    withAnimation(.easeOut(duration: 0.08)) {
                        showTagDot = true
                    }
                }
            }
            // Bars celebrate after reaching final spot
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.90) {
                for i in 0..<3 {
                    withAnimation(.easeInOut(duration: 0.15).delay(Double(i) * 0.05)) {
                        barWiggle[i] = 8
                    }
                    withAnimation(.easeInOut(duration: 0.15).delay(Double(i) * 0.05 + 0.15)) {
                        barWiggle[i] = 0
                    }
                }
            }
            // Ensure all bars end perfectly straight and uncompressed
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 1.05) {
                withAnimation(.easeOut(duration: 0.12)) {
                    for i in 0..<3 {
                        barScaleY[i] = 1.0
                        barWiggle[i] = 0
                    }
                }
            }
            // Navigate to login
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 1.20) {
                navigateToLogin = true
            }
        }
    }
}

#Preview {
    IntroView()
}
