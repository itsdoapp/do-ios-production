//
//  AdvancedMetricsView.swift
//  Do Watch App
//
//  Advanced running metrics display (watchOS 9.0+)
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import SwiftUI

struct AdvancedMetricsView: View {
    let metrics: AdvancedRunningMetrics
    
    var body: some View {
        if metrics.hasAnyMetrics {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("ADVANCED METRICS")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(0.5)
                }
                .padding(.bottom, 12)
                
                // Metrics Grid - 2 columns
                let metricItems = getMetricItems()
                if !metricItems.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(Array(metricItems.chunked(into: 2).enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 10) {
                                ForEach(row) { item in
                                    MetricCard(item: item)
                                }
                                
                                // Fill empty space if odd number
                                if row.count == 1 {
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
    }
    
    private func getMetricItems() -> [MetricItem] {
        var items: [MetricItem] = []
        
        if let power = metrics.runningPower {
            items.append(MetricItem(
                icon: "bolt.fill",
                label: "Power",
                value: "\(Int(power))",
                unit: "W",
                color: Color(red: 1.0, green: 0.8, blue: 0.0)
            ))
        }
        
        if let stride = metrics.strideLength {
            items.append(MetricItem(
                icon: "ruler.fill",
                label: "Stride",
                value: String(format: "%.2f", stride),
                unit: "m",
                color: Color.blue
            ))
        }
        
        if let gct = metrics.groundContactTime {
            items.append(MetricItem(
                icon: "stopwatch.fill",
                label: "GCT",
                value: String(format: "%.0f", gct * 1000),
                unit: "ms",
                color: Color.green
            ))
        }
        
        if let vo = metrics.verticalOscillation {
            items.append(MetricItem(
                icon: "arrow.up.and.down",
                label: "VO",
                value: String(format: "%.1f", vo),
                unit: "cm",
                color: Color.purple
            ))
        }
        
        if let hrv = metrics.heartRateVariability {
            items.append(MetricItem(
                icon: "waveform.path",
                label: "HRV",
                value: String(format: "%.0f", hrv),
                unit: "ms",
                color: Color(red: 0.969, green: 0.576, blue: 0.122)
            ))
        }
        
        return items
    }
}

struct MetricItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color
}

struct MetricCard: View {
    let item: MetricItem
    
    var body: some View {
        VStack(spacing: 6) {
            // Icon
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.2))
                    .frame(width: 28, height: 28)
                
                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(item.color)
            }
            
            // Value
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(item.value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(item.unit)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.gray.opacity(0.8))
            }
            
            // Label
            Text(item.label)
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundColor(.gray.opacity(0.7))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(item.color.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

