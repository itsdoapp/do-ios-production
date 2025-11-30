//
//  AmbientAudioService.swift
//  Do
//
//  Plays ambient background audio for meditation sessions using professional recordings
//

import Foundation
import AVFoundation
import Accelerate

enum AmbientSoundType: String {
    case ocean = "ocean"
    case rain = "rain"
    case forest = "forest"
    case zen = "zen"
    case whiteNoise = "white_noise"
    case motivation = "motivation" // For motivation sessions (energetic, inspiring)
    case story = "story" // For bedtime stories (calm, peaceful)
    
    var description: String {
        switch self {
        case .ocean: return "Ocean Waves"
        case .rain: return "Gentle Rain"
        case .forest: return "Forest Sounds"
        case .zen: return "Zen Garden"
        case .whiteNoise: return "White Noise"
        case .motivation: return "Motivational Music"
        case .story: return "Calm Music"
        }
    }
    
    /// Returns available audio file names for this sound type
    /// Files should be placed in the app bundle under "AmbientSounds/" directory
    /// Format: "ambient_\(type)_\(variant).mp3" or "ambient_\(type).mp3"
    var audioFileNames: [String] {
        switch self {
        case .ocean:
            return ["ambient_ocean", "ambient_ocean_gentle", "ambient_ocean_rhythmic"]
        case .rain:
            return ["ambient_rain", "ambient_rain_light", "ambient_rain_steady"]
        case .forest:
            return ["ambient_forest", "ambient_forest_birds", "ambient_forest_nature"]
        case .zen:
            return ["ambient_zen", "ambient_zen_bowls", "ambient_zen_chimes"]
        case .whiteNoise:
            return ["ambient_noise_white", "ambient_noise_brown", "ambient_noise_pink"]
        case .motivation:
            return ["ambient_motivation_energetic", "ambient_motivation_uplifting", "ambient_motivation_epic", "ambient_motivation_ambient", "ambient_forest"] // Fallback to forest if motivation files not found
        case .story:
            return ["ambient_story_calm", "ambient_story_peaceful", "ambient_story_dreamy", "ambient_story_minimal", "ambient_rain"] // Fallback to rain if story files not found
        }
    }
}

@MainActor
class AmbientAudioService: NSObject, ObservableObject {
    static let shared = AmbientAudioService()
    
    private var audioPlayer: AVPlayer?
    private var playerLooper: AVPlayerLooper?
    private var audioEngine: AVAudioEngine? // For fallback generation
    private var playerNode: AVAudioPlayerNode? // For fallback generation
    private var isPlaying = false
    private var isPaused = false
    private var currentSoundType: AmbientSoundType?
    private var savedVolume: Float = 0.35
    private var notificationObserver: NSObjectProtocol?
    
    private override init() {
        super.init()
        setupAudioSession()
        setupNotifications()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("❌ [AmbientAudio] Failed to setup audio session: \(error)")
        }
    }
    
    private func setupNotifications() {
        // Observe when playback finishes (for non-looped playback fallback)
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let playerItem = notification.object as? AVPlayerItem,
                  playerItem == self.audioPlayer?.currentItem else { return }
            
            // Restart playback (fallback if looping fails)
            self.audioPlayer?.seek(to: .zero)
            self.audioPlayer?.play()
        }
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    /// Find available audio file for the given sound type
    /// Returns a randomly selected file from available variants, or first available if random selection fails
    private func findAudioFile(for type: AmbientSoundType) -> URL? {
        // Collect all available file URLs
        var availableUrls: [URL] = []
        
        for fileName in type.audioFileNames {
            // Try with .mp3 extension first
            if let url = Bundle.main.url(forResource: fileName, withExtension: "mp3", subdirectory: "AmbientSounds") {
                availableUrls.append(url)
            }
            // Try without subdirectory (in root Resources)
            if let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") {
                availableUrls.append(url)
            }
            // Try with .m4a extension
            if let url = Bundle.main.url(forResource: fileName, withExtension: "m4a", subdirectory: "AmbientSounds") {
                availableUrls.append(url)
            }
            if let url = Bundle.main.url(forResource: fileName, withExtension: "m4a") {
                availableUrls.append(url)
            }
        }
        
        // Remove duplicates (same file found in multiple locations)
        availableUrls = Array(Set(availableUrls.map { $0.absoluteString })).compactMap { URL(string: $0) }
        
        guard !availableUrls.isEmpty else {
            print("⚠️ [AmbientAudio] No audio file found for \(type.rawValue). Using fallback generation.")
            return nil
        }
        
        // Select random variant if multiple available, otherwise return first
        let selectedUrl = availableUrls.count > 1 ? availableUrls.randomElement()! : availableUrls[0]
        print("🔊 [AmbientAudio] Selected variant: \(selectedUrl.lastPathComponent) from \(availableUrls.count) available")
        return selectedUrl
    }
    
    func startAmbientSound(_ type: AmbientSoundType, volume: Float = 0.5) {
        guard !isPlaying || currentSoundType != type else {
            print("🔊 [AmbientAudio] Already playing \(type.rawValue)")
            return
        }
        
        stopAmbientSound() // Stop any existing sound
        
        print("🔊 [AmbientAudio] Starting \(type.description) at volume \(volume)...")
        
        // Try to find and play audio file
        if let audioURL = findAudioFile(for: type) {
            playAudioFile(url: audioURL, type: type, volume: volume)
        } else {
            // Fallback: Use programmatic generation (old method) if no file found
            print("⚠️ [AmbientAudio] Falling back to programmatic generation for \(type.rawValue)")
            startGeneratedSound(type: type, volume: volume)
        }
    }
    
    /// Play audio from file with seamless looping
    private func playAudioFile(url: URL, type: AmbientSoundType, volume: Float) {
        let playerItem = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        
        // Use AVPlayerLooper for seamless looping
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        
        audioPlayer = queuePlayer
        playerLooper = looper
        
        // Set volume (0.0 to 1.0)
        savedVolume = max(0.0, min(1.0, volume))
        queuePlayer.volume = savedVolume
        
        // Start playback
        queuePlayer.play()
        
        isPlaying = true
        isPaused = false
        currentSoundType = type
        
        print("🔊 [AmbientAudio] \(type.description) started from file: \(url.lastPathComponent)")
    }
    
    /// Fallback: Generate audio programmatically (old method)
    /// This is kept as fallback if audio files are not available
    private func startGeneratedSound(type: AmbientSoundType, volume: Float) {
        // Store references to prevent deallocation
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let node = playerNode else { return }
        
        engine.attach(node)
        
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        // Generate buffer based on sound type
        let buffer = generateAmbientBuffer(type: type, format: format, duration: 15.0)
        
        // Connect node to main mixer
        engine.connect(node, to: engine.mainMixerNode, format: format)
        
        // Set volume
        savedVolume = max(0.4, min(0.7, volume))
        engine.mainMixerNode.outputVolume = savedVolume
        
        do {
            try engine.start()
            node.scheduleBuffer(buffer, at: nil, options: .loops) { }
            node.play()
            
            isPlaying = true
            currentSoundType = type
            print("🔊 [AmbientAudio] \(type.description) started (generated - fallback mode)")
        } catch {
            print("❌ [AmbientAudio] Failed to start generated sound: \(error)")
            audioEngine = nil
            playerNode = nil
        }
    }
    
    func pauseAmbientSound() {
        guard isPlaying && !isPaused else { return }
        
        // Pause file-based playback
        audioPlayer?.pause()
        
        // Pause generated playback (fallback)
        playerNode?.pause()
        
        isPaused = true
        print("🔊 [AmbientAudio] Paused")
    }
    
    func resumeAmbientSound() {
        guard isPaused else { return }
        
        // Resume file-based playback
        audioPlayer?.play()
        
        // Resume generated playback (fallback)
        playerNode?.play()
        audioEngine?.mainMixerNode.outputVolume = savedVolume
        
        isPaused = false
        print("🔊 [AmbientAudio] Resumed at volume \(savedVolume)")
    }
    
    func stopAmbientSound() {
        guard isPlaying else { return }
        
        // Stop file-based playback
        audioPlayer?.pause()
        audioPlayer?.seek(to: .zero)
        audioPlayer = nil
        playerLooper?.disableLooping()
        playerLooper = nil
        
        // Stop generated playback (fallback)
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine?.reset()
        audioEngine = nil
        playerNode = nil
        
        isPlaying = false
        isPaused = false
        
        if let type = currentSoundType {
            print("🔊 [AmbientAudio] \(type.description) stopped")
        }
        currentSoundType = nil
    }
    
    func setVolume(_ volume: Float) {
        savedVolume = max(0.0, min(1.0, volume))
        audioPlayer?.volume = savedVolume
    }
    
    // MARK: - Fallback Audio Generation (for when files not available)
    
    private func generateAmbientBuffer(type: AmbientSoundType, format: AVAudioFormat, duration: Double) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            fatalError("Failed to create audio buffer")
        }
        
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData else {
            fatalError("Failed to get channel data")
        }
        
        let channelCount = Int(format.channelCount)
        
        switch type {
        case .ocean:
            generateOceanWaves(channelData: channelData, frameCount: frameCount, channelCount: channelCount, sampleRate: sampleRate)
        case .rain:
            generateRain(channelData: channelData, frameCount: frameCount, channelCount: channelCount, sampleRate: sampleRate)
        case .forest:
            generateForest(channelData: channelData, frameCount: frameCount, channelCount: channelCount, sampleRate: sampleRate)
        case .zen:
            generateZenTones(channelData: channelData, frameCount: frameCount, channelCount: channelCount, sampleRate: sampleRate)
        case .whiteNoise:
            generateWhiteNoise(channelData: channelData, frameCount: frameCount, channelCount: channelCount)
        case .motivation:
            // Use forest sounds as fallback for motivation (energetic nature sounds)
            generateForest(channelData: channelData, frameCount: frameCount, channelCount: channelCount, sampleRate: sampleRate)
        case .story:
            // Use rain sounds as fallback for story (calm, peaceful)
            generateRain(channelData: channelData, frameCount: frameCount, channelCount: channelCount, sampleRate: sampleRate)
        }
        
        return buffer
    }
    
    // Simple wave generation methods (fallback only)
    private func generateOceanWaves(channelData: UnsafePointer<UnsafeMutablePointer<Float>>, frameCount: AVAudioFrameCount, channelCount: Int, sampleRate: Double) {
        var filterState: Float = 0.0
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let primaryWave = Float(sin(2.0 * .pi * 0.8 * time))
            let secondaryWave = Float(sin(2.0 * .pi * 0.12 * time))
            let combinedWave = primaryWave * (0.7 + 0.3 * secondaryWave)
            let whiteNoise = Float.random(in: -0.5...0.5)
            filterState = filterState * 0.985 + whiteNoise * 0.015
            let waterTexture = filterState * 0.15
            let sample = combinedWave * 0.35 + waterTexture
            for channel in 0..<channelCount {
                let pan: Float = channel == 0 ? 1.0 : 0.92
                channelData[channel][frame] = sample * pan
            }
        }
    }
    
    private func generateRain(channelData: UnsafePointer<UnsafeMutablePointer<Float>>, frameCount: AVAudioFrameCount, channelCount: Int, sampleRate: Double) {
        var filterState: Float = 0.0
        for frame in 0..<Int(frameCount) {
            let whiteNoise = Float.random(in: -1.0...1.0)
            filterState = filterState * 0.99 + whiteNoise * 0.01
            let time = Double(frame) / sampleRate
            let gentleVariation = Float(sin(2.0 * .pi * 0.2 * time)) * 0.1 + 0.9
            let sample = filterState * 0.4 * gentleVariation
            for channel in 0..<channelCount {
                channelData[channel][frame] = sample
            }
        }
    }
    
    private func generateForest(channelData: UnsafePointer<UnsafeMutablePointer<Float>>, frameCount: AVAudioFrameCount, channelCount: Int, sampleRate: Double) {
        var filterState: Float = 0.0
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let whiteNoise = Float.random(in: -1.0...1.0)
            filterState = filterState * 0.98 + whiteNoise * 0.02
            let tone1 = Float(sin(2.0 * .pi * 200.0 * time)) * 0.03
            let tone2 = Float(sin(2.0 * .pi * 300.0 * time)) * 0.02
            let noiseLayer = filterState * 0.35
            let toneLayer = tone1 + tone2
            let sample = noiseLayer + toneLayer
            for channel in 0..<channelCount {
                channelData[channel][frame] = sample
            }
        }
    }
    
    private func generateZenTones(channelData: UnsafePointer<UnsafeMutablePointer<Float>>, frameCount: AVAudioFrameCount, channelCount: Int, sampleRate: Double) {
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let baseFreq = 80.0 + sin(2.0 * .pi * 0.03 * time) * 5.0
            let tone1 = Float(sin(2.0 * .pi * baseFreq * time)) * 0.25
            let tone2 = Float(sin(2.0 * .pi * baseFreq * 2.0 * time)) * 0.1
            let envelope = Float(sin(2.0 * .pi * 0.05 * time)) * 0.1 + 0.9
            let allTones = tone1 + tone2
            let sample = allTones * envelope * 0.3
            for channel in 0..<channelCount {
                channelData[channel][frame] = sample
            }
        }
    }
    
    private func generateWhiteNoise(channelData: UnsafePointer<UnsafeMutablePointer<Float>>, frameCount: AVAudioFrameCount, channelCount: Int) {
        var filterState: Float = 0.0
        for frame in 0..<Int(frameCount) {
            let noise = Float.random(in: -1.0...1.0)
            filterState = filterState * 0.98 + noise * 0.02
            let sample = filterState * 0.5
            for channel in 0..<channelCount {
                channelData[channel][frame] = sample
            }
        }
    }
}
