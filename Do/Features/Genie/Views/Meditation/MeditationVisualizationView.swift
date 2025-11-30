//
//  MeditationVisualizationView.swift
//  Do
//
//  Animated visualizations for different meditation types
//

import SwiftUI

enum MeditationVisualizationType {
    case boxBreathing
    case breathing
    case mindfulness
    case focus
    case stress
    case sleep
    case motivation
    
    static func from(focus: String, script: String) -> MeditationVisualizationType {
        let lowerFocus = focus.lowercased()
        let lowerScript = script.lowercased()
        
        // Check for box breathing
        if lowerScript.contains("box breathing") || lowerScript.contains("4-4-4-4") || 
           (lowerScript.contains("breathe in") && lowerScript.contains("hold") && lowerScript.contains("exhale") && lowerScript.contains("4")) {
            return .boxBreathing
        }
        
        // Check for breathing exercises
        if lowerFocus.contains("breath") || lowerScript.contains("breathe") || lowerScript.contains("breathing") {
            return .breathing
        }
        
        // Check for other types
        if lowerFocus.contains("stress") || lowerFocus.contains("anxiety") {
            return .stress
        }
        if lowerFocus.contains("sleep") || lowerFocus.contains("rest") {
            return .sleep
        }
        if lowerFocus.contains("focus") || lowerFocus.contains("concentration") || lowerFocus.contains("clarity") {
            return .focus
        }
        if lowerFocus.contains("motivation") || lowerFocus.contains("energy") {
            return .motivation
        }
        
        return .mindfulness
    }
}

struct MeditationVisualizationView: View {
    let visualizationType: MeditationVisualizationType
    @State private var animationPhase: CGFloat = 0
    @State private var breathingPhase: BoxBreathingPhase = .inhale
    @State private var count: Int = 0
    
    var body: some View {
        Group {
            visualizationContent
        }
        .onAppear {
            startAnimation()
        }
    }
    
    @ViewBuilder
    private var visualizationContent: some View {
        switch visualizationType {
        case .boxBreathing:
            BoxBreathingAnimation(phase: $breathingPhase, count: $count)
        case .breathing:
            BreathingCircleAnimation(phase: $animationPhase)
        case .focus:
            FocusVisualization(phase: $animationPhase)
        case .stress:
            StressReliefVisualization(phase: $animationPhase)
        case .sleep:
            SleepVisualization(phase: $animationPhase)
        case .motivation:
            MotivationVisualization(phase: $animationPhase)
        case .mindfulness:
            MindfulnessVisualization(phase: $animationPhase)
        }
    }
    
    private func startAnimation() {
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: true)) {
            animationPhase = 1
        }
    }
}

// MARK: - Box Breathing Animation

enum BoxBreathingPhase {
    case inhale
    case holdIn
    case exhale
    case holdOut
}

struct BoxBreathingAnimation: View {
    @Binding var phase: BoxBreathingPhase
    @Binding var count: Int
    @State private var timer: Timer?
    @State private var boxSize: CGFloat = 100
    @State private var opacity: Double = 0.3
    
    var body: some View {
        ZStack {
            outerBox
            animatedBox
            cornerIndicators
            instructionText
        }
        .onAppear {
            startBoxBreathing()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private var outerBox: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(Color.white.opacity(0.3), lineWidth: 3)
            .frame(width: 200, height: 200)
    }
    
    private var animatedBox: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.brandOrange.opacity(opacity))
            .frame(width: boxSize, height: boxSize)
            .animation(.easeInOut(duration: 4), value: boxSize)
            .animation(.easeInOut(duration: 4), value: opacity)
    }
    
    private var cornerIndicators: some View {
        VStack(spacing: 120) {
            HStack(spacing: 120) {
                Circle()
                    .fill(cornerColor(for: .inhale))
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(cornerColor(for: .holdIn))
                    .frame(width: 12, height: 12)
            }
            HStack(spacing: 120) {
                Circle()
                    .fill(cornerColor(for: .holdOut))
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(cornerColor(for: .exhale))
                    .frame(width: 12, height: 12)
            }
        }
        .frame(width: 200, height: 200)
    }
    
    private var instructionText: some View {
        VStack(spacing: 8) {
            Text(phaseInstruction)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            Text("\(count)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color.brandOrange)
                .opacity(phase == .holdIn || phase == .holdOut ? 1 : 0.5)
        }
    }
    
    private func cornerColor(for phaseType: BoxBreathingPhase) -> Color {
        phase == phaseType ? Color.brandOrange : Color.white.opacity(0.3)
    }
    
    private var phaseInstruction: String {
        switch phase {
        case .inhale: return "Breathe In"
        case .holdIn: return "Hold"
        case .exhale: return "Breathe Out"
        case .holdOut: return "Hold"
        }
    }
    
    private func startBoxBreathing() {
        phase = .inhale
        count = 4
        boxSize = 80
        opacity = 0.3
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            count -= 1
            
            if count <= 0 {
                switch phase {
                case .inhale:
                    phase = .holdIn
                    count = 4
                    withAnimation(.easeInOut(duration: 0.5)) {
                        boxSize = 160
                        opacity = 0.6
                    }
                case .holdIn:
                    phase = .exhale
                    count = 4
                    withAnimation(.easeInOut(duration: 0.5)) {
                        boxSize = 80
                        opacity = 0.3
                    }
                case .exhale:
                    phase = .holdOut
                    count = 4
                    withAnimation(.easeInOut(duration: 0.5)) {
                        boxSize = 100
                        opacity = 0.4
                    }
                case .holdOut:
                    phase = .inhale
                    count = 4
                    withAnimation(.easeInOut(duration: 0.5)) {
                        boxSize = 80
                        opacity = 0.3
                    }
                }
            }
        }
    }
}

// MARK: - Breathing Circle Animation

struct BreathingCircleAnimation: View {
    @Binding var phase: CGFloat
    
    var body: some View {
        ZStack {
            concentricCircles
            mainBreathingCircle
            breathingIndicator
        }
    }
    
    private var concentricCircles: some View {
        ForEach(0..<3) { index in
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                .frame(width: circleWidth(for: index))
                .scaleEffect(circleScale(for: index))
        }
    }
    
    private func circleWidth(for index: Int) -> CGFloat {
        150 + CGFloat(index * 40)
    }
    
    private func circleScale(for index: Int) -> CGFloat {
        let phaseOffset = Double(index) * 0.5
        let phaseValue = Double(phase) * .pi * 2 + phaseOffset
        let scale = 1 + sin(phaseValue) * 0.3
        return CGFloat(scale)
    }
    
    private var mainBreathingCircle: some View {
        Circle()
            .fill(breathingGradient)
            .frame(width: 200, height: 200)
            .scaleEffect(breathingCircleScale)
    }
    
    private var breathingCircleScale: CGFloat {
        let phaseValue = Double(phase) * .pi * 2
        return CGFloat(1 + sin(phaseValue) * 0.4)
    }
    
    private var breathingGradient: RadialGradient {
        RadialGradient(
            colors: [
                Color.brandOrange.opacity(0.6),
                Color.brandOrange.opacity(0.2),
                Color.clear
            ],
            center: .center,
            startRadius: 20,
            endRadius: 100
        )
    }
    
    private var breathingIndicator: some View {
        VStack(spacing: 8) {
            Image(systemName: "wind")
                .font(.system(size: 30))
                .foregroundColor(.white.opacity(0.8))
                .scaleEffect(breathingIndicatorScale)
            Text("Breathe")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private var breathingIndicatorScale: CGFloat {
        let phaseValue = Double(phase) * .pi * 2
        return CGFloat(1 + sin(phaseValue) * 0.3)
    }
}

// MARK: - Focus Visualization

struct FocusVisualization: View {
    @Binding var phase: CGFloat
    
    var body: some View {
        ZStack {
            focusCircles
            centerPoint
        }
    }
    
    private var focusCircles: some View {
        ForEach(0..<5) { index in
            Circle()
                .stroke(focusGradient, lineWidth: 2)
                .frame(width: focusCircleWidth(for: index))
                .opacity(focusCircleOpacity(for: index))
                .scaleEffect(focusCircleScale(for: index))
        }
    }
    
    private func focusCircleWidth(for index: Int) -> CGFloat {
        120 + CGFloat(index * 25)
    }
    
    private func focusCircleOpacity(for index: Int) -> Double {
        1 - Double(index) * 0.15
    }
    
    private func focusCircleScale(for index: Int) -> CGFloat {
        let phaseOffset = Double(index) * 0.3
        let phaseValue = Double(phase) * .pi * 2 + phaseOffset
        let scale = 1 + sin(phaseValue) * 0.1
        return CGFloat(scale)
    }
    
    private var focusGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.brandOrange.opacity(0.6),
                Color.brandOrange.opacity(0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var centerPoint: some View {
        Circle()
            .fill(Color.brandOrange)
            .frame(width: 20, height: 20)
            .shadow(color: Color.brandOrange.opacity(0.8), radius: 20)
    }
}

// MARK: - Stress Relief Visualization

struct StressReliefVisualization: View {
    @Binding var phase: CGFloat
    
    var body: some View {
        ZStack {
            flowingWaves
            floatingParticles
        }
    }
    
    private var flowingWaves: some View {
        ForEach(0..<4) { index in
            WaveShape(phase: phase + Double(index) * 0.25)
                .fill(Color.white.opacity(0.2))
                .frame(height: 150)
                .offset(y: CGFloat(index * 30) - 60)
        }
    }
    
    private var floatingParticles: some View {
        ForEach(0..<8) { index in
            Circle()
                .fill(Color.white.opacity(0.4))
                .frame(width: 8, height: 8)
                .offset(x: particleOffsetX(for: index), y: particleOffsetY(for: index))
        }
    }
    
    private func particleOffsetX(for index: Int) -> CGFloat {
        let phaseValue = Double(phase) * .pi * 2 + Double(index)
        let offset = sin(phaseValue) * 60
        return CGFloat(offset)
    }
    
    private func particleOffsetY(for index: Int) -> CGFloat {
        let phaseValue = Double(phase) * .pi * 2 + Double(index) * 0.7
        let offset = cos(phaseValue) * 60
        return CGFloat(offset)
    }
}

// MARK: - Sleep Visualization

struct SleepVisualization: View {
    @Binding var phase: CGFloat
    
    var body: some View {
        ZStack {
            moon
            stars
        }
    }
    
    private var moon: some View {
        Circle()
            .fill(moonGradient)
            .frame(width: 160, height: 160)
            .offset(y: -20)
    }
    
    private var moonGradient: RadialGradient {
        RadialGradient(
            colors: [
                Color.white.opacity(0.3),
                Color.white.opacity(0.1)
            ],
            center: .center,
            startRadius: 30,
            endRadius: 80
        )
    }
    
    private var stars: some View {
        ForEach(0..<6) { index in
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .offset(x: starOffsetX(for: index), y: starOffsetY(for: index))
                .opacity(starOpacity(for: index))
        }
    }
    
    private func starOffsetX(for index: Int) -> CGFloat {
        let offset = cos(Double(index) * .pi / 3) * 80
        return CGFloat(offset)
    }
    
    private func starOffsetY(for index: Int) -> CGFloat {
        let offset = sin(Double(index) * .pi / 3) * 80 - 20
        return CGFloat(offset)
    }
    
    private func starOpacity(for index: Int) -> Double {
        let phaseValue = Double(phase) * .pi * 2 + Double(index)
        return 0.5 + sin(phaseValue) * 0.5
    }
}

// MARK: - Motivation Visualization

struct MotivationVisualization: View {
    @Binding var phase: CGFloat
    
    var body: some View {
        ZStack {
            flameBurst
            centerGlow
        }
    }
    
    private var flameBurst: some View {
        ForEach(0..<6) { index in
            RoundedRectangle(cornerRadius: 4)
                .fill(flameGradient)
                .frame(width: 20, height: 100)
                .rotationEffect(.degrees(flameRotation(for: index)))
                .offset(y: -30)
                .scaleEffect(y: flameScale(for: index))
        }
    }
    
    private func flameRotation(for index: Int) -> Double {
        Double(index) * 60
    }
    
    private func flameScale(for index: Int) -> CGFloat {
        let phaseValue = Double(phase) * .pi * 2 + Double(index) * 0.5
        let scale = 1 + sin(phaseValue) * 0.3
        return CGFloat(scale)
    }
    
    private var flameGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.brandOrange,
                Color("FF6B35").opacity(0.6),
                Color.clear
            ],
            startPoint: .center,
            endPoint: .bottom
        )
    }
    
    private var centerGlow: some View {
        Circle()
            .fill(Color.brandOrange)
            .frame(width: 40, height: 40)
            .blur(radius: 20)
    }
}

// MARK: - Mindfulness Visualization

struct MindfulnessVisualization: View {
    @Binding var phase: CGFloat
    
    var body: some View {
        ZStack {
            mandalaPattern
            centerCircle
        }
    }
    
    private var mandalaPattern: some View {
        ForEach(0..<8) { index in
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.3))
                .frame(width: 4, height: 120)
                .rotationEffect(.degrees(mandalaRotation(for: index)))
                .scaleEffect(mandalaScale(for: index))
        }
    }
    
    private func mandalaRotation(for index: Int) -> Double {
        Double(index) * 45
    }
    
    private func mandalaScale(for index: Int) -> CGFloat {
        let phaseValue = Double(phase) * .pi * 2 + Double(index) * 0.25
        let scale = 1 + sin(phaseValue) * 0.2
        return CGFloat(scale)
    }
    
    private var centerCircle: some View {
        Circle()
            .stroke(Color.white.opacity(0.5), lineWidth: 3)
            .frame(width: 100, height: 100)
            .scaleEffect(mindfulnessCenterScale)
    }
    
    private var mindfulnessCenterScale: CGFloat {
        let phaseValue = Double(phase) * .pi * 2
        return CGFloat(1 + sin(phaseValue) * 0.1)
    }
}

// MARK: - Wave Shape

struct WaveShape: Shape {
    var phase: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height / 2
        
        path.move(to: CGPoint(x: 0, y: midHeight))
        
        for x in stride(from: 0, through: width, by: 10) {
            let relativeX = x / width
            let phaseValue = Double(relativeX) * .pi * 4 + Double(phase) * .pi * 2
            let y = midHeight + sin(phaseValue) * height * 0.3
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}

