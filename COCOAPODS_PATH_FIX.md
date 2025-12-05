# Fix CocoaPods File List Path Error

## 🔍 Problem

Xcode shows:
```
Unable to load contents of file list: '/Target Support Files/Pods-Do/Pods-Do-frameworks-Debug-input-files.xcfilelist'
```

The path is missing the `Pods/` prefix, suggesting `PODS_ROOT` build setting isn't resolving correctly.

## ✅ Solution: Complete Fix

### Method 1: Quick Fix (Recommended)

Run this script:
```bash
cd /Users/mikimeseret/Documents/Workspaces/Production/Do/ios
./fix_pods_paths.sh
```

This will:
1. Clean and reinstall Pods
2. Regenerate workspace
3. Open Xcode with correct workspace

### Method 2: Manual Fix

#### Step 1: Clean Everything
```bash
cd /Users/mikimeseret/Documents/Workspaces/Production/Do/ios

# Close Xcode first
killall Xcode

# Clean Pods
rm -rf Pods/
rm -f Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData/Do-*
```

#### Step 2: Reinstall Pods
```bash
pod install
```

#### Step 3: Verify Build Settings

1. Open `Do.xcworkspace` (NOT .xcodeproj!)
2. Select the **Do** project in Project Navigator
3. Select the **Do** target
4. Go to **Build Settings** tab
5. Search for `PODS_ROOT`
6. Verify it shows: `$(SRCROOT)/Pods`

If it's empty or wrong:
- Click the value
- Set it to: `$(SRCROOT)/Pods`
- Press Enter

#### Step 4: Clean and Build

1. **Clean Build Folder**: `Cmd + Shift + K`
2. **Clean Derived Data**: 
   - Xcode → Preferences → Locations
   - Click arrow next to Derived Data
   - Delete the `Do-*` folder
3. **Build**: `Cmd + B`

### Method 3: Fix Build Settings Directly

If the above doesn't work, manually set PODS_ROOT:

1. Open `Do.xcworkspace`
2. Select **Do** project → **Do** target
3. **Build Settings** tab
4. Search for `PODS_ROOT`
5. If empty, add: `$(SRCROOT)/Pods`
6. Also check these settings:
   - `PODS_BUILD_DIR` = `$(BUILD_DIR)`
   - `PODS_CONFIGURATION_BUILD_DIR` = `$(PODS_BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)`
   - `PODS_ROOT` = `$(SRCROOT)/Pods`
   - `PODS_TARGET_SRCROOT` = `$(PODS_ROOT)`

## 🔍 Verification

After applying the fix:

1. ✅ Xcode title shows: **"Do — Do.xcworkspace"**
2. ✅ Project Navigator shows both:
   - 📁 Do
   - 📁 Pods
3. ✅ Build succeeds without file list errors
4. ✅ `PODS_ROOT` build setting is set correctly

## 🚨 Common Causes

1. **Opening .xcodeproj instead of .xcworkspace**
   - Fix: Always open `Do.xcworkspace`

2. **PODS_ROOT build setting is empty**
   - Fix: Set to `$(SRCROOT)/Pods`

3. **Stale derived data**
   - Fix: Clean derived data folder

4. **Pods not properly installed**
   - Fix: Run `pod install`

5. **Workspace not regenerated after pod changes**
   - Fix: Run `pod install` to regenerate workspace

## 📋 Quick Checklist

- [ ] Closed Xcode completely
- [ ] Ran `pod install` successfully
- [ ] Opened `Do.xcworkspace` (not .xcodeproj)
- [ ] Verified `PODS_ROOT` build setting
- [ ] Cleaned build folder
- [ ] Cleaned derived data
- [ ] Built successfully

## 🆘 Still Not Working?

If the error persists:

1. **Check Podfile location**:
   ```bash
   ls -la Podfile
   ```
   Should be in `/Users/mikimeseret/Documents/Workspaces/Production/Do/ios/`

2. **Verify CocoaPods version**:
   ```bash
   pod --version
   ```
   Should be 1.11.0 or newer

3. **Try updating CocoaPods**:
   ```bash
   sudo gem install cocoapods
   pod repo update
   pod install
   ```

4. **Check for workspace corruption**:
   ```bash
   rm -rf Do.xcworkspace
   pod install
   ```

5. **Nuclear option** (if nothing else works):
   ```bash
   # Backup first!
   cp -r Do.xcodeproj Do.xcodeproj.backup
   
   # Clean everything
   rm -rf Pods/ Podfile.lock Do.xcworkspace
   rm -rf ~/Library/Developer/Xcode/DerivedData/Do-*
   
   # Reinstall
   pod install
   
   # Open workspace
   open Do.xcworkspace
   ```

---

**Remember**: Always use `Do.xcworkspace`, never `Do.xcodeproj` when CocoaPods are involved!








