#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Do.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔍 Analyzing iOS app's watch embedding: #{project_path}"

# Find both targets
ios_target = project.targets.find { |t| t.name == 'Do' }
watch_target = project.targets.find { |t| t.name == 'Do Watch App' }

if ios_target.nil?
  puts "❌ Could not find iOS target 'Do'"
  exit 1
end

if watch_target.nil?
  puts "❌ Could not find watch target 'Do Watch App'"
  exit 1
end

puts "✅ Found iOS target: #{ios_target.name}"
puts "✅ Found watch target: #{watch_target.name}"

# Check all build phases in iOS target
puts "\n📋 iOS app build phases:"
ios_target.build_phases.each_with_index do |phase, index|
  phase_name = phase.display_name || phase.class.name.split('::').last
  puts "  #{index + 1}. #{phase_name}"
  if phase.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
    puts "     → Destination: #{phase.dst_path}"
    puts "     → Files: #{phase.files.count}"
    phase.files.each do |file|
      puts "       - #{file.file_ref&.path || file.display_name}"
    end
  end
end

# Find ALL copy files build phases
copy_phases = ios_target.build_phases.select { |p| p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) }
puts "\n🔍 Found #{copy_phases.count} total copy files build phases in iOS app"

# Find watch-related copy phases
watch_copy_phases = copy_phases.select { |p| 
  p.dst_path&.include?('Watch') || 
  p.name&.include?('Watch') ||
  p.name&.include?('Embed')
}

puts "🔍 Found #{watch_copy_phases.count} watch-related copy phases"

if watch_copy_phases.count > 1
  puts "\n⚠️  PROBLEM: Multiple watch embed phases found!"
  watch_copy_phases.each_with_index do |phase, idx|
    puts "  #{idx + 1}. #{phase.name} → #{phase.dst_path}"
  end
  
  puts "\n🔧 Removing all watch embed phases..."
  watch_copy_phases.each do |phase|
    ios_target.build_phases.delete(phase)
  end
  puts "  ✅ Removed #{watch_copy_phases.count} phases"
  
  # Create a single clean embed phase
  puts "\n🔧 Creating single clean embed phase..."
  embed_phase = ios_target.new_copy_files_build_phase('Embed Watch Content')
  embed_phase.symbol_dst_subfolder_spec = :products_directory
  embed_phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
  
  # Add watch app product
  watch_product = watch_target.product_reference
  build_file = embed_phase.add_file_reference(watch_product)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  
  puts "  ✅ Created clean embed phase with watch app"
  
elsif watch_copy_phases.count == 1
  # Check if watch app is embedded multiple times in the single phase
  puts "\n🔍 Checking single embed phase for duplicates..."
  embed_phase = watch_copy_phases.first
  
  watch_files = embed_phase.files.select { |f| 
    f.file_ref&.display_name&.include?('Watch') ||
    f.file_ref&.path&.include?('Watch')
  }
  
  puts "  Found #{watch_files.count} watch-related file(s) in embed phase"
  
  if watch_files.count > 1
    puts "  ⚠️  Watch app is embedded multiple times!"
    watch_files[1..-1].each do |dup|
      embed_phase.files.delete(dup)
    end
    puts "  ✅ Removed #{watch_files.count - 1} duplicate(s)"
  elsif watch_files.count == 0
    puts "  ⚠️  No watch app in embed phase!"
    watch_product = watch_target.product_reference
    build_file = embed_phase.add_file_reference(watch_product)
    build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
    puts "  ✅ Added watch app to embed phase"
  else
    puts "  ✅ Embed phase looks good"
  end
  
elsif watch_copy_phases.count == 0
  puts "\n⚠️  No watch embed phase found!"
  puts "🔧 Creating embed phase..."
  
  embed_phase = ios_target.new_copy_files_build_phase('Embed Watch Content')
  embed_phase.symbol_dst_subfolder_spec = :products_directory
  embed_phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
  
  watch_product = watch_target.product_reference
  build_file = embed_phase.add_file_reference(watch_product)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  
  puts "  ✅ Created embed phase"
end

# Check dependencies
puts "\n🔍 Checking iOS app dependencies..."
watch_deps = ios_target.dependencies.select { |d| 
  d.target&.name&.include?('Watch')
}

puts "  Found #{watch_deps.count} watch dependencies"

if watch_deps.count > 1
  puts "  ⚠️  Multiple watch dependencies!"
  watch_deps[1..-1].each do |dep|
    ios_target.dependencies.delete(dep)
  end
  puts "  ✅ Removed #{watch_deps.count - 1} duplicate dependencies"
elsif watch_deps.count == 0
  puts "  ⚠️  No watch dependency!"
  ios_target.add_dependency(watch_target)
  puts "  ✅ Added watch dependency"
else
  puts "  ✅ Dependencies look good"
end

# Verify watch target settings
puts "\n🔍 Verifying watch target settings..."
watch_target.build_configurations.each do |config|
  if config.build_settings['SKIP_INSTALL'] != 'YES'
    config.build_settings['SKIP_INSTALL'] = 'YES'
    puts "  ✅ Set SKIP_INSTALL = YES for #{config.name}"
  end
  
  if config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] != 'YES'
    config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'YES'
    puts "  ✅ Set ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = YES for #{config.name}"
  end
end

puts "\n💾 Saving project..."
project.save

puts "\n✅ SUCCESS! Fixed iOS app's watch embedding."
puts ""
puts "📋 Final iOS build phases:"
ios_target.build_phases.each_with_index do |phase, index|
  phase_name = phase.display_name || phase.class.name.split('::').last
  puts "  #{index + 1}. #{phase_name}"
  if phase.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
    puts "     → Files: #{phase.files.count}"
  end
end
puts ""
puts "📋 CRITICAL: Do these steps now:"
puts "1. Quit Xcode completely (Cmd+Q)"
puts "2. Delete derived data again:"
puts "   rm -rf ~/Library/Developer/Xcode/DerivedData/Do-*"
puts "3. Open workspace:"
puts "   open Do.xcworkspace"
puts "4. Select 'Do' scheme (iOS app, not watch)"
puts "5. Build iOS app first (Cmd+B)"
puts "6. Then select 'Do Watch App' scheme"
puts "7. Build watch app (Cmd+B)"
puts ""

