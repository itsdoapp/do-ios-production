//
//  GenieVoiceService.swift
//  Do
//
//  Voice input and output service for Genie
//

import Foundation
import Speech
import AVFoundation

@MainActor
class GenieVoiceService: NSObject, ObservableObject {
    static let shared = GenieVoiceService()
    
    // MARK: - Published Properties
    @Published var isListening = false
    @Published var isRecognizing = false
    @Published var isSpeaking = false
    @Published var recognizedText = ""
    @Published var partialText = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    // Track if tap is installed to prevent crashes
    private var isTapInstalled = false
    
    // MARK: - Private Properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    
    private override init() {
        super.init()
        speechSynthesizer.delegate = self
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }
    
    // MARK: - Voice Input (Speech Recognition)
    
    func startListening() async throws -> String {
        // Cancel any ongoing recognition and wait for cleanup
        stopListening()
        
        // Give time for cleanup to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Check authorization
        if authorizationStatus != .authorized {
            let authorized = await requestAuthorization()
            guard authorized else {
                throw VoiceError.notAuthorized
            }
        }
        
        // Check if speech recognizer is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceError.recognizerNotAvailable
        }
        
        // Ensure audio engine is stopped and clean
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Ensure no existing tap
        let inputNode = audioEngine.inputNode
        if isTapInstalled {
            inputNode.removeTap(onBus: 0)
            isTapInstalled = false
            // Wait a bit more after removing tap
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.unableToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Reset state
        recognizedText = ""
        partialText = ""
        isListening = true
        isRecognizing = true
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let result = result {
                    self.partialText = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        self.recognizedText = result.bestTranscription.formattedString
                        self.stopListening()
                    }
                }
                
                if error != nil {
                    self.stopListening()
                }
            }
        }
        
        // Configure audio tap - ensure we only install if not already installed
        guard !isTapInstalled else {
            throw VoiceError.unableToCreateRequest // Tap already exists, something went wrong
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        isTapInstalled = true
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        print("🎤 [Voice] Started listening...")
        
        // Wait for recognition to complete (with timeout)
        return await withCheckedContinuation { continuation in
            Task {
                // Wait up to 30 seconds for user to finish speaking
                for _ in 0..<60 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    if !self.isListening {
                        continuation.resume(returning: self.recognizedText)
                        return
                    }
                }
                
                // Timeout - stop listening and return what we have
                self.stopListening()
                continuation.resume(returning: self.recognizedText)
            }
        }
    }
    
    func stopListening() {
        guard isListening || isRecognizing else {
            // Already stopped, avoid duplicate cleanup
            return
        }
        
        isListening = false
        isRecognizing = false
        
        // Stop audio engine first
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Remove tap safely - check if it exists first
        let inputNode = audioEngine.inputNode
        if isTapInstalled {
            inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        
        // End recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        
        print("🎤 [Voice] Stopped listening")
    }
    
    // MARK: - Voice Output (Text-to-Speech)
    
    func speak(_ text: String, rate: Float = 0.4, voice: AVSpeechSynthesisVoice? = nil) {
        // Stop any ongoing speech
        stopSpeaking()
        
        // Configure audio session for meditation (better quality)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("⚠️ [Voice] Audio session setup error: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate // Slower for meditation (0.4 = calm, contemplative pace)
        utterance.pitchMultiplier = 0.95 // Slightly lower pitch for calming effect
        utterance.volume = 0.9 // Slightly reduced volume for meditative atmosphere
        utterance.preUtteranceDelay = 0.1 // Small pause before speaking
        utterance.postUtteranceDelay = 0.15 // Small pause after speaking
        
        // Use a natural English voice - prefer premium/enhanced voices for meditation
        if let voice = voice {
            utterance.voice = voice
        } else {
            // Get the best available voice for meditation
            if let preferredVoice = getPreferredVoice() {
                utterance.voice = preferredVoice
            } else {
                // Fallback to enhanced Siri voice
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            }
        }
        
        currentUtterance = utterance
        isSpeaking = true
        
        speechSynthesizer.speak(utterance)
        print("🔊 [Voice] Speaking meditation: \(text.prefix(50))... (rate: \(rate), voice: \(utterance.voice?.identifier ?? "default"))")
    }
    
    func stopSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        currentUtterance = nil
        print("🔊 [Voice] Stopped speaking")
    }
    
    func pauseSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.pauseSpeaking(at: .word)
        }
    }
    
    func resumeSpeaking() {
        if speechSynthesizer.isPaused {
            speechSynthesizer.continueSpeaking()
        }
    }
    
    // MARK: - Available Voices
    
    func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.starts(with: "en") }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
    }
    
    func getPreferredVoice() -> AVSpeechSynthesisVoice? {
        // Try to get enhanced Siri voice
        let voices = getAvailableVoices()
        
        // Prefer premium/enhanced voices
        if let premiumVoice = voices.first(where: { $0.quality == .premium }) {
            return premiumVoice
        }
        
        // Fall back to enhanced
        if let enhancedVoice = voices.first(where: { $0.quality == .enhanced }) {
            return enhancedVoice
        }
        
        // Default to first available
        return voices.first
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension GenieVoiceService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = true
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            currentUtterance = nil
            print("🔊 [Voice] Finished speaking segment")
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            currentUtterance = nil
        }
    }
}

// MARK: - Errors

enum VoiceError: LocalizedError {
    case notAuthorized
    case recognizerNotAvailable
    case unableToCreateRequest
    case audioEngineError
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized. Please enable in Settings."
        case .recognizerNotAvailable:
            return "Speech recognizer not available."
        case .unableToCreateRequest:
            return "Unable to create speech recognition request."
        case .audioEngineError:
            return "Audio engine error."
        }
    }
}

