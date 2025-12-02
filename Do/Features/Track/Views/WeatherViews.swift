//
//  SunRaysView.swift
//  Do.
//
//  Created by Mikiyas Meseret on 3/28/25.
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//


//
//  ModernWeatherAnimations.swift
//  Do.
//
//  Created for Do App
//

import SwiftUI

// MARK: - Weather Animation Views
struct SunRaysView: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.6
    var opacity: Double = 1.0
    var scale_factor: CGFloat = 1.0
    var showSun: Bool = false // New parameter to control sun visibility
    
    init(opacity: Double = 1.0, scale: CGFloat = 1.0, showSun: Bool = false) {
        self.opacity = opacity
        self.scale_factor = scale
        self.showSun = showSun
    }
    
    var body: some View {
        ZStack {
            // Outer glow - keep this for ambient light effect
            Circle()
                .fill(Color.yellow)
                .frame(width: 60 * scale_factor, height: 60 * scale_factor)
                .blur(radius: 20)
                .opacity(glowOpacity * opacity)
            
            // Sun center - only show if showSun is true
            if showSun {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [Color.white, Color.yellow.opacity(0.8)]),
                            center: .center,
                            startRadius: 1,
                            endRadius: 25 * scale_factor
                        )
                    )
                    .frame(width: 40 * scale_factor, height: 40 * scale_factor)
                    .scaleEffect(scale)
                    .shadow(color: Color.yellow.opacity(0.5 * opacity), radius: 10, x: 0, y: 0)
            }
            
            // Sun rays - keep these for ambient light effect
            ForEach(0..<18) { i in // Increased from 12 to 18 rays for better coverage
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white, Color.yellow.opacity(0.6)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2.0, height: (i.isMultiple(of: 2) ? 35 : 25) * scale_factor)
                    .offset(y: (i.isMultiple(of: 2) ? -50 : -40) * scale_factor)
                    .rotationEffect(.degrees(Double(i) * 20 + rotation)) // Adjusted angle for more rays
                    .opacity((i.isMultiple(of: 2) ? 1.0 : 0.7) * opacity)
            }
        }
        .opacity(opacity)
        .scaleEffect(scale_factor)
        .onAppear {
            // Rotation animation
            withAnimation(Animation.linear(duration: 40).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            
            // Pulsing animation
            withAnimation(Animation.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                scale = 1.1
                glowOpacity = 0.8
            }
        }
    }
}

struct StarsView: View {
    let starCount = 50
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Background stars (static, smaller)
                ForEach(0..<30, id: \.self) { i in
                    Circle()
                        .fill(Color.white)
                        .frame(width: CGFloat.random(in: 1...2), height: CGFloat.random(in: 1...2))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                        .opacity(Double.random(in: 0.3...0.6))
                }
                
                // Twinkling stars
                ForEach(0..<starCount, id: \.self) { i in
                    TwinklingStar(size: CGFloat.random(in: 2...4))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                }
                
                // A few shooting stars with different angles
                ShootingStar(angle: -45)
                    .position(x: geo.size.width * 0.7, y: geo.size.height * 0.3)
                
                ShootingStar(delay: 3.0, angle: -35)
                    .position(x: geo.size.width * 0.2, y: geo.size.height * 0.6)
                
                ShootingStar(delay: 5.0, angle: -55)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) // Ensure consistent positioning
        }
    }
    
    struct TwinklingStar: View {
        let size: CGFloat
        @State private var opacity: Double = 0.0
        @State private var scale: CGFloat = 0.5
        
        var body: some View {
            StarShape(size: size)
                .fill(Color.white)
                .frame(width: size, height: size)
                .opacity(opacity)
                .scaleEffect(scale)
                .onAppear {
                    // Random initial delay
                    let delay = Double.random(in: 0...3)
                    
                    // Random animation duration
                    let duration = Double.random(in: 1.5...3.0)
                    
                    // Animate with delay and repeat
                    withAnimation(
                        Animation
                            .easeInOut(duration: duration)
                            .repeatForever(autoreverses: true)
                            .delay(delay)
                    ) {
                        opacity = Double.random(in: 0.5...1.0)
                        scale = CGFloat.random(in: 0.8...1.2)
                    }
                }
        }
    }
    
    struct StarShape: Shape {
        let size: CGFloat
        
        func path(in rect: CGRect) -> Path {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let points = 5
            var path = Path()
            
            for i in 0..<points * 2 {
                let radius = i.isMultiple(of: 2) ? size : size / 2
                let angle = Double(i) * .pi / Double(points)
                let x = center.x + CGFloat(cos(angle)) * radius
                let y = center.y + CGFloat(sin(angle)) * radius
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            path.closeSubpath()
            return path
        }
    }
    
    struct ShootingStar: View {
        let delay: Double
        let angle: Double // Add angle parameter to control direction
        
        @State private var offset: CGSize = .zero
        @State private var opacity: Double = 0.0
        
        init(delay: Double = 0.0, angle: Double = -45) {
            self.delay = delay
            self.angle = angle
        }
        
        var body: some View {
            VStack {
                Capsule()
                    .fill(Color.white)
                    .frame(width: 1, height: 15)
                    .blur(radius: 0.5)
                    .rotationEffect(.degrees(angle)) // Use the angle parameter
                    .offset(offset)
                    .opacity(opacity)
            }
            .onAppear {
                // Initial delay
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    // Repeat the animation
                    animateShootingStar()
                }
            }
        }
        
        private func animateShootingStar() {
            // Reset position
            opacity = 0
            offset = .zero
            
            // Calculate offset direction based on angle
            let radians = angle * .pi / 180
            let xOffset = -100 * cos(radians)
            let yOffset = 100 * sin(radians)
            
            // Animate shooting in the correct direction
            withAnimation(.easeOut(duration: 0.8)) {
                opacity = 1.0
                offset = CGSize(width: xOffset, height: yOffset)
            }
            
            // Schedule next animation with random delay
            let nextDelay = Double.random(in: 4...8)
            DispatchQueue.main.asyncAfter(deadline: .now() + nextDelay) {
                animateShootingStar()
            }
        }
    }
}

struct CloudOverlay: View {
    var nightMode: Bool = false
    var cloudiness: CloudAmount = .full
    @State private var position = -300.0
    
    enum CloudAmount {
        case partial, full
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Fewer cloud layers with purely horizontal movement
                // Background clouds (darker, slower)
                FluidCloudLayer(
                    opacity: nightMode ? 0.25 : 0.4, 
                    blur: 15,
                    nightMode: nightMode,
                    speed: 0.3,
                    yOffset: 0, // No vertical offset
                    scale: cloudiness == .full ? 1.2 : 0.9,
                    count: cloudiness == .full ? 4 : 2 // Fewer clouds
                )
                .offset(x: position * 0.3, y: 0)
                
                // Only one middle layer for full cloudiness
                if cloudiness == .full {
                    FluidCloudLayer(
                        opacity: nightMode ? 0.2 : 0.35, 
                        blur: 12,
                        nightMode: nightMode,
                        speed: 0.5,
                        yOffset: 0, // No vertical offset
                        scale: 1.1,
                        count: 3 // Fewer clouds
                    )
                    .offset(x: position * 0.5, y: 0)
                }
                
                // Foreground clouds (lighter, faster)
                FluidCloudLayer(
                    opacity: nightMode ? 0.15 : 0.3, 
                    blur: 10,
                    nightMode: nightMode,
                    speed: 0.7,
                    yOffset: 0, // No vertical offset
                    scale: 1.0,
                    count: cloudiness == .full ? 3 : 2 // Fewer clouds
                )
                .offset(x: position * 0.7, y: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                // Animate clouds slowly across the screen
                withAnimation(Animation.linear(duration: 60).repeatForever(autoreverses: false)) {
                    position = geo.size.width + 300
                }
            }
        }
    }
    
    // Fluid cloud layer with purely horizontal movement
    struct FluidCloudLayer: View {
        let opacity: Double
        let blur: CGFloat
        let nightMode: Bool
        let speed: Double
        let yOffset: CGFloat
        let scale: CGFloat
        let count: Int
        
        var body: some View {
            HStack(spacing: -20) { // Tighter spacing for fewer clouds
                ForEach(0..<count, id: \.self) { i in
                    Circle()
                        .fill(
                            nightMode ? 
                            Color(red: 0.15, green: 0.15, blue: 0.25).opacity(opacity) : 
                            Color.white.opacity(opacity)
                        )
                        .frame(width: 150, height: 150) // Larger clouds
                        .scaleEffect(scale)
                        .blur(radius: blur)
                }
            }
        }
    }
}

// Completely redesigned rain overlay for more realistic top-down rain
struct ModernRainOverlay: View {
    enum Intensity {
        case light, medium, heavy
    }
    
    let intensity: Intensity
    var nightMode: Bool = false
    @State private var cloudPosition = -300.0
    @State private var windDirection = 12.0 // Wind angle
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Dark overlay for rainy atmosphere
                Color.black.opacity(nightMode ? 0.3 : 0.15)
                    .edgesIgnoringSafeArea(.all)
                
                // Directional wind streaks in background
                ForEach(0..<8) { i in
                    WindDrivenRainStreak(
                        width: geo.size.width * 0.6,
                        height: CGFloat.random(in: 2...4),
                        opacity: Double.random(in: 0.03...0.08),
                        speed: Double.random(in: 8...12),
                        angle: windDirection + Double.random(in: -3...3),
                        nightMode: nightMode
                    )
                    .position(
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: CGFloat.random(in: 0...geo.size.height * 0.7)
                    )
                }
                
                // Rain clouds layer - now using fluid clouds like fog
                VStack(spacing: 0) {
                    // Dark heavy cloud layer with fluid movement
                    ZStack {
                        // Fluid background clouds
                        FluidRainClouds(
                            opacity: nightMode ? 0.7 : 0.85,
                            blur: 14,
                            nightMode: nightMode,
                            count: 10,
                            width: geo.size.width,
                            height: geo.size.height * 0.5
                        )
                        .offset(x: cloudPosition * 0.3, y: -geo.size.height * 0.1)
                        
                        // Additional fluid cloud layer for depth
                        FluidRainClouds(
                            opacity: nightMode ? 0.5 : 0.65,
                            blur: 10,
                            nightMode: nightMode,
                            count: 8,
                            width: geo.size.width,
                            height: geo.size.height * 0.4
                        )
                        .offset(x: cloudPosition * 0.6, y: -geo.size.height * 0.05)
                    }
                    .frame(height: geo.size.height * 0.4)
                    
                    Spacer()
                }
                .onAppear {
                    // Animate clouds slowly across the screen
                    withAnimation(Animation.linear(duration: 80).repeatForever(autoreverses: false)) {
                        cloudPosition = geo.size.width + 300
                    }
                }
                
                // Rain mist overlay
                RainMistEffect(
                    intensity: intensity,
                    nightMode: nightMode
                )
                
                // Falling mist and haze - diagonal motion
                ForEach(0..<getMistLayerCount(), id: \.self) { i in
                    FallingMistLayer(
                        width: geo.size.width,
                        height: geo.size.height,
                        opacity: getMistOpacity(index: i),
                        speed: getMistSpeed(index: i),
                        nightMode: nightMode
                    )
                }
                
                // Rain blur streaks - more diagonal for wind-driven effect
                ForEach(0..<getStreakCount(), id: \.self) { i in
                    RainBlurStreak(
                        height: geo.size.height * CGFloat.random(in: 0.3...0.7),
                        opacity: getStreakOpacity(),
                        nightMode: nightMode
                    )
                    .frame(width: 2)
                    .position(
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: CGFloat.random(in: 0...geo.size.height)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    
    // Fluid rain clouds for a more fog-like appearance
    struct FluidRainClouds: View {
        let opacity: Double
        let blur: CGFloat
        let nightMode: Bool
        let count: Int
        let width: CGFloat
        let height: CGFloat
        
        var body: some View {
            HStack(spacing: -40) {
                ForEach(0..<count, id: \.self) { i in
                    Circle()
                        .fill(
                            nightMode ? 
                            Color(red: 0.2, green: 0.2, blue: 0.3).opacity(opacity) : 
                            Color.gray.opacity(opacity)
                        )
                        .frame(width: width / CGFloat(count - 2), height: width / CGFloat(count - 2))
                        .offset(y: i.isMultiple(of: 2) ? 0 : 20)
                        .blur(radius: blur)
                }
            }
            .frame(width: width * 1.5, height: height)
            .rotationEffect(.degrees(2)) // Slight tilt to suggest wind
        }
    }
    
    // Wind-driven rain streak effect
    struct WindDrivenRainStreak: View {
        let width: CGFloat
        let height: CGFloat
        let opacity: Double
        let speed: Double
        let angle: Double
        let nightMode: Bool
        
        @State private var offset: CGFloat = -400
        
        var body: some View {
            Capsule()
                .fill(Color.white.opacity(nightMode ? opacity * 0.7 : opacity))
                .frame(width: width, height: height)
                .blur(radius: 1.2)
                .rotationEffect(.degrees(angle))
                .offset(x: offset)
                .onAppear {
                    withAnimation(Animation.linear(duration: speed).repeatForever(autoreverses: false)) {
                        offset = 400
                    }
                }
        }
    }
    
    // Remaining rain overlay methods unchanged
    private func getMistLayerCount() -> Int {
        switch intensity {
        case .light: return 3
        case .medium: return 5
        case .heavy: return 7
        }
    }
    
    private func getMistOpacity(index: Int) -> Double {
        let baseOpacity: Double
        switch intensity {
        case .light: baseOpacity = 0.07
        case .medium: baseOpacity = 0.1
        case .heavy: baseOpacity = 0.15
        }
        
        return baseOpacity * (Double(index) * 0.5 + 1.0)
    }
    
    private func getMistSpeed(index: Int) -> Double {
        let baseSpeed: Double
        switch intensity {
        case .light: baseSpeed = 25.0
        case .medium: baseSpeed = 20.0
        case .heavy: baseSpeed = 15.0
        }
        
        return baseSpeed - Double(index) * 1.5
    }
    
    private func getStreakCount() -> Int {
        switch intensity {
        case .light: return 15
        case .medium: return 30
        case .heavy: return 50
        }
    }
    
    private func getStreakOpacity() -> Double {
        switch intensity {
        case .light: return Double.random(in: 0.05...0.1)
        case .medium: return Double.random(in: 0.08...0.15)
        case .heavy: return Double.random(in: 0.1...0.2)
        }
    }
}

// Mist effect for rain atmosphere
struct RainMistEffect: View {
    let intensity: ModernRainOverlay.Intensity
    let nightMode: Bool
    
    var body: some View {
        ZStack {
            // Ambient mist
            Color.white.opacity(nightMode ? 0.02 : 0.05)
                .blur(radius: 20)
            
            // Additional mist layers based on intensity
            ForEach(0..<getMistLayers(), id: \.self) { _ in
                MistLayer(
                    opacity: getMistOpacity(),
                    blur: getMistBlur(),
                    nightMode: nightMode
                )
            }
        }
    }
    
    private func getMistLayers() -> Int {
        switch intensity {
        case .light: return 2
        case .medium: return 3
        case .heavy: return 4
        }
    }
    
    private func getMistOpacity() -> Double {
        switch intensity {
        case .light: return Double.random(in: 0.03...0.07)
        case .medium: return Double.random(in: 0.05...0.1)
        case .heavy: return Double.random(in: 0.08...0.15)
        }
    }
    
    private func getMistBlur() -> CGFloat {
        switch intensity {
        case .light: return CGFloat.random(in: 15...25)
        case .medium: return CGFloat.random(in: 10...20)
        case .heavy: return CGFloat.random(in: 8...15)
        }
    }
}

// Individual mist layer
struct MistLayer: View {
    let opacity: Double
    let blur: CGFloat
    let nightMode: Bool
    
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.white.opacity(nightMode ? opacity * 0.7 : opacity))
                    .frame(width: geo.size.width * 0.6, height: geo.size.width * 0.6)
                    .position(
                        x: CGFloat(i) * geo.size.width * 0.4,
                        y: CGFloat.random(in: geo.size.height * 0.2...geo.size.height * 0.8)
                    )
                    .blur(radius: blur)
            }
        }
    }
}

// Falling mist layer
struct FallingMistLayer: View {
    let width: CGFloat
    let height: CGFloat
    let opacity: Double
    let speed: Double
    let nightMode: Bool
    
    @State private var yOffset: CGFloat = -500
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Falling mist particles with diagonal direction
                ForEach(0..<10) { i in
                    Circle()
                        .fill(Color.white.opacity(nightMode ? opacity * 0.7 : opacity))
                        .frame(width: width * 0.6, height: height * 0.15)
                        .blur(radius: 12)
                        .position(x: CGFloat(i) * width / 10, y: (height / 2) + yOffset)
                }
            }
            .onAppear {
                withAnimation(Animation.linear(duration: speed).repeatForever(autoreverses: false)) {
                    yOffset = 500
                }
            }
        }
        .clipped() // Prevent overflow
    }
}

// Rain blurred streak effect
struct RainBlurStreak: View {
    let height: CGFloat
    let opacity: Double
    let nightMode: Bool
    
    @State private var isAnimating = false
    
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(nightMode ? opacity * 0.7 : opacity))
            .frame(width: 2, height: height)
            .blur(radius: 0.8)
            .rotationEffect(.degrees(15)) // More diagonal for wind-driven effect
            .offset(y: isAnimating ? 800 : -800)
            .onAppear {
                let delay = Double.random(in: 0...1.0)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(Animation.linear(duration: Double.random(in: 0.6...1.2)).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }
            }
    }
}

struct LightningView: View {
    @State private var isFlashing = false
    @State private var secondaryFlash = false
    @State private var backgroundGlow = false
    @State private var cloudPosition = -300.0
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Dark background to increase contrast for lightning
                Color.black.opacity(0.25)
                    .edgesIgnoringSafeArea(.all)
                
                // Background glow effect
                Color.white.opacity(backgroundGlow ? 0.3 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blur(radius: 25)
                    .animation(.easeOut(duration: 0.2), value: backgroundGlow)
                
                // Fluid storm cloud layers with movement
                VStack(spacing: 0) {
                    ZStack {
                        // Dark storm cloud base - fluid style like fog
                        FluidStormCloudLayer(
                            opacity: 0.8,
                            blur: 16,
                            isNight: true,
                            count: 8,
                            width: geo.size.width,
                            height: geo.size.height * 0.5,
                            isFlashing: isFlashing || secondaryFlash
                        )
                        .offset(x: cloudPosition * 0.3, y: -geo.size.height * 0.1)
                        
                        // Middle storm cloud layer
                        FluidStormCloudLayer(
                            opacity: 0.7,
                            blur: 14,
                            isNight: true,
                            count: 6,
                            width: geo.size.width,
                            height: geo.size.height * 0.4,
                            isFlashing: isFlashing || secondaryFlash
                        )
                        .offset(x: cloudPosition * 0.5, y: -geo.size.height * 0.05)
                        
                        // Foreground storm cloud details
                        FluidStormCloudLayer(
                            opacity: 0.6,
                            blur: 10,
                            isNight: true,
                            count: 10,
                            width: geo.size.width,
                            height: geo.size.height * 0.3,
                            isFlashing: isFlashing || secondaryFlash
                        )
                        .offset(x: cloudPosition * 0.7, y: 0)
                    }
                    .frame(height: geo.size.height * 0.5)
                    
                    Spacer()
                }
                
                // Rain streaks for stormy weather (more intense rain with more streaks)
                ForEach(0..<45) { _ in
                    ThunderRainStreak(
                        height: geo.size.height * CGFloat.random(in: 0.3...0.8),
                        width: CGFloat.random(in: 1.0...2.8),
                        opacity: Double.random(in: 0.07...0.18)
                    )
                    .position(
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: CGFloat.random(in: 0...geo.size.height)
                    )
                }
                
                // Main lightning bolt group - only shows during flashes
                Group {
                    if isFlashing || secondaryFlash {
                        // Primary lightning bolt
                        ThunderBolt(
                            startPoint: CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.15),
                            endPoint: CGPoint(x: geo.size.width * 0.45, y: geo.size.height * 0.65),
                            width: 5,
                            variance: 30,
                            segmentLength: 60,
                            branchProbability: 0.3
                        )
                        .stroke(Color.white, lineWidth: isFlashing ? 3 : 2)
                        .shadow(color: Color.white.opacity(0.8), radius: 8, x: 0, y: 0)
                        .opacity(isFlashing ? 1.0 : (secondaryFlash ? 0.8 : 0))
                        
                        // Secondary bolt (only visible sometimes)
                        if Double.random(in: 0...1) > 0.3 {
                            ThunderBolt(
                                startPoint: CGPoint(x: geo.size.width * 0.6, y: geo.size.height * 0.2),
                                endPoint: CGPoint(x: geo.size.width * 0.67, y: geo.size.height * 0.5),
                                width: 3,
                                variance: 20,
                                segmentLength: 40,
                                branchProbability: 0.2
                            )
                            .stroke(Color.white, lineWidth: isFlashing ? 2 : 1.5)
                            .shadow(color: Color.white.opacity(0.7), radius: 6, x: 0, y: 0)
                            .opacity(isFlashing ? 0.9 : (secondaryFlash ? 0.7 : 0))
                        }
                    }
                }
                
                // Cloud illumination effect - subtle internal glow that flashes with lightning
                Rectangle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(isFlashing ? 0.3 : (secondaryFlash ? 0.2 : 0)),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 5,
                            endRadius: geo.size.width * 0.6
                        )
                    )
                    .frame(width: geo.size.width, height: geo.size.height * 0.6)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.3)
                    .animation(.easeOut(duration: 0.1), value: isFlashing)
                    .animation(.easeOut(duration: 0.15), value: secondaryFlash)
                
                // Distant lightning flashes in the clouds
                if !isFlashing && !secondaryFlash && Double.random(in: 0...1) > 0.6 {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: CGFloat.random(in: 50...100), height: CGFloat.random(in: 50...100))
                            .blur(radius: CGFloat.random(in: 20...30))
                            .position(
                                x: CGFloat.random(in: geo.size.width * 0.2...geo.size.width * 0.8),
                                y: CGFloat.random(in: geo.size.height * 0.1...geo.size.height * 0.4)
                            )
                            .opacity(backgroundGlow ? Double.random(in: 0.1...0.3) : 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                // Start cloud movement animation
                withAnimation(Animation.linear(duration: 70).repeatForever(autoreverses: false)) {
                    cloudPosition = geo.size.width + 300
                }
                
                // Start lightning sequence
                startLightningSequence()
            }
        }
    }
    
    // Fluid storm cloud layer for more dynamic appearance
    struct FluidStormCloudLayer: View {
        let opacity: Double
        let blur: CGFloat
        let isNight: Bool
        let count: Int
        let width: CGFloat
        let height: CGFloat
        let isFlashing: Bool
        
        var body: some View {
            HStack(spacing: -40) {
                ForEach(0..<count, id: \.self) { i in
                    Circle()
                        .fill(
                            isFlashing ?
                            Color(red: 0.3, green: 0.3, blue: 0.4).opacity(opacity * 1.2) :
                            Color(red: 0.2, green: 0.2, blue: 0.3).opacity(opacity)
                        )
                        .frame(width: width / CGFloat(count - 3), height: width / CGFloat(count - 3))
                        .offset(y: i.isMultiple(of: 2) ? 0 : 15)
                        .blur(radius: blur)
                }
            }
            .frame(width: width * 1.5, height: height)
        }
    }
    
    private func startLightningSequence() {
        // More natural timing for lightning flashes
        let delay = Double.random(in: 2.0...5.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Background glow first (distant lightning)
            withAnimation(.easeIn(duration: 0.15)) {
                backgroundGlow = true
            }
            
            // Main flash with slight delay for realism
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.07)) {
                    isFlashing = true
                }
                
                // Dim main flash
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.easeIn(duration: 0.05)) {
                        isFlashing = false
                    }
                    
                    // Higher chance of secondary flash (more realistic)
                    let hasSecondaryFlash = Double.random(in: 0...1) > 0.1
                    
                    if hasSecondaryFlash {
                        // Secondary flash after a brief pause
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeOut(duration: 0.05)) {
                                secondaryFlash = true
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                                withAnimation(.easeIn(duration: 0.1)) {
                                    secondaryFlash = false
                                }
                                
                                // Possible third flash in quick succession (natural thunderstorm pattern)
                                if Double.random(in: 0...1) > 0.4 {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        withAnimation(.easeOut(duration: 0.03)) {
                                            isFlashing = true
                                        }
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                                            withAnimation(.easeIn(duration: 0.07)) {
                                                isFlashing = false
                                            }
                                            
                                            // Fade background glow
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                withAnimation(.easeOut(duration: 0.3)) {
                                                    backgroundGlow = false
                                                }
                                                
                                                // Continue sequence
                                                startLightningSequence()
                                            }
                                        }
                                    }
                                } else {
                                    // Fade background glow
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            backgroundGlow = false
                                        }
                                        
                                        // Continue sequence
                                        startLightningSequence()
                                    }
                                }
                            }
                        }
                    } else {
                        // Fade background glow
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                backgroundGlow = false
                            }
                            
                            // Continue sequence
                            startLightningSequence()
                        }
                    }
                }
            }
        }
    }
}

// Rain streak specifically for thunder view
struct ThunderRainStreak: View {
    let height: CGFloat
    let width: CGFloat
    let opacity: Double
    
    @State private var isAnimating = false
    
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(opacity))
            .frame(width: width, height: height)
            .blur(radius: 1.2)
            .rotationEffect(.degrees(5))
            .offset(y: isAnimating ? 1000 : -1000)
            .onAppear {
                // Add randomized initial delay to stagger rain appearance
                let delay = Double.random(in: 0...1.0)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    // Continuous rain animation that never stops
                    withAnimation(
                        Animation.linear(duration: Double.random(in: 0.7...1.0))
                        .repeatForever(autoreverses: false)
                    ) {
                        isAnimating = true
                    }
                }
            }
    }
}

// Advanced lightning bolt shape with branching
struct ThunderBolt: Shape {
    let startPoint: CGPoint
    let endPoint: CGPoint
    let width: CGFloat
    let variance: CGFloat
    let segmentLength: CGFloat
    let branchProbability: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Generate the main lightning path
        let mainPoints = generateLightningPath(from: startPoint, to: endPoint)
        
        // Draw the main bolt
        path.move(to: mainPoints[0])
        for i in 1..<mainPoints.count {
            path.addLine(to: mainPoints[i])
        }
        
        // Generate random branches
        let segments = mainPoints.count - 1
        for i in 0..<segments {
            if i % 2 == 0 && Double.random(in: 0...1) < branchProbability {
                let branchStart = mainPoints[i]
                let branchDirection = Double.random(in: -90...90)
                let branchLength = CGFloat.random(in: segmentLength * 0.3...segmentLength * 0.7)
                let branchEnd = CGPoint(
                    x: branchStart.x + branchLength * CGFloat(cos(branchDirection * .pi / 180)),
                    y: branchStart.y + branchLength * CGFloat(sin(branchDirection * .pi / 180))
                )
                
                let branchPoints = generateLightningPath(from: branchStart, to: branchEnd)
                path.move(to: branchPoints[0])
                for j in 1..<branchPoints.count {
                    path.addLine(to: branchPoints[j])
                }
            }
        }
        
        return path
    }
    
    private func generateLightningPath(from start: CGPoint, to end: CGPoint) -> [CGPoint] {
        var points = [start]
        
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // Calculate how many segments we need
        let numSegments = max(Int(distance / segmentLength), 2)
        
        for i in 1..<numSegments {
            let progress = CGFloat(i) / CGFloat(numSegments)
            let straightX = start.x + dx * progress
            let straightY = start.y + dy * progress
            
            // Add some randomness, more in the middle
            let randFactor = variance * sin(progress * .pi)
            let offsetX = CGFloat.random(in: -randFactor...randFactor)
            let offsetY = CGFloat.random(in: -randFactor / 2...randFactor / 2) // Less vertical variance
            
            points.append(CGPoint(x: straightX + offsetX, y: straightY + offsetY))
        }
        
        points.append(end)
        return points
    }
}

// Improved cloud shape that looks more natural
struct ImprovedCloudShape: Shape {
    var width: CGFloat
    var height: CGFloat
    
    init(width: CGFloat = 100, height: CGFloat = 60) {
        self.width = width
        self.height = height
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Create a more complex cloud shape with multiple bumps of varying sizes
        path.move(to: CGPoint(x: width * 0.1, y: height * 0.8))
        
        // Left edge bump
        path.addArc(
            center: CGPoint(x: width * 0.15, y: height * 0.7),
            radius: height * 0.3,
            startAngle: .degrees(90),
            endAngle: .degrees(270),
            clockwise: false
        )
        
        // First large bump
        path.addArc(
            center: CGPoint(x: width * 0.3, y: height * 0.5),
            radius: height * 0.4,
            startAngle: .degrees(180),
            endAngle: .degrees(320),
            clockwise: false
        )
        
        // Middle large bump
        path.addArc(
            center: CGPoint(x: width * 0.5, y: height * 0.4),
            radius: height * 0.5,
            startAngle: .degrees(220),
            endAngle: .degrees(320),
            clockwise: false
        )
        
        // Right side bump
        path.addArc(
            center: CGPoint(x: width * 0.7, y: height * 0.45),
            radius: height * 0.45,
            startAngle: .degrees(250),
            endAngle: .degrees(40),
            clockwise: false
        )
        
        // Small far right bump
        path.addArc(
            center: CGPoint(x: width * 0.85, y: height * 0.65),
            radius: height * 0.3,
            startAngle: .degrees(300),
            endAngle: .degrees(90),
            clockwise: false
        )
        
        // Bottom right
        path.addLine(to: CGPoint(x: width * 0.9, y: height * 0.8))
        
        // Bottom edge
        path.addLine(to: CGPoint(x: width * 0.1, y: height * 0.8))
        
        path.closeSubpath()
        return path
    }
}

struct SnowfallView: View {
    var nightMode: Bool = false
    
    // Snowflake properties
    @State private var snowflakePositions: [(x: CGFloat, y: CGFloat, size: CGFloat, rotation: Double, speed: Double, landed: Bool, meltProgress: CGFloat)] = []
    
    // Accumulated snow properties
    @State private var snowDepth: CGFloat = 0
    @State private var snowCoverWidth: CGFloat = 0
    @State private var isMelting: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Cold blue tint for snowy atmosphere
                Color.blue.opacity(nightMode ? 0.05 : 0.02)
                    .edgesIgnoringSafeArea(.all)
                
                // Falling snowflakes
                ForEach(0..<snowflakePositions.count, id: \.self) { i in
                    if !snowflakePositions[i].landed {
                        Circle()
                            .fill(Color.white.opacity(nightMode ? 0.7 : 0.9))
                            .frame(width: snowflakePositions[i].size, height: snowflakePositions[i].size)
                            .rotationEffect(.degrees(snowflakePositions[i].rotation))
                            .position(x: snowflakePositions[i].x, y: snowflakePositions[i].y)
                            .blur(radius: 0.3)
                    } else {
                        // Landed snowflakes that gradually melt
                        Circle()
                            .fill(Color.white.opacity(nightMode ? 0.7 : 0.9))
                            .frame(width: snowflakePositions[i].size * (1.0 - snowflakePositions[i].meltProgress), 
                                  height: snowflakePositions[i].size * (1.0 - snowflakePositions[i].meltProgress))
                            .position(x: snowflakePositions[i].x, 
                                    y: geo.size.height - snowDepth + (snowflakePositions[i].size / 2))
                            .opacity(1.0 - snowflakePositions[i].meltProgress)
                            .blur(radius: 0.3)
                    }
                }
                
                // Accumulated snow at the bottom
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(nightMode ? 0.7 : 0.9),
                                Color.white.opacity(nightMode ? 0.5 : 0.7)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: snowCoverWidth, height: snowDepth)
                    .position(x: geo.size.width / 2, y: geo.size.height - (snowDepth / 2))
                    .blur(radius: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                // Initialize snowflake positions with more flakes
                snowflakePositions = (0..<100).map { _ in
                    (
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: CGFloat.random(in: -100...geo.size.height * 0.7),
                        size: CGFloat.random(in: 4...12),
                        rotation: Double.random(in: 0...360),
                        speed: Double.random(in: 15...30), // Slower snow
                        landed: false,
                        meltProgress: 0.0
                    )
                }
                
                // Start animation
                animateSnowfall(geo: geo)
                
                // Start snow build-up
                startSnowAccumulation()
                
                // Set up a melting timer
                startMeltingCycle(geo: geo)
            }
        }
    }
    
    private func animateSnowfall(geo: GeometryProxy) {
        // Calculate landing threshold based on current pile height
        let landingThreshold = geo.size.height * (1.0 - 0.15 * snowDepth)
        
        // Animate each snowflake
        for i in 0..<snowflakePositions.count where !snowflakePositions[i].landed {
            // Create local copy to avoid read-write issue
            var snowflake = snowflakePositions[i]
            
            // Animate vertical movement at varying speeds for more natural snow
            withAnimation(Animation.linear(duration: snowflake.speed)) {
                snowflake.y = landingThreshold + 5
            }
            
            // Animate horizontal drift with wider range for more natural snow movement
            withAnimation(Animation.easeInOut(duration: Double.random(in: 8...12)).repeatForever(autoreverses: true)) {
                snowflake.x += CGFloat.random(in: -30...30)
            }
            
            // Animate rotation
            withAnimation(Animation.linear(duration: Double.random(in: 15...25)).repeatForever(autoreverses: false)) {
                snowflake.rotation += 360
            }
            
            // When snowflake reaches the landing threshold, mark it as landed
            DispatchQueue.main.asyncAfter(deadline: .now() + snowflake.speed * 0.95) {
                if i < snowflakePositions.count && !snowflakePositions[i].landed {
                    // Mark as landed and reset for new snowflake from top
                    var landedSnowflake = snowflakePositions[i]
                    landedSnowflake.landed = true
                    snowflakePositions[i] = landedSnowflake
                    
                    // Create a new snowflake to replace the landed one
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.1...1.0)) {
                        if i < snowflakePositions.count {
                            snowflakePositions[i] = (
                                x: CGFloat.random(in: 0...geo.size.width),
                                y: CGFloat.random(in: -50...0),
                                size: CGFloat.random(in: 4...12),
                                rotation: Double.random(in: 0...360),
                                speed: Double.random(in: 15...30),
                                landed: false,
                                meltProgress: 0.0
                            )
                        }
                    }
                }
            }
            
            // Update the position
            snowflakePositions[i] = snowflake
        }
    }
    
    private func startSnowAccumulation() {
        // Gradually increase snow pile height
        withAnimation(.linear(duration: 30)) {
            snowDepth = 1.0
        }
    }
    
    private func startMeltingCycle(geo: GeometryProxy) {
        // Start melting cycle after 45 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) {
            withAnimation(.easeInOut(duration: 2)) {
                isMelting = true
            }
            
            // Gradually melt the snow
            withAnimation(.easeInOut(duration: 15)) {
                snowDepth = 0.0
            }
            
            // Melt landed snowflakes
            for i in 0..<snowflakePositions.count where snowflakePositions[i].landed {
                withAnimation(.easeInOut(duration: Double.random(in: 5...15))) {
                    var meltingSnowflake = snowflakePositions[i]
                    meltingSnowflake.meltProgress = 1.0
                    snowflakePositions[i] = meltingSnowflake
                }
            }
            
            // After melting cycle, restart snow accumulation
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                withAnimation(.easeInOut(duration: 2)) {
                    isMelting = false
                }
                
                // Reset all snowflakes
                for i in 0..<snowflakePositions.count {
                    snowflakePositions[i] = (
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: CGFloat.random(in: -100...geo.size.height * 0.7),
                        size: CGFloat.random(in: 4...12),
                        rotation: Double.random(in: 0...360),
                        speed: Double.random(in: 15...30),
                        landed: false,
                        meltProgress: 0.0
                    )
                }
                
                // Start snow accumulation again
                startSnowAccumulation()
                
                // Restart the cycle
                startMeltingCycle(geo: geo)
            }
        }
    }
    
    struct Snowflake: View {
        let size: CGFloat
        let rotation: Double
        let nightMode: Bool
        let meltProgress: Double
        
        var body: some View {
            Group {
                // Some snowflakes are simple circles for better visibility
                if Bool.random() {
                    Circle()
                        .fill(Color.white.opacity(nightMode ? 0.9 : 1.0))
                        .frame(width: size, height: size)
                        .blur(radius: 0.5 + meltProgress * 2)
                        .shadow(color: .white.opacity((nightMode ? 0.6 : 0.8) * (1 - meltProgress)), radius: 2, x: 0, y: 0)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity((nightMode ? 0.6 : 0.8) * (1 - meltProgress)), lineWidth: 1)
                        )
                } else {
                    // Some snowflakes have crystal shape
                    ZStack {
                        // Back glow
                        Image(systemName: "snowflake.circle.fill")
                            .font(.system(size: size * 1.5))
                            .foregroundColor(.white.opacity(0.4 * (1 - meltProgress)))
                            .blur(radius: 2 + meltProgress * 2)
                        
                        // Main snowflake
                        Image(systemName: "snowflake")
                            .font(.system(size: size * 1.2))
                            .foregroundColor(.white.opacity((nightMode ? 0.9 : 1.0) * (1 - meltProgress)))
                    }
                    .shadow(color: .white.opacity((nightMode ? 0.5 : 0.8) * (1 - meltProgress)), radius: 2, x: 0, y: 0)
                }
            }
            .rotationEffect(.degrees(rotation))
        }
    }
    
    // Snow pile shape
    struct SnowPile: Shape {
        var height: CGFloat // 0.0 to 1.0
        
        var animatableData: CGFloat {
            get { height }
            set { height = newValue }
        }
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            
            // No pile when height is 0
            if height <= 0 {
                return path
            }
            
            let width = rect.width
            let maxHeight = rect.height * height
            
            // Create a wavy snow pile top
            path.move(to: CGPoint(x: 0, y: rect.height))
            
            // Add multiple arcs for the snow surface to create a natural look
            let segments = 8
            let segmentWidth = width / CGFloat(segments)
            
            for i in 0...segments {
                let x = CGFloat(i) * segmentWidth
                let yVariation = CGFloat.random(in: -maxHeight * 0.2...maxHeight * 0.1)
                let y = rect.height - maxHeight + yVariation
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: rect.height))
                    path.addLine(to: CGPoint(x: x, y: y))
                } else {
                    // Create rounded humps for snow pile
                    let controlPoint1 = CGPoint(
                        x: CGFloat(i-1) * segmentWidth + segmentWidth * 0.5,
                        y: rect.height - maxHeight + CGFloat.random(in: -maxHeight * 0.15...maxHeight * 0.15)
                    )
                    
                    path.addQuadCurve(to: CGPoint(x: x, y: y), control: controlPoint1)
                }
            }
            
            // Complete the shape
            path.addLine(to: CGPoint(x: width, y: rect.height))
            path.closeSubpath()
            
            return path
        }
    }
    
    // Water effect for melting snow
    struct MeltingEffect: View {
        let progress: CGFloat // 0.0 to 1.0
        let width: CGFloat
        
        var body: some View {
            ZStack {
                // Water droplets
                ForEach(0..<Int(15 * progress), id: \.self) { i in
                    WaterDrop(size: CGFloat.random(in: 3...8) * progress)
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 8, height: 12)
                        .offset(
                            x: CGFloat.random(in: -width/2...width/2),
                            y: CGFloat.random(in: -10...0) * progress
                        )
                }
                
                // Small puddle effect
                Ellipse()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.2),
                                Color.blue.opacity(0.5)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width * 0.5 * progress, height: 10 * progress)
                    .blur(radius: 2)
                    .opacity(progress)
            }
            .frame(width: width)
        }
    }
    
    struct WaterDrop: Shape {
        let size: CGFloat
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            
            let width = rect.width
            let height = rect.height
            
            // Draw teardrop shape
            path.move(to: CGPoint(x: width / 2, y: 0))
            
            path.addQuadCurve(
                to: CGPoint(x: width, y: height * 0.4),
                control: CGPoint(x: width * 1.2, y: height * 0.1)
            )
            
            path.addQuadCurve(
                to: CGPoint(x: width / 2, y: height),
                control: CGPoint(x: width * 0.8, y: height)
            )
            
            path.addQuadCurve(
                to: CGPoint(x: 0, y: height * 0.4),
                control: CGPoint(x: width * 0.2, y: height)
            )
            
            path.addQuadCurve(
                to: CGPoint(x: width / 2, y: 0),
                control: CGPoint(x: -width * 0.2, y: height * 0.1)
            )
            
            return path
        }
    }
    
    // Additional visible snow cluster for more dramatic effect
    struct SnowCluster: View {
        let size: CGFloat
        let nightMode: Bool
        let fallDuration: Double
        
        @State private var yOffset: CGFloat = -200
        @State private var xOffset: CGFloat = 0
        @State private var rotation: Double = 0
        
        var body: some View {
            ZStack {
                // Cluster of 3-5 overlapping snowflakes
                ForEach(0..<5) { i in
                    if i < Int.random(in: 3...5) {
                        Circle()
                            .fill(Color.white.opacity(nightMode ? 0.7 : 0.9))
                            .frame(width: size * CGFloat.random(in: 0.4...0.7), 
                                  height: size * CGFloat.random(in: 0.4...0.7))
                            .offset(
                                x: CGFloat.random(in: -size/3...size/3),
                                y: CGFloat.random(in: -size/3...size/3)
                            )
                            .blur(radius: 0.5)
                    }
                }
                
                // Central larger snowflake
                Image(systemName: "snowflake")
                    .font(.system(size: size * 0.8))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.8), radius: 3, x: 0, y: 0)
            }
            .rotationEffect(.degrees(rotation))
            .offset(x: xOffset, y: yOffset)
            .onAppear {
                // Falling animation - much slower
                withAnimation(Animation.linear(duration: fallDuration).repeatForever(autoreverses: false)) {
                    yOffset = 1000
                }
                
                // Side-to-side drift - more gentle
                withAnimation(Animation.easeInOut(duration: Double.random(in: 8...12)).repeatForever(autoreverses: true)) {
                    xOffset = CGFloat.random(in: -20...20)
                }
                
                // Slow rotation
                withAnimation(Animation.linear(duration: Double.random(in: 15...25)).repeatForever(autoreverses: false)) {
                    rotation = Double.random(in: -360...360)
                }
            }
        }
    }
}

struct WindyOverlay: View {
    var nightMode: Bool = false
    @State private var animationPhase = false
    @State private var leafAnimationPhase = false
    @State private var windIntensity: Double = 1.0
    @State private var windDirection: Double = 0.0
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Cloud movements to show wind in sky
                CloudyWindBackground(
                    nightMode: nightMode, 
                    intensity: windIntensity, 
                    direction: windDirection
                )
                
                // Main wind layers - longer, faster streaks (reduced count and opacity)
                ForEach(0..<8, id: \.self) { i in
                    WindStreak(
                        width: CGFloat.random(in: geo.size.width * 0.6...geo.size.width * 0.9),
                        height: CGFloat.random(in: 4...10),
                        yOffset: CGFloat.random(in: 0...geo.size.height),
                        speed: Double.random(in: 2.5...4.0) / windIntensity, // Even slower wind speed
                        delay: Double(i) * 0.1 * windIntensity,
                        opacity: Double.random(in: 0.2...0.4), // Lower opacity
                        nightMode: nightMode,
                        angle: windDirection
                    )
                }
                
                // Secondary wind layers - thinner, varied streaks (reduced count)
                ForEach(0..<12, id: \.self) { i in
                    WindStreak(
                        width: CGFloat.random(in: geo.size.width * 0.3...geo.size.width * 0.6),
                        height: CGFloat.random(in: 1...3),
                        yOffset: CGFloat.random(in: 0...geo.size.height),
                        speed: Double.random(in: 2.0...3.5) / windIntensity, // Even slower wind speed
                        delay: Double.random(in: 0...1.0) * windIntensity,
                        opacity: Double.random(in: 0.1...0.3), // Lower opacity
                        nightMode: nightMode,
                        angle: windDirection + Double.random(in: -5...5)
                    )
                }
                
                // Blowing particles (dust, leaves, etc) - reduced count
                ForEach(0..<15, id: \.self) { i in
                    if i % 5 == 0 {
                        // Occasional leaf or debris
                        BlowingLeaf(
                            size: CGFloat.random(in: 4...10),
                            nightMode: nightMode
                        )
                        .position(
                            x: leafAnimationPhase ? geo.size.width + 100 : -50,
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                        .animation(
                            Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: Double.random(in: 6.0...14.0) / windIntensity) // Even slower leaf movement
                                .repeatForever(autoreverses: false)
                                .delay(Double.random(in: 0...3)),
                            value: leafAnimationPhase
                        )
                    } else {
                        // Regular dust/small particles
                        Circle()
                            .fill(
                                nightMode ? 
                                Color(red: 0.75, green: 0.75, blue: 0.85).opacity(Double.random(in: 0.05...0.2)) : // Lower opacity
                                Color.white.opacity(Double.random(in: 0.05...0.2)) // Lower opacity
                            )
                            .frame(width: CGFloat.random(in: 1...3), height: CGFloat.random(in: 1...3))
                            .blur(radius: 0.5)
                            .position(
                                x: animationPhase ? geo.size.width + 50 : -50,
                                y: CGFloat.random(in: 0...geo.size.height)
                            )
                            .animation(
                                Animation.timingCurve(0.1, 0.9, 0.2, 1, duration: Double.random(in: 3.5...7.0) / windIntensity) // Even slower particle movement
                                    .repeatForever(autoreverses: false)
                                    .delay(Double.random(in: 0...1.5)),
                                value: animationPhase
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                // Start animation phases
                animationPhase = true
                leafAnimationPhase = true
                
                // Randomize initial wind parameters with more subtle values
                windIntensity = Double.random(in: 0.4...0.8) // Reduced intensity
                windDirection = Double.random(in: -3...3) // Smaller angle variation
                
                // Create varying wind intensity over time
                animateWindChanges()
            }
        }
    }
    
    private func animateWindChanges() {
        // Create natural variations in wind speed and direction
        let duration = Double.random(in: 5...12) // Even longer duration for slower changes
        
        withAnimation(Animation.easeInOut(duration: duration)) {
            windIntensity = Double.random(in: 0.3...0.7) // Reduced intensity range
            windDirection = Double.random(in: -4...4) // Smaller angle variation
        }
        
        // Schedule next change
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            animateWindChanges()
        }
    }
    
    // Enhanced wind streak with angle control
    struct WindStreak: View {
        let width: CGFloat
        let height: CGFloat
        let yOffset: CGFloat
        let speed: Double
        let delay: Double
        let opacity: Double
        let nightMode: Bool
        let angle: Double
        
        @State private var offset: CGFloat = -400
        
        var body: some View {
            Capsule()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            nightMode ? Color(red: 0.8, green: 0.8, blue: 0.9).opacity(opacity) : Color.white.opacity(opacity),
                            nightMode ? Color(red: 0.8, green: 0.8, blue: 0.9).opacity(opacity) : Color.white.opacity(opacity),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: height)
                .rotationEffect(.degrees(angle))
                .offset(x: offset, y: yOffset)
                .onAppear {
                    // Add initial delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        // Continuous movement animation
                        withAnimation(Animation.linear(duration: speed).repeatForever(autoreverses: false)) {
                            offset = 400
                        }
                    }
                }
        }
    }
    
    // Blowing leaf with rotation and path movement
    struct BlowingLeaf: View {
        let size: CGFloat
        let nightMode: Bool
        
        @State private var rotation: Double = 0
        @State private var yOffset: CGFloat = 0
        
        var body: some View {
            // Leaf shape
            Image(systemName: "leaf.fill")
                .font(.system(size: size))
                .foregroundColor(
                    nightMode ?
                        Color(red: 0.6, green: 0.6, blue: 0.7).opacity(0.7) :
                        Color(red: 0.7, green: 0.8, blue: 0.5).opacity(0.8)
                )
                .rotationEffect(.degrees(rotation))
                .offset(y: yOffset)
                .onAppear {
                    // Animate rotation
                    withAnimation(Animation.easeInOut(duration: Double.random(in: 0.6...1.2))
                        .repeatForever(autoreverses: true)) {
                        rotation = Double.random(in: -360...360)
                    }
                    
                    // Animate vertical movement
                    withAnimation(Animation.easeInOut(duration: Double.random(in: 0.5...1.0))
                        .repeatForever(autoreverses: true)) {
                        yOffset = CGFloat.random(in: -20...20)
                    }
                }
        }
    }
    
    // Windy grass that sways with the wind
    struct WindyGrass: View {
        let height: CGFloat
        let width: CGFloat
        let intensity: Double
        let nightMode: Bool
        
        @State private var rotation: Double = 0
        
        var body: some View {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                nightMode ? Color(red: 0.2, green: 0.3, blue: 0.4) : Color(red: 0.3, green: 0.6, blue: 0.2),
                                nightMode ? Color(red: 0.4, green: 0.5, blue: 0.6) : Color(red: 0.4, green: 0.7, blue: 0.3)
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: width, height: height)
                    .cornerRadius(width / 2, corners: [.topLeft, .topRight])
            }
            .rotationEffect(.degrees(rotation), anchor: .bottom)
            .onAppear {
                // Start grass swaying animation based on wind intensity
                withAnimation(Animation.easeInOut(duration: 1.5 / intensity)
                    .repeatForever(autoreverses: true)) {
                    rotation = Double.random(in: 20...35) * intensity
                }
            }
            .onChange(of: intensity) { newIntensity in
                // Update swaying when wind intensity changes
                withAnimation(.spring()) {
                    rotation = Double.random(in: 20...35) * newIntensity
                }
            }
        }
    }
    
    // Palm tree that sways with the wind - redesigned to be more realistic
    struct PalmTree: View {
        let height: CGFloat
        let trunkWidth: CGFloat
        let intensity: Double
        let nightMode: Bool
        
        @State private var frondRotation: Double = 0
        @State private var trunkBend: Double = 0
        
        var body: some View {
            ZStack(alignment: .bottom) {
                // Trunk of the palm tree - more textured with segments
                VStack(spacing: -1) {
                    // Create multiple trunk segments for texture
                    ForEach(0..<8) { i in
                        TrunkSegment(
                            width: trunkWidth + (i < 2 ? 2 : (i > 6 ? -1 : 0)), // Wider at bottom, narrower at top
                            height: height * 0.09,
                            nightMode: nightMode,
                            offset: CGFloat(i % 2 == 0 ? 1 : -1) // Alternating offset for texture
                        )
                    }
                }
                .frame(width: trunkWidth, height: height * 0.7)
                .rotationEffect(.degrees(trunkBend), anchor: .bottom)
                
                // Palm fronds crown at the top in a more fan-like arrangement
                VStack {
                    ZStack {
                        // Lower fronds (drooping more)
                        ForEach(0..<5) { i in
                            ImprovedPalmFrond(
                                length: height * 0.45,
                                width: trunkWidth * 2.2,
                                angle: Double(i) * 72 + frondRotation,
                                droop: 15, // More droop for lower fronds
                                nightMode: nightMode
                            )
                        }
                        
                        // Upper fronds (more upright)
                        ForEach(0..<4) { i in
                            ImprovedPalmFrond(
                                length: height * 0.4,
                                width: trunkWidth * 2.0,
                                angle: Double(i) * 90 + 45 + frondRotation,
                                droop: 5, // Less droop for upper fronds
                                nightMode: nightMode
                            )
                        }
                        
                        // Youngest center fronds (most upright)
                        ForEach(0..<3) { i in
                            ImprovedPalmFrond(
                                length: height * 0.35,
                                width: trunkWidth * 1.5,
                                angle: Double(i) * 120 + 60 + frondRotation,
                                droop: -10, // Negative droop makes them point up
                                nightMode: nightMode
                            )
                        }
                    }
                }
                .offset(y: -height * 0.65)
                .rotationEffect(.degrees(trunkBend), anchor: .bottom)
                
                // Optional: add coconuts
                if height > 150 {
                    ZStack {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(nightMode ? 
                                    Color(red: 0.3, green: 0.25, blue: 0.2) : 
                                    Color(red: 0.4, green: 0.3, blue: 0.2))
                                .frame(width: trunkWidth * 1.2, height: trunkWidth * 1.2)
                                .offset(
                                    x: CGFloat(i - 1) * trunkWidth * 0.8,
                                    y: 0
                                )
                        }
                    }
                    .offset(y: -height * 0.63)
                    .rotationEffect(.degrees(trunkBend), anchor: .bottom)
                }
            }
            .onAppear {
                // Animate palm fronds swaying in wind
                withAnimation(Animation.easeInOut(duration: 2.5 / intensity)
                    .repeatForever(autoreverses: true)) {
                    frondRotation = Double.random(in: 8...15) * intensity
                }
                
                // Animate trunk bending slightly in stronger winds
                withAnimation(Animation.easeInOut(duration: 4.0 / intensity)
                    .repeatForever(autoreverses: true)) {
                    trunkBend = Double.random(in: 3...6) * intensity
                }
            }
            .onChange(of: intensity) { newIntensity in
                // Update movements when wind intensity changes
                withAnimation(.spring()) {
                    frondRotation = Double.random(in: 8...15) * newIntensity
                    trunkBend = Double.random(in: 3...6) * newIntensity
                }
            }
        }
    }
    
    // Trunk segment for texture
    struct TrunkSegment: View {
        let width: CGFloat
        let height: CGFloat
        let nightMode: Bool
        let offset: CGFloat
        
        var body: some View {
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            nightMode ? Color(red: 0.25, green: 0.2, blue: 0.15) : Color(red: 0.45, green: 0.3, blue: 0.15),
                            nightMode ? Color(red: 0.35, green: 0.25, blue: 0.2) : Color(red: 0.55, green: 0.4, blue: 0.25)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: height)
                .offset(x: offset, y: 0)
        }
    }
    
    // Improved palm frond with more realistic shape
    struct ImprovedPalmFrond: View {
        let length: CGFloat
        let width: CGFloat
        let angle: Double
        let droop: Double // Controls how much the frond droops
        let nightMode: Bool
        
        var body: some View {
            ZStack {
                // Main frond shape
                FrondShape(droop: droop)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                nightMode ? Color(red: 0.1, green: 0.2, blue: 0.15) : Color(red: 0.15, green: 0.5, blue: 0.25),
                                nightMode ? Color(red: 0.15, green: 0.25, blue: 0.2) : Color(red: 0.25, green: 0.6, blue: 0.3)
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: width, height: length)
                
                // Frond spine/stem
                Rectangle()
                    .fill(
                        nightMode ? Color(red: 0.2, green: 0.25, blue: 0.2) : Color(red: 0.3, green: 0.4, blue: 0.2)
                    )
                    .frame(width: width * 0.05, height: length)
            }
            .rotationEffect(.degrees(angle), anchor: .bottom)
            .rotationEffect(.degrees(droop), anchor: .bottom) // Apply droop rotation
        }
    }
    
    // Custom shape for more realistic palm frond
    struct FrondShape: Shape {
        let droop: Double
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            
            // Start at the bottom center
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            
            // Define leaflets along the frond
            let numberOfLeaflets = 12
            let stemLength = rect.height
            let maxLeafletWidth = rect.width / 2.2
            
            for i in 0..<numberOfLeaflets {
                let progress = CGFloat(i) / CGFloat(numberOfLeaflets - 1)
                let yPos = rect.maxY - stemLength * progress
                
                // Leaflet width varies along the frond - wider in middle, tapering at ends
                let leafletWidth = maxLeafletWidth * sin(progress * .pi)
                
                // Position varies based on droop - more droop makes the leaflets hang down
                let droopFactor = CGFloat(droop) * 0.01 * progress
                
                // Left leaflet
                let leftX = rect.midX - leafletWidth * (1 + droopFactor)
                path.addLine(to: CGPoint(x: leftX, y: yPos))
                
                // Back to center
                path.addLine(to: CGPoint(x: rect.midX, y: yPos))
                
                // Right leaflet
                let rightX = rect.midX + leafletWidth * (1 - droopFactor)
                path.addLine(to: CGPoint(x: rightX, y: yPos))
                
                // Back to center
                path.addLine(to: CGPoint(x: rect.midX, y: yPos))
            }
            
            // End at the top
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            
            return path
        }
    }
    
    // Background with fast-moving clouds to show wind in the sky
    struct CloudyWindBackground: View {
        let nightMode: Bool
        let intensity: Double
        let direction: Double
        
        @State private var cloudOffset: CGFloat = -500
        
        var body: some View {
            ZStack {
                // Cloud streaks moving across the sky
                ForEach(0..<5, id: \.self) { i in
                    CloudStreak(
                        width: 200 + CGFloat(i * 40),
                        height: 40 + CGFloat(i * 5),
                        yPosition: 50 + CGFloat(i * 60),
                        opacity: 0.15 - Double(i) * 0.02,
                        nightMode: nightMode,
                        speed: 8.0 / (intensity * (1.0 + Double(i) * 0.2)),
                        direction: direction
                    )
                }
            }
        }
    }
    
    // Streaking cloud elements
    struct CloudStreak: View {
        let width: CGFloat
        let height: CGFloat
        let yPosition: CGFloat
        let opacity: Double
        let nightMode: Bool
        let speed: Double
        let direction: Double
        
        @State private var offset: CGFloat = -600
        
        var body: some View {
            ImprovedCloudShape(width: width, height: height)
                .fill(
                    nightMode ?
                        Color(red: 0.7, green: 0.7, blue: 0.8).opacity(opacity) :
                        Color.white.opacity(opacity)
                )
                .offset(x: offset, y: yPosition)
                .rotationEffect(.degrees(direction * 0.5))
                .onAppear {
                    withAnimation(Animation.linear(duration: speed).repeatForever(autoreverses: false)) {
                        offset = 600
                    }
                }
        }
    }
}

// Extension to create rounded corners on specific sides
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// Helper shape for rounded corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// Bright sunny day with enhanced sun rays and heat shimmer
struct SunnyView: View {
    @State private var rotateAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var shimmerOffset: CGFloat = -200
    @State private var glowOpacity: Double = 0.7
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base color gradient - more vibrant
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(#colorLiteral(red: 0.9921568627, green: 0.8470588235, blue: 0.2078431373, alpha: 1)), // Brighter yellow
                        Color(#colorLiteral(red: 0.9764705882, green: 0.6980392157, blue: 0.05882352941, alpha: 1))  // Deeper orange
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(0.5) // Increased opacity for more color
                
                // Sun with rays
                ZStack {
                    // Outer glow - larger and brighter
                    Circle()
                        .fill(Color.yellow.opacity(0.4))
                        .frame(width: 180, height: 180)
                        .scaleEffect(pulseScale)
                        .blur(radius: 25)
                        .opacity(glowOpacity)
                    
                    // Additional middle glow
                    Circle()
                        .fill(Color.yellow.opacity(0.6))
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseScale * 0.95)
                        .blur(radius: 15)
                        .opacity(glowOpacity)
                    
                    // Sun rays (long) - more rays, brighter
                    ForEach(0..<18) { i in
                        Rectangle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [Color.white, Color.yellow]),
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .frame(width: i.isMultiple(of: 3) ? 5 : 3, height: i.isMultiple(of: 3) ? 120 : 100)
                            .offset(y: -90)
                            .rotationEffect(.degrees(Double(i) * 20 + rotateAngle))
                            .opacity(i.isMultiple(of: 3) ? 0.7 : 0.5)
                            .blur(radius: 1)
                    }
                    
                    // Core sun - brighter with better gradient
                    Circle()
                        .fill(RadialGradient(
                            gradient: Gradient(colors: [Color.white, Color.yellow]),
                            center: .center,
                            startRadius: 5,
                            endRadius: 40
                        ))
                        .frame(width: 80, height: 80)
                        .shadow(color: .yellow, radius: 30, x: 0, y: 0)
                        .scaleEffect(pulseScale * 0.9)
                }
                .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.35)
                
                // Heat shimmer effect - more pronounced
                ForEach(0..<5) { i in
                    ShimmerWave(waveWidth: geometry.size.width * 1.5, waveHeight: 25)
                        .fill(Color.white.opacity(0.25 - Double(i) * 0.04))
                        .frame(height: 25)
                        .offset(x: shimmerOffset + CGFloat(i * 80), y: CGFloat(i * 60) + geometry.size.height * 0.6)
                        .blur(radius: 2)
                }
                
                // Light rays from top
                VStack {
                    ForEach(0..<3) { i in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.7),
                                        Color.white.opacity(0)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 80 + CGFloat(i * 60), height: 200)
                            .blur(radius: 20)
                            .opacity(0.3)
                            .offset(x: CGFloat(i * 100) - 150, y: -100)
                    }
                }
            }
            .onAppear {
                // Animate sun rays rotation - slightly faster
                withAnimation(.linear(duration: 100).repeatForever(autoreverses: false)) {
                    rotateAngle = 360
                }
                
                // Animate sun pulse - more dynamic
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    pulseScale = 1.3
                    glowOpacity = 0.9
                }
                
                // Animate heat shimmer - faster movement
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    shimmerOffset = 900
                }
            }
        }
    }
}

// MARK: - Clear Day View
struct ClearDayView: View {
    @State private var heatShimmer: CGFloat = 0 // Heat shimmer animation
    @State private var cloudPosition: CGFloat = -300 // For occasional cloud
    @State private var showCloud: Bool = true // Control cloud visibility
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) { // Explicitly set top alignment
                // Vibrant blue sky gradient - much more saturated to represent clear day
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.5, blue: 0.95),     // Deep blue at top
                        Color(red: 0.3, green: 0.6, blue: 0.95),     // Azure in middle
                        Color(red: 0.6, green: 0.8, blue: 1.0)       // Light sky blue at horizon
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                
                // Subtle light rays
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.1),
                        Color.white.opacity(0)
                    ]),
                    startPoint: UnitPoint(x: 0.65, y: 0.4),
                    endPoint: UnitPoint(x: 0.35, y: 0.7)
                )
                .edgesIgnoringSafeArea(.all)
                
                // Atmospheric haze at horizon - more pronounced warm glow
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0),
                                Color(red: 1.0, green: 0.9, blue: 0.8).opacity(0.15)  // Warm glow
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: geo.size.height * 0.3)
                    .position(x: geo.size.width/2, y: geo.size.height * 0.8)
                
                // Occasional small fluffy cloud - more three-dimensional
                if showCloud {
                    makeSingleCloud(width: geo.size.width, height: geo.size.height)
                        .offset(x: cloudPosition, y: geo.size.height * 0.25)
                        .shadow(color: Color.white.opacity(0.5), radius: 10, x: 0, y: 2)
                }
                
                // Heat shimmer effect - using the existing ShimmerWave struct
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 20)
                    .mask(
                        ShimmerWave(waveWidth: geo.size.width * 1.5, waveHeight: 20)
                            .fill(Color.white)
                            .offset(x: heatShimmer)
                    )
                    .frame(height: 20)
                    .position(x: geo.size.width/2, y: geo.size.height * 0.6)
                    .blur(radius: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                // Animate cloud movement
                withAnimation(Animation.linear(duration: 80).repeatForever(autoreverses: false)) {
                    cloudPosition = geo.size.width + 300
                }
                
                // Animate heat shimmer
                withAnimation(Animation.linear(duration: 10).repeatForever(autoreverses: false)) {
                    heatShimmer = geo.size.width
                }
            }
        }
    }
    
    // Create a single small fluffy cloud that moves across the sky
    private func makeSingleCloud(width: CGFloat, height: CGFloat) -> some View {
        // More realistic 3D cloud with multiple overlapping circles
        ZStack {
            // Base cloud shape
            HStack(spacing: -18) {
                ForEach(0..<4) { i in
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 45 + CGFloat(i * 5), height: 45 + CGFloat(i * 5))
                        .offset(y: i == 1 ? -8 : (i == 2 ? 5 : 0))
                }
            }
            
            // Top cloud details for more dimension
            HStack(spacing: -15) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 30 + CGFloat(i * 6), height: 30 + CGFloat(i * 6))
                        .offset(y: i == 1 ? -12 : -5)
                        .offset(x: CGFloat(i * 15) - 20)
                }
            }
        }
        .frame(width: 150)
        .blur(radius: 2)
    }
}

// MARK: - Clear Morning View
struct ClearMorningView: View {
    @State private var animationAmount: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Dawn sky gradient - enhanced colors
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.85, green: 0.6, blue: 0.5),    // Soft orange/pink at top
                        Color(red: 0.95, green: 0.8, blue: 0.7),    // Light peach in middle
                        Color(red: 0.7, green: 0.8, blue: 0.95)     // Light blue at bottom
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                
                // Atmospheric bands for morning
                VStack(spacing: 0) {
                    ForEach(0..<3) { i in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 1.0, green: 0.8, blue: 0.6).opacity(0.1),
                                        Color(red: 1.0, green: 0.8, blue: 0.6).opacity(0.2),
                                        Color(red: 1.0, green: 0.8, blue: 0.6).opacity(0.1)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 15)
                            .offset(y: CGFloat(i * 30) + 50)
                            .opacity(0.5 + (animationAmount * 0.1))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            // Animate the atmospheric pulsing
            withAnimation(Animation.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                animationAmount = 1.15
            }
        }
    }
}

// MARK: - Clear Evening View
struct ClearEveningView: View {
    @State private var animationAmount: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Sunset sky gradient - enhanced colors
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.2, green: 0.3, blue: 0.5),      // Dark blue at top
                        Color(red: 0.85, green: 0.5, blue: 0.5),     // Pinkish purple in middle
                        Color(red: 1.0, green: 0.65, blue: 0.3)      // Orange near horizon
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                
                // Evening atmospheric bands
                VStack(spacing: 0) {
                    ForEach(0..<3) { i in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 1.0, green: 0.6, blue: 0.4).opacity(0.1),
                                        Color(red: 1.0, green: 0.5, blue: 0.4).opacity(0.2),
                                        Color(red: 1.0, green: 0.6, blue: 0.4).opacity(0.1)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 20)
                            .offset(y: CGFloat(i * 40) + 80)
                            .opacity(0.6 + (animationAmount * 0.1))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            // Animate the atmospheric pulsing
            withAnimation(Animation.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                animationAmount = 1.2
            }
        }
    }
}

// MARK: - Partly Cloudy Morning View
struct PartlyCloudyMorningView: View {
    @State private var rayRotation: Double = 0
    @State private var cloudOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Morning sky gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.8, green: 0.7, blue: 0.6),    // Soft warm color at top
                        Color(red: 0.9, green: 0.8, blue: 0.7),    // Light peach in middle
                        Color(red: 0.7, green: 0.8, blue: 0.9)     // Light blue at bottom
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                
                // Morning ambient light
                SunrayGroup(count: 10, length: 250, width: 2, angle: 270 + rayRotation, spread: 90)
                    .offset(y: 120)
                    .opacity(0.4)
                
                // A few scattered clouds
                Group {
                    // Larger cloud
                    ImprovedCloudShape(width: geo.size.width * 0.6, height: 50)
                        .fill(Color.white.opacity(0.7))
                        .blur(radius: 2)
                        .offset(x: geo.size.width * 0.1 + cloudOffset, y: geo.size.height * 0.2)
                    
                    // Medium cloud
                    ImprovedCloudShape(width: geo.size.width * 0.4, height: 40)
                        .fill(Color.white.opacity(0.8))
                        .blur(radius: 1.5)
                        .offset(x: geo.size.width * 0.6 - cloudOffset * 0.7, y: geo.size.height * 0.4)
                    
                    // Small cloud
                    ImprovedCloudShape(width: geo.size.width * 0.3, height: 30)
                        .fill(Color.white.opacity(0.6))
                        .blur(radius: 2)
                        .offset(x: geo.size.width * -0.1 + cloudOffset * 0.5, y: geo.size.height * 0.3)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                // Animate the cloud movement
                withAnimation(Animation.easeInOut(duration: 20).repeatForever(autoreverses: true)) {
                    cloudOffset = 30
                }
                
                // Animate the light rays
                withAnimation(Animation.linear(duration: 180).repeatForever(autoreverses: false)) {
                    rayRotation = 360
                }
            }
        }
    }
}

// MARK: - Partly Cloudy Evening View
struct PartlyCloudyEveningView: View {
    @State private var rayRotation: Double = 0
    @State private var cloudOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Evening sky gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.3, green: 0.35, blue: 0.5),    // Dark blue at top
                        Color(red: 0.7, green: 0.5, blue: 0.6),     // Purple in middle
                        Color(red: 0.9, green: 0.65, blue: 0.5)     // Orange near horizon
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                
                // Evening ambient light
                SunrayGroup(count: 8, length: 200, width: 2.5, angle: 270 + rayRotation, spread: 90)
                    .offset(y: 120)
                    .opacity(0.3)
                
                // Evening clouds with warm coloring
                Group {
                    // Larger cloud
                    ImprovedCloudShape(width: geo.size.width * 0.6, height: 50)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.9, green: 0.7, blue: 0.6).opacity(0.7),  // Warm color underneath
                                    Color.white.opacity(0.8)                              // White on top
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .blur(radius: 2)
                        .offset(x: geo.size.width * 0.1 + cloudOffset, y: geo.size.height * 0.3)
                    
                    // Medium cloud
                    ImprovedCloudShape(width: geo.size.width * 0.4, height: 40)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.9, green: 0.65, blue: 0.5).opacity(0.6),
                                    Color.white.opacity(0.7)
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .blur(radius: 1.5)
                        .offset(x: geo.size.width * 0.6 - cloudOffset * 0.6, y: geo.size.height * 0.4)
                    
                    // Small cloud
                    ImprovedCloudShape(width: geo.size.width * 0.3, height: 30)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.8, green: 0.6, blue: 0.6).opacity(0.5),
                                    Color.white.opacity(0.6)
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .blur(radius: 2)
                        .offset(x: geo.size.width * -0.1 + cloudOffset * 0.5, y: geo.size.height * 0.2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                // Animate the cloud movement
                withAnimation(Animation.easeInOut(duration: 25).repeatForever(autoreverses: true)) {
                    cloudOffset = 40
                }
                
                // Animate the light rays
                withAnimation(Animation.linear(duration: 200).repeatForever(autoreverses: false)) {
                    rayRotation = 360
                }
            }
        }
    }
}

struct SunrayGroup: View {
    var count: Int = 12
    var length: CGFloat = 200
    var width: CGFloat = 1
    var angle: Double = 0
    var spread: Double = 360
    
    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.8), Color.white.opacity(0)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width, height: length)
                    .offset(y: -length/2)
                    .rotationEffect(.degrees(Double(i) * (spread/Double(count))))
                    .opacity(i.isMultiple(of: 2) ? 0.7 : 0.4)
            }
        }
    }
}

// Rain splash effect at the bottom
struct RainSplashEffect: View {
    let count: Int
    let width: CGFloat
    let nightMode: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                RainSplash(nightMode: nightMode)
                    .frame(width: width / CGFloat(count))
            }
        }
    }
}

// Rain splash layer for positioning multiple splashes
struct RainSplashLayer: View {
    let count: Int
    let bounds: CGSize
    
    var body: some View {
        ForEach(0..<count, id: \.self) { _ in
            RainSplash(nightMode: false)
                .position(
                    x: CGFloat.random(in: 0...bounds.width),
                    y: CGFloat.random(in: 0...bounds.height)
                )
        }
    }
}

// Individual splash animation
struct RainSplash: View {
    let nightMode: Bool
    
    @State private var isVisible = false
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        ZStack {
            // Outer ripple
            Circle()
                .stroke(Color.white.opacity(nightMode ? 0.4 : 0.6), lineWidth: 1)
                .frame(width: 8, height: 8)
                .scaleEffect(isVisible ? scale : 0)
                .opacity(isVisible ? 0.7 : 0)
            
            // Center splash
            Circle()
                .fill(Color.white.opacity(nightMode ? 0.5 : 0.8))
                .frame(width: 3, height: 3)
                .scaleEffect(isVisible ? 1 : 0)
                .opacity(isVisible ? 1 : 0)
        }
        .blur(radius: 0.2)
        .onAppear {
            animateSplash()
        }
    }
    
    private func animateSplash() {
        // Random delay before showing splash
        let delay = Double.random(in: 0...1.5)
        let duration = Double.random(in: 0.3...0.6)
        scale = CGFloat.random(in: 1.8...3.5)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: duration)) {
                isVisible = true
            }
            
            // Fade out after appearing
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                withAnimation(.easeIn(duration: 0.2)) {
                    isVisible = false
                }
                
                // Repeat the animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    animateSplash()
                }
            }
        }
    }
}

// Add ModernFogOverlay struct back
struct ModernFogOverlay: View {
    var nightMode: Bool = false
    @State private var position = -300.0
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) { // Ensure top alignment
                // Multiple fog layers with different opacities and movement speeds
                FogLayer(opacity: 0.15, blur: 12, nightMode: nightMode)
                    .offset(x: position * 0.5, y: 0)
                
                FogLayer(opacity: 0.2, blur: 15, nightMode: nightMode)
                    .offset(x: position * 0.7, y: 30)
                
                FogLayer(opacity: 0.25, blur: 18, nightMode: nightMode)
                    .offset(x: position * 0.9, y: -20)
                
                // Additional subtle foreground layer
                FogLayer(opacity: 0.15, blur: 8, nightMode: nightMode)
                    .offset(x: position * 1.2, y: 15)
                    .scaleEffect(1.2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) // Ensure consistent positioning
            .onAppear {
                withAnimation(Animation.linear(duration: 45).repeatForever(autoreverses: false)) {
                    position = geo.size.width + 300
                }
            }
        }
    }
    
    struct FogLayer: View {
        let opacity: Double
        let blur: CGFloat
        let nightMode: Bool
        
        var body: some View {
            HStack(spacing: -20) {
                ForEach(0..<8) { _ in
                    Circle()
                        .fill(
                            nightMode ? 
                            Color(red: 0.1, green: 0.1, blue: 0.2).opacity(opacity) : 
                            Color.white.opacity(opacity)
                        )
                        .frame(width: 100, height: 100)
                        .blur(radius: blur)
                }
            }
        }
    }
}

// Add CloudLayer struct back for compatibility
struct CloudLayer: View {
    let count: Int
    let sizeRange: ClosedRange<CGFloat>
    let opacityRange: ClosedRange<Double>
    let speedRange: ClosedRange<Double>
    let bounds: CGSize
    let zIndex: Double
    let verticalVariation: Bool
    let nightMode: Bool
    
    init(
        count: Int,
        sizeRange: ClosedRange<CGFloat>,
        opacityRange: ClosedRange<Double>,
        speedRange: ClosedRange<Double>,
        bounds: CGSize,
        zIndex: Double,
        verticalVariation: Bool = false,
        nightMode: Bool = false
    ) {
        self.count = count
        self.sizeRange = sizeRange
        self.opacityRange = opacityRange
        self.speedRange = speedRange
        self.bounds = bounds
        self.zIndex = zIndex
        self.verticalVariation = verticalVariation
        self.nightMode = nightMode
    }
    
    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                EnhancedCloudElement(
                    size: CGFloat.random(in: sizeRange),
                    opacity: Double.random(in: opacityRange),
                    speed: Double.random(in: speedRange),
                    xPosition: CGFloat.random(in: 0...bounds.width),
                    yPosition: CGFloat.random(in: 0...bounds.height / 2),
                    bounds: bounds,
                    verticalVariation: verticalVariation,
                    nightMode: nightMode
                )
                .zIndex(zIndex)
            }
        }
    }
}

// Add EnhancedCloudElement struct back for compatibility
struct EnhancedCloudElement: View {
    let size: CGFloat
    let opacity: Double
    let speed: Double
    let xPosition: CGFloat
    let yPosition: CGFloat
    let bounds: CGSize
    let verticalVariation: Bool
    let nightMode: Bool
    
    @State private var horizontalOffset: CGFloat = 0
    @State private var verticalOffset: CGFloat = 0
    
    var body: some View {
        // Using custom cloud shape for more realistic clouds
        CloudShape()
            .fill(
                nightMode ? 
                Color(red: 0.1, green: 0.1, blue: 0.2).opacity(opacity) : 
                Color.white.opacity(opacity)
            )
            .frame(width: size, height: size * 0.6)
            .offset(x: horizontalOffset, y: yPosition + verticalOffset)
            .blur(radius: nightMode ? 6 : 8)
            .onAppear {
                // Start offscreen to the left
                horizontalOffset = -size - 50
                
                // Animate across the screen slowly
                withAnimation(Animation.linear(duration: speed).repeatForever(autoreverses: false)) {
                    horizontalOffset = bounds.width + size + 50
                }
                
                // Add vertical drift if enabled
                if verticalVariation {
                    withAnimation(
                        Animation
                            .easeInOut(duration: Double.random(in: 8...12))
                            .repeatForever(autoreverses: true)
                    ) {
                        verticalOffset = CGFloat.random(in: -15...15)
                    }
                }
            }
    }
}

// Add CloudShape struct back for compatibility
struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Draw a cloud shape with multiple arcs
        path.move(to: CGPoint(x: width * 0.2, y: height * 0.8))
        path.addArc(center: CGPoint(x: width * 0.3, y: height * 0.6),
                   radius: height * 0.4,
                   startAngle: .degrees(90),
                   endAngle: .degrees(270),
                   clockwise: false)
        path.addArc(center: CGPoint(x: width * 0.5, y: height * 0.4),
                   radius: height * 0.5,
                   startAngle: .degrees(180),
                   endAngle: .degrees(360),
                   clockwise: false)
        path.addArc(center: CGPoint(x: width * 0.7, y: height * 0.5),
                   radius: height * 0.4,
                   startAngle: .degrees(270),
                   endAngle: .degrees(90),
                   clockwise: false)
        path.addArc(center: CGPoint(x: width * 0.8, y: height * 0.7),
                   radius: height * 0.3,
                   startAngle: .degrees(0),
                   endAngle: .degrees(180),
                   clockwise: false)
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Night Sky
struct StarryNightOverlay: View {
    let smallStarCount = 200
    let starCount = 40
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Night sky background
                Color(red: 0.05, green: 0.05, blue: 0.15)
                    .opacity(0.8) // Slightly transparent for a more layered effect
                    .edgesIgnoringSafeArea(.all)
                
                // Distant tiny stars - many small points
                ForEach(0..<smallStarCount, id: \.self) { _ in
                    Circle()
                        .fill(Color.white)
                        .frame(width: CGFloat.random(in: 1...2), height: CGFloat.random(in: 1...2))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                        .opacity(Double.random(in: 0.3...0.6))
                }
                
                // Twinkling stars
                ForEach(0..<starCount, id: \.self) { i in
                    TwinklingStar(size: CGFloat.random(in: 2...4))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                }
                
                // A few shooting stars with different angles
                ShootingStar(angle: -45)
                    .position(x: geo.size.width * 0.7, y: geo.size.height * 0.3)
                
                ShootingStar(delay: 3.0, angle: -35)
                    .position(x: geo.size.width * 0.2, y: geo.size.height * 0.6)
                
                ShootingStar(delay: 5.0, angle: -55)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) // Ensure consistent positioning
        }
    }
    
    struct TwinklingStar: View {
        let size: CGFloat
        @State private var opacity: Double = 0.0
        @State private var scale: CGFloat = 0.5
        
        var body: some View {
            StarShape(size: size)
                .fill(Color.white)
                .frame(width: size, height: size)
                .opacity(opacity)
                .scaleEffect(scale)
                .onAppear {
                    // Random initial delay
                    let delay = Double.random(in: 0...3)
                    
                    // Random animation duration
                    let duration = Double.random(in: 1.5...3.0)
                    
                    // Animate with delay and repeat
                    withAnimation(
                        Animation
                            .easeInOut(duration: duration)
                            .repeatForever(autoreverses: true)
                            .delay(delay)
                    ) {
                        opacity = Double.random(in: 0.5...1.0)
                        scale = CGFloat.random(in: 0.8...1.2)
                    }
                }
        }
    }
    
    struct StarShape: Shape {
        let size: CGFloat
        
        func path(in rect: CGRect) -> Path {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let points = 5
            var path = Path()
            
            for i in 0..<points * 2 {
                let radius = i.isMultiple(of: 2) ? size : size / 2
                let angle = Double(i) * .pi / Double(points)
                let x = center.x + CGFloat(cos(angle)) * radius
                let y = center.y + CGFloat(sin(angle)) * radius
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            path.closeSubpath()
            return path
        }
    }
    
    struct ShootingStar: View {
        let delay: Double
        let angle: Double // Add angle parameter to control direction
        
        @State private var offset: CGSize = .zero
        @State private var opacity: Double = 0.0
        
        init(delay: Double = 0.0, angle: Double = -45) {
            self.delay = delay
            self.angle = angle
        }
        
        var body: some View {
            VStack {
                Capsule()
                    .fill(Color.white)
                    .frame(width: 1, height: 15)
                    .blur(radius: 0.5)
                    .rotationEffect(.degrees(angle)) // Use the angle parameter
                    .offset(offset)
                    .opacity(opacity)
            }
            .onAppear {
                // Initial delay
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    // Repeat the animation
                    animateShootingStar()
                }
            }
        }
        
        private func animateShootingStar() {
            // Reset position
            opacity = 0
            offset = .zero
            
            // Calculate offset direction based on angle
            let radians = angle * .pi / 180
            let xOffset = -100 * cos(radians)
            let yOffset = 100 * sin(radians)
            
            // Animate shooting in the correct direction
            withAnimation(.easeOut(duration: 0.8)) {
                opacity = 1.0
                offset = CGSize(width: xOffset, height: yOffset)
            }
            
            // Schedule next animation with random delay
            let nextDelay = Double.random(in: 4...8)
            DispatchQueue.main.asyncAfter(deadline: .now() + nextDelay) {
                animateShootingStar()
            }
        }
    }
}

// MARK: - Windy Weather View
struct WindyWeatherView: View {
    @State private var windPhase1: CGFloat = 0
    @State private var windPhase2: CGFloat = 0
    @State private var windPhase3: CGFloat = 0
    @State private var leafRotation1: Double = 0
    @State private var leafRotation2: Double = 0
    @State private var leafPosition1: CGPoint = .zero
    @State private var leafPosition2: CGPoint = .zero
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base sky color - light blue
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.6, green: 0.8, blue: 0.95),
                        Color(red: 0.7, green: 0.9, blue: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                
                // Wind streak layers - different speeds and opacities
                Group {
                    // Fast, light winds
                    WindStreakLayer(
                        count: 12,
                        width: geo.size.width,
                        height: geo.size.height,
                        phase: windPhase1,
                        opacity: 0.4,
                        lineWidth: 1.5,
                        speed: 1.2
                    )
                    
                    // Medium winds
                    WindStreakLayer(
                        count: 8,
                        width: geo.size.width,
                        height: geo.size.height,
                        phase: windPhase2,
                        opacity: 0.6,
                        lineWidth: 2.0,
                        speed: 0.9
                    )
                    
                    // Slow, heavy winds
                    WindStreakLayer(
                        count: 5,
                        width: geo.size.width,
                        height: geo.size.height,
                        phase: windPhase3,
                        opacity: 0.7,
                        lineWidth: 2.5,
                        speed: 0.7
                    )
                }
                
                // Blowing leaves for visual interest
                Group {
                    // Leaf 1
                    Image(systemName: "leaf.fill")
                        .foregroundColor(Color.green.opacity(0.7))
                        .font(.system(size: 20))
                        .rotationEffect(.degrees(leafRotation1))
                        .position(
                            x: leafPosition1.x * geo.size.width,
                            y: leafPosition1.y * geo.size.height
                        )
                    
                    // Leaf 2
                    Image(systemName: "leaf.fill")
                        .foregroundColor(Color.green.opacity(0.6))
                        .font(.system(size: 16))
                        .rotationEffect(.degrees(leafRotation2))
                        .position(
                            x: leafPosition2.x * geo.size.width,
                            y: leafPosition2.y * geo.size.height
                        )
                }
            }
            .onAppear {
                // Animate wind streaks continuously
                withAnimation(Animation.linear(duration: 4).repeatForever(autoreverses: false)) {
                    windPhase1 = 2.0
                }
                
                withAnimation(Animation.linear(duration: 6).repeatForever(autoreverses: false)) {
                    windPhase2 = 2.0
                }
                
                withAnimation(Animation.linear(duration: 8).repeatForever(autoreverses: false)) {
                    windPhase3 = 2.0
                }
                
                // Initial leaf positions
                leafPosition1 = CGPoint(x: -0.1, y: 0.4)
                leafPosition2 = CGPoint(x: -0.1, y: 0.6)
                
                // Animate leaves blowing in the wind
                animateLeaves(geo: geo)
            }
        }
    }
    
    // Animate leaves blowing across the screen
    private func animateLeaves(geo: GeometryProxy) {
        // Leaf 1 animation
        withAnimation(Animation.easeInOut(duration: 6)) {
            leafPosition1 = CGPoint(x: 1.1, y: 0.3)
            leafRotation1 = 360 * 3
        }
        
        // Leaf 2 animation (delayed start)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(Animation.easeInOut(duration: 7)) {
                leafPosition2 = CGPoint(x: 1.1, y: 0.7)
                leafRotation2 = 360 * 4
            }
        }
        
        // Reset and repeat animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            // Reset positions without animation
            leafPosition1 = CGPoint(x: -0.1, y: 0.5)
            leafPosition2 = CGPoint(x: -0.1, y: 0.3)
            leafRotation1 = 0
            leafRotation2 = 0
            
            // Restart animation after reset
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateLeaves(geo: geo)
            }
        }
    }
}

// Helper struct for wind streaks
struct WindStreakLayer: View {
    let count: Int
    let width: CGFloat
    let height: CGFloat
    let phase: CGFloat
    let opacity: Double
    let lineWidth: CGFloat
    let speed: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<count, id: \.self) { i in
                Path { path in
                    let yPos = height * CGFloat(i) / CGFloat(count) + height * 0.1
                    
                    // Create wavy patterns with different amplitudes based on index
                    path.move(to: CGPoint(x: -50, y: yPos))
                    
                    // Add points along the path with varying y positions to create wave effect
                    for x in stride(from: 0, to: width + 100, by: 20) {
                        let waveAmplitude = CGFloat(i % 3 + 1) * 5.0
                        let wavePeriod = CGFloat(i % 2 + 1) * 120.0
                        let offsetY = sin((x / wavePeriod + phase) * .pi * 2) * waveAmplitude
                        path.addLine(to: CGPoint(x: x, y: yPos + offsetY))
                    }
                }
                .stroke(
                    Color.white.opacity(opacity),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round,
                        miterLimit: 0,
                        dash: [15, 10], // Dashed line for wind effect
                        dashPhase: CGFloat(i * 5)
                    )
                )
                .blur(radius: lineWidth * 0.8) // Soft blur for ethereal look
                .offset(x: -phase * 100 * speed) // Offset based on phase and speed
            }
        }
    }
}
// MARK: - Shimmer Wave Shape (for heat shimmer effect)
struct ShimmerWave: Shape {
    let waveWidth: CGFloat
    let waveHeight: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = waveWidth
        let height = waveHeight
        
        // Create a wavy pattern for heat shimmer
        path.move(to: CGPoint(x: 0, y: height / 2))
        
        for x in stride(from: 0, through: width, by: 5) {
            let wave = sin((x / width) * .pi * 4) * (height / 4)
            path.addLine(to: CGPoint(x: x, y: height / 2 + wave))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}

// Note: weatherGradient extension is defined in Color+Brand.swift
