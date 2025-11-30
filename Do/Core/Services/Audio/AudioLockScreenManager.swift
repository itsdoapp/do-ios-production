//
//  AudioLockScreenManager.swift
//  Do
//
//  Manages lock screen controls for meditation, motivation, and bedtime story audio playback
//

import Foundation
import MediaPlayer
import AVFoundation

@MainActor
class AudioLockScreenManager: ObservableObject {
    static let shared = AudioLockScreenManager()
    
    private var commandCenter: MPRemoteCommandCenter
    private var playCommandHandler: Any?
    private var pauseCommandHandler: Any?
    private var stopCommandHandler: Any?
    
    private var currentTitle: String = ""
    private var currentDuration: TimeInterval = 0
    private var currentElapsedTime: TimeInterval = 0
    private var isPlaying: Bool = false
    
    private var onPlay: (() -> Void)?
    private var onPause: (() -> Void)?
    private var onStop: (() -> Void)?
    
    private init() {
        commandCenter = MPRemoteCommandCenter.shared()
        setupCommandCenter()
    }
    
    private func setupCommandCenter() {
        // Enable commands
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.stopCommand.isEnabled = true
        
        // Set up handlers
        playCommandHandler = commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.onPlay?()
            }
            return .success
        }
        
        pauseCommandHandler = commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.onPause?()
            }
            return .success
        }
        
        stopCommandHandler = commandCenter.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.onStop?()
            }
            return .success
        }
    }
    
    func startSession(
        title: String,
        duration: TimeInterval,
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        self.currentTitle = title
        self.currentDuration = duration
        self.currentElapsedTime = 0
        self.isPlaying = false
        self.onPlay = onPlay
        self.onPause = onPause
        self.onStop = onStop
        
        updateNowPlayingInfo()
    }
    
    func updatePlaybackState(isPlaying: Bool, elapsedTime: TimeInterval) {
        self.isPlaying = isPlaying
        self.currentElapsedTime = elapsedTime
        updateNowPlayingInfo()
    }
    
    func stopSession() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        currentTitle = ""
        currentDuration = 0
        currentElapsedTime = 0
        isPlaying = false
        onPlay = nil
        onPause = nil
        onStop = nil
    }
    
    private func updateNowPlayingInfo() {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: currentTitle,
            MPMediaItemPropertyArtist: "Genie",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentElapsedTime,
            MPMediaItemPropertyPlaybackDuration: currentDuration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}


