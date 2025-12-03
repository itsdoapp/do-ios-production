# Fix: Watch App and iOS App Killing Each Other

## The Problem

When you run the iOS app, it rebuilds and reinstalls the watch app (because it's embedded), which kills any running watch app instance. Similarly, the watch app scheme was trying to build the iOS app, causing conflicts.

## Root Cause

1. **Watch app is embedded in iOS app**: The watch app lives at `Do.app/Watch/Do Watch App.app` inside the iOS app bundle
2. **Running iOS app reinstalls watch app**: When you run the iOS app, Xcode installs the entire bundle, including the embedded watch app, which terminates any running watch app
3. **Watch app scheme building iOS app**: The watch app scheme had `buildImplicitDependencies = "YES"`, causing it to rebuild the iOS app

## The Fix

### 1. Watch App Scheme
- ✅ Set `buildImplicitDependencies = "NO"` 
- This prevents the watch app from rebuilding the iOS app when you run it
- The watch app can now run independently

### 2. iOS App Scheme  
- ✅ Removed watch app from build action for running
- Watch app is still built as a dependency (via target dependency), but not explicitly in the scheme
- This minimizes rebuilds when running the iOS app

## How to Use

### Run Watch App Independently
1. Select **"Do Watch App"** scheme
2. Choose **Apple Watch Simulator** (paired with iPhone simulator)
3. Run (Cmd+R)
   - ✅ Won't rebuild iOS app
   - ✅ Can run independently

### Run iOS App
1. Select **"Do"** scheme  
2. Choose **iPhone Simulator**
3. Run (Cmd+R)
   - ✅ Builds watch app as dependency (if needed)
   - ⚠️ Will reinstall watch app if it's running (this is unavoidable due to embedding)

## Important Notes

### Why They Still Can't Run Simultaneously

Even with these fixes, **you still can't run both simultaneously** because:

1. **Watch app is embedded**: It's part of the iOS app bundle
2. **Installing iOS app reinstalls watch app**: When Xcode installs the iOS app to the simulator, it installs the entire bundle, including the embedded watch app
3. **This terminates running watch app**: Installing a new version of an app terminates any running instance

This is a **fundamental limitation** of how watchOS apps work - they're embedded in iOS apps.

## Workarounds

### Option 1: Run on Physical Devices
- Install iOS app on iPhone (includes watch app)
- Watch app automatically installs on paired Apple Watch
- Both can run simultaneously on physical devices
- Simulators have limitations that physical devices don't

### Option 2: Use Different Build Configurations
- Create separate Debug configurations
- But this still won't solve the fundamental embedding issue

### Option 3: Accept the Limitation
- Build and run iOS app first
- Then manually launch watch app from watch simulator home screen
- Or use Xcode's "Run Without Building" for watch app after iOS app is running

## Testing Workflow

1. **First time setup:**
   ```
   Build iOS app → Installs watch app to watch simulator
   ```

2. **Development workflow:**
   ```
   Option A: Run iOS app (rebuilds both, watch app restarts)
   Option B: Run watch app only (doesn't rebuild iOS app)
   ```

3. **Best practice:**
   - Make changes to watch app → Run watch app scheme
   - Make changes to iOS app → Run iOS app scheme (watch app will restart)
   - Make changes to both → Run iOS app scheme

## Verification

After these changes:
- ✅ Watch app scheme won't rebuild iOS app
- ✅ iOS app scheme won't explicitly rebuild watch app for running (but still builds as dependency)
- ⚠️ Running iOS app will still reinstall watch app (unavoidable)

The key improvement is that **running the watch app won't kill the iOS app** anymore, and **running the watch app won't rebuild the iOS app**.


