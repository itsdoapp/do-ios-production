#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Do.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔍 Complete watch target analysis and rebuild"

# Find all targets
puts "\n📋 All targets in project:"
project.targets.each_with_index do |target, idx|
  puts "  #{idx + 1}. #{target.name} (#{target.product_type})"
end

# Find watch targets (there should be only ONE)
watch_targets = project.targets.select { |t| 
  t.name.include?('Watch') || t.product_type == 'com.apple.product-type.application.watchapp2'
}

puts "\n🔍 Found #{watch_targets.count} watch target(s):"
watch_targets.each do |target|
  puts "  - #{target.name}"
end

if watch_targets.count > 1
  puts "\n⚠️  CRITICAL: Multiple watch targets found!"
  puts "This is likely causing the duplicate commands error."
  puts "\nRemoving all watch targets and rebuilding..."
  
  watch_targets.each do |target|
    puts "  Removing: #{target.name}"
    target.remove_from_project
  end
  
  watch_targets = []
end

# Find iOS target
ios_target = project.targets.find { |t| t.name == 'Do' }
if ios_target.nil?
  puts "❌ Could not find iOS target"
  exit 1
end

puts "\n✅ iOS target: #{ios_target.name}"
ios_bundle_id = ios_target.build_configurations.first.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] || 'com.do.fitness'
watch_bundle_id = "#{ios_bundle_id}.watchapp"

# Remove all watch-related dependencies and embed phases from iOS target
puts "\n🧹 Cleaning iOS target..."
ios_target.dependencies.select { |d| d.target&.name&.include?('Watch') }.each do |dep|
  ios_target.dependencies.delete(dep)
end

ios_target.build_phases.select { |p| 
  p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) && 
  (p.name&.include?('Watch') || p.dst_path&.include?('Watch'))
}.each do |phase|
  ios_target.build_phases.delete(phase)
end

puts "  ✅ Removed all watch dependencies and embed phases"

# Create fresh watch target
puts "\n🆕 Creating fresh watch target..."
watch_target = project.new_target(:watch2_app, 'Do Watch App', :watchos, '8.0')

# Configure watch target
puts "⚙️  Configuring watch target..."
watch_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = watch_bundle_id
  config.build_settings['PRODUCT_NAME'] = 'Do Watch App'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '4'
  config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '8.0'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['ENABLE_PREVIEWS'] = 'YES'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['INFOPLIST_FILE'] = 'Do Watch App/Info.plist'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = ios_target.build_configurations.first.build_settings['DEVELOPMENT_TEAM']
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'YES'
  config.build_settings['WKCompanionAppBundleIdentifier'] = ios_bundle_id
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Do Watch App/DoWatchApp.entitlements'
  config.build_settings['PRODUCT_MODULE_NAME'] = 'DoWatchApp'
end

puts "  ✅ Configured bundle ID: #{watch_bundle_id}"

# Add watch app group
watch_app_group = project.main_group.find_subpath('Do Watch App', true)
watch_app_group.set_source_tree('<group>')

# Add all Swift files
puts "\n📁 Adding source files..."
swift_files = Dir.glob('Do Watch App/**/*.swift')
swift_files.each do |file_path|
  file_ref = watch_app_group.new_reference(file_path)
  watch_target.source_build_phase.add_file_reference(file_ref)
end
puts "  ✅ Added #{swift_files.count} Swift files"

# Add Assets
assets_path = 'Do Watch App/Assets.xcassets'
if File.exist?(assets_path)
  assets_ref = watch_app_group.new_reference(assets_path)
  assets_ref.last_known_file_type = 'folder.assetcatalog'
  watch_target.resources_build_phase.add_file_reference(assets_ref)
  puts "  ✅ Added Assets.xcassets"
end

# Add dependency and embed phase to iOS target
puts "\n🔗 Linking watch app to iOS app..."
ios_target.add_dependency(watch_target)
puts "  ✅ Added dependency"

embed_phase = ios_target.new_copy_files_build_phase('Embed Watch Content')
embed_phase.symbol_dst_subfolder_spec = :products_directory
embed_phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'

watch_product_ref = watch_target.product_reference
build_file = embed_phase.add_file_reference(watch_product_ref)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
puts "  ✅ Added embed phase"

# Verify build phases
puts "\n📋 Watch target build phases:"
watch_target.build_phases.each_with_index do |phase, idx|
  puts "  #{idx + 1}. #{phase.display_name} (#{phase.files.count} files)"
end

puts "\n📋 iOS target watch-related phases:"
ios_target.build_phases.select { |p| 
  p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
}.each do |phase|
  puts "  - #{phase.name}: #{phase.files.count} file(s)"
end

# Save
puts "\n💾 Saving project..."
project.save

puts "\n✅ SUCCESS! Watch target completely rebuilt."
puts ""
puts "🎯 FINAL STEPS (CRITICAL):"
puts "1. Quit Xcode if open (Cmd+Q)"
puts "2. Run: sudo rm -rf ~/Library/Developer/Xcode/DerivedData/*"
puts "3. Run: rm -rf ~/Library/Caches/org.swift.swiftpm"
puts "4. Open: open Do.xcworkspace"
puts "5. Product → Clean Build Folder (Shift+Cmd+K)"
puts "6. Build 'Do' scheme first"
puts "7. Then build 'Do Watch App' scheme"
puts ""

