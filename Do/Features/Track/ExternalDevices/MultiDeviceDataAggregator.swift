//
//  MultiDeviceDataAggregator.swift
//  Do
//
//  Collects and merges metrics from all connected devices
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import Combine

class MultiDeviceDataAggregator: ObservableObject {
    static let shared = MultiDeviceDataAggregator()
    
    @Published var aggregatedMetrics: WorkoutMetrics = WorkoutMetrics()
    @Published var metricsBySource: [MetricsSource: WorkoutMetrics] = [:]
    
    private let deviceManager = ExternalDeviceManager.shared
    private let coordinationEngine = DeviceCoordinationEngine.shared
    private let sourceSelector = MetricSourceSelector.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Observe device manager for connected devices
        deviceManager.$connectedDevices
            .sink { [weak self] devices in
                self?.subscribeToDeviceMetrics(devices)
            }
            .store(in: &cancellables)
        
        // Periodically aggregate metrics
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.aggregateMetrics()
        }
    }
    
    private func subscribeToDeviceMetrics(_ devices: [FitnessDeviceProtocol]) {
        cancellables.removeAll()
        
        for device in devices {
            device.metricsPublisher
                .sink { [weak self] metrics in
                    if let metrics = metrics {
                        let source = MetricsSource(rawValue: device.deviceType.rawValue) ?? .phone
                        self?.updateMetricsFromSource(metrics, source: source)
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    private func updateMetricsFromSource(_ metrics: WorkoutMetrics, source: MetricsSource) {
        metricsBySource[source] = metrics
        aggregateMetrics()
    }
    
    // MARK: - Metrics Aggregation
    
    func aggregateMetrics(workoutType: WorkoutType = .running, isIndoor: Bool = false) {
        let allSources = deviceManager.getAllMetrics()
        guard !allSources.isEmpty else { return }
        
        var aggregated = WorkoutMetrics()
        
        // Distance: Use best source (usually phone for GPS)
        if let distanceSource = sourceSelector.selectSource(
            for: .distance,
            workoutType: workoutType,
            isIndoor: isIndoor,
            availableSources: allSources
        ) {
            aggregated.distance = distanceSource.metrics.distance
        }
        
        // Elapsed time: Use longest (most accurate)
        aggregated.elapsedTime = allSources.map { $0.metrics.elapsedTime }.max() ?? 0
        
        // Heart rate: Merge multiple sources (average)
        let heartRates = allSources.compactMap { source -> Double? in
            sourceSelector.selectSource(
                for: .heartRate,
                workoutType: workoutType,
                isIndoor: isIndoor,
                availableSources: [source]
            )?.metrics.heartRate
        }
        if !heartRates.isEmpty {
            aggregated.heartRate = heartRates.reduce(0, +) / Double(heartRates.count)
        }
        
        // Pace: Calculate from distance and time, or use best source
        if aggregated.distance > 0 && aggregated.elapsedTime > 0 {
            aggregated.pace = aggregated.elapsedTime / aggregated.distance
        } else if let paceSource = sourceSelector.selectSource(
            for: .pace,
            workoutType: workoutType,
            isIndoor: isIndoor,
            availableSources: allSources
        ) {
            aggregated.pace = paceSource.metrics.pace
        }
        
        // Calories: Average or use highest
        let calories = allSources.compactMap { $0.metrics.calories }
        if !calories.isEmpty {
            aggregated.calories = calories.reduce(0, +) / Double(calories.count)
        }
        
        // Cadence: Use watch if available
        if let cadenceSource = sourceSelector.selectSource(
            for: .cadence,
            workoutType: workoutType,
            isIndoor: isIndoor,
            availableSources: allSources
        ) {
            aggregated.cadence = cadenceSource.metrics.cadence
        }
        
        // Elevation: Use phone (GPS-based)
        if let elevationSource = sourceSelector.selectSource(
            for: .elevation,
            workoutType: workoutType,
            isIndoor: isIndoor,
            availableSources: allSources
        ) {
            aggregated.elevationGain = elevationSource.metrics.elevationGain
        }
        
        // Speed: Use phone (GPS-based)
        if let speedSource = sourceSelector.selectSource(
            for: .speed,
            workoutType: workoutType,
            isIndoor: isIndoor,
            availableSources: allSources
        ) {
            aggregated.currentSpeed = speedSource.metrics.currentSpeed
        }
        
        aggregatedMetrics = aggregated
    }
    
    // MARK: - Missing Data Handling
    
    func handleMissingData(for metric: MetricType, workoutType: WorkoutType, isIndoor: Bool) -> Double? {
        let allSources = deviceManager.getAllMetrics()
        
        // Try primary source
        if let primary = sourceSelector.selectSource(
            for: metric,
            workoutType: workoutType,
            isIndoor: isIndoor,
            availableSources: allSources
        ) {
            return getMetricValue(from: primary.metrics, for: metric)
        }
        
        // Try fallback
        let fallbackSource = coordinationEngine.getFallbackDevice(
            for: metric,
            primaryDevice: coordinationEngine.determinePrimaryDevice(
                for: metric,
                workoutType: workoutType,
                isIndoor: isIndoor
            )
        )
        
        if let fallback = allSources.first(where: { $0.source == fallbackSource }) {
            return getMetricValue(from: fallback.metrics, for: metric)
        }
        
        return nil
    }
    
    private func getMetricValue(from metrics: WorkoutMetrics, for metric: MetricType) -> Double? {
        switch metric {
        case .distance: return metrics.distance
        case .pace: return metrics.pace
        case .heartRate: return metrics.heartRate
        case .cadence: return metrics.cadence
        case .calories: return metrics.calories
        case .elevation: return metrics.elevationGain
        case .speed: return metrics.currentSpeed
        }
    }
}

