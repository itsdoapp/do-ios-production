//
//  DailyBricksService.swift
//  Do Watch App
//
//  Daily bricks service for watchOS - tracks 6 daily "bricks" (Move, Heart, Strength, Recovery, Mind, Fuel)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

#if os(watchOS)
import Foundation
import Combine
import HealthKit
import WidgetKit

class DailyBricksService: ObservableObject {
    static let shared = DailyBricksService()
    
    @Published var todayProgress: Double = 0.0
    @Published var bricks: [DailyBrickProgress] = []
    @Published var isLoading = false
    
    private let healthStore = HKHealthStore()
    private let appGroupIdentifier = "group.com.do.fitness"
    private var userDefaults: UserDefaults?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        userDefaults = UserDefaults(suiteName: appGroupIdentifier)
        loadTodayProgress()
        
        // Reload progress every hour
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.loadTodayProgress()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadTodayProgress() {
        isLoading = true
        
        Task {
            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)
            
            // Load all brick data
            async let moveData = loadMoveData(startOfDay: startOfDay)
            async let heartData = loadHeartData(startOfDay: startOfDay)
            async let strengthData = loadStrengthData(startOfDay: startOfDay)
            async let recoveryData = loadRecoveryData(startOfDay: startOfDay)
            async let mindData = loadMindData(startOfDay: startOfDay)
            async let fuelData = loadFuelData(startOfDay: startOfDay)
            
            let (move, heart, strength, recovery, mind, fuel) = await (
                moveData, heartData, strengthData, recoveryData, mindData, fuelData
            )
            
            let loadedBricks = [move, heart, strength, recovery, mind, fuel].compactMap { $0 }
            
            await MainActor.run {
                self.bricks = loadedBricks
                // Calculate overall progress (average of all bricks)
                if !loadedBricks.isEmpty {
                    self.todayProgress = loadedBricks.map { $0.progress }.reduce(0, +) / Double(loadedBricks.count)
                } else {
                    self.todayProgress = 0.0
                }
                self.isLoading = false
                
                // Reload widget timeline
                WidgetCenter.shared.reloadTimelines(ofKind: "DailyBricksWidget")
            }
        }
    }
    
    // MARK: - Individual Brick Loading
    
    private func loadMoveData(startOfDay: Date) async -> DailyBrickProgress? {
        let goalMinutes = 20.0
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
        let goalMinutes = 20.0
        let minutes = await getStrengthMinutesFromHealthKit(startOfDay: startOfDay)
        let progress = min(1.0, minutes / goalMinutes)
        
        return DailyBrickProgress(
            type: .strength,
            progress: progress,
            currentValue: minutes,
            goalValue: goalMinutes,
            unit: "min"
        )
    }
    
    private func loadRecoveryData(startOfDay: Date) async -> DailyBrickProgress? {
        // Recovery: 10 minutes of yoga/stretching
        let goalMinutes = 10.0
        let minutes = await getRecoveryMinutesFromHealthKit(startOfDay: startOfDay)
        let progress = min(1.0, minutes / goalMinutes)
        
        return DailyBrickProgress(
            type: .recovery,
            progress: progress,
            currentValue: minutes,
            goalValue: goalMinutes,
            unit: "min"
        )
    }
    
    private func loadMindData(startOfDay: Date) async -> DailyBrickProgress? {
        // Mind: 10 minutes of meditation
        let goalMinutes = 10.0
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
        // Fuel: 3 healthy meals or water goal
        let goalMeals = 3.0
        let mealCount = getSharedMealCount() ?? 0.0
        let progress = min(1.0, mealCount / goalMeals)
        
        return DailyBrickProgress(
            type: .fuel,
            progress: progress,
            currentValue: mealCount,
            goalValue: goalMeals,
            unit: "meals"
        )
    }
    
    // MARK: - HealthKit Queries
    
    private func getWorkoutMinutesFromHealthKit(startOfDay: Date) async -> Double {
        let workoutType = HKObjectType.workoutType()
        
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
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                guard let workouts = samples as? [HKWorkout], error == nil else {
                    continuation.resume(returning: 0.0)
                    return
                }
                
                let totalMinutes = workouts.reduce(0.0) { total, workout in
                    total + workout.duration / 60.0
                }
                
                continuation.resume(returning: totalMinutes)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func getCardioMinutesFromHealthKit(startOfDay: Date) async -> Double {
        let workoutType = HKObjectType.workoutType()
        
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
            ) { _, samples, error in
                guard let workouts = samples as? [HKWorkout], error == nil else {
                    continuation.resume(returning: 0.0)
                    return
                }
                
                // Filter for cardio workouts
                let cardioTypes: Set<HKWorkoutActivityType> = [
                    .running, .walking, .cycling, .rowing, .elliptical, .stairClimbing
                ]
                
                let cardioMinutes = workouts
                    .filter { cardioTypes.contains($0.workoutActivityType) }
                    .reduce(0.0) { $0 + $1.duration / 60.0 }
                
                continuation.resume(returning: cardioMinutes)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func getStrengthMinutesFromHealthKit(startOfDay: Date) async -> Double {
        let workoutType = HKObjectType.workoutType()
        
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
            ) { _, samples, error in
                guard let workouts = samples as? [HKWorkout], error == nil else {
                    continuation.resume(returning: 0.0)
                    return
                }
                
                let strengthTypes: Set<HKWorkoutActivityType> = [
                    .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining
                ]
                
                let strengthMinutes = workouts
                    .filter { strengthTypes.contains($0.workoutActivityType) }
                    .reduce(0.0) { $0 + $1.duration / 60.0 }
                
                continuation.resume(returning: strengthMinutes)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func getRecoveryMinutesFromHealthKit(startOfDay: Date) async -> Double {
        let workoutType = HKObjectType.workoutType()
        
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
            ) { _, samples, error in
                guard let workouts = samples as? [HKWorkout], error == nil else {
                    continuation.resume(returning: 0.0)
                    return
                }
                
                let recoveryTypes: Set<HKWorkoutActivityType> = [
                    .yoga, .flexibility, .cooldown
                ]
                
                let recoveryMinutes = workouts
                    .filter { recoveryTypes.contains($0.workoutActivityType) }
                    .reduce(0.0) { $0 + $1.duration / 60.0 }
                
                continuation.resume(returning: recoveryMinutes)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func getMeditationMinutesFromHealthKit(startOfDay: Date) async -> Double {
        let workoutType = HKObjectType.workoutType()
        
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
            ) { _, samples, error in
                guard let workouts = samples as? [HKWorkout], error == nil else {
                    continuation.resume(returning: 0.0)
                    return
                }
                
                let meditationMinutes = workouts
                    .filter { $0.workoutActivityType == .mindAndBody }
                    .reduce(0.0) { $0 + $1.duration / 60.0 }
                
                continuation.resume(returning: meditationMinutes)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Shared Data (App Group)
    
    private func getSharedMealCount() -> Double? {
        return userDefaults?.double(forKey: "dailyMealCount")
    }
    
    private func getSharedWorkoutMinutes() -> Double? {
        return userDefaults?.double(forKey: "dailyWorkoutMinutes")
    }
    
    // MARK: - Save to App Group
    
    func saveWorkoutMinutes(_ minutes: Double) {
        userDefaults?.set(minutes, forKey: "dailyWorkoutMinutes")
        userDefaults?.synchronize()
    }
    
    func saveMealCount(_ count: Double) {
        userDefaults?.set(count, forKey: "dailyMealCount")
        userDefaults?.synchronize()
    }
    
    // MARK: - Computed Properties
    
    var summary: DailyBricksSummary? {
        guard !bricks.isEmpty else { return nil }
        return DailyBricksSummary(bricks: bricks, date: Date())
    }
}
#endif
