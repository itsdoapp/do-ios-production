//
//  GenieUserLearningService.swift
//  Do
//
//  User learning service to track preferences and improve AI
//

import Foundation
import SwiftUI

@MainActor
class GenieUserLearningService: ObservableObject {
    static let shared = GenieUserLearningService()
    
    // Cache insights in memory for fast access during conversation
    private var cachedInsights: [String: Any]? = nil
    private var lastCacheUpdate: Date? = nil
    
    private init() {}
    
    func updateUserLearning(activity: String, data: [String: Any]) {
        Task {
            // Save to local storage first
            saveToLocalStorage(activity: activity, data: data)
            
            // TODO: Save to DynamoDB when backend is ready
            // await saveToDynamoDB(activity: activity, data: data)
        }
    }
    
    func getUserPreferences() async -> [String: Any] {
        // Load from local storage
        return loadFromLocalStorage()
    }
    
    private func saveToLocalStorage(activity: String, data: [String: Any]) {
        // Use file-based storage for large arrays to avoid UserDefaults 4MB limit
        let key = "userLearning_\(activity)"
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("\(key).json")
        
        // Load existing history from file
        var history: [[String: Any]] = []
        if let fileData = try? Data(contentsOf: fileURL),
           let decoded = try? JSONSerialization.jsonObject(with: fileData) as? [[String: Any]] {
            history = decoded
        }
        
        history.insert(data, at: 0)
        
        // Keep only last 50 entries per activity (reduced from 100 to save space)
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        
        // Save to file instead of UserDefaults
        if let encoded = try? JSONSerialization.data(withJSONObject: history, options: .prettyPrinted) {
            try? encoded.write(to: fileURL)
            print("✅ [Learning] Saved \(activity) data to file (count: \(history.count))")
        } else {
            // Fallback to UserDefaults for small data only
            if history.count <= 10 {
                UserDefaults.standard.set(history, forKey: key)
                print("✅ [Learning] Saved \(activity) data to UserDefaults (fallback)")
            } else {
                print("⚠️ [Learning] Failed to save \(activity) data - too large for UserDefaults")
            }
        }
    }
    
    private func loadFromLocalStorage() -> [String: Any] {
        var preferences: [String: Any] = [:]
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Load meditation preferences (try file first, then UserDefaults fallback)
        if let meditationHistory = loadHistoryFromFile(key: "userLearning_meditation", fileManager: fileManager, documentsURL: documentsURL) {
            preferences["meditation"] = extractMeditationPreferences(from: meditationHistory)
        }
        
        // Load food preferences (try file first, then UserDefaults fallback)
        if let foodHistory = loadHistoryFromFile(key: "userLearning_food", fileManager: fileManager, documentsURL: documentsURL) {
            preferences["food"] = extractFoodPreferences(from: foodHistory)
        }
        
        return preferences
    }
    
    private func loadHistoryFromFile(key: String, fileManager: FileManager, documentsURL: URL) -> [[String: Any]]? {
        let fileURL = documentsURL.appendingPathComponent("\(key).json")
        
        // Try file first
        if let fileData = try? Data(contentsOf: fileURL),
           let decoded = try? JSONSerialization.jsonObject(with: fileData) as? [[String: Any]] {
            return decoded
        }
        
        // Fallback to UserDefaults for migration
        if let history = UserDefaults.standard.array(forKey: key) as? [[String: Any]] {
            // Migrate to file storage
            if let encoded = try? JSONSerialization.data(withJSONObject: history, options: .prettyPrinted) {
                try? encoded.write(to: fileURL)
                // Clear from UserDefaults after migration
                UserDefaults.standard.removeObject(forKey: key)
            }
            return history
        }
        
        return nil
    }
    
    private func extractMeditationPreferences(from history: [[String: Any]]) -> [String: Any] {
        var focusCounts: [String: Int] = [:]
        var totalDuration = 0
        var completedCount = 0
        
        for entry in history {
            if let focus = entry["focus"] as? String {
                focusCounts[focus, default: 0] += 1
            }
            if let duration = entry["duration"] as? Int {
                totalDuration += duration
            }
            if let completed = entry["completed"] as? Bool, completed {
                completedCount += 1
            }
        }
        
        let favoriteFocus = focusCounts.max(by: { $0.value < $1.value })?.key
        let averageDuration = history.isEmpty ? 10 : totalDuration / history.count
        
        return [
            "favoriteFocus": favoriteFocus ?? "stress",
            "averageDuration": averageDuration,
            "completedSessions": completedCount,
            "totalSessions": history.count
        ]
    }
    
    private func extractFoodPreferences(from history: [[String: Any]]) -> [String: Any] {
        var mealTypeCounts: [String: Int] = [:]
        var totalLogs = history.count
        
        for entry in history {
            if let mealType = entry["mealType"] as? String {
                mealTypeCounts[mealType, default: 0] += 1
            }
        }
        
        let mostLoggedMeal = mealTypeCounts.max(by: { $0.value < $1.value })?.key
        
        return [
            "mostLoggedMeal": mostLoggedMeal ?? "breakfast",
            "totalLogs": totalLogs,
            "loggingFrequency": totalLogs > 0 ? "regular" : "new"
        ]
    }
    
    // MARK: - Conversation Insights
    
    /// Extract insights from a conversation and save to user learning
    func extractConversationInsights(conversationId: String, messages: [ChatMessage]) async {
        var topics: [String] = []
        var interests: [String] = []
        var goals: [String] = []
        var questions: [String] = []
        var preferences: [String] = [] // "I prefer", "I usually", "I don't like"
        var communicationStyle = "balanced" // "brief", "detailed", "formal", "casual"
        var messageLengths: [Int] = []
        var featureUsage: [String: Int] = [:]
        
        // Analyze user messages for insights
        for message in messages where message.isUser {
            let text = message.text.lowercased()
            let originalText = message.text
            messageLengths.append(originalText.count)
            
            // Extract communication style indicators
            if originalText.count < 20 {
                communicationStyle = "brief"
            } else if originalText.count > 100 {
                communicationStyle = "detailed"
            }
            
            if text.contains("prefer") || text.contains("usually") || text.contains("typically") {
                preferences.append(originalText)
            }
            if text.contains("don't like") || text.contains("don't want") || text.contains("avoid") {
                preferences.append("dislikes: " + originalText)
            }
            
            // Extract topics (meditation, fitness, nutrition, etc.)
            if text.contains("meditat") || text.contains("stress") || text.contains("anxiety") || text.contains("relax") {
                topics.append("meditation")
                featureUsage["meditation", default: 0] += 1
                if text.contains("stress") || text.contains("anxiety") {
                    interests.append("stress_relief")
                }
                if text.contains("sleep") || text.contains("bedtime") {
                    interests.append("sleep_improvement")
                }
            }
            if text.contains("workout") || text.contains("exercise") || text.contains("train") || text.contains("gym") {
                topics.append("fitness")
                featureUsage["fitness", default: 0] += 1
            }
            if text.contains("food") || text.contains("meal") || text.contains("nutrition") || text.contains("calorie") || text.contains("diet") {
                topics.append("nutrition")
                featureUsage["nutrition", default: 0] += 1
            }
            if text.contains("equipment") || text.contains("scanner") {
                featureUsage["equipment_scanner", default: 0] += 1
            }
            if text.contains("story") || text.contains("bedtime") {
                featureUsage["bedtime_story", default: 0] += 1
            }
            
            // Extract goals
            if text.contains("goal") || text.contains("want to") || text.contains("looking to") || text.contains("trying to") {
                if text.contains("lose") || text.contains("weight") || text.contains("slim") {
                    goals.append("weight_loss")
                }
                if text.contains("gain") || text.contains("muscle") || text.contains("bulk") {
                    goals.append("muscle_gain")
                }
                if text.contains("run") || text.contains("marathon") || text.contains("endurance") {
                    goals.append("running")
                }
                if text.contains("flexible") || text.contains("stretch") {
                    goals.append("flexibility")
                }
                if text.contains("sleep") || text.contains("rest") {
                    goals.append("better_sleep")
                }
                if text.contains("energy") || text.contains("energetic") {
                    goals.append("more_energy")
                }
            }
            
            // Track question patterns
            if text.contains("?") || text.contains("how") || text.contains("what") || text.contains("why") || text.contains("when") {
                questions.append(String(originalText.prefix(100))) // Store first 100 chars
            }
        }
        
        // Determine communication style based on average message length
        if !messageLengths.isEmpty {
            let avgLength = messageLengths.reduce(0, +) / messageLengths.count
            if avgLength < 30 {
                communicationStyle = "brief"
            } else if avgLength > 80 {
                communicationStyle = "detailed"
            } else {
                communicationStyle = "balanced"
            }
        }
        
        // Count topic frequencies
        let topicCounts = Dictionary(grouping: topics, by: { $0 }).mapValues { $0.count }
        let interestCounts = Dictionary(grouping: interests, by: { $0 }).mapValues { $0.count }
        let goalCounts = Dictionary(grouping: goals, by: { $0 }).mapValues { $0.count }
        
        // Extract most common topics, interests, and goals
        let topTopics = Array(topicCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key })
        let topInterests = Array(interestCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key })
        let topGoals = Array(goalCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key })
        let topFeatures = Array(featureUsage.sorted { $0.value > $1.value }.prefix(3).map { $0.key })
        
        // Save insights
        let insights: [String: Any] = [
            "conversationId": conversationId,
            "messageCount": messages.count,
            "topics": topTopics,
            "interests": topInterests,
            "goals": topGoals,
            "questionCount": questions.count,
            "communicationStyle": communicationStyle,
            "preferences": Array(preferences.prefix(5)), // Store top 5 preference phrases
            "featureUsage": topFeatures,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        updateUserLearning(activity: "conversation_insights", data: insights)
        
        // Invalidate cache to force refresh
        cachedInsights = nil
        lastCacheUpdate = nil
        
        print("✅ [Learning] Extracted insights: topics=\(topTopics), interests=\(topInterests), goals=\(topGoals), style=\(communicationStyle)")
    }
    
    
    /// Get aggregated conversation insights (cached for performance)
    func getConversationInsights() async -> [String: Any] {
        // Return cached insights if available and fresh (less than 5 minutes old)
        if let cached = cachedInsights,
           let lastUpdate = lastCacheUpdate,
           Date().timeIntervalSince(lastUpdate) < 300 {
            return cached
        }
        
        // Load and aggregate insights (from file storage)
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let insightsKey = "userLearning_conversation_insights"
        let fileURL = documentsURL.appendingPathComponent("\(insightsKey).json")
        
        var insightsHistory: [[String: Any]] = []
        
        // Try file first
        if let fileData = try? Data(contentsOf: fileURL),
           let decoded = try? JSONSerialization.jsonObject(with: fileData) as? [[String: Any]] {
            insightsHistory = decoded
        } else if let history = UserDefaults.standard.array(forKey: insightsKey) as? [[String: Any]] {
            // Fallback to UserDefaults and migrate
            insightsHistory = history
            if let encoded = try? JSONSerialization.data(withJSONObject: history, options: .prettyPrinted) {
                try? encoded.write(to: fileURL)
                UserDefaults.standard.removeObject(forKey: insightsKey)
            }
        }
        
        if !insightsHistory.isEmpty {
            var aggregatedTopics: [String: Int] = [:]
            var aggregatedInterests: [String: Int] = [:]
            var aggregatedGoals: [String: Int] = [:]
            var communicationStyles: [String: Int] = [:]
            var allPreferences: [String] = []
            var featureUsage: [String: Int] = [:]
            var totalConversations = insightsHistory.count
            
            for insight in insightsHistory {
                if let topics = insight["topics"] as? [String] {
                    for topic in topics {
                        aggregatedTopics[topic, default: 0] += 1
                    }
                }
                if let interests = insight["interests"] as? [String] {
                    for interest in interests {
                        aggregatedInterests[interest, default: 0] += 1
                    }
                }
                if let goals = insight["goals"] as? [String] {
                    for goal in goals {
                        aggregatedGoals[goal, default: 0] += 1
                    }
                }
                if let style = insight["communicationStyle"] as? String {
                    communicationStyles[style, default: 0] += 1
                }
                if let prefs = insight["preferences"] as? [String] {
                    allPreferences.append(contentsOf: prefs)
                }
                if let features = insight["featureUsage"] as? [String] {
                    for feature in features {
                        featureUsage[feature, default: 0] += 1
                    }
                }
            }
            
            let topTopics = Array(aggregatedTopics.sorted { $0.value > $1.value }.prefix(5).map { $0.key })
            let topInterests = Array(aggregatedInterests.sorted { $0.value > $1.value }.prefix(5).map { $0.key })
            let topGoals = Array(aggregatedGoals.sorted { $0.value > $1.value }.prefix(5).map { $0.key })
            let dominantStyle = communicationStyles.max(by: { $0.value < $1.value })?.key ?? "balanced"
            let topFeatures = Array(featureUsage.sorted { $0.value > $1.value }.prefix(3).map { $0.key })
            
            let aggregatedInsights: [String: Any] = [
                "topTopics": topTopics,
                "topInterests": topInterests,
                "topGoals": topGoals,
                "communicationStyle": dominantStyle,
                "preferences": Array(allPreferences.prefix(3)), // Top 3 preference phrases
                "featureUsage": topFeatures,
                "totalConversations": totalConversations
            ]
            
            // Cache the results
            cachedInsights = aggregatedInsights
            lastCacheUpdate = Date()
            
            return aggregatedInsights
        }
        
        return [:]
    }
    
    /// Get compact insight summary for API context (under 200 characters)
    func getInsightSummary() async -> String {
        let insights = await getConversationInsights()
        
        var parts: [String] = []
        
        // Add topics
        if let topics = insights["topTopics"] as? [String], !topics.isEmpty {
            parts.append("Interests: \(topics.joined(separator: ", "))")
        }
        
        // Add goals
        if let goals = insights["topGoals"] as? [String], !goals.isEmpty {
            parts.append("Goals: \(goals.joined(separator: ", "))")
        }
        
        // Add communication style
        if let style = insights["communicationStyle"] as? String {
            parts.append("Prefers: \(style) responses")
        }
        
        // Combine and limit to ~200 chars
        let summary = parts.joined(separator: ". ")
        if summary.count > 200 {
            return String(summary.prefix(197)) + "..."
        }
        
        return summary.isEmpty ? "" : summary
    }
    
    /// Clear cache (call when user logs out or preferences reset)
    func clearCache() {
        cachedInsights = nil
        lastCacheUpdate = nil
    }
}


