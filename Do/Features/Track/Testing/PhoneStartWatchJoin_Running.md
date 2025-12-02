# Test: Phone Starts Run → Watch Joins

## Test Scenario
Start a running workout on the **phone**, then **join from the watch**.

---

## Step-by-Step Test Procedure

### Phase 1: Start Run on Phone
1. [ ] Open the app on **iPhone simulator**
2. [ ] Navigate to **Track → Running**
3. [ ] Select **"Outdoor Run"**
4. [ ] Tap **"Start"**
5. [ ] Wait 10-15 seconds for the run to initialize
6. [ ] Verify on phone:
   - [ ] Run timer is counting
   - [ ] Distance shows (may be 0.00 initially)
   - [ ] Location permission granted (if prompted)

### Phase 2: Watch Detects Phone Workout
7. [ ] Open the app on **Watch simulator**
8. [ ] Navigate to the **main workout list** (WorkoutListView)
9. [ ] Verify watch shows:
   - [ ] **"Join on iPhone"** button/card appears (green, highlighted)
   - [ ] Button shows workout type: "Running" or "Outdoor Run"
   - [ ] Button has iPhone icon

### Phase 3: Watch Joins the Workout
10. [ ] On watch, tap **"Join on iPhone"** button
11. [ ] Verify watch:
    - [ ] Transitions to running workout view
    - [ ] Shows elapsed time (should match phone's elapsed time)
    - [ ] Shows distance (should match phone's distance)
    - [ ] Shows heart rate (if available)
12. [ ] Verify phone:
    - [ ] Still shows running workout
    - [ ] Metrics continue updating
    - [ ] No interruption or restart

### Phase 4: Continue Tracking (2-3 minutes)
13. [ ] Let both devices track for **2-3 minutes**
14. [ ] During tracking, verify:
    - [ ] Phone continues GPS tracking
    - [ ] Watch shows live metrics
    - [ ] Both devices show similar elapsed time (±2 seconds)
    - [ ] Distance increases on both devices
    - [ ] Heart rate appears on watch (if available)

### Phase 5: Stop Workout
15. [ ] On **phone**, tap **"Stop"** or **"End Run"**
16. [ ] Verify:
    - [ ] Phone workout ends
    - [ ] Watch workout ends (should sync automatically)
    - [ ] Both show final summary

---

## Expected Log Patterns

### On Phone (Start Run)
Look for these log sections:

```
=== TEST START: RUNNING ===
Scenario: Phone Only
[PHONE] [RUNNING] State change: notStarted → starting
[PHONE] [RUNNING] State change: starting → running
[COORDINATION] [RUNNING] Primary device for distance: PHONE [REASON: Outdoor GPS tracking]
[COORDINATION] [RUNNING] Primary device for pace: PHONE [REASON: Calculated from GPS distance]
[COORDINATION] [RUNNING] Primary device for heartRate: WATCH [REASON: Watch has better HR sensors]
[COORDINATION] [RUNNING] Primary device for cadence: WATCH [REASON: Watch better for step detection]
=== SYNC EVENT ===
Category: RUNNING
Direction: phoneToWatch
Payload: {type: "workoutStateChange", workoutType: "running", state: "running", ...}
```

### On Watch (Detect Phone Workout)
Look for:
```
[WATCH] [RUNNING] Received message: type=workoutStateChange, workoutType=running
[WATCH] [RUNNING] Phone workout detected: active=true
```

### On Watch (Join Workout)
Look for:
```
=== TEST START: RUNNING ===
Scenario: Watch Joining Phone Workout
[WATCH] [RUNNING] Joining phone workout
[WATCH] [RUNNING] State change: notStarted → running
=== SYNC EVENT ===
Category: RUNNING
Direction: watchToPhone
Payload: {type: "syncWorkoutData", ...}
```

### On Phone (Watch Joins)
Look for:
```
[PHONE] [RUNNING] Received workout update from watch
[PHONE] [RUNNING] Watch has acknowledged our join request!
[PHONE] [RUNNING] Watch joined workout
=== SYNC EVENT ===
Category: RUNNING
Direction: phoneToWatch
Payload: {type: "joinedWorkoutFromPhone", status: "success", ...}
```

### During Active Tracking (Both Devices)
Look for periodic updates every ~2 seconds:
```
[PHONE] [RUNNING] distance = 125.5 m [SOURCE: primary]
[PHONE] [RUNNING] elapsedTime = 45.2 s [SOURCE: primary]
[PHONE] [RUNNING] pace = 360.0 s/km [SOURCE: primary]
=== SYNC EVENT ===
Category: RUNNING
Direction: phoneToWatch
Payload: {distance: 125.5, elapsedTime: 45.2, ...}

[WATCH] [RUNNING] heartRate = 145 bpm [SOURCE: primary]
[WATCH] [RUNNING] cadence = 165 spm [SOURCE: primary]
=== SYNC EVENT ===
Category: RUNNING
Direction: watchToPhone
Payload: {heartRate: 145, cadence: 165, ...}
```

### On Stop
Look for:
```
[PHONE] [RUNNING] State change: running → stopped
=== SYNC EVENT ===
Category: RUNNING
Direction: phoneToWatch
Payload: {type: "workoutStateChange", state: "stopped", ...}
=== TEST END: RUNNING ===
```

---

## Expected Behavior

### Device Coordination
- **Distance**: Phone is primary (GPS-based)
- **Pace**: Phone is primary (calculated from GPS)
- **Heart Rate**: Watch is primary (better sensors)
- **Cadence**: Watch is primary (step detection)
- **Elapsed Time**: Should match between devices (±2 seconds)

### Sync Frequency
- Phone → Watch: Every ~2 seconds
- Watch → Phone: Every ~2 seconds
- No duplicate metrics (each device is primary for its metrics)

### Data Accuracy
- Distance should only increase (never decrease)
- Elapsed time should match between devices
- Heart rate should be reasonable (40-220 bpm)
- Pace should be reasonable (3-20 min/km for running)

### Error Handling
- If watch disconnects, phone should continue tracking
- If phone disconnects, watch should continue tracking
- Reconnection should resume sync without restarting workout

---

## What to Paste Back

When pasting logs, include:

1. **Phone logs** from `=== TEST START: RUNNING ===` to `=== TEST END: RUNNING ===`
2. **Watch logs** from `=== TEST START: RUNNING ===` to `=== TEST END: RUNNING ===`
3. **Any error messages** (look for ⚠️ or ❌)
4. **Timing observations**:
   - How long did it take for watch to detect phone workout?
   - How long did it take for watch to join after tapping button?
   - Did metrics sync correctly?
5. **Unexpected behavior**:
   - Did the workout restart when watch joined?
   - Did metrics reset or continue?
   - Did both devices show the same elapsed time?

---

## Success Criteria

✅ **Phone starts workout successfully**
✅ **Watch detects phone workout within 5-10 seconds**
✅ **Watch can join the workout**
✅ **Both devices show matching elapsed time**
✅ **Distance continues from phone's GPS**
✅ **Heart rate appears on watch**
✅ **Sync events occur every ~2 seconds**
✅ **No duplicate metrics**
✅ **Workout stops cleanly on both devices**

---

## Common Issues to Watch For

1. **Watch doesn't detect phone workout**
   - Check WatchConnectivity session is activated
   - Check phone is sending workout state updates
   - Check watch is checking for active workouts

2. **Watch joins but metrics reset**
   - Should preserve phone's elapsed time and distance
   - Should continue tracking, not restart

3. **Metrics don't sync**
   - Check sync events are being logged
   - Check both devices are connected
   - Check coordination flags are set correctly

4. **Workout stops on one device but not the other**
   - Both should stop when phone stops
   - Watch should receive stop message from phone

