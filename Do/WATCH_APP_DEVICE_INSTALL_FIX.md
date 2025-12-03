# Watch App Device Installation Fix Guide

## Quick Fix Steps

### 1. **Verify Bundle Identifiers Match**
- iOS App: `com.do.fitness`
- Watch App: `com.do.fitness.watchapp` ✅
- They must share the same base identifier

### 2. **Check Code Signing**
In Xcode:
1. Select **"Do Watch App"** target
2. Go to **Signing & Capabilities** tab
3. Ensure:
   - ✅ "Automatically manage signing" is checked
   - ✅ Development Team matches your iOS app team
   - ✅ Provisioning profile is valid (no errors)

### 3. **Verify Watch App is Embedded**
In Xcode:
1. Select **"Do"** (iOS app) target
2. Go to **Build Phases** tab
3. Look for **"Embed Watch Content"** phase
4. Ensure **"Do Watch App.app"** is listed
5. Destination should be: `$(CONTENTS_FOLDER_PATH)/Watch`

### 4. **Check Deployment Target**
- Watch App deployment target: **watchOS 10.0**
- Your Apple Watch must be running **watchOS 10.0 or later**
- Check on watch: Settings → General → About → Version

### 5. **Info.plist Configuration** ✅
The Info.plist is correctly configured:
- `WKCompanionAppBundleIdentifier` = `com.do.fitness` ✅
- `WKApplication` = `true` ✅

### 6. **Build and Run Process**

**IMPORTANT:** Always build from the iOS app scheme, not the watch app scheme:

1. In Xcode, select **"Do"** scheme (not "Do Watch App")
2. Choose your **iPhone** as the destination (not Apple Watch)
3. Click **Run** (⌘R) or **Build** (⌘B)
4. This will build both iOS and watch apps
5. The watch app should automatically install to your paired Apple Watch

### 7. **Clean Build (If Still Not Working)**

1. **Product → Clean Build Folder** (⇧⌘K)
2. **Delete Derived Data:**
   - Xcode → Settings → Locations
   - Click arrow next to Derived Data path
   - Delete the folder for your project
3. **Quit Xcode completely**
4. **Reopen Xcode and rebuild**

### 8. **Manual Installation via Watch App**

If automatic installation fails:

1. On your **iPhone**, open the **Watch** app
2. Go to **"My Watch"** tab
3. Scroll down to find **"Do"** in the list
4. If it shows "Not Installed", tap **"Install"**
5. Wait for installation to complete

### 9. **Verify Device Pairing**

Ensure your watch is properly paired:
- On iPhone: Watch app → My Watch tab
- Verify your Apple Watch appears at the top
- Check that both devices are unlocked
- Ensure both devices are on the same Wi-Fi network (or use cellular)

### 10. **Check for Specific Errors**

In Xcode console, look for:
- Code signing errors
- Bundle identifier conflicts
- Provisioning profile errors
- Deployment target mismatches

### 11. **Common Issues & Solutions**

#### Issue: "Watch app not found"
**Solution:** Ensure watch app is embedded in iOS app build phases

#### Issue: "Code signing failed"
**Solution:** 
- Check Development Team matches on both targets
- Ensure provisioning profiles are valid
- Try cleaning build folder

#### Issue: "Deployment target too high"
**Solution:** 
- Update your Apple Watch to watchOS 10.0+
- Or lower deployment target (not recommended)

#### Issue: "Watch app builds but doesn't install"
**Solution:**
- Build from iOS app scheme, not watch app scheme
- Ensure watch is paired and unlocked
- Try manual installation via Watch app on iPhone

### 12. **Verify Installation**

After building:
1. Check Xcode console for "Installing app on Apple Watch..."
2. On your Apple Watch, look for the "Do" app icon
3. If not visible, check Watch app on iPhone → My Watch → Do

## Still Not Working?

1. **Check Xcode Organizer:**
   - Window → Devices and Simulators
   - Select your Apple Watch
   - Check for error messages

2. **Verify Build Settings:**
   - Watch App Target → Build Settings
   - Search for "SKIP_INSTALL"
   - Ensure it's set to **NO** (not YES)

3. **Check Scheme Settings:**
   - Product → Scheme → Edit Scheme
   - Select "Do Watch App" scheme
   - Under "Run", ensure destination is set correctly

4. **Try Building Watch App Separately:**
   - Select "Do Watch App" scheme
   - Choose your Apple Watch as destination
   - Build (⌘B) - don't run
   - Then build iOS app normally

## Quick Checklist

- [ ] Watch app bundle ID: `com.do.fitness.watchapp`
- [ ] iOS app bundle ID: `com.do.fitness`
- [ ] Both use same Development Team
- [ ] Watch app embedded in iOS app build phases
- [ ] Info.plist has correct WKCompanionAppBundleIdentifier
- [ ] Watch deployment target matches your watch OS version
- [ ] Building from iOS app scheme (not watch app scheme)
- [ ] Both devices unlocked during installation
- [ ] Watch is paired with iPhone
- [ ] Clean build folder if issues persist


