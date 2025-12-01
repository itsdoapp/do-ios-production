//
//  HeartRateZoneService.swift
//  Do Watch App
//
//  Heart Rate Zones service using watchOS 9.0+ APIs
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import HealthKit
import Combine
import SwiftUI

// MARK: - Heart Rate Zone

enum HeartRateZone: Int, CaseIterable, Identifiable {
    case zone1 = 1  // Recovery (50-60% of max HR)
    case zone2 = 2  // Aerobic (60-70% of max HR)
    case zone3 = 3  // Tempo (70-80% of max HR)
    case zone4 = 4  // Threshold (80-90% of max HR)
    case zone5 = 5  // Maximum (90-100% of max HR)
    
    var id: Int { rawValue }
    
    var name: String {
        switch self {
        case .zone1: return "Recovery"
        case .zone2: return "Aerobic"
        case .zone3: return "Tempo"
        case .zone4: return "Threshold"
        case .zone5: return "Maximum"
        }
    }
    
    var color: Color {
        switch self {
        case .zone1: return .blue
        case .zone2: return .green
        case .zone3: return .yellow
        case .zone4: return .orange
        case .zone5: return .red
        }
    }
    
    var description: String {
        switch self {
        case .zone1: return "Easy recovery pace"
        case .zone2: return "Comfortable aerobic base"
        case .zone3: return "Moderate tempo effort"
        case .zone4: return "Hard threshold pace"
        case .zone5: return "Maximum effort"
        }
    }
    
    func range(minHR: Double, maxHR: Double) -> ClosedRange<Double> {
        let percentages: (Double, Double)
        switch self {
        case .zone1: percentages = (0.50, 0.60)
        case .zone2: percentages = (0.60, 0.70)
        case .zone3: percentages = (0.70, 0.80)
        case .zone4: percentages = (0.80, 0.90)
        case .zone5: percentages = (0.90, 1.00)
        }
        return (maxHR * percentages.0)...(maxHR * percentages.1)
    }
}

// MARK: - Heart Rate Zone Service

@MainActor
class HeartRateZoneService: ObservableObject {
    static let shared = HeartRateZoneService()
    
    @Published var currentZone: HeartRateZone?
    @Published var maxHeartRate: Double = 190.0 // Default, will be calculated
    @Published var restingHeartRate: Double = 60.0
    @Published var zoneTimeSpent: [HeartRateZone: TimeInterval] = [:]
    @Published var zonePercentages: [HeartRateZone: Double] = [:]
    
    private let healthStore = HKHealthStore()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadUserHeartRateData()
    }
    
    // MARK: - Zone Calculation
    
    /// Calculate heart rate zone from current heart rate
    func calculateZone(for heartRate: Double) -> HeartRateZone? {
        guard heartRate > 0 else { return nil }
        
        for zone in HeartRateZone.allCases.reversed() {
            let range = zone.range(minHR: restingHeartRate, maxHR: maxHeartRate)
            if range.contains(heartRate) {
                return zone
            }
        }
        
        // If above max, return zone 5
        if heartRate > maxHeartRate {
            return .zone5
        }
        
        // If below zone 1, return zone 1
        return .zone1
    }
    
    /// Update current zone and track time spent
    func updateZone(for heartRate: Double, duration: TimeInterval = 1.0) {
        guard let newZone = calculateZone(for: heartRate) else { return }
        
        let previousZone = currentZone
        currentZone = newZone
        
        // Track time spent in zone
        if let previous = previousZone, previous == newZone {
            // Same zone, accumulate time
            zoneTimeSpent[newZone, default: 0] += duration
        } else if previousZone != nil {
            // Zone changed, add duration to new zone
            zoneTimeSpent[newZone, default: 0] += duration
        }
        
        // Calculate percentages
        updateZonePercentages()
    }
    
    /// Reset zone tracking for a new workout
    func resetZoneTracking() {
        zoneTimeSpent = [:]
        zonePercentages = [:]
        currentZone = nil
    }
    
    /// Get zone summary for current workout
    func getZoneSummary() -> (totalTime: TimeInterval, zones: [HeartRateZone: TimeInterval]) {
        let totalTime = zoneTimeSpent.values.reduce(0, +)
        return (totalTime, zoneTimeSpent)
    }
    
    // MARK: - User Heart Rate Data
    
    private func loadUserHeartRateData() {
        Task {
            await fetchMaxHeartRate()
            await fetchRestingHeartRate()
        }
    }
    
    private func fetchMaxHeartRate() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            // Use age-based formula: 220 - age (default to 30 years old)
            maxHeartRate = 190.0
            return
        }
        
        // Try to get user's date of birth for age calculation
        do {
            let dateOfBirth = try healthStore.dateOfBirthComponents()
            if let birthDate = dateOfBirth.date {
                let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 30
                // Use age-based formula: 220 - age
                maxHeartRate = Double(220 - age)
                return
            }
        } catch {
            // Fallback: use historical max heart rate
        }
        
        // Fallback: use historical max heart rate from workouts
        await fetchHistoricalMaxHeartRate()
    }
    
    private func fetchHistoricalMaxHeartRate() async {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            maxHeartRate = 190.0
            return
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: .discreteMax
            ) { _, result, error in
                if let max = result?.maximumQuantity() {
                    let maxHR = max.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                    DispatchQueue.main.async {
                        self.maxHeartRate = maxHR > 0 ? maxHR : 190.0
                    }
                } else {
                    DispatchQueue.main.async {
                        self.maxHeartRate = 190.0
                    }
                }
                continuation.resume()
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchRestingHeartRate() async {
        guard HKHealthStore.isHealthDataAvailable(),
              let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            restingHeartRate = 60.0
            return
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: restingHRType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                if let avg = result?.averageQuantity() {
                    let restingHR = avg.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                    DispatchQueue.main.async {
                        self.restingHeartRate = restingHR > 0 ? restingHR : 60.0
                    }
                } else {
                    DispatchQueue.main.async {
                        self.restingHeartRate = 60.0
                    }
                }
                continuation.resume()
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateZonePercentages() {
        let totalTime = zoneTimeSpent.values.reduce(0, +)
        guard totalTime > 0 else {
            zonePercentages = [:]
            return
        }
        
        for zone in HeartRateZone.allCases {
            let timeInZone = zoneTimeSpent[zone] ?? 0
            zonePercentages[zone] = (timeInZone / totalTime) * 100.0
        }
    }
}

// MARK: - Color Extension

extension Color {
    static var brandOrange: Color {
        Color(red: 0.969, green: 0.576, blue: 0.122)
    }
}

