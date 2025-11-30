# Correct Build Order for Watch App

## The Problem

"Multiple commands produce" errors often occur when trying to build the watch app before the iOS app, or when the iOS app's embed configuration is incorrect.

## ✅ Correct Build Order

### 1. **Build iOS App First**
```
Scheme: Do
Destination: iPhone Simulator
Action: Build (Cmd+B)
```

The iOS app must build successfully **before** building the watch app because:
- The watch app is embedded in the iOS app
- iOS app dependencies must be resolved first
- Build system needs to establish the correct target relationships

### 2. **Then Build Watch App**
```
Scheme: Do Watch App  
Destination: Apple Watch Simulator
Action: Build (Cmd+B) or Run (Cmd+R)
```

## 🔧 Fixed Issues

The `fix_ios_watch_embedding.rb` script fixed:
- ✅ Removed duplicate watch embed phases from iOS app
- ✅ Ensured watch app is embedded only once
- ✅ Verified watch app dependency is correct
- ✅ Set proper watch target build settings

## 📋 Step-by-Step Build Process

### Initial Setup (One Time)
```bash
cd /Users/mikimeseret/Documents/DoIOS/iOS/Do
ruby fix_ios_watch_embedding.rb
rm -rf ~/Library/Developer/Xcode/DerivedData/Do-*
```

### Every Time You Build

1. **Quit Xcode** (Cmd+Q) if it's open

2. **Open Workspace**
   ```bash
   open Do.xcworkspace
   ```

3. **Clean Build Folder**
   - Product → Clean Build Folder (Shift+Cmd+K)

4. **Build iOS App**
   - Select **"Do"** scheme
   - Choose **iPhone Simulator** as destination  
   - Press **Cmd+B** to build
   - Wait for build to complete ✅

5. **Build Watch App**
   - Select **"Do Watch App"** scheme
   - Choose **Apple Watch Simulator** as destination
   - Press **Cmd+B** to build
   - Or press **Cmd+R** to build and run

## ⚠️ Common Mistakes

### ❌ Building Watch App First
```
ERROR: Multiple commands produce .../Do Watch App.app/Do Watch App
```
**Solution:** Always build iOS app first

### ❌ Using .xcodeproj Instead of .xcworkspace
```
ERROR: Library not found / Framework not found
```
**Solution:** Always open `Do.xcworkspace` (because of CocoaPods)

### ❌ Not Cleaning After Project Changes
```
ERROR: Old cached files / Stale references
```
**Solution:** Clean build folder (Shift+Cmd+K) after project changes

## 🎯 Quick Build Commands (Terminal)

If you prefer command line:

```bash
# Build iOS app
xcodebuild -workspace Do.xcworkspace \
           -scheme Do \
           -sdk iphonesimulator \
           -destination 'platform=iOS Simulator,name=iPhone 15' \
           clean build

# Then build watch app  
xcodebuild -workspace Do.xcworkspace \
           -scheme "Do Watch App" \
           -sdk watchsimulator \
           -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
           clean build
```

## 🔍 Verify Setup

Check that your iOS app's build phases include:
1. **Dependencies** - Watch app listed as dependency
2. **Compile Sources** - iOS source files
3. **Link Binary With Libraries** - Frameworks
4. **Copy Bundle Resources** - Assets
5. **Embed Watch Content** - Watch app (ONLY ONCE)

Check in Xcode:
1. Click blue project icon
2. Select "Do" target
3. Go to "Build Phases" tab
4. Verify "Embed Watch Content" phase exists and has watch app

## ✅ Success Indicators

Build succeeded when you see:
```
** BUILD SUCCEEDED **
```

Watch app running when you see:
- Simulator launches
- Watch app appears on watch screen
- Workout list view displays

## 🆘 If Build Still Fails

Try this nuclear option:

```bash
# 1. Delete all derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 2. Delete all build folders
cd /Users/mikimeseret/Documents/DoIOS/iOS/Do
rm -rf build/

# 3. Clean pods
cd /Users/mikimeseret/Documents/DoIOS/iOS/Do
pod deintegrate
pod install

# 4. Reopen and build
open Do.xcworkspace
```

Then follow the correct build order above.

