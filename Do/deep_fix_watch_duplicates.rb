#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Do.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔍 Deep analysis of project: #{project_path}"

# Find the watch target
watch_target = project.targets.find { |t| t.name == 'Do Watch App' }
if watch_target.nil?
  puts "❌ Could not find 'Do Watch App' target"
  exit 1
end

puts "✅ Found watch target: #{watch_target.name}"

# Print all build phases
puts "\n📋 Current build phases:"
watch_target.build_phases.each_with_index do |phase, index|
  puts "  #{index + 1}. #{phase.class.name.split('::').last} - #{phase.display_name}"
  if phase.respond_to?(:files)
    puts "     Files: #{phase.files.count}"
  end
end

# Check for duplicate compile sources phases
puts "\n🔍 Checking for duplicate 'Compile Sources' phases..."
compile_phases = watch_target.build_phases.select { |p| p.is_a?(Xcodeproj::Project::Object::PBXSourcesBuildPhase) }
puts "  Found #{compile_phases.count} compile sources phases"

if compile_phases.count > 1
  puts "  ⚠️  FOUND DUPLICATE COMPILE SOURCES PHASES!"
  puts "  Removing duplicates..."
  
  # Keep only the first one
  compile_phases[1..-1].each do |phase|
    watch_target.build_phases.delete(phase)
  end
  puts "  ✅ Removed #{compile_phases.count - 1} duplicate compile phases"
end

# Check for duplicate resources phases
puts "\n🔍 Checking for duplicate 'Copy Bundle Resources' phases..."
resources_phases = watch_target.build_phases.select { |p| p.is_a?(Xcodeproj::Project::Object::PBXResourcesBuildPhase) }
puts "  Found #{resources_phases.count} resources phases"

if resources_phases.count > 1
  puts "  ⚠️  FOUND DUPLICATE RESOURCES PHASES!"
  puts "  Removing duplicates..."
  
  # Keep only the first one
  resources_phases[1..-1].each do |phase|
    watch_target.build_phases.delete(phase)
  end
  puts "  ✅ Removed #{resources_phases.count - 1} duplicate resources phases"
end

# Check for duplicate frameworks phases
puts "\n🔍 Checking for duplicate 'Link Binary With Libraries' phases..."
frameworks_phases = watch_target.build_phases.select { |p| p.is_a?(Xcodeproj::Project::Object::PBXFrameworksBuildPhase) }
puts "  Found #{frameworks_phases.count} frameworks phases"

if frameworks_phases.count > 1
  puts "  ⚠️  FOUND DUPLICATE FRAMEWORKS PHASES!"
  puts "  Removing duplicates..."
  
  # Keep only the first one
  frameworks_phases[1..-1].each do |phase|
    watch_target.build_phases.delete(phase)
  end
  puts "  ✅ Removed #{frameworks_phases.count - 1} duplicate frameworks phases"
end

# Now check for duplicate files within the remaining compile sources phase
if compile_phases.first
  puts "\n🔍 Checking for duplicate files in Compile Sources..."
  compile_phase = compile_phases.first
  
  file_refs_seen = {}
  duplicates = []
  
  compile_phase.files.each do |build_file|
    if build_file.file_ref
      file_path = build_file.file_ref.path
      if file_refs_seen[file_path]
        duplicates << build_file
        puts "  ⚠️  Duplicate: #{file_path}"
      else
        file_refs_seen[file_path] = build_file
      end
    end
  end
  
  if duplicates.any?
    puts "  Found #{duplicates.count} duplicate file(s)"
    duplicates.each do |dup|
      compile_phase.files.delete(dup)
    end
    puts "  ✅ Removed all duplicate files"
  else
    puts "  ✅ No duplicate files found"
  end
end

# Check WatchApp.swift specifically (common culprit)
puts "\n🔍 Checking WatchApp.swift specifically..."
if compile_phases.first
  watchapp_files = compile_phases.first.files.select { |f| 
    f.file_ref&.path&.include?('WatchApp.swift')
  }
  
  puts "  Found #{watchapp_files.count} reference(s) to WatchApp.swift"
  
  if watchapp_files.count > 1
    puts "  ⚠️  WatchApp.swift is added multiple times!"
    watchapp_files[1..-1].each do |dup|
      compile_phases.first.files.delete(dup)
    end
    puts "  ✅ Removed duplicate WatchApp.swift references"
  end
end

# Check iOS target dependencies
puts "\n🔍 Checking iOS target dependencies..."
ios_target = project.targets.find { |t| t.name == 'Do' }
if ios_target
  watch_dependencies = ios_target.dependencies.select { |d| 
    d.target&.name&.include?('Watch')
  }
  
  puts "  Found #{watch_dependencies.count} watch app dependencies"
  
  if watch_dependencies.count > 1
    puts "  ⚠️  Multiple watch app dependencies found!"
    watch_dependencies[1..-1].each do |dep|
      ios_target.dependencies.delete(dep)
    end
    puts "  ✅ Removed duplicate dependencies"
  end
end

# Ensure clean build settings
puts "\n🔍 Cleaning build settings..."
watch_target.build_configurations.each do |config|
  # Remove any array duplicates
  ['FRAMEWORK_SEARCH_PATHS', 'HEADER_SEARCH_PATHS', 'LIBRARY_SEARCH_PATHS', 'OTHER_LDFLAGS'].each do |setting|
    if config.build_settings[setting].is_a?(Array)
      original_count = config.build_settings[setting].count
      config.build_settings[setting] = config.build_settings[setting].uniq
      new_count = config.build_settings[setting].count
      if original_count != new_count
        puts "  ✅ Removed #{original_count - new_count} duplicate entries from #{setting}"
      end
    end
  end
  
  # Ensure SKIP_INSTALL is YES
  config.build_settings['SKIP_INSTALL'] = 'YES'
  
  # Ensure proper product module name
  config.build_settings['PRODUCT_MODULE_NAME'] = 'Do_Watch_App'
end

puts "\n💾 Saving project..."
project.save

puts "\n✅ SUCCESS! Deep clean complete."
puts ""
puts "📋 Final build phases:"
watch_target.build_phases.each_with_index do |phase, index|
  puts "  #{index + 1}. #{phase.display_name}"
end
puts ""
puts "📋 Next steps:"
puts "1. Close Xcode completely"
puts "2. Delete derived data:"
puts "   rm -rf ~/Library/Developer/Xcode/DerivedData/Do-*"
puts "3. Reopen Xcode workspace:"
puts "   open Do.xcworkspace"
puts "4. Clean build folder (Cmd+Shift+K)"
puts "5. Build watch app"
puts ""

