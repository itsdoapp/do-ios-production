//
//  AudioManager.swift
//  Do
//

import Foundation
import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    
    private var audioPlayer: AVAudioPlayer?
    
    private init() {}
    
    enum AmbientSound: String, CaseIterable {
        case forest = "ambient_forest"
        case ocean = "ambient_ocean"
        case rain = "ambient_rain"
        case zenBowls = "ambient_zen_bowls"
        case zenChimes = "ambient_zen_chimes"
        case zen = "ambient_zen"
        case motivationEnergetic = "ambient_motivation_energetic"
        case motivationEpic = "ambient_motivation_epic"
        case motivationUplifting = "ambient_motivation_uplifting"
        case noiseBrown = "ambient_noise_brown"
        case noisePink = "ambient_noise_pink"
        case noiseWhite = "ambient_noise_white"
        case storyCalm = "ambient_story_calm"
        case storyDreamy = "ambient_story_dreamy"
        case storyPeaceful = "ambient_story_peaceful"
        
        var displayName: String {
            switch self {
            case .forest: return "Forest"
            case .ocean: return "Ocean Waves"
            case .rain: return "Rain"
            case .zenBowls: return "Zen Bowls"
            case .zenChimes: return "Zen Chimes"
            case .zen: return "Zen"
            case .motivationEnergetic: return "Energetic"
            case .motivationEpic: return "Epic"
            case .motivationUplifting: return "Uplifting"
            case .noiseBrown: return "Brown Noise"
            case .noisePink: return "Pink Noise"
            case .noiseWhite: return "White Noise"
            case .storyCalm: return "Calm Story"
            case .storyDreamy: return "Dreamy Story"
            case .storyPeaceful: return "Peaceful Story"
            }
        }
    }
    
    func play(_ sound: AmbientSound, loop: Bool = true) {
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3", subdirectory: "AmbientSounds") else {
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = loop ? -1 : 0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            // Silently fail
        }
    }
    
    func pause() {
        audioPlayer?.pause()
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    func setVolume(_ volume: Float) {
        audioPlayer?.volume = min(max(volume, 0.0), 1.0)
    }
    
    var isPlaying: Bool {
        return audioPlayer?.isPlaying ?? false
    }
    
    var currentTime: TimeInterval {
        return audioPlayer?.currentTime ?? 0
    }
    
    var duration: TimeInterval {
        return audioPlayer?.duration ?? 0
    }
}
