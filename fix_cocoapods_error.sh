#!/bin/bash

echo "🔧 CocoaPods File List Error - Complete Fix"
echo "=========================================="
echo ""

cd "$(dirname "$0")"

# Step 1: Close Xcode
echo "1️⃣ Closing Xcode..."
killall Xcode 2>/dev/null
sleep 2

# Step 2: Clean Derived Data
echo "2️⃣ Cleaning Derived Data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Do-* 2>/dev/null
echo "   ✅ Derived data cleaned"
echo ""

# Step 3: Verify files exist
echo "3️⃣ Verifying CocoaPods files..."
INPUT_FILE="Pods/Target Support Files/Pods-Do/Pods-Do-frameworks-Debug-input-files.xcfilelist"
OUTPUT_FILE="Pods/Target Support Files/Pods-Do/Pods-Do-frameworks-Debug-output-files.xcfilelist"

if [ -f "$INPUT_FILE" ] && [ -f "$OUTPUT_FILE" ]; then
    echo "   ✅ File list files exist"
    echo "   • $INPUT_FILE"
    echo "   • $OUTPUT_FILE"
    echo ""
else
    echo "   ⚠️  Files missing - reinstalling Pods..."
    rm -rf Pods/ Podfile.lock
    pod install
    echo ""
fi

# Step 4: Verify workspace exists
if [ ! -d "Do.xcworkspace" ]; then
    echo "   ⚠️  Workspace missing - regenerating..."
    pod install
    echo ""
fi

# Step 5: Open workspace
echo "4️⃣ Opening Do.xcworkspace..."
open Do.xcworkspace

echo ""
echo "✅ Fix applied!"
echo ""
echo "📋 NEXT STEPS IN XCODE:"
echo ""
echo "1. Verify title bar shows: 'Do — Do.xcworkspace'"
echo "   (NOT 'Do.xcodeproj')"
echo ""
echo "2. Check Build Settings:"
echo "   • Select 'Do' project → 'Do' target"
echo "   • Build Settings tab"
echo "   • Search for 'PODS_ROOT'"
echo "   • Should be: \$(SRCROOT)/Pods"
echo "   • If empty, set it manually"
echo ""
echo "3. Clean and Build:"
echo "   • Clean: Cmd + Shift + K"
echo "   • Build: Cmd + B"
echo ""
echo "📖 For detailed instructions, see: COCOAPODS_PATH_FIX.md"
echo ""








