//
//  TrackingTestLogger.swift
//  Do Watch App
//
//  Structured logging system for tracking tests (Watch App)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

/// Structured logger for tracking tests with clear section markers (Watch App)
class TrackingTestLogger {
    static let shared = TrackingTestLogger()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    private init() {}
    
    // MARK: - Section Markers
    
    func logTestStart(category: String, scenario: String) {
        print("\n" + "=".repeating(80))
        print("=== TEST START: \(category.uppercased()) - \(scenario.uppercased()) [WATCH] ===")
        print("=".repeating(80))
        print("[\(timestamp())] [WATCH] [TEST] Starting test for category: \(category), scenario: \(scenario)")
    }
    
    func logTestEnd(category: String) {
        print("\n" + "=".repeating(80))
        print("=== TEST END: \(category.uppercased()) [WATCH] ===")
        print("=".repeating(80))
    }
    
    func logMetricUpdate(device: String, category: String, metric: String, value: Any, source: String? = nil) {
        let sourceStr = source != nil ? " [SOURCE: \(source!)]" : ""
        print("[\(timestamp())] [\(device.uppercased())] [\(category.uppercased())] [\(metric)] = \(value)\(sourceStr)")
    }
    
    func logCoordination(category: String, metric: String, primaryDevice: String, reason: String) {
        print("[\(timestamp())] [COORDINATION] [\(category.uppercased())] Primary device for [\(metric)]: [\(primaryDevice.uppercased())] [REASON: \(reason)]")
    }
    
    func logSyncEvent(category: String, direction: String, data: [String: Any]) {
        print("\n=== SYNC EVENT [WATCH] ===")
        print("[\(timestamp())] [SYNC] [\(category.uppercased())] \(direction):")
        for (key, value) in data.sorted(by: { $0.key < $1.key }) {
            print("  \(key): \(value)")
        }
        print("=== END SYNC EVENT [WATCH] ===\n")
    }
    
    func logStateChange(category: String, oldState: String, newState: String) {
        print("[\(timestamp())] [STATE] [\(category.uppercased())] State changed: \(oldState) => \(newState)")
    }
    
    func logError(category: String, message: String, error: Error? = nil) {
        let errorStr = error != nil ? " - \(error!.localizedDescription)" : ""
        print("[\(timestamp())] [ERROR] [\(category.uppercased())] \(message)\(errorStr)")
    }
    
    func logInfo(category: String, message: String) {
        print("[\(timestamp())] [INFO] [\(category.uppercased())] \(message)")
    }
    
    // MARK: - Helper Methods
    
    private func timestamp() -> String {
        return dateFormatter.string(from: Date())
    }
}

extension String {
    func repeating(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}

