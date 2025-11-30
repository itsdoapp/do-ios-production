//
//  MotivationView.swift
//  Do
//
//  Displays motivation session from Genie with audio playback and lock screen controls
//

import SwiftUI
import MediaPlayer

struct MotivationView: View {
    let motivation: MotivationAction
    @Environment(\.dismiss) var dismiss
    @StateObject private var actionHandler = GenieActionHandler.shared
    @StateObject private var audioService = MeditationAudioService.shared
    @StateObject private var lockScreenManager = AudioLockScreenManager.shared
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var hasStarted = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.brandBlue,
                        Color("1A2456")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Animated Motivation Visualization
                    MotivationVisualizationView()
                        .frame(width: 300, height: 300)
                    
                    // Title
                    VStack(spacing: 8) {
                        Text(motivation.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 16) {
                            Label("\(motivation.duration) min", systemImage: "clock")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Label("Motivational", systemImage: "flame.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    // Status message with time
                    VStack(spacing: 12) {
                        if !hasStarted {
                            Text("Ready to begin?")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Button {
                                startMotivation()
                            } label: {
                                Text("Get Started")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                Color.brandOrange,
                                                Color("FF6B35")
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                            }
                        } else if audioService.isSpeaking {
                            Text("Session in progress...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            // Elapsed time
                            Text(formatTime(elapsedTime))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(Color.brandOrange)
                        } else if audioService.isPaused {
                            Text("Paused")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text(formatTime(elapsedTime))
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        // Ambient sound indicator
                        if hasStarted {
                            HStack(spacing: 6) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 12))
                                Text(motivation.ambientSoundType.description)
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
                    }
                    
                    Spacer()
                    
                    // Controls (only show if started)
                    if hasStarted {
                        HStack(spacing: 24) {
                            // Stop button
                            Button {
                                stopAllMotivationAudio()
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
                                    lockScreenManager.updatePlaybackState(isPlaying: true, elapsedTime: elapsedTime)
                                } else {
                                    audioService.pauseSpeaking()
                                    lockScreenManager.updatePlaybackState(isPlaying: false, elapsedTime: elapsedTime)
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
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Motivation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        stopAllMotivationAudio()
                        dismiss()
                    }
                    .foregroundColor(Color.brandOrange)
                }
            }
            .onAppear {
                if hasStarted {
                    startTimer()
                }
            }
            .onDisappear {
                timer?.invalidate()
                lockScreenManager.stopSession()
            }
        }
    }
    
    private func startMotivation() {
        hasStarted = true
        startTimer()
        
        // Setup lock screen controls
        let duration = TimeInterval(motivation.duration * 60)
        lockScreenManager.startSession(
            title: motivation.title,
            duration: duration,
            onPlay: {
                audioService.resumeSpeaking()
            },
            onPause: {
                audioService.pauseSpeaking()
            },
            onStop: {
                stopAllMotivationAudio()
            }
        )
        
        // Start audio playback
        if motivation.playAudio {
            audioService.playMeditationAudio(
                audioUrl: motivation.audioUrl,
                script: motivation.script,
                voiceType: .female,
                ambientType: motivation.ambientSoundType
            )
            lockScreenManager.updatePlaybackState(isPlaying: true, elapsedTime: 0)
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            if audioService.isSpeaking {
                elapsedTime += 1
                lockScreenManager.updatePlaybackState(isPlaying: true, elapsedTime: elapsedTime)
            } else if audioService.isPaused {
                lockScreenManager.updatePlaybackState(isPlaying: false, elapsedTime: elapsedTime)
            }
        }
    }
    
    private func stopAllMotivationAudio() {
        print("🛑 [MotivationView] Stopping all motivation audio...")
        
        // Stop narration audio
        audioService.stopSpeaking()
        
        // Stop ambient background audio
        Task { @MainActor in
            AmbientAudioService.shared.stopAmbientSound()
        }
        
        // Stop lock screen session
        lockScreenManager.stopSession()
        
        timer?.invalidate()
        
        print("🛑 [MotivationView] All audio stopped")
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Motivation Visualization

struct MotivationVisualizationView: View {
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Flame burst effect
            ForEach(0..<6) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(flameGradient)
                    .frame(width: 20, height: 100)
                    .rotationEffect(.degrees(Double(index) * 60))
                    .offset(y: -30)
                    .scaleEffect(y: flameScale(for: index))
            }
            
            // Center glow
            Circle()
                .fill(Color.brandOrange)
                .frame(width: 40, height: 40)
                .blur(radius: 20)
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: true)) {
                animationPhase = 1
            }
        }
    }
    
    private func flameScale(for index: Int) -> CGFloat {
        let phaseValue = Double(animationPhase) * .pi * 2 + Double(index) * 0.5
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
}


