#!/usr/bin/env ruby

# Script to add all Genie and Profile migration files to Xcode project
# Requires: gem install xcodeproj

require 'xcodeproj'

project_path = File.join(__dir__, '..', 'Do.xcodeproj')
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.find { |t| t.name == 'Do' }
unless target
  puts "❌ Could not find 'Do' target"
  exit 1
end

# Find or create groups
def find_or_create_group(project, path)
  parts = path.split('/')
  group = project.main_group
  
  parts.each do |part|
    existing = group.children.find { |c| c.display_name == part && c.is_a?(Xcodeproj::Project::Object::PBXGroup) }
    if existing
      group = existing
    else
      group = group.new_group(part)
    end
  end
  
  group
end

# Files to add (relative to iOS/Do/)
files_to_add = [
  # Models
  'Features/Genie/Models/GenieModels.swift',
  'Features/Genie/Models/LLMModels.swift',
  'Features/Genie/Models/GenieAPIModels.swift',
  'Features/Genie/Models/AnalysisResponse.swift',
  'Features/Genie/Models/MeditationModels.swift',
  
  # Core Services - Genie
  'Core/Services/Genie/GenieAPIService.swift',
  'Core/Services/Genie/GenieConversationStoreService.swift',
  'Core/Services/Genie/GenieUserLearningService.swift',
  'Core/Services/Genie/GenieVoiceService.swift',
  'Core/Services/Genie/GenieVisionService.swift',
  'Core/Services/Genie/GenieMeditationService.swift',
  'Core/Services/Genie/VoiceRecordingService.swift',
  'Core/Services/Genie/RecipeStorageService.swift',
  'Core/Services/Genie/GenieConversationManager.swift',
  'Core/Services/Genie/GenieActionHandler.swift',
  'Core/Services/Genie/BarcodeService.swift',
  'Core/Services/Genie/GroceryListService.swift',
  'Core/Services/Genie/FoodImageAnalysisService.swift',
  
  # Auth Adapters
  'Core/Services/Auth/AWSCognitoAuth.swift',
  'Core/Services/UserPreferences.swift',
  'Core/Services/LocationManager.swift',
  
  # Profile ViewModels
  'Features/Profile/ViewModels/ProfileViewModel.swift',
  'Features/Profile/ViewModels/ProfileSettingsViewModel.swift',
  
  # Profile Views
  'Features/Profile/Views/ProfileSettingsView.swift',
  'Features/Profile/Views/ProfileSettingsHostingController.swift',
  
  # Genie Views
  'Features/Genie/Views/GenieView.swift',
  'Features/Genie/Views/SheetCoordinator.swift',
  'Features/Genie/Views/AttachmentMenuView.swift',
  'Features/Genie/Views/ConversationsListView.swift',
  'Features/Genie/Views/VoiceRecordingView.swift',
  'Features/Genie/Views/VideoResultsView.swift',
  'Features/Genie/Views/MealPlanView.swift',
  'Features/Genie/Views/FoodImageAnalysisView.swift',
  'Features/Genie/Views/MotivationView.swift',
  'Features/Genie/Views/AffirmationView.swift',
  'Features/Genie/Views/ManifestationView.swift',
  'Features/Genie/Views/GenieWorkoutPreviewView.swift',
  'Features/Genie/Views/RestaurantSearchView.swift',
  'Features/Genie/Views/MealSuggestionsView.swift',
  'Features/Genie/Views/SmartTokenUpsellView.swift',
  'Features/Genie/Views/TokenPurchaseView.swift',
  'Features/Genie/Views/SubscriptionUpgradeView.swift',
  'Features/Genie/Views/SubscriptionSuccessView.swift',
  'Features/Genie/Views/TokenBalanceWarningBanner.swift',
  'Features/Genie/Views/TokenTopUpView.swift',
  
  # Genie Views - Food
  'Features/Genie/Views/Food/FoodCameraView.swift',
  'Features/Genie/Views/Food/FridgeCameraView.swift',
  'Features/Genie/Views/Food/BarcodeScannerView.swift',
  
  # Genie Views - Equipment
  'Features/Genie/Views/Equipment/EquipmentCameraView.swift',
  'Features/Genie/Views/Equipment/EquipmentScannerView.swift',
  
  # Genie Views - Meditation
  'Features/Genie/Views/Meditation/MeditationPlayerView.swift',
  'Features/Genie/Views/Meditation/GuidedMeditationsView.swift',
  'Features/Genie/Views/Meditation/MeditationVisualizationView.swift',
  'Features/Genie/Views/Meditation/EnhancedMeditationVisualizationView.swift',
]

# Define base path
base_path = File.join(__dir__, '..')

# Dynamically find all Swift files in Genie Views subdirectories
genie_views_base = File.join(base_path, 'Features/Genie/Views')
if Dir.exist?(genie_views_base)
  ['Restaurant', 'Cookbook', 'Grocery', 'MealPlan', 'Shared'].each do |subdir|
    subdir_path = File.join(genie_views_base, subdir)
    if Dir.exist?(subdir_path)
      Dir.glob(File.join(subdir_path, '*.swift')).each do |file|
        relative_path = file.sub(base_path + '/', '')
        files_to_add << relative_path unless files_to_add.include?(relative_path)
      end
    end
  end
end

added_count = 0
skipped_count = 0
error_count = 0

files_to_add.each do |file_path|
  full_path = File.join(base_path, file_path)
  
  unless File.exist?(full_path)
    puts "⚠️  File not found: #{file_path}"
    skipped_count += 1
    next
  end
  
  # Determine group path
  dir_path = File.dirname(file_path)
  file_name = File.basename(file_path)
  
  # Create group structure
  group = find_or_create_group(project, dir_path)
  
  # Check if file already exists in project (check both files and groups)
  existing_ref = group.children.find { |f| 
    f.path == file_name || f.path == file_path
  }
  
  # ALWAYS remove existing reference to ensure clean slate and correct properties
  if existing_ref
    puts "🗑️  Removing existing reference for clean add: #{file_path}"
    
    # Remove from all build phases first
    target.build_phases.each do |phase|
      phase.files.each do |build_file|
        if build_file.file_ref == existing_ref
          phase.remove_file_reference(build_file)
        end
      end
    end
    
    group.remove_reference(existing_ref)
    existing_ref = nil
  end
  
  # Create new correct file reference manually
  file_ref = project.new(Xcodeproj::Project::Object::PBXFileReference)
  file_ref.name = file_name # Explicitly set name to basename
  file_ref.path = file_path # Set path to full relative path
  file_ref.source_tree = '<group>'
  file_ref.last_known_file_type = 'sourcecode.swift'
  group.children << file_ref
  
  # Add to target
  target.add_file_references([file_ref])
  
  # Add to compile sources phase
  compile_phase = target.build_phases.find { |bp| bp.is_a?(Xcodeproj::Project::Object::PBXSourcesBuildPhase) }
  if compile_phase && !compile_phase.files.any? { |f| f.file_ref == file_ref }
    compile_phase.add_file_reference(file_ref)
  end
  
  puts "✅ Added: #{file_path}"
  added_count += 1
rescue => e
  puts "❌ Error adding #{file_path}: #{e.message}"
  error_count += 1
end

# Save project
project.save

puts "\n📊 Summary:"
puts "   ✅ Added: #{added_count}"
puts "   ⏭️  Skipped: #{skipped_count}"
puts "   ❌ Errors: #{error_count}"
puts "\n✅ Project saved successfully!"

