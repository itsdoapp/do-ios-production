//
//  VoiceRecordingService.swift
//  Do
//
//  Service for recording and playing back voice messages
//

import Foundation
import AVFoundation
import Speech
import Combine

@MainActor
class VoiceRecordingService: NSObject, ObservableObject {
    static let shared = VoiceRecordingService()
    
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var playbackProgress: TimeInterval = 0
    @Published var audioLevel: Float = 0.0 // For waveform visualization
    @Published var recordedAudioURL: URL?
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var playbackTimer: Timer?
    private var audioLevelTimer: Timer?
    private var recognitionTask: Task<Void, Never>?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Recording
    
    func startRecording() async throws {
        // Stop any existing recording/playback
        stopRecording()
        stopPlayback()
        
        // Stop any speech recognition that might be running
        await MainActor.run {
            GenieVoiceService.shared.stopListening()
        }
        
        // Wait for cleanup
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Create recording URL - use CAF format for better compatibility with speech recognition
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("voice_message_\(Date().timeIntervalSince1970).caf")
        
        // Configure recorder settings - use Linear PCM for best compatibility
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0, // Speech recognition works best with 16kHz
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        // Configure audio session first (on background thread)
        try await Task.detached(priority: .userInitiated) {
            let audioSession = AVAudioSession.sharedInstance()
            // Deactivate first to release any existing session
            try? audioSession.setActive(false)
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true)
        }.value
        
        // Create recorder on main actor
        let recorder = try await MainActor.run {
            let recorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            
            recordedAudioURL = audioFilename
            audioRecorder = recorder
            
            return recorder
        }
        
        // Start recording on background thread
        let success = await Task.detached(priority: .userInitiated) {
            return recorder.record()
        }.value
        
        guard success else {
            throw VoiceRecordingError.recordingFailed
        }
        
        await MainActor.run {
            isRecording = true
            recordingDuration = 0
            
            // Start timers
            startRecordingTimer()
            startAudioLevelTimer()
        }
        
        print("🎤 [VoiceRecording] Started recording")
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        // Stop recorder
        audioRecorder?.stop()
        
        // Invalidate timers
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        
        // Update state
        isRecording = false
        audioLevel = 0.0
        
        // Deactivate audio session on background thread
        Task.detached(priority: .userInitiated) {
            let audioSession = AVAudioSession.sharedInstance()
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        }
        
        // Clear recorder reference
        audioRecorder = nil
        
        print("🎤 [VoiceRecording] Stopped recording, duration: \(recordingDuration)s")
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 0.1
            }
        }
    }
    
    private func startAudioLevelTimer() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            recorder.updateMeters()
            let level = recorder.averagePower(forChannel: 0)
            // Convert from dB to 0-1 range
            let normalizedLevel = pow(10, level / 20)
            Task { @MainActor in
                self.audioLevel = min(1.0, max(0.0, Float(normalizedLevel)))
            }
        }
    }
    
    // MARK: - Playback
    
    func startPlayback() throws {
        guard let url = recordedAudioURL else {
            throw VoiceRecordingError.noAudioFile
        }
        
        stopPlayback()
        
        // Configure audio session for playback
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default, options: [])
        try audioSession.setActive(true)
        
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
        
        isPlaying = true
        playbackProgress = 0
        
        startPlaybackTimer()
        
        print("🎵 [VoiceRecording] Started playback")
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    func resumePlayback() {
        audioPlayer?.play()
        isPlaying = true
        startPlaybackTimer()
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playbackProgress = 0
        playbackTimer?.invalidate()
        playbackTimer = nil
        
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let player = self.audioPlayer else { return }
                self.playbackProgress = player.currentTime
                
                if !player.isPlaying {
                    self.stopPlayback()
                }
            }
        }
    }
    
    func deleteRecording() {
        stopRecording()
        stopPlayback()
        
        if let url = recordedAudioURL {
            try? FileManager.default.removeItem(at: url)
            recordedAudioURL = nil
        }
        
        recordingDuration = 0
        playbackProgress = 0
    }
    
    // MARK: - Speech Recognition
    
    func transcribeAudio() async throws -> String {
        // Run entire transcription on background thread to prevent UI hang
        return try await Task.detached(priority: .userInitiated) {
            guard let url = await self.recordedAudioURL else {
                throw VoiceRecordingError.noAudioFile
            }
            
            // Check if file exists and is readable
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw VoiceRecordingError.noAudioFile
            }
            
            // Ensure speech recognition is stopped (on main actor)
            await MainActor.run {
                GenieVoiceService.shared.stopListening()
            }
            
            // Wait for cleanup (on background thread)
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            // Check authorization
            let authStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            
            guard authStatus == .authorized else {
                throw VoiceRecordingError.recognizerNotAvailable
            }
            
            // Create recognizer and check availability
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            guard let recognizer = recognizer, recognizer.isAvailable else {
                throw VoiceRecordingError.recognizerNotAvailable
            }
            
            // Configure audio session for speech recognition
            let audioSession = AVAudioSession.sharedInstance()
            try? audioSession.setActive(false)
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [])
            try audioSession.setActive(true)
            
            // Create recognition request
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = false
            
            // Perform recognition
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                var isCompleted = false
                var recognitionTask: SFSpeechRecognitionTask?
                
                recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                    guard !isCompleted else { return }
                    
                    if let error = error {
                        isCompleted = true
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    if let result = result, result.isFinal {
                        isCompleted = true
                        continuation.resume(returning: result.bestTranscription.formattedString)
                    }
                }
                
                // Timeout after 30 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    if !isCompleted {
                        recognitionTask?.cancel()
                        isCompleted = true
                        continuation.resume(throwing: VoiceRecordingError.recognizerNotAvailable)
                    }
                }
            }
        }.value
    }
}

extension VoiceRecordingService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                print("❌ [VoiceRecording] Recording failed")
                deleteRecording()
            }
        }
    }
}

extension VoiceRecordingService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            stopPlayback()
        }
    }
}

enum VoiceRecordingError: LocalizedError {
    case recordingFailed
    case noAudioFile
    case recognizerNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .recordingFailed:
            return "Failed to start recording"
        case .noAudioFile:
            return "No audio file available"
        case .recognizerNotAvailable:
            return "Speech recognizer not available"
        }
    }
}

