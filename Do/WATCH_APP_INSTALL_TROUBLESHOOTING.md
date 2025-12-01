# Watch App Won't Install - Troubleshooting Guide

## You Can See the App in Watch App But Can't Install

If you see "Do" in the Watch app on iPhone but tapping "Install" doesn't work, try these fixes:

### 1. **Build and Install from Xcode First**

The watch app needs to be built and installed via Xcode before it can be manually installed:

1. **In Xcode:**
   - Select **"Do"** scheme (iOS app)
   - Choose your **iPhone** as destination
   - **Build and Run** (⌘R)
   - This builds both iOS and watch apps
   - The watch app should automatically install

2. **If automatic install fails:**
   - After building, check Watch app on iPhone
   - The app should now be installable

### 2. **Check Watch Storage**

Your watch might be out of storage:

1. **On Apple Watch:**
   - Settings → General → About
   - Check available storage
   - If low, delete some apps or data

2. **On iPhone:**
   - Watch app → My Watch → General → About
   - Check storage information

### 3. **Ensure Watch is Unlocked and Connected**

1. **Unlock your Apple Watch** (enter passcode if locked)
2. **Keep watch on your wrist** or ensure it's not in sleep mode
3. **Check connection:**
   - On iPhone: Watch app → My Watch tab
   - Ensure watch shows as "Connected" (not disconnected)
   - Both devices should be on same Wi-Fi or use Bluetooth

### 4. **Restart Both Devices**

1. **Restart Apple Watch:**
   - Hold side button → Power Off → Wait 30 seconds → Power On

2. **Restart iPhone:**
   - Power off and on

3. **Try installing again:**
   - Watch app → My Watch → Do → Install

### 5. **Check for Installation Errors**

1. **On iPhone:**
   - Watch app → My Watch → Do
   - Look for any error messages
   - Check if it shows "Installing..." and gets stuck

2. **On Apple Watch:**
   - Check if you see any error notifications
   - Look for the app icon (it might be installing)

### 6. **Verify Code Signing**

The watch app must be properly signed:

1. **In Xcode:**
   - Select **"Do Watch App"** target
   - Signing & Capabilities tab
   - Ensure:
     - ✅ "Automatically manage signing" is checked
     - ✅ Development Team is selected
     - ✅ No signing errors (red text)

2. **If there are errors:**
   - Fix signing issues first
   - Clean build folder (⇧⌘K)
   - Rebuild

### 7. **Check Deployment Target**

1. **On Apple Watch:**
   - Settings → General → About → Version
   - Note your watchOS version

2. **In Xcode:**
   - Watch App target → General → Deployment
   - Ensure deployment target matches or is lower than your watchOS version
   - Current: watchOS 10.0

3. **If watchOS is older:**
   - Update your watch to watchOS 10.0+
   - Or lower deployment target (not recommended)

### 8. **Force Installation via Xcode**

If manual install doesn't work:

1. **In Xcode:**
   - Window → Devices and Simulators (⇧⌘2)
   - Select your **iPhone**
   - If your watch appears, select it
   - Look for "Installed Apps" section
   - Try to install the watch app directly

2. **Or build directly to watch:**
   - Select **"Do Watch App"** scheme
   - Choose your **Apple Watch** as destination (if visible)
   - Build and Run

### 9. **Delete and Reinstall**

If the app is partially installed:

1. **On Apple Watch:**
   - Long press app icon → Delete App
   - Or Settings → General → Reset → Erase All Content (last resort)

2. **On iPhone:**
   - Watch app → My Watch → Do
   - If it shows "Installed", tap to uninstall
   - Then try installing again

### 10. **Check App Size and Compatibility**

1. **Verify app isn't too large:**
   - Watch apps have size limits
   - Check build log for warnings

2. **Check compatibility:**
   - Ensure watch model supports the app
   - Some features require specific watch models

### 11. **Network Issues**

1. **Ensure both devices connected:**
   - Same Wi-Fi network, OR
   - Bluetooth enabled and connected

2. **Check for network errors:**
   - Try installing when both devices are on same Wi-Fi
   - Disable VPN if active

### 12. **Xcode Console Errors**

Check Xcode console for specific errors:

1. **In Xcode:**
   - View → Debug Area → Show Debug Area
   - Look for watch installation errors
   - Common errors:
     - "Failed to install app"
     - "Code signing failed"
     - "Device not found"
     - "Storage full"

## Quick Fix Checklist

Try these in order:

- [ ] Build from Xcode first (Do scheme → iPhone → Run)
- [ ] Ensure watch is unlocked and connected
- [ ] Check watch storage (delete apps if needed)
- [ ] Restart both iPhone and Watch
- [ ] Verify code signing (no errors in Xcode)
- [ ] Check watchOS version compatibility
- [ ] Try manual install after building from Xcode
- [ ] Check Xcode console for specific errors
- [ ] Ensure both devices on same network
- [ ] Delete app from watch and reinstall

## Most Common Solution

**The most common fix is to build from Xcode first:**

1. **Xcode → Select "Do" scheme**
2. **Choose iPhone as destination**
3. **Build and Run (⌘R)**
4. **Wait for build to complete**
5. **Then try installing from Watch app on iPhone**

The watch app needs to be built and signed before it can be installed. Building from Xcode creates the installable watch app bundle.

## Still Not Working?

Check Xcode console for the specific error message - that will tell us exactly what's wrong!

