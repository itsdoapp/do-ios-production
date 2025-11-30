#!/bin/bash

# Script to add all Genie migration files to Xcode project
# This script should be run from the iOS/Do directory

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$PROJECT_DIR/Do.xcodeproj/project.pbxproj"

echo "🔧 Adding Genie migration files to Xcode project..."
echo "📁 Project directory: $PROJECT_DIR"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if file exists
check_file() {
    if [ ! -f "$1" ]; then
        echo -e "${YELLOW}⚠️  File not found: $1${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Found: $1${NC}"
        return 0
    fi
}

# List of files to add (relative to PROJECT_DIR)
FILES=(
    # Models
    "Features/Genie/Models/GenieModels.swift"
    "Features/Genie/Models/LLMModels.swift"
    "Features/Genie/Models/GenieAPIModels.swift"
    "Features/Genie/Models/AnalysisResponse.swift"
    "Features/Genie/Models/MeditationModels.swift"
    
    # Core Services
    "Core/Services/Genie/GenieAPIService.swift"
    "Core/Services/Genie/GenieConversationStoreService.swift"
    "Core/Services/Genie/GenieUserLearningService.swift"
    "Core/Services/Genie/GenieVoiceService.swift"
    "Core/Services/Genie/GenieVisionService.swift"
    "Core/Services/Genie/GenieMeditationService.swift"
    "Core/Services/Genie/VoiceRecordingService.swift"
    "Core/Services/Genie/RecipeStorageService.swift"
    
    # Auth Adapters
    "Core/Services/Auth/AWSCognitoAuth.swift"
    "Core/Services/UserPreferences.swift"
    "Core/Services/LocationManager.swift"
)

echo ""
echo "📋 Checking files..."
echo ""

MISSING_FILES=()
for file in "${FILES[@]}"; do
    full_path="$PROJECT_DIR/$file"
    if ! check_file "$full_path"; then
        MISSING_FILES+=("$file")
    fi
done

echo ""
if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Missing files (${#MISSING_FILES[@]}):${NC}"
    for file in "${MISSING_FILES[@]}"; do
        echo "   - $file"
    done
    echo ""
    echo "These files need to be created before adding to Xcode."
    echo ""
fi

echo "📝 Note: This script only checks for file existence."
echo "To actually add files to Xcode project, use Xcode's 'Add Files to Do' option,"
echo "or use a tool like 'xcodeproj' gem to programmatically add files."
echo ""
echo "Alternatively, you can:"
echo "1. Open Do.xcodeproj in Xcode"
echo "2. Right-click on the appropriate group (e.g., 'Features/Genie/Models')"
echo "3. Select 'Add Files to Do...'"
echo "4. Select the files and ensure 'Copy items if needed' is unchecked"
echo "5. Ensure 'Create groups' is selected"
echo "6. Ensure the correct target is selected"
echo ""

# Generate a list of files for manual addition
echo "📄 Files to add manually:"
echo ""
for file in "${FILES[@]}"; do
    full_path="$PROJECT_DIR/$file"
    if [ -f "$full_path" ]; then
        echo "   $file"
    fi
done

echo ""
echo "✅ Script complete!"


