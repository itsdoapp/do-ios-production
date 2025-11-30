# Testing Handoff Between Watch and iPhone Apps

## The Challenge
Companion watch apps are automatically reinstalled when the iPhone app runs, which stops the watch app. But for handoff testing, you need both running simultaneously.

## Solution: Run Without Building

### Method 1: Run Without Building (Recommended)
This is the best approach for testing handoff:

1. **Initial Setup - Build and Install Both Apps**:
   ```
   - Select "Do" scheme
   - Run on iPhone Simulator (this builds and installs both apps)
   - Wait for installation to complete
   - Stop the app
   ```

2. **Start iPhone App**:
   ```
   - Select "Do" scheme
   - Click and hold the "Run" button in Xcode
   - Choose "Run Without Building" (⌃⌘R)
   - This launches the iPhone app without rebuilding
   ```

3. **Start Watch App**:
   ```
   - Select "Do Watch App" scheme
   - Click and hold the "Run" button
   - Choose "Run Without Building"
   - This launches the watch app without affecting iPhone app
   ```

4. **Test Handoff**:
   - Both apps are now running
   - Test workout handoff from watch to iPhone
   - Test workout handoff from iPhone to watch

### Method 2: Manual Launch After Initial Build

1. **Build Both Once**:
   ```
   - Select "Do" scheme → Build (⌘B)
   - This installs both apps
   ```

2. **Launch Manually**:
   ```
   - Open iPhone Simulator
   - Open Watch Simulator
   - Tap app icons to launch manually
   - Attach debugger if needed: Debug → Attach to Process
   ```

### Method 3: Conditional Embedding (Advanced)

For frequent handoff testing, you can make the watch app embedding conditional:

**In project.pbxproj:**
```xml
61F92E6D03768CC811E80DDA /* Embed Watch Content */ = {
    isa = PBXCopyFilesBuildPhase;
    buildActionMask = 2147483647;
    dstPath = "$(CONTENTS_FOLDER_PATH)/Watch";
    dstSubfolderSpec = 16;
    files = (
        39E304897A3E2061991C28F1 /* Do.app in Embed Watch Content */,
    );
    name = "Embed Watch Content";
    runOnlyForDeploymentPostprocessing = 1;  // Changed from 0
};
```

⚠️ **Important**: This disables embedding during Debug builds. You'll need to change it back to `0` before Release builds.

## Testing Workflow

### Typical Handoff Test Session:

1. **Clean Build** (Once per session):
   ```bash
   # Clean build directory
   Product → Clean Build Folder (⇧⌘K)
   
   # Build main app (installs both)
   Select "Do" scheme
   Build (⌘B)
   ```

2. **Launch Both Apps** (No rebuilding):
   ```bash
   # Launch iPhone app
   Select "Do" scheme
   Hold Run button → "Run Without Building" (⌃⌘R)
   
   # Launch Watch app (in new terminal/scheme)
   Select "Do Watch App" scheme
   Hold Run button → "Run Without Building"
   ```

3. **Test Handoff Scenarios**:
   - Start workout on watch → Hand off to iPhone
   - Start workout on iPhone → Hand off to watch
   - Test WatchConnectivity messages
   - Test workout state synchronization

4. **Make Code Changes**:
   ```bash
   # After changing code:
   - Stop both apps
   - Build (⌘B) to rebuild
   - Repeat step 2 (Run Without Building)
   ```

## Debugging Tips

### Viewing Logs from Both Devices:
```bash
# Terminal 1 - iPhone logs
xcrun simctl spawn booted log stream --predicate 'subsystem contains "com.do.fitness"'

# Terminal 2 - Watch logs  
xcrun simctl spawn <watch-uuid> log stream --predicate 'subsystem contains "com.do.fitness.watchapp"'
```

### Attaching Debugger After Manual Launch:
```
1. Launch both apps manually from simulators
2. In Xcode: Debug → Attach to Process by PID or Name
3. Type "Do" for iPhone app or "Do Watch App" for watch
4. Set breakpoints and debug
```

## Handoff-Specific Testing Checklist

- [ ] Start run on watch, hand off to iPhone mid-run
- [ ] Start run on iPhone, hand off to watch mid-run
- [ ] Verify metrics sync during handoff (distance, pace, HR)
- [ ] Verify GPS location continues on iPhone after handoff
- [ ] Verify HealthKit workout continues properly
- [ ] Test handoff with poor WatchConnectivity (airplane mode)
- [ ] Test handoff completion and summary display
- [ ] Verify workout saves correctly after handoff

## Common Issues

### Issue: "App not installed"
**Solution**: Run the main iPhone app once with Build to install both apps.

### Issue: "Watch app stops when iPhone app runs"
**Solution**: Use "Run Without Building" instead of regular Run.

### Issue: "WatchConnectivity not working"
**Solution**: 
- Ensure simulators are paired: Window → Devices and Simulators
- Check WCSession activation state in both apps
- Verify reachability before sending messages

### Issue: "Can't see watch logs"
**Solution**: 
- Use Console.app to view device logs
- Or use `xcrun simctl spawn <uuid> log stream`
- Print statements should appear in Xcode debug console

## Before Release

Remember to:
1. Change `runOnlyForDeploymentPostprocessing` back to `0` if you modified it
2. Verify watch app is properly embedded: Product → Archive
3. Test full build → archive → TestFlight workflow
4. Ensure companion app bundle identifier is correct

## Quick Reference

| Action | iPhone App | Watch App |
|--------|-----------|-----------|
| Initial Install | Run "Do" scheme | Installed automatically |
| Testing Handoff | Run Without Building (⌃⌘R) | Run Without Building (⌃⌘R) |
| After Code Change | Build (⌘B) | Included in iPhone build |
| Debug Only | Attach to Process → "Do" | Attach to Process → "Do Watch App" |


