//
//  MetricSourceSelector.swift
//  Do
//
//  Chooses best data source for each metric (iOS side)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

class MetricSourceSelector {
    static let shared = MetricSourceSelector()
    
    private let coordinationEngine = DeviceCoordinationEngine.shared
    
    private init() {}
    
    // MARK: - Source Selection
    
    func selectSource(for metric: MetricType,
                     workoutType: WorkoutType,
                     isIndoor: Bool,
                     availableSources: [MetricsWithSource]) -> MetricsWithSource? {
        guard !availableSources.isEmpty else { return nil }
        
        let primarySource = coordinationEngine.determinePrimaryDevice(
            for: metric,
            workoutType: workoutType,
            isIndoor: isIndoor
        )
        
        if let primary = availableSources.first(where: { $0.source == primarySource }) {
            return primary
        }
        
        let sorted = availableSources.sorted { source1, source2 in
            let score1 = coordinationEngine.scoreDeviceQuality(
                device: source1.source,
                for: metric,
                workoutType: workoutType
            )
            let score2 = coordinationEngine.scoreDeviceQuality(
                device: source2.source,
                for: metric,
                workoutType: workoutType
            )
            
            let accuracy1 = source1.accuracy ?? score1
            let accuracy2 = source2.accuracy ?? score2
            
            return accuracy1 > accuracy2
        }
        
        return sorted.first
    }
    
    // MARK: - Multi-Source Merging
    
    func mergeMultipleSources(_ sources: [MetricsWithSource],
                            for metric: MetricType,
                            workoutType: WorkoutType) -> Double? {
        guard !sources.isEmpty else { return nil }
        
        if sources.count == 1 {
            return getMetricValue(from: sources[0].metrics, for: metric)
        }
        
        if metric == .heartRate {
            let values = sources.compactMap { getMetricValue(from: $0.metrics, for: metric) }
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +) / Double(values.count)
        }
        
        let primary = coordinationEngine.determinePrimaryDevice(
            for: metric,
            workoutType: workoutType,
            isIndoor: false
        )
        
        if let primarySource = sources.first(where: { $0.source == primary }) {
            return getMetricValue(from: primarySource.metrics, for: metric)
        }
        
        return getMetricValue(from: sources[0].metrics, for: metric)
    }
    
    // MARK: - Metric Value Extraction
    
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

