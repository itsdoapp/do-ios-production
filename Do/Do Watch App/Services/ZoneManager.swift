//
//  ZoneManager.swift
//  Do Watch App
//
//  Manages heart rate zones and visual feedback
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//
//  NOTE: This file has been deprecated. HeartRateZone is now defined in HeartRateZoneService.swift
//  This file is kept for backward compatibility but should be removed if no longer needed.

import SwiftUI

// Legacy zone enum - use HeartRateZone from HeartRateZoneService instead
enum LegacyHeartRateZone: Int {
    case rest = 0
    case warmup = 1
    case fatBurn = 2
    case cardio = 3
    case peak = 4
    
    var color: Color {
        switch self {
        case .rest: return Color(red: 0.4, green: 0.6, blue: 1.0) // Blue
        case .warmup: return Color(red: 0.2, green: 0.8, blue: 0.4) // Green
        case .fatBurn: return Color(red: 1.0, green: 0.8, blue: 0.0) // Yellow
        case .cardio: return Color(red: 1.0, green: 0.5, blue: 0.0) // Orange
        case .peak: return Color(red: 1.0, green: 0.2, blue: 0.2) // Red
        }
    }
    
    var label: String {
        switch self {
        case .rest: return "Rest"
        case .warmup: return "Warmup"
        case .fatBurn: return "Fat Burn"
        case .cardio: return "Cardio"
        case .peak: return "Peak"
        }
    }
    
    static func from(heartRate: Double, maxHeartRate: Double = 190) -> LegacyHeartRateZone {
        let percentage = heartRate / maxHeartRate
        if percentage < 0.5 { return .rest }
        else if percentage < 0.6 { return .warmup }
        else if percentage < 0.7 { return .fatBurn }
        else if percentage < 0.85 { return .cardio }
        else { return .peak }
    }
}

