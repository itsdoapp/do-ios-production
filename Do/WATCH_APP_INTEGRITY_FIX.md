# Watch App Integrity Verification Fix

## The Problem

**Error:** "The app cannot be installed because its integrity could not be verified"

This error occurs when the watch app's code signature cannot be verified by iOS/watchOS. This is almost always a **code signing issue**.

## Root Causes

1. **Missing or invalid provisioning profile** for the watch app
2. **Code signing certificate issues** (expired, revoked, or not trusted)
3. **Development team mismatch** between iOS and watch apps
4. **Watch app not properly signed** during the build process
5. **Provisioning profile doesn't include your Apple Watch device**

## ✅ Solution Steps

### Step 1: Verify Code Signing in Xcode

1. **Open Xcode:**
   ```bash
   open Do.xcworkspace
   ```
   ⚠️ **Important:** Use `.xcworkspace`, not `.xcodeproj`

2. **Select Watch App Target:**
   - In the project navigator, select the project (top item)
   - Under "TARGETS", select **"Do Watch App"**

3. **Go to Signing & Capabilities:**
   - Click the **"Signing & Capabilities"** tab
   - Check the following:

   **Required Settings:**
   - ✅ **"Automatically manage signing"** should be **CHECKED**
   - ✅ **Team** should be selected: `R8RJG8QJ4J` (or your team name)
   - ✅ **Provisioning Profile** should show "Xcode Managed Profile" or a valid profile
   - ✅ **Signing Certificate** should show "Apple Development"

4. **If You See Errors:**
   - Red text indicating signing issues
   - "No provisioning profile found"
   - "Failed to create provisioning profile"

   **Fix:**
   - **Uncheck** "Automatically manage signing"
   - **Check** "Automatically manage signing" again
   - This forces Xcode to regenerate provisioning profiles
   - Click **"Try Again"** if prompted

### Step 2: Verify iOS App Code Signing

1. **Select iOS App Target:**
   - Under "TARGETS", select **"Do"** (iOS app)

2. **Go to Signing & Capabilities:**
   - Verify **Team** matches the watch app: `R8RJG8QJ4J`
   - Both apps **must** use the same development team

### Step 3: Register Your Apple Watch Device

1. **Connect Your iPhone:**
   - Connect your iPhone to your Mac via USB
   - Unlock your iPhone
   - Trust the computer if prompted

2. **Open Devices Window:**
   - In Xcode: **Window → Devices and Simulators** (⇧⌘2)
   - Select your **iPhone** from the left sidebar

3. **Check Apple Watch:**
   - Your paired Apple Watch should appear under your iPhone
   - If it doesn't appear, ensure:
     - Watch is on and unlocked
     - Watch is paired with iPhone
     - Both devices are on the same Wi-Fi network

4. **Verify Watch is Registered:**
   - If you see your watch, it's registered
   - If not, Xcode should automatically register it when you build

### Step 4: Clean Build Folder

1. **In Xcode:**
   - **Product → Clean Build Folder** (⇧⌘K)
   - Wait for cleanup to complete

2. **Delete Derived Data (Optional but Recommended):**
   - **Xcode → Settings → Locations**
   - Click the arrow next to "Derived Data" path
   - Find and delete the folder for your project (usually named `Do-*`)
   - Or run:
     ```bash
     rm -rf ~/Library/Developer/Xcode/DerivedData/Do-*
     ```

### Step 5: Build and Run

**IMPORTANT:** Always build from the **iOS app scheme**, not the watch app scheme.

1. **Select Scheme:**
   - In Xcode toolbar, select **"Do"** scheme (not "Do Watch App")

2. **Select Destination:**
   - Choose your **iPhone** as the destination (not Apple Watch)

3. **Build:**
   - Press **⌘B** to build
   - Wait for build to complete successfully

4. **Run:**
   - Press **⌘R** to build and run
   - The watch app should automatically install to your paired Apple Watch

### Step 6: Verify Installation

1. **On Your Apple Watch:**
   - Look for the "Do" app icon
   - It should appear in your app grid

2. **On Your iPhone:**
   - Open the **Watch** app
   - Go to **"My Watch"** tab
   - Scroll to find **"Do"**
   - It should show as installed

## 🔧 Advanced Troubleshooting

### If Automatic Signing Still Fails

1. **Check Apple Developer Account:**
   - Ensure your Apple ID is added to Xcode
   - **Xcode → Settings → Accounts**
   - Add your Apple ID if not present
   - Ensure you're part of development team `R8RJG8QJ4J`

2. **Verify Team Access:**
   - If you're not the team admin, ask admin to:
     - Add you to the team
     - Ensure you have "Developer" or "Admin" role
     - Ensure App Groups and HealthKit are enabled for the team

3. **Check Bundle IDs in Developer Portal:**
   - Go to https://developer.apple.com/account
   - **Certificates, Identifiers & Profiles**
   - **Identifiers → App IDs**
   - Verify these exist:
     - `com.do.fitness` (iOS app)
     - `com.do.fitness.watchapp` (Watch app)
   - Both should have:
     - App Groups capability
     - HealthKit capability (if using HealthKit)

4. **Regenerate Provisioning Profiles:**
   - In Developer Portal: **Profiles**
   - Delete old development profiles for the watch app
   - Xcode will regenerate them automatically when you build

### If Watch App Still Won't Install

1. **Check watchOS Version:**
   - On your Apple Watch: **Settings → General → About**
   - Verify watchOS version is **10.0 or later**
   - If not, update your watch

2. **Enable Developer Mode (if needed):**
   - On Apple Watch: **Settings → Privacy & Security → Developer Mode**
   - Enable Developer Mode
   - Restart watch if prompted

3. **Unpair and Re-pair Watch:**
   - This is a last resort
   - On iPhone: **Watch app → My Watch → [Your Watch] → Unpair Apple Watch**
   - Re-pair the watch
   - Try installing again

4. **Manual Installation:**
   - On iPhone: Open **Watch** app
   - Go to **"My Watch"** tab
   - Find **"Do"** in available apps
   - Tap **"Install"** manually

## ✅ Verification Checklist

Before building, verify:

- [ ] Watch app target has "Automatically manage signing" checked
- [ ] Development Team is `R8RJG8QJ4J` for both iOS and watch apps
- [ ] No signing errors in Xcode (no red text)
- [ ] Provisioning profile shows as valid
- [ ] Apple Watch is paired with iPhone
- [ ] Both iPhone and Watch are unlocked
- [ ] watchOS version is 10.0 or later
- [ ] Clean build folder completed
- [ ] Building from "Do" scheme (iOS app), not "Do Watch App" scheme
- [ ] Destination is iPhone, not Apple Watch

## 📝 Common Error Messages

### "No provisioning profile found"
**Solution:** Toggle "Automatically manage signing" off and on in Xcode

### "Team not found"
**Solution:** Verify your Apple ID is added to Xcode and has access to the team

### "Device not registered"
**Solution:** Connect iPhone to Mac, Xcode will register both iPhone and paired Watch

### "Capability not available"
**Solution:** Enable the capability in Apple Developer Portal for the bundle ID

### "Failed to create provisioning profile"
**Solution:** Check Apple Developer Portal, ensure bundle IDs are registered and capabilities are enabled

## 🎯 Quick Fix Summary

1. Open `Do.xcworkspace` in Xcode
2. Select "Do Watch App" target → Signing & Capabilities
3. Toggle "Automatically manage signing" off and on
4. Verify Team is `R8RJG8QJ4J`
5. Clean build folder (⇧⌘K)
6. Build iOS app (⌘B) with iPhone as destination
7. Run (⌘R)

The watch app should now install successfully! 🎉



