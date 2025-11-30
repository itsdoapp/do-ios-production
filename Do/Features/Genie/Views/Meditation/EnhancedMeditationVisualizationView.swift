//
//  EnhancedMeditationVisualizationView.swift
//  Do.
//
//  Enhanced meditation visualizations with audio-synced animations
//

import SwiftUI

struct EnhancedMeditationVisualizationView: View {
    let visualizationType: MeditationVisualizationType
    @Binding var currentSpokenText: String
    @Binding var detectedCount: Int?
    @State private var animationPhase: CGFloat = 0
    @State private var breathingPhase: BoxBreathingPhase = .inhale
    @State private var count: Int = 4
    @State private var timer: Timer?
    @State private var isAnimating = false
    
    var body: some View {
        Group {
            visualizationContent
        }
        .onAppear {
            startAnimation()
            startScriptMonitoring()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: currentSpokenText) { newText in
            detectCountingInText(newText)
        }
    }
    
    @ViewBuilder
    private var visualizationContent: some View {
        switch visualizationType {
        case .boxBreathing:
            EnhancedBoxBreathingAnimation(
                phase: $breathingPhase,
                count: $count,
                detectedCount: $detectedCount,
                currentSpokenText: $currentSpokenText
            )
        case .breathing:
            EnhancedBreathingCircleAnimation(phase: $animationPhase, isAnimating: $isAnimating)
        case .focus:
            EnhancedFocusVisualization(phase: $animationPhase)
        case .stress:
            EnhancedStressReliefVisualization(phase: $animationPhase)
        case .sleep:
            EnhancedSleepVisualization(phase: $animationPhase)
        case .motivation:
            EnhancedMotivationVisualization(phase: $animationPhase)
        case .mindfulness:
            EnhancedMindfulnessVisualization(phase: $animationPhase)
        }
    }
    
    private func startAnimation() {
        isAnimating = true
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: true)) {
            animationPhase = 1
        }
    }
    
    private func startScriptMonitoring() {
        // Monitor for counting patterns in spoken text
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [self] _ in
            // Detect counting in current spoken text
            if !currentSpokenText.isEmpty {
                detectCountingInText(currentSpokenText)
            }
        }
    }
    
    private func detectCountingInText(_ text: String) {
        let lowerText = text.lowercased()
        
        // Detect number words: "one", "two", "three", "four"
        let numberWords = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8]
        for (word, num) in numberWords {
            if lowerText.contains(word) {
                detectedCount = num
                if visualizationType == .boxBreathing {
                    count = num
                }
                return
            }
        }
        
        // Detect numeric patterns: "1", "2", "3", "4"
        if let regex = try? NSRegularExpression(pattern: #"\b(\d+)\b"#, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let countRange = Range(match.range(at: 1), in: text),
           let num = Int(text[countRange]) {
            detectedCount = num
            if visualizationType == .boxBreathing {
                count = num
            }
        }
    }
}

// MARK: - Breathing Pattern Types

enum BreathingPattern {
    case box4444 // 4-4-4-4 (standard box breathing)
    case breathing478 // 4-7-8 (relaxation breathing)
    case breathing478Inhale // 4-7-8 with specific inhale timing
    case custom(in: Int, hold: Int, out: Int, holdOut: Int)
}

// MARK: - Enhanced Box Breathing Animation (Audio-Synced)

struct EnhancedBoxBreathingAnimation: View {
    @Binding var phase: BoxBreathingPhase
    @Binding var count: Int
    @Binding var detectedCount: Int?
    @Binding var currentSpokenText: String
    @State private var boxSize: CGFloat = 100
    @State private var opacity: Double = 0.3
    @State private var cornerGlow: [Bool] = [false, false, false, false]
    @State private var timer: Timer?
    @State private var autoMode = true // Auto-advance if no audio sync
    @State private var breathingPattern: BreathingPattern = .box4444 // Default box breathing
    @State private var lastDetectedNumber: Int? = nil
    @State private var numberSequence: [Int] = [] // Track counting sequence
    
    var body: some View {
        ZStack {
            // Outer glow effect
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.3),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 250, height: 250)
                .scaleEffect(boxSize / 100)
            
            // Outer box frame
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
                .frame(width: 220, height: 220)
            
            // Animated inner box
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.976, green: 0.576, blue: 0.125).opacity(opacity),
                            Color(red: 1.0, green: 0.42, blue: 0.21).opacity(opacity * 0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: boxSize, height: boxSize)
                .shadow(color: Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.6), radius: 20, x: 0, y: 0)
                .animation(.easeInOut(duration: phaseDuration), value: boxSize)
                .animation(.easeInOut(duration: phaseDuration), value: opacity)
            
            // Corner indicators with glow
            cornerIndicators
            
            // Center instruction and count
            VStack(spacing: 12) {
                Text(phaseInstruction)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                
                if phase == .holdIn || phase == .holdOut {
                    Text("\(count)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.976, green: 0.576, blue: 0.125),
                                    Color(red: 1.0, green: 0.42, blue: 0.21)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.8), radius: 12, x: 0, y: 0)
                        .scaleEffect(count > 0 ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: count)
                } else {
                    // Breathing indicator
                    Image(systemName: phase == .inhale ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(Color(red: 0.976, green: 0.576, blue: 0.125))
                        .scaleEffect(phase == .inhale ? 1.2 : 0.9)
                        .animation(.easeInOut(duration: phaseDuration), value: phase)
                }
            }
        }
        .onAppear {
            startBoxBreathing()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: detectedCount) { newCount in
            if let newCount = newCount, newCount != count {
                // Audio detected a count - sync animation
                syncWithAudioCount(newCount)
            }
        }
        .onChange(of: currentSpokenText) { newText in
            // Parse spoken text for counting patterns
            parseSpokenTextForCounting()
        }
    }
    
    private var phaseDuration: Double {
        // Use detected count or default to 4
        let targetCount = detectedCount ?? 4
        return Double(targetCount)
    }
    
    private var cornerIndicators: some View {
        VStack(spacing: 140) {
            HStack(spacing: 140) {
                // Top-left: Inhale
                Circle()
                    .fill(cornerColor(for: .inhale))
                    .frame(width: 16, height: 16)
                    .shadow(color: cornerColor(for: .inhale).opacity(0.8), radius: 8, x: 0, y: 0)
                    .scaleEffect(cornerGlow[0] ? 1.3 : 1.0)
                    .opacity(phase == .inhale ? 1.0 : 0.4)
                
                // Top-right: Hold In
                Circle()
                    .fill(cornerColor(for: .holdIn))
                    .frame(width: 16, height: 16)
                    .shadow(color: cornerColor(for: .holdIn).opacity(0.8), radius: 8, x: 0, y: 0)
                    .scaleEffect(cornerGlow[1] ? 1.3 : 1.0)
                    .opacity(phase == .holdIn ? 1.0 : 0.4)
            }
            HStack(spacing: 140) {
                // Bottom-left: Hold Out
                Circle()
                    .fill(cornerColor(for: .holdOut))
                    .frame(width: 16, height: 16)
                    .shadow(color: cornerColor(for: .holdOut).opacity(0.8), radius: 8, x: 0, y: 0)
                    .scaleEffect(cornerGlow[2] ? 1.3 : 1.0)
                    .opacity(phase == .holdOut ? 1.0 : 0.4)
                
                // Bottom-right: Exhale
                Circle()
                    .fill(cornerColor(for: .exhale))
                    .frame(width: 16, height: 16)
                    .shadow(color: cornerColor(for: .exhale).opacity(0.8), radius: 8, x: 0, y: 0)
                    .scaleEffect(cornerGlow[3] ? 1.3 : 1.0)
                    .opacity(phase == .exhale ? 1.0 : 0.4)
            }
        }
        .frame(width: 220, height: 220)
    }
    
    private func cornerColor(for phaseType: BoxBreathingPhase) -> Color {
        if phase == phaseType {
            return Color(red: 0.976, green: 0.576, blue: 0.125)
        }
        return Color.white.opacity(0.3)
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
        count = detectedCount ?? 4
        boxSize = 80
        opacity = 0.3
        
        // Parse initial script to detect breathing pattern
        parseSpokenTextForCounting()
        
        // Start auto-advance timer (will be overridden by audio sync)
        // Use pattern-specific timing
        let interval = getPhaseDuration(for: phase)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [self] _ in
            if autoMode {
                advancePhase()
            }
        }
    }
    
    private func getPhaseDuration(for phase: BoxBreathingPhase) -> Double {
        switch breathingPattern {
        case .box4444:
            return 4.0
        case .breathing478, .breathing478Inhale:
            switch phase {
            case .inhale: return 4.0
            case .holdIn: return 7.0
            case .exhale: return 8.0
            case .holdOut: return 4.0
            }
        case .custom(let inhale, let hold, let out, let holdOut):
            switch phase {
            case .inhale: return Double(inhale)
            case .holdIn: return Double(hold)
            case .exhale: return Double(out)
            case .holdOut: return Double(holdOut)
            }
        }
    }
    
    private func advancePhase() {
        // Only count down if we're in a hold phase or if no audio sync is happening
        if phase == .holdIn || phase == .holdOut {
            count -= 1
        } else {
            // During inhale/exhale, use time-based progression
            // Count will be updated by audio sync if available
        }
        
        // Check if we should advance to next phase
        let shouldAdvance: Bool
        if phase == .holdIn || phase == .holdOut {
            shouldAdvance = count <= 0
        } else {
            // For inhale/exhale, use duration-based timing
            // This will be handled by timer interval changes
            shouldAdvance = false
        }
        
        if shouldAdvance {
            // Animate corner glow
            withAnimation(.easeInOut(duration: 0.3)) {
                switch phase {
                case .inhale:
                    cornerGlow[0] = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        cornerGlow[0] = false
                    }
                case .holdIn:
                    cornerGlow[1] = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        cornerGlow[1] = false
                    }
                case .exhale:
                    cornerGlow[3] = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        cornerGlow[3] = false
                    }
                case .holdOut:
                    cornerGlow[2] = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        cornerGlow[2] = false
                    }
                }
            }
            
            // Transition to next phase with pattern-specific counts
            let (nextPhase, nextCount, nextSize, nextOpacity) = getNextPhase()
            
            phase = nextPhase
            count = nextCount
            
            withAnimation(.easeInOut(duration: 0.5)) {
                boxSize = nextSize
                opacity = nextOpacity
            }
            
            // Update timer interval for new phase
            timer?.invalidate()
            let newInterval = getPhaseDuration(for: nextPhase)
            timer = Timer.scheduledTimer(withTimeInterval: newInterval, repeats: true) { [self] _ in
                if autoMode {
                    advancePhase()
                }
            }
        }
    }
    
    private func getNextPhase() -> (BoxBreathingPhase, Int, CGFloat, Double) {
        switch phase {
        case .inhale:
            let holdCount = getCountForPhase(.holdIn)
            return (.holdIn, holdCount, 180, 0.7)
        case .holdIn:
            let exhaleCount = getCountForPhase(.exhale)
            return (.exhale, exhaleCount, 80, 0.3)
        case .exhale:
            let holdOutCount = getCountForPhase(.holdOut)
            return (.holdOut, holdOutCount, 120, 0.5)
        case .holdOut:
            let inhaleCount = getCountForPhase(.inhale)
            return (.inhale, inhaleCount, 80, 0.3)
        }
    }
    
    private func getCountForPhase(_ phase: BoxBreathingPhase) -> Int {
        switch breathingPattern {
        case .box4444:
            return detectedCount ?? 4
        case .breathing478, .breathing478Inhale:
            switch phase {
            case .inhale: return 4
            case .holdIn: return 7
            case .exhale: return 8
            case .holdOut: return 4
            }
        case .custom(let inhale, let hold, let out, let holdOut):
            switch phase {
            case .inhale: return inhale
            case .holdIn: return hold
            case .exhale: return out
            case .holdOut: return holdOut
            }
        }
    }
    
    private func syncWithAudioCount(_ audioCount: Int) {
        // When audio detects a count, sync the animation
        count = audioCount
        lastDetectedNumber = audioCount
        
        // Track number sequence for pattern detection
        numberSequence.append(audioCount)
        if numberSequence.count > 4 {
            numberSequence.removeFirst()
        }
        
        // Detect breathing pattern from sequence
        detectBreathingPattern()
        
        // If we're in a hold phase and count changes, it means audio is counting down
        if phase == .holdIn || phase == .holdOut {
            // Count is already updated, just trigger visual update
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                // Visual update happens automatically via @State
            }
        } else if phase == .inhale || phase == .exhale {
            // If we detect a number during inhale/exhale, it might be counting
            // Don't change phase, just update count for display
        }
    }
    
    private func detectBreathingPattern() {
        // Detect 4-7-8 pattern: [4, 7, 8, 4] or similar
        if numberSequence.count >= 4 {
            let seq = Array(numberSequence.suffix(4))
            if seq == [4, 7, 8, 4] || seq == [4, 7, 8] {
                breathingPattern = .breathing478
            } else if seq.allSatisfy({ $0 == 4 }) {
                breathingPattern = .box4444
            }
        }
    }
    
    private func parseSpokenTextForCounting() {
        let lowerText = currentSpokenText.lowercased()
        
        // Detect "breathe in for X counts" or "count to X"
        let patterns = [
            #"breathe\s+(?:in|out)\s+for\s+(\d+)\s+counts?"#,
            #"count\s+to\s+(\d+)"#,
            #"hold\s+for\s+(\d+)\s+counts?"#,
            #"(\d+)\s+counts?"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: lowerText, options: [], range: NSRange(lowerText.startIndex..., in: lowerText)),
               let countRange = Range(match.range(at: 1), in: lowerText),
               let num = Int(lowerText[countRange]) {
                syncWithAudioCount(num)
                return
            }
        }
        
        // Detect number words
        let numberWords = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8]
        for (word, num) in numberWords {
            if lowerText.contains(word) && !lowerText.contains("\(word) minute") && !lowerText.contains("\(word) min") {
                syncWithAudioCount(num)
                return
            }
        }
    }
}

// MARK: - Enhanced Breathing Circle Animation

struct EnhancedBreathingCircleAnimation: View {
    @Binding var phase: CGFloat
    @Binding var isAnimating: Bool
    
    var body: some View {
        ZStack {
            // Multiple concentric circles with glow
            ForEach(0..<4) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.4 - Double(index) * 0.1),
                                Color(red: 1.0, green: 0.42, blue: 0.21).opacity(0.3 - Double(index) * 0.08)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: circleWidth(for: index))
                    .scaleEffect(circleScale(for: index))
                    .blur(radius: CGFloat(index) * 2)
            }
            
            // Main breathing circle
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.8),
                            Color(red: 1.0, green: 0.42, blue: 0.21).opacity(0.6),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 30,
                        endRadius: 120
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(breathingCircleScale)
                .shadow(color: Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.6), radius: 30, x: 0, y: 0)
            
            // Breathing indicator
            VStack(spacing: 8) {
                Image(systemName: "wind")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)
                    .scaleEffect(breathingIndicatorScale)
                
                Text("Breathe")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }
    
    private func circleWidth(for index: Int) -> CGFloat {
        180 + CGFloat(index * 50)
    }
    
    private func circleScale(for index: Int) -> CGFloat {
        let phaseOffset = Double(index) * 0.4
        let phaseValue = Double(phase) * .pi * 2 + phaseOffset
        let scale = 1 + sin(phaseValue) * 0.25
        return CGFloat(scale)
    }
    
    private var breathingCircleScale: CGFloat {
        let phaseValue = Double(phase) * .pi * 2
        return CGFloat(1 + sin(phaseValue) * 0.35)
    }
    
    private var breathingIndicatorScale: CGFloat {
        let phaseValue = Double(phase) * .pi * 2
        return CGFloat(1 + sin(phaseValue) * 0.2)
    }
}

// MARK: - Enhanced Focus Visualization

struct EnhancedFocusVisualization: View {
    @Binding var phase: CGFloat
    
    var body: some View {
        ZStack {
            // Concentric focus circles with gradient
            ForEach(0..<6) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.6 - Double(index) * 0.1),
                                Color(red: 1.0, green: 0.42, blue: 0.21).opacity(0.4 - Double(index) * 0.08)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: focusCircleWidth(for: index))
                    .opacity(focusCircleOpacity(for: index))
                    .scaleEffect(focusCircleScale(for: index))
            }
            
            // Center point with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.976, green: 0.576, blue: 0.125),
                                Color(red: 1.0, green: 0.42, blue: 0.21).opacity(0.6),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 5,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .blur(radius: 15)
                
                Circle()
                    .fill(Color(red: 0.976, green: 0.576, blue: 0.125))
                    .frame(width: 24, height: 24)
                    .shadow(color: Color(red: 0.976, green: 0.576, blue: 0.125).opacity(0.9), radius: 20, x: 0, y: 0)
            }
        }
    }
    
    private func focusCircleWidth(for index: Int) -> CGFloat {
        130 + CGFloat(index * 30)
    }
    
    private func focusCircleOpacity(for index: Int) -> Double {
        1 - Double(index) * 0.12
    }
    
    private func focusCircleScale(for index: Int) -> CGFloat {
        let phaseOffset = Double(index) * 0.25
        let phaseValue = Double(phase) * .pi * 2 + phaseOffset
        let scale = 1 + sin(phaseValue) * 0.08
        return CGFloat(scale)
    }
}

// MARK: - Enhanced Stress Relief Visualization

struct EnhancedStressReliefVisualization: View {
    @Binding var phase: CGFloat
    
    var body: some View {
        ZStack {
            // Flowing waves with gradient
            ForEach(0..<5) { index in
                WaveShape(phase: phase + Double(index) * 0.2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.3 - Double(index) * 0.05),
                                Color.white.opacity(0.1 - Double(index) * 0.02)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 160)
                    .offset(y: CGFloat(index * 25) - 50)
            }
            
            // Floating particles with glow
            ForEach(0..<12) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.2),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 8
                        )
                    )
                    .frame(width: 12, height: 12)
                    .offset(x: particleOffsetX(for: index), y: particleOffsetY(for: index))
                    .blur(radius: 2)
            }
        }
    }
    
    private func particleOffsetX(for index: Int) -> CGFloat {
        let phaseValue = Double(phase) * .pi * 2 + Double(index) * 0.5
        let offset = sin(phaseValue) * 70
        return CGFloat(offset)
    }
    
    private func particleOffsetY(for index: Int) -> CGFloat {
        let phaseValue = Double(phase) * .pi * 2 + Double(index) * 0.7
        let offset = cos(phaseValue) * 70
        return CGFloat(offset)
    }
}

// MARK: - Enhanced Sleep Visualization

struct EnhancedSleepVisualization: View {
    @Binding var phase: CGFloat
    
    var body: some View {
        ZStack {
            // Moon with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.2),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 20)
                
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.2)
                            ]),
                            center: .center,
                            startRadius: 30,
                            endRadius: 90
                        )
                    )
                    .frame(width: 160, height: 160)
            }
            .offset(y: -30)
            
            // Twinkling stars
            ForEach(0..<8) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .offset(x: starOffsetX(for: index), y: starOffsetY(for: index))
                    .opacity(starOpacity(for: index))
                    .shadow(color: .white.opacity(0.8), radius: 4, x: 0, y: 0)
            }
        }
    }
    
    private func starOffsetX(for index: Int) -> CGFloat {
        let angle = Double(index) * .pi / 4
        let offset = cos(angle) * 90
        return CGFloat(offset)
    }
    
    private func starOffsetY(for index: Int) -> CGFloat {
        let angle = Double(index) * .pi / 4
        let offset = sin(angle) * 90 - 30
        return CGFloat(offset)
    }
    
    private func starOpacity(for index: Int) -> Double {
        let phaseValue = Double(phase) * .pi * 2 + Double(index) * 0.8
        return 0.4 + sin(phaseValue) * 0.6
    }
}

// MARK: - Enhanced Motivation Visualization

struct EnhancedMotivationVisualization: View {
    @Binding var phase: CGFloat
    
    var body: some View {
        ZStack {
            // Flame bursts with gradient
            ForEach(0..<8) { index in
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.976, green: 0.576, blue: 0.125),
                                Color(red: 1.0, green: 0.42, blue: 0.21).opacity(0.8),
                                Color.clear
                            ]),
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 24, height: 120)
                    .rotationEffect(.degrees(flameRotation(for: index)))
                    .offset(y: -40)
                    .scaleEffect(y: flameScale(for: index))
                    .blur(radius: 2)
            }
            
            // Center glow
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.976, green: 0.576, blue: 0.125),
                            Color(red: 1.0, green: 0.42, blue: 0.21).opacity(0.6),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 10,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .blur(radius: 25)
        }
    }
    
    private func flameRotation(for index: Int) -> Double {
        Double(index) * 45
    }
    
    private func flameScale(for index: Int) -> CGFloat {
        let phaseValue = Double(phase) * .pi * 2 + Double(index) * 0.4
        let scale = 1 + sin(phaseValue) * 0.4
        return CGFloat(scale)
    }
}

// MARK: - Enhanced Mindfulness Visualization

struct EnhancedMindfulnessVisualization: View {
    @Binding var phase: CGFloat
    
    var body: some View {
        ZStack {
            // Mandala pattern with gradient
            ForEach(0..<12) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.2)
                            ]),
                            startPoint: .center,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 6, height: 140)
                    .rotationEffect(.degrees(mandalaRotation(for: index)))
                    .scaleEffect(mandalaScale(for: index))
            }
            
            // Center circle with glow
            Circle()
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.3)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
                .frame(width: 110, height: 110)
                .scaleEffect(mindfulnessCenterScale)
                .shadow(color: .white.opacity(0.5), radius: 15, x: 0, y: 0)
        }
    }
    
    private func mandalaRotation(for index: Int) -> Double {
        Double(index) * 30
    }
    
    private func mandalaScale(for index: Int) -> CGFloat {
        let phaseValue = Double(phase) * .pi * 2 + Double(index) * 0.2
        let scale = 1 + sin(phaseValue) * 0.15
        return CGFloat(scale)
    }
    
    private var mindfulnessCenterScale: CGFloat {
        let phaseValue = Double(phase) * .pi * 2
        return CGFloat(1 + sin(phaseValue) * 0.08)
    }
}

