#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Do.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔍 Opening project: #{project_path}"

# Find the watch target
watch_target = project.targets.find { |t| t.name == 'Do Watch App' }
if watch_target.nil?
  puts "❌ Could not find 'Do Watch App' target"
  exit 1
end

puts "✅ Found watch target: #{watch_target.name}"

# Check for duplicate files in build phases
puts "\n📋 Checking for duplicate files..."

# Track all file references we've seen
seen_files = {}
duplicates_found = false

# Check source build phase
watch_target.source_build_phase.files.each do |build_file|
  if build_file.file_ref
    file_path = build_file.file_ref.path
    if seen_files[file_path]
      puts "  ⚠️  Duplicate source file: #{file_path}"
      # Remove the duplicate
      watch_target.source_build_phase.files.delete(build_file)
      duplicates_found = true
    else
      seen_files[file_path] = true
    end
  end
end

# Check resources build phase
seen_resources = {}
watch_target.resources_build_phase.files.each do |build_file|
  if build_file.file_ref
    file_path = build_file.file_ref.path
    if seen_resources[file_path]
      puts "  ⚠️  Duplicate resource file: #{file_path}"
      # Remove the duplicate
      watch_target.resources_build_phase.files.delete(build_file)
      duplicates_found = true
    else
      seen_resources[file_path] = true
    end
  end
end

if !duplicates_found
  puts "  ✅ No duplicate files found in build phases"
end

# Check for multiple copy files build phases
puts "\n📋 Checking build phases..."
copy_files_phases = watch_target.build_phases.select { |phase| phase.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) }
puts "  Found #{copy_files_phases.count} copy files build phases"

if copy_files_phases.count > 1
  puts "  ⚠️  Multiple copy files phases found, keeping only the first one"
  copy_files_phases[1..-1].each do |phase|
    watch_target.build_phases.delete(phase)
  end
end

# Check build settings for duplicate output paths
puts "\n📋 Checking build settings..."
watch_target.build_configurations.each do |config|
  # Ensure SKIP_INSTALL is YES for watch app
  if config.build_settings['SKIP_INSTALL'] != 'YES'
    config.build_settings['SKIP_INSTALL'] = 'YES'
    puts "  ✅ Set SKIP_INSTALL to YES for #{config.name}"
  end
  
  # Ensure proper product name
  if config.build_settings['PRODUCT_NAME'] != 'Do Watch App'
    config.build_settings['PRODUCT_NAME'] = 'Do Watch App'
    puts "  ✅ Set PRODUCT_NAME to 'Do Watch App' for #{config.name}"
  end
  
  # Remove any duplicate entries in build settings
  config.build_settings['OTHER_LDFLAGS'] = ['$(inherited)'] if config.build_settings['OTHER_LDFLAGS'].is_a?(Array) && config.build_settings['OTHER_LDFLAGS'].length > 1
end

# Find iOS target and check its embed watch content phase
ios_target = project.targets.find { |t| t.name == 'Do' }
if ios_target
  puts "\n📋 Checking iOS target embed phases..."
  
  # Get all copy files phases
  embed_phases = ios_target.build_phases.select { |phase| 
    phase.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) && 
    (phase.name == 'Embed Watch Content' || phase.dst_path&.include?('Watch'))
  }
  
  if embed_phases.count > 1
    puts "  ⚠️  Found #{embed_phases.count} embed watch content phases, keeping only one"
    # Keep the first one, remove others
    embed_phases[1..-1].each do |phase|
      ios_target.build_phases.delete(phase)
    end
  end
  
  # Check if watch app is embedded only once
  if embed_phases.first
    watch_products = embed_phases.first.files.select { |f| 
      f.file_ref&.path&.include?('Do Watch App') 
    }
    
    if watch_products.count > 1
      puts "  ⚠️  Watch app embedded multiple times, removing duplicates"
      watch_products[1..-1].each do |file|
        embed_phases.first.files.delete(file)
      end
    end
  end
end

# Save the project
puts "\n💾 Saving project..."
project.save

puts "\n✅ SUCCESS! Fixed duplicate build targets."
puts ""
puts "📋 Next steps:"
puts "1. Clean build folder in Xcode (Cmd+Shift+K)"
puts "2. Close and reopen Xcode"
puts "3. Build the watch app target"
puts ""

