//
//  ZoneAlertBanner.swift
//  Do Watch App
//
//  Zone alert banner component (watchOS 9.0+)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

struct ZoneAlertBanner: View {
    let alert: ZoneAlert
    
    var body: some View {
        HStack(spacing: 6) {
            // Severity indicator
            Circle()
                .fill(severityColor)
                .frame(width: 6, height: 6)
            
            // Alert message
            Text(alert.message)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(severityColor.opacity(0.3))
        .cornerRadius(8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private var severityColor: Color {
        switch alert.severity {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}





