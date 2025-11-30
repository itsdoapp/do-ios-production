#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Do.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔍 Opening project: #{project_path}"

# Find the iOS app target
ios_target = project.targets.find { |t| t.name == 'Do' || t.name == 'DoIOS' || t.platform_name == :ios }
if ios_target.nil?
  puts "❌ Could not find iOS app target"
  puts "Available targets: #{project.targets.map(&:name).join(', ')}"
  exit 1
end

puts "✅ Found iOS target: #{ios_target.name}"
puts "   Bundle ID: #{ios_target.build_configurations.first.build_settings['PRODUCT_BUNDLE_IDENTIFIER']}"

# Check if watch target already exists
existing_watch_target = project.targets.find { |t| t.name.include?('Watch') }
if existing_watch_target
  puts "⚠️  Watch target '#{existing_watch_target.name}' already exists. Removing it first..."
  existing_watch_target.remove_from_project
end

# Create the watch app target
puts "📱 Creating watchOS app target..."
watch_target = project.new_target(:watch2_app, 'Do Watch App', :watchos, '8.0')

# Get iOS bundle ID to derive watch bundle ID
ios_bundle_id = ios_target.build_configurations.first.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] || 'com.itsdoapp.doios'
watch_bundle_id = "#{ios_bundle_id}.watchapp"

puts "   iOS Bundle ID: #{ios_bundle_id}"
puts "   Watch Bundle ID: #{watch_bundle_id}"

# Configure bundle identifier
watch_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = watch_bundle_id
  config.build_settings['PRODUCT_NAME'] = 'Do Watch App'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '4' # Watch
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
  
  # Add companion app bundle identifier
  config.build_settings['WKCompanionAppBundleIdentifier'] = ios_bundle_id
  
  # Entitlements
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Do Watch App/DoWatchApp.entitlements'
  
  # Framework search paths
  config.build_settings['FRAMEWORK_SEARCH_PATHS'] = [
    '$(inherited)',
    '$(SDKROOT)/System/Library/Frameworks/WatchKit.framework'
  ]
end

puts "✅ Configured watch target with bundle identifier: #{watch_bundle_id}"

# Get or create the watch app group in project
watch_app_group = project.main_group.find_subpath('Do Watch App', true)
watch_app_group.set_source_tree('<group>')

puts "📁 Adding files to watch target..."

# Add Swift files
swift_files = [
  'Do Watch App/WatchApp.swift',
  'Do Watch App/Models/WatchDeviceInfo.swift',
  'Do Watch App/Models/WatchMetrics.swift',
  'Do Watch App/Models/WatchWorkoutSession.swift',
  'Do Watch App/Models/WorkoutState.swift',
  'Do Watch App/Services/DeviceCoordinationEngine.swift',
  'Do Watch App/Services/GymWorkoutSync.swift',
  'Do Watch App/Services/LiveMetricsSync.swift',
  'Do Watch App/Services/MetricsHandoffService.swift',
  'Do Watch App/Services/MetricSourceSelector.swift',
  'Do Watch App/Services/WatchConnectivityManager.swift',
  'Do Watch App/Services/WatchMetricsSyncService.swift',
  'Do Watch App/Services/WatchWorkoutCoordinator.swift',
  'Do Watch App/Services/WorkoutHandoffProtocol.swift',
  'Do Watch App/Services/WorkoutStateSync.swift',
  'Do Watch App/Views/WorkoutListView.swift',
  'Do Watch App/Views/Running/RunningWorkoutView.swift',
  'Do Watch App/Views/Biking/BikingWorkoutView.swift',
  'Do Watch App/Views/Hiking/HikingWorkoutView.swift',
  'Do Watch App/Views/Walking/WalkingWorkoutView.swift',
  'Do Watch App/Views/Swimming/SwimmingWorkoutView.swift',
  'Do Watch App/Views/Sports/SportsWorkoutView.swift',
  'Do Watch App/Views/Gym/GymWorkoutView.swift'
]

swift_files.each do |file_path|
  if File.exist?(file_path)
    file_ref = watch_app_group.new_reference(file_path)
    watch_target.source_build_phase.add_file_reference(file_ref)
    puts "  ✅ Added source: #{file_path}"
  else
    puts "  ⚠️  File not found: #{file_path}"
  end
end

# Add Assets.xcassets
assets_path = 'Do Watch App/Assets.xcassets'
if File.exist?(assets_path)
  assets_ref = watch_app_group.new_reference(assets_path)
  assets_ref.last_known_file_type = 'folder.assetcatalog'
  watch_target.resources_build_phase.add_file_reference(assets_ref)
  puts "  ✅ Added resource: #{assets_path}"
else
  puts "  ⚠️  Assets not found: #{assets_path}"
end

# Create Info.plist
info_plist_path = 'Do Watch App/Info.plist'
info_plist_content = <<~PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleDisplayName</key>
    <string>Do</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
    <key>WKCompanionAppBundleIdentifier</key>
    <string>#{ios_bundle_id}</string>
    <key>WKApplication</key>
    <true/>
    <key>NSHealthShareUsageDescription</key>
    <string>We need access to your health data to track your workouts</string>
    <key>NSHealthUpdateUsageDescription</key>
    <string>We need to update your health data with workout information</string>
</dict>
</plist>
PLIST

File.write(info_plist_path, info_plist_content)
puts "✅ Created Info.plist at #{info_plist_path}"

# Create entitlements file
entitlements_path = 'Do Watch App/DoWatchApp.entitlements'
entitlements_content = <<~ENTITLEMENTS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.#{ios_bundle_id}</string>
    </array>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>
</dict>
</plist>
ENTITLEMENTS

File.write(entitlements_path, entitlements_content)
puts "✅ Created entitlements at #{entitlements_path}"

# Embed watch app in iOS app
puts "🔗 Linking watch app to iOS app..."

# Add watch app as a target dependency
# Clean up any stale dependencies first (leftovers from previous runs can contain nil targets)
ios_target.dependencies.select { |dep| dep.target.nil? }.each { |dep| ios_target.dependencies.delete(dep) }

ios_target.add_dependency(watch_target)
puts "✅ Added watch app as dependency to iOS app"

# Create copy files build phase to embed watch app
embed_phase = ios_target.new_copy_files_build_phase('Embed Watch Content')
embed_phase.symbol_dst_subfolder_spec = :products_directory
embed_phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'

# Add the watch app product to the embed phase
watch_product_ref = watch_target.product_reference
build_file = embed_phase.add_file_reference(watch_product_ref)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
puts "✅ Configured watch app to be embedded in iOS app"

# Save the project
puts "💾 Saving project..."
project.save

puts ""
puts "✅ SUCCESS! Watch app target created and configured!"
puts ""
puts "📋 Summary:"
puts "  - iOS App Target: #{ios_target.name}"
puts "  - iOS Bundle ID: #{ios_bundle_id}"
puts "  - Watch App Target: Do Watch App"
puts "  - Watch Bundle ID: #{watch_bundle_id}"
puts ""
puts "📋 Next steps:"
puts "1. Open the project in Xcode: Do.xcworkspace (use workspace, not xcodeproj)"
puts "2. Select the 'Do Watch App' target"
puts "3. Go to Signing & Capabilities:"
puts "   - Enable 'App Groups' and add: group.#{ios_bundle_id}"
puts "   - Enable 'HealthKit'"
puts "   - Enable 'Background Modes' and check 'Workout Processing'"
puts "4. Build and run on Apple Watch simulator"
puts ""

