//
//  DailyBricksWidgetDataManager.swift
//  Do
//
//  Data manager for iOS Daily Bricks widget - merges data from iOS and Watch
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import HealthKit
import WidgetKit

@MainActor
class DailyBricksWidgetDataManager {
    static let shared = DailyBricksWidgetDataManager()
    
    private let healthStore = HKHealthStore()
    private let appGroupIdentifier = "group.com.do.fitness"
    private var userDefaults: UserDefaults?
    
    private init() {
        userDefaults = UserDefaults(suiteName: appGroupIdentifier)
    }
    
    // MARK: - Public Methods
    
    func loadTodaySummary() async -> DailyBricksSummary? {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        // Load data from multiple sources (merged from iOS and Watch)
        async let moveData = loadMoveData(startOfDay: startOfDay)
        async let heartData = loadHeartData(startOfDay: startOfDay)
        async let strengthData = loadStrengthData(startOfDay: startOfDay)
        async let recoveryData = loadRecoveryData(startOfDay: startOfDay)
        async let mindData = loadMindData(startOfDay: startOfDay)
        async let fuelData = loadFuelData(startOfDay: startOfDay)
        
        let (move, heart, strength, recovery, mind, fuel) = await (
            moveData, heartData, strengthData, recoveryData, mindData, fuelData
        )
        
        let bricks = [
            move, heart, strength, recovery, mind, fuel
        ].compactMap { $0 }
        
        guard !bricks.isEmpty else { return nil }
        
        return DailyBricksSummary(bricks: bricks, date: now)
    }
    
    // MARK: - Individual Brick Calculations (Merged from iOS and Watch)
    
    private func loadMoveData(startOfDay: Date) async -> DailyBrickProgress? {
        // Goal: 20 minutes of any workout
        let goalMinutes = 20.0
        
        // Get data from App Group (merged from iOS and Watch)
        var workoutMinutes = getSharedWorkoutMinutes() ?? 0.0
        
        // Also query HealthKit directly to ensure we have the latest data
        let healthKitMinutes = await getWorkoutMinutesFromHealthKit(startOfDay: startOfDay)
        
        // Use the maximum to merge data from both sources (avoid double counting)
        workoutMinutes = max(workoutMinutes, healthKitMinutes)
        
        let progress = min(1.0, workoutMinutes / goalMinutes)
        
        return DailyBrickProgress(
            type: .move,
            progress: progress,
            currentValue: workoutMinutes,
            goalValue: goalMinutes,
            unit: "min"
        )
    }
    
    private func loadHeartData(startOfDay: Date) async -> DailyBrickProgress? {
        // Goal: 30 minutes of cardio
        let goalMinutes = 30.0
        
        let minutes = await getCardioMinutesFromHealthKit(startOfDay: startOfDay)
        let progress = min(1.0, minutes / goalMinutes)
        
        return DailyBrickProgress(
            type: .heart,
            progress: progress,
            currentValue: minutes,
            goalValue: goalMinutes,
            unit: "min"
        )
    }
    
    private func loadStrengthData(startOfDay: Date) async -> DailyBrickProgress? {
        // Goal: 1 strength session or 20 minutes
        let goalMinutes = 20.0
        
        // Get shared data (merged from iOS and Watch)
        var (minutes, hasSession) = getSharedStrengthData() ?? (0.0, false)
        
        // Also query HealthKit to merge data
        let (healthKitMinutes, healthKitHasSession) = await getStrengthDataFromHealthKit(startOfDay: startOfDay)
        
        // Merge: use maximum minutes and OR the session flags
        minutes = max(minutes, healthKitMinutes)
        hasSession = hasSession || healthKitHasSession
        
        let progress = hasSession ? 1.0 : min(1.0, minutes / goalMinutes)
        
        return DailyBrickProgress(
            type: .strength,
            progress: progress,
            currentValue: hasSession ? goalMinutes : minutes,
            goalValue: goalMinutes,
            unit: hasSession ? "session" : "min"
        )
    }
    
    private func loadRecoveryData(startOfDay: Date) async -> DailyBrickProgress? {
        // Goal: Rest day or recovery activity (yoga, stretching)
        let hasRecovery = await hasRecoveryActivity(startOfDay: startOfDay)
        
        return DailyBrickProgress(
            type: .recovery,
            progress: hasRecovery ? 1.0 : 0.0,
            currentValue: hasRecovery ? 1.0 : 0.0,
            goalValue: 1.0,
            unit: hasRecovery ? "activity" : ""
        )
    }
    
    private func loadMindData(startOfDay: Date) async -> DailyBrickProgress? {
        // Goal: 10 minutes of meditation
        let goalMinutes = 10.0
        
        // Get shared data (merged from iOS and Watch)
        var minutes = getSharedMeditationMinutes() ?? 0.0
        
        // Also query HealthKit to merge data
        let healthKitMinutes = await getMeditationMinutesFromHealthKit(startOfDay: startOfDay)
        
        // Use maximum to merge data from both sources
        minutes = max(minutes, healthKitMinutes)
        
        let progress = min(1.0, minutes / goalMinutes)
        
        return DailyBrickProgress(
            type: .mind,
            progress: progress,
            currentValue: minutes,
            goalValue: goalMinutes,
            unit: "min"
        )
    }
    
    private func loadFuelData(startOfDay: Date) async -> DailyBrickProgress? {
        // Goal: 3 healthy meals or water goal
        let goalMeals = 3.0
        
        // Get shared meal count (merged from iOS and Watch)
        var mealCount = getSharedMealCount() ?? 0.0
        
        // Also check water intake from HealthKit
        let waterProgress = await getWaterIntakeProgress(startOfDay: startOfDay)
        
        // Progress: 50% from meals, 50% from water, or complete if either goal is met
        let mealProgress = min(1.0, mealCount / goalMeals)
        let progress = max(mealProgress, waterProgress)
        
        // For display, show meals if available, otherwise water progress
        let displayValue = mealCount > 0 ? mealCount : (waterProgress * goalMeals)
        
        return DailyBrickProgress(
            type: .fuel,
            progress: progress,
            currentValue: displayValue,
            goalValue: goalMeals,
            unit: mealCount > 0 ? "meals" : (waterProgress >= 1.0 ? "goal" : "meals")
        )
    }
    
    // MARK: - Shared Data (App Group - Merged from iOS and Watch)
    
    private func getSharedWorkoutMinutes() -> Double? {
        return userDefaults?.double(forKey: "shared_workout_minutes")
    }
    
    private func getSharedStrengthData() -> (minutes: Double, hasSession: Bool)? {
        guard let minutes = userDefaults?.double(forKey: "shared_strength_minutes"),
              let hasSession = userDefaults?.bool(forKey: "shared_strength_session") else {
            return nil
        }
        return (minutes, hasSession)
    }
    
    private func getSharedMeditationMinutes() -> Double? {
        return userDefaults?.double(forKey: "shared_meditation_minutes")
    }
    
    private func getSharedMealCount() -> Double? {
        return userDefaults?.double(forKey: "shared_meal_count")
    }
    
    // MARK: - HealthKit Queries
    
    private func getWorkoutMinutesFromHealthKit(startOfDay: Date) async -> Double {
        guard HKHealthStore.isHealthDataAvailable() else {
            return 0.0
        }
        
        let workoutType = HKWorkoutType.workoutType()
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                let totalMinutes = workouts.reduce(0.0) { $0 + $1.duration / 60.0 }
                continuation.resume(returning: totalMinutes)
            }
            healthStore.execute(query)
        }
    }
    
    private func getCardioMinutesFromHealthKit(startOfDay: Date) async -> Double {
        guard HKHealthStore.isHealthDataAvailable() else {
            return 0.0
        }
        
        let workoutType = HKWorkoutType.workoutType()
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )
        
        let cardioTypes: Set<HKWorkoutActivityType> = [
            .running, .cycling, .swimming, .rowing, .elliptical, .highIntensityIntervalTraining
        ]
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let cardioWorkouts = (samples as? [HKWorkout])?.filter { cardioTypes.contains($0.workoutActivityType) } ?? []
                let totalMinutes = cardioWorkouts.reduce(0.0) { $0 + $1.duration / 60.0 }
                continuation.resume(returning: totalMinutes)
            }
            healthStore.execute(query)
        }
    }
    
    private func getStrengthDataFromHealthKit(startOfDay: Date) async -> (minutes: Double, hasSession: Bool) {
        guard HKHealthStore.isHealthDataAvailable() else {
            return (0.0, false)
        }
        
        let workoutType = HKWorkoutType.workoutType()
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )
        
        let strengthTypes: Set<HKWorkoutActivityType> = [
            .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining
        ]
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let strengthWorkouts = (samples as? [HKWorkout])?.filter { strengthTypes.contains($0.workoutActivityType) } ?? []
                let hasSession = !strengthWorkouts.isEmpty
                let totalMinutes = strengthWorkouts.reduce(0.0) { $0 + $1.duration / 60.0 }
                continuation.resume(returning: (totalMinutes, hasSession))
            }
            healthStore.execute(query)
        }
    }
    
    private func hasRecoveryActivity(startOfDay: Date) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }
        
        let workoutType = HKWorkoutType.workoutType()
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )
        
        let recoveryTypes: Set<HKWorkoutActivityType> = [
            .yoga, .flexibility, .mindAndBody
        ]
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let hasRecovery = (samples as? [HKWorkout])?.contains { recoveryTypes.contains($0.workoutActivityType) } ?? false
                continuation.resume(returning: hasRecovery)
            }
            healthStore.execute(query)
        }
    }
    
    private func getMeditationMinutesFromHealthKit(startOfDay: Date) async -> Double {
        guard HKHealthStore.isHealthDataAvailable() else {
            return 0.0
        }
        
        let workoutType = HKWorkoutType.workoutType()
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let meditationWorkouts = (samples as? [HKWorkout])?.filter { $0.workoutActivityType == .mindAndBody } ?? []
                let totalMinutes = meditationWorkouts.reduce(0.0) { $0 + $1.duration / 60.0 }
                continuation.resume(returning: totalMinutes)
            }
            healthStore.execute(query)
        }
    }
    
    private func getWaterIntakeProgress(startOfDay: Date) async -> Double {
        guard HKHealthStore.isHealthDataAvailable(),
              let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            return 0.0
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )
        
        // Goal: 2 liters (2000ml)
        let goalML = 2000.0
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: waterType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                if let sum = result?.sumQuantity() {
                    let ml = sum.doubleValue(for: HKUnit.literUnit(with: .milli))
                    let progress = min(1.0, ml / goalML)
                    continuation.resume(returning: progress)
                } else {
                    continuation.resume(returning: 0.0)
                }
            }
            healthStore.execute(query)
        }
    }
}


