#!/bin/bash

echo "🔧 CocoaPods Fix Script"
echo "======================="
echo ""

# Close Xcode
echo "1️⃣ Closing Xcode..."
killall Xcode 2>/dev/null
sleep 2

# Navigate to project
cd "$(dirname "$0")"
echo "2️⃣ Current directory: $(pwd)"
echo ""

# Check for workspace
if [ -d "Do.xcworkspace" ]; then
    echo "✅ Do.xcworkspace found"
else
    echo "❌ Do.xcworkspace NOT found"
    exit 1
fi

# Check for Pods
if [ -d "Pods" ]; then
    echo "✅ Pods directory found"
else
    echo "❌ Pods directory NOT found - run 'pod install'"
    exit 1
fi

echo ""
echo "3️⃣ Opening Do.xcworkspace in Xcode..."
open Do.xcworkspace

echo ""
echo "✅ Done!"
echo ""
echo "IMPORTANT:"
echo "  • Verify Xcode title shows 'Do.xcworkspace'"
echo "  • Clean Build: Cmd + Shift + K"
echo "  • Build: Cmd + B"
echo ""
