//
//  BedtimeStoryView.swift
//  Do
//
//  Displays a bedtime story with optional audio playback
//

import SwiftUI

struct BedtimeStoryView: View {
    let story: BedtimeStoryAction
    @Environment(\.dismiss) var dismiss
    @StateObject private var audioService = MeditationAudioService.shared
    @State private var isPlaying = false
    @State private var showGetStarted = true
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(hex: "0F163E"), location: 0),
                        .init(color: Color(hex: "1A1F3A"), location: 0.5),
                        .init(color: Color(hex: "0F163E"), location: 1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text(story.title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 16) {
                                Label("\(story.duration) min", systemImage: "clock")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                if !story.audience.isEmpty {
                                    Label(story.audience, systemImage: "person.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                if !story.tone.isEmpty {
                                    Label(story.tone, systemImage: "heart.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Story Content
                        VStack(alignment: .leading, spacing: 16) {
                            Text(story.story)
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(.white)
                                .lineSpacing(8)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        
                        // Get Started Button (shown initially)
                        if showGetStarted {
                            Button(action: {
                                showGetStarted = false
                                startStory()
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Get Started")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.doOrange)
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        }
                        
                        // Audio Controls (shown when playing)
                        if !showGetStarted {
                            HStack(spacing: 20) {
                                Button(action: {
                                    if isPlaying {
                                        audioService.pauseSpeaking()
                                    } else {
                                        audioService.resumeSpeaking()
                                    }
                                    isPlaying.toggle()
                                }) {
                                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                        .frame(width: 60, height: 60)
                                        .background(
                                            Circle()
                                                .fill(Color.doOrange.opacity(0.2))
                                        )
                                }
                                
                                Button(action: {
                                    audioService.stopSpeaking()
                                    isPlaying = false
                                }) {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                        .frame(width: 60, height: 60)
                                        .background(
                                            Circle()
                                                .fill(Color.white.opacity(0.1))
                                        )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        audioService.stopSpeaking()
                        dismiss()
                    }
                    .foregroundColor(.doOrange)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .meditationAudioDidFinish)) { _ in
                isPlaying = false
            }
            .onDisappear {
                audioService.stopSpeaking()
            }
        }
    }
    
    private func startStory() {
        if story.playAudio, let audioUrl = story.audioUrl, !audioUrl.isEmpty {
            // Play audio from URL
            audioService.playMeditationAudio(
                audioUrl: audioUrl,
                script: story.story,
                voiceType: .female,
                ambientType: story.ambientSoundType
            )
        } else {
            // Fallback to TTS
            audioService.speakMeditationScript(
                story.story,
                voiceType: .female,
                ambientType: story.ambientSoundType
            )
        }
        isPlaying = true
    }
}

