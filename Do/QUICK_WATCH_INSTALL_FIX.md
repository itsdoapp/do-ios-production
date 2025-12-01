# Quick Fix: "Could Not Install At This Time" on Physical Watch

## The Issue
✅ Works on **simulator**  
❌ Fails on **physical Apple Watch** with "could not install at this time"

## Root Cause
**Provisioning profile doesn't include your Apple Watch's UDID** or the watch isn't properly registered.

## Quick Fix (5 Minutes)

### Step 1: Regenerate Provisioning Profiles

1. **In Xcode:**
   - Select **"Do Watch App"** target
   - Go to **Signing & Capabilities** tab
   - **Uncheck** "Automatically manage signing"
   - Wait 2 seconds
   - **Check** "Automatically manage signing" again
   - Xcode will regenerate profiles

2. **Do the same for iOS app:**
   - Select **"Do"** target
   - **Signing & Capabilities** tab
   - Toggle "Automatically manage signing" off and on

### Step 2: Enable Developer Mode on Watch

1. **On Apple Watch:**
   - Settings → Privacy & Security
   - Scroll to **Developer Mode**
   - Toggle **ON**
   - Watch will restart (confirm when prompted)

2. **After restart:**
   - Developer Mode should be enabled
   - You may see a developer badge

### Step 3: Register Watch in Xcode

1. **In Xcode:**
   - Window → Devices and Simulators (⇧⌘2)
   - Select your **iPhone**
   - Your watch should appear below it
   - If it doesn't appear, the watch needs to be registered

2. **If watch doesn't appear:**
   - Make sure iPhone is connected to Mac
   - Make sure iPhone is trusted on Mac
   - The watch should appear automatically when paired

### Step 4: Clean and Rebuild

1. **Clean:**
   - Product → Clean Build Folder (⇧⌘K)

2. **Rebuild:**
   - Select **"Do"** scheme
   - Choose your **iPhone** (physical device, NOT simulator)
   - Build and Run (⌘R)

### Step 5: Check for Errors

1. **In Xcode:**
   - Watch App target → Signing & Capabilities
   - Look for any **red errors**
   - Common errors:
     - "No provisioning profile found"
     - "Device not registered"
     - "Failed to create provisioning profile"

2. **If you see errors:**
   - Click **"Try Again"** or **"Download Manual Profiles"**
   - Or go to: Xcode → Settings → Accounts
   - Select your Apple ID
   - Click **"Download Manual Profiles"**

## Alternative: Manual Profile Fix

If automatic signing keeps failing:

1. **Go to Apple Developer Portal:**
   - https://developer.apple.com/account
   - Certificates, Identifiers & Profiles

2. **Get Watch UDID:**
   - In Xcode: Window → Devices and Simulators
   - Select your watch
   - Copy the **Identifier** (UDID)

3. **Register Watch:**
   - Developer Portal → Devices → Register New Device
   - Add your watch's UDID
   - Device Type: **Apple Watch**

4. **Regenerate Profiles:**
   - Profiles → Find your watchOS development profile
   - Edit → Add your watch device
   - Save and download
   - Double-click to install in Xcode

5. **Use Manual Signing:**
   - In Xcode: Watch App target → Signing & Capabilities
   - Uncheck "Automatically manage signing"
   - Select the downloaded profile

## Most Common Solution

**90% of the time, Step 1 fixes it:**
1. Toggle "Automatically manage signing" off and on
2. Let Xcode regenerate profiles
3. Rebuild

This forces Xcode to create new provisioning profiles that include your watch's UDID.

## Still Not Working?

Check the **exact error message** in:
- Xcode build log (Report Navigator ⌘9)
- Xcode console (View → Debug Area)
- Watch app on iPhone (My Watch tab)

The specific error will tell us what's wrong!

