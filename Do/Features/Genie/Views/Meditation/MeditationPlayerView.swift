//
//  MeditationPlayerView.swift
//  Do
//
//  Displays meditation session from Genie
//

import SwiftUI
import MediaPlayer

struct MeditationPlayerView: View {
    let meditation: MeditationAction
    @Environment(\.dismiss) var dismiss
    @StateObject private var actionHandler = GenieActionHandler.shared
    @StateObject private var audioService = MeditationAudioService.shared
    @StateObject private var meditationService = GenieMeditationService.shared
    @StateObject private var lockScreenManager = AudioLockScreenManager.shared
    @State private var detectedCount: Int? = nil // Track detected counting
    
    var body: some View {
        ZStack {
            // Premium background gradient matching ModernMeditationTrackerViewController
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.08, green: 0.0, blue: 0.15), location: 0),
                    .init(color: Color(red: 0.12, green: 0.02, blue: 0.22), location: 0.5),
                    .init(color: Color(red: 0.15, green: 0.03, blue: 0.28), location: 1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Top buttons bar with safe area inset
                    HStack {
                        // Back button
                        Button {
                            stopAllMeditationAudio()
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                            )
                        }
                        
                        Spacer()
                        
                        // Log button (only show when meditation is finished or has been playing for 30+ seconds)
                        if (!audioService.isSpeaking && !audioService.isPaused && audioService.currentPlaybackTime > 30) ||
                            (audioService.isSpeaking && audioService.currentPlaybackTime >= 30) {
                            Button {
                                stopAllMeditationAudio()
                                logMeditationSession()
                                dismiss()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Log")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.green)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.green.opacity(0.2))
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, geometry.safeAreaInsets.top + 8) // Reduced top padding
                    .padding(.bottom, 8)
                    
                    // Main content
                    VStack(spacing: 32) {
                        Spacer()
                            .frame(height: 40) // Added specific spacer to push content down slightly but keep it high
                        
                        // Character Illustration with Animation
                        ZStack {
                            // Animated Meditation Visualization (larger, more prominent)
                            EnhancedMeditationVisualizationView(
                                visualizationType: MeditationVisualizationType.from(
                                    focus: meditation.focus,
                                    script: meditation.script
                                ),
                                currentSpokenText: $audioService.currentSpokenText,
                                detectedCount: $detectedCount
                            )
                            .frame(width: 280, height: 280)
                            .opacity(0.7) // Subtle background effect
                            
                            // Character illustration with smooth, responsive animation
                            MeditationCharacterView(category: mapFocusToCategory(meditation.focus))
                                .frame(width: 120, height: 120)
                                .scaleEffect(audioService.isSpeaking ? 1.03 : 1.0)
                                .animation(
                                    .spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2),
                                    value: audioService.isSpeaking
                                )
                        }
                        .frame(height: 300)
                        
                        // Title
                        VStack(spacing: 8) {
                            Text(meditation.isMotivation ? "Motivational Meditation" : "Guided Meditation")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 16) {
                                Label("\(meditation.duration) min", systemImage: "clock")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                if !meditation.isMotivation {
                                    Label(meditation.focus.capitalized, systemImage: "heart.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                        
                        // Status message with time
                        VStack(spacing: 12) {
                            if audioService.isSpeaking {
                                Text("Session in progress...")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                // Actual audio playback time
                                Text(formatTime(audioService.currentPlaybackTime))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.brandOrange)
                            } else if audioService.isPaused {
                                Text("Paused")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text(formatTime(audioService.currentPlaybackTime))
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.5))
                            } else {
                                Text("Getting ready...")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            // Ambient sound indicator
                            HStack(spacing: 6) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 12))
                                Text(ambientTypeForFocus(meditation.focus).description)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                        
                        Spacer()
                        
                        // Controls
                        HStack(spacing: 24) {
                            // Stop button
                            Button {
                                stopAllMeditationAudio()
                                logMeditationSession()
                                dismiss()
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "stop.circle.fill")
                                        .font(.system(size: 50))
                                    Text("Stop")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.white.opacity(0.7))
                            }
                            
                            // Pause/Resume button
                            Button {
                                if audioService.isPaused {
                                    audioService.resumeSpeaking()
                                } else {
                                    audioService.pauseSpeaking()
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: audioService.isPaused ? "play.circle.fill" : "pause.circle.fill")
                                        .font(.system(size: 70))
                                    Text(audioService.isPaused ? "Resume" : "Pause")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(Color.brandOrange)
                            }
                            .disabled(!audioService.isSpeaking && !audioService.isPaused)
                            
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .onAppear {
                startScriptParsing()
                setupLockScreenControls()
            }
            .onDisappear {
                lockScreenManager.stopSession()
            }
            .onChange(of: audioService.isSpeaking) { isSpeaking in
                updateLockScreenPlaybackState()
            }
            .onChange(of: audioService.isPaused) { isPaused in
                updateLockScreenPlaybackState()
            }
            .onChange(of: audioService.currentPlaybackTime) { playbackTime in
                lockScreenManager.updatePlaybackState(
                    isPlaying: audioService.isSpeaking && !audioService.isPaused,
                    elapsedTime: playbackTime
                )
            }
        }
    }
     func logMeditationSession() {
        // Log meditation session using MeditationTrackingService
        Task {
            do {
                // Map focus to meditation type
                let meditationType: MeditationType = {
                    switch meditation.focus.lowercased() {
                    case "stress", "anxiety": return .stress
                    case "sleep", "rest": return .sleep
                    case "focus", "concentration": return .focus
                    case "breathing": return .breathing
                    default: return .mindfulness
                    }
                }()
                
                // Determine if completed (if user listened for at least 30 seconds)
                let playbackTime = audioService.currentPlaybackTime
                let completed = playbackTime >= 30
                let actualDurationMinutes = Double(playbackTime) / 60.0
                
                // Map focus string to MeditationFocus enum
                let focus: MeditationFocus = {
                    let lower = meditation.focus.lowercased()
                    if lower.contains("stress") { return .stress }
                    if lower.contains("sleep") { return .sleep }
                    if lower.contains("focus") || lower.contains("clarity") { return .focus }
                    if lower.contains("anxiety") { return .anxiety }
                    if lower.contains("breath") { return .breathing }
                    if lower.contains("energy") || lower.contains("motivation") { return .energy }
                    return .stress
                }()
                
                // Create a simple script struct for tracking
                let script = MeditationScript(
                    duration: meditation.duration, focus: focus,
                    segments: [MeditationSegment(name: "Main", content: meditation.script)]
                )
                
                try await MeditationTrackingService.shared.logAIMeditation(
                    focus: focus,
                    duration: TimeInterval(meditation.duration * 60),
                    script: script,
                    completed: completed
                )
                
                print("✅ [Meditation] Session logged successfully")
            } catch {
                print("❌ [Meditation] Error logging session: \(error)")
            }
        }
    }
    
    /// Stop all meditation audio (narration + background)
     func stopAllMeditationAudio() {
        print("🛑 [MeditationPlayer] Stopping all meditation audio...")
        
        // Stop lock screen controls
        lockScreenManager.stopSession()
        
        // Stop narration audio (Polly or TTS)
        audioService.stopSpeaking()
        
        // Stop ambient background audio
        Task { @MainActor in
            AmbientAudioService.shared.stopAmbientSound()
        }
        
        print("🛑 [MeditationPlayer] All audio stopped")
    }
    
     func ambientTypeForFocus(_ focus: String) -> AmbientSoundType {
        // Use ambient sound type from meditation action if available
        // This is already set by GenieActionHandler based on agent's selection
        return meditation.ambientSoundType
    }
    
     func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
     func mapFocusToCategory(_ focus: String) -> String {
        let lower = focus.lowercased()
        if lower.contains("sleep") { return "Sleep" }
        if lower.contains("focus") || lower.contains("concentration") { return "Focus" }
        if lower.contains("stress") || lower.contains("anxiety") { return "Stress & Anxiety" }
        if lower.contains("breath") { return "Breathe" }
        if lower.contains("gratitude") { return "Gratitude & Happiness" }
        if lower.contains("recovery") || lower.contains("healing") { return "Healing & Recovery" }
        if lower.contains("performance") || lower.contains("energy") { return "Performance" }
        return "Meditation Basics"
    }
    
    // MARK: - Lock Screen Controls
    
     func setupLockScreenControls() {
        let duration = TimeInterval(meditation.duration * 60)
        let title = meditation.isMotivation ? "Motivational Meditation" : "Guided Meditation"
        
        lockScreenManager.startSession(
            title: title,
            duration: duration,
            onPlay: {
                audioService.resumeSpeaking()
            },
            onPause: {
                audioService.pauseSpeaking()
            },
            onStop: {
                stopAllMeditationAudio()
                dismiss()
            }
        )
        
        // Update initial state when audio starts
        if audioService.isSpeaking {
            updateLockScreenPlaybackState()
        }
    }
    
     func updateLockScreenPlaybackState() {
        lockScreenManager.updatePlaybackState(
            isPlaying: audioService.isSpeaking && !audioService.isPaused,
            elapsedTime: audioService.currentPlaybackTime
        )
    }
    
    // Parse script to detect counting patterns and update animation
     func parseScriptForCounting() {
        let script = meditation.script.lowercased()
        
        // Detect box breathing pattern (4-4-4-4)
        if script.contains("box breathing") || script.contains("4-4-4-4") {
            // Extract counting sequences
            let numberPattern = #"(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)"#
            if let regex = try? NSRegularExpression(pattern: numberPattern, options: []),
               let match = regex.firstMatch(in: script, options: [], range: NSRange(script.startIndex..., in: script)) {
                // Found counting pattern - will sync with animation
            }
        }
        
        // Detect "breathe in for X counts" patterns
        let breathePattern = #"breathe\s+(?:in|out)\s+for\s+(\d+)\s+counts?"#
        if let regex = try? NSRegularExpression(pattern: breathePattern, options: []),
           let match = regex.firstMatch(in: script, options: [], range: NSRange(script.startIndex..., in: script)),
           let countRange = Range(match.range(at: 1), in: script),
           let count = Int(script[countRange]) {
            detectedCount = count
        }
    }
    
     func startScriptParsing() {
        parseScriptForCounting()
        
        // Monitor audio service for spoken text updates
        // This would require adding a published property to MeditationAudioService
        // For now, we'll use the script parsing approach
    }
}

struct MeditationPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        MeditationPlayerView(
            meditation: MeditationAction(
                duration: 10,
                focus: "stress",
                isMotivation: false,
                script: "Let's begin with a calming breath...",
                playAudio: true,
                audioUrl: nil,
                audioDuration: nil,
                ambientSoundType: .ocean
            )
        )
        .preferredColorScheme(.dark)
    }
}

