//
//  PerformanceLogger.swift
//  Track Infrastructure
//
//  Copied from Do./Util/PerformanceLogger.swift
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation

final class PerformanceLogger {
    static let shared = PerformanceLogger()
    private var marks: [String: Date] = [:]
    private let queue = DispatchQueue(label: "com.do.performanceLogger", qos: .background)
    
    private init() {}
    
    @discardableResult
    static func start(_ label: String) -> Date {
        shared.queue.sync { shared.marks[label] = Date() }
        print("⏱️ [Perf] START: \(label)")
        return Date()
    }
    
    static func end(_ label: String, extra: String? = nil) {
        var start: Date?
        shared.queue.sync { start = shared.marks.removeValue(forKey: label) }
        guard let started = start else {
            print("⏱️ [Perf] END without START for: \(label)")
            return
        }
        let ms = Int(Date().timeIntervalSince(started) * 1000)
        if let extra = extra, !extra.isEmpty {
            print("⏱️ [Perf] END: \(label) • \(ms) ms • \(extra)")
        } else {
            print("⏱️ [Perf] END: \(label) • \(ms) ms")
        }
    }
}

