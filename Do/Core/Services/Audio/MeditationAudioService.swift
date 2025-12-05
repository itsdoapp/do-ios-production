import Foundation
import MediaPlayer
import AVFoundation

class MeditationAudioService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = MeditationAudioService()
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any? // Store time observer for cleanup
    private var ttsTimer: Timer? // Timer for TTS time tracking
    private var ttsStartTime: Date? // Start time for TTS tracking
    @Published private(set) var isSpeaking = false
    @Published private(set) var isPaused = false
    @Published var currentSpokenText: String = "" // Track current text being spoken
    @Published var currentSegmentIndex: Int = 0 // Track which segment is being spoken
    @Published var currentPlaybackTime: TimeInterval = 0 // Track actual audio playback time
    
    // Expose player rate for lock screen verification
    var playerRate: Float {
        return audioPlayer?.rate ?? 0.0
    }
    
    // Store fallback info in case Polly audio fails
    private var fallbackScript: String?
    private var fallbackVoiceType: UserPreferences.VoiceType = .female
    private var fallbackAmbientType: AmbientSoundType?
    private var scriptSegments: [String] = [] // Store segments for tracking
    
    private override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    /// Play meditation audio - tries OpenAI TTS first, then Polly, then iOS TTS
    func playMeditationAudio(audioUrl: String?, script: String, voiceType: UserPreferences.VoiceType = .female, ambientType: AmbientSoundType? = nil) {
        // Store fallback info
        fallbackScript = script
        fallbackVoiceType = voiceType
        fallbackAmbientType = ambientType
        
        print("🔊 [MeditationAudio] playMeditationAudio called")
        
        // Start ambient background audio IMMEDIATELY if specified
        // This provides immediate feedback and ensures audio session/lock screen is active while TTS generates
        if let ambientType = ambientType {
            print("🔊 [MeditationAudio] Starting ambient audio immediately...")
            Task { @MainActor in
                // Configure audio session first
                self.configureAudioSessionForPlayback()
                AmbientAudioService.shared.startAmbientSound(ambientType, volume: 0.12)
            }
        } else {
            // Even if no ambient, configure session to be ready
            self.configureAudioSessionForPlayback()
        }
        
        // Priority 1: Use provided audioUrl if available (from backend)
        if let audioUrlString = audioUrl, !audioUrlString.isEmpty, let url = URL(string: audioUrlString) {
            print("🔊 [MeditationAudio] ✅ Using provided audio URL: \(url.absoluteString.prefix(100))...")
            playPollyAudio(url: url, ambientType: nil) // Ambient already started
            return
        }
        
        // Priority 2: Generate Polly Neural TTS audio (high quality, AWS-native)
        print("🎙️ [MeditationAudio] No audio URL provided - generating Polly Neural TTS...")
        Task {
            // Select voice based on user preference
            let pollyVoice: String = voiceType == .female ? "female" : "male"
            
            if let generatedUrl = await OpenAITTSService.shared.generateAudioURL(
                script: script,
                voice: pollyVoice
            ) {
                await MainActor.run {
                    print("✅ [MeditationAudio] Polly Neural TTS generated successfully")
                    self.playPollyAudio(url: URL(string: generatedUrl)!, ambientType: nil) // Ambient already started
                }
            } else {
                // Polly TTS failed - do not fallback, show error instead
                await MainActor.run {
                    print("❌ [MeditationAudio] Polly TTS failed - no fallback")
                    // TODO: Show error to user instead of falling back
                }
            }
        }
    }
    
    /// Configure audio session for playback
    private func configureAudioSessionForPlayback() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use .playback mode with .default options to allow lock screen media player
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers, .allowBluetooth]
            )
            // Activate if not already active
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true, options: [])
                print("🔊 [MeditationAudio] Audio session activated for playback")
            }
        } catch {
            print("❌ [MeditationAudio] Failed to configure audio session: \(error)")
        }
    }
    
    /// Fallback to TTS if Polly audio fails
    private func fallbackToTTS() {
        guard let script = fallbackScript else {
            print("❌ [MeditationAudio] No fallback script available")
            return
        }
        
        // Clean up AVPlayer if it exists
        if let player = audioPlayer {
            player.pause()
            if let item = playerItem {
                item.removeObserver(self, forKeyPath: "status")
                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: item)
            }
            audioPlayer = nil
            playerItem = nil
        }
        
        print("🔄 [MeditationAudio] Falling back to TTS")
        speakMeditationScript(script, voiceType: fallbackVoiceType, ambientType: fallbackAmbientType)
    }
    
    /// Play Polly-generated audio from URL
    private func playPollyAudio(url: URL, ambientType: AmbientSoundType?) {
        print("🔊 [MeditationAudio] Playing Polly audio from URL: \(url)")
        
        // Start ambient background audio if specified
        // Background volume: Lower base volume (12%) - will be ducked further when speech plays
        if let ambientType = ambientType {
            Task { @MainActor in
                AmbientAudioService.shared.startAmbientSound(ambientType, volume: 0.12)
            }
        }
        
        // Configure audio session for optimal meditation audio with background playback
        // Use .default mode (not .spokenAudio) to allow lock screen media player to show
        // .spokenAudio mode prevents lock screen from appearing
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Check if lock screen is already set up - if so, use .playback with .default mode
            // Otherwise use .spokenAudio for better speech clarity
            let hasLockScreenSetup = MPNowPlayingInfoCenter.default().nowPlayingInfo != nil
            
            // Only reconfigure if needed to avoid conflicts
            let needsReconfig = audioSession.category != .playback || 
                               (hasLockScreenSetup && audioSession.mode != .default) ||
                               (!hasLockScreenSetup && audioSession.mode != .spokenAudio)
            
            if needsReconfig {
                if hasLockScreenSetup {
                    // Lock screen is set up - use .default mode to allow it to show
                    try audioSession.setCategory(
                        .playback,
                        mode: .default,
                        options: [.mixWithOthers, .duckOthers, .allowBluetooth]
                    )
                    print("🔊 [MeditationAudio] Audio session configured with .default mode for lock screen")
                } else {
                    // No lock screen setup - use .spokenAudio for better speech clarity
                    try audioSession.setCategory(
                        .playback,
                        mode: .spokenAudio,
                        options: [.mixWithOthers, .duckOthers, .allowBluetooth]
                    )
                    print("🔊 [MeditationAudio] Audio session configured with .spokenAudio mode")
                }
            }
            
            // Only activate if not already active to avoid conflicts
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true, options: [])
                print("🔊 [MeditationAudio] Audio session activated for background playback")
            } else {
                print("🔊 [MeditationAudio] Audio session already active (other audio playing)")
            }
        } catch {
            print("❌ [MeditationAudio] Failed to configure audio session: \(error)")
            // Don't fail completely - audio might still play
        }
        
        // Create AVPlayer for Polly audio
        playerItem = AVPlayerItem(url: url)
        
        // Observe player item status for error handling
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemFailedToPlay),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem
        )
        
        // Observe when playback finishes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        // Observe when player item is ready to play
        playerItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        
        // Observe when playback actually starts (for adaptive volume ducking)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackStarted),
            name: .AVPlayerItemTimeJumped,
            object: playerItem
        )
        
        audioPlayer = AVPlayer(playerItem: playerItem)
        
        // Add periodic time observer to track playback time (updates every 0.1 seconds)
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let seconds = CMTimeGetSeconds(time)
            if !seconds.isNaN && !seconds.isInfinite && seconds >= 0 {
                self.currentPlaybackTime = seconds
            }
        }
        
        // Observe when playback rate changes (starts/stops)
        audioPlayer?.addObserver(self, forKeyPath: "rate", options: [.new], context: nil)
        
        // Start playback - AVPlayer will buffer automatically
        audioPlayer?.play()
        isSpeaking = true
        isPaused = false
        currentPlaybackTime = 0
        
        // Duck ambient audio when speech starts
        Task { @MainActor in
            AmbientAudioService.shared.setVolume(0.06) // Duck to 6% when speech is playing
        }
        
        print("🔊 [MeditationAudio] Polly audio playback initiated (buffering...)")
    }
    
    @objc private func playerItemFailedToPlay(_ notification: Notification) {
        print("❌ [MeditationAudio] Polly audio failed to play")
        if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
            print("❌ [MeditationAudio] Error: \(error.localizedDescription)")
        }
        // Fallback to TTS
        fallbackToTTS()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status", let item = object as? AVPlayerItem {
            switch item.status {
            case .readyToPlay:
                print("🔊 [MeditationAudio] Polly audio ready to play")
                // Duck ambient audio when ready to play
                Task { @MainActor in
                    AmbientAudioService.shared.setVolume(0.06) // Duck to 6% when speech is playing
                }
                // Post notification that audio is ready (for lock screen setup)
                NotificationCenter.default.post(name: NSNotification.Name("MeditationAudioReady"), object: nil)
            case .failed:
                print("❌ [MeditationAudio] Polly audio failed to load")
                if let error = item.error {
                    print("❌ [MeditationAudio] Error: \(error.localizedDescription)")
                }
                // Fallback to TTS
                fallbackToTTS()
            case .unknown:
                print("⏳ [MeditationAudio] Polly audio status unknown (buffering...)")
            @unknown default:
                break
            }
        } else if keyPath == "rate", let player = object as? AVPlayer {
            // Adaptive volume: duck ambient when speech plays, restore when paused
            let rate = player.rate
            Task { @MainActor in
                if rate > 0 {
                    // Speech is playing - duck ambient
                    AmbientAudioService.shared.setVolume(0.06) // 6% when speech active
                    // Post notification that audio is actually playing (for lock screen)
                    NotificationCenter.default.post(name: NSNotification.Name("MeditationAudioPlaying"), object: nil)
                } else {
                    // Speech paused - restore ambient slightly
                    AmbientAudioService.shared.setVolume(0.10) // 10% when paused
                }
            }
        }
    }
    
    @objc private func playbackStarted() {
        // Duck ambient audio when playback actually starts
        Task { @MainActor in
            AmbientAudioService.shared.setVolume(0.06) // 6% when speech is playing
        }
    }
    
    @objc private func audioDidFinishPlaying() {
        print("🔊 [MeditationAudio] Polly audio finished")
        isSpeaking = false
        isPaused = false
        
        // Remove time observer
        if let player = audioPlayer, let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        // Restore ambient volume before stopping (optional - could fade out)
        Task { @MainActor in
            AmbientAudioService.shared.setVolume(0.12) // Restore to base volume
            // Stop ambient audio when meditation narration completes
            AmbientAudioService.shared.stopAmbientSound()
        }
        
        // Post notification that audio finished
        NotificationCenter.default.post(name: .meditationAudioDidFinish, object: nil)
    }
    
    /// Speak an arbitrary guided meditation script (string, potentially multi-paragraph)
    /// This is the fallback TTS method when Polly audio is not available
    func speakMeditationScript(_ script: String, voiceType: UserPreferences.VoiceType = .female, ambientType: AmbientSoundType? = nil) {
        print("🔊 [MeditationAudio] Starting meditation audio playback...")
        print("🔊 [MeditationAudio] Script length: \(script.count) characters")
        
        // Start ambient background audio if specified
        // Background volume: Lower base volume (12%) - will be ducked further when speech plays
        if let ambientType = ambientType {
            Task { @MainActor in
                AmbientAudioService.shared.startAmbientSound(ambientType, volume: 0.12)
            }
        }
        
        // Configure audio session to mix with ambient audio and support background playback
        // Use .spokenAudio mode for better speech clarity during meditation
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.mixWithOthers, .duckOthers, .allowBluetooth]
            )
            try audioSession.setActive(true, options: [])
            print("🔊 [MeditationAudio] Audio session configured successfully for background playback")
        } catch {
            print("❌ [MeditationAudio] Failed to configure audio session: \(error)")
        }
        
        // Split script intelligently using proper sentence segmentation
        // First, preserve breathing markers ("...") as special pause indicators
        let breathingMarker = "___BREATHING_MARKER___"
        let scriptWithMarkers = script.replacingOccurrences(of: "...", with: breathingMarker)
        
        // Split by paragraph breaks first
        let paragraphs = scriptWithMarkers.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        var segments: [String] = []
        
        // Process each paragraph
        for paragraph in paragraphs {
            let trimmedParagraph = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Split into sentences using natural sentence boundaries
            // Match sentence endings: . ! ? followed by space and capital letter or end of text
            let sentencePattern = #"([.!?]+)(\s+|$)"#
            let regex = try? NSRegularExpression(pattern: sentencePattern, options: [])
            
            var lastIndex = trimmedParagraph.startIndex
            var sentences: [String] = []
            
            if let regex = regex {
                let nsRange = NSRange(trimmedParagraph.startIndex..., in: trimmedParagraph)
                let matches = regex.matches(in: trimmedParagraph, options: [], range: nsRange)
                
                var currentStart = trimmedParagraph.startIndex
                
                for match in matches {
                    guard let range = Range(match.range, in: trimmedParagraph) else { continue }
                    
                    let sentenceEnd = range.upperBound
                    
                    // Check if this is a real sentence boundary (not abbreviation or decimal)
                    if sentenceEnd < trimmedParagraph.endIndex {
                        let nextChar = trimmedParagraph[sentenceEnd]
                        let isRealBoundary = nextChar.isWhitespace || nextChar.isUppercase || nextChar == "\n"
                        
                        if isRealBoundary {
                            let sentence = String(trimmedParagraph[currentStart..<sentenceEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !sentence.isEmpty {
                                sentences.append(sentence)
                            }
                            currentStart = sentenceEnd
                        }
                    } else {
                        // End of string
                        let sentence = String(trimmedParagraph[currentStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !sentence.isEmpty {
                            sentences.append(sentence)
                        }
                        currentStart = trimmedParagraph.endIndex
                    }
                }
                
                // Add remaining text
                if currentStart < trimmedParagraph.endIndex {
                    let remaining = String(trimmedParagraph[currentStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !remaining.isEmpty {
                        sentences.append(remaining)
                    }
                }
            }
            
            // If no sentences found, use the whole paragraph
            if sentences.isEmpty {
                sentences = [trimmedParagraph]
            }
            
            segments.append(contentsOf: sentences)
        }
        
        // Filter empty segments
        segments = segments.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        // Try premium voices first, fallback to standard voices
        let premiumFemale = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Samantha-premium") ?? 
                          AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.en-US.Samantha") ??
                          AVSpeechSynthesisVoice(identifier: "com.apple.voice.compact.en-US.Samantha") ??
                          AVSpeechSynthesisVoice(language: "en-US")
        
        let premiumMale = AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.en-US.Alex") ??
                         AVSpeechSynthesisVoice(identifier: "com.apple.voice.compact.en-US.Alex") ??
                         AVSpeechSynthesisVoice(language: "en-US")
        
        let selectedVoice = voiceType == .female ? premiumFemale : premiumMale
        
        print("🔊 [MeditationAudio] Speaking \(segments.count) segments with natural pauses...")
        isSpeaking = true
        isPaused = false
        currentPlaybackTime = 0
        ttsStartTime = Date()
        
        // Start timer to track TTS playback time
        ttsTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.ttsStartTime, self.isSpeaking && !self.isPaused else { return }
            self.currentPlaybackTime = Date().timeIntervalSince(startTime)
        }
        
        // Store segments for tracking
        scriptSegments = segments
        
        // Speak segments sequentially with natural pauses
        for (index, segment) in segments.enumerated() {
            // Restore breathing markers to actual pauses in speech
            var processedSegment = segment.replacingOccurrences(of: breathingMarker, with: "...")
            
            // Update current spoken text for animation sync
            currentSegmentIndex = index
            currentSpokenText = processedSegment
            
            let utterance = AVSpeechUtterance(string: processedSegment)
            utterance.voice = selectedVoice
            
            // Optimized speech rate for meditation (slightly slower than default)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.78 // Slower, more contemplative pace
            // Slightly lower pitch for calming effect
            utterance.pitchMultiplier = 0.95 // Calm, soothing tone
            utterance.volume = 1.0
            
            // Duck ambient audio when each utterance starts (adaptive volume)
            if index == 0 {
                // First utterance - duck ambient immediately
                Task { @MainActor in
                    AmbientAudioService.shared.setVolume(0.06) // 6% when speech is playing
                }
            }
            
            // Calculate natural pause timing based on context
            if index > 0 {
                // Check previous segment ending to determine pause duration
                let prevSegment = segments[index - 1]
                let prevEndsStrong = prevSegment.hasSuffix(".") || prevSegment.hasSuffix("!") || prevSegment.hasSuffix("?")
                
                // Check if previous segment had a breathing marker (meditation pause)
                if prevSegment.contains(breathingMarker) || prevSegment.contains("...") {
                    // Longer pause for breathing markers
                    utterance.preUtteranceDelay = 3.0
                } else if prevEndsStrong {
                    // Natural pause after sentence-ending punctuation
                    utterance.preUtteranceDelay = 1.2
                } else {
                    // Shorter pause for continuation
                    utterance.preUtteranceDelay = 0.8
                }
            } else {
                // Small delay before starting
                utterance.preUtteranceDelay = 0.5
            }
            
            // Post-utterance delay only if more segments follow
            if index < segments.count - 1 {
                utterance.postUtteranceDelay = 0.2 // Brief pause between segments
            } else {
                utterance.postUtteranceDelay = 0.0 // No delay after final segment
            }
            
            synthesizer.speak(utterance)
        }
        
        print("🔊 [MeditationAudio] Speech synthesis started")
    }
    
    func pauseSpeaking() {
        guard isSpeaking && !isPaused else { return }
        
        // Pause either Polly audio or TTS
        if let player = audioPlayer {
            player.pause()
        } else {
            synthesizer.pauseSpeaking(at: .word)
            // Pause TTS timer
            ttsTimer?.invalidate()
            ttsTimer = nil
        }
        
        isPaused = true
        
        // Restore ambient volume slightly when paused (not fully, but more than when playing)
        Task { @MainActor in
            AmbientAudioService.shared.setVolume(0.10) // 10% when paused
            AmbientAudioService.shared.pauseAmbientSound()
        }
        print("🔊 [MeditationAudio] Speech paused")
    }
    
    func resumeSpeaking() {
        guard isPaused else { return }
        
        // Resume either Polly audio or TTS
        if let player = audioPlayer {
            player.play()
        } else {
            synthesizer.continueSpeaking()
            // Resume TTS timer
            if ttsStartTime == nil {
                ttsStartTime = Date() - currentPlaybackTime // Adjust start time to account for paused time
            }
            ttsTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let startTime = self.ttsStartTime, self.isSpeaking && !self.isPaused else { return }
                self.currentPlaybackTime = Date().timeIntervalSince(startTime)
            }
        }
        
        isPaused = false
        
        // Duck ambient audio again when speech resumes
        Task { @MainActor in
            AmbientAudioService.shared.resumeAmbientSound()
            AmbientAudioService.shared.setVolume(0.06) // Duck to 6% when speech resumes
        }
        print("🔊 [MeditationAudio] Speech resumed")
    }
    
    func stopSpeaking() {
        // Stop either Polly audio or TTS
        if let player = audioPlayer {
            player.pause()
            player.seek(to: .zero)
            
            // Remove time observer
            if let observer = timeObserver {
                player.removeTimeObserver(observer)
                timeObserver = nil
            }
            
            // Remove observers
            if let item = playerItem {
                item.removeObserver(self, forKeyPath: "status")
                player.removeObserver(self, forKeyPath: "rate")
                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: item)
                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemTimeJumped, object: item)
            }
            
            audioPlayer = nil
            playerItem = nil
        } else {
            synthesizer.stopSpeaking(at: .immediate)
            // Stop TTS timer
            ttsTimer?.invalidate()
            ttsTimer = nil
            ttsStartTime = nil
        }
        
        isSpeaking = false
        isPaused = false
        currentPlaybackTime = 0
        
        // Restore ambient volume before stopping
        Task { @MainActor in
            AmbientAudioService.shared.setVolume(0.12) // Restore to base volume
            AmbientAudioService.shared.stopAmbientSound()
        }
        print("🔊 [MeditationAudio] Speech stopped")
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🔊 [MeditationAudio] Speech started")
        isSpeaking = true
        isPaused = false
        
        // Start TTS timer if not already started
        if ttsStartTime == nil {
            ttsStartTime = Date()
            ttsTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let startTime = self.ttsStartTime, self.isSpeaking && !self.isPaused else { return }
                self.currentPlaybackTime = Date().timeIntervalSince(startTime)
            }
        }
        
        // Update current spoken text
        currentSpokenText = utterance.speechString
        
        // Duck ambient audio when speech starts
        Task { @MainActor in
            AmbientAudioService.shared.setVolume(0.06) // 6% when speech is playing
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("🔊 [MeditationAudio] Speech finished")
        
        // Check if there are more utterances (speech is still continuing)
        if synthesizer.isSpeaking {
            // More speech coming - keep ambient ducked
            return
        }
        
        // Stop TTS timer
        ttsTimer?.invalidate()
        ttsTimer = nil
        ttsStartTime = nil
        
        isSpeaking = false
        isPaused = false
        
        // Restore ambient volume before stopping
        Task { @MainActor in
            AmbientAudioService.shared.setVolume(0.12) // Restore to base volume
            // Stop ambient audio when TTS narration completes naturally
            AmbientAudioService.shared.stopAmbientSound()
        }
        
        // Post notification that audio finished
        NotificationCenter.default.post(name: .meditationAudioDidFinish, object: nil)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("🔊 [MeditationAudio] Speech cancelled")
        
        // Stop TTS timer
        ttsTimer?.invalidate()
        ttsTimer = nil
        ttsStartTime = nil
        
        isSpeaking = false
        isPaused = false
        currentPlaybackTime = 0
        
        // Stop ambient audio on cancellation
        Task { @MainActor in
            AmbientAudioService.shared.stopAmbientSound()
        }
        
        // Post notification that audio finished
        NotificationCenter.default.post(name: .meditationAudioDidFinish, object: nil)
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let meditationAudioDidFinish = Notification.Name("meditationAudioDidFinish")
}


