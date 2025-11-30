# Fix "Multiple commands produce" Error

## Error
```
Multiple commands produce '/Users/mikimeseret/Library/Developer/Xcode/DerivedData/Do-*/Build/Products/Debug-watchsimulator/Do Watch App.app/Do Watch App'
```

## Root Cause
This error occurs when the Xcode build system tries to create the same output file multiple times, usually due to:
- Duplicate build phases (multiple "Compile Sources" or "Copy Bundle Resources" phases)
- The same file added to a build phase multiple times
- Multiple targets trying to produce the same output
- Duplicate dependencies

## Automated Fix Applied

I ran `deep_fix_watch_duplicates.rb` which:
✅ Checked for and removed duplicate build phases
✅ Removed duplicate files within build phases
✅ Cleaned up duplicate dependencies
✅ Verified WatchApp.swift is only referenced once
✅ Cleaned build settings (removed duplicate search paths)
✅ Set proper product module name

## Manual Steps Required

### 1. Delete Derived Data (Done)
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/Do-*
```

### 2. Close and Reopen Xcode
- **Completely quit** Xcode (Cmd+Q)
- Reopen the **workspace** (not the project):
```bash
open /Users/mikimeseret/Documents/DoIOS/iOS/Do/Do.xcworkspace
```

### 3. Clean Build Folder
In Xcode:
- Go to **Product → Clean Build Folder** (Shift+Cmd+K)
- Or hold **Option** and go to **Product → Clean Build Folder** for a deeper clean

### 4. Build Watch App
1. Select **"Do Watch App"** scheme from the scheme dropdown
2. Choose **Apple Watch Simulator** as the destination
3. Build (Cmd+B) or Run (Cmd+R)

## If Error Persists

If you still see the error after following all steps above, try these additional fixes:

### Option 1: Remove and Re-add Watch Target Files

In Xcode:
1. Select the **"Do Watch App"** target
2. Go to **Build Phases** tab
3. Expand **"Compile Sources"**
4. Check if any file appears multiple times
5. Remove duplicates (select and press Delete)

### Option 2: Check Build Phases Manually

1. Click the blue project icon at the top of Project Navigator
2. Select **"Do Watch App"** target
3. Go to **Build Phases** tab
4. You should see these phases **ONCE each**:
   - Dependencies
   - Compile Sources
   - Link Binary With Libraries
   - Copy Bundle Resources

If you see any phase multiple times, delete the duplicates.

### Option 3: Re-run Setup Script

If all else fails, you can recreate the watch target:
```bash
cd /Users/mikimeseret/Documents/DoIOS/iOS/Do
ruby setup_watch_target.rb
```

This will remove the old watch target and create a fresh one.

### Option 4: Check for WatchApp.swift Duplicates

The most common culprit is `WatchApp.swift` being added multiple times:

1. In Xcode Project Navigator, search for "WatchApp.swift"
2. If you see multiple copies, delete all but one
3. Make sure the remaining one has "Do Watch App" checked in Target Membership

## Prevention

To avoid this in the future:
- Only add files to targets once
- Don't manually create duplicate build phases
- Use the automated scripts provided for target setup
- Always clean build folder after major project changes

## Verification

After applying the fixes, verify success:
```bash
cd /Users/mikimeseret/Documents/DoIOS/iOS/Do
xcodebuild -workspace Do.xcworkspace -scheme "Do Watch App" -sdk watchsimulator clean build
```

If the build succeeds, the issue is resolved! ✅

## Related Files
- `setup_watch_target.rb` - Creates watch target
- `fix_watch_target_duplicates.rb` - Fixes duplicate embed phases
- `deep_fix_watch_duplicates.rb` - Deep clean of all duplicates (most comprehensive)

