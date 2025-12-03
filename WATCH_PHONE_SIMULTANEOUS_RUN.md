# Running Watch App and iPhone App Simultaneously

## The Problem

You can't run the watch target and phone target at the same time because:

1. **Separate Schemes**: Each target has its own scheme, and Xcode can only run one scheme at a time per workspace
2. **Scheme Configuration Issues**: 
   - Watch app scheme had wrong `BuildableName` (`Do.app` instead of `Do Watch App.app`)
   - iOS app scheme didn't include watch app in build action

## The Solution

### Option 1: Use the iOS App Scheme (Recommended)

The iOS app scheme now includes the watch app as a build dependency. When you run the iOS app:

1. **Select "Do" scheme** (iOS app)
2. **Choose iPhone Simulator** as destination
3. **Run (Cmd+R)**
   - This builds both iOS app and watch app
   - Watch app is automatically embedded in the iOS app bundle
   - You can then manually launch the watch app on a paired watch simulator

### Option 2: Run on Different Simulators

You can run both apps simultaneously on different simulators:

1. **First Terminal/Window:**
   - Select "Do" scheme
   - Choose iPhone Simulator
   - Run (Cmd+R)

2. **Second Terminal/Window:**
   - Select "Do Watch App" scheme  
   - Choose Apple Watch Simulator (must be paired with the iPhone simulator)
   - Run (Cmd+R)

**Note:** The watch simulator must be paired with the iPhone simulator. In Xcode:
- Window → Devices and Simulators
- Create a watch simulator and pair it with an iPhone simulator

### Option 3: Use Xcode's Multi-Scheme Run (Advanced)

You can create a custom scheme that runs both, but this requires manual configuration in Xcode's scheme editor.

## What Was Fixed

1. ✅ **Watch App Scheme**: Fixed `BuildableName` from `Do.app` to `Do Watch App.app`
2. ✅ **iOS App Scheme**: Added watch app to build action (builds but doesn't run)
3. ✅ **Dependencies**: Watch app is already a dependency of iOS app, so it builds automatically

## Current Configuration

### iOS App Scheme ("Do")
- Builds: iOS app + Watch app (as dependency)
- Runs: iOS app only
- Destination: iPhone Simulator

### Watch App Scheme ("Do Watch App")  
- Builds: Watch app only
- Runs: Watch app only
- Destination: Apple Watch Simulator (must be paired)

## Best Practice Workflow

1. **Build iOS app first** (this also builds watch app):
   ```
   Scheme: Do
   Destination: iPhone Simulator
   Action: Build (Cmd+B) or Run (Cmd+R)
   ```

2. **Then run watch app** (if needed separately):
   ```
   Scheme: Do Watch App
   Destination: Apple Watch Simulator (paired)
   Action: Run (Cmd+R)
   ```

## Why This Design?

WatchOS apps are **embedded** in iOS apps. The watch app:
- Lives inside the iOS app bundle at `Do.app/Watch/Do Watch App.app`
- Can be installed on a paired Apple Watch
- Communicates with iOS app via WatchConnectivity

This is why you typically:
1. Build/run the iOS app (which includes the watch app)
2. The watch app gets installed on the paired watch automatically
3. You can then run the watch app separately for testing

## Troubleshooting

**"Can't find watch app"**
- Ensure watch simulator is paired with iPhone simulator
- Build iOS app first to embed watch app

**"Watch app not installing"**
- Check that watch app is in "Embed Watch Content" build phase
- Verify watch app target dependency is set

**"Build errors when running both"**
- Clean build folder (Shift+Cmd+K)
- Build iOS app first, then watch app
- Ensure no conflicting build settings


