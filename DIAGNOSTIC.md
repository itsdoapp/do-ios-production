# Diagnostic: Why Apps Kill Each Other

## The Hard Truth

**This is NOT a configuration issue - it's how watchOS apps work in simulators.**

When you press **Run (⌘R)** in Xcode, it:
1. Builds the app
2. **Installs it to the simulator** ← This is what kills the other app
3. Launches it

The installation step **always terminates** any running instance of the same app or related apps.

## Why Configuration Changes Don't Help

Even with:
- ✅ No target dependencies
- ✅ No implicit dependencies  
- ✅ No embedding during runs
- ✅ Separate schemes

**The installation step still happens**, and that's what kills the other app.

## The ONLY Solutions

### Solution 1: Use "Run Without Building" ⭐ REQUIRED

This is the **ONLY** way to run both simultaneously:

1. **Build both apps ONCE:**
   ```
   - Select "Do" scheme → Build (⌘B)
   - Select "Do Watch App" scheme → Build (⌘B)
   ```

2. **Run WITHOUT building:**
   ```
   - Select "Do" scheme
   - Press ⌃⌘R (Control + Command + R)
   - OR: Hold Run button → "Run Without Building"
   
   - Select "Do Watch App" scheme  
   - Press ⌃⌘R
   - OR: Hold Run button → "Run Without Building"
   ```

3. **Both run simultaneously!** ✅

### Solution 2: Manual Launch from Simulator

1. Build both apps (⌘B)
2. Open iPhone Simulator → Tap "Do" app icon
3. Open Watch Simulator → Tap "Do Watch App" icon
4. Attach debuggers if needed: Debug → Attach to Process

### Solution 3: Physical Devices

On **real iPhone + Apple Watch**, both apps run simultaneously without any issues.

## Verification Test

Try this to prove it works:

1. **Build both apps:**
   ```bash
   # Terminal
   cd /Users/mikimeseret/Documents/Workspaces/Production/Do/ios
   xcodebuild -workspace Do.xcworkspace -scheme "Do" build
   xcodebuild -workspace Do.xcworkspace -scheme "Do Watch App" build
   ```

2. **In Xcode, use "Run Without Building":**
   - Select "Do" scheme → ⌃⌘R
   - Select "Do Watch App" scheme → ⌃⌘R
   
3. **Both should be running** ✅

If you use regular **Run (⌘R)**, the second one will kill the first. This is **expected behavior**.

## What's Happening

When you press **Run (⌘R)**:
```
Xcode → Build → Install → Launch
                ↑
         This kills other app
```

When you press **Run Without Building (⌃⌘R)**:
```
Xcode → Launch (skip build/install)
         ↑
    Doesn't kill other app
```

## Summary

**You MUST use "Run Without Building" (⌃⌘R) to run both simultaneously.**

This is not a bug - it's how watchOS apps work. The simulator installs apps, and installation terminates running instances.

**No amount of configuration changes will fix this** because it's a fundamental limitation of the simulator.

## Quick Reference

| What You Want | What To Do |
|---------------|------------|
| Run both simultaneously | Use ⌃⌘R (Run Without Building) |
| Test after code changes | Build (⌘B) then ⌃⌘R |
| Normal development | Use ⌘R (accepts that it kills the other) |
| Production testing | Use physical devices |

