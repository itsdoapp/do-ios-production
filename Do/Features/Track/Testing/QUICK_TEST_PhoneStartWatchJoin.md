# Quick Test: Phone Starts → Watch Joins (Running)

## Expected Behavior Summary

### 1. Phone Starts Run
- **Phone logs**: `=== TEST START: RUNNING ===` with scenario "Phone Only"
- **Coordination**: Phone primary for distance/pace (GPS), Watch primary for HR/cadence
- **Sync**: Phone sends `workoutStateChange` to watch every ~2 seconds

### 2. Watch Detects Phone Workout
- **Watch shows**: "Join on iPhone" button (green, highlighted)
- **Detection time**: Should appear within 5-10 seconds
- **Watch logs**: Receives `workoutStateChange` message from phone

### 3. Watch Joins
- **Watch logs**: `=== TEST START: RUNNING ===` with scenario "Watch Joining Phone Workout"
- **Phone logs**: Receives `syncWorkoutData` from watch, sends `joinedWorkoutFromPhone` confirmation
- **Metrics**: Should preserve phone's elapsed time and distance (no reset)

### 4. Active Tracking (Both Devices)
- **Phone**: Continues GPS tracking, sends distance/pace/elapsedTime every ~2s
- **Watch**: Sends heartRate/cadence every ~2s
- **Sync frequency**: ~2 seconds between devices
- **Elapsed time**: Should match between devices (±2 seconds)

### 5. Stop Workout
- **Phone**: Tap Stop → sends `workoutStateChange` with state "stopped"
- **Watch**: Receives stop message, ends workout
- **Both**: Show `=== TEST END: RUNNING ===`

---

## Key Log Markers to Look For

### Phone Side
```
=== TEST START: RUNNING ===
[COORDINATION] [RUNNING] Primary device for distance: PHONE
=== SYNC EVENT === (phoneToWatch)
[PHONE] [RUNNING] Watch has acknowledged our join request!
=== TEST END: RUNNING ===
```

### Watch Side
```
[WATCH] [RUNNING] Received message: type=workoutStateChange
=== TEST START: RUNNING ===
=== SYNC EVENT === (watchToPhone)
=== TEST END: RUNNING ===
```

---

## Success Checklist

- [ ] Phone starts run successfully
- [ ] Watch detects phone workout within 10 seconds
- [ ] "Join on iPhone" button appears on watch
- [ ] Watch can join the workout
- [ ] Elapsed time matches between devices
- [ ] Distance continues (doesn't reset)
- [ ] Heart rate appears on watch
- [ ] Sync events occur every ~2 seconds
- [ ] Both devices stop together

---

## What to Report

1. **Phone logs**: Copy from `=== TEST START: RUNNING ===` to `=== TEST END: RUNNING ===`
2. **Watch logs**: Copy from `=== TEST START: RUNNING ===` to `=== TEST END: RUNNING ===`
3. **Timing**: How long for detection? How long for join?
4. **Issues**: Any errors, resets, or unexpected behavior

