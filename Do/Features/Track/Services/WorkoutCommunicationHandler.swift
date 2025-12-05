//
//  WorkoutCommunicationHandler.swift
//  Do
//
//  Handles communication between workout tracking engines and watch
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import WatchConnectivity

// MARK: - Watch Food Entry Data Model
// Simplified model for sharing food entries with watch app
// Uses String timestamps and optional mealType for compatibility
struct WatchFoodEntryData: Codable {
    let id: String
    let userId: String
    let name: String
    let mealType: String?
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let servingSize: String?
    let notes: String?
    let timestamp: String? // ISO8601 string
    let source: String
}

// Forward declarations - these will be resolved at link time
// The actual services are in other modules

protocol WorkoutCommunicationHandlerDelegate: AnyObject {
    func workoutCommunicationHandler(_ handler: WorkoutCommunicationHandler, didReceiveMessage message: [String: Any])
    func workoutCommunicationHandler(_ handler: WorkoutCommunicationHandler, didUpdateConnectionStatus isConnected: Bool)
}

class WorkoutCommunicationHandler: NSObject {
    static let shared = WorkoutCommunicationHandler()
    
    weak var delegate: WorkoutCommunicationHandlerDelegate?
    
    private var session: WCSession?
    private var isPhoneTracking: Bool = false
    
    // Primary device flags
    var isPrimaryForDistance: Bool = true
    var isPrimaryForPace: Bool = true
    var isPrimaryForHeartRate: Bool = false
    var isPrimaryForCalories: Bool = true
    var isPrimaryForCadence: Bool = false
    
    // Tracking status flags
    var isDashboardMode: Bool = false
    var isWatchTracking: Bool = false
    
    private override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("⚠️ [WorkoutCommunicationHandler] WatchConnectivity not supported")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    func sendTrackingStatus(isPhoneTracking: Bool) {
        self.isPhoneTracking = isPhoneTracking
        
        guard let session = session, session.isWatchAppInstalled else { return }
        
        let message: [String: Any] = [
            "type": "trackingStatus",
            "isPhoneTracking": isPhoneTracking,
            "isPrimaryForDistance": isPrimaryForDistance,
            "isPrimaryForPace": isPrimaryForPace,
            "isPrimaryForHeartRate": isPrimaryForHeartRate,
            "isPrimaryForCalories": isPrimaryForCalories,
            "isPrimaryForCadence": isPrimaryForCadence
        ]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: { error in
                print("❌ [WorkoutCommunicationHandler] Error sending status: \(error.localizedDescription)")
            })
        } else {
            do {
                try session.updateApplicationContext(message)
            } catch {
                print("❌ [WorkoutCommunicationHandler] Error updating context: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WorkoutCommunicationHandler: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ [WorkoutCommunicationHandler] Session activation failed: \(error.localizedDescription)")
        } else {
            print("✅ [WorkoutCommunicationHandler] Session activated")
            delegate?.workoutCommunicationHandler(self, didUpdateConnectionStatus: session.isReachable)
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ [WorkoutCommunicationHandler] Session became inactive")
        delegate?.workoutCommunicationHandler(self, didUpdateConnectionStatus: false)
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleIncomingMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        // Handle messages that require a reply
        if let type = message["type"] as? String {
            switch type {
            case "requestActivePhoneWorkout":
                // Check for active workouts across all tracking engines
                let response: [String: Any] = [
                    "workoutActive": false,
                    "timestamp": Date().timeIntervalSince1970
                ]
                replyHandler(response)
                delegate?.workoutCommunicationHandler(self, didReceiveMessage: message)
                
            case "requestDailyBricksData":
                // Handle daily bricks data requests from watch
                handleDailyBricksDataRequest(message, replyHandler: replyHandler)
                
            default:
                // For other messages, just acknowledge
                replyHandler(["status": "received"])
                handleIncomingMessage(message)
            }
        } else {
            replyHandler(["status": "received"])
            handleIncomingMessage(message)
        }
    }
    
    private func handleDailyBricksDataRequest(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let dataType = message["dataType"] as? String,
              let startOfDayTimestamp = message["startOfDay"] as? TimeInterval,
              let nowTimestamp = message["now"] as? TimeInterval else {
            replyHandler(["error": "Invalid request"])
            return
        }
        
        let startOfDay = Date(timeIntervalSince1970: startOfDayTimestamp)
        let now = Date(timeIntervalSince1970: nowTimestamp)
        
        Task {
            var response: [String: Any] = [:]
            
            switch dataType {
            case "workoutMinutes":
                let minutes = await getTotalWorkoutMinutes(startOfDay: startOfDay, now: now)
                response["workoutMinutes"] = minutes
                
            case "strengthWorkout":
                let strengthData = await getStrengthWorkoutData(startOfDay: startOfDay, now: now)
                response["strengthMinutes"] = strengthData.minutes
                response["hasStrengthSession"] = strengthData.hasSession
                
            case "mealCount":
                let mealCount = await getMealCount(startOfDay: startOfDay, now: now)
                response["mealCount"] = mealCount
                
            default:
                response["error"] = "Unknown data type"
            }
            
            replyHandler(response)
        }
    }
    
    private func getTotalWorkoutMinutes(startOfDay: Date, now: Date) async -> Double {
        // Get workout logs from ActivityService
        guard let userId = CurrentUserService.shared.userID else { return 0.0 }
        
        return await withCheckedContinuation { continuation in
            ActivityService.shared.getSessionLogs(userId: userId, limit: 100) { result in
                switch result {
                case .success(let response):
                    guard let logs = response.data?.logs else {
                        continuation.resume(returning: 0.0)
                        return
                    }
                    
                    // Filter logs for today
                    let todayLogs = logs.filter { log in
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        guard let createdAt = formatter.date(from: log.createdAt) else {
                            return false
                        }
                        return createdAt >= startOfDay && createdAt <= now && log.completed == true
                    }
                    
                    // Sum durations (in seconds, convert to minutes)
                    let totalSeconds = todayLogs.reduce(0.0) { total, log in
                        total + (log.duration ?? 0.0)
                    }
                    
                    continuation.resume(returning: totalSeconds / 60.0)
                    
                case .failure:
                    continuation.resume(returning: 0.0)
                }
            }
        }
    }
    
    private func getStrengthWorkoutData(startOfDay: Date, now: Date) async -> (minutes: Double, hasSession: Bool) {
        guard let userId = CurrentUserService.shared.userID else { return (0.0, false) }
        
        return await withCheckedContinuation { continuation in
            ActivityService.shared.getSessionLogs(userId: userId, limit: 100) { result in
                switch result {
                case .success(let response):
                    guard let logs = response.data?.logs else {
                        continuation.resume(returning: (0.0, false))
                        return
                    }
                    
                    // Filter for gym/strength workouts today
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    
                    let strengthLogs = logs.filter { log in
                        guard let createdAt = formatter.date(from: log.createdAt) else {
                            return false
                        }
                        // Check if it's a gym/strength workout (you may need to adjust this logic)
                        let isStrength = log.title?.lowercased().contains("gym") == true ||
                                        log.title?.lowercased().contains("strength") == true ||
                                        log.title?.lowercased().contains("weight") == true
                        return createdAt >= startOfDay && createdAt <= now && log.completed == true && isStrength
                    }
                    
                    let totalSeconds = strengthLogs.reduce(0.0) { total, log in
                        total + (log.duration ?? 0.0)
                    }
                    
                    continuation.resume(returning: (totalSeconds / 60.0, !strengthLogs.isEmpty))
                    
                case .failure:
                    continuation.resume(returning: (0.0, false))
                }
            }
        }
    }
    
    private func getMealCount(startOfDay: Date, now: Date) async -> Double {
        // Try App Group first (where watch app stores data)
        let appGroupDefaults = UserDefaults(suiteName: "group.com.do.fitness")
        
        // Check for watch app's format (FoodEntryData with String timestamps)
        if let foodData = appGroupDefaults?.data(forKey: "todaysFoods"),
           let foods = try? JSONDecoder().decode([WatchFoodEntryData].self, from: foodData) {
            // Filter foods for today
            let todayFoods = foods.filter { food in
                guard let timestampString = food.timestamp else {
                    return false
                }
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                guard let timestamp = formatter.date(from: timestampString) else {
                    return false
                }
                return timestamp >= startOfDay && timestamp <= now
            }
            
            // Count unique meal types
            let mealTypes = Set(todayFoods.compactMap { $0.mealType })
            return Double(mealTypes.count)
        }
        
        // Fallback: Get from FoodTrackingService directly
        // FoodTrackingService is @MainActor, so we need to access it on the main actor
        return await MainActor.run {
            // Get today's foods from FoodTrackingService
            let calendar = Calendar.current
            let todaysFoods = FoodTrackingService.shared.todaysFoods.filter { entry in
                entry.timestamp >= startOfDay && entry.timestamp <= now
            }
            
            // Count unique meal types
            let mealTypes = Set(todaysFoods.map { $0.mealType.rawValue })
            return Double(mealTypes.count)
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleIncomingMessage(applicationContext)
    }
    
    private func handleIncomingMessage(_ message: [String: Any]) {
        // Intercept unit preference updates
        if let type = message["type"] as? String, type == "unitPreferences",
           let useMetric = message["useMetric"] as? Bool {
            // Update central user preferences (which will handle sync back loop prevention)
            UserPreferences.shared.updateFromWatch(useMetric: useMetric)
        }
        
        // Forward to delegate for other handlers
        delegate?.workoutCommunicationHandler(self, didReceiveMessage: message)
    }
}
