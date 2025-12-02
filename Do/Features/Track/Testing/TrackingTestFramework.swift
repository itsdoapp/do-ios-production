//
//  TrackingTestFramework.swift
//  Do
//
//  Test framework infrastructure for tracking validation
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

/// Test result structure
struct TrackingTestResult {
    let category: String
    let scenario: String
    let startTime: Date
    var endTime: Date?
    var metrics: [MetricSnapshot] = []
    var syncEvents: [SyncEvent] = []
    var coordinationEvents: [CoordinationEvent] = []
    var errors: [TestError] = []
    
    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
}

struct MetricSnapshot {
    let timestamp: Date
    let device: String
    let metric: String
    let value: Any
    let source: String?
}

struct SyncEvent {
    let timestamp: Date
    let direction: String // "phoneToWatch" or "watchToPhone"
    let category: String
    let data: [String: Any]
}

struct CoordinationEvent {
    let timestamp: Date
    let category: String
    let metric: String
    let primaryDevice: String
    let reason: String
}

struct TestError {
    let timestamp: Date
    let category: String
    let message: String
    let error: Error?
}

/// Expected results validator
class TrackingTestValidator {
    static func validate(result: TrackingTestResult, against expected: ExpectedResults) -> ValidationResult {
        var issues: [String] = []
        
        // Check if all expected metrics were tracked
        for expectedMetric in expected.requiredMetrics {
            let found = result.metrics.contains { $0.metric == expectedMetric }
            if !found {
                issues.append("Missing required metric: \(expectedMetric)")
            }
        }
        
        // Check coordination events
        for expectedCoordination in expected.expectedCoordination {
            let found = result.coordinationEvents.contains {
                $0.metric == expectedCoordination.metric &&
                $0.primaryDevice == expectedCoordination.primaryDevice
            }
            if !found {
                issues.append("Missing expected coordination: \(expectedCoordination.metric) should be primary on \(expectedCoordination.primaryDevice)")
            }
        }
        
        // Check sync frequency (should sync approximately every 2 seconds)
        if result.syncEvents.count > 1 {
            let syncIntervals = zip(result.syncEvents.dropFirst(), result.syncEvents).map {
                $0.timestamp.timeIntervalSince($1.timestamp)
            }
            let avgInterval = syncIntervals.reduce(0, +) / Double(syncIntervals.count)
            if avgInterval < 1.0 {
                issues.append("Sync frequency too high (avg: \(String(format: "%.1f", avgInterval))s, expected ~2s)")
            } else if avgInterval > 5.0 {
                issues.append("Sync frequency too low (avg: \(String(format: "%.1f", avgInterval))s, expected ~2s)")
            }
        }
        
        return ValidationResult(
            isValid: issues.isEmpty,
            issues: issues
        )
    }
}

struct ValidationResult {
    let isValid: Bool
    let issues: [String]
}

/// Expected results structure
struct ExpectedResults {
    let category: String
    let requiredMetrics: [String]
    let expectedCoordination: [ExpectedCoordination]
    let syncFrequency: TimeInterval // Expected sync interval in seconds
}

struct ExpectedCoordination {
    let metric: String
    let primaryDevice: String
    let reason: String
}

