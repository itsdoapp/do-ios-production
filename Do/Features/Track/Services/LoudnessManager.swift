//
//  LoudnessManager.swift
//  Do
//
//  Manages background audio to keep workout tracking active in background
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import AVFoundation

class LoudnessManager {
    static let shared = LoudnessManager()
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioSessionConfigured = false
    
    private init() {}
    
    // MARK: - Background Audio Management
    
    func startBackgroundAudio() {
        // Configure audio session for background playback
        setupAudioSession()
        
        // Start playing silent audio
        playSilentAudio()
    }
    
    func stopBackgroundAudio() {
        stopSilentAudio()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        guard !audioSessionConfigured else { return }
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Configure audio session for background playback
            try audioSession.setCategory(.playback,
                                       mode: .default,
                                       options: [.mixWithOthers])
            
            // Activate the audio session
            try audioSession.setActive(true)
            
            audioSessionConfigured = true
            print("✅ [LoudnessManager] Audio session configured for background playback")
        } catch {
            print("❌ [LoudnessManager] Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Silent Audio Playback
    
    private func playSilentAudio() {
        // If audio engine is already running, don't start another
        if let engine = audioEngine, engine.isRunning {
            return
        }
        
        do {
            let engine = AVAudioEngine()
            let playerNode = AVAudioPlayerNode()
            
            engine.attach(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
            
            // Create a silent buffer (1 second of silence)
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
            let frameCount = AVAudioFrameCount(format.sampleRate * 1.0) // 1 second
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
            buffer.frameLength = frameCount
            
            // Fill buffer with silence (zeros)
            if let channelData = buffer.floatChannelData {
                for channel in 0..<Int(format.channelCount) {
                    memset(channelData[channel], 0, Int(frameCount) * MemoryLayout<Float>.size)
                }
            }
            
            // Start the engine
            try engine.start()
            playerNode.volume = 0.0 // Silent
            playerNode.play()
            
            // Schedule buffer to loop
            playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
            
            // Store references
            self.audioEngine = engine
            self.playerNode = playerNode
            
            print("✅ [LoudnessManager] Silent audio started for background operation")
        } catch {
            print("❌ [LoudnessManager] Failed to start silent audio: \(error.localizedDescription)")
        }
    }
    
    private func stopSilentAudio() {
        playerNode?.stop()
        audioEngine?.stop()
        playerNode = nil
        audioEngine = nil
        audioSessionConfigured = false
        
        print("📱 [LoudnessManager] Silent audio stopped")
    }
}




