# Tracking Test Checklists

This document contains step-by-step checklists for testing each tracking category. Follow the checklist, observe the logs, and paste the relevant log sections back for analysis.

## How to Use

1. Start the app in simulator
2. Follow the checklist for the category you want to test
3. Watch the console logs (they will have clear section markers)
4. Copy the log sections between the markers (e.g., `=== TEST START ===` to `=== TEST END ===`)
5. Paste the logs back for analysis

---

## Running

### Phone Only (Outdoor Run)
- [ ] Navigate to Track → Running
- [ ] Select "Outdoor Run"
- [ ] Tap Start
- [ ] Let it run for 2-3 minutes
- [ ] Observe logs for:
  - [ ] Distance updates (should be from phone GPS)
  - [ ] Pace calculations
  - [ ] Heart rate (if available from phone)
  - [ ] Calories
- [ ] Tap Pause
- [ ] Tap Resume
- [ ] Tap Stop
- [ ] Copy logs from `=== TEST START: RUNNING ===` to `=== TEST END: RUNNING ===`

### Watch Only (Indoor Run)
- [ ] Start workout on watch first
- [ ] Navigate to Track → Running on phone
- [ ] Select "Indoor Run"
- [ ] Tap "Join Workout" when prompted
- [ ] Let it run for 2-3 minutes
- [ ] Observe logs for:
  - [ ] Watch metrics being received
  - [ ] Distance from watch (no GPS)
  - [ ] Heart rate from watch
  - [ ] Coordination flags (watch should be primary)
- [ ] Tap Stop
- [ ] Copy logs from `=== TEST START: RUNNING ===` to `=== TEST END: RUNNING ===`

### Both Devices (Outdoor Run with Watch)
- [ ] Start workout on phone (Outdoor Run)
- [ ] Ensure watch is connected and tracking
- [ ] Let it run for 2-3 minutes
- [ ] Observe logs for:
  - [ ] Phone primary for distance/pace (GPS)
  - [ ] Watch primary for heart rate/cadence
  - [ ] Sync events every ~2 seconds
  - [ ] No conflicting data
- [ ] Tap Stop
- [ ] Copy logs from `=== TEST START: RUNNING ===` to `=== TEST END: RUNNING ===`

---

## Gym

### Phone Only
- [ ] Navigate to Track → Gym
- [ ] Start a new workout
- [ ] Add a movement (e.g., Bench Press)
- [ ] Complete a set (enter weight and reps)
- [ ] Observe logs for:
  - [ ] Set completion logged
  - [ ] Volume calculation
  - [ ] Heart rate (if available)
  - [ ] Calories
- [ ] Complete 2-3 more sets
- [ ] End workout
- [ ] Copy logs from `=== TEST START: GYM ===` to `=== TEST END: GYM ===`

### Watch Only
- [ ] Start workout on watch first
- [ ] Navigate to Track → Gym on phone
- [ ] Join workout when prompted
- [ ] Observe logs for:
  - [ ] Watch HR and calories being received
  - [ ] Phone still handles sets/reps manually
- [ ] End workout
- [ ] Copy logs from `=== TEST START: GYM ===` to `=== TEST END: GYM ===`

### Both Devices
- [ ] Start workout on phone
- [ ] Ensure watch is connected
- [ ] Add movements and complete sets
- [ ] Observe logs for:
  - [ ] Phone handles sets/reps
  - [ ] Watch provides HR/calories
  - [ ] Sync events
- [ ] End workout
- [ ] Copy logs from `=== TEST START: GYM ===` to `=== TEST END: GYM ===`

---

## Cycling

### Phone Only (Outdoor)
- [ ] Navigate to Track → Cycling
- [ ] Select "Outdoor Bike"
- [ ] Tap Start
- [ ] Let it run for 2-3 minutes
- [ ] Observe logs for:
  - [ ] GPS distance
  - [ ] Pace/speed
  - [ ] Heart rate (if available)
  - [ ] Calories
- [ ] Tap Stop
- [ ] Copy logs from `=== TEST START: CYCLING ===` to `=== TEST END: CYCLING ===`

### Watch Only (Indoor)
- [ ] Start workout on watch first
- [ ] Navigate to Track → Cycling on phone
- [ ] Select "Indoor Bike"
- [ ] Join workout when prompted
- [ ] Observe logs for:
  - [ ] Watch metrics
  - [ ] No GPS distance
- [ ] Tap Stop
- [ ] Copy logs from `=== TEST START: CYCLING ===` to `=== TEST END: CYCLING ===`

### Both Devices (Outdoor)
- [ ] Start outdoor bike on phone
- [ ] Ensure watch is connected
- [ ] Let it run for 2-3 minutes
- [ ] Observe logs for:
  - [ ] Phone primary for distance/pace
  - [ ] Watch primary for HR/cadence
  - [ ] Sync events
- [ ] Tap Stop
- [ ] Copy logs from `=== TEST START: CYCLING ===` to `=== TEST END: CYCLING ===`

---

## Hiking

### Phone Only
- [ ] Navigate to Track → Hiking
- [ ] Select "Trail"
- [ ] Tap Start
- [ ] Let it run for 2-3 minutes
- [ ] Observe logs for:
  - [ ] GPS distance
  - [ ] Elevation gain
  - [ ] Pace
  - [ ] Heart rate (if available)
- [ ] Tap Stop
- [ ] Copy logs from `=== TEST START: HIKING ===` to `=== TEST END: HIKING ===`

### Watch Only
- [ ] Start workout on watch first
- [ ] Navigate to Track → Hiking on phone
- [ ] Join workout when prompted
- [ ] Observe logs for:
  - [ ] Watch metrics
  - [ ] Elevation from watch (if available)
- [ ] Tap Stop
- [ ] Copy logs from `=== TEST START: HIKING ===` to `=== TEST END: HIKING ===`

### Both Devices
- [ ] Start hike on phone
- [ ] Ensure watch is connected
- [ ] Let it run for 2-3 minutes
- [ ] Observe logs for:
  - [ ] Phone primary for distance/elevation
  - [ ] Watch primary for HR
  - [ ] Sync events
- [ ] Tap Stop
- [ ] Copy logs from `=== TEST START: HIKING ===` to `=== TEST END: HIKING ===`

---

## Walking

### Phone Only
- [ ] Navigate to Track → Walking
- [ ] Select "Outdoor Walk"
- [ ] Tap Start
- [ ] Let it run for 2-3 minutes
- [ ] Observe logs for:
  - [ ] GPS distance
  - [ ] Steps (from phone if available)
  - [ ] Pace
  - [ ] Heart rate (if available)
- [ ] Tap Stop
- [ ] Copy logs from `=== TEST START: WALKING ===` to `=== TEST END: WALKING ===`

### Watch Only
- [ ] Start workout on watch first
- [ ] Navigate to Track → Walking on phone
- [ ] Join workout when prompted
- [ ] Observe logs for:
  - [ ] Watch distance/steps
  - [ ] Watch HR
- [ ] Tap Stop
- [ ] Copy logs from `=== TEST START: WALKING ===` to `=== TEST END: WALKING ===`

### Both Devices
- [ ] Start walk on phone
- [ ] Ensure watch is connected
- [ ] Let it run for 2-3 minutes
- [ ] Observe logs for:
  - [ ] Phone primary for distance (outdoor)
  - [ ] Watch primary for steps/HR
  - [ ] Sync events
- [ ] Tap Stop
- [ ] Copy logs from `=== TEST START: WALKING ===` to `=== TEST END: WALKING ===`

---

## Swimming

### Phone Only
- [ ] Navigate to Track → Swimming
- [ ] Enter pool length (e.g., 25m)
- [ ] Tap Start
- [ ] Manually add laps (tap + button)
- [ ] Observe logs for:
  - [ ] Lap count
  - [ ] Distance calculation
  - [ ] Pace per 100m
  - [ ] Heart rate (if available)
- [ ] Add 3-5 laps
- [ ] Tap Stop
- [ ] Copy logs from `=== TEST START: SWIMMING ===` to `=== TEST END: SWIMMING ===`

### Watch Only
- [ ] Start workout on watch first
- [ ] Navigate to Track → Swimming on phone
- [ ] Join workout when prompted
- [ ] Observe logs for:
  - [ ] Watch distance (pool detection)
  - [ ] Watch HR
  - [ ] Watch is primary for all metrics
- [ ] Tap Stop
- [ ] Copy logs from `=== TEST START: SWIMMING ===` to `=== TEST END: SWIMMING ===`

### Both Devices
- [ ] Start swim on phone
- [ ] Ensure watch is connected
- [ ] Add laps manually on phone
- [ ] Observe logs for:
  - [ ] Watch primary for all metrics (GPS doesn't work underwater)
  - [ ] Phone acts as dashboard
  - [ ] Sync events
- [ ] Tap Stop
- [ ] Copy logs from `=== TEST START: SWIMMING ===` to `=== TEST END: SWIMMING ===`

---

## Food

### Phone Only (Manual Entry)
- [ ] Navigate to Track → Food
- [ ] Tap "Add Food"
- [ ] Enter food details:
  - [ ] Name: "Test Meal"
  - [ ] Meal Type: Breakfast
  - [ ] Calories: 300
  - [ ] Protein: 20g
  - [ ] Carbs: 40g
  - [ ] Fat: 10g
- [ ] Tap Save
- [ ] Observe logs for:
  - [ ] Food entry logged
  - [ ] AppGroup sync event: `[SYNC] [FOOD] Syncing to AppGroup: key=todaysFoods, entries=X`
  - [ ] Verify entry count increases
- [ ] Add 2-3 more food entries (different meal types)
- [ ] Observe logs for:
  - [ ] Each entry syncs to AppGroup
  - [ ] Entry count updates
- [ ] Copy logs from `=== TEST START: FOOD ===` to `=== TEST END: FOOD ===`

### Verify Watch Fuel Category
- [ ] After logging food on phone, check watch
- [ ] Navigate to Daily Bricks on watch
- [ ] Check Fuel brick
- [ ] Verify:
  - [ ] Meal count matches entries logged
  - [ ] Fuel progress updates
- [ ] Note: Watch reads from AppGroup, so sync should be immediate

---

## Meditation

### Phone Only
- [ ] Navigate to Track → Meditation
- [ ] Start a meditation session
- [ ] Select type (e.g., Mindfulness)
- [ ] Set duration (e.g., 5 minutes)
- [ ] Tap Start
- [ ] Let it run for 1-2 minutes
- [ ] Observe logs for:
  - [ ] Duration tracking
  - [ ] Session state
- [ ] Complete session
- [ ] Copy logs from `=== TEST START: MEDITATION ===` to `=== TEST END: MEDITATION ===`

### Watch Only (HR during meditation)
- [ ] Start meditation on phone
- [ ] Ensure watch is connected
- [ ] Observe logs for:
  - [ ] Watch HR being received
  - [ ] HR updates during meditation
- [ ] Complete session
- [ ] Copy logs from `=== TEST START: MEDITATION ===` to `=== TEST END: MEDITATION ===`

### Both Devices
- [ ] Start meditation on phone
- [ ] Ensure watch is connected
- [ ] Let it run for 2-3 minutes
- [ ] Observe logs for:
  - [ ] Phone tracks duration
  - [ ] Watch provides HR
  - [ ] Sync events
- [ ] Complete session
- [ ] Copy logs from `=== TEST START: MEDITATION ===` to `=== TEST END: MEDITATION ===`

---

## Sports

### Phone Only (Outdoor)
- [ ] Navigate to Track → Sports
- [ ] Select sport type (e.g., Basketball)
- [ ] Select "Outdoor"
- [ ] Tap Start
- [ ] Let it run for 2-3 minutes
- [ ] Observe logs for:
  - [ ] GPS distance
  - [ ] Heart rate (if available)
  - [ ] Calories
- [ ] Tap Stop
- [ ] Copy logs from `=== TEST START: SPORTS ===` to `=== TEST END: SPORTS ===`

### Watch Only (Indoor)
- [ ] Start workout on watch first
- [ ] Navigate to Track → Sports on phone
- [ ] Select "Indoor"
- [ ] Join workout when prompted
- [ ] Observe logs for:
  - [ ] Watch metrics
  - [ ] No GPS distance
- [ ] Tap Stop
- [ ] Copy logs from `=== TEST START: SPORTS ===` to `=== TEST END: SPORTS ===`

### Both Devices (Outdoor)
- [ ] Start outdoor sport on phone
- [ ] Ensure watch is connected
- [ ] Let it run for 2-3 minutes
- [ ] Observe logs for:
  - [ ] Phone primary for distance
  - [ ] Watch primary for HR
  - [ ] Sync events
- [ ] Tap Stop
- [ ] Copy logs from `=== TEST START: SPORTS ===` to `=== TEST END: SPORTS ===`

---

## Expected Log Patterns

### Coordination Logs
Look for: `[COORDINATION] [CATEGORY] Primary device for [METRIC]: [DEVICE] [REASON: ...]`

### Sync Logs
Look for: `=== SYNC EVENT ===` sections showing data flow between devices

### Metric Updates
Look for: `[PHONE/WATCH] [CATEGORY] [METRIC] = VALUE [SOURCE: primary/fallback]`

### AppGroup Sync (Food)
Look for: `[SYNC] [FOOD] Syncing to AppGroup: key=todaysFoods, entries=X`

---

## What to Paste Back

When pasting logs back, include:
1. All logs between `=== TEST START: [CATEGORY] ===` and `=== TEST END: [CATEGORY] ===`
2. Any error messages
3. Any unexpected behavior you noticed
4. Which scenario you tested (Phone Only, Watch Only, Both Devices)

