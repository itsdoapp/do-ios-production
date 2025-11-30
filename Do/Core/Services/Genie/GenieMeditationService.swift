//
//  GenieMeditationService.swift
//  Do
//
//  Guided meditation generator and player for Genie
//

import Foundation
import AVFoundation

@MainActor
class GenieMeditationService: ObservableObject {
    static let shared = GenieMeditationService()
    
    // MARK: - Published Properties
    @Published var isGenerating = false
    @Published var isPlaying = false
    @Published var currentSegment = 0
    @Published var totalSegments = 0
    @Published var progress: Double = 0
    @Published var currentScript: MeditationScript?
    @Published var currentLibraryMeditationId: String? // Track if this is from library
    
    // MARK: - Callbacks
    var onMeditationComplete: ((Bool) -> Void)? // Called when meditation ends (completed or cancelled)
    var onMeditationStart: ((MeditationScript, String?) -> Void)? // Called when meditation starts (script, libraryId)
    
    // MARK: - Private Properties
    private var meditationSegments: [String] = []
    private var currentSegmentIndex = 0
    private var timer: Timer?
    private var startTime: Date?
    
    private init() {}
    
    // MARK: - Meditation Generation
    
    func generateMeditation(
        duration: Int = 10, // minutes
        focus: MeditationFocus = .stress,
        userContext: String? = nil
    ) async throws -> MeditationScript {
        isGenerating = true
        defer { isGenerating = false }
        
        // Build personalized meditation prompt
        let prompt = buildMeditationPrompt(duration: duration, focus: focus, userContext: userContext)
        
        // Generate meditation script using Genie
        let response = try await GenieAPIService.shared.query(prompt)
        
        // Parse meditation script
        let script = parseMeditationScript(response.response, duration: duration, focus: focus)
        
        currentScript = script
        return script
    }
    
    private func buildMeditationPrompt(duration: Int, focus: MeditationFocus, userContext: String?) -> String {
        var prompt = """
        Create a guided meditation script for a \(duration)-minute session focused on \(focus.rawValue).
        
        """
        
        if let context = userContext {
            prompt += "User context: \(context)\n\n"
        }
        
        prompt += """
        Structure the meditation with these segments:
        1. Welcome and settling (1 minute)
        2. Breathing exercises (2-3 minutes)
        3. Body scan or visualization (main portion)
        4. Deepening relaxation
        5. Gentle return and closing
        
        IMPORTANT - PAUSE MARKERS:
        After EVERY action or instruction completes, add [PAUSE: X seconds] marker to allow time for the listener to follow.
        
        Examples:
        - "Find a comfortable position. [PAUSE: 2s] Feel the gentle support of the ground beneath you. [PAUSE: 2s]"
        - "Take a deep breath in... [PAUSE: 3s] and slowly release. [PAUSE: 2s]"
        - "Allow your body to settle into the present moment. [PAUSE: 2s] Notice the rhythm of your breath. [PAUSE: 2s]"
        
        Use [PAUSE: 1-2s] after short instructions, [PAUSE: 3-5s] after breathing exercises or longer actions.
        
        Format each segment clearly with [SEGMENT: name] markers.
        
        Use calming, present-tense language. Make it personal, encouraging, and deeply relaxing.
        """
        
        return prompt
    }
    
    private func parseMeditationScript(_ text: String, duration: Int, focus: MeditationFocus) -> MeditationScript {
        // Split into segments
        let segments = text.components(separatedBy: "[SEGMENT:")
            .dropFirst()
            .map { segment -> MeditationSegment in
                let parts = segment.components(separatedBy: "]")
                let name = parts[0].trimmingCharacters(in: .whitespaces)
                let content = parts.dropFirst().joined(separator: "]").trimmingCharacters(in: .whitespacesAndNewlines)
                
                return MeditationSegment(name: name, content: content)
            }
        
        return MeditationScript(
            duration: duration,
            focus: focus,
            segments: segments.isEmpty ? [MeditationSegment(name: "Full Session", content: text)] : segments
        )
    }
    
    // MARK: - Meditation Playback
    
    func startMeditation(_ script: MeditationScript, libraryMeditationId: String? = nil) {
        currentScript = script
        currentLibraryMeditationId = libraryMeditationId
        currentSegmentIndex = 0
        totalSegments = script.segments.count
        isPlaying = true
        progress = 0
        startTime = Date()
        
        // Notify that meditation started
        onMeditationStart?(script, libraryMeditationId)
        
        playNextSegment()
    }
    
    private func playNextSegment() {
        guard let script = currentScript,
              currentSegmentIndex < script.segments.count else {
            // All segments finished - complete naturally
            endMeditation(completed: true)
            return
        }
        
        // Combine all remaining segments into full script for better audio generation
        // This creates one continuous high-quality Polly audio file
        let remainingScript = script.segments[currentSegmentIndex..<script.segments.count]
            .map { $0.content }
            .joined(separator: "\n\n")
        
        currentSegment = currentSegmentIndex + 1
        
        print("🧘 [Meditation] Playing meditation with Polly TTS: segment \(currentSegment)/\(totalSegments)")
        
        // Use MeditationAudioService which handles Polly TTS generation automatically
        MeditationAudioService.shared.playMeditationAudio(
            audioUrl: nil, // Will generate using Polly TTS
            script: remainingScript,
            voiceType: .female, // Calm female voice for meditations
            ambientType: selectAmbientTypeForFocus(script.focus)
        )
        
        // Mark all remaining segments as played since we're playing them all as one audio
        currentSegmentIndex = script.segments.count
        
        // Monitor playback completion via MeditationAudioService
        timer?.invalidate()
        
        // Wait for audio to start (Polly generation may take a moment), then monitor completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, let script = self.currentScript else { return }
            
            // Update progress over time based on estimated duration
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard let self = self, let script = self.currentScript else {
                    timer.invalidate()
                    return
                }
                
                // Check if MeditationAudioService has finished playing
                if !MeditationAudioService.shared.isSpeaking {
                    timer.invalidate()
                    
                    // Audio finished - complete meditation
                    self.progress = 1.0
                    self.endMeditation(completed: true)
                } else {
                    // Update progress based on elapsed time
                    let elapsed = Date().timeIntervalSince(self.startTime ?? Date())
                    let totalEstimated = Double(script.duration * 60) // Convert minutes to seconds
                    self.progress = min(1.0, elapsed / totalEstimated)
                }
            }
        }
    }
    
    func pauseMeditation() {
        isPlaying = false
        timer?.invalidate()
        MeditationAudioService.shared.pauseSpeaking()
    }
    
    func resumeMeditation() {
        isPlaying = true
        MeditationAudioService.shared.resumeSpeaking()
    }
    
    func stopMeditation() {
        endMeditation(completed: false)
    }
    
    func completeMeditation() {
        endMeditation(completed: true)
    }
    
    private func endMeditation(completed: Bool) {
        let wasPlaying = isPlaying
        isPlaying = false
        timer?.invalidate()
        timer = nil
        
        // Stop meditation audio (Polly TTS or iOS TTS)
        MeditationAudioService.shared.stopSpeaking()
        
        // Stop ambient background audio for complete orchestration
        AmbientAudioService.shared.stopAmbientSound()
        
        if completed {
            progress = 1.0
        }
        
        // Notify completion
        if wasPlaying {
            onMeditationComplete?(completed)
        }
        
        print("🧘 [Meditation] Session \(completed ? "completed" : "stopped")")
        print("🛑 [Meditation] All audio stopped")
        
        // Clear state after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.currentScript = nil
            self?.currentLibraryMeditationId = nil
            self?.startTime = nil
        }
    }
    
    // MARK: - Helper Functions
    
    /// Select ambient sound type based on meditation focus
    private func selectAmbientTypeForFocus(_ focus: MeditationFocus) -> AmbientSoundType {
        switch focus {
        case .stress, .anxiety:
            return .ocean
        case .sleep:
            return .rain
        case .focus:
            return .zen
        case .energy, .recovery:
            return .forest
        case .breathing, .bodyScan, .visualization:
            return .zen
        case .gratitude:
            return .forest
        default:
            return .ocean
        }
    }
    
    // MARK: - Quick Meditations
    
    func quickBreathingExercise() async throws {
        let script = MeditationScript(
            duration: 3,
            focus: .breathing,
            segments: [
                MeditationSegment(
                    name: "Box Breathing",
                    content: """
                    Let's do a quick breathing exercise together.
                    
                    Find a comfortable position and close your eyes if you'd like.
                    
                    Breathe in slowly through your nose for 4 counts... 1, 2, 3, 4.
                    
                    Hold your breath for 4 counts... 1, 2, 3, 4.
                    
                    Exhale slowly through your mouth for 4 counts... 1, 2, 3, 4.
                    
                    Hold empty for 4 counts... 1, 2, 3, 4.
                    
                    Let's do this three more times together.
                    
                    Breathe in... 2, 3, 4. Hold... 2, 3, 4. Breathe out... 2, 3, 4. Hold... 2, 3, 4.
                    
                    Again. Breathe in... 2, 3, 4. Hold... 2, 3, 4. Breathe out... 2, 3, 4. Hold... 2, 3, 4.
                    
                    One more time. Breathe in... 2, 3, 4. Hold... 2, 3, 4. Breathe out... 2, 3, 4. Hold... 2, 3, 4.
                    
                    Beautiful. Return to your natural breath. Notice how calm and centered you feel.
                    
                    When you're ready, gently open your eyes.
                    """
                )
            ]
        )
        
        startMeditation(script)
    }
}
