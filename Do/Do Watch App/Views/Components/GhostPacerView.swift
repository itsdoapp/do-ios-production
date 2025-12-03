//
//  GhostPacerView.swift
//  Do Watch App
//
//  Visual pace comparison indicator
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

struct GhostPacerView: View {
    let currentPace: Double // seconds per meter
    let averagePace: Double // seconds per meter
    let color: Color
    
    private var isAhead: Bool {
        guard currentPace > 0 && averagePace > 0 else { return false }
        return currentPace < averagePace // Lower pace = faster
    }
    
    private var paceDifference: Double {
        guard currentPace > 0 && averagePace > 0 else { return 0 }
        return abs(currentPace - averagePace) / averagePace * 100
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Ghost bar (average pace)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    // Ghost pace indicator
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: geometry.size.width * 0.5, height: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.gray.opacity(0.8), lineWidth: 1)
                        )
                    
                    // Current pace indicator
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isAhead ? Color.green : Color.red)
                        .frame(
                            width: geometry.size.width * min(paceDifference / 50.0, 1.0),
                            height: 6
                        )
                        .shadow(color: (isAhead ? Color.green : Color.red).opacity(0.6), radius: 4, x: 0, y: 0)
                        .offset(x: isAhead ? 0 : geometry.size.width * 0.5)
                }
            }
            .frame(height: 6)
            
            // Status text
            HStack(spacing: 4) {
                Image(systemName: isAhead ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(isAhead ? .green : .red)
                
                Text(isAhead ? "AHEAD" : "BEHIND")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isAhead ? .green : .red)
            }
        }
    }
}


