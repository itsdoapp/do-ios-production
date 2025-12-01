# iOS Daily Bricks Widget Setup

## Overview

This iOS widget displays Daily Bricks progress merged from both iOS and Watch app data sources. It uses the same App Group (`group.com.do.fitness`) to share data between platforms.

## Files Created

1. **`Widgets/DailyBricksWidget.swift`** - Main widget definition and timeline provider
2. **`Widgets/DailyBricksWidgetDataManager.swift`** - Data manager that merges iOS and Watch data
3. **`Widgets/DailyBricksWidgetViews.swift`** - Widget views for different sizes (small, medium, large)
4. **`Widgets/DailyBricksWidgetBundle.swift`** - Widget bundle entry point

## Data Merging Strategy

The widget merges data from multiple sources:

1. **App Group UserDefaults** (Primary) - Data written by both iOS and Watch apps
   - `shared_workout_minutes` - Total workout minutes (Move brick)
   - `shared_strength_minutes` - Strength workout minutes
   - `shared_strength_session` - Has strength session (bool)
   - `shared_meditation_minutes` - Meditation minutes (Mind brick)
   - `shared_meal_count` - Meal count (Fuel brick)
   - `shared_overall_progress` - Overall progress (0.0-1.0)
   - `shared_completed_count` - Completed bricks count
   - `shared_last_update` - Last update timestamp

2. **HealthKit** (Secondary) - Direct queries for real-time data
   - Used as fallback when App Group data is unavailable
   - Also used to merge/validate data from both sources

3. **Merging Logic**:
   - For numeric values (minutes, counts): Uses `max()` to avoid double counting
   - For boolean values (sessions): Uses `OR` logic to merge
   - Ensures data from both iOS and Watch is combined accurately

## Widget Sizes

- **Small**: Shows overall progress ring and completed count
- **Medium**: Shows progress ring + 2x3 grid of brick icons
- **Large/Extra Large**: Shows all 6 bricks with detailed progress bars

## Setup Instructions

### 1. Add Widget Extension Target

In Xcode:
1. File > New > Target
2. Select "Widget Extension"
3. Name: "DailyBricksWidget"
4. Include Configuration Intent: No
5. Target: iOS 16.0+

### 2. Configure App Group

Ensure the widget extension has:
- App Group capability: `group.com.do.fitness`
- Same bundle identifier prefix: `com.do.fitness`

### 3. Add Files to Widget Target

Add these files to the widget extension target:
- `Widgets/DailyBricksWidget.swift`
- `Widgets/DailyBricksWidgetDataManager.swift`
- `Widgets/DailyBricksWidgetViews.swift`
- `Widgets/DailyBricksWidgetBundle.swift`
- `Do Watch App/Models/DailyBricks.swift` (or copy to shared location)

### 4. Configure Info.plist

Add to widget extension's Info.plist:
```xml
<key>NSSupportsLiveActivities</key>
<false/>
```

### 5. HealthKit Permissions

The widget needs HealthKit read permissions. These should be requested by the main iOS app and shared via App Group.

## Data Flow

1. **iOS App** calculates DailyBricks progress
   - Writes to App Group UserDefaults
   - Triggers widget timeline reload

2. **Watch App** calculates DailyBricks progress
   - Writes to same App Group UserDefaults
   - Merges with iOS data

3. **Widget** reads from App Group
   - Primary: App Group UserDefaults (merged data)
   - Fallback: HealthKit queries (direct)
   - Merges both sources using max/OR logic

4. **Timeline Provider**
   - Creates timeline entries
   - Updates hourly + at midnight
   - Handles loading states

## Next Steps

1. **Create iOS DailyBricksService**: Create a service similar to the Watch app's `DailyBricksService` that:
   - Calculates DailyBricks progress from iOS app data
   - Writes to App Group UserDefaults
   - Triggers widget updates

2. **Integrate with iOS App**: Call the service from appropriate places:
   - After workout completion
   - After meditation session
   - After meal logging
   - Periodically (every 5-10 minutes)

3. **Test Widget**: 
   - Add widget to home screen
   - Verify data appears correctly
   - Test with both iOS and Watch data sources

## Notes

- The widget uses the same `DailyBricksSummary` model as the Watch app
- Data is merged intelligently to avoid double counting
- Widget updates automatically via timeline policy
- Manual refresh: `WidgetCenter.shared.reloadTimelines(ofKind: "DailyBricksWidget")`

