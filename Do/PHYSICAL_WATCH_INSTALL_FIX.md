# Physical Watch Installation Fix - "Could Not Install At This Time"

## The Problem

Watch app installs successfully on **simulator** but fails on **physical Apple Watch** with error: **"could not install at this time"**

## Root Causes (Most Common)

### 1. **Provisioning Profile Issues** ⚠️ MOST COMMON
Physical devices require valid provisioning profiles that include:
- Your Apple Watch's UDID
- Watch app bundle ID: `com.do.fitness.watchapp`
- Proper App Groups capability
- HealthKit capability

### 2. **Code Signing Certificate Issues**
- Development certificate not trusted on device
- Certificate expired or revoked
- Team ID mismatch

### 3. **Device Trust/Developer Mode**
- Apple Watch not in Developer Mode
- Device not trusted
- Watch not properly paired

### 4. **Watch App Not Embedded for Device Builds**
- Watch app might not be included in device builds
- Embed phase might be skipped for device builds

## Solutions (Try in Order)

### Solution 1: Fix Provisioning Profiles (MOST IMPORTANT)

1. **In Xcode:**
   - Select **"Do Watch App"** target
   - Go to **Signing & Capabilities** tab
   - **Uncheck** "Automatically manage signing"
   - **Check** "Automatically manage signing" again
   - This forces Xcode to regenerate provisioning profiles

2. **Verify Team:**
   - Ensure **Development Team** is selected: `R8RJG8QJ4J`
   - If you see errors, click **"Try Again"** or **"Download Manual Profiles"**

3. **Check for Errors:**
   - Look for red text in Signing & Capabilities
   - Common errors:
     - "No provisioning profile found"
     - "Device not registered"
     - "Capability not available"

### Solution 2: Register Your Apple Watch

1. **In Xcode:**
   - Window → Devices and Simulators (⇧⌘2)
   - Select your **iPhone**
   - If your watch appears, select it
   - Check if it shows any errors

2. **Register Watch Manually:**
   - If watch doesn't appear, you may need to:
     - Connect iPhone to Mac
     - Open Xcode → Devices
     - Trust the device
     - The watch should appear automatically when paired

### Solution 3: Enable Developer Mode on Watch

1. **On Apple Watch:**
   - Settings → Privacy & Security
   - Scroll to **Developer Mode**
   - Toggle **ON**
   - Watch will restart (confirm when prompted)

2. **Verify:**
   - After restart, Developer Mode should be enabled
   - You may see a developer badge in Control Center

### Solution 4: Clean and Rebuild

1. **Clean Everything:**
   ```bash
   # In Xcode:
   Product → Clean Build Folder (⇧⌘K)
   
   # Or in terminal:
   cd /Users/mikimeseret/Documents/Workspaces/Production/Do/ios
   rm -rf ~/Library/Developer/Xcode/DerivedData/Do-*
   ```

2. **Delete Old Provisioning Profiles:**
   - Xcode → Settings → Accounts
   - Select your Apple ID
   - Click **"Download Manual Profiles"**
   - Or delete old profiles and let Xcode regenerate

3. **Rebuild:**
   - Select **"Do"** scheme
   - Choose your **iPhone** (physical device, not simulator)
   - Build and Run (⌘R)

### Solution 5: Check Apple Developer Portal

1. **Verify App IDs:**
   - Go to [developer.apple.com](https://developer.apple.com)
   - Certificates, Identifiers & Profiles
   - **Identifiers** → Check:
     - `com.do.fitness` (iOS app) exists
     - `com.do.fitness.watchapp` (Watch app) exists
   - Both should have:
     - ✅ App Groups: `group.com.do.fitness`
     - ✅ HealthKit enabled

2. **Verify Provisioning Profiles:**
   - **Profiles** → Check for:
     - iOS App Development profile for `com.do.fitness`
     - watchOS App Development profile for `com.do.fitness.watchapp`
   - Both should:
     - Include your development certificate
     - Include your iPhone's UDID
     - Include your Apple Watch's UDID (if registered)

3. **Register Watch UDID:**
   - If watch UDID is not in profiles:
     - In Xcode: Window → Devices and Simulators
     - Select your watch
     - Copy the Identifier (UDID)
     - In Developer Portal: Devices → Register New Device
     - Add your watch's UDID
     - Regenerate provisioning profiles

### Solution 6: Manual Provisioning Profile Fix

If automatic signing keeps failing:

1. **Download Profiles Manually:**
   - Developer Portal → Profiles
   - Download both iOS and watchOS development profiles
   - Double-click to install in Xcode

2. **Use Manual Signing:**
   - In Xcode: Watch App target → Signing & Capabilities
   - Uncheck "Automatically manage signing"
   - Select the downloaded provisioning profile
   - Do the same for iOS app if needed

### Solution 7: Check Build Settings for Device

1. **Verify Embed Phase Runs for Device:**
   - Select **"Do"** target → **Build Phases**
   - Check **"Embed Watch Content"** phase
   - Ensure it's not set to "runOnlyForDeploymentPostprocessing = 1"
   - For device builds, it should run during regular builds

2. **Check Scheme Configuration:**
   - Product → Scheme → Edit Scheme
   - Select **"Do"** scheme
   - **Build** action should include "Do Watch App"
   - **Run** action should include "Do Watch App"

### Solution 8: Trust Developer Certificate on iPhone

1. **On iPhone:**
   - Settings → General → VPN & Device Management
   - Look for your developer certificate
   - Tap **"Trust [Your Name]"**
   - Confirm trust

2. **This may also affect watch app installation**

## Diagnostic Steps

### Step 1: Check Build Log
1. Build the iOS app for your physical iPhone
2. Open **Report Navigator** (⌘9)
3. Select the latest build
4. Look for errors related to:
   - "Do Watch App" code signing
   - Provisioning profile
   - Embed Watch Content phase

### Step 2: Check Device Window
1. Window → Devices and Simulators (⇧⌘2)
2. Select your **iPhone**
3. Look for **"Installed Apps"** section
4. Check if "Do Watch App" appears
5. If it appears but shows an error, note the error message

### Step 3: Check Watch App on iPhone
1. Open **Watch** app on iPhone
2. Go to **My Watch** tab
3. Find **"Do"** in the list
4. Check for any error messages or status indicators

### Step 4: Check Console for Errors
1. In Xcode: View → Debug Area → Show Debug Area
2. Build and try to install
3. Look for specific error messages in console

## Most Likely Fix

**90% of the time, this is a provisioning profile issue.** Try Solution 1 first:

1. Uncheck "Automatically manage signing"
2. Check "Automatically manage signing" again
3. Let Xcode regenerate profiles
4. Build again

## If Nothing Works

1. **Check exact error in Xcode console** - there's usually a more specific error message
2. **Check Apple Developer Portal** - ensure all capabilities are enabled
3. **Verify watch is properly paired** - unpair and re-pair if needed
4. **Try a different development team** (if you have access to multiple)
5. **Check if watchOS version matches** - your watch must be on watchOS 10.0+

## Quick Checklist

- [ ] Developer Mode enabled on Apple Watch
- [ ] Watch properly paired with iPhone
- [ ] iPhone trusted on Mac
- [ ] Development Team selected in both targets
- [ ] No red errors in Signing & Capabilities
- [ ] Provisioning profiles regenerated
- [ ] Clean build performed
- [ ] Building for physical device (not simulator)
- [ ] watchOS version is 10.0+

Try these solutions in order, and the issue should be resolved!

