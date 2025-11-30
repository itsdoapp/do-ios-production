#!/bin/bash

echo "🚀 Setting up Do - Clean iOS Project"
echo ""

# Check if xcodegen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "❌ xcodegen not found. Installing..."
    brew install xcodegen
fi

# Check if CocoaPods is installed
if ! command -v pod &> /dev/null; then
    echo "❌ CocoaPods not found. Installing..."
    sudo gem install cocoapods
fi

echo "📦 Installing CocoaPods dependencies..."
pod install

echo ""
echo "🏗️  Generating Xcode project..."
xcodegen generate

echo ""
echo "✅ Setup complete!"
echo ""
echo "📝 Next steps:"
echo "1. Open Do.xcworkspace"
echo "2. Add Cognito Client ID to Constants.swift"
echo "3. Add GoogleService-Info.plist for Google Sign In"
echo "4. Build and run!"
echo ""
