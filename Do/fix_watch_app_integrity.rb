#!/usr/bin/env ruby

require 'xcodeproj'

puts "🔧 Fixing Watch App Integrity Verification Issue"
puts "=" * 60

project_path = File.join(__dir__, 'Do.xcodeproj')
project = Xcodeproj::Project.open(project_path)

# Find targets
ios_target = project.targets.find { |t| t.name == 'Do' }
watch_target = project.targets.find { |t| t.name == 'Do Watch App' }

unless ios_target
  puts "❌ Could not find iOS target 'Do'"
  exit 1
end

unless watch_target
  puts "❌ Could not find Watch target 'Do Watch App'"
  exit 1
end

puts "\n✅ Found targets:"
puts "   - iOS: #{ios_target.name}"
puts "   - Watch: #{watch_target.name}"

# Fix watch app code signing settings
puts "\n🔐 Fixing Watch App Code Signing Settings..."

watch_target.build_configurations.each do |config|
  puts "\n   Configuring: #{config.name}"
  
  # Ensure proper code signing settings
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CODE_SIGN_IDENTITY'] = 'Apple Development'
  config.build_settings['DEVELOPMENT_TEAM'] = 'R8RJG8QJ4J'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Do Watch App/DoWatchApp.entitlements'
  
  # Critical: Ensure watch app is properly signed
  # Remove any explicit provisioning profile specifier to let automatic signing work
  config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ''
  config.build_settings.delete('PROVISIONING_PROFILE')
  
  # Ensure proper bundle identifier
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.do.fitness.watchapp'
  
  # Ensure SKIP_INSTALL is NO for watch apps (so they get installed)
  config.build_settings['SKIP_INSTALL'] = 'NO'
  
  # Ensure proper SDK
  config.build_settings['SDKROOT'] = 'watchos'
  
  puts "      ✅ Code Sign Style: Automatic"
  puts "      ✅ Code Sign Identity: Apple Development"
  puts "      ✅ Development Team: R8RJG8QJ4J"
  puts "      ✅ Bundle ID: com.do.fitness.watchapp"
  puts "      ✅ Skip Install: NO"
end

# Verify iOS app code signing matches
puts "\n🔐 Verifying iOS App Code Signing..."

ios_target.build_configurations.each do |config|
  if config.build_settings['DEVELOPMENT_TEAM'] != 'R8RJG8QJ4J'
    puts "   ⚠️  iOS app team doesn't match watch app!"
    config.build_settings['DEVELOPMENT_TEAM'] = 'R8RJG8QJ4J'
    puts "      ✅ Fixed iOS app team to match"
  end
end

# Verify watch app embedding
puts "\n📦 Verifying Watch App Embedding..."

embed_phases = ios_target.build_phases.select { |phase|
  phase.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
  phase.name == 'Embed Watch Content'
}

if embed_phases.empty?
  puts "   ⚠️  No Embed Watch Content phase found!"
  puts "   🔧 Creating embed phase..."
  
  embed_phase = ios_target.new_copy_files_build_phase('Embed Watch Content')
  embed_phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
  embed_phase.dst_subfolder_spec = 16 # Products Directory
  
  watch_product = watch_target.product_reference
  if watch_product
    build_file = embed_phase.add_file_reference(watch_product)
    build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
    puts "      ✅ Added watch app to embed phase"
  else
    puts "      ❌ Could not find watch app product reference"
  end
elsif embed_phases.count > 1
  puts "   ⚠️  Multiple embed phases found! Removing duplicates..."
  embed_phases[1..-1].each { |phase| phase.remove_from_project }
  puts "      ✅ Removed duplicate embed phases"
else
  embed_phase = embed_phases.first
  watch_files = embed_phase.files.select { |f|
    f.file_ref&.display_name&.include?('Watch') ||
    f.file_ref&.path&.include?('Watch')
  }
  
  if watch_files.empty?
    puts "   ⚠️  Watch app not in embed phase!"
    watch_product = watch_target.product_reference
    if watch_product
      build_file = embed_phase.add_file_reference(watch_product)
      build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
      puts "      ✅ Added watch app to embed phase"
    end
  else
    puts "      ✅ Watch app is properly embedded"
  end
end

# Ensure watch target is a dependency
puts "\n🔗 Verifying Target Dependencies..."

watch_deps = ios_target.dependencies.select { |dep|
  dep.target == watch_target
}

if watch_deps.empty?
  puts "   ⚠️  Watch app not in iOS app dependencies!"
  ios_target.add_dependency(watch_target)
  puts "      ✅ Added watch app as dependency"
else
  puts "      ✅ Watch app is a dependency"
end

# Save project
puts "\n💾 Saving project..."
project.save

puts "\n" + "=" * 60
puts "✅ Watch App Integrity Fix Complete!"
puts "\n📋 Next Steps:"
puts "1. Open Xcode: open Do.xcworkspace"
puts "2. Select 'Do Watch App' target"
puts "3. Go to Signing & Capabilities tab"
puts "4. Verify 'Automatically manage signing' is checked"
puts "5. Verify Development Team is: R8RJG8QJ4J"
puts "6. If you see any errors, click 'Try Again' or toggle signing off/on"
puts "7. Clean build folder: Product → Clean Build Folder (⇧⌘K)"
puts "8. Build iOS app first (⌘B), then run (⌘R)"
puts "\n💡 The watch app should now install without integrity errors!"



