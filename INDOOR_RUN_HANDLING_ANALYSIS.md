# Indoor Run Handling Analysis: Client vs Lambda

## Summary
✅ **Indoor runs are handled correctly** - Client sends `"treadmill_run"` which matches production database
⚠️ **Potential issue with outdoor runs** - Client sends camelCase but database expects snake_case

## Production Database Findings

### Database Structure
- **Table:** `prod-runs`
- **Primary Key:** `userId` (HASH), `runId` (RANGE)
- **GSI:** `runType` (String)

### Run Types in Production
- ✅ `"treadmill_run"` - Indoor/treadmill runs
- ✅ `"outdoor_run"` - Outdoor runs

## Client Side (iOS) Implementation

### Indoor Run Saving (`saveIndoorRun()`)
**Location:** `RunTrackingEngine.swift:3367-3368`

```swift
let activityData: [String: Any] = [
    "runType": "treadmill_run",  // ✅ CORRECT - matches database
    "formattedPace": formattedPace,
    "formattedDistance": distValue,
    "formattedTime": formattedTime,
    "averagePaceMph": averagePaceMph,
    "treadmillDataPoints": treadmillDataArray
]
```

**What gets sent to Lambda:**
```json
{
  "activityData": {
    "runType": "treadmill_run",  // ✅ Correct format
    ...
  },
  "routePoints": [],  // Empty for indoor
  "startLocation": null,
  "endLocation": null
}
```

### Outdoor Run Saving (`saveOutdoorRun()`)
**Location:** `RunTrackingEngine.swift:3561-3562`

```swift
let activityData: [String: Any] = [
    "runType": runType.rawValue,  // ⚠️ POTENTIAL ISSUE
    "formattedPace": formattedPace,
    "formattedDistance": distValue,
    "formattedTime": formattedTime
]
```

**What gets sent to Lambda:**
```json
{
  "activityData": {
    "runType": "outdoorRun",  // ⚠️ camelCase (if RunType.rawValue is camelCase)
    ...
  },
  "routePoints": [...],  // GPS coordinates
  "startLocation": {...},
  "endLocation": {...}
}
```

## Lambda Side Expectations

### What Lambda Must Do
1. **Extract `runType` from `activityData`** and set as top-level field
2. **Convert camelCase to snake_case** (if needed):
   - `"outdoorRun"` → `"outdoor_run"`
   - `"treadmillRun"` → `"treadmill_run"`
   - `"trailRun"` → `"trail_run"` (if exists)
3. **Set `runType` as top-level field** in DynamoDB item

### Expected Lambda Logic
```javascript
// Pseudo-code
const runType = activityData.runType;

// Convert camelCase to snake_case if needed
let dbRunType = runType;
if (runType === "outdoorRun") {
    dbRunType = "outdoor_run";
} else if (runType === "treadmillRun") {
    dbRunType = "treadmill_run";
} else if (runType === "treadmill_run") {
    // Already correct
    dbRunType = runType;
}

// Set as top-level field
dynamoItem.runType = dbRunType;
```

## Verification Needed

### ✅ Confirmed Working
- **Indoor runs:** Client sends `"treadmill_run"` ✅
- **Database stores:** `runType = "treadmill_run"` ✅
- **Match:** Perfect ✅

### ⚠️ Needs Verification
- **Outdoor runs:** Client sends `runType.rawValue` (unknown format)
- **Database stores:** `runType = "outdoor_run"` (snake_case)
- **Question:** Is Lambda converting `"outdoorRun"` → `"outdoor_run"`?

## Recommendations

### Option 1: Fix Client Side (Recommended)
Update `saveOutdoorRun()` to explicitly set the correct format:

```swift
let activityData: [String: Any] = [
    "runType": "outdoor_run",  // Explicit snake_case
    "formattedPace": formattedPace,
    "formattedDistance": distValue,
    "formattedTime": formattedTime
]
```

### Option 2: Verify Lambda Conversion
Check Lambda code to ensure it converts:
- `"outdoorRun"` → `"outdoor_run"`
- `"treadmillRun"` → `"treadmill_run"`
- Other RunType enum values → snake_case

### Option 3: Create Conversion Helper
```swift
extension RunType {
    var databaseValue: String {
        switch self {
        case .outdoorRun: return "outdoor_run"
        case .treadmillRun: return "treadmill_run"
        case .trailRun: return "trail_run"
        case .intervalTraining: return "interval_training"
        case .recoveryRun: return "recovery_run"
        case .lapRun: return "lap_run"
        }
    }
}
```

Then use: `"runType": runType.databaseValue`

## Current Status

### ✅ Working Correctly
1. **Indoor runs** - Client sends `"treadmill_run"` ✅
2. **Database storage** - Stores `runType = "treadmill_run"` ✅
3. **Identification** - `isIndoorRun` checks for `"treadmill_run"` ✅

### ⚠️ Potential Issues
1. **Outdoor runs** - May be sending camelCase instead of snake_case
2. **Lambda conversion** - Need to verify Lambda handles conversion
3. **Other run types** - Trail, interval, recovery, lap runs may have format issues

## Action Items

1. ✅ **Verify Lambda code** - Check if it converts camelCase to snake_case
2. ⚠️ **Fix client side** - Ensure all run types send correct format
3. ✅ **Test indoor runs** - Already working correctly
4. ⚠️ **Test outdoor runs** - Verify format matches database








