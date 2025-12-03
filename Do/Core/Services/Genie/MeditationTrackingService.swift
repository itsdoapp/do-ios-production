//
//  MeditationTrackingService.swift
//  Do
//
//  Enterprise-grade meditation tracking with database integration
//

import Foundation
import AVFoundation

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
    
    private init() {
        loadTodaysSessions()
        calculateStreak()
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
        
        session.endTime = Date()
        session.actualDuration = session.endTime!.timeIntervalSince(session.startTime)
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
        // Update UI with current duration
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
    
    private func getCurrentUserId() -> String {
        return CurrentUserService.shared.userID ?? ""
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


