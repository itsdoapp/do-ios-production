//
//  DailyBricksWidgetDataManager.swift
//  Do Watch App
//
//  Data manager for WidgetKit complications
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
        
        // Load data from multiple sources
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
    
    // MARK: - Individual Brick Calculations
    
    private func loadMoveData(startOfDay: Date) async -> DailyBrickProgress? {
        // Goal: 20 minutes of any workout
        let goalMinutes = 20.0
        
        // Try to get from shared data first
        if let minutes = getSharedWorkoutMinutes() {
            let progress = min(1.0, minutes / goalMinutes)
            return DailyBrickProgress(
                type: .move,
                progress: progress,
                currentValue: minutes,
                goalValue: goalMinutes,
                unit: "min"
            )
        }
        
        // Fallback to HealthKit
        let minutes = await getWorkoutMinutesFromHealthKit(startOfDay: startOfDay)
        let progress = min(1.0, minutes / goalMinutes)
        
        return DailyBrickProgress(
            type: .move,
            progress: progress,
            currentValue: minutes,
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
        
        // Try shared data first
        if let (minutes, hasSession) = getSharedStrengthData() {
            let progress = hasSession ? 1.0 : min(1.0, minutes / goalMinutes)
            return DailyBrickProgress(
                type: .strength,
                progress: progress,
                currentValue: hasSession ? goalMinutes : minutes,
                goalValue: goalMinutes,
                unit: hasSession ? "session" : "min"
            )
        }
        
        // Fallback to HealthKit
        let (minutes, hasSession) = await getStrengthDataFromHealthKit(startOfDay: startOfDay)
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
        
        // Try shared data first
        if let minutes = getSharedMeditationMinutes() {
            let progress = min(1.0, minutes / goalMinutes)
            return DailyBrickProgress(
                type: .mind,
                progress: progress,
                currentValue: minutes,
                goalValue: goalMinutes,
                unit: "min"
            )
        }
        
        // Fallback to HealthKit
        let minutes = await getMeditationMinutesFromHealthKit(startOfDay: startOfDay)
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
        
        // Try shared data first
        if let mealCount = getSharedMealCount() {
            let progress = min(1.0, mealCount / goalMeals)
            return DailyBrickProgress(
                type: .fuel,
                progress: progress,
                currentValue: mealCount,
                goalValue: goalMeals,
                unit: "meals"
            )
        }
        
        // Fallback: check water intake from HealthKit
        let waterProgress = await getWaterIntakeProgress(startOfDay: startOfDay)
        
        return DailyBrickProgress(
            type: .fuel,
            progress: waterProgress,
            currentValue: waterProgress * goalMeals,
            goalValue: goalMeals,
            unit: waterProgress >= 1.0 ? "goal" : "meals"
        )
    }
    
    // MARK: - Shared Data (App Group)
    
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
        guard HKHealthStore.isHealthDataAvailable(),
              let workoutType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return 0.0
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: workoutType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                if let sum = result?.sumQuantity() {
                    // Estimate minutes from calories (rough approximation)
                    let calories = sum.doubleValue(for: HKUnit.kilocalorie())
                    let estimatedMinutes = calories / 10.0 // ~10 cal/min for moderate activity
                    continuation.resume(returning: min(estimatedMinutes, 120.0))
                } else {
                    continuation.resume(returning: 0.0)
                }
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
        
        // Assume goal is 2 liters (2000ml)
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

