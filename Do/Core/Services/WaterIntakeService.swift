//
//  WaterIntakeService.swift
//  Do
//
//  Service for tracking daily water intake
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import Combine
import HealthKit
import UIKit

class WaterIntakeService: ObservableObject {
    static let shared = WaterIntakeService()
    
    // MARK: - Published Properties
    
    @Published var todayIntake: Double = 0.0 // in fluid ounces
    @Published var dailyGoal: Double = 64.0 // 8 cups (64 oz)
    @Published var waterLog: [WaterEntry] = []
    @Published var weeklyData: [Date: Double] = [:]
    
    // MARK: - Private Properties
    
    private let healthStore = HKHealthStore()
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    // Keys for UserDefaults
    private let dailyGoalKey = "waterDailyGoal"
    private let todayIntakeKey = "waterTodayIntake"
    private let lastUpdateDateKey = "waterLastUpdateDate"
    
    // MARK: - Initialization
    
    private init() {
        loadDailyGoal()
        loadTodayIntake()
        setupDayChangeObserver()
    }
    
    // MARK: - Public Methods
    
    /// Add water intake in fluid ounces
    func addWater(amount: Double) {
        let entry = WaterEntry(
            id: UUID().uuidString,
            amount: amount,
            timestamp: Date(),
            unit: .fluidOunces
        )
        
        waterLog.insert(entry, at: 0)
        todayIntake += amount
        
        saveTodayIntake()
        saveToHealthKit(amount: amount)
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .waterIntakeUpdated, object: nil)
    }
    
    /// Remove a water entry
    func removeWaterEntry(id: String) {
        guard let index = waterLog.firstIndex(where: { $0.id == id }) else { return }
        let entry = waterLog[index]
        
        waterLog.remove(at: index)
        todayIntake -= entry.amount
        
        saveTodayIntake()
    }
    
    /// Update daily goal
    func updateDailyGoal(_ newGoal: Double) {
        dailyGoal = newGoal
        userDefaults.set(newGoal, forKey: dailyGoalKey)
    }
    
    /// Get progress percentage (0.0 to 1.0)
    func getProgress() -> Double {
        guard dailyGoal > 0 else { return 0 }
        return min(todayIntake / dailyGoal, 1.0)
    }
    
    /// Get remaining amount to reach goal
    func getRemainingAmount() -> Double {
        return max(dailyGoal - todayIntake, 0)
    }
    
    /// Load weekly water intake data
    func loadWeeklyData() {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        
        // Load from UserDefaults or HealthKit
        for day in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: day, to: startOfWeek) {
                let key = "waterIntake_\(dateString(from: date))"
                let intake = userDefaults.double(forKey: key)
                weeklyData[date] = intake
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadDailyGoal() {
        dailyGoal = userDefaults.double(forKey: dailyGoalKey)
        if dailyGoal == 0 {
            dailyGoal = 64.0 // Default to 64 oz (8 cups)
        }
    }
    
    private func loadTodayIntake() {
        let lastUpdateDate = userDefaults.object(forKey: lastUpdateDateKey) as? Date ?? Date.distantPast
        let calendar = Calendar.current
        
        if calendar.isDateInToday(lastUpdateDate) {
            todayIntake = userDefaults.double(forKey: todayIntakeKey)
        } else {
            // New day, reset intake
            resetDailyIntake()
        }
    }
    
    private func saveTodayIntake() {
        userDefaults.set(todayIntake, forKey: todayIntakeKey)
        userDefaults.set(Date(), forKey: lastUpdateDateKey)
        
        // Save to daily log
        let dateKey = "waterIntake_\(dateString(from: Date()))"
        userDefaults.set(todayIntake, forKey: dateKey)
    }
    
    private func resetDailyIntake() {
        todayIntake = 0
        waterLog.removeAll()
        userDefaults.set(0, forKey: todayIntakeKey)
        userDefaults.set(Date(), forKey: lastUpdateDateKey)
    }
    
    private func setupDayChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkDayChange()
        }
    }
    
    private func checkDayChange() {
        let lastUpdateDate = userDefaults.object(forKey: lastUpdateDateKey) as? Date ?? Date.distantPast
        let calendar = Calendar.current
        
        if !calendar.isDateInToday(lastUpdateDate) {
            resetDailyIntake()
        }
    }
    
    private func saveToHealthKit(amount: Double) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        // Convert fluid ounces to liters
        let liters = amount * 0.0295735
        
        let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        let quantity = HKQuantity(unit: .literUnit(with: .none), doubleValue: liters)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: Date(), end: Date())
        
        healthStore.save(sample) { success, error in
            if let error = error {
                print("❌ Error saving water to HealthKit: \(error.localizedDescription)")
            }
        }
    }
    
    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - WaterEntry Model

struct WaterEntry: Identifiable, Codable {
    let id: String
    let amount: Double // in fluid ounces
    let timestamp: Date
    let unit: WaterUnit
    
    enum WaterUnit: String, Codable {
        case fluidOunces = "fl oz"
        case cups = "cups"
        case milliliters = "ml"
        case liters = "L"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let waterIntakeUpdated = Notification.Name("WaterIntakeUpdated")
}








