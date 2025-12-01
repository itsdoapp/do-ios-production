# Watch App Installation Troubleshooting Guide

## Common Issues When Watch App Won't Install on Device

### 1. **Code Signing & Provisioning Profiles**
The most common issue is code signing. Check:

- **Xcode → Watch App Target → Signing & Capabilities**
  - Ensure "Automatically manage signing" is enabled
  - Verify the Development Team matches your iOS app
  - Check that provisioning profiles are valid
  - The watch app bundle ID should be: `com.do.fitness.watchapp`

### 2. **Watch App Not Embedded in iOS App**
The watch app must be embedded in the iOS app bundle:

- **Xcode → iOS App Target → Build Phases**
  - Look for "Embed Watch Content" phase
  - Ensure "Do Watch App.app" is listed
  - The destination should be: `$(CONTENTS_FOLDER_PATH)/Watch`

### 3. **Deployment Target Compatibility**
Check your watchOS version:

- **Watch App Target → General → Deployment**
  - Current: watchOS 10.0
  - Ensure your physical Apple Watch is running watchOS 10.0 or later
  - If your watch is on an older version, either:
    - Update your watch to watchOS 10.0+
    - Or lower the deployment target (not recommended)

### 4. **Bundle Identifier Mismatch**
The watch app bundle ID must follow the pattern:

- iOS App: `com.do.fitness`
- Watch App: `com.do.fitness.watchapp` ✅
- They must share the same base identifier

### 5. **Info.plist Configuration**
Verify `Do Watch App/Info.plist` contains:

```xml
<key>WKCompanionAppBundleIdentifier</key>
<string>com.do.fitness</string>
<key>WKApplication</key>
<true/>
```

### 6. **Build Scheme Issues**
When building for device:

1. **Select the iOS App scheme** (not the watch app scheme)
2. **Choose your iPhone as the destination**
3. **Build and Run** - this should build both iOS and watch apps
4. The watch app should automatically install to your paired Apple Watch

### 7. **Manual Installation Steps**

If automatic installation fails:

1. **Build the watch app separately:**
   - Select "Do Watch App" scheme
   - Choose your Apple Watch as destination
   - Build (⌘B) - don't run yet

2. **Then build and run iOS app:**
   - Select "Do" scheme
   - Choose your iPhone
   - Run (⌘R)

3. **Check Watch app on device:**
   - Open Watch app on iPhone
   - Go to "My Watch" tab
   - Find "Do" in the list
   - Ensure it's installed

### 8. **Clean Build Folder**

Sometimes cached builds cause issues:

1. **Product → Clean Build Folder** (⇧⌘K)
2. **Delete Derived Data:**
   - Xcode → Preferences → Locations
   - Click arrow next to Derived Data path
   - Delete the folder for your project
3. **Rebuild everything**

### 9. **Check Device Pairing**

Ensure your watch is properly paired:

- Settings → General → About (on watch)
- Verify watchOS version
- On iPhone: Watch app → My Watch tab
- Verify "Do" appears in available apps

### 10. **Entitlements & Capabilities**

Verify watch app has correct entitlements:

- **App Groups:** `group.com.do.fitness`
- **HealthKit:** Enabled
- **Background Modes:** Workout Processing

### 11. **Xcode Console Errors**

Check Xcode console for specific errors:

- Look for code signing errors
- Check for bundle identifier conflicts
- Verify provisioning profile issues

### 12. **Quick Fix Checklist**

Run through this checklist:

- [ ] Watch app target has correct bundle ID: `com.do.fitness.watchapp`
- [ ] iOS app target has bundle ID: `com.do.fitness`
- [ ] Both targets use the same Development Team
- [ ] Watch app is embedded in iOS app build phases
- [ ] Info.plist has `WKCompanionAppBundleIdentifier` set correctly
- [ ] Watch app deployment target matches your watch OS version
- [ ] Clean build folder and rebuild
- [ ] Watch is paired with iPhone
- [ ] Both devices are unlocked during installation

## If Still Not Working

1. **Check Xcode Organizer:**
   - Window → Devices and Simulators
   - Select your Apple Watch
   - Check for any error messages

2. **Verify in Watch App (iPhone):**
   - Open Watch app on iPhone
   - My Watch → Do
   - Check installation status

3. **Try Manual Installation:**
   - In Watch app on iPhone
   - Find "Do" in available apps
   - Tap "Install" manually

4. **Check Build Logs:**
   - View → Navigators → Report Navigator
   - Look for watch app build errors
   - Check for code signing failures

