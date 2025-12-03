# Daily Bricks Complication Setup Guide

## Overview
The Daily Bricks complication has been implemented and configured. Follow these steps to ensure it works properly.

## 1. Info.plist Configuration ✅
The `Do-Watch-App-Watch-App-Info.plist` file has been updated with:
- `CLKComplicationPrincipalClass`: Points to `DailyBricksComplicationController`
- `CLKComplicationSupportedFamilies`: Lists all supported complication families

## 2. Xcode Configuration Steps

### Step 1: Verify Info.plist
1. Open Xcode
2. Select the **"Do Watch App"** target
3. Go to **Build Settings**
4. Search for `INFOPLIST_FILE`
5. Verify it points to: `Do Watch App/Do-Watch-App-Watch-App-Info.plist`

### Step 2: Add Complication to Target
1. In Xcode Project Navigator, find `Do Watch App/Complications/DailyBricksComplication.swift`
2. Select the file
3. In the File Inspector (right panel), under **Target Membership**, ensure **"Do Watch App"** is checked ✅

### Step 3: Verify Build Settings
1. Select **"Do Watch App"** target
2. Go to **Build Settings**
3. Search for `SWIFT_OBJC_BRIDGING_HEADER` (should be empty for Swift-only)
4. Verify `PRODUCT_MODULE_NAME` is set (usually auto-generated as "Do_Watch_App")

### Step 4: Build and Test
1. Clean build folder: `Cmd + Shift + K`
2. Build: `Cmd + B`
3. Run on Watch simulator or device
4. On the Watch, go to **Watch app** → **Face Gallery** or edit an existing face
5. Add a complication slot
6. Look for **"Daily Bricks"** in the complication list

## 3. Troubleshooting

### Complication Not Appearing
- **Check module name**: The `CLKComplicationPrincipalClass` uses `$(PRODUCT_MODULE_NAME)` which should resolve to your module name
- **Verify file is in target**: Check Target Membership for `DailyBricksComplication.swift`
- **Clean build**: Delete DerivedData and rebuild
- **Check logs**: Look for complication-related errors in Xcode console

### Complication Shows But No Data
- **Check DailyBricksService**: Ensure it's loading data properly
- **Verify HealthKit permissions**: The service needs HealthKit access
- **Check WatchConnectivity**: Ensure phone-watch communication is working

### Build Errors
- **Missing ClockKit import**: Ensure `import ClockKit` is present
- **Module not found**: Check that the file is included in the Watch App target
- **Swift version**: Ensure Swift 5.0+ is being used

## 4. Supported Complication Families

The complication supports:
- ✅ Accessory Circular (watchOS 9+)
- ✅ Accessory Rectangular (watchOS 9+)
- ✅ Accessory Inline (watchOS 9+)
- ✅ Graphic Circular
- ✅ Graphic Rectangular
- ✅ Graphic Corner
- ✅ Graphic Bezel
- ✅ Graphic Extra Large

## 5. Testing on Device

1. **Install on Watch**: Build and run the Watch app
2. **Add to Face**: 
   - Long press watch face
   - Tap "Customize"
   - Tap a complication slot
   - Scroll to find "Daily Bricks"
3. **Verify Updates**: The complication should update every hour (or when data changes)

## Notes

- The complication identifier is: `"dailyBricks"`
- Data updates are triggered by `DailyBricksService.shared.loadTodayProgress()`
- The complication fetches data asynchronously when requested by watchOS


