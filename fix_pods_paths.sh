#!/bin/bash

echo "🔧 Fixing CocoaPods File List Paths"
echo "===================================="
echo ""

cd "$(dirname "$0")"

# Step 1: Verify we're in the right directory
if [ ! -f "Podfile" ]; then
    echo "❌ Error: Podfile not found. Are you in the ios directory?"
    exit 1
fi

echo "✅ Found Podfile"
echo ""

# Step 2: Check if Pods directory exists
if [ ! -d "Pods" ]; then
    echo "⚠️  Pods directory not found. Running pod install..."
    pod install
    echo ""
fi

# Step 3: Verify the xcfilelist files exist
INPUT_FILE="Pods/Target Support Files/Pods-Do/Pods-Do-frameworks-Debug-input-files.xcfilelist"
OUTPUT_FILE="Pods/Target Support Files/Pods-Do/Pods-Do-frameworks-Debug-output-files.xcfilelist"

if [ -f "$INPUT_FILE" ] && [ -f "$OUTPUT_FILE" ]; then
    echo "✅ File list files exist:"
    echo "   • $INPUT_FILE"
    echo "   • $OUTPUT_FILE"
    echo ""
else
    echo "❌ File list files missing!"
    echo "   Running pod install to regenerate..."
    pod install
    echo ""
fi

# Step 4: Reinstall pods to fix any path issues
echo "🔄 Reinstalling CocoaPods to fix paths..."
echo ""

# Clean first
echo "1️⃣ Cleaning old Pods..."
rm -rf Pods/
rm -f Podfile.lock

# Reinstall
echo "2️⃣ Reinstalling Pods..."
pod install

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Pods reinstalled successfully!"
    echo ""
    echo "3️⃣ Opening workspace..."
    killall Xcode 2>/dev/null
    sleep 1
    open Do.xcworkspace
    
    echo ""
    echo "✅ Done!"
    echo ""
    echo "IMPORTANT:"
    echo "  • Verify Xcode title shows 'Do.xcworkspace'"
    echo "  • Clean Build: Cmd + Shift + K"
    echo "  • Build: Cmd + B"
    echo ""
else
    echo ""
    echo "❌ pod install failed. Check the error messages above."
    echo ""
    exit 1
fi








