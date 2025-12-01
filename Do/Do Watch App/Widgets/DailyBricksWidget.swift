//
//  DailyBricksWidget.swift
//  Do Watch App
//
//  WidgetKit complication for Daily Bricks
//  Copyright © 2025 Mikiyas Tadesse. All rights reserved.
//

import WidgetKit
import SwiftUI

struct DailyBricksWidget: Widget {
    let kind: String = "DailyBricksWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyBricksTimelineProvider()) { entry in
            DailyBricksWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Bricks")
        .description("Track your daily progress across 6 key areas: Move, Heart, Strength, Recovery, Mind, and Fuel.")
        .supportedFamilies([
            // Accessory complications (watchOS 9.0+)
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
            // Note: Graphic families (graphicCircular, graphicRectangular, graphicExtraLarge)
            // are ClockKit-only and not available in WidgetKit
        ])
    }
}

// MARK: - Widget Entry

struct DailyBricksEntry: TimelineEntry {
    let date: Date
    let summary: DailyBricksSummary?
    let isLoading: Bool
    let error: String?
    
    init(date: Date = Date(), summary: DailyBricksSummary? = nil, isLoading: Bool = false, error: String? = nil) {
        self.date = date
        self.summary = summary
        self.isLoading = isLoading
        self.error = error
    }
}

// MARK: - Timeline Provider

struct DailyBricksTimelineProvider: TimelineProvider {
    typealias Entry = DailyBricksEntry
    
    func placeholder(in context: Context) -> Entry {
        Entry(summary: createPlaceholderSummary())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        // For previews and snapshots, use current data or placeholder
        if context.isPreview {
            completion(Entry(summary: createPlaceholderSummary()))
        } else {
            loadCurrentData { summary in
                completion(Entry(summary: summary))
            }
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        loadCurrentData { summary in
            let entry = Entry(summary: summary)
            
            // Update every hour, or at midnight for new day
            let calendar = Calendar.current
            let now = Date()
            let nextUpdate: Date
            
            if let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 1, to: now) ?? now) {
                // Update at midnight for new day
                nextUpdate = midnight
            } else {
                // Fallback: update in 1 hour
                nextUpdate = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
            }
            
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadCurrentData(completion: @escaping (DailyBricksSummary?) -> Void) {
        Task {
            let summary = await DailyBricksWidgetDataManager.shared.loadTodaySummary()
            await MainActor.run {
                completion(summary)
            }
        }
    }
    
    func createPlaceholderSummary() -> DailyBricksSummary {
        let bricks = DailyBrickType.allCases.map { type in
            DailyBrickProgress(
                type: type,
                progress: Double.random(in: 0.3...1.0),
                currentValue: Double.random(in: 10...30),
                goalValue: 20.0,
                unit: type == .move || type == .heart || type == .strength || type == .mind ? "min" : "count"
            )
        }
        return DailyBricksSummary(bricks: bricks)
    }
}

// MARK: - Widget Entry View

struct DailyBricksWidgetEntryView: View {
    var entry: DailyBricksEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                AccessoryCircularView(summary: entry.summary)
            case .accessoryRectangular:
                AccessoryRectangularView(summary: entry.summary)
            case .accessoryInline:
                AccessoryInlineView(summary: entry.summary)
            default:
                // Fallback to circular for any other family
                AccessoryCircularView(summary: entry.summary)
            }
        }
    }
}

// MARK: - Preview

#Preview(as: .accessoryCircular) {
    DailyBricksWidget()
} timeline: {
    DailyBricksEntry(summary: DailyBricksTimelineProvider().createPlaceholderSummary())
    DailyBricksEntry(summary: DailyBricksTimelineProvider().createPlaceholderSummary())
}

