//
//  DailyBricksWidget.swift
//  Do
//
//  iOS Widget for Daily Bricks - merges data from iOS and Watch
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
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge
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
    
    func placeholder(in context: Context) -> DailyBricksEntry {
        DailyBricksEntry(
            summary: createPlaceholderSummary(),
            isLoading: false
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (DailyBricksEntry) -> Void) {
        Task {
            let summary = await DailyBricksWidgetDataManager.shared.loadTodaySummary()
            let entry = DailyBricksEntry(summary: summary, isLoading: false)
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyBricksEntry>) -> Void) {
        Task {
            let summary = await DailyBricksWidgetDataManager.shared.loadTodaySummary()
            let entry = DailyBricksEntry(summary: summary, isLoading: false)
            
            // Update every hour, and at midnight
            let calendar = Calendar.current
            let now = Date()
            let nextHour = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
            let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
            let nextUpdate = min(nextHour, midnight)
            
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    private func createPlaceholderSummary() -> DailyBricksSummary {
        let bricks = DailyBrickType.allCases.map { type in
            DailyBrickProgress(
                type: type,
                progress: Double.random(in: 0.3...1.0),
                currentValue: Double.random(in: 10...30),
                goalValue: 20.0,
                unit: "min"
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
        switch family {
        case .systemSmall:
            SmallBricksView(entry: entry)
        case .systemMedium:
            MediumBricksView(entry: entry)
        case .systemLarge, .systemExtraLarge:
            LargeBricksView(entry: entry)
        default:
            SmallBricksView(entry: entry)
        }
    }
}







