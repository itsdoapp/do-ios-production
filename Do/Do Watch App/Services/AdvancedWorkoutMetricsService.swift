//
//  AdvancedWorkoutMetricsService.swift
//  Do Watch App
//
//  Service for advanced running metrics (watchOS 9.0+)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import HealthKit
import Combine

// MARK: - Advanced Running Metrics

struct AdvancedRunningMetrics {
    var runningPower: Double? // Watts
    var strideLength: Double? // Meters
    var groundContactTime: Double? // Seconds
    var verticalOscillation: Double? // Centimeters
    var heartRateVariability: Double? // SDNN in milliseconds
    
    var hasAnyMetrics: Bool {
        runningPower != nil || strideLength != nil || 
        groundContactTime != nil || verticalOscillation != nil || 
        heartRateVariability != nil
    }
}

// MARK: - Advanced Workout Metrics Service

@MainActor
class AdvancedWorkoutMetricsService: ObservableObject {
    static let shared = AdvancedWorkoutMetricsService()
    
    @Published var currentMetrics = AdvancedRunningMetrics()
    @Published var isCollecting = false
    
    private let healthStore = HKHealthStore()
    private var currentBuilder: HKLiveWorkoutBuilder?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Setup
    
    func startCollecting(with builder: HKLiveWorkoutBuilder) {
        currentBuilder = builder
        isCollecting = true
        
        // Set up queries for advanced metrics
        setupRunningPowerQuery()
        setupStrideLengthQuery()
        setupGroundContactTimeQuery()
        setupVerticalOscillationQuery()
        setupHRVQuery()
    }
    
    func stopCollecting() {
        isCollecting = false
        currentBuilder = nil
    }
    
    // MARK: - Running Power (watchOS 9.0+)
    
    private func setupRunningPowerQuery() {
        guard let powerType = HKQuantityType.quantityType(forIdentifier: .runningPower) else {
            print("⚠️ [AdvancedMetrics] Running Power not available on this device")
            return
        }
        
        // Request authorization
        healthStore.requestAuthorization(toShare: nil, read: [powerType]) { success, error in
            if success {
                print("✅ [AdvancedMetrics] Running Power authorization granted")
            }
        }
    }
    
    func getRunningPower() async -> Double? {
        guard let powerType = HKQuantityType.quantityType(forIdentifier: .runningPower),
              let builder = currentBuilder else {
            return nil
        }
        
        // statistics(for:) returns synchronously, not via completion handler
        let statistics = builder.statistics(for: powerType)
        if let stats = statistics,
           let mostRecent = stats.mostRecentQuantity() {
            let power = mostRecent.doubleValue(for: HKUnit.watt())
            return power > 0 ? power : nil
        }
        return nil
    }
    
    // MARK: - Stride Length (watchOS 9.0+)
    
    private func setupStrideLengthQuery() {
        guard let strideType = HKQuantityType.quantityType(forIdentifier: .runningStrideLength) else {
            print("⚠️ [AdvancedMetrics] Stride Length not available")
            return
        }
        
        healthStore.requestAuthorization(toShare: nil, read: [strideType]) { success, error in
            if success {
                print("✅ [AdvancedMetrics] Stride Length authorization granted")
            }
        }
    }
    
    func getStrideLength() async -> Double? {
        guard let strideType = HKQuantityType.quantityType(forIdentifier: .runningStrideLength),
              let builder = currentBuilder else {
            return nil
        }
        
        // statistics(for:) returns synchronously, not via completion handler
        let statistics = builder.statistics(for: strideType)
        if let stats = statistics,
           let average = stats.averageQuantity() {
            let stride = average.doubleValue(for: HKUnit.meter())
            return stride > 0 ? stride : nil
        }
        return nil
    }
    
    // MARK: - Ground Contact Time (watchOS 9.0+)
    
    private func setupGroundContactTimeQuery() {
        guard let gctType = HKQuantityType.quantityType(forIdentifier: .runningGroundContactTime) else {
            print("⚠️ [AdvancedMetrics] Ground Contact Time not available")
            return
        }
        
        healthStore.requestAuthorization(toShare: nil, read: [gctType]) { success, error in
            if success {
                print("✅ [AdvancedMetrics] Ground Contact Time authorization granted")
            }
        }
    }
    
    func getGroundContactTime() async -> Double? {
        guard let gctType = HKQuantityType.quantityType(forIdentifier: .runningGroundContactTime),
              let builder = currentBuilder else {
            return nil
        }
        
        // statistics(for:) returns synchronously, not via completion handler
        let statistics = builder.statistics(for: gctType)
        if let stats = statistics,
           let average = stats.averageQuantity() {
            let gct = average.doubleValue(for: HKUnit.second())
            return gct > 0 ? gct : nil
        }
        return nil
    }
    
    // MARK: - Vertical Oscillation (watchOS 9.0+)
    
    private func setupVerticalOscillationQuery() {
        guard let voType = HKQuantityType.quantityType(forIdentifier: .runningVerticalOscillation) else {
            print("⚠️ [AdvancedMetrics] Vertical Oscillation not available")
            return
        }
        
        healthStore.requestAuthorization(toShare: nil, read: [voType]) { success, error in
            if success {
                print("✅ [AdvancedMetrics] Vertical Oscillation authorization granted")
            }
        }
    }
    
    func getVerticalOscillation() async -> Double? {
        guard let voType = HKQuantityType.quantityType(forIdentifier: .runningVerticalOscillation),
              let builder = currentBuilder else {
            return nil
        }
        
        // statistics(for:) returns synchronously, not via completion handler
        let statistics = builder.statistics(for: voType)
        if let stats = statistics,
           let average = stats.averageQuantity() {
            // Convert from meters to centimeters
            let vo = average.doubleValue(for: HKUnit.meter()) * 100.0
            return vo > 0 ? vo : nil
        }
        return nil
    }
    
    // MARK: - Heart Rate Variability (watchOS 9.0+)
    
    private func setupHRVQuery() {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            print("⚠️ [AdvancedMetrics] HRV not available")
            return
        }
        
        healthStore.requestAuthorization(toShare: nil, read: [hrvType]) { success, error in
            if success {
                print("✅ [AdvancedMetrics] HRV authorization granted")
            }
        }
    }
    
    func getHeartRateVariability() async -> Double? {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
              let builder = currentBuilder else {
            return nil
        }
        
        // statistics(for:) returns synchronously, not via completion handler
        let statistics = builder.statistics(for: hrvType)
        if let stats = statistics,
           let mostRecent = stats.mostRecentQuantity() {
            let hrv = mostRecent.doubleValue(for: HKUnit.secondUnit(with: .milli))
            return hrv > 0 ? hrv : nil
        }
        return nil
    }
    
    // MARK: - Update All Metrics
    
    func updateAllMetrics() async {
        guard isCollecting else { return }
        
        // Since the get methods are now synchronous, we can call them directly
        // and update on the main actor (this class is already @MainActor)
        let power = await getRunningPower()
        let stride = await getStrideLength()
        let gct = await getGroundContactTime()
        let vo = await getVerticalOscillation()
        let hrv = await getHeartRateVariability()
        
        // Update metrics on main actor
        currentMetrics = AdvancedRunningMetrics(
            runningPower: power,
            strideLength: stride,
            groundContactTime: gct,
            verticalOscillation: vo,
            heartRateVariability: hrv
        )
    }
}

