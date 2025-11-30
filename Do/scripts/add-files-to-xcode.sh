#!/bin/bash

# Script to add all Genie and Profile migration files to Xcode project
# This script uses Ruby xcodeproj gem to programmatically add files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUBY_SCRIPT="$SCRIPT_DIR/add-files-to-xcode.rb"

echo "🔧 Adding Genie and Profile files to Xcode project..."
echo "📁 Project directory: $PROJECT_DIR"
echo ""

# Check if xcodeproj gem is installed
if ! gem list xcodeproj | grep -q xcodeproj; then
    echo "📦 Installing xcodeproj gem..."
    gem install xcodeproj
    echo ""
fi

# Check if Ruby script exists
if [ ! -f "$RUBY_SCRIPT" ]; then
    echo "❌ Ruby script not found: $RUBY_SCRIPT"
    exit 1
fi

# Run Ruby script
echo "🚀 Running Ruby script to add files..."
cd "$PROJECT_DIR"
ruby "$RUBY_SCRIPT"

echo ""
echo "✅ Done! Files have been added to Xcode project."
echo "💡 Open Do.xcodeproj in Xcode to verify files are added correctly."


