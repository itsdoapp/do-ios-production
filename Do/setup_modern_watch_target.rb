#!/usr/bin/env ruby
require 'xcodeproj'
require 'fileutils'

# Define paths relative to this script
project_path = 'Do.xcodeproj'
watch_app_dir = 'Do Watch App'

puts "📱 Opening project: #{project_path}"
project = Xcodeproj::Project.open(project_path)

# 1. Remove existing watch targets to start clean
puts "🗑️ Removing existing watch targets..."
project.targets.dup.each do |target|
  if target.name.include?('Watch')
    puts "   - Removing target: #{target.name}"
    target.remove_from_project
  end
end

# Remove products related to watch
project.products_group.children.dup.each do |product|
  if product.name.to_s.include?('Watch')
    puts "   - Removing product: #{product.name}"
    product.remove_from_project
  end
end

# 2. Create the new Single Target Watch App
target_name = "Do Watch App"
puts "🆕 Creating new Single-Target Watch App: #{target_name}"

# Create the target
# :application type with :watchos platform creates a standard application target configured for watchOS
watch_target = project.new_target(:application, target_name, :watchos, '10.0')

# 3. Configure Build Settings
puts "⚙️ Configuring build settings..."
watch_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.itsdoapp.doios.watchapp'
  config.build_settings['SDKROOT'] = 'watchos'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '4' # 4 is Watch
  config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '10.0'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['INFOPLIST_KEY_WKApplication'] = 'YES' # Critical for single target apps
  config.build_settings['INFOPLIST_KEY_WKCompanionAppBundleIdentifier'] = 'com.itsdoapp.doios'
  config.build_settings['INFOPLIST_KEY_UISupportedInterfaceOrientations'] = 'UIInterfaceOrientationPortrait'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ENABLE_PREVIEWS'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  
  # Point to the entitlements file if it exists
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Do Watch App/DoWatchApp.entitlements'
end

# 4. Add Files
puts "📂 Adding files to target..."

# Create a group for the watch app if it doesn't exist
group = project.main_group['Do Watch App']
unless group
  # If the group exists as a file ref (weird state), remove it
  existing_ref = project.main_group.find_file_by_path('Do Watch App')
  existing_ref.remove_from_project if existing_ref
  
  # Create new group
  group = project.main_group.new_group('Do Watch App', 'Do Watch App')
end

# Helper to recursively add files
def add_files_to_group(path, parent_group, target)
  Dir.glob("#{path}/*").each do |item|
    next if item.include?('.DS_Store')
    
    name = File.basename(item)
    
    if File.directory?(item) && !item.end_with?('.xcassets')
       # Create subgroup
       subgroup = parent_group.children.find { |c| c.isa == 'PBXGroup' && c.name == name } || parent_group.new_group(name, name)
       add_files_to_group(item, subgroup, target)
    else
       # Add file
       file_ref = parent_group.find_file_by_path(name) || parent_group.new_file(name)
       
       if item.end_with?('.swift')
         target.source_build_phase.add_file_reference(file_ref)
         # puts "   + Added source: #{name}"
       elsif item.end_with?('.xcassets')
         target.resources_build_phase.add_file_reference(file_ref)
         puts "   + Added resource: #{name}"
       end
    end
  end
end

# Add contents of Do Watch App directory
# We rely on the group pointing to the folder 'Do Watch App'
# But since we might have flattened it or not, let's just iterate the directory
add_files_to_group(watch_app_dir, group, watch_target)

# 5. Add Specific Shared Files (located outside Do Watch App folder)
puts "🔗 Adding shared files..."
shared_files = [
  'Features/Track/Auth/WatchAuthService.swift',
  'Features/Track/Models/GymWorkoutMetrics.swift',
  'Features/Track/Models/WorkoutMetrics.swift'
]

shared_files.each do |path|
  # Try to find existing reference in the project
  file_ref = nil
  project.files.each do |f|
    if f.path && f.path.end_with?(path)
        file_ref = f
        break
    end
  end

  # If not found by exact path match, look by name
  if file_ref.nil?
      name = File.basename(path)
      project.files.each do |f|
        if f.name == name || (f.path && File.basename(f.path) == name)
            file_ref = f
            break
        end
      end
  end

  if file_ref
    watch_target.source_build_phase.add_file_reference(file_ref)
    puts "   + Linked shared file: #{file_ref.display_name}"
  else
    puts "   ⚠️ Could not find reference for #{path}. Please add manually."
  end
end

# 6. Embed in iOS App
puts "📦 Configuring iOS App embedding..."
ios_target = project.targets.find { |t| t.name == 'Do' }
if ios_target
  # Remove old embed phases
  ios_target.build_phases.dup.each do |phase|
    if phase.display_name.include?('Embed Watch Content') || phase.display_name.include?('Embed Watch')
      phase.remove_from_project
    end
  end

  # Add new Embed Watch Content phase
  # For single target watch apps (watchOS 7+), we embed the app directly into the iOS app
  embed_phase = ios_target.new_copy_files_build_phase("Embed Watch Content")
  embed_phase.dst_path = "$(CONTENTS_FOLDER_PATH)/Watch"
  embed_phase.dst_subfolder_spec = "16" # Wrapper/Products Directory
  embed_phase.add_file_reference(watch_target.product_reference)
  
  puts "   + Added Do Watch App to iOS Embed Watch Content phase"
else
  puts "❌ Could not find iOS target 'Do'"
end

project.save
puts "✅ Project saved. Setup complete."

