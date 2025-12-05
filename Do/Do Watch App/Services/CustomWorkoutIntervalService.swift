//
//  CustomWorkoutIntervalService.swift
//  Do Watch App
//
//  Service for managing custom workout intervals (watchOS 9.0+)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import Combine

@MainActor
class CustomWorkoutIntervalService: ObservableObject {
    static let shared = CustomWorkoutIntervalService()
    
    @Published var currentPlan: CustomWorkoutPlan?
    @Published var currentIntervalIndex: Int = 0
    @Published var isInInterval: Bool = false
    @Published var intervalStartTime: Date?
    @Published var intervalElapsedTime: TimeInterval = 0
    
    private var intervalTimer: Timer?
    private let heartRateZoneService = HeartRateZoneService.shared
    
    private init() {}
    
    // MARK: - Plan Management
    
    func startPlan(_ plan: CustomWorkoutPlan) {
        currentPlan = plan
        currentIntervalIndex = 0
        isInInterval = false
        intervalElapsedTime = 0
        
        // Start warmup if configured
        if plan.warmupDuration > 0 {
            // Warmup logic would go here
        }
    }
    
    func startNextInterval() {
        guard let plan = currentPlan,
              currentIntervalIndex < plan.intervals.count else {
            // All intervals complete
            completePlan()
            return
        }
        
        let interval = plan.intervals[currentIntervalIndex]
        isInInterval = true
        intervalStartTime = Date()
        intervalElapsedTime = 0
        
        // Start timer
        intervalTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateIntervalTimer()
            }
        }
        
        // Check if interval has duration target
        if let targetDuration = interval.target.duration {
            // Auto-advance after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + targetDuration) {
                Task { @MainActor in
                    self.completeCurrentInterval()
                }
            }
        }
    }
    
    func completeCurrentInterval() {
        guard let plan = currentPlan,
              currentIntervalIndex < plan.intervals.count else {
            return
        }
        
        intervalTimer?.invalidate()
        intervalTimer = nil
        
        // Update interval with actual duration
        var updatedInterval = plan.intervals[currentIntervalIndex]
        updatedInterval.actualDuration = intervalElapsedTime
        updatedInterval.completed = true
        
        // Update plan
        var updatedPlan = plan
        updatedPlan.intervals[currentIntervalIndex] = updatedInterval
        currentPlan = updatedPlan
        
        // Move to next interval
        currentIntervalIndex += 1
        isInInterval = false
        
        // Check if we should start next interval or cooldown
        if currentIntervalIndex < plan.intervals.count {
            // Small delay before next interval
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                Task { @MainActor in
                    self.startNextInterval()
                }
            }
        } else {
            // All intervals complete, start cooldown
            if plan.cooldownDuration > 0 {
                // Cooldown logic
            }
        }
    }
    
    func pauseInterval() {
        intervalTimer?.invalidate()
        intervalTimer = nil
    }
    
    func resumeInterval() {
        guard isInInterval, intervalStartTime != nil else { return }
        
        intervalTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateIntervalTimer()
            }
        }
    }
    
    func cancelPlan() {
        intervalTimer?.invalidate()
        intervalTimer = nil
        currentPlan = nil
        currentIntervalIndex = 0
        isInInterval = false
        intervalStartTime = nil
        intervalElapsedTime = 0
    }
    
    private func completePlan() {
        intervalTimer?.invalidate()
        intervalTimer = nil
        isInInterval = false
        
        // Plan completion logic
        print("✅ [CustomWorkout] Plan completed: \(currentPlan?.name ?? "Unknown")")
    }
    
    private func updateIntervalTimer() {
        guard let startTime = intervalStartTime else { return }
        intervalElapsedTime = Date().timeIntervalSince(startTime)
    }
    
    // MARK: - Target Checking
    
    func checkIntervalTargets(currentHeartRate: Double, currentPace: Double?) -> [String] {
        guard let plan = currentPlan,
              currentIntervalIndex < plan.intervals.count else {
            return []
        }
        
        let interval = plan.intervals[currentIntervalIndex]
        var alerts: [String] = []
        
        // Check heart rate zone target
        if let targetZone = interval.target.heartRateZone {
            let currentZone = heartRateZoneService.calculateZone(for: currentHeartRate)
            if currentZone != targetZone {
                alerts.append("Target Zone: \(targetZone.name), Current: \(currentZone?.name ?? "Unknown")")
            }
        }
        
        // Check heart rate target
        if let targetHR = interval.target.heartRate {
            let difference = abs(currentHeartRate - targetHR)
            if difference > 5 {
                alerts.append("Target HR: \(Int(targetHR)) bpm, Current: \(Int(currentHeartRate)) bpm")
            }
        }
        
        // Check pace target
        if let targetPace = interval.target.pace,
           let currentPace = currentPace {
            let difference = abs(currentPace - targetPace)
            if difference > 5 {
                alerts.append("Target Pace: \(formatPace(targetPace)), Current: \(formatPace(currentPace))")
            }
        }
        
        return alerts
    }
    
    private func formatPace(_ pace: Double) -> String {
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}





