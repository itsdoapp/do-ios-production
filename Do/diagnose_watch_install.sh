#!/bin/bash

# Watch App Installation Diagnostic Script
# Run this to check your watch app configuration

echo "🔍 Watch App Installation Diagnostic"
echo "====================================="
echo ""

# Check if we're in the right directory
if [ ! -f "Do.xcodeproj/project.pbxproj" ] && [ ! -f "Do/Do.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Must run from project root (where Do.xcodeproj is located)"
    exit 1
fi

# Set project path
if [ -f "Do/Do.xcodeproj/project.pbxproj" ]; then
    PROJECT_FILE="Do/Do.xcodeproj/project.pbxproj"
    INFO_PLIST="Do/Do Watch App/Info.plist"
    ENTITLEMENTS="Do/Do Watch App/DoWatchApp.entitlements"
else
    PROJECT_FILE="Do.xcodeproj/project.pbxproj"
    INFO_PLIST="Do Watch App/Info.plist"
    ENTITLEMENTS="Do Watch App/DoWatchApp.entitlements"
fi

echo "✅ Found Xcode project"
echo ""

# Check bundle identifiers
echo "📦 Bundle Identifiers:"
ios_bundle=$(grep -A 10 '"Do".*Debug' "$PROJECT_FILE" | grep "PRODUCT_BUNDLE_IDENTIFIER" | head -1 | sed 's/.*= //;s/;//' | tr -d ' ')
watch_bundle=$(grep -A 10 '"Do Watch App".*Debug' "$PROJECT_FILE" | grep "PRODUCT_BUNDLE_IDENTIFIER" | head -1 | sed 's/.*= //;s/;//' | tr -d ' ')

echo "  iOS App: $ios_bundle"
echo "  Watch App: $watch_bundle"

if [[ "$watch_bundle" == *"$ios_bundle"* ]]; then
    echo "  ✅ Watch bundle ID follows correct pattern"
else
    echo "  ❌ Watch bundle ID should be: ${ios_bundle}.watchapp"
fi
echo ""

# Check deployment target
echo "📱 Deployment Targets:"
watch_deployment=$(grep -A 10 '"Do Watch App".*Debug' "$PROJECT_FILE" | grep "WATCHOS_DEPLOYMENT_TARGET" | head -1 | sed 's/.*= //;s/;//' | tr -d ' ')
echo "  Watch App: watchOS $watch_deployment"
echo "  ⚠️  Ensure your Apple Watch is running watchOS $watch_deployment or later"
echo ""

# Check SKIP_INSTALL
echo "🔧 Build Settings:"
skip_install=$(grep -A 10 '"Do Watch App".*Debug' "$PROJECT_FILE" | grep "SKIP_INSTALL" | head -1 | sed 's/.*= //;s/;//' | tr -d ' ')
if [ "$skip_install" == "NO" ]; then
    echo "  ✅ SKIP_INSTALL = NO (correct)"
else
    echo "  ❌ SKIP_INSTALL = $skip_install (should be NO)"
fi
echo ""

# Check Info.plist
echo "📄 Info.plist Configuration:"
if [ -f "$INFO_PLIST" ]; then
    companion_id=$(grep -A 1 "WKCompanionAppBundleIdentifier" "$INFO_PLIST" | tail -1 | sed 's/.*<string>//;s/<\/string>//' | tr -d ' ')
    wk_application=$(grep -A 1 "WKApplication" "$INFO_PLIST" | tail -1)
    
    echo "  WKCompanionAppBundleIdentifier: $companion_id"
    if [ "$companion_id" == "$ios_bundle" ]; then
        echo "  ✅ Companion app ID matches iOS bundle ID"
    else
        echo "  ❌ Should match iOS bundle ID: $ios_bundle"
    fi
    
    if echo "$wk_application" | grep -q "<true/>"; then
        echo "  ✅ WKApplication is set to true"
    else
        echo "  ❌ WKApplication should be true"
    fi
else
    echo "  ❌ Info.plist not found!"
fi
echo ""

# Check embedding
echo "🔗 Watch App Embedding:"
if grep -q "Embed Watch Content" "$PROJECT_FILE"; then
    echo "  ✅ Embed Watch Content phase exists"
    if grep -q "Do Watch App.app" "$PROJECT_FILE" | grep -q "Embed Watch"; then
        echo "  ✅ Watch app is included in embed phase"
    else
        echo "  ⚠️  Watch app may not be in embed phase"
    fi
else
    echo "  ❌ Embed Watch Content phase not found!"
fi
echo ""

# Check development team
echo "👥 Development Team:"
ios_team=$(grep -A 10 '"Do".*Debug' "$PROJECT_FILE" | grep "DEVELOPMENT_TEAM" | head -1 | sed 's/.*= //;s/;//' | tr -d ' ')
watch_team=$(grep -A 10 '"Do Watch App".*Debug' "$PROJECT_FILE" | grep "DEVELOPMENT_TEAM" | head -1 | sed 's/.*= //;s/;//' | tr -d ' ')

if [ -n "$ios_team" ] && [ -n "$watch_team" ]; then
    echo "  iOS App Team: $ios_team"
    echo "  Watch App Team: $watch_team"
    if [ "$ios_team" == "$watch_team" ]; then
        echo "  ✅ Both targets use the same team"
    else
        echo "  ❌ Teams don't match! They must be the same"
    fi
else
    echo "  ⚠️  Could not determine development teams"
fi
echo ""

# Summary
echo "📋 Quick Fix Checklist:"
echo ""
echo "1. In Xcode:"
echo "   - Select 'Do Watch App' target"
echo "   - Signing & Capabilities → Verify Development Team matches iOS app"
echo "   - Ensure 'Automatically manage signing' is checked"
echo ""
echo "2. Build Process:"
echo "   - Select 'Do' scheme (NOT 'Do Watch App' scheme)"
echo "   - Choose your iPhone as destination"
echo "   - Build and Run (⌘R)"
echo ""
echo "3. If still not working:"
echo "   - Clean Build Folder (⇧⌘K)"
echo "   - Delete Derived Data"
echo "   - Ensure both iPhone and Watch are unlocked"
echo "   - Check Watch app on iPhone → My Watch → Do → Install"
echo ""
echo "4. Verify Watch OS Version:"
echo "   - On Apple Watch: Settings → General → About"
echo "   - Must be watchOS $watch_deployment or later"
echo ""

