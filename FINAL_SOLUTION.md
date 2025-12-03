# Final Solution: Running Watch and iPhone Apps Simultaneously

## The Real Problem

The fundamental issue is that **watchOS apps are embedded in iOS apps**. When Xcode **installs** the iOS app to the simulator, it installs the entire bundle including the embedded watch app. This installation process **terminates any running watch app instance**.

This is a **simulator limitation** - it's how watchOS apps work. Even with all the configuration changes, the installation step is what kills the other app.

## The Only Real Solutions

### Solution 1: Use "Run Without Building" (Recommended)

This is the **only reliable way** to run both apps simultaneously:

1. **Initial Setup (One Time):**
   ```
   - Build both apps: Select "Do" scheme → Build (⌘B)
   - Install both: Run "Do" scheme once, then "Do Watch App" scheme once
   - Stop both apps
   ```

2. **Run Both Simultaneously:**
   ```
   - Select "Do" scheme
   - Hold the Run button (or press ⌃⌘R)
   - Choose "Run Without Building"
   - Select "Do Watch App" scheme
   - Hold the Run button (or press ⌃⌘R)  
   - Choose "Run Without Building"
   ```

3. **Both apps now run simultaneously!** ✅

### Solution 2: Manual Launch from Simulators

After building once:

1. **Open iPhone Simulator** - Tap the Do app icon
2. **Open Watch Simulator** - Tap the Do Watch App icon
3. **Attach debuggers if needed:**
   - Debug → Attach to Process by PID or Name
   - Type "Do" for iPhone or "Do Watch App" for watch

### Solution 3: Use Physical Devices

On **real devices**, both apps can run simultaneously without issues:
- Install iOS app on iPhone (includes watch app)
- Watch app automatically installs on paired Apple Watch
- Both can run at the same time
- No killing each other

## What I've Changed

To minimize the issue, I've made these changes:

1. ✅ **Disabled implicit dependencies** in iOS app scheme
   - iOS app won't automatically build watch app when running

2. ✅ **Set watch embedding to deployment-only**
   - Watch app only embedded during archiving, not regular runs
   - Reduces unnecessary rebuilds

3. ✅ **Watch app scheme independent**
   - Watch app won't build iOS app when running

## Why This Still Happens

Even with all these changes, **running the iOS app still installs it**, and that installation can affect the watch app because:

1. **Simulator behavior**: Installing an app can terminate related apps
2. **Bundle relationship**: Watch app is conceptually part of iOS app bundle
3. **Xcode limitation**: Can't prevent installation when using "Run"

## The Workaround

**You MUST use "Run Without Building"** to run both simultaneously:

- **Keyboard shortcut**: `⌃⌘R` (Control + Command + R)
- **Or**: Hold the Run button → Choose "Run Without Building"

This launches the app **without rebuilding or reinstalling**, so it won't kill the other app.

## Quick Reference

| Action | Command | Kills Other App? |
|--------|---------|------------------|
| Run iOS app | ⌘R | ✅ Yes (reinstalls) |
| Run Watch app | ⌘R | ✅ Yes (if iOS runs) |
| Run iOS (no build) | ⌃⌘R | ❌ No |
| Run Watch (no build) | ⌃⌘R | ❌ No |
| Build only | ⌘B | ❌ No |

## Recommended Workflow

1. **Make code changes**
2. **Build both apps**: `⌘B` on each scheme
3. **Run without building**: `⌃⌘R` on each scheme
4. **Test simultaneously** ✅

## Alternative: Script Helper

I've created `run_both_apps.sh` that:
- Builds both apps
- Installs them to simulators
- Provides instructions for running

Usage:
```bash
./run_both_apps.sh
```

Then use "Run Without Building" in Xcode.

## Summary

**The killing behavior is unavoidable when using regular "Run"** because of how watchOS apps are embedded and how simulators work.

**The solution is to use "Run Without Building" (⌃⌘R)** after the initial build/install.

This is a **known limitation** of watchOS app development in simulators, not a bug in your configuration.


