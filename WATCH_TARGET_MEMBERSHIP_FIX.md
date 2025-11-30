# Fix: Cannot find 'WatchConnectivityManager' and 'WatchWorkoutCoordinator' in scope

## Problem
Xcode is reporting "Cannot find 'WatchConnectivityManager' in scope" and "Cannot find 'WatchWorkoutCoordinator' in scope" even though the files exist.

## Root Cause
The files are not added to the **Do Watch App** target in Xcode. All Swift files must be explicitly added to their target to be compiled and accessible.

## Solution: Add Files to Watch App Target

### Method 1: Using File Inspector (Recommended)

1. **Open Xcode** and navigate to the Project Navigator
2. **Select each file** that's causing the error:
   - `WatchConnectivityManager.swift`
   - `WatchWorkoutCoordinator.swift`
   - Any other files showing "Cannot find in scope" errors

3. **Open the File Inspector** (right panel, or press `Cmd+Option+1`)

4. **Under "Target Membership"**, check the box for:
   - ✅ **Do Watch App**

5. **Uncheck** any incorrect targets (like "Do" if it's checked)

6. **Clean and rebuild**:
   - `Product` → `Clean Build Folder` (Cmd+Shift+K)
   - `Product` → `Build` (Cmd+B)

### Method 2: Using Project Settings

1. **Select the project** in Project Navigator
2. **Select "Do Watch App" target**
3. **Go to "Build Phases" tab**
4. **Expand "Compile Sources"**
5. **Click the "+" button**
6. **Add the missing files**:
   - `WatchConnectivityManager.swift`
   - `WatchWorkoutCoordinator.swift`

### Method 3: Verify All Watch App Files

Check that these files are in the **Do Watch App** target:
- ✅ `WatchApp.swift`
- ✅ `WatchAuthService.swift`
- ✅ `WatchConnectivityManager.swift`
- ✅ `WatchWorkoutCoordinator.swift`
- ✅ All other files in `Do/Do Watch App/` directory

## Verification

After adding files to the target:

1. **Clean Build Folder**: `Cmd+Shift+K`
2. **Build**: `Cmd+B`
3. **Check for errors**: The "Cannot find in scope" errors should be resolved

## Note

All files in the same Xcode target (module) are automatically accessible to each other. You don't need `import` statements for files in the same target.

If errors persist after verifying target membership, try:
- Restarting Xcode
- Deleting Derived Data: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Reopening the workspace




