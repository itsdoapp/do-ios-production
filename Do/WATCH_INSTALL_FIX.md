# Watch App Installation Fix

## The Problem

You're seeing "unable to install" even though:
- ✅ Watch is paired and connected
- ✅ watchOS version is 10.0+
- ✅ Storage is available
- ✅ You tried manual install from Watch app

## Root Cause

The `Embed Watch Content` build phase has `runOnlyForDeploymentPostprocessing = 0`, which means it runs during regular builds. However, there might be an issue with how the watch app is being embedded or signed.

## The Fix

I need to verify and potentially fix the embedding configuration. The watch app MUST be embedded in the iOS app bundle for installation to work.

## Critical Check: Build Output

When you build the iOS app, check the build log for:

1. **Watch app build errors:**
   - Look for any red errors related to "Do Watch App"
   - Check for code signing errors
   - Check for missing dependencies

2. **Embedding errors:**
   - Look for "Embed Watch Content" phase errors
   - Check if the watch app bundle is found

3. **Installation errors:**
   - Check Xcode console for specific installation errors
   - Look for device communication errors

## Immediate Steps to Try

### 1. Clean Everything
```bash
# In Xcode:
Product → Clean Build Folder (⇧⌘K)

# Or in terminal:
cd /Users/mikimeseret/Documents/Workspaces/Production/Do/ios
rm -rf ~/Library/Developer/Xcode/DerivedData/Do-*
```

### 2. Verify Watch App Builds Successfully
1. Select **"Do Watch App"** scheme
2. Choose **Any Apple Watch** as destination
3. Build (⌘B) - NOT Run, just Build
4. Check for any errors

### 3. Build iOS App with Watch App
1. Select **"Do"** scheme
2. Choose your **iPhone** as destination
3. Build (⌘B) - Check build log for:
   - "Do Watch App" building successfully
   - "Embed Watch Content" phase completing
   - No code signing errors

### 4. Check Device Window
1. Window → Devices and Simulators (⇧⌘2)
2. Select your **iPhone**
3. Look for **"Installed Apps"** section
4. Check if "Do Watch App" appears in the list
5. If it appears, try installing from there

### 5. Check Watch App on iPhone
1. Open **Watch** app on iPhone
2. Go to **My Watch** tab
3. Find **"Do"** in the list
4. If it shows "Installed" but app isn't on watch:
   - Tap to uninstall
   - Wait a moment
   - Tap to install again

### 6. Check for Specific Error Messages

Look in Xcode console for:
- "Failed to install app"
- "Code signing failed"
- "Device not found"
- "Storage full"
- "Incompatible app"
- "Provisioning profile not found"

## Potential Issues

### Issue 1: Watch App Not Building
**Symptom:** Build fails when building iOS app
**Fix:** Build watch app separately first, fix any errors

### Issue 2: Code Signing Mismatch
**Symptom:** Code signing errors in build log
**Fix:** 
- Verify both apps use same Development Team
- Check provisioning profiles in Apple Developer Portal
- Try toggling "Automatically manage signing" off and on

### Issue 3: Watch App Not Embedded
**Symptom:** Build succeeds but watch app doesn't install
**Fix:** Verify "Embed Watch Content" phase includes "Do Watch App.app"

### Issue 4: Provisioning Profile Issues
**Symptom:** "Provisioning profile not found" or similar
**Fix:**
- In Xcode: Watch App target → Signing & Capabilities
- Uncheck "Automatically manage signing"
- Check it again
- Xcode will regenerate profiles

### Issue 5: Watch App Bundle ID Mismatch
**Symptom:** Installation fails silently
**Fix:** Verify bundle IDs match exactly:
- iOS: `com.do.fitness`
- Watch: `com.do.fitness.watchapp`

## Next Steps

1. **Try the clean build process above**
2. **Check the build log for specific errors**
3. **Share the exact error message** you see in:
   - Xcode build log
   - Watch app on iPhone (if it shows an error)
   - Xcode console

The exact error message will tell us what's wrong!


