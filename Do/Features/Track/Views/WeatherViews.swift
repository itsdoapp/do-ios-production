//
//  WeatherViews.swift
//  Do
//
//  Weather overlay views for Track features
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

// MARK: - Clear Weather Views

struct ClearDayView: View {
    @State private var heatShimmer: CGFloat = 0 // Heat shimmer animation
    @State private var cloudPosition: CGFloat = -300 // For occasional cloud
    @State private var showCloud: Bool = true // Control cloud visibility
    @State private var animationsStarted: Bool = false // Track if animations have started
    
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
                
                // Heat shimmer effect
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
                // Only start animations once to prevent reset
                guard !animationsStarted else { return }
                animationsStarted = true
                
                // Animate cloud movement
                withAnimation(Animation.linear(duration: 80).repeatForever(autoreverses: false)) {
                    cloudPosition = geo.size.width + 300
                }
                
                // Animate heat shimmer
                withAnimation(Animation.linear(duration: 10).repeatForever(autoreverses: false)) {
                    heatShimmer = geo.size.width
                }
            }
            // Use stable ID to preserve view identity and animation state
            .id("clear-day-\(geo.size.width)-\(geo.size.height)")
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

struct SunView: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.yellow.opacity(0.4),
                            Color.orange.opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
            
            // Sun
            Circle()
                .fill(Color.yellow.opacity(0.8))
                .frame(width: 40, height: 40)
            
            // Rays
            ForEach(0..<8) { index in
                Rectangle()
                    .fill(Color.yellow.opacity(0.6))
                    .frame(width: 3, height: 15)
                    .offset(y: -30)
                    .rotationEffect(.degrees(Double(index) * 45 + rotation))
            }
        }
        .onAppear {
            withAnimation(Animation.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Night Views

struct StarsView: View {
    var body: some View {
        StarryNightOverlay()
            // Ensure stars are visible and properly rendered
            .opacity(1.0)
    }
}

struct StarryNightOverlay: View {
    let starCount = 50
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Multiple layers of stars
                StarField(count: starCount / 2, sizeRange: 1...2, opacityRange: 0.3...0.6, twinkleIntensity: 0.3, bounds: geometry.size)
                StarField(count: starCount / 3, sizeRange: 2...3, opacityRange: 0.5...0.8, twinkleIntensity: 0.5, bounds: geometry.size)
                StarField(count: starCount / 5, sizeRange: 3...4, opacityRange: 0.7...1.0, twinkleIntensity: 0.7, bounds: geometry.size)
            }
        }
    }
}

struct StarField: View {
    let count: Int
    let sizeRange: ClosedRange<CGFloat>
    let opacityRange: ClosedRange<Double>
    let twinkleIntensity: Double
    let bounds: CGSize
    
    var body: some View {
        ForEach(0..<count, id: \.self) { _ in
            Star(
                size: CGFloat.random(in: sizeRange),
                position: CGPoint(
                    x: CGFloat.random(in: 0...bounds.width),
                    y: CGFloat.random(in: 0...bounds.height * 0.7)
                ),
                baseOpacity: Double.random(in: opacityRange),
                twinkleIntensity: twinkleIntensity
            )
        }
    }
}

struct Star: View {
    let size: CGFloat
    let position: CGPoint
    let baseOpacity: Double
    let twinkleIntensity: Double
    
    @State private var opacity: Double
    @State private var scale: CGFloat = 1.0
    
    init(size: CGFloat, position: CGPoint, baseOpacity: Double, twinkleIntensity: Double) {
        self.size = size
        self.position = position
        self.baseOpacity = baseOpacity
        self.twinkleIntensity = twinkleIntensity
        self._opacity = State(initialValue: baseOpacity)
    }
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: size, height: size)
            .position(position)
            .opacity(opacity)
            .scaleEffect(scale)
            .blur(radius: 0.2)
            .onAppear {
                startTwinkling()
            }
    }
    
    private func startTwinkling() {
        guard twinkleIntensity > 0 else { return }
        
        let minOpacity = baseOpacity * (1.0 - twinkleIntensity)
        let maxOpacity = baseOpacity * (1.0 + twinkleIntensity)
        let duration = Double.random(in: 1.5...3.5)
        
        withAnimation(Animation.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            opacity = maxOpacity
        }
        
        // Also add subtle scale animation
        withAnimation(Animation.easeInOut(duration: duration * 0.8).repeatForever(autoreverses: true)) {
            scale = 1.1
        }
    }
}

// MARK: - Cloud Views

enum Cloudiness {
    case partial
    case full
}

struct CloudOverlay: View {
    var nightMode: Bool = false
    var cloudiness: Cloudiness = .full
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CloudBase(opacity: nightMode ? 0.2 : 0.3)
                
                if cloudiness == .partial {
                    CloudGroup(count: 2, opacity: nightMode ? 0.3 : 0.5, scale: 0.8, speed: 20)
                } else {
                    CloudGroup(count: 3, opacity: nightMode ? 0.4 : 0.6, scale: 1.0, speed: 25)
                }
            }
        }
    }
}

struct CloudBase: View {
    let opacity: Double
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(opacity),
                Color.white.opacity(opacity * 0.6)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .opacity(0.3)
    }
}

struct CloudGroup: View {
    let count: Int
    let opacity: Double
    let scale: CGFloat
    let speed: Double
    
    @State private var cloudPositions: [(offsetX: CGFloat, offsetY: CGFloat, size: CGFloat)] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<count, id: \.self) { index in
                    if index < cloudPositions.count {
                        Cloud(opacity: opacity, speed: speed)
                            .scaleEffect(cloudPositions[index].size * scale)
                            .offset(x: cloudPositions[index].offsetX * geometry.size.width,
                                    y: cloudPositions[index].offsetY * geometry.size.height)
                    }
                }
            }
            .onAppear {
                cloudPositions = (0..<count).map { index in
                    let section = 1.0 / CGFloat(count)
                    let offsetX = CGFloat(index) * section
                    let offsetY = CGFloat.random(in: -0.2...0.2)
                    let size = CGFloat.random(in: 0.8...1.2)
                    return (offsetX: offsetX, offsetY: offsetY, size: size)
                }
            }
        }
    }
}

struct Cloud: View {
    let opacity: Double
    let speed: Double
    @State private var pulse = false
    
    var body: some View {
        Image(systemName: "cloud.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 80, height: 50)
            .foregroundColor(.white.opacity(opacity))
            .scaleEffect(pulse ? 1.03 : 1.0)
            .animation(
                Animation.easeInOut(duration: speed/10)
                    .repeatForever(autoreverses: true),
                value: pulse
            )
            .onAppear {
                pulse = true
            }
            .blur(radius: 0.5)
    }
}

// MARK: - Rain Views

enum RainIntensity {
    case light
    case medium
    case heavy
}

struct ModernRainOverlay: View {
    let intensity: RainIntensity
    var nightMode: Bool = false
    
    private var dropCount: Int {
        switch intensity {
        case .light: return 30
        case .medium: return 50
        case .heavy: return 80
        }
    }
    
    private var speed: Double {
        switch intensity {
        case .light: return 1.5
        case .medium: return 1.0
        case .heavy: return 0.7
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<dropCount, id: \.self) { index in
                    Raindrop(
                        startX: CGFloat.random(in: 0...geometry.size.width),
                        speed: speed + Double.random(in: -0.2...0.2),
                        delay: Double(index) * 0.02
                    )
                }
            }
        }
    }
}

struct Raindrop: View {
    let startX: CGFloat
    let speed: Double
    let delay: Double
    
    @State private var yPosition: CGFloat = -20
    
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.7))
            .frame(width: 2, height: 15)
            .position(x: startX, y: yPosition)
            .onAppear {
                withAnimation(Animation.linear(duration: speed).delay(delay).repeatForever(autoreverses: false)) {
                    yPosition = UIScreen.main.bounds.height + 20
                }
            }
    }
}

// MARK: - Lightning View

struct LightningView: View {
    @State private var flashOpacity: Double = 0
    @State private var isFlashing = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Lightning bolt
                Image(systemName: "bolt.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 50)
                    .foregroundColor(.white)
                    .opacity(flashOpacity)
                    .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.4)
                    .blur(radius: 2)
                
                // Flash effect
                Rectangle()
                    .fill(Color.white.opacity(flashOpacity * 0.3))
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .onAppear {
                startLightning()
            }
        }
    }
    
    private func startLightning() {
        guard !isFlashing else { return }
        isFlashing = true
        
        flashLightning()
    }
    
    private func flashLightning() {
        // Flash on
        withAnimation(.easeOut(duration: 0.1)) {
            flashOpacity = 1.0
        }
        
        // Flash off quickly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.1)) {
                flashOpacity = 0.0
            }
        }
        
        // Next flash after random delay
        let nextDelay = Double.random(in: 2.0...5.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + nextDelay) {
            flashLightning()
        }
    }
}

// MARK: - Snow Views

struct SnowOverlay: View {
    let smallFlakeCount = 20
    let mediumFlakeCount = 15
    let largeFlakeCount = 10
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                SnowflakeLayer(count: smallFlakeCount, size: 8...12, speed: 15...25, swayFactor: 20, opacity: 0.6, zPos: 20, bounds: geometry.size)
                    .blur(radius: 0.3)
                
                SnowflakeLayer(count: mediumFlakeCount, size: 12...18, speed: 10...20, swayFactor: 30, opacity: 0.8, zPos: 0, bounds: geometry.size)
                
                SnowflakeLayer(count: largeFlakeCount, size: 18...24, speed: 8...15, swayFactor: 40, opacity: 0.7, zPos: -20, bounds: geometry.size)
                    .blur(radius: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

struct SnowfallView: View {
    var nightMode: Bool = false
    
    var body: some View {
        SnowOverlay()
    }
}

struct SnowflakeLayer: View {
    let count: Int
    let size: ClosedRange<CGFloat>
    let speed: ClosedRange<Double>
    let swayFactor: CGFloat
    let opacity: Double
    let zPos: CGFloat
    let bounds: CGSize
    
    var body: some View {
        ForEach(0..<count, id: \.self) { _ in
            EnhancedSnowflake(
                size: CGFloat.random(in: size),
                speed: Double.random(in: speed),
                swayFactor: CGFloat.random(in: swayFactor/2...swayFactor),
                startPosition: CGPoint(
                    x: CGFloat.random(in: 0...bounds.width),
                    y: CGFloat.random(in: -50...0)
                ),
                canvasSize: bounds
            )
            .opacity(opacity)
            .scaleEffect(1.0 - (zPos * 0.01))
        }
    }
}

struct EnhancedSnowflake: View {
    let size: CGFloat
    let speed: Double
    let swayFactor: CGFloat
    let startPosition: CGPoint
    let canvasSize: CGSize
    
    @State private var xPosition: CGFloat = 0
    @State private var yPosition: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1
    
    let snowflakeOptions = ["❄️", "❅", "❆", "✻", "✼"]
    @State private var snowflakeType: String = "❄️"
    
    var body: some View {
        Text(snowflakeType)
            .font(.system(size: size))
            .foregroundColor(.white)
            .position(x: xPosition, y: yPosition)
            .rotationEffect(Angle(degrees: rotation))
            .scaleEffect(scale)
            .shadow(color: .white.opacity(0.5), radius: 2, x: 0, y: 0)
            .onAppear {
                snowflakeType = snowflakeOptions.randomElement() ?? "❄️"
                xPosition = startPosition.x
                yPosition = startPosition.y
                startFallingAnimation()
                startSwayingAnimation()
                startRotatingAnimation()
                startPulsingAnimation()
            }
    }
    
    private func startFallingAnimation() {
        let fallDuration = speed + Double.random(in: 0...3)
        let delay = Double.random(in: 0...3)
        
        withAnimation(Animation.linear(duration: fallDuration).delay(delay).repeatForever(autoreverses: false)) {
            yPosition = canvasSize.height + 50
        }
    }
    
    private func startSwayingAnimation() {
        let startX = xPosition
        let maxWidth = canvasSize.width
        let fallDuration = speed + Double.random(in: 0...3)
        let delay = Double.random(in: 0...1)
        let swayCount = Int.random(in: 3...6)
        
        for i in 0..<swayCount {
            let swayDelay = fallDuration / Double(swayCount) * Double(i)
            let direction = i % 2 == 0 ? 1.0 : -1.0
            let swayDistance = CGFloat.random(in: swayFactor/2...swayFactor) * direction
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + swayDelay) {
                withAnimation(Animation.easeInOut(duration: fallDuration / Double(swayCount))) {
                    xPosition = max(min(startX + swayDistance, maxWidth), 0)
                }
            }
        }
    }
    
    private func startRotatingAnimation() {
        let rotationSpeed = Double.random(in: 2...5)
        let rotationDirection = Bool.random() ? 1.0 : -1.0
        let rotationAmount = 360 * rotationDirection
        
        withAnimation(Animation.linear(duration: rotationSpeed).repeatForever(autoreverses: false)) {
            rotation = rotationAmount
        }
    }
    
    private func startPulsingAnimation() {
        let pulseSpeed = Double.random(in: 1.5...3)
        
        withAnimation(Animation.easeInOut(duration: pulseSpeed).repeatForever(autoreverses: true)) {
            scale = CGFloat.random(in: 0.85...1.15)
        }
    }
}

// MARK: - Fog Views

struct FogOverlay: View {
    let fogLayerCount = 6
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CloudBase(opacity: 0.3)
                
                ForEach(0..<fogLayerCount, id: \.self) { index in
                    FogLayer(
                        density: getFogDensity(for: index),
                        speed: getFogSpeed(for: index),
                        baseOffset: CGFloat(index) * 60,
                        opacity: getFogOpacity(for: index),
                        bounds: geometry.size
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
    
    private func getFogDensity(for index: Int) -> Int {
        let baseDensity = [3, 4, 5, 4, 3, 2]
        return baseDensity[index % baseDensity.count]
    }
    
    private func getFogSpeed(for index: Int) -> Double {
        let baseSpeed = [45.0, 60.0, 50.0, 55.0, 65.0, 70.0]
        return baseSpeed[index % baseSpeed.count]
    }
    
    private func getFogOpacity(for index: Int) -> Double {
        if index == 0 || index == fogLayerCount-1 {
            return 0.15
        } else if index == 1 || index == fogLayerCount-2 {
            return 0.25
        } else {
            return 0.3
        }
    }
}

struct ModernFogOverlay: View {
    var nightMode: Bool = false
    
    var body: some View {
        FogOverlay()
    }
}

struct FogLayer: View {
    let density: Int
    let speed: Double
    let baseOffset: CGFloat
    let opacity: Double
    let bounds: CGSize
    
    @State private var xOffset: CGFloat = -100
    @State private var yOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            ForEach(0..<density, id: \.self) { index in
                FogElement(
                    size: getFogSize(for: index),
                    position: getFogPosition(for: index),
                    opacity: opacity
                )
            }
        }
        .offset(x: xOffset, y: yOffset)
        .onAppear {
            startFogAnimation()
        }
    }
    
    private func getFogSize(for index: Int) -> CGSize {
        let width = CGFloat.random(in: bounds.width * 0.3...bounds.width * 0.5)
        let height = CGFloat.random(in: 30...60)
        return CGSize(width: width, height: height)
    }
    
    private func getFogPosition(for index: Int) -> CGPoint {
        let x = CGFloat.random(in: 0...bounds.width)
        let y = baseOffset + CGFloat.random(in: -20...20)
        return CGPoint(
            x: x,
            y: min(max(20, y), bounds.height - 20)
        )
    }
    
    private func startFogAnimation() {
        let initialDelay = Double.random(in: 0...2.0)
        
        withAnimation(Animation.linear(duration: speed).delay(initialDelay).repeatForever(autoreverses: false)) {
            xOffset = bounds.width + 100
        }
        
        withAnimation(Animation.easeInOut(duration: 10).delay(initialDelay).repeatForever(autoreverses: true)) {
            yOffset = CGFloat.random(in: -15...15)
        }
    }
}

struct FogElement: View {
    let size: CGSize
    let position: CGPoint
    let opacity: Double
    
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(opacity * 1.2),
                        Color.white.opacity(opacity),
                        Color.white.opacity(0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: size.width, height: size.height)
            .position(position)
            .blur(radius: 15)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: Double.random(in: 4...8)).repeatForever(autoreverses: true)) {
                    scale = CGFloat.random(in: 0.9...1.1)
                }
            }
    }
}

// MARK: - Wind Views

struct WindyOverlay: View {
    var nightMode: Bool = false
    
    var body: some View {
        WindyWeatherView()
    }
}

struct WindyWeatherView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Wind lines
                ForEach(0..<15, id: \.self) { index in
                    WindLine(
                        startX: CGFloat.random(in: 0...geometry.size.width),
                        startY: CGFloat.random(in: 0...geometry.size.height),
                        length: CGFloat.random(in: 30...60),
                        speed: Double.random(in: 2...4),
                        delay: Double(index) * 0.1
                    )
                }
            }
        }
    }
}

struct WindLine: View {
    let startX: CGFloat
    let startY: CGFloat
    let length: CGFloat
    let speed: Double
    let delay: Double
    
    @State private var xOffset: CGFloat = 0
    @State private var opacity: Double = 0.6
    
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: startX + xOffset, y: startY))
            path.addLine(to: CGPoint(x: startX + xOffset + length, y: startY))
        }
        .stroke(Color.white.opacity(opacity), lineWidth: 2)
        .onAppear {
            startWindAnimation()
        }
    }
    
    private func startWindAnimation() {
        withAnimation(Animation.linear(duration: speed).delay(delay).repeatForever(autoreverses: false)) {
            xOffset = UIScreen.main.bounds.width + length
        }
        
        withAnimation(Animation.easeInOut(duration: speed * 0.5).delay(delay).repeatForever(autoreverses: true)) {
            opacity = 0.3
        }
    }
}

// MARK: - Partly Cloudy Views

struct PartlyCloudyDayView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Clear blue sky background (like clear day)
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
                
                // Modern moving clouds - more substantial for daytime
                ZStack {
                    // Subtle atmospheric base
                    CloudBase(opacity: 0.2)
                    
                    // Main cloud layer - moving left to right with fluffy clouds
                    MovingDayCloudGroup(
                        count: 2,
                        opacity: 0.5,
                        scale: 0.9,
                        speed: 28.0,
                        startY: geometry.size.height * 0.25
                    )
                    
                    // Additional cloud for depth
                    MovingDayCloudGroup(
                        count: 1,
                        opacity: 0.4,
                        scale: 0.7,
                        speed: 32.0,
                        startY: geometry.size.height * 0.45
                    )
                }
                .blendMode(.normal)
            }
        }
    }
}

// Daytime cloud group with more substantial, fluffy clouds
struct MovingDayCloudGroup: View {
    let count: Int
    let opacity: Double
    let scale: CGFloat
    let speed: Double
    let startY: CGFloat
    
    @State private var cloudPositions: [(startX: CGFloat, y: CGFloat, size: CGFloat, delay: Double)] = []
    @State private var xOffsets: [CGFloat] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<count, id: \.self) { index in
                    if index < cloudPositions.count && index < xOffsets.count {
                        FluffyDayCloud(opacity: opacity, size: cloudPositions[index].size * scale)
                            .offset(
                                x: cloudPositions[index].startX + xOffsets[index],
                                y: cloudPositions[index].y
                            )
                            .onAppear {
                                startMoving(index: index, width: geometry.size.width)
                            }
                    }
                }
            }
            .onAppear {
                initializeClouds(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
    
    private func initializeClouds(width: CGFloat, height: CGFloat) {
        cloudPositions = (0..<count).map { index in
            let startX = CGFloat.random(in: -150...0) // Start off-screen left
            let y = startY + CGFloat.random(in: -40...40)
            let size = CGFloat.random(in: 0.8...1.2)
            let delay = Double(index) * 3.0 // Stagger the clouds
            return (startX: startX, y: y, size: size, delay: delay)
        }
        xOffsets = Array(repeating: 0, count: count)
    }
    
    private func startMoving(index: Int, width: CGFloat) {
        guard index < cloudPositions.count else { return }
        
        let delay = cloudPositions[index].delay
        let travelDistance = width + 300 // Move completely across and off-screen
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(
                Animation.linear(duration: speed)
                    .repeatForever(autoreverses: false)
            ) {
                xOffsets[index] = travelDistance
            }
        }
    }
}

// Organic, smokey cloud design - like real clouds with no defined shape
struct FluffyDayCloud: View {
    let opacity: Double
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Main cloud blob - irregular, organic shape
            CloudBlob(
                width: 140 * size,
                height: 80 * size,
                opacity: opacity * 0.8,
                blur: 12
            )
            .offset(x: -20 * size, y: 0)
            
            // Secondary blob - overlapping for depth
            CloudBlob(
                width: 100 * size,
                height: 60 * size,
                opacity: opacity * 0.7,
                blur: 10
            )
            .offset(x: 30 * size, y: -15)
            
            // Tertiary blob - smaller wisps
            CloudBlob(
                width: 70 * size,
                height: 45 * size,
                opacity: opacity * 0.6,
                blur: 8
            )
            .offset(x: -40 * size, y: 20)
            
            // Additional wispy blob
            CloudBlob(
                width: 60 * size,
                height: 40 * size,
                opacity: opacity * 0.5,
                blur: 7
            )
            .offset(x: 50 * size, y: 25)
            
            // Top wisp
            CloudBlob(
                width: 50 * size,
                height: 35 * size,
                opacity: opacity * 0.4,
                blur: 6
            )
            .offset(x: 0, y: -30)
        }
        .blur(radius: 3)
    }
}

// Organic cloud blob with irregular, smokey shape
struct CloudBlob: View {
    let width: CGFloat
    let height: CGFloat
    let opacity: Double
    let blur: CGFloat
    
    var body: some View {
        // Create an irregular blob shape using multiple overlapping ellipses
        ZStack {
            // Main blob body - irregular ellipse
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(opacity),
                            Color.white.opacity(opacity * 0.7),
                            Color.white.opacity(opacity * 0.4),
                            Color.white.opacity(opacity * 0.1),
                            Color.white.opacity(0)
                        ],
                        center: UnitPoint(x: 0.5, y: 0.4),
                        startRadius: 0,
                        endRadius: max(width, height) * 0.6
                    )
                )
                .frame(width: width, height: height)
            
            // Additional irregular shapes for organic look
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(opacity * 0.6),
                            Color.white.opacity(opacity * 0.3),
                            Color.white.opacity(0)
                        ],
                        center: UnitPoint(x: 0.3, y: 0.5),
                        startRadius: 0,
                        endRadius: width * 0.4
                    )
                )
                .frame(width: width * 0.7, height: height * 0.8)
                .offset(x: -width * 0.15, y: height * 0.1)
            
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(opacity * 0.5),
                            Color.white.opacity(opacity * 0.2),
                            Color.white.opacity(0)
                        ],
                        center: UnitPoint(x: 0.7, y: 0.6),
                        startRadius: 0,
                        endRadius: width * 0.35
                    )
                )
                .frame(width: width * 0.6, height: height * 0.7)
                .offset(x: width * 0.2, y: height * 0.15)
            
            // Top wisp
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(opacity * 0.4),
                            Color.white.opacity(0)
                        ],
                        center: UnitPoint(x: 0.5, y: 0.2),
                        startRadius: 0,
                        endRadius: width * 0.3
                    )
                )
                .frame(width: width * 0.5, height: height * 0.4)
                .offset(x: 0, y: -height * 0.3)
        }
        .blur(radius: blur)
    }
}

struct PartlyCloudyNightView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Stars in the background (like clear night) - full starry sky
                StarryNightOverlay()
                
                // Sleek modern clouds moving left to right
                ZStack {
                    // Subtle atmospheric base
                    CloudBase(opacity: 0.1)
                    
                    // Modern moving clouds - sleek and smooth
                    MovingCloudGroup(
                        count: 2,
                        opacity: 0.3,
                        scale: 0.7,
                        speed: 25.0,
                        startY: geometry.size.height * 0.2
                    )
                    
                    // Additional cloud for depth
                    MovingCloudGroup(
                        count: 1,
                        opacity: 0.2,
                        scale: 0.5,
                        speed: 30.0,
                        startY: geometry.size.height * 0.4
                    )
                }
                .blendMode(.normal)
            }
        }
    }
}

// Modern cloud group with smooth left-to-right movement
struct MovingCloudGroup: View {
    let count: Int
    let opacity: Double
    let scale: CGFloat
    let speed: Double
    let startY: CGFloat
    
    @State private var cloudPositions: [(startX: CGFloat, y: CGFloat, size: CGFloat, delay: Double)] = []
    @State private var xOffsets: [CGFloat] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<count, id: \.self) { index in
                    if index < cloudPositions.count && index < xOffsets.count {
                        SmokeyCloud(opacity: opacity, size: cloudPositions[index].size * scale)
                            .offset(
                                x: cloudPositions[index].startX + xOffsets[index],
                                y: cloudPositions[index].y
                            )
                            .onAppear {
                                startMoving(index: index, width: geometry.size.width)
                            }
                    }
                }
            }
            .onAppear {
                initializeClouds(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
    
    private func initializeClouds(width: CGFloat, height: CGFloat) {
        cloudPositions = (0..<count).map { index in
            let startX = CGFloat.random(in: -150...0) // Start off-screen left
            let y = startY + CGFloat.random(in: -40...40)
            let size = CGFloat.random(in: 0.8...1.3)
            let delay = Double(index) * 3.0 // Stagger the clouds more
            return (startX: startX, y: y, size: size, delay: delay)
        }
        xOffsets = Array(repeating: 0, count: count)
    }
    
    private func startMoving(index: Int, width: CGFloat) {
        guard index < cloudPositions.count else { return }
        
        let delay = cloudPositions[index].delay
        let travelDistance = width + 300 // Move completely across and off-screen
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(
                Animation.linear(duration: speed)
                    .repeatForever(autoreverses: false)
            ) {
                xOffsets[index] = travelDistance
            }
        }
    }
}

// Organic, smokey night cloud design - like real clouds with no defined shape
struct SmokeyCloud: View {
    let opacity: Double
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Main cloud blob - irregular, organic shape (more subtle at night)
            CloudBlob(
                width: 120 * size,
                height: 70 * size,
                opacity: opacity * 0.5,
                blur: 10
            )
            .offset(x: -15 * size, y: 0)
            
            // Secondary blob - overlapping for depth
            CloudBlob(
                width: 85 * size,
                height: 50 * size,
                opacity: opacity * 0.4,
                blur: 8
            )
            .offset(x: 25 * size, y: -12)
            
            // Wispy trailing blob
            CloudBlob(
                width: 60 * size,
                height: 35 * size,
                opacity: opacity * 0.3,
                blur: 7
            )
            .offset(x: 40 * size, y: 15)
            
            // Additional wisp
            CloudBlob(
                width: 50 * size,
                height: 30 * size,
                opacity: opacity * 0.25,
                blur: 6
            )
            .offset(x: -30 * size, y: -20)
        }
        .blur(radius: 2.5)
    }
}

// Wispy trail component for smokey effect
struct SmokeyTrail: View {
    let width: CGFloat
    let height: CGFloat
    let opacity: Double
    let blur: CGFloat
    
    var body: some View {
        // Create a wispy, flowing trail using a gradient ellipse
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(opacity * 0.4),
                        Color.white.opacity(opacity * 0.6),
                        Color.white.opacity(opacity * 0.4),
                        Color.white.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
            .blur(radius: blur)
            .overlay(
                // Add subtle inner glow
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(opacity * 0.3),
                                Color.white.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: width * 0.3
                        )
                    )
                    .frame(width: width * 0.6, height: height * 1.5)
                    .blur(radius: blur * 0.5)
            )
    }
}

struct PartlyCloudyMorningView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Sunrise gradient
                LinearGradient(
                    colors: [
                        Color.orange.opacity(0.3),
                        Color.yellow.opacity(0.2),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Sun near horizon
                SunView()
                    .frame(width: min(geometry.size.width, geometry.size.height) * 0.35,
                           height: min(geometry.size.width, geometry.size.height) * 0.35)
                    .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.7)
                
                // Partial clouds
                CloudOverlay(nightMode: false, cloudiness: .partial)
            }
        }
    }
}

struct PartlyCloudyEveningView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Sunset gradient
                LinearGradient(
                    colors: [
                        Color.pink.opacity(0.3),
                        Color.orange.opacity(0.2),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Sun setting
                SunView()
                    .frame(width: min(geometry.size.width, geometry.size.height) * 0.35,
                           height: min(geometry.size.width, geometry.size.height) * 0.35)
                    .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.7)
                
                // Partial clouds
                CloudOverlay(nightMode: false, cloudiness: .partial)
            }
        }
    }
}

struct SunRaysView: View {
    let showSun: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if showSun {
                    // Sun with rays
                    SunView()
                        .frame(width: min(geometry.size.width, geometry.size.height) * 0.4,
                               height: min(geometry.size.width, geometry.size.height) * 0.4)
                        .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.3)
                } else {
                    // Just rays without the sun circle
                    ForEach(0..<8) { index in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.yellow.opacity(0.4),
                                        Color.yellow.opacity(0.0)
                                    ],
                                    startPoint: .center,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 3, height: 30)
                            .offset(y: -40)
                            .rotationEffect(.degrees(Double(index) * 45))
                            .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.3)
                    }
                }
            }
        }
    }
}

// MARK: - Storm View

struct StormOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark clouds
                CloudOverlay(nightMode: true, cloudiness: .full)
                
                // Lightning
                LightningView()
                
                // Heavy rain
                ModernRainOverlay(intensity: .heavy, nightMode: true)
            }
        }
    }
}

// MARK: - ShimmerWave Shape for Heat Shimmer Effect

struct ShimmerWave: Shape {
    let waveWidth: CGFloat
    let waveHeight: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerY = rect.midY
        
        // Create a wavy pattern
        path.move(to: CGPoint(x: 0, y: centerY))
        
        let points = 20
        for i in 0...points {
            let x = CGFloat(i) * (rect.width / CGFloat(points))
            let waveAmplitude = waveHeight * 0.5
            let wavePeriod = rect.width / 2
            let y = centerY + sin((x / wavePeriod) * .pi * 2) * waveAmplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
    }
}
