//
//  DailyBricksService.swift
//  Do Watch App
//
//  Service to calculate daily bricks progress from HealthKit and app data
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import HealthKit
import Combine
import WidgetKit

// MARK: - Supporting Data Models

struct FoodEntryData: Codable {
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

struct MeditationSessionData: Codable {
    let id: String
    let userId: String
    let type: String
    let plannedDuration: TimeInterval
    var actualDuration: TimeInterval
    let guided: Bool
    var notes: String?
    let startTime: String? // ISO8601 string
    var endTime: String? // ISO8601 string
    var completed: Bool
    var rating: Int?
    let source: String
    var aiGenerated: Bool
    var scriptId: String?
}

// MARK: - DailyBricksService

class DailyBricksService: ObservableObject {
    static let shared = DailyBricksService()
    
    @Published var todaySummary: DailyBricksSummary?
    @Published var isLoading: Bool = false
    
    private let healthStore = HKHealthStore()
    private var cancellables = Set<AnyCancellable>()
    private let appGroupIdentifier = "group.com.do.fitness"
    private var sharedUserDefaults: UserDefaults?
    
    private init() {
        sharedUserDefaults = UserDefaults(suiteName: appGroupIdentifier)
        // Load initial data
        Task {
            await loadTodayProgress()
        }
        
        // Set up periodic updates (every 5 minutes)
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.loadTodayProgress()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadTodayProgress() async {
        await MainActor.run {
            isLoading = true
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        // Calculate progress for each brick
        var bricks: [DailyBrickProgress] = []
        
        // 1. Move (Intentional Movement)
        let moveProgress = await calculateMoveProgress(startOfDay: startOfDay, now: now)
        bricks.append(moveProgress)
        
        // 2. Heart (Cardio Challenge)
        let heartProgress = await calculateHeartProgress(startOfDay: startOfDay, now: now)
        bricks.append(heartProgress)
        
        // 3. Strength (Muscle Challenge)
        let strengthProgress = await calculateStrengthProgress(startOfDay: startOfDay, now: now)
        bricks.append(strengthProgress)
        
        // 4. Recovery (Balance/Rest)
        let recoveryProgress = await calculateRecoveryProgress(startOfDay: startOfDay, now: now)
        bricks.append(recoveryProgress)
        
        // 5. Mind (Mental Wellness)
        let mindProgress = await calculateMindProgress(startOfDay: startOfDay, now: now)
        bricks.append(mindProgress)
        
        // 6. Fuel (Good Nutrition)
        let fuelProgress = await calculateFuelProgress(startOfDay: startOfDay, now: now)
        bricks.append(fuelProgress)
        
        let summary = DailyBricksSummary(bricks: bricks, date: now)
        
        await MainActor.run {
            self.todaySummary = summary
            self.isLoading = false
            
            // Share data with widget via App Group
            self.shareDataWithWidget(summary: summary)
        }
    }
    
    // MARK: - Widget Data Sharing
    
    private func shareDataWithWidget(summary: DailyBricksSummary) {
        guard let sharedDefaults = sharedUserDefaults else { return }
        
        // Share individual brick data for widget access
        if let moveBrick = summary.brick(for: .move) {
            sharedDefaults.set(moveBrick.currentValue, forKey: "shared_workout_minutes")
        }
        
        if let strengthBrick = summary.brick(for: .strength) {
            sharedDefaults.set(strengthBrick.currentValue, forKey: "shared_strength_minutes")
            sharedDefaults.set(strengthBrick.isComplete, forKey: "shared_strength_session")
        }
        
        if let mindBrick = summary.brick(for: .mind) {
            sharedDefaults.set(mindBrick.currentValue, forKey: "shared_meditation_minutes")
        }
        
        if let fuelBrick = summary.brick(for: .fuel) {
            sharedDefaults.set(fuelBrick.currentValue, forKey: "shared_meal_count")
        }
        
        // Share overall summary
        sharedDefaults.set(summary.overallProgress, forKey: "shared_overall_progress")
        sharedDefaults.set(summary.completedCount, forKey: "shared_completed_count")
        sharedDefaults.set(Date().timeIntervalSince1970, forKey: "shared_last_update")
        
        // Reload widget timelines
        WidgetCenter.shared.reloadTimelines(ofKind: "DailyBricksWidget")
    }
    
    // MARK: - Private Calculation Methods
    
    private func calculateMoveProgress(startOfDay: Date, now: Date) async -> DailyBrickProgress {
        // Goal: 20 minutes of any workout
        let goalMinutes = 20.0
        
        // Get workouts from HealthKit
        var workoutMinutes = await getWorkoutMinutes(startOfDay: startOfDay, now: now, activityTypes: nil)
        
        // Also get workout data from our app database
        let appWorkoutMinutes = await getAppWorkoutMinutes(startOfDay: startOfDay, now: now)
        
        // Use the maximum of HealthKit and app data (to avoid double counting)
        workoutMinutes = max(workoutMinutes, appWorkoutMinutes)
        
        let progress = min(1.0, workoutMinutes / goalMinutes)
        
        return DailyBrickProgress(
            type: .move,
            progress: progress,
            currentValue: workoutMinutes,
            goalValue: goalMinutes,
            unit: "min"
        )
    }
    
    private func calculateHeartProgress(startOfDay: Date, now: Date) async -> DailyBrickProgress {
        // Goal: 30 minutes of cardio (running, biking, swimming, sports)
        let goalMinutes = 30.0
        
        let cardioTypes: [HKWorkoutActivityType] = [
            .running, .cycling, .swimming, .soccer, .basketball,
            .tennis, .americanFootball, .baseball, .volleyball, .hockey
        ]
        
        let cardioMinutes = await getWorkoutMinutes(startOfDay: startOfDay, now: now, activityTypes: cardioTypes)
        
        let progress = min(1.0, cardioMinutes / goalMinutes)
        
        return DailyBrickProgress(
            type: .heart,
            progress: progress,
            currentValue: cardioMinutes,
            goalValue: goalMinutes,
            unit: "min"
        )
    }
    
    private func calculateStrengthProgress(startOfDay: Date, now: Date) async -> DailyBrickProgress {
        // Goal: 1 gym/strength session OR 20 minutes
        let goalMinutes = 20.0
        
        let strengthTypes: [HKWorkoutActivityType] = [
            .traditionalStrengthTraining, .crossTraining, .coreTraining,
            .functionalStrengthTraining
            // Note: .powerlifting and .weightlifting don't exist in HKWorkoutActivityType
            // Use .traditionalStrengthTraining for all weightlifting activities
        ]
        
        var strengthMinutes = await getWorkoutMinutes(startOfDay: startOfDay, now: now, activityTypes: strengthTypes)
        
        // Also check our app database for gym workouts
        let appStrengthData = await getAppStrengthWorkoutData(startOfDay: startOfDay, now: now)
        let appStrengthMinutes = appStrengthData.minutes
        let hasAppSession = appStrengthData.hasSession
        
        // Use the maximum of HealthKit and app data
        strengthMinutes = max(strengthMinutes, appStrengthMinutes)
        
        // Check if we have at least one session (binary completion)
        let hasSession = strengthMinutes > 0 || hasAppSession
        
        // Progress: 100% if session exists, otherwise based on minutes
        let progress = hasSession ? 1.0 : min(1.0, strengthMinutes / goalMinutes)
        
        return DailyBrickProgress(
            type: .strength,
            progress: progress,
            currentValue: strengthMinutes,
            goalValue: goalMinutes,
            unit: "min"
        )
    }
    
    private func calculateRecoveryProgress(startOfDay: Date, now: Date) async -> DailyBrickProgress {
        // Goal: 15 minutes of recovery/balance activities (yoga, stretching, meditation)
        // Progressive calculation - no penalty for working out
        // Focus on balance through recovery activities
        let goalMinutes = 15.0
        
        let recoveryTypes: [HKWorkoutActivityType] = [
            .yoga, .flexibility, .mindAndBody
        ]
        
        var recoveryMinutes = await getWorkoutMinutes(startOfDay: startOfDay, now: now, activityTypes: recoveryTypes)
        
        // Also check our app meditation data (meditation counts as recovery/balance)
        let appGroupDefaults = UserDefaults(suiteName: "group.com.do.fitness")
        if let meditationData = appGroupDefaults?.data(forKey: "meditationSessions"),
           let sessions = try? JSONDecoder().decode([MeditationSessionData].self, from: meditationData) {
            // Filter sessions for today and sum actual duration
            let todaySessions = sessions.filter { session in
                guard let startTimeString = session.startTime,
                      let startTime = ISO8601DateFormatter().date(from: startTimeString) else {
                    return false
                }
                return startTime >= startOfDay && startTime <= now && session.completed == true
            }
            
            let meditationMinutes = todaySessions.reduce(0.0) { total, session in
                total + (Double(session.actualDuration ?? 0) / 60.0)
            }
            
            // Add meditation minutes to recovery (meditation is a form of recovery/balance)
            recoveryMinutes += meditationMinutes
        }
        
        // Progressive progress based on recovery activity minutes
        let progress = min(1.0, recoveryMinutes / goalMinutes)
        
        return DailyBrickProgress(
            type: .recovery,
            progress: progress,
            currentValue: recoveryMinutes,
            goalValue: goalMinutes,
            unit: "min"
        )
    }
    
    private func calculateMindProgress(startOfDay: Date, now: Date) async -> DailyBrickProgress {
        // Goal: 10 minutes of meditation/mindfulness
        let goalMinutes = 10.0
        
        // Get meditation from HealthKit (mindAndBody type)
        var meditationMinutes = await getWorkoutMinutes(
            startOfDay: startOfDay,
            now: now,
            activityTypes: [.mindAndBody]
        )
        
        // Also check our own meditation tracking data from UserDefaults
        let appGroupDefaults = UserDefaults(suiteName: "group.com.do.fitness")
        if let meditationData = appGroupDefaults?.data(forKey: "meditationSessions"),
           let sessions = try? JSONDecoder().decode([MeditationSessionData].self, from: meditationData) {
            // Filter sessions for today and sum actual duration
            let todaySessions = sessions.filter { session in
                guard let startTimeString = session.startTime,
                      let startTime = ISO8601DateFormatter().date(from: startTimeString) else {
                    return false
                }
                return startTime >= startOfDay && startTime <= now && session.completed == true
            }
            
            let appMeditationMinutes = todaySessions.reduce(0.0) { total, session in
                total + (Double(session.actualDuration ?? 0) / 60.0)
            }
            
            // Use the maximum of HealthKit and app data
            meditationMinutes = max(meditationMinutes, appMeditationMinutes)
        }
        
        let progress = min(1.0, meditationMinutes / goalMinutes)
        
        return DailyBrickProgress(
            type: .mind,
            progress: progress,
            currentValue: meditationMinutes,
            goalValue: goalMinutes,
            unit: "min"
        )
    }
    
    private func calculateFuelProgress(startOfDay: Date, now: Date) async -> DailyBrickProgress {
        // Goal: 3 healthy meals logged OR water goal met
        let waterGoal = 64.0 // 8 cups (64 oz)
        let mealGoal = 3.0 // 3 healthy meals
        
        let waterIntake = await getWaterIntake(startOfDay: startOfDay, now: now)
        
        // Get meal count from our app data
        var mealCount = 0.0
        
        // Check UserDefaults for food entries
        let appGroupDefaults = UserDefaults(suiteName: "group.com.do.fitness")
        if let foodData = appGroupDefaults?.data(forKey: "todaysFoods"),
           let foods = try? JSONDecoder().decode([FoodEntryData].self, from: foodData) {
            // Filter foods for today and count distinct meals
            let todayFoods = foods.filter { food in
                guard let timestampString = food.timestamp,
                      let timestamp = ISO8601DateFormatter().date(from: timestampString) else {
                    return false
                }
                return timestamp >= startOfDay && timestamp <= now
            }
            
            // Count unique meal types (breakfast, lunch, dinner, snack)
            let mealTypes = Set(todayFoods.compactMap { $0.mealType })
            mealCount = Double(mealTypes.count)
            
            // Test logging
            TrackingTestLogger.shared.logInfo(category: "FOOD", message: "Read \(foods.count) total entries, \(todayFoods.count) today, \(mealTypes.count) unique meal types from AppGroup")
        } else {
            // Test logging
            TrackingTestLogger.shared.logInfo(category: "FOOD", message: "No food data in AppGroup, requesting from phone")
            
            // Fallback: Request from phone via WatchConnectivity
            mealCount = await requestMealCountFromPhone(startOfDay: startOfDay, now: now)
        }
        
        // Progress: 50% from water, 50% from meals
        // If water goal is met OR 3 meals logged, it's complete
        let waterProgress = min(1.0, waterIntake / waterGoal)
        let mealProgress = min(1.0, mealCount / mealGoal)
        
        // Complete if either water goal OR meal goal is met
        let progress = max(waterProgress, mealProgress)
        
        // For display, show the primary metric (meals if available, otherwise water)
        let displayValue = mealCount > 0 ? mealCount : waterIntake
        let displayUnit = mealCount > 0 ? "meals" : "oz"
        let displayGoal = mealCount > 0 ? mealGoal : waterGoal
        
        return DailyBrickProgress(
            type: .fuel,
            progress: progress,
            currentValue: displayValue,
            goalValue: displayGoal,
            unit: displayUnit
        )
    }
    
    // MARK: - HealthKit Helpers
    
    private func getWorkoutMinutes(startOfDay: Date, now: Date, activityTypes: [HKWorkoutActivityType]?) async -> Double {
        guard HKHealthStore.isHealthDataAvailable() else { return 0.0 }
        
        return await withCheckedContinuation { continuation in
            let workoutType = HKObjectType.workoutType()
            let predicate = HKQuery.predicateForSamples(
                withStart: startOfDay,
                end: now,
                options: .strictStartDate
            )
            
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                guard let workouts = samples as? [HKWorkout], error == nil else {
                    continuation.resume(returning: 0.0)
                    return
                }
                
                var totalMinutes: Double = 0
                
                for workout in workouts {
                    // Filter by activity type if specified
                    if let activityTypes = activityTypes,
                       !activityTypes.contains(workout.workoutActivityType) {
                        continue
                    }
                    
                    let duration = workout.duration // in seconds
                    totalMinutes += duration / 60.0
                }
                
                continuation.resume(returning: totalMinutes)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func hasIntenseWorkoutToday(startOfDay: Date, now: Date) async -> Bool {
        let intenseTypes: [HKWorkoutActivityType] = [
            .running, .cycling, .swimming, .traditionalStrengthTraining,
            .crossTraining, .soccer, .basketball, .tennis
        ]
        
        let minutes = await getWorkoutMinutes(startOfDay: startOfDay, now: now, activityTypes: intenseTypes)
        return minutes > 0
    }
    
    private func getWaterIntake(startOfDay: Date, now: Date) async -> Double {
        guard HKHealthStore.isHealthDataAvailable(),
              let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            return 0.0
        }
        
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: startOfDay,
                end: now,
                options: .strictStartDate
            )
            
            let query = HKStatisticsQuery(
                quantityType: waterType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                guard let sum = result?.sumQuantity(), error == nil else {
                    continuation.resume(returning: 0.0)
                    return
                }
                
                // Convert to fluid ounces
                let fluidOunces = sum.doubleValue(for: HKUnit.fluidOunceUS())
                continuation.resume(returning: fluidOunces)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - App Database Helpers
    
    private func getAppWorkoutMinutes(startOfDay: Date, now: Date) async -> Double {
        // Request workout logs from phone via WatchConnectivity
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            let resumeOnce: (Double) -> Void = { value in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: value)
            }
            
            let message: [String: Any] = [
                "type": "requestDailyBricksData",
                "dataType": "workoutMinutes",
                "startOfDay": startOfDay.timeIntervalSince1970,
                "now": now.timeIntervalSince1970
            ]
            
            WatchConnectivityManager.shared.sendMessage(message) { response in
                if let minutes = response["workoutMinutes"] as? Double {
                    resumeOnce(minutes)
                } else {
                    resumeOnce(0.0)
                }
            } errorHandler: { _ in
                resumeOnce(0.0)
            }
        }
    }
    
    private func getAppStrengthWorkoutData(startOfDay: Date, now: Date) async -> (minutes: Double, hasSession: Bool) {
        // Request gym workout data from phone
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            let resumeOnce: (Double, Bool) -> Void = { minutes, hasSession in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: (minutes, hasSession))
            }
            
            let message: [String: Any] = [
                "type": "requestDailyBricksData",
                "dataType": "strengthWorkout",
                "startOfDay": startOfDay.timeIntervalSince1970,
                "now": now.timeIntervalSince1970
            ]
            
            WatchConnectivityManager.shared.sendMessage(message) { response in
                let minutes = response["strengthMinutes"] as? Double ?? 0.0
                let hasSession = response["hasStrengthSession"] as? Bool ?? false
                resumeOnce(minutes, hasSession)
            } errorHandler: { _ in
                resumeOnce(0.0, false)
            }
        }
    }
    
    // MARK: - Phone Communication Helpers
    
    private func requestMealCountFromPhone(startOfDay: Date, now: Date) async -> Double {
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            let resumeOnce: (Double) -> Void = { value in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: value)
            }
            
            let message: [String: Any] = [
                "type": "requestDailyBricksData",
                "dataType": "mealCount",
                "startOfDay": startOfDay.timeIntervalSince1970,
                "now": now.timeIntervalSince1970
            ]
            
            WatchConnectivityManager.shared.sendMessage(message) { response in
                if let mealCount = response["mealCount"] as? Double {
                    resumeOnce(mealCount)
                } else {
                    resumeOnce(0.0)
                }
            } errorHandler: { _ in
                resumeOnce(0.0)
            }
        }
    }
}

