//
//  MeditationTrackingService.swift
//  Do
//
//  Enterprise-grade meditation tracking with database integration
//

import Foundation
import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

@MainActor
class MeditationTrackingService: ObservableObject {
    static let shared = MeditationTrackingService()
    
    @Published var activeSessions: [MeditationSession] = []
    @Published var todaysMinutes: Int = 0
    @Published var currentStreak: Int = 0
    @Published var weeklyStats: WeeklyMeditationStats?
    @Published var isLoading = false
    
    private var currentSession: MeditationSession?
    private var sessionTimer: Timer?
    
    // Lock screen media player
    private var commandCenter: MPRemoteCommandCenter?
    private var playCommandHandler: Any?
    private var pauseCommandHandler: Any?
    private var stopCommandHandler: Any?
    private var isPaused: Bool = false
    private var pauseStartTime: Date?
    private var totalPausedTime: TimeInterval = 0
    
    // Silent audio engine for lock screen (needed for manual meditations without audio)
    private var silentAudioEngine: AVAudioEngine?
    private var silentPlayerNode: AVAudioPlayerNode?
    
    // Active meditation info (for AI-generated meditations from action handler)
    private var activeMeditationTitle: String?
    private var activeMeditationDuration: TimeInterval?
    private var activeMeditationStartTime: Date?
    private var activeMeditationTimer: Timer?
    private var activeMeditationFocus: String?
    private var activeMeditationArtwork: MPMediaItemArtwork?
    private var lastCategoryCheckTime: Date = Date()
    
    // Public getter for current session
    var activeSession: MeditationSession? {
        return currentSession
    }
    
    var hasActiveSession: Bool {
        return currentSession != nil || activeMeditationTitle != nil
    }
    
    private init() {
        loadTodaysSessions()
        calculateStreak()
        setupLockScreenControls()
        setupMeditationAudioObservers()
        setupAppStateObservers()
    }
    
    private func setupAppStateObservers() {
        // Observe app going to background to ensure audio session stays active
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // Observe app becoming active to refresh lock screen if needed
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppDidEnterBackground() {
        // When app goes to background, ensure audio session is active for lock screen
        if activeMeditationTitle != nil {
            print("📱 [Meditation] App entered background - ensuring audio session is active for lock screen")
            do {
                let audioSession = AVAudioSession.sharedInstance()
                // Ensure audio session is active with .playback category
                if audioSession.category != .playback || audioSession.mode != .default {
                    try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetooth])
                }
                // CRITICAL: Activate audio session with options to allow background playback
                try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
                
                // Force update lock screen info immediately when going to background
                // This ensures iOS sees the media info when the lock screen appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Update with current playback state
                    self.updateActiveMeditationLockScreen()
                    
                    // Force set NowPlayingInfo again to ensure iOS sees it
                    if let title = self.activeMeditationTitle,
                       let duration = self.activeMeditationDuration {
                        var nowPlayingInfo: [String: Any] = [
                            MPMediaItemPropertyTitle: title,
                            MPMediaItemPropertyArtist: "Do",
                            MPNowPlayingInfoPropertyElapsedPlaybackTime: MeditationAudioService.shared.currentPlaybackTime,
                            MPMediaItemPropertyPlaybackDuration: duration,
                            MPNowPlayingInfoPropertyPlaybackRate: MeditationAudioService.shared.isPaused ? 0.0 : 1.0
                        ]
                        if let artwork = self.activeMeditationArtwork {
                            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                        }
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                        print("📱 [Meditation] NowPlayingInfo force-set in background")
                    }
                    
                    // Double-check that NowPlayingInfo is set
                    if let info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                        print("📱 [Meditation] NowPlayingInfo confirmed in background: \(info.keys)")
                        print("📱 [Meditation] Playback rate: \(info[MPNowPlayingInfoPropertyPlaybackRate] ?? "nil")")
                        print("📱 [Meditation] AVPlayer rate: \(MeditationAudioService.shared.playerRate)")
                    } else {
                        print("❌ [Meditation] WARNING: NowPlayingInfo is nil in background!")
                    }
                }
                
                print("📱 [Meditation] Audio session kept active for background playback")
            } catch {
                print("❌ [Meditation] Failed to keep audio session active: \(error.localizedDescription)")
            }
        }
    }
    
    @objc private func handleAppDidBecomeActive() {
        // When app becomes active, refresh lock screen info
        if activeMeditationTitle != nil {
            print("📱 [Meditation] App became active - refreshing lock screen")
            updateActiveMeditationLockScreen()
        }
    }
    
    private func setupMeditationAudioObservers() {
        // Observe when meditation audio is ready to play
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MeditationAudioReady"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Audio is ready - ensure lock screen is set up and updated
            if let title = self?.activeMeditationTitle,
               let duration = self?.activeMeditationDuration {
                print("📱 [Meditation] Audio ready - ensuring lock screen is set up")
                // Reconfigure audio session to .playback for lock screen
                self?.ensurePlaybackCategory()
                // Update lock screen info
                self?.updateActiveMeditationLockScreen()
            }
        }
        
        // Observe when meditation audio actually starts playing (rate > 0)
        // This is critical - iOS only shows lock screen when audio is actually playing
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MeditationAudioPlaying"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Audio is actually playing - ensure lock screen is properly configured
            if let title = self?.activeMeditationTitle,
               let duration = self?.activeMeditationDuration {
                print("📱 [Meditation] Audio playing - finalizing lock screen setup")
                
                // CRITICAL: Ensure audio session is .playback (required for lock screen)
                // Do this AFTER audio starts playing to ensure it sticks
                self?.ensurePlaybackCategory()
                
                // Wait a moment for audio session to settle, then update lock screen
                // CRITICAL: iOS requires audio to actually be playing before lock screen appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Ensure audio session is still active and in correct mode
                    let audioSession = AVAudioSession.sharedInstance()
                    if audioSession.category != .playback || audioSession.mode != .default {
                        self?.ensurePlaybackCategory()
                    }
                    
                    // Force update lock screen with current playback info
                    self?.updateActiveMeditationLockScreen()
                    
                    // Also ensure MPNowPlayingInfoCenter has the info with rate=1.0
                    // CRITICAL: iOS requires all these properties to be set correctly
                    var nowPlayingInfo: [String: Any] = [
                        MPMediaItemPropertyTitle: title,
                        MPMediaItemPropertyArtist: "Do",
                        MPNowPlayingInfoPropertyElapsedPlaybackTime: MeditationAudioService.shared.currentPlaybackTime,
                        MPMediaItemPropertyPlaybackDuration: duration,
                        MPNowPlayingInfoPropertyPlaybackRate: 1.0 // Now playing!
                    ]
                    if let artwork = self?.activeMeditationArtwork {
                        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                    }
                    
                    // CRITICAL: Set NowPlayingInfo AFTER ensuring audio session is active
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                    print("📱 [Meditation] Lock screen finalized with playing state (rate=1.0)")
                    print("📱 [Meditation] NowPlayingInfo keys: \(nowPlayingInfo.keys)")
                    
                    // Double-check audio session category and verify AVPlayer is playing
                    print("📱 [Meditation] Audio session category: \(audioSession.category.rawValue), mode: \(audioSession.mode.rawValue)")
                    print("📱 [Meditation] Audio session isActive: \(audioSession.isOtherAudioPlaying ? "other playing" : "active")")
                    print("📱 [Meditation] MeditationAudioService isSpeaking: \(MeditationAudioService.shared.isSpeaking)")
                    print("📱 [Meditation] MeditationAudioService isPaused: \(MeditationAudioService.shared.isPaused)")
                    print("📱 [Meditation] AVPlayer rate: \(MeditationAudioService.shared.playerRate)")
                    print("📱 [Meditation] Current playback time: \(MeditationAudioService.shared.currentPlaybackTime)")
                    
                    // CRITICAL: Verify AVPlayer is actually playing (rate > 0)
                    if MeditationAudioService.shared.playerRate <= 0 {
                        print("⚠️ [Meditation] WARNING: AVPlayer rate is 0 - audio may not be playing!")
                    }
                    
                    // Force one more update after a short delay to ensure iOS sees it
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                        print("📱 [Meditation] Lock screen info refreshed (final check)")
                    }
                    
                    print("📱 [Meditation] ⚠️ IMPORTANT: Lock screen will ONLY appear when device is LOCKED or app is BACKGROUNDED")
                }
            }
        }
    }
    
    private func ensurePlaybackCategory() {
        // Ensure audio session is using .playback category with .default mode (required for lock screen)
        // MeditationAudioService might use .spokenAudio which doesn't show lock screen
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Only reconfigure if it's not already correct to avoid excessive reconfiguration
            if audioSession.category != .playback || audioSession.mode != .default {
                // Force set to .playback with .default mode (not .spokenAudio)
                // This is required for lock screen media player to appear
                try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetooth])
                
                // Only activate if not already active to avoid conflicts
                if !audioSession.isOtherAudioPlaying {
                    try audioSession.setActive(true, options: [])
                }
                print("📱 [Meditation] Audio session reconfigured to .playback/.default for lock screen")
            }
        } catch {
            print("❌ [Meditation] Failed to reconfigure audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Manual Meditation Tracking
    
    func startSession(
        type: MeditationType,
        duration: TimeInterval,
        guided: Bool = false,
        notes: String? = nil
    ) {
        let session = MeditationSession(
            id: UUID().uuidString,
            userId: getCurrentUserId(),
            type: type,
            plannedDuration: duration,
            guided: guided,
            notes: notes,
            startTime: Date(),
            source: .manual
        )
        
        currentSession = session
        isPaused = false
        pauseStartTime = nil
        totalPausedTime = 0
        
        // Configure audio session for lock screen media player
        setupAudioSession()
        
        // Setup lock screen media player
        setupLockScreenForSession(session: session)
        
        // Start timer
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSessionDuration()
        }
        
        print("🧘 [Meditation] Started: \(type.name) - \(Int(duration/60))min")
    }
    
    func completeSession(rating: Int? = nil, notes: String? = nil) async throws {
        guard var session = currentSession else { return }
        
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        // If currently paused, add the current pause duration to total
        if isPaused, let pauseStart = pauseStartTime {
            let pausedDuration = Date().timeIntervalSince(pauseStart)
            totalPausedTime += pausedDuration
        }
        
        session.endTime = Date()
        // Calculate actual duration accounting for paused time
        session.actualDuration = session.endTime!.timeIntervalSince(session.startTime) - totalPausedTime
        session.completed = true
        session.rating = rating
        if let notes = notes {
            session.notes = notes
        }
        
        // Save locally
        activeSessions.append(session)
        saveToLocalStorage(session)
        
        // Save to DynamoDB
        try await saveToDynamoDB(session)
        
        // Update stats
        await updateStats()
        
        // Update user learning
        await GenieUserLearningService.shared.updateUserLearning(
            activity: "meditation",
            data: session.toDictionary()
        )
        
        // Stop all meditation audio when session completes
        // This ensures clean orchestration - all audio stops when session completes
        Task { @MainActor in
            MeditationAudioService.shared.stopSpeaking()
            AmbientAudioService.shared.stopAmbientSound()
            print("🛑 [MeditationTracking] All audio stopped after session completion")
        }
        
        // Clean up lock screen
        cleanupLockScreen()
        
        currentSession = nil
        
        print("✅ [Meditation] Completed: \(session.type) - \(Int(session.actualDuration/60))min")
    }
    
    func cancelSession() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        // Stop all meditation audio when session is cancelled
        Task { @MainActor in
            MeditationAudioService.shared.stopSpeaking()
            AmbientAudioService.shared.stopAmbientSound()
            print("🛑 [MeditationTracking] All audio stopped after session cancellation")
        }
        
        // Clean up lock screen
        cleanupLockScreen()
        
        currentSession = nil
        print("❌ [Meditation] Cancelled")
    }
    
    // MARK: - AI Meditation Tracking
    
    func logAIMeditation(
        focus: MeditationFocus,
        duration: TimeInterval,
        script: MeditationScript,
        completed: Bool
    ) async throws {
        // Create descriptive note with category, intention, and duration
        let intention = focus.rawValue.capitalized
        let durationText = "\(Int(duration/60)) min"
        let notes = "\(intention) • \(durationText)"
        
        let session = MeditationSession(
            id: UUID().uuidString,
            userId: getCurrentUserId(),
            type: mapFocusToType(focus),
            plannedDuration: duration,
            actualDuration: completed ? duration : 0,
            guided: true,
            notes: notes,
            startTime: Date(),
            endTime: completed ? Date().addingTimeInterval(duration) : nil,
            completed: completed,
            source: .ai,
            aiGenerated: true,
            scriptId: UUID().uuidString
        )
        
        // Save locally
        activeSessions.append(session)
        saveToLocalStorage(session)
        
        // Save to DynamoDB
        try await saveToDynamoDB(session)
        
        // Update stats
        await updateStats()
        
        // Update user learning
        await GenieUserLearningService.shared.updateUserLearning(
            activity: "meditation",
            data: session.toDictionary()
        )
        
        // Stop all meditation audio when logging completes
        // This ensures clean orchestration - all audio stops when session is logged
        Task { @MainActor in
            MeditationAudioService.shared.stopSpeaking()
            AmbientAudioService.shared.stopAmbientSound()
            print("🛑 [MeditationTracking] All audio stopped after logging session")
        }
        
        print("✅ [AI Meditation] Logged: \(focus.rawValue) - \(Int(duration/60))min")
    }
    
    // MARK: - Library Meditation Tracking
    
    func logLibraryMeditation(
        libraryMeditationId: String,
        title: String,
        category: String,
        focus: MeditationFocus,
        duration: TimeInterval,
        startTime: Date,
        endTime: Date?,
        completed: Bool
    ) async throws {
        // Create descriptive note with category, title, and duration
        let durationText = "\(Int(duration/60)) min"
        let notes = "\(category) • \(durationText)"
        
        let session = MeditationSession(
            id: UUID().uuidString,
            userId: getCurrentUserId(),
            type: mapFocusToType(focus),
            plannedDuration: duration,
            actualDuration: completed ? (endTime?.timeIntervalSince(startTime) ?? duration) : 0,
            guided: true,
            notes: notes,
            startTime: startTime,
            endTime: endTime,
            completed: completed,
            source: .ai, // Using .ai for library meditations too since they're guided
            aiGenerated: true,
            scriptId: libraryMeditationId // Store library ID as scriptId
        )
        
        // Save locally
        activeSessions.append(session)
        saveToLocalStorage(session)
        
        // Save to DynamoDB
        try await saveToDynamoDB(session)
        
        // Update stats
        await updateStats()
        
        // Update user learning
        await GenieUserLearningService.shared.updateUserLearning(
            activity: "meditation",
            data: session.toDictionary()
        )
        
        // Stop all meditation audio when logging completes
        // This ensures clean orchestration - all audio stops when session is logged
        Task { @MainActor in
            MeditationAudioService.shared.stopSpeaking()
            AmbientAudioService.shared.stopAmbientSound()
            print("🛑 [MeditationTracking] All audio stopped after logging library meditation")
        }
        
        print("✅ [Library Meditation] Logged: \(title) - \(Int(duration/60))min - \(completed ? "completed" : "incomplete")")
    }
    
    // MARK: - History & Analytics
    
    func getSessionHistory(days: Int = 30) async throws -> [MeditationSession] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return try await fetchFromDynamoDB(startDate: startDate)
    }
    
    func getMeditationTrends(days: Int = 7) async throws -> MeditationTrends {
        let history = try await getSessionHistory(days: days)
        return calculateTrends(from: history)
    }
    
    func getMeditationInsights() async throws -> MeditationInsights {
        let history = try await getSessionHistory(days: 90)
        return generateInsights(from: history)
    }
    
    // MARK: - Streaks & Achievements
    
    func calculateStreak() {
        let sessions = loadAllFromLocalStorage()
        let calendar = Calendar.current
        
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        while true {
            let hasMeditation = sessions.contains { session in
                calendar.isDate(session.startTime, inSameDayAs: currentDate)
            }
            
            if hasMeditation {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }
        
        currentStreak = streak
    }
    
    func getAchievements() -> [MeditationAchievement] {
        let sessions = loadAllFromLocalStorage()
        var achievements: [MeditationAchievement] = []
        
        // Total sessions
        if sessions.count >= 1 {
            achievements.append(.firstSession)
        }
        if sessions.count >= 7 {
            achievements.append(.weekWarrior)
        }
        if sessions.count >= 30 {
            achievements.append(.monthMaster)
        }
        if sessions.count >= 100 {
            achievements.append(.centurion)
        }
        
        // Streak achievements
        if currentStreak >= 3 {
            achievements.append(.threeDayStreak)
        }
        if currentStreak >= 7 {
            achievements.append(.weekStreak)
        }
        if currentStreak >= 30 {
            achievements.append(.monthStreak)
        }
        
        // Total minutes
        let totalMinutes = sessions.reduce(0) { $0 + Int($1.actualDuration / 60) }
        if totalMinutes >= 60 {
            achievements.append(.hourOfPeace)
        }
        if totalMinutes >= 600 {
            achievements.append(.tenHours)
        }
        
        return achievements
    }
    
    // MARK: - Database Operations
    
    private func saveToDynamoDB(_ session: MeditationSession) async throws {
        // Save to prod-meditation table via API
        let data = session.toDictionary()
        await GenieUserLearningService.shared.updateUserLearning(
            activity: "meditation_detailed",
            data: data
        )
        
        // Extract focus from notes if available (format: "Focus • 10 min")
        let focus: String? = {
            if let notes = session.notes, notes.contains("•") {
                let parts = notes.components(separatedBy: "•")
                if !parts.isEmpty {
                    return parts[0].trimmingCharacters(in: .whitespaces)
                }
            }
            return nil
        }()
        
        // Save to backend
        let sessionData = MeditationSessionData(
            sessionId: session.id,
            type: session.type,
            focus: focus,
            duration: Int(session.plannedDuration),
            actualDuration: Int(session.actualDuration),
            guided: session.guided,
            completed: session.completed,
            rating: session.rating,
            notes: session.notes,
            aiGenerated: session.aiGenerated,
            scriptId: session.scriptId,
            startTime: ISO8601DateFormatter().string(from: session.startTime),
            endTime: session.endTime.map { ISO8601DateFormatter().string(from: $0) }
        )
        
        try await GenieAPIService.shared.saveMeditationSession(sessionData)
        print("✅ [Meditation] Saved to DynamoDB via API")
    }
    
    private func fetchFromDynamoDB(startDate: Date) async throws -> [MeditationSession] {
        // Load from local storage for now
        return loadFromLocalStorage(startDate: startDate)
    }
    
    // MARK: - Local Storage
    
    private func saveToLocalStorage(_ session: MeditationSession) {
        var sessions = loadAllFromLocalStorage()
        sessions.insert(session, at: 0)
        
        // Keep last 500 sessions
        if sessions.count > 500 {
            sessions = Array(sessions.prefix(500))
        }
        
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "meditationSessions")
        }
    }
    
    func loadAllFromLocalStorage() -> [MeditationSession] {
        guard let data = UserDefaults.standard.data(forKey: "meditationSessions"),
              let sessions = try? JSONDecoder().decode([MeditationSession].self, from: data) else {
            return []
        }
        return sessions
    }
    
    private func loadFromLocalStorage(startDate: Date) -> [MeditationSession] {
        let all = loadAllFromLocalStorage()
        return all.filter { $0.startTime >= startDate }
    }
    
    private func loadTodaysSessions() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        activeSessions = loadFromLocalStorage(startDate: today)
        
        todaysMinutes = activeSessions.reduce(0) { $0 + Int($1.actualDuration / 60) }
    }
    
    // MARK: - Analytics
    
    private func updateStats() async {
        loadTodaysSessions()
        calculateStreak()
        
        // Calculate weekly stats
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let weeklySessions = loadFromLocalStorage(startDate: weekAgo)
        
        let totalMinutes = weeklySessions.reduce(0) { $0 + Int($1.actualDuration / 60) }
        let completedSessions = weeklySessions.filter { $0.completed }.count
        
        weeklyStats = WeeklyMeditationStats(
            totalSessions: weeklySessions.count,
            completedSessions: completedSessions,
            totalMinutes: totalMinutes,
            averageMinutesPerDay: Double(totalMinutes) / 7.0,
            consistency: Double(completedSessions) / Double(max(weeklySessions.count, 1))
        )
    }
    
    private func calculateTrends(from history: [MeditationSession]) -> MeditationTrends {
        let groupedByDay = Dictionary(grouping: history) { session in
            Calendar.current.startOfDay(for: session.startTime)
        }
        
        let dailyMinutes = groupedByDay.map { date, sessions in
            (date, sessions.reduce(0) { $0 + Int($1.actualDuration / 60) })
        }.sorted { $0.0 < $1.0 }
        
        let avgMinutes = dailyMinutes.isEmpty ? 0 : dailyMinutes.reduce(0) { $0 + $1.1 } / dailyMinutes.count
        
        let typeDistribution = Dictionary(grouping: history) { $0.type }
            .mapValues { $0.count }
        
        return MeditationTrends(
            averageMinutesPerDay: avgMinutes,
            totalSessions: history.count,
            completionRate: Double(history.filter { $0.completed }.count) / Double(max(history.count, 1)),
            dailyMinutes: dailyMinutes,
            typeDistribution: typeDistribution,
            consistency: Double(groupedByDay.count) / 7.0
        )
    }
    
    private func generateInsights(from history: [MeditationSession]) -> MeditationInsights {
        let totalMinutes = history.reduce(0) { $0 + Int($1.actualDuration / 60) }
        let completedSessions = history.filter { $0.completed }
        
        let favoriteType = Dictionary(grouping: history) { $0.type }
            .max(by: { $0.value.count < $1.value.count })?.key
        
        let bestTimeOfDay = findBestTimeOfDay(from: history)
        let averageRating = history.compactMap { $0.rating }.reduce(0, +) / max(history.compactMap { $0.rating }.count, 1)
        
        return MeditationInsights(
            totalMinutes: totalMinutes,
            totalSessions: history.count,
            completedSessions: completedSessions.count,
            favoriteType: favoriteType,
            bestTimeOfDay: bestTimeOfDay,
            averageRating: Double(averageRating),
            longestStreak: calculateLongestStreak(from: history),
            currentStreak: currentStreak
        )
    }
    
    private func findBestTimeOfDay(from history: [MeditationSession]) -> String {
        let calendar = Calendar.current
        let timeGroups = Dictionary(grouping: history) { session -> String in
            let hour = calendar.component(.hour, from: session.startTime)
            if hour < 12 { return "Morning" }
            if hour < 17 { return "Afternoon" }
            return "Evening"
        }
        
        return timeGroups.max(by: { $0.value.count < $1.value.count })?.key ?? "Morning"
    }
    
    private func calculateLongestStreak(from history: [MeditationSession]) -> Int {
        let calendar = Calendar.current
        let sortedSessions = history.sorted { $0.startTime < $1.startTime }
        
        var longestStreak = 0
        var currentStreakCount = 0
        var lastDate: Date?
        
        for session in sortedSessions {
            let sessionDate = calendar.startOfDay(for: session.startTime)
            
            if let last = lastDate {
                let daysDiff = calendar.dateComponents([.day], from: last, to: sessionDate).day ?? 0
                
                if daysDiff == 1 {
                    currentStreakCount += 1
                } else if daysDiff > 1 {
                    longestStreak = max(longestStreak, currentStreakCount)
                    currentStreakCount = 1
                }
            } else {
                currentStreakCount = 1
            }
            
            lastDate = sessionDate
        }
        
        return max(longestStreak, currentStreakCount)
    }
    
    private func updateSessionDuration() {
        guard let session = currentSession else { return }
        
        // Calculate elapsed time accounting for paused time
        let elapsedTime = Date().timeIntervalSince(session.startTime) - totalPausedTime
        updateLockScreenInfo(elapsedTime: elapsedTime, isPaused: isPaused)
    }
    
    private func mapFocusToType(_ focus: MeditationFocus) -> MeditationType {
        // Map MeditationFocus to existing MeditationType enum
        // Available types: mindfulness, breathing, sleep, focus, stress
        switch focus {
        case .stress: return .stress
        case .sleep: return .sleep
        case .focus: return .focus
        case .anxiety: return .stress
        case .breathing: return .breathing
        case .bodyScan: return .mindfulness
        case .visualization: return .mindfulness
        case .gratitude: return .mindfulness
        case .energy: return .focus
        case .recovery: return .mindfulness
        }
    }
    
    /// Map focus string to LockScreenCharacterType for artwork
    private func mapFocusToCharacterType(_ focus: String) -> LockScreenCharacterType {
        let lowerFocus = focus.lowercased()
        if lowerFocus.contains("sleep") {
            return .sleep
        } else if lowerFocus.contains("focus") || lowerFocus.contains("productivity") || lowerFocus.contains("performance") || lowerFocus.contains("energy") {
            return .focus
        } else if lowerFocus.contains("stress") || lowerFocus.contains("anxiety") {
            return .stress
        } else if lowerFocus.contains("breathe") || lowerFocus.contains("breathing") {
            return .breathing
        } else if lowerFocus.contains("gratitude") || lowerFocus.contains("happiness") {
            return .gratitude
        } else if lowerFocus.contains("performance") || lowerFocus.contains("energy") {
            return .performance
        } else if lowerFocus.contains("healing") || lowerFocus.contains("recovery") {
            return .recovery
        }
        return .default
    }
    
    /// Create MPMediaItemArtwork from meditation character view
    private func createMeditationArtwork(for focus: String) -> MPMediaItemArtwork? {
        let characterType = mapFocusToCharacterType(focus)
        
        // Create character view
        let characterView = LockScreenCharacterArtworkView(characterType: characterType)
        
        // Render to UIImage
        guard let image = renderViewToImage(characterView) else {
            print("❌ [Meditation] Failed to render character artwork")
            return nil
        }
        
        // Create artwork
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
            return image
        }
        
        print("📱 [Meditation] Created artwork for focus: \(focus) (character: \(characterType))")
        return artwork
    }
    
    /// Render SwiftUI view to UIImage
    private func renderViewToImage<V: View>(_ view: V) -> UIImage? {
        let controller = UIHostingController(rootView: view)
        let view = controller.view
        
        let targetSize = CGSize(width: 500, height: 500)
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
    
    private func getCurrentUserId() -> String {
        return CurrentUserService.shared.userID ?? ""
    }
    
    // MARK: - Lock Screen Media Player
    
    /// Set up lock screen for an active meditation session (called from action handler)
    /// This is used when meditation is started through Genie/AI, not through startSession()
    func setupLockScreenForActiveMeditation(
        title: String,
        duration: TimeInterval,
        notes: String? = nil,
        focus: String? = nil
    ) {
        // Store active meditation info
        activeMeditationTitle = title
        activeMeditationDuration = duration
        activeMeditationStartTime = Date()
        activeMeditationFocus = focus
        
        // Create and store artwork
        if let focus = focus {
            activeMeditationArtwork = createMeditationArtwork(for: focus)
        }
        
        // Configure audio session immediately to .playback/.default
        // This ensures lock screen is ready even before audio starts
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetooth])
            
            // Only activate if not already active to avoid conflicts
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true, options: [])
                print("📱 [Meditation] Audio session activated for lock screen setup")
            }
        } catch {
            print("❌ [Meditation] Failed to configure audio session: \(error.localizedDescription)")
        }
        
        // Setup lock screen with provided info
        // CRITICAL: iOS requires playback rate to be 1.0 for lock screen to appear
        // We'll set it to 1.0 from the start, even if audio hasn't started yet
        // This ensures iOS recognizes it as "playing" media
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "Do",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0.0,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0 // Set to 1.0 from start - required for lock screen
        ]
        
        // Add album title with session info if available
        if let notes = notes {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = notes
        }
        
        // Add artwork (meditation character) based on focus type
        if let focus = focus, let artwork = createMeditationArtwork(for: focus) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        // Set initial now playing info
        // CRITICAL: Set this BEFORE audio starts to ensure iOS sees it
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        print("📱 [Meditation] Initial NowPlayingInfo set (rate=\(nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] ?? "nil"), ready for lock screen)")
        
        // Ensure lock screen controls are set up (should already be done in init, but double-check)
        setupLockScreenControls()
        
        // Verify audio session is active and configured correctly
        let audioSession = AVAudioSession.sharedInstance()
        print("📱 [Meditation] Lock screen setup complete:")
        print("   - Audio session category: \(audioSession.category.rawValue)")
        print("   - Audio session mode: \(audioSession.mode.rawValue)")
        print("   - Audio session active: \(audioSession.isOtherAudioPlaying ? "other playing" : "active")")
        print("   - NowPlayingInfo set: \(MPNowPlayingInfoCenter.default().nowPlayingInfo != nil)")
        print("   - Lock screen controls enabled: \(MPRemoteCommandCenter.shared().playCommand.isEnabled)")
        print("   - Note: Lock screen will appear when device is locked or app is backgrounded")
        
        // Start timer to update lock screen periodically
        activeMeditationTimer?.invalidate()
        lastCategoryCheckTime = Date()
        activeMeditationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            // Only check audio session category every 5 seconds to avoid excessive reconfiguration
            let now = Date()
            if now.timeIntervalSince(self.lastCategoryCheckTime) >= 5.0 {
                // Ensure audio session stays in .playback mode (MeditationAudioService might change it)
                if MeditationAudioService.shared.isSpeaking {
                    let audioSession = AVAudioSession.sharedInstance()
                    // Only reconfigure if it's not already .playback with .default mode
                    if audioSession.category != .playback || audioSession.mode != .default {
                        self.ensurePlaybackCategory()
                    }
                }
                self.lastCategoryCheckTime = now
            }
            self.updateActiveMeditationLockScreen()
        }
        
        print("📱 [Meditation] Lock screen setup for active meditation: \(title)")
        print("📱 [Meditation] NowPlayingInfo set: \(nowPlayingInfo)")
    }
    
    private func updateActiveMeditationLockScreen() {
        guard let title = activeMeditationTitle,
              let duration = activeMeditationDuration else {
            return
        }
        
        // Use actual playback time from MeditationAudioService if available, otherwise use elapsed time
        let elapsedTime: TimeInterval
        let isPaused: Bool
        
        if MeditationAudioService.shared.isSpeaking {
            // Audio is playing - use actual playback time
            elapsedTime = MeditationAudioService.shared.currentPlaybackTime
            isPaused = MeditationAudioService.shared.isPaused
        } else if let startTime = activeMeditationStartTime {
            // No audio yet or audio stopped - use elapsed time since start
            elapsedTime = Date().timeIntervalSince(startTime)
            isPaused = false
        } else {
            return
        }
        
        // Update lock screen
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "Do",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPaused ? 0.0 : 1.0
        ]
        
        // Include artwork if available
        if let artwork = activeMeditationArtwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    /// Update lock screen info for active meditation
    func updateLockScreenForActiveMeditation(
        elapsedTime: TimeInterval,
        duration: TimeInterval,
        isPaused: Bool = false
    ) {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPaused ? 0.0 : 1.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Always configure with .playback category for lock screen to show
            // Even if MeditationAudioService uses .spokenAudio, we need .playback for lock screen
            // Use .mixWithOthers so it doesn't interfere with other audio
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetooth])
            try audioSession.setActive(true)
            print("📱 [Meditation] Audio session configured for lock screen (.playback category)")
            
            // For manual meditations without audio, play silent audio to keep session active
            // This ensures the lock screen player shows up
            // If MeditationAudioService is playing, it will handle the actual audio
            startSilentAudioIfNeeded()
        } catch {
            print("❌ [Meditation] Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
    private func startSilentAudioIfNeeded() {
        // Only start silent audio if there's no active audio player from MeditationAudioService
        // Check if audio is already playing (guided meditation)
        // For AI-generated meditations, MeditationAudioService will handle audio, so we don't need silent audio
        if MeditationAudioService.shared.isSpeaking {
            print("📱 [Meditation] MeditationAudioService is playing, skipping silent audio")
            return
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        guard !audioSession.isOtherAudioPlaying else {
            // Other audio is playing (guided meditation), don't start silent audio
            print("📱 [Meditation] Other audio playing, skipping silent audio")
            return
        }
        
        // If audio engine is already running, don't start another
        if let engine = silentAudioEngine, engine.isRunning {
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
            self.silentAudioEngine = engine
            self.silentPlayerNode = playerNode
            
            print("📱 [Meditation] Silent audio started for lock screen")
        } catch {
            print("❌ [Meditation] Failed to start silent audio: \(error.localizedDescription)")
        }
    }
    
    private func stopSilentAudio() {
        silentPlayerNode?.stop()
        silentAudioEngine?.stop()
        silentPlayerNode = nil
        silentAudioEngine = nil
        print("📱 [Meditation] Silent audio stopped")
    }
    
    private func setupLockScreenControls() {
        commandCenter = MPRemoteCommandCenter.shared()
        
        // Enable commands
        commandCenter?.playCommand.isEnabled = true
        commandCenter?.pauseCommand.isEnabled = true
        commandCenter?.stopCommand.isEnabled = true
        
        // Set up handlers
        playCommandHandler = commandCenter?.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.resumeSession()
            }
            return .success
        }
        
        pauseCommandHandler = commandCenter?.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pauseSession()
            }
            return .success
        }
        
        stopCommandHandler = commandCenter?.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.cancelSession()
            }
            return .success
        }
    }
    
    private func setupLockScreenForSession(session: MeditationSession) {
        let title = session.meditationType.name + " Meditation"
        let duration = session.plannedDuration
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "Do",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0.0,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
        
        // Add album title with session info if available
        if let notes = session.notes {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = notes
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        print("📱 [Meditation] Lock screen setup: \(title)")
    }
    
    private func updateLockScreenInfo(elapsedTime: TimeInterval, isPaused: Bool) {
        guard let session = currentSession else { return }
        
        let title = session.meditationType.name + " Meditation"
        let duration = session.plannedDuration
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "Do",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPaused ? 0.0 : 1.0
        ]
        
        // Add album title with session info if available
        if let notes = session.notes {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = notes
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func cleanupLockScreen() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        
        // Stop active meditation timer
        activeMeditationTimer?.invalidate()
        activeMeditationTimer = nil
        activeMeditationTitle = nil
        activeMeditationDuration = nil
        activeMeditationStartTime = nil
        activeMeditationFocus = nil
        activeMeditationArtwork = nil
        
        // Stop silent audio if playing
        stopSilentAudio()
        
        // Deactivate audio session when session ends
        // Only deactivate if no other audio is playing (like guided meditation)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Check if other audio services are using the session
            // If MeditationAudioService or AmbientAudioService are active, don't deactivate
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                print("📱 [Meditation] Audio session deactivated")
            } else {
                print("📱 [Meditation] Keeping audio session active (other audio playing)")
            }
        } catch {
            print("❌ [Meditation] Failed to deactivate audio session: \(error.localizedDescription)")
        }
        
        isPaused = false
        pauseStartTime = nil
        totalPausedTime = 0
        print("📱 [Meditation] Lock screen cleaned up")
    }
    
    /// Clean up active meditation lock screen (called when meditation ends)
    func cleanupActiveMeditationLockScreen() {
        cleanupLockScreen()
    }
    
    // MARK: - Session Control Methods
    
    func pauseSession() {
        guard currentSession != nil, !isPaused else { return }
        isPaused = true
        pauseStartTime = Date()
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        // Update lock screen to show paused state
        if let session = currentSession {
            let elapsedTime = Date().timeIntervalSince(session.startTime) - totalPausedTime
            updateLockScreenInfo(elapsedTime: elapsedTime, isPaused: true)
        }
        
        print("⏸️ [Meditation] Session paused")
    }
    
    func resumeSession() {
        guard let session = currentSession, isPaused else { return }
        
        // Calculate paused time and add to total
        if let pauseStart = pauseStartTime {
            let pausedDuration = Date().timeIntervalSince(pauseStart)
            totalPausedTime += pausedDuration
            pauseStartTime = nil
        }
        
        isPaused = false
        
        // Resume timer
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSessionDuration()
        }
        
        // Update lock screen to show playing state
        let elapsedTime = Date().timeIntervalSince(session.startTime) - totalPausedTime
        updateLockScreenInfo(elapsedTime: elapsedTime, isPaused: false)
        
        print("▶️ [Meditation] Session resumed")
    }
}

// MARK: - Lock Screen Character Artwork View

/// SwiftUI view for rendering meditation character artwork for lock screen
private struct LockScreenCharacterArtworkView: View {
    let characterType: LockScreenCharacterType
    
    var body: some View {
        ZStack {
            // Background circle with gradient
            Circle()
                .fill(characterBackgroundGradient)
                .frame(width: 500, height: 500)
            
            // Character illustration (scaled up for lock screen)
            characterIllustration
                .scaleEffect(5.0) // Scale up from 100x100 to 500x500
        }
        .frame(width: 500, height: 500)
    }
    
    private var characterIllustration: some View {
        Group {
            switch characterType {
            case .sleep:
                LockScreenSleepCharacter()
            case .focus:
                LockScreenFocusCharacter()
            case .stress:
                LockScreenStressReliefCharacter()
            case .breathing:
                LockScreenBreathingCharacter()
            case .gratitude:
                LockScreenGratitudeCharacter()
            case .performance:
                LockScreenPerformanceCharacter()
            case .recovery:
                LockScreenRecoveryCharacter()
            case .default:
                LockScreenMindfulnessCharacter()
            }
        }
    }
    
    private var characterBackgroundGradient: LinearGradient {
        let colors = characterType.colors
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Lock Screen Character Type

private enum LockScreenCharacterType {
    case sleep
    case focus
    case stress
    case breathing
    case gratitude
    case performance
    case recovery
    case `default`
    
    var colors: [Color] {
        switch self {
        case .sleep:
            return [Color(hex: "9B87F5").opacity(0.4), Color(hex: "6B5CE6").opacity(0.6)]
        case .focus:
            return [Color.brandOrange.opacity(0.4), Color(hex: "FFB84D").opacity(0.6)]
        case .stress:
            return [Color(hex: "4ECDC4").opacity(0.4), Color(hex: "44A08D").opacity(0.6)]
        case .breathing:
            return [Color(hex: "87CEEB").opacity(0.4), Color(hex: "5F9EA0").opacity(0.6)]
        case .gratitude:
            return [Color(hex: "FFD700").opacity(0.4), Color(hex: "FFA500").opacity(0.6)]
        case .performance:
            return [Color(hex: "FF6B6B").opacity(0.4), Color(hex: "FF8E53").opacity(0.6)]
        case .recovery:
            return [Color(hex: "A8E6CF").opacity(0.4), Color(hex: "7FCDBB").opacity(0.6)]
        case .default:
            return [Color(hex: "B19CD9").opacity(0.4), Color(hex: "8B7FA8").opacity(0.6)]
        }
    }
}

// MARK: - Lock Screen Character Views (Simplified for artwork)

private struct LockScreenSleepCharacter: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 8, height: 3)
                    .offset(x: -8)
                Capsule()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 8, height: 3)
                    .offset(x: 8)
            }
            Capsule()
                .fill(Color.black.opacity(0.2))
                .frame(width: 12, height: 2)
                .offset(y: 8)
            Image(systemName: "moon.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "FFD700").opacity(0.8))
                .offset(y: -35)
        }
    }
}

private struct LockScreenFocusCharacter: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 10, height: 10)
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 10, height: 10)
            }
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 14, height: 3)
                .offset(y: 10)
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundColor(Color.brandOrange)
                .offset(y: -38)
        }
    }
}

private struct LockScreenStressReliefCharacter: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            HStack(spacing: 12) {
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 10, height: 3)
                    .rotationEffect(.degrees(-20))
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 10, height: 3)
                    .rotationEffect(.degrees(20))
            }
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 16, height: 3)
                .offset(y: 8)
            ForEach(0..<3) { index in
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 60 + CGFloat(index * 8))
            }
        }
    }
}

private struct LockScreenBreathingCharacter: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 8, height: 8)
            }
            Ellipse()
                .fill(Color.black.opacity(0.2))
                .frame(width: 12, height: 8)
                .offset(y: 10)
            ForEach(0..<2) { index in
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    .frame(width: 40 + CGFloat(index * 10))
            }
        }
    }
}

private struct LockScreenGratitudeCharacter: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            HStack(spacing: 12) {
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 10, height: 3)
                    .rotationEffect(.degrees(-20))
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 10, height: 3)
                    .rotationEffect(.degrees(20))
            }
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 20, height: 4)
                .offset(y: 10)
            Image(systemName: "heart.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "FF6B6B"))
                .offset(y: -35)
        }
    }
}

private struct LockScreenPerformanceCharacter: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 10, height: 10)
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 10, height: 10)
            }
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 18, height: 3)
                .offset(y: 10)
            Image(systemName: "bolt.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "FFD700"))
                .offset(y: -38)
        }
    }
}

private struct LockScreenRecoveryCharacter: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            HStack(spacing: 12) {
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 8, height: 3)
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 8, height: 3)
            }
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 14, height: 3)
                .offset(y: 8)
            Image(systemName: "leaf.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "4ECDC4"))
                .offset(y: -35)
        }
    }
}

private struct LockScreenMindfulnessCharacter: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 50, height: 50)
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 9, height: 9)
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 9, height: 9)
            }
            Capsule()
                .fill(Color.black.opacity(0.3))
                .frame(width: 12, height: 2)
                .offset(y: 10)
            ForEach(0..<3) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: 8))
                    .foregroundColor(Color.white.opacity(0.6))
                    .offset(
                        x: cos(Double(index) * 2 * .pi / 3) * 25,
                        y: sin(Double(index) * 2 * .pi / 3) * 25
                    )
            }
        }
    }
}
// MARK: - MeditationType Enum

enum MeditationType: String, Codable {
    case mindfulness = "mindfulness"
    case breathing = "breathing"
    case sleep = "sleep"
    case focus = "focus"
    case stress = "stress"
    
    var name: String {
        switch self {
        case .mindfulness: return "Mindfulness"
        case .breathing: return "Breathing"
        case .sleep: return "Sleep"
        case .focus: return "Focus"
        case .stress: return "Stress Relief"
        }
    }
}

// MARK: - Models

struct MeditationSession: Identifiable, Codable {
    let id: String
    let userId: String
    let type: String // Store as String to avoid MeditationType Codable issues
    let plannedDuration: TimeInterval
    var actualDuration: TimeInterval
    let guided: Bool
    var notes: String?
    let startTime: Date
    var endTime: Date?
    var completed: Bool
    var rating: Int?
    let source: MeditationSource
    var aiGenerated: Bool
    var scriptId: String?
    
    init(id: String, userId: String, type: MeditationType, plannedDuration: TimeInterval, actualDuration: TimeInterval = 0, guided: Bool, notes: String?, startTime: Date, endTime: Date? = nil, completed: Bool = false, rating: Int? = nil, source: MeditationSource = .manual, aiGenerated: Bool = false, scriptId: String? = nil) {
        self.id = id
        self.userId = userId
        self.type = type.rawValue // Convert to String
        self.plannedDuration = plannedDuration
        self.actualDuration = actualDuration
        self.guided = guided
        self.notes = notes
        self.startTime = startTime
        self.endTime = endTime
        self.completed = completed
        self.rating = rating
        self.source = source
        self.aiGenerated = aiGenerated
        self.scriptId = scriptId
    }
    
    var meditationType: MeditationType {
        MeditationType(rawValue: type) ?? .mindfulness
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "userId": userId,
            "type": type,
            "plannedDuration": plannedDuration,
            "actualDuration": actualDuration,
            "guided": guided,
            "notes": notes ?? "",
            "startTime": ISO8601DateFormatter().string(from: startTime),
            "endTime": endTime.map { ISO8601DateFormatter().string(from: $0) } ?? "",
            "completed": completed,
            "rating": rating ?? 0,
            "source": source.rawValue,
            "aiGenerated": aiGenerated
        ]
    }
}

enum MeditationSource: String, Codable {
    case manual = "manual"
    case ai = "ai"
    case guided = "guided"
}

// MARK: - MeditationSessionData
/// Data structure for sending meditation session data to the backend API
struct MeditationSessionData: Codable {
    let sessionId: String
    let type: String
    let focus: String?
    let duration: Int
    let actualDuration: Int
    let guided: Bool
    let completed: Bool
    let rating: Int?
    let notes: String?
    let aiGenerated: Bool
    let scriptId: String?
    let startTime: String
    let endTime: String?
    
    enum CodingKeys: String, CodingKey {
        case sessionId
        case type
        case focus
        case duration
        case actualDuration
        case guided
        case completed
        case rating
        case notes
        case aiGenerated
        case scriptId
        case startTime
        case endTime
    }
}

struct MeditationTrends {
    let averageMinutesPerDay: Int
    let totalSessions: Int
    let completionRate: Double
    let dailyMinutes: [(Date, Int)]
    let typeDistribution: [String: Int]
    let consistency: Double
}

struct MeditationInsights {
    let totalMinutes: Int
    let totalSessions: Int
    let completedSessions: Int
    let favoriteType: String?
    let bestTimeOfDay: String
    let averageRating: Double
    let longestStreak: Int
    let currentStreak: Int
}

struct WeeklyMeditationStats {
    let totalSessions: Int
    let completedSessions: Int
    let totalMinutes: Int
    let averageMinutesPerDay: Double
    let consistency: Double
}

enum MeditationAchievement: String {
    case firstSession = "First Session"
    case weekWarrior = "Week Warrior"
    case monthMaster = "Month Master"
    case centurion = "Centurion"
    case threeDayStreak = "3-Day Streak"
    case weekStreak = "Week Streak"
    case monthStreak = "Month Streak"
    case hourOfPeace = "Hour of Peace"
    case tenHours = "10 Hours"
    
    var icon: String {
        switch self {
        case .firstSession: return "star.fill"
        case .weekWarrior: return "flame.fill"
        case .monthMaster: return "crown.fill"
        case .centurion: return "trophy.fill"
        case .threeDayStreak: return "3.circle.fill"
        case .weekStreak: return "7.circle.fill"
        case .monthStreak: return "30.circle.fill"
        case .hourOfPeace: return "clock.fill"
        case .tenHours: return "hourglass.fill"
        }
    }
}


