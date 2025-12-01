# Watch App Code Signing & Development Setup

## Current Configuration ✅

Your Watch app is configured with:
- **Code Signing Style:** Automatic ✅
- **Development Team:** R8RJG8QJ4J ✅
- **Bundle ID:** `com.do.fitness.watchapp` ✅

## Do You Need to Set Up Development Version?

**Short Answer:** No, if automatic signing is working. But you may need to verify/trigger it.

## Automatic Code Signing Setup

With `CODE_SIGN_STYLE = Automatic`, Xcode should:
1. ✅ Automatically create provisioning profiles for both iOS and Watch apps
2. ✅ Sign both apps with your development team
3. ✅ Handle all the certificates and profiles

## What to Check in Xcode

### 1. **Verify Watch App Signing**

1. Open Xcode
2. Select **"Do Watch App"** target
3. Go to **Signing & Capabilities** tab
4. Check:
   - ✅ "Automatically manage signing" is **checked**
   - ✅ **Team** is selected (should show your team name)
   - ✅ **Provisioning Profile** shows "Xcode Managed Profile" or a valid profile
   - ✅ **Signing Certificate** shows "Apple Development"

### 2. **If You See Errors**

If you see signing errors like:
- "No provisioning profile found"
- "Failed to create provisioning profile"
- "Team not found"

**Fix Steps:**
1. **Check Apple Developer Account:**
   - Ensure your Apple ID is added to Xcode
   - Xcode → Settings → Accounts
   - Add your Apple ID if not present
   - Ensure you're part of the development team

2. **Verify Team Access:**
   - Ensure your Apple ID has access to team `R8RJG8QJ4J`
   - If you're not the team admin, ask admin to add you

3. **Regenerate Profiles:**
   - In Signing & Capabilities, uncheck "Automatically manage signing"
   - Check it again
   - This forces Xcode to regenerate provisioning profiles

### 3. **Manual Provisioning Profile (If Needed)**

If automatic signing fails, you can manually create profiles:

1. **Go to Apple Developer Portal:**
   - https://developer.apple.com/account
   - Certificates, Identifiers & Profiles

2. **Create Watch App Identifier:**
   - Identifiers → App IDs → +
   - Select "App" → Continue
   - Description: "Do Watch App"
   - Bundle ID: `com.do.fitness.watchapp`
   - Capabilities: Enable App Groups, HealthKit
   - Continue → Register

3. **Create Development Provisioning Profile:**
   - Profiles → +
   - Select "watchOS App Development" → Continue
   - Select App ID: `com.do.fitness.watchapp`
   - Select Certificates: Your development certificate
   - Select Devices: Your Apple Watch
   - Name: "Do Watch App Development"
   - Generate → Download

4. **Install Profile:**
   - Double-click downloaded `.mobileprovision` file
   - Or drag into Xcode

5. **Use Manual Signing:**
   - In Xcode, uncheck "Automatically manage signing"
   - Select the provisioning profile you just created

## Watch App Specific Requirements

### Bundle ID Relationship
- iOS App: `com.do.fitness`
- Watch App: `com.do.fitness.watchapp` ✅
- The Watch app bundle ID **must** be a child of the iOS app bundle ID

### App Groups
Both iOS and Watch apps need:
- **App Group:** `group.com.do.fitness`
- This must be enabled in both app's entitlements
- The same App Group ID must be registered in Apple Developer Portal

### HealthKit
If using HealthKit:
- Both apps need HealthKit capability enabled
- HealthKit must be enabled in Apple Developer Portal for both bundle IDs

## Quick Verification Checklist

- [ ] Watch app target has "Automatically manage signing" checked
- [ ] Development Team is selected (matches iOS app)
- [ ] No signing errors in Xcode
- [ ] Provisioning profile shows as valid
- [ ] App Groups capability is enabled for both apps
- [ ] HealthKit capability is enabled (if using HealthKit)
- [ ] Both apps use the same Development Team

## Common Issues & Solutions

### Issue: "No provisioning profile matching"
**Solution:**
1. Clean build folder (⇧⌘K)
2. In Signing & Capabilities, toggle "Automatically manage signing" off and on
3. Build again

### Issue: "Team not found"
**Solution:**
1. Xcode → Settings → Accounts
2. Add your Apple ID
3. Select your team
4. Download manual profiles if needed

### Issue: "Bundle identifier is already in use"
**Solution:**
- This means the bundle ID is registered to another team
- You need to use a different bundle ID or get access to that team

### Issue: "App Groups not configured"
**Solution:**
1. Apple Developer Portal → Identifiers
2. Find your App Group: `group.com.do.fitness`
3. Ensure it's enabled for both iOS and Watch app bundle IDs

## Testing on Device

Once signing is correct:
1. Connect your iPhone
2. Select "Do" scheme
3. Choose your iPhone as destination
4. Build and Run (⌘R)
5. Watch app should automatically install to paired Apple Watch

## Summary

**You typically DON'T need to manually set up development profiles** if:
- ✅ Automatic signing is enabled
- ✅ Your Apple ID is in Xcode
- ✅ You have access to the development team
- ✅ No signing errors appear

**You DO need to check manually if:**
- ❌ You see signing errors
- ❌ Provisioning profiles are missing
- ❌ Team access issues
- ❌ Bundle ID conflicts

The current configuration looks correct - just verify in Xcode that signing is working properly!

