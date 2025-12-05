#!/bin/bash

# Watch App Configuration Checker
# This script helps diagnose why the watch app isn't installing on device

echo "🔍 Checking Watch App Configuration..."
echo ""

# Check if we're in the right directory
if [ ! -f "Do.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Must run from project root directory"
    exit 1
fi

echo "✅ Found Xcode project"
echo ""

# Check bundle identifiers
echo "📦 Bundle Identifiers:"
ios_bundle=$(grep -A 5 "Do.*Debug" Do.xcodeproj/project.pbxproj | grep "PRODUCT_BUNDLE_IDENTIFIER" | head -1 | sed 's/.*= //;s/;//')
watch_bundle=$(grep -A 5 "Do Watch App.*Debug" Do.xcodeproj/project.pbxproj | grep "PRODUCT_BUNDLE_IDENTIFIER" | head -1 | sed 's/.*= //;s/;//')

echo "  iOS App: $ios_bundle"
echo "  Watch App: $watch_bundle"

if [[ "$watch_bundle" == *"$ios_bundle"* ]]; then
    echo "  ✅ Watch bundle ID follows correct pattern"
else
    echo "  ⚠️  Watch bundle ID should be: ${ios_bundle}.watchapp"
fi
echo ""

# Check deployment target
echo "📱 Deployment Targets:"
watch_deployment=$(grep -A 5 "Do Watch App.*Debug" Do.xcodeproj/project.pbxproj | grep "WATCHOS_DEPLOYMENT_TARGET" | head -1 | sed 's/.*= //;s/;//')
echo "  Watch App: watchOS $watch_deployment"
echo "  ⚠️  Ensure your Apple Watch is running watchOS $watch_deployment or later"
echo ""

# Check Info.plist
echo "📄 Info.plist Configuration:"
if [ -f "Do/Do Watch App/Info.plist" ]; then
    companion_id=$(grep -A 1 "WKCompanionAppBundleIdentifier" "Do/Do Watch App/Info.plist" | tail -1 | sed 's/.*<string>//;s/<\/string>//')
    wk_application=$(grep -A 1 "WKApplication" "Do/Do Watch App/Info.plist" | tail -1 | sed 's/.*<true\/>//;s/.*<false\/>//')
    
    echo "  WKCompanionAppBundleIdentifier: $companion_id"
    if [ "$companion_id" == "$ios_bundle" ]; then
        echo "  ✅ Companion app ID matches iOS bundle ID"
    else
        echo "  ⚠️  Should match iOS bundle ID: $ios_bundle"
    fi
    
    if grep -q "<true/>" "Do/Do Watch App/Info.plist" | grep -q "WKApplication"; then
        echo "  ✅ WKApplication is set to true"
    else
        echo "  ⚠️  WKApplication should be true"
    fi
else
    echo "  ❌ Info.plist not found!"
fi
echo ""

# Check embedding
echo "🔗 Watch App Embedding:"
if grep -q "Embed Watch Content" Do.xcodeproj/project.pbxproj; then
    echo "  ✅ Embed Watch Content phase exists"
    if grep -q "Do Watch App.app" Do.xcodeproj/project.pbxproj | grep -q "Embed Watch"; then
        echo "  ✅ Watch app is included in embed phase"
    else
        echo "  ⚠️  Watch app may not be in embed phase"
    fi
else
    echo "  ❌ Embed Watch Content phase not found!"
fi
echo ""

# Check target dependency
echo "🔗 Target Dependencies:"
if grep -q "Do Watch App" Do.xcodeproj/project.pbxproj | grep -q "PBXTargetDependency"; then
    echo "  ✅ Watch app is a dependency of iOS app"
else
    echo "  ⚠️  Watch app may not be a dependency (this is OK for development)"
fi
echo ""

# Check entitlements
echo "🔐 Entitlements:"
if [ -f "Do/Do Watch App/DoWatchApp.entitlements" ]; then
    echo "  ✅ Entitlements file exists"
    if grep -q "group.com.do.fitness" "Do/Do Watch App/DoWatchApp.entitlements"; then
        echo "  ✅ App Groups configured"
    else
        echo "  ⚠️  App Groups may not be configured"
    fi
else
    echo "  ⚠️  Entitlements file not found"
fi
echo ""

# Summary
echo "📋 Summary & Recommendations:"
echo ""
echo "1. In Xcode, verify:"
echo "   - Watch App Target → Signing & Capabilities"
echo "     • Development Team matches iOS app"
echo "     • Code signing is automatic"
echo ""
echo "2. Build and Run:"
echo "   - Select 'Do' scheme (iOS app)"
echo "   - Choose your iPhone as destination"
echo "   - Build and Run (⌘R)"
echo "   - Watch app should install automatically"
echo ""
echo "3. If still not working:"
echo "   - Clean Build Folder (⇧⌘K)"
echo "   - Delete Derived Data"
echo "   - Rebuild"
echo ""
echo "4. Check Watch App on iPhone:"
echo "   - Open Watch app on iPhone"
echo "   - My Watch tab → Find 'Do'"
echo "   - Tap 'Install' if needed"
echo ""





