# Indoor Run Identification in Production Database

## Database Information
- **Table Name:** `prod-runs`
- **Region:** `us-east-1`
- **Profile:** `do-app-admin`

## Table Structure
- **Primary Key:**
  - `userId` (HASH) - String
  - `runId` (RANGE) - String
- **Indexes:**
  - `runType` (String) - GSI attribute
  - `startTime` (String) - GSI attribute

## How Indoor Runs Are Identified

### Primary Field: `runType`
Indoor runs are identified by the `runType` field with the value:
- **`"treadmill_run"`** - This is the primary identifier for indoor/treadmill runs

### Secondary Identifiers (from code analysis)
Based on the `AWSActivity` struct in `ActivityService.swift`, indoor runs can also be identified by:
- `runType == "treadmill_run"` ✅ (Primary - confirmed in production)
- `runType == "indoor"` (Possible alternative)
- `activityType == "treadmill_run"` (Legacy/alternative field)
- `activityType == "indoor"` (Legacy/alternative field)

### Code Implementation
The `isIndoorRun` computed property in `AWSActivity` struct checks:
```swift
var isIndoorRun: Bool {
    return runType == "treadmill_run" || 
           runType == "indoor" || 
           activityType == "treadmill_run" ||
           activityType == "indoor"
}
```

## Production Data Examples

### Indoor Run Example
```json
{
  "runType": "treadmill_run",
  "runId": "CPCVV1dTKa",
  "userId": "cBTeVzFM3O",
  "duration": 520,
  "distance": 0,
  "calories": 0,
  "pace": 0,
  "startTime": "2024-11-08T00:33:58.580Z",
  "endTime": "2024-11-08T00:33:58.580Z",
  "createdAt": "2024-11-08T00:33:58.580Z",
  "updatedAt": "2024-11-08T00:33:58.580Z"
}
```

### Outdoor Run Example
```json
{
  "runType": "outdoor_run",
  "distance": 3814.1358,
  "route": {
    "coordinates": [...]
  }
}
```

## Key Differences

### Indoor Runs (`treadmill_run`)
- ✅ `runType = "treadmill_run"`
- ❌ No GPS route data (no `route` field or empty coordinates)
- ✅ May have treadmill-specific metrics (incline, speed settings)
- ✅ Typically has `distance = 0` or manually entered distance

### Outdoor Runs (`outdoor_run`)
- ✅ `runType = "outdoor_run"`
- ✅ Has GPS route data (`route.coordinates` array)
- ✅ Has location data (latitude/longitude points)
- ✅ May have elevation data

## Query Examples

### Find all indoor runs
```bash
aws dynamodb scan \
  --table-name prod-runs \
  --profile do-app-admin \
  --region us-east-1 \
  --filter-expression "runType = :treadmill" \
  --expression-attribute-values '{":treadmill":{"S":"treadmill_run"}}'
```

### Find all outdoor runs
```bash
aws dynamodb scan \
  --table-name prod-runs \
  --profile do-app-admin \
  --region us-east-1 \
  --filter-expression "runType = :outdoor" \
  --expression-attribute-values '{":outdoor":{"S":"outdoor_run"}}'
```

## Summary

**Primary Identifier:** `runType = "treadmill_run"`

This is the standard way to identify indoor runs in the production database. The code also checks for alternative values (`"indoor"` or `activityType` fields) for backward compatibility, but `runType = "treadmill_run"` is the current production standard.




