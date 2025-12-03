# Xcode Project Integration Guide

## ✅ Files Created and Fixed

All Swift type errors have been resolved. The following files were created:

### New Files Created:
1. ✅ `Do/Features/Track/Models/RunAnalysisHelpers.swift` - TreadmillImageData, MulticolorPolyline, RunVideoPreviewViewController
2. ✅ `Do/Features/Track/Extensions/UnitSpeedExtensions.swift` - UnitSpeed.minutesPerKilometer, UnitSpeed.minutesPerMile
3. ✅ `Do/Core/Services/WaterIntakeService.swift` - Water intake tracking service
4. ✅ `Do/Features/Track/Models/BikingTypes.swift` - BikeType enum and IndoorBikeLog
5. ✅ `Do/Features/Track/Managers/RunningWorkoutManager.swift` - HealthKit workout manager
6. ✅ `Do/Features/Track/Models/GymInsightsModels.swift` - WorkoutGap, WorkoutRecommendation, ParticipantStatus, CategoryStats

### Files Modified:
- ✅ `Do/Features/Genie/Models/TokenModels.swift` - Added MealType typealias
- ✅ `Do/Features/Track/Models/TrackingModels.swift` - Added MapViewMode enum
- ✅ `Do/Features/Track/Engines/HikeTrackingEngine.swift` - Removed duplicate SplitTime
- ✅ `Do/Features/Track/ViewControllers/Hiking/Outdoor/OutdoorHikeViewController.swift` - Removed duplicate MapViewMode
- ✅ `Do/Features/Track/ViewControllers/Biking/Outdoor/OutdoorBikeViewController.swift` - Removed duplicate MapViewMode
- ✅ `Do/Features/Track/ViewControllers/Walking/Outdoor/OutdoorWalkViewController.swift` - Removed duplicate MapViewMode
- ✅ `Do/Features/Track/ViewControllers/Running/Outdoor/OutdoorRunViewController.swift` - Removed duplicate MapViewMode
- ✅ `Do/Do Watch App/Models/WatchMetrics.swift` - Added MetricType enum
- ✅ `Do/Do Watch App/Models/WorkoutState.swift` - Added WorkoutType enum
- ✅ `Do/Do Watch App/Services/WorkoutHandoffProtocol.swift` - Added import WatchConnectivity

---

## 🔧 REQUIRED: Add New Files to Xcode Project

**These files exist on disk but are NOT yet in the Xcode project.**

### Method 1: Drag and Drop (Easiest)

1. Open **Finder** and navigate to the `ios` directory
2. Open **Xcode** with your `Do.xcodeproj`
3. In Xcode's Project Navigator (left sidebar), locate the appropriate group:
   - `Do/Features/Track/Models` for model files
   - `Do/Features/Track/Extensions` for extension files
   - `Do/Core/Services` for service files
   - `Do/Features/Track/Managers` for manager files
4. Drag the following files from Finder into their appropriate groups in Xcode:

**Files to Add:**
```
Do/Features/Track/Models/RunAnalysisHelpers.swift
Do/Features/Track/Extensions/UnitSpeedExtensions.swift
Do/Core/Services/WaterIntakeService.swift
Do/Features/Track/Models/BikingTypes.swift
Do/Features/Track/Managers/RunningWorkoutManager.swift
Do/Features/Track/Models/GymInsightsModels.swift
```

5. When prompted, ensure:
   - ✅ **"Copy items if needed"** is UNCHECKED (files are already in the right location)
   - ✅ **"Add to targets: Do"** is CHECKED
   - ❌ **"Do Watch App"** target should be UNCHECKED (unless it's a shared file)

### Method 2: Add Files Menu

1. In Xcode, right-click on the appropriate group (e.g., `Features/Track/Models`)
2. Select **"Add Files to 'Do'..."**
3. Navigate to the file location
4. Select the file
5. Ensure **"Add to targets: Do"** is checked
6. Click **"Add"**

---

## ⚠️ ISSUE: Multiple @main Attributes

### The Problem
You have two files with `@main` attribute:
- `Do/App/AppDelegate.swift` - iOS app entry point
- `Do/Do Watch App/WatchApp.swift` - Watch app entry point

This is **CORRECT** because they're for different targets, BUT if `WatchApp.swift` is accidentally included in the iOS app target, you'll get an error.

### How to Fix:

1. Open Xcode and select `WatchApp.swift` in the Project Navigator
2. Open the **File Inspector** (right sidebar, first tab)
3. Check the **"Target Membership"** section
4. Ensure:
   - ❌ **"Do"** (iOS app) is UNCHECKED
   - ✅ **"Do Watch App"** is CHECKED

Similarly, verify `AppDelegate.swift`:
   - ✅ **"Do"** (iOS app) is CHECKED
   - ❌ **"Do Watch App"** is UNCHECKED

---

## 🧹 Clean Build (After Adding Files)

Once you've added the files to Xcode:

1. **Clean Build Folder**: `Cmd + Shift + K`
2. **Clean Derived Data**: 
   - `Cmd + Option + Shift + K` or
   - Xcode → Preferences → Locations → Derived Data → Click arrow → Delete folder
3. **Rebuild**: `Cmd + B`

---

## ✅ Verification Checklist

After adding files and cleaning:

- [ ] All 6 new files appear in Xcode Project Navigator
- [ ] Each file shows correct target membership (File Inspector)
- [ ] `WatchApp.swift` is only in "Do Watch App" target
- [ ] `AppDelegate.swift` is only in "Do" target
- [ ] Project builds successfully (`Cmd + B`)
- [ ] No "Cannot find type" errors
- [ ] No "@main attribute" errors

---

## 📊 Summary of Types Created

### Run Analysis
- `TreadmillImageData` - OCR data from treadmill displays
- `MulticolorPolyline` - Speed-colored map routes
- `RunVideoPreviewViewController` - Animated route replay

### Extensions
- `UnitSpeed.minutesPerKilometer` - Pace unit
- `UnitSpeed.minutesPerMile` - Pace unit

### Services
- `WaterIntakeService` - Daily water tracking with HealthKit

### Bike Types
- `BikeType` enum - Outdoor, Mountain, Road, Indoor, Stationary, E-Bike
- `IndoorBikeLog` - Indoor cycling workout data

### Workout Management
- `RunningWorkoutManager` - HealthKit workout sessions

### Gym Insights
- `WorkoutGap` - Muscle groups not trained recently
- `WorkoutRecommendation` - AI-generated workout suggestions
- `ParticipantStatus` - Group workout participant status
- `CategoryStats` - Statistics per muscle group category
- `WorkoutParticipant` - Group workout participant data
- `WorkoutInsightsGenerator` - Analyzes gaps and generates recommendations

### Shared Types (Consolidated)
- `SplitTime` - Distance interval splits (now in TrackingModels.swift)
- `MapViewMode` - Map display modes (now in TrackingModels.swift)
- `MealType` - Typealias for FoodMealType

---

## 🎯 Next Steps

1. ✅ Add all 6 new files to Xcode project
2. ✅ Verify target membership for @main files
3. ✅ Clean build
4. ✅ Rebuild project
5. ✅ Test that all types are now found

If you encounter any issues after following these steps, please let me know!





