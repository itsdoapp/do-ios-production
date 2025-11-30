//
//  HealthKitGenericDevice.swift
//  Do
//
//  Generic HealthKit device implementation
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import HealthKit
import Combine

class HealthKitGenericDevice: NSObject, FitnessDeviceProtocol {
    let deviceId = "healthKitGeneric"
    let deviceName = "HealthKit Device"
    let deviceType: DeviceType = .healthKitGeneric
    
    @Published var isConnected = false
    @Published var currentMetrics: WorkoutMetrics?
    
    var capabilities: DeviceCapabilities {
        return DeviceCapabilities(
            supportsGPS: false, // HealthKit doesn't provide GPS directly
            supportsHeartRate: true,
            supportsCadence: true,
            supportsElevation: false,
            supportsCalories: true,
            supportsDistance: true,
            supportsPace: true
        )
    }
    
    var connectionStatusPublisher: AnyPublisher<Bool, Never> {
        $isConnected.eraseToAnyPublisher()
    }
    
    var metricsPublisher: AnyPublisher<WorkoutMetrics?, Never> {
        $currentMetrics.eraseToAnyPublisher()
    }
    
    private let healthStore = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        checkAvailability()
    }
    
    private func checkAvailability() {
        isConnected = HKHealthStore.isHealthDataAvailable()
    }
    
    // MARK: - FitnessDeviceProtocol
    
    func connect() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw DeviceError.notAvailable
        }
        
        // Request authorization
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.workoutType()
        ]
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        isConnected = true
    }
    
    func disconnect() {
        isConnected = false
        stopMetricsStream()
    }
    
    func isAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    func startMetricsStream() async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        // Set up observer queries for real-time updates
        setupHeartRateObserver()
        setupDistanceObserver()
        setupCaloriesObserver()
    }
    
    func stopMetricsStream() {
        observerQueries.forEach { healthStore.stop($0) }
        observerQueries.removeAll()
    }
    
    func supportsMetric(_ metric: MetricType) -> Bool {
        switch metric {
        case .heartRate, .calories, .distance, .pace, .cadence:
            return true
        case .elevation, .speed:
            return false
        }
    }
    
    func getQualityScore(for metric: MetricType) -> Double {
        switch metric {
        case .heartRate:
            return 0.90 // HealthKit aggregates from multiple sources
        case .calories:
            return 0.85
        case .distance:
            return 0.80 // May come from various sources
        case .pace:
            return 0.75 // Calculated
        case .cadence:
            return 0.85
        default:
            return 0.50
        }
    }
    
    // MARK: - HealthKit Observers
    
    private func setupHeartRateObserver() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] query, completionHandler, error in
            if let error = error {
                print("❌ [HealthKitGenericDevice] Heart rate observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            self?.fetchLatestHeartRate()
            completionHandler()
        }
        
        healthStore.execute(query)
        observerQueries.append(query)
    }
    
    private func setupDistanceObserver() {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return }
        
        let query = HKObserverQuery(sampleType: distanceType, predicate: nil) { [weak self] query, completionHandler, error in
            if let error = error {
                print("❌ [HealthKitGenericDevice] Distance observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            self?.fetchLatestDistance()
            completionHandler()
        }
        
        healthStore.execute(query)
        observerQueries.append(query)
    }
    
    private func setupCaloriesObserver() {
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        let query = HKObserverQuery(sampleType: caloriesType, predicate: nil) { [weak self] query, completionHandler, error in
            if let error = error {
                print("❌ [HealthKitGenericDevice] Calories observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            self?.fetchLatestCalories()
            completionHandler()
        }
        
        healthStore.execute(query)
        observerQueries.append(query)
    }
    
    // MARK: - Data Fetching
    
    private func fetchLatestHeartRate() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { [weak self] query, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            
            let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
            
            DispatchQueue.main.async {
                if var metrics = self?.currentMetrics {
                    metrics.heartRate = heartRate
                    self?.currentMetrics = metrics
                } else {
                    var metrics = WorkoutMetrics()
                    metrics.heartRate = heartRate
                    self?.currentMetrics = metrics
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchLatestDistance() {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-3600), end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] query, statistics, error in
            guard let statistics = statistics, let sum = statistics.sumQuantity() else { return }
            
            let distance = sum.doubleValue(for: HKUnit.meter())
            
            DispatchQueue.main.async {
                if var metrics = self?.currentMetrics {
                    metrics.distance = distance
                    if metrics.elapsedTime > 0 {
                        metrics.pace = metrics.elapsedTime / distance
                    }
                    self?.currentMetrics = metrics
                } else {
                    var metrics = WorkoutMetrics()
                    metrics.distance = distance
                    self?.currentMetrics = metrics
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchLatestCalories() {
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-3600), end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: caloriesType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] query, statistics, error in
            guard let statistics = statistics, let sum = statistics.sumQuantity() else { return }
            
            let calories = sum.doubleValue(for: HKUnit.kilocalorie())
            
            DispatchQueue.main.async {
                if var metrics = self?.currentMetrics {
                    metrics.calories = calories
                    self?.currentMetrics = metrics
                } else {
                    var metrics = WorkoutMetrics()
                    metrics.calories = calories
                    self?.currentMetrics = metrics
                }
            }
        }
        
        healthStore.execute(query)
    }
}

