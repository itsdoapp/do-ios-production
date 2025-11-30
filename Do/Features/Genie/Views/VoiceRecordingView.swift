//
//  VoiceRecordingView.swift
//  Do
//
//  iMessage-style voice recording UI
//

import SwiftUI
import AVFoundation
import UIKit

struct VoiceRecordingView: View {
    @ObservedObject var recordingService: VoiceRecordingService
    let onSend: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if recordingService.isRecording {
                // Recording state
                recordingView
            } else if recordingService.recordedAudioURL != nil {
                // Playback state
                playbackView
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    private var recordingView: some View {
        HStack(spacing: 12) {
            // Stop button
            Button(action: {
                recordingService.stopRecording()
            }) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.red)
            }
            
            // Waveform
            WaveformView(amplitude: recordingService.audioLevel)
                .frame(height: 30)
            
            // Duration
            Text(formatDuration(recordingService.recordingDuration))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 50)
        }
    }
    
    private var playbackView: some View {
        HStack(spacing: 12) {
            // Play/Pause button
            Button(action: {
                if recordingService.isPlaying {
                    recordingService.pausePlayback()
                } else {
                    do {
                        try recordingService.startPlayback()
                    } catch {
                        print("❌ [Voice] Playback error: \(error)")
                    }
                }
            }) {
                Image(systemName: recordingService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color.brandOrange)
            }
            
            // Waveform with progress
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background waveform
                    WaveformView(amplitude: 0.5)
                        .frame(height: 30)
                        .opacity(0.3)
                    
                    // Progress waveform
                    WaveformView(amplitude: 0.7)
                        .frame(width: geometry.size.width * progressPercentage, height: 30)
                        .clipped()
                }
            }
            .frame(height: 30)
            
            // Duration
            Text(formatDuration(recordingService.playbackProgress))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 50)
            
            // Delete button
            Button(action: {
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                onDelete()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundColor(.red.opacity(0.8))
                    .frame(width: 32, height: 32)
            }
            
            // Send button
            Button(action: {
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                onSend()
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color.brandOrange)
            }
        }
    }
    
    private var progressPercentage: CGFloat {
        guard recordingService.recordingDuration > 0 else { return 0 }
        return min(1.0, CGFloat(recordingService.playbackProgress / recordingService.recordingDuration))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct WaveformView: View {
    let amplitude: Float
    @State private var bars: [Float] = Array(repeating: 0.3, count: 30)
    @State private var animationTimer: Timer?
    
    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<30, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.brandOrange)
                    .frame(width: 2, height: barHeight(for: index))
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: amplitude) { newAmplitude in
            updateBars(with: newAmplitude)
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        guard index < bars.count else { return 2 }
        let baseHeight: CGFloat = 2
        let maxHeight: CGFloat = 30
        let normalizedAmplitude = CGFloat(bars[index])
        return baseHeight + (maxHeight - baseHeight) * normalizedAmplitude
    }
    
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [self] _ in
            Task { @MainActor in
                self.updateBars(with: self.amplitude)
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func updateBars(with amplitude: Float) {
        // Update bars with current amplitude and add some variation
        bars = bars.enumerated().map { index, oldValue in
            // Create a wave pattern based on index and amplitude
            let wave = sin(Float(index) * 0.3 + Float(Date().timeIntervalSince1970) * 2) * 0.3 + 0.5
            let target = max(0.2, min(1.0, amplitude * 2.0 + wave * 0.3))
            // Smooth interpolation
            return oldValue * 0.6 + target * 0.4
        }
    }
}

