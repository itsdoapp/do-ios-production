//
//  ZoneAlertService.swift
//  Do Watch App
//
//  Zone-based alerts and notifications (watchOS 9.0+)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import Foundation
import WatchKit
import Combine

@MainActor
class ZoneAlertService: ObservableObject {
    static let shared = ZoneAlertService()
    
    @Published var activeAlerts: [ZoneAlert] = []
    
    private var alertTimers: [String: Timer] = [:]
    private let heartRateZoneService = HeartRateZoneService.shared
    
    private init() {}
    
    // MARK: - Zone Alerts
    
    func checkZoneTarget(heartRate: Double, targetZone: HeartRateZone?) {
        guard let targetZone = targetZone else { return }
        
        let currentZone = heartRateZoneService.calculateZone(for: heartRate)
        
        if currentZone != targetZone {
            let alert = ZoneAlert(
                id: UUID().uuidString,
                type: .zoneMismatch,
                message: "Target: \(targetZone.name), Current: \(currentZone?.name ?? "Unknown")",
                severity: .warning
            )
            showAlert(alert)
        }
    }
    
    func checkHeartRateTarget(heartRate: Double, targetHR: Double, tolerance: Double = 5.0) {
        let difference = abs(heartRate - targetHR)
        
        if difference > tolerance {
            let alert = ZoneAlert(
                id: UUID().uuidString,
                type: .heartRateTarget,
                message: "Target: \(Int(targetHR)) bpm, Current: \(Int(heartRate)) bpm",
                severity: difference > 10 ? .critical : .warning
            )
            showAlert(alert)
        }
    }
    
    func checkPaceTarget(currentPace: Double, targetPace: Double, tolerance: Double = 5.0) {
        let difference = abs(currentPace - targetPace)
        
        if difference > tolerance {
            let alert = ZoneAlert(
                id: UUID().uuidString,
                type: .paceTarget,
                message: "Adjust pace to target",
                severity: difference > 10 ? .critical : .warning
            )
            showAlert(alert)
        }
    }
    
    // MARK: - Alert Management
    
    private func showAlert(_ alert: ZoneAlert) {
        // Remove existing alert of same type
        activeAlerts.removeAll { $0.type == alert.type }
        
        // Add new alert
        activeAlerts.append(alert)
        
        // Haptic feedback based on severity
        switch alert.severity {
        case .info:
            WKInterfaceDevice.current().play(.click)
        case .warning:
            WKInterfaceDevice.current().play(.notification)
        case .critical:
            WKInterfaceDevice.current().play(.failure)
        }
        
        // Auto-dismiss after 3 seconds
        let alertId = alert.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            Task { @MainActor in
                self.dismissAlert(id: alertId)
            }
        }
    }
    
    func dismissAlert(id: String) {
        activeAlerts.removeAll { $0.id == id }
    }
    
    func clearAllAlerts() {
        activeAlerts.removeAll()
    }
}

// MARK: - Zone Alert Model

struct ZoneAlert: Identifiable {
    let id: String
    let type: AlertType
    let message: String
    let severity: AlertSeverity
    
    enum AlertType {
        case zoneMismatch
        case heartRateTarget
        case paceTarget
        case powerTarget
    }
    
    enum AlertSeverity {
        case info
        case warning
        case critical
    }
}





