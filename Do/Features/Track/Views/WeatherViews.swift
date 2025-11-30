//
//  WeatherViews.swift
//  Do.
//
//  Shared weather animation views for all Modern tracker view controllers
//

import SwiftUI

// MARK: - Clear Sky Views

struct ClearDayView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Bright sun
                SunView()
                    .frame(width: geometry.size.width * 0.4, height: geometry.size.width * 0.4)
                    .position(x: geometry.size.width * 0.7, y: geometry.size.height * 0.2)
                
                // Sun rays
                SunRaysView(showSun: true)
            }
        }
    }
}

struct ClearMorningView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Lower, warmer sun for morning
                SunView(color: Color.orange.opacity(0.8))
                    .frame(width: geometry.size.width * 0.3, height: geometry.size.width * 0.3)
                    .position(x: geometry.size.width * 0.2, y: geometry.size.height * 0.3)
                
                // Warm morning rays
                SunRaysView(showSun: true, color: Color.orange.opacity(0.3))
            }
        }
    }
}

struct ClearEveningView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Lower, warmer sun for evening
                SunView(color: Color.orange.opacity(0.7))
                    .frame(width: geometry.size.width * 0.35, height: geometry.size.width * 0.35)
                    .position(x: geometry.size.width * 0.8, y: geometry.size.height * 0.35)
                
                // Warm evening rays
                SunRaysView(showSun: true, color: Color.orange.opacity(0.25))
            }
        }
    }
}

struct SunView: View {
    let color: Color
    
    init(color: Color = Color.yellow) {
        self.color = color
    }
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        color.opacity(0.9),
                        color.opacity(0.6),
                        color.opacity(0.3)
                    ]),
                    center: .center,
                    startRadius: 5,
                    endRadius: 50
                )
            )
            .shadow(color: color.opacity(0.5), radius: 20)
    }
}

struct SunRaysView: View {
    let showSun: Bool
    let color: Color
    
    init(showSun: Bool = false, color: Color = Color.yellow.opacity(0.3)) {
        self.showSun = showSun
        self.color = color
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if showSun {
                    // Radiating sun rays
                    ForEach(0..<8, id: \.self) { index in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        color,
                                        color.opacity(0)
                                    ]),
                                    startPoint: .center,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 2, height: geometry.size.height * 0.3)
                            .rotationEffect(.degrees(Double(index) * 45))
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                }
            }
        }
    }
}

// MARK: - Night Sky Views

struct StarsView: View {
    let starCount = 50
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                StarField(
                    count: starCount,
                    sizeRange: 1...3,
                    opacityRange: 0.3...0.9,
                    twinkleIntensity: 0.5,
                    bounds: geometry.size
                )
            }
        }
    }
}

struct StarryNightOverlay: View {
    var body: some View {
        ZStack {
            StarsView()
        }
    }
}

// MARK: - Cloud Views

enum Cloudiness {
    case full
    case partial
}

struct CloudOverlay: View {
    let nightMode: Bool
    let cloudiness: Cloudiness?
    
    init(nightMode: Bool = false, cloudiness: Cloudiness? = nil) {
        self.nightMode = nightMode
        self.cloudiness = cloudiness
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Cloud base
                CloudBase(opacity: cloudiness == .partial ? 0.2 : 0.4)
                
                // Cloud layers
                let cloudCount = cloudiness == .partial ? 3 : 5
                CloudGroup(
                    count: cloudCount,
                    opacity: nightMode ? 0.3 : 0.6,
                    scale: 1.0,
                    speed: 20.0
                )
            }
        }
    }
}
//
//struct CloudBase: View {
//    let opacity: Double
//    
//    var body: some View {
//        LinearGradient(
//            gradient: Gradient(colors: [
//                Color.white.opacity(opacity),
//                Color.white.opacity(opacity * 0.6)
//            ]),
//            startPoint: .top,
//            endPoint: .bottom
//        )
//        .opacity(0.3)
//    }
//}
//
//struct CloudGroup: View {
//    let count: Int
//    let opacity: Double
//    let scale: CGFloat
//    let speed: Double
//    
//    @State private var cloudPositions: [(offsetX: CGFloat, offsetY: CGFloat, size: CGFloat)] = []
//    
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack {
//                ForEach(0..<count, id: \.self) { index in
//                    if index < cloudPositions.count {
//                        Cloud(opacity: opacity, speed: speed)
//                            .scaleEffect(cloudPositions[index].size * scale)
//                            .offset(x: cloudPositions[index].offsetX * geometry.size.width,
//                                    y: cloudPositions[index].offsetY * geometry.size.height)
//                    }
//                }
//            }
//            .onAppear {
//                cloudPositions = (0..<count).map { index in
//                    let section = 1.0 / CGFloat(count)
//                    let offsetX = CGFloat(index) * section
//                    let offsetY = CGFloat.random(in: -0.2...0.2)
//                    let size = CGFloat.random(in: 0.8...1.2)
//                    return (offsetX: offsetX, offsetY: offsetY, size: size)
//                }
//            }
//        }
//    }
//}
//
//struct Cloud: View {
//    let opacity: Double
//    let speed: Double
//    @State private var pulse = false
//    
//    var body: some View {
//        Image(systemName: "cloud.fill")
//            .resizable()
//            .aspectRatio(contentMode: .fit)
//            .frame(width: 80, height: 50)
//            .foregroundColor(.white.opacity(opacity))
//            .scaleEffect(pulse ? 1.03 : 1.0)
//            .animation(
//                Animation.easeInOut(duration: speed/10)
//                    .repeatForever(autoreverses: true),
//                value: pulse
//            )
//            .onAppear {
//                pulse = true
//            }
//            .blur(radius: 0.5)
//    }
//}

// MARK: - Partly Cloudy Views

struct PartlyCloudyMorningView: View {
    var body: some View {
        ZStack {
            ClearMorningView()
            CloudOverlay(cloudiness: .partial)
        }
    }
}

struct PartlyCloudyEveningView: View {
    var body: some View {
        ZStack {
            ClearEveningView()
            CloudOverlay(cloudiness: .partial)
        }
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
    let nightMode: Bool
    
    var body: some View {
        RainOverlay()
            .colorMultiply(nightMode ? Color(red: 0.3, green: 0.3, blue: 0.4) : Color.white)
    }
}
//
//struct RainOverlay: View {
//    let lightRainCount = 30
//    let mediumRainCount = 20
//    let heavyRainCount = 10
//    
//    @State private var backgroundOpacity = 0.0
//    
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack {
//                Color.gray.opacity(0.05)
//                    .opacity(backgroundOpacity)
//                    .onAppear {
//                        withAnimation(.easeIn(duration: 1.0)) {
//                            backgroundOpacity = 1.0
//                        }
//                    }
//                
//                RainStreakLayer(
//                    count: lightRainCount,
//                    lengthRange: 10...30,
//                    widthRange: 0.5...1.0,
//                    opacityRange: 0.1...0.25,
//                    speedRange: 0.15...0.3,
//                    color: Color(red: 0.7, green: 0.7, blue: 0.8),
//                    bounds: geometry.size
//                )
//                
//                RainStreakLayer(
//                    count: mediumRainCount,
//                    lengthRange: 20...50,
//                    widthRange: 1.0...1.5,
//                    opacityRange: 0.2...0.4,
//                    speedRange: 0.25...0.4,
//                    color: Color(red: 0.6, green: 0.6, blue: 0.75),
//                    bounds: geometry.size
//                )
//                
//                RainStreakLayer(
//                    count: heavyRainCount,
//                    lengthRange: 40...100,
//                    widthRange: 1.5...2.5,
//                    opacityRange: 0.3...0.6,
//                    speedRange: 0.4...0.7,
//                    color: Color(red: 0.5, green: 0.5, blue: 0.7),
//                    bounds: geometry.size
//                )
//                
//                RainSplashLayer(count: 8, bounds: geometry.size)
//            }
//            .clipShape(RoundedRectangle(cornerRadius: 20))
//        }
//    }
//}
//
//struct RainStreakLayer: View {
//    let count: Int
//    let lengthRange: ClosedRange<CGFloat>
//    let widthRange: ClosedRange<CGFloat>
//    let opacityRange: ClosedRange<Double>
//    let speedRange: ClosedRange<Double>
//    let color: Color
//    let bounds: CGSize
//    
//    var body: some View {
//        ForEach(0..<count, id: \.self) { _ in
//            RainStreak(
//                length: CGFloat.random(in: lengthRange),
//                width: CGFloat.random(in: widthRange),
//                opacity: Double.random(in: opacityRange),
//                speed: Double.random(in: speedRange),
//                startPosition: CGPoint(
//                    x: CGFloat.random(in: 0...bounds.width),
//                    y: CGFloat.random(in: -50...0)
//                ),
//                screenHeight: bounds.height,
//                color: color
//            )
//        }
//    }
//}
//
//struct RainStreak: View {
//    let length: CGFloat
//    let width: CGFloat
//    let opacity: Double
//    let speed: Double
//    let startPosition: CGPoint
//    let screenHeight: CGFloat
//    let color: Color
//    
//    @State private var yOffset: CGFloat = 0
//    
//    var body: some View {
//        LinearGradient(
//            gradient: Gradient(colors: [
//                color.opacity(opacity * 0.7),
//                color.opacity(opacity)
//            ]),
//            startPoint: .top,
//            endPoint: .bottom
//        )
//        .frame(width: width, height: length)
//        .blur(radius: 0.3)
//        .position(x: startPosition.x, y: startPosition.y + yOffset)
//        .onAppear {
//            startRainAnimation()
//        }
//    }
//    
//    private func startRainAnimation() {
//        let initialDelay = Double.random(in: 0...0.5)
//        DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) {
//            withAnimation(Animation.linear(duration: 1.0 / speed).repeatForever(autoreverses: false)) {
//                yOffset = screenHeight + length + 50
//            }
//        }
//    }
//}
//
//struct RainSplashLayer: View {
//    let count: Int
//    let bounds: CGSize
//    
//    var body: some View {
//        ForEach(0..<count, id: \.self) { _ in
//            RainSplash(nightMode: false)
//                .position(
//                    x: CGFloat.random(in: 0...bounds.width),
//                    y: CGFloat.random(in: 0...bounds.height)
//                )
//        }
//    }
//}
//
//struct RainSplash: View {
//    let nightMode: Bool
//    
//    var body: some View {
//        Circle()
//            .fill(Color.white.opacity(0.3))
//            .frame(width: 4, height: 4)
//            .blur(radius: 2)
//    }
//}
//
//// MARK: - Storm Views
//
//struct StormOverlay: View {
//    @State private var isLightning = false
//    @State private var lightningOpacity: Double = 0
//    @State private var lightningPosition: CGPoint = .zero
//    @State private var showBolt: Bool = false
//    
//    let stormRainCount = 100
//    
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack {
//                CloudOverlay()
//                    .colorMultiply(Color(red: 0.2, green: 0.2, blue: 0.3))
//                    .blur(radius: 1)
//                
//                RainOverlay()
//                
//                ZStack {
//                    Rectangle()
//                        .fill(Color.white)
//                        .opacity(lightningOpacity)
//                        .blendMode(.plusLighter)
//                    
//                    if showBolt {
//                        LightningBolt()
//                            .stroke(Color.white, lineWidth: 3)
//                            .frame(width: 80, height: 150)
//                            .shadow(color: .white, radius: 12, x: 0, y: 0)
//                            .position(lightningPosition)
//                            .opacity(isLightning ? 1 : 0)
//                            .transition(.opacity)
//                            .blendMode(.plusLighter)
//                    }
//                }
//                
//                RainStreakLayer(
//                    count: stormRainCount,
//                    lengthRange: 40...100,
//                    widthRange: 1.5...3.0,
//                    opacityRange: 0.3...0.6,
//                    speedRange: 0.4...0.7,
//                    color: Color(red: 0.5, green: 0.5, blue: 0.7),
//                    bounds: geometry.size
//                )
//                .blendMode(.plusLighter)
//            }
//            .clipShape(RoundedRectangle(cornerRadius: 20))
//            .onAppear {
//                startLightningSequence(in: geometry)
//            }
//        }
//    }
//    
//    private func startLightningSequence(in geometry: GeometryProxy) {
//        let nextStrike = Double.random(in: 2.0...6.0)
//        
//        DispatchQueue.main.asyncAfter(deadline: .now() + nextStrike) {
//            lightningPosition = CGPoint(
//                x: CGFloat.random(in: 50...geometry.size.width-50),
//                y: CGFloat.random(in: 50...200)
//            )
//            
//            let isBoltStrike = Bool.random()
//            showBolt = isBoltStrike
//            
//            withAnimation(.easeIn(duration: 0.1)) {
//                lightningOpacity = Double.random(in: 0.2...0.5)
//                isLightning = true
//            }
//            
//            let flickerCount = Int.random(in: 1...3)
//            var cumulativeDelay = 0.1
//            
//            for _ in 0..<flickerCount {
//                cumulativeDelay += Double.random(in: 0.05...0.2)
//                
//                DispatchQueue.main.asyncAfter(deadline: .now() + cumulativeDelay) {
//                    withAnimation(.easeInOut(duration: 0.1)) {
//                        lightningOpacity = Double.random(in: 0.05...0.2)
//                    }
//                }
//                
//                cumulativeDelay += 0.1
//                
//                DispatchQueue.main.asyncAfter(deadline: .now() + cumulativeDelay) {
//                    withAnimation(.easeInOut(duration: 0.1)) {
//                        lightningOpacity = Double.random(in: 0.2...0.5)
//                    }
//                }
//            }
//            
//            DispatchQueue.main.asyncAfter(deadline: .now() + cumulativeDelay + 0.2) {
//                withAnimation(.easeOut(duration: 0.3)) {
//                    lightningOpacity = 0
//                    isLightning = false
//                }
//                
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                    showBolt = false
//                    startLightningSequence(in: geometry)
//                }
//            }
//        }
//    }
//}
//
//struct LightningBolt: Shape {
//    func path(in rect: CGRect) -> Path {
//        var path = Path()
//        let width = rect.width
//        let height = rect.height
//        
//        path.move(to: CGPoint(x: width/2, y: 0))
//        path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.2))
//        path.addLine(to: CGPoint(x: width * 0.65, y: height * 0.35))
//        path.addLine(to: CGPoint(x: width * 0.3, y: height * 0.55))
//        path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.75))
//        path.addLine(to: CGPoint(x: width * 0.2, y: height))
//        
//        path.move(to: CGPoint(x: width * 0.4, y: height * 0.2))
//        path.addLine(to: CGPoint(x: width * 0.2, y: height * 0.3))
//        
//        path.move(to: CGPoint(x: width * 0.65, y: height * 0.35))
//        path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.45))
//        
//        return path
//    }
//}

struct LightningView: View {
    var body: some View {
        StormOverlay()
    }
}

// MARK: - Snow Views

struct SnowfallView: View {
    let nightMode: Bool
    
    var body: some View {
        SnowOverlay()
            .colorMultiply(nightMode ? Color(red: 0.4, green: 0.4, blue: 0.5) : Color.white)
    }
}
//
//struct SnowOverlay: View {
//    let smallFlakeCount = 20
//    let mediumFlakeCount = 15
//    let largeFlakeCount = 10
//    
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack {
//                SnowflakeLayer(count: smallFlakeCount, size: 8...12, speed: 15...25, swayFactor: 20, opacity: 0.6, zPos: 20, bounds: geometry.size)
//                    .blur(radius: 0.3)
//                
//                SnowflakeLayer(count: mediumFlakeCount, size: 12...18, speed: 10...20, swayFactor: 30, opacity: 0.8, zPos: 0, bounds: geometry.size)
//                
//                SnowflakeLayer(count: largeFlakeCount, size: 18...24, speed: 8...15, swayFactor: 40, opacity: 0.7, zPos: -20, bounds: geometry.size)
//                    .blur(radius: 0.5)
//            }
//            .clipShape(RoundedRectangle(cornerRadius: 20))
//        }
//    }
//}
//
//struct SnowflakeLayer: View {
//    let count: Int
//    let size: ClosedRange<CGFloat>
//    let speed: ClosedRange<Double>
//    let swayFactor: CGFloat
//    let opacity: Double
//    let zPos: CGFloat
//    let bounds: CGSize
//    
//    var body: some View {
//        ForEach(0..<count, id: \.self) { _ in
//            EnhancedSnowflake(
//                size: CGFloat.random(in: size),
//                speed: Double.random(in: speed),
//                swayFactor: CGFloat.random(in: swayFactor/2...swayFactor),
//                startPosition: CGPoint(
//                    x: CGFloat.random(in: 0...bounds.width),
//                    y: CGFloat.random(in: -50...0)
//                ),
//                canvasSize: bounds
//            )
//            .opacity(opacity)
//            .scaleEffect(1.0 - (zPos * 0.01))
//        }
//    }
//}
//
//struct EnhancedSnowflake: View {
//    let size: CGFloat
//    let speed: Double
//    let swayFactor: CGFloat
//    let startPosition: CGPoint
//    let canvasSize: CGSize
//    
//    @State private var xPosition: CGFloat = 0
//    @State private var yPosition: CGFloat = 0
//    @State private var rotation: Double = 0
//    @State private var scale: CGFloat = 1
//    
//    let snowflakeOptions = ["❄️", "❅", "❆", "✻", "✼"]
//    @State private var snowflakeType: String = "❄️"
//    
//    var body: some View {
//        Text(snowflakeType)
//            .font(.system(size: size))
//            .foregroundColor(.white)
//            .position(x: xPosition, y: yPosition)
//            .rotationEffect(Angle(degrees: rotation))
//            .scaleEffect(scale)
//            .shadow(color: .white.opacity(0.5), radius: 2, x: 0, y: 0)
//            .onAppear {
//                snowflakeType = snowflakeOptions.randomElement() ?? "❄️"
//                xPosition = startPosition.x
//                yPosition = startPosition.y
//                startFallingAnimation()
//                startSwayingAnimation()
//                startRotatingAnimation()
//                startPulsingAnimation()
//            }
//    }
//    
//    private func startFallingAnimation() {
//        let fallDuration = speed + Double.random(in: 0...3)
//        let delay = Double.random(in: 0...3)
//        
//        withAnimation(Animation.linear(duration: fallDuration).delay(delay).repeatForever(autoreverses: false)) {
//            yPosition = canvasSize.height + 50
//        }
//    }
//    
//    private func startSwayingAnimation() {
//        let startX = xPosition
//        let maxWidth = canvasSize.width
//        let fallDuration = speed + Double.random(in: 0...3)
//        let delay = Double.random(in: 0...1)
//        let swayCount = Int.random(in: 3...6)
//        
//        for i in 0..<swayCount {
//            let swayDelay = fallDuration / Double(swayCount) * Double(i)
//            let direction = i % 2 == 0 ? 1.0 : -1.0
//            let swayDistance = CGFloat.random(in: swayFactor/2...swayFactor) * direction
//            
//            DispatchQueue.main.asyncAfter(deadline: .now() + delay + swayDelay) {
//                withAnimation(Animation.easeInOut(duration: fallDuration / Double(swayCount))) {
//                    xPosition = max(min(startX + swayDistance, maxWidth), 0)
//                }
//            }
//        }
//    }
//    
//    private func startRotatingAnimation() {
//        let rotationSpeed = Double.random(in: 2...5)
//        let rotationDirection = Bool.random() ? 1.0 : -1.0
//        let rotationAmount = 360 * rotationDirection
//        
//        withAnimation(Animation.linear(duration: rotationSpeed).repeatForever(autoreverses: false)) {
//            rotation = rotationAmount
//        }
//    }
//    
//    private func startPulsingAnimation() {
//        let pulseSpeed = Double.random(in: 1.5...3)
//        
//        withAnimation(Animation.easeInOut(duration: pulseSpeed).repeatForever(autoreverses: true)) {
//            scale = CGFloat.random(in: 0.85...1.15)
//        }
//    }
//}

// MARK: - Fog Views

struct ModernFogOverlay: View {
    let nightMode: Bool
    
    var body: some View {
        FogOverlay()
            .colorMultiply(nightMode ? Color(red: 0.3, green: 0.3, blue: 0.4) : Color.white)
    }
}
//
//struct FogOverlay: View {
//    let fogLayerCount = 6
//    
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack {
//                CloudBase(opacity: 0.3)
//                
//                ForEach(0..<fogLayerCount, id: \.self) { index in
//                    FogLayer(
//                        density: getFogDensity(for: index),
//                        speed: getFogSpeed(for: index),
//                        baseOffset: CGFloat(index) * 60,
//                        opacity: getFogOpacity(for: index),
//                        bounds: geometry.size
//                    )
//                }
//            }
//            .clipShape(RoundedRectangle(cornerRadius: 20))
//        }
//    }
//    
//    private func getFogDensity(for index: Int) -> Int {
//        let baseDensity = [3, 4, 5, 4, 3, 2]
//        return baseDensity[index % baseDensity.count]
//    }
//    
//    private func getFogSpeed(for index: Int) -> Double {
//        let baseSpeed = [45.0, 60.0, 50.0, 55.0, 65.0, 70.0]
//        return baseSpeed[index % baseSpeed.count]
//    }
//    
//    private func getFogOpacity(for index: Int) -> Double {
//        if index == 0 || index == fogLayerCount-1 {
//            return 0.15
//        } else if index == 1 || index == fogLayerCount-2 {
//            return 0.25
//        } else {
//            return 0.3
//        }
//    }
//}
//
//struct FogLayer: View {
//    let density: Int
//    let speed: Double
//    let baseOffset: CGFloat
//    let opacity: Double
//    let bounds: CGSize
//    
//    @State private var xOffset: CGFloat = -100
//    @State private var yOffset: CGFloat = 0
//    
//    var body: some View {
//        ZStack {
//            ForEach(0..<density, id: \.self) { index in
//                FogElement(
//                    size: getFogSize(for: index),
//                    position: getFogPosition(for: index),
//                    opacity: opacity
//                )
//            }
//        }
//        .offset(x: xOffset, y: yOffset)
//        .onAppear {
//            startFogAnimation()
//        }
//    }
//    
//    private func getFogSize(for index: Int) -> CGSize {
//        let width = CGFloat.random(in: bounds.width * 0.3...bounds.width * 0.5)
//        let height = CGFloat.random(in: 30...60)
//        return CGSize(width: width, height: height)
//    }
//    
//    private func getFogPosition(for index: Int) -> CGPoint {
//        let x = CGFloat.random(in: 0...bounds.width)
//        let y = baseOffset + CGFloat.random(in: -20...20)
//        return CGPoint(
//            x: x,
//            y: min(max(20, y), bounds.height - 20)
//        )
//    }
//    
//    private func startFogAnimation() {
//        let initialDelay = Double.random(in: 0...2.0)
//        
//        withAnimation(Animation.linear(duration: speed).delay(initialDelay).repeatForever(autoreverses: false)) {
//            xOffset = bounds.width + 100
//        }
//        
//        withAnimation(Animation.easeInOut(duration: 10).delay(initialDelay).repeatForever(autoreverses: true)) {
//            yOffset = CGFloat.random(in: -15...15)
//        }
//    }
//}
//
//struct FogElement: View {
//    let size: CGSize
//    let position: CGPoint
//    let opacity: Double
//    
//    @State private var scale: CGFloat = 0.8
//    
//    var body: some View {
//        Capsule()
//            .fill(
//                LinearGradient(
//                    gradient: Gradient(colors: [
//                        Color.white.opacity(0),
//                        Color.white.opacity(opacity * 1.2),
//                        Color.white.opacity(opacity),
//                        Color.white.opacity(0)
//                    ]),
//                    startPoint: .leading,
//                    endPoint: .trailing
//                )
//            )
//            .frame(width: size.width, height: size.height)
//            .position(position)
//            .blur(radius: 15)
//            .scaleEffect(scale)
//            .onAppear {
//                withAnimation(Animation.easeInOut(duration: Double.random(in: 4...8)).repeatForever(autoreverses: true)) {
//                    scale = CGFloat.random(in: 0.9...1.1)
//                }
//            }
//    }
//}

// MARK: - Wind Views

struct WindyOverlay: View {
    let nightMode: Bool
    
    var body: some View {
        WindyWeatherView()
            .colorMultiply(nightMode ? Color(red: 0.3, green: 0.3, blue: 0.4) : Color.white)
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
                        speed: Double.random(in: 2...4)
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
    
    @State private var xOffset: CGFloat = 0
    @State private var opacity: Double = 0.3
    
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: startX + xOffset, y: startY))
            path.addLine(to: CGPoint(x: startX + xOffset + length, y: startY - 10))
        }
        .stroke(Color.white.opacity(opacity), lineWidth: 1)
        .onAppear {
            startWindAnimation()
        }
    }
    
    private func startWindAnimation() {
        withAnimation(Animation.linear(duration: speed).repeatForever(autoreverses: false)) {
            xOffset = 200
        }
        
        withAnimation(Animation.easeInOut(duration: speed * 0.5).repeatForever(autoreverses: true)) {
            opacity = Double.random(in: 0.2...0.5)
        }
    }
}

//// MARK: - Star Field (Supporting View)
//
//struct StarField: View {
//    let count: Int
//    let sizeRange: ClosedRange<CGFloat>
//    let opacityRange: ClosedRange<Double>
//    let twinkleIntensity: Double
//    let bounds: CGSize
//    
//    var body: some View {
//        ForEach(0..<count, id: \.self) { _ in
//            Star(
//                size: CGFloat.random(in: sizeRange),
//                position: CGPoint(
//                    x: CGFloat.random(in: 0...bounds.width),
//                    y: CGFloat.random(in: 0...bounds.height * 0.7)
//                ),
//                baseOpacity: Double.random(in: opacityRange),
//                twinkleIntensity: twinkleIntensity
//            )
//        }
//    }
//}
//
//struct Star: View {
//    let size: CGFloat
//    let position: CGPoint
//    let baseOpacity: Double
//    let twinkleIntensity: Double
//    
//    @State private var opacity: Double
//    @State private var scale: CGFloat = 1.0
//    
//    init(size: CGFloat, position: CGPoint, baseOpacity: Double, twinkleIntensity: Double) {
//        self.size = size
//        self.position = position
//        self.baseOpacity = baseOpacity
//        self.twinkleIntensity = twinkleIntensity
//        self._opacity = State(initialValue: baseOpacity)
//    }
//    
//    var body: some View {
//        Circle()
//            .fill(Color.white)
//            .frame(width: size, height: size)
//            .position(position)
//            .opacity(opacity)
//            .scaleEffect(scale)
//            .blur(radius: 0.2)
//            .onAppear {
//                startTwinkling()
//            }
//    }
//    
//    private func startTwinkling() {
//        guard twinkleIntensity > 0.1 else { return }
//        
//        let duration = Double.random(in: 1.0...3.0)
//        let delay = Double.random(in: 0...3.0)
//        let minOpacity = max(0.1, baseOpacity - (twinkleIntensity * baseOpacity * 0.7))
//        
//        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
//            withAnimation(Animation.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
//                opacity = minOpacity
//            }
//            
//            withAnimation(Animation.easeInOut(duration: duration * 1.5).repeatForever(autoreverses: true)) {
//                scale = 1.0 - (twinkleIntensity * 0.3)
//            }
//        }
//    }
//}



