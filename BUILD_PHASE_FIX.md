# Build Phase Fix for Simultaneous Running

## Changes Made

1. ✅ **Removed target dependency** - iOS app no longer depends on watch app
2. ✅ **Removed "Embed Watch Content" from build phases** - Not executed during regular builds
3. ✅ **Set `ignoresPersistentStateOnLaunch = "YES"`** - Both schemes now ignore persistent state
4. ✅ **Updated buildActionMask** - Embed phase now has proper mask (2147483647 = all actions, but `runOnlyForDeploymentPostprocessing = 1` prevents it from running except during archiving)

## How It Works

### Build Action Mask Values
- `8` = Analyze only
- `2147483647` = All build actions (Build, Install, Profile, Analyze, Archive, Test)
- But `runOnlyForDeploymentPostprocessing = 1` overrides this and only runs during Archive

### ignoresPersistentStateOnLaunch
- `YES` = Don't restore previous app state, launch fresh
- This might help prevent conflicts when launching

## Current Configuration

### iOS App Scheme
- `buildImplicitDependencies = "NO"` - Won't build watch app
- `ignoresPersistentStateOnLaunch = "YES"` - Fresh launch
- No watch app in build action
- No target dependency

### Watch App Scheme  
- `buildImplicitDependencies = "YES"` - Can build dependencies if needed
- `ignoresPersistentStateOnLaunch = "YES"` - Fresh launch
- Independent of iOS app

### Embed Phase
- `buildActionMask = 2147483647` - All actions
- `runOnlyForDeploymentPostprocessing = 1` - Only runs during Archive
- **Not in iOS app's build phases list** - Won't execute during Run

## Testing

Try running both apps now:
1. Run watch app (⌘R)
2. Run iOS app (⌘R)
3. Both should stay running ✅

If it still doesn't work, the issue is that Xcode's Run action **always installs** the app, and installation kills running instances. This is a simulator limitation that can't be worked around with build settings alone.





