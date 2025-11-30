# Solution: Running Watch and iPhone Apps Simultaneously

## The Problem

The watch app is **embedded** in the iOS app bundle. When you run the iOS app, Xcode:
1. Builds the iOS app
2. Builds the watch app (as dependency)
3. **Embeds the watch app** into the iOS app bundle
4. **Installs the iOS app** to the simulator
5. This installation **reinstalls the watch app**, killing any running instance

## The Solution

I've modified the project so the watch app is **only embedded during archiving**, not during regular runs. This means:

- ✅ **Running iOS app** won't reinstall the watch app
- ✅ **Running watch app** won't be affected by iOS app runs
- ✅ **Both can run simultaneously** without killing each other
- ⚠️ **Archiving** still includes the watch app (for App Store/TestFlight)

## How It Works

The `Embed Watch Content` build phase now has:
```
runOnlyForDeploymentPostprocessing = 1
```

This means:
- **During Run/Build**: Watch app is NOT embedded → No reinstallation → No killing
- **During Archive**: Watch app IS embedded → Proper bundle for distribution

## Usage

### Initial Setup (One Time)

1. **Build both apps once:**
   ```
   - Select "Do" scheme
   - Build (⌘B) - This builds both apps
   - Select "Do Watch App" scheme  
   - Build (⌘B) - This ensures watch app is built
   ```

2. **Install both apps:**
   ```
   - Select "Do" scheme
   - Run (⌘R) on iPhone Simulator - Installs iOS app
   - Select "Do Watch App" scheme
   - Run (⌘R) on Watch Simulator - Installs watch app
   - Stop both apps
   ```

### Running Both Simultaneously

Now you can run both at the same time:

1. **Run iOS app:**
   ```
   - Select "Do" scheme
   - Choose iPhone Simulator
   - Run (⌘R)
   - ✅ Watch app stays running!
   ```

2. **Run watch app:**
   ```
   - Select "Do Watch App" scheme
   - Choose Apple Watch Simulator (paired)
   - Run (⌘R)
   - ✅ iOS app stays running!
   ```

### After Code Changes

If you change code in either app:

1. **Build the changed app:**
   ```
   - Select appropriate scheme
   - Build (⌘B)
   ```

2. **Run without rebuilding the other:**
   ```
   - Use "Run Without Building" (⌃⌘R)
   - Or just Run (⌘R) - it won't kill the other app anymore!
   ```

## Important Notes

### For Development
- ✅ Both apps can run simultaneously
- ✅ No more killing each other
- ✅ Perfect for testing WatchConnectivity and handoff

### For Distribution
- ⚠️ Before archiving for App Store/TestFlight, the watch app will be embedded
- ✅ This is correct - the watch app must be in the iOS app bundle for distribution
- ✅ Archive builds work normally

### If You Need to Re-embed

If you need the watch app embedded during development (rare), you can temporarily change:
```
runOnlyForDeploymentPostprocessing = 0
```

But remember to change it back to `1` for normal development.

## Verification

To verify this is working:

1. **Run watch app** - Note it's running
2. **Run iOS app** - Watch app should **NOT** be killed
3. **Both should be running** simultaneously ✅

## Troubleshooting

**"Watch app not found when running iOS app"**
- This is expected - the watch app isn't embedded during runs
- Run the watch app separately using its own scheme

**"Watch app not in archive"**
- Check that `runOnlyForDeploymentPostprocessing = 1` (not 0)
- Archive builds should still include the watch app

**"Both apps still killing each other"**
- Clean build folder (⇧⌘K)
- Rebuild both apps
- Make sure you're using the updated project file

## Summary

✅ **Problem Solved**: Watch app embedding is now conditional
✅ **Development**: Both apps can run simultaneously  
✅ **Distribution**: Watch app still embedded in archives
✅ **No more killing**: Running one won't terminate the other

