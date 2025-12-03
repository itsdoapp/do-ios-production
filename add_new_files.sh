#!/bin/bash

# Script to add newly created Swift files to Xcode project
# Run this script from the ios directory

echo "🔧 Adding newly created files to Xcode project..."

# List of new files that need to be added
NEW_FILES=(
    "Do/Features/Track/Models/RunAnalysisHelpers.swift"
    "Do/Features/Track/Extensions/UnitSpeedExtensions.swift"
    "Do/Core/Services/WaterIntakeService.swift"
    "Do/Features/Track/Models/BikingTypes.swift"
    "Do/Features/Track/Managers/RunningWorkoutManager.swift"
    "Do/Features/Track/Models/GymInsightsModels.swift"
)

# Check if files exist
echo "📋 Checking files..."
for file in "${NEW_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ Found: $file"
    else
        echo "❌ Missing: $file"
    fi
done

echo ""
echo "⚠️  MANUAL STEP REQUIRED:"
echo "Please open Xcode and add these files to your project:"
echo ""
for file in "${NEW_FILES[@]}"; do
    echo "  • $file"
done
echo ""
echo "To add files in Xcode:"
echo "1. Right-click on the appropriate group in Project Navigator"
echo "2. Select 'Add Files to \"Do\"...'"
echo "3. Navigate to and select the file"
echo "4. Make sure 'Add to targets: Do' is checked"
echo "5. Click 'Add'"
echo ""
echo "Or drag and drop the files from Finder into the Xcode Project Navigator."
echo ""





