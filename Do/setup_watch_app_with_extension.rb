#!/usr/bin/env ruby
require 'xcodeproj'

def gather_file_refs(group)
  refs = []
  group.children.each do |child|
    if child.is_a?(Xcodeproj::Project::Object::PBXGroup)
      refs.concat(gather_file_refs(child))
    elsif child.is_a?(Xcodeproj::Project::Object::PBXFileReference)
      refs << child
    end
  end
  refs
end

project_path = 'Do.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔍 Setting up watch app + extension"

ios_target = project.targets.find { |t| t.name == 'Do' }
abort('❌ iOS target not found') unless ios_target

ios_bundle = ios_target.build_configurations.first.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] || 'com.do.fitness'
watch_bundle = "#{ios_bundle}.watchapp"
ext_bundle = "#{watch_bundle}.extension"

watch_group = project.main_group.find_subpath('Do Watch App', true)
abort('❌ Could not find "Do Watch App" group') unless watch_group

file_refs = gather_file_refs(watch_group)
asset_refs = file_refs.select { |ref| ref.path&.end_with?('Assets.xcassets') }
plist_refs = file_refs.select { |ref| ref.path&.end_with?('.plist') }
ent_refs = file_refs.select { |ref| ref.path&.end_with?('.entitlements') }
source_refs = file_refs.select do |ref|
  path = ref.path || ''
  ref.last_known_file_type&.include?('sourcecode') &&
    !path.end_with?('.plist') &&
    !path.end_with?('.entitlements') &&
    !path.include?('Assets.xcassets')
end

# Create watch app target (container)
watch_app_target = project.new_target(:watch2_app, 'Do Watch App', :watchos, '8.0')
watch_app_target.product_reference.name = 'Do Watch App.app'
watch_app_target.product_reference.path = 'Do Watch App.app'
watch_app_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = watch_bundle
  config.build_settings['PRODUCT_NAME'] = 'Do Watch App'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '4'
  config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '8.0'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['ENABLE_PREVIEWS'] = 'YES'
  config.build_settings['INFOPLIST_FILE'] = 'Do Watch App/Info.plist'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = ios_target.build_configurations.first.build_settings['DEVELOPMENT_TEAM']
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['WKCompanionAppBundleIdentifier'] = ios_bundle
end

# Create watch extension target (executable)
ext_target = project.new_target(:watch2_extension, 'Do Watch App Extension', :watchos, '8.0')
ext_target.product_reference.name = 'Do Watch App Extension.appex'
ext_target.product_reference.path = 'Do Watch App Extension.appex'
ext_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = ext_bundle
  config.build_settings['PRODUCT_NAME'] = 'Do Watch App Extension'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '4'
  config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '8.0'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['ENABLE_PREVIEWS'] = 'YES'
  config.build_settings['INFOPLIST_FILE'] = 'Do Watch App Extension/Info.plist'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = ios_target.build_configurations.first.build_settings['DEVELOPMENT_TEAM']
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Do Watch App Extension/DoWatchAppExtension.entitlements'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
end

# Link app -> extension
watch_app_target.add_dependency(ext_target)
embed_phase = watch_app_target.new_copy_files_build_phase('Embed App Extensions')
embed_phase.dst_subfolder_spec = "13"
embed_phase.add_file_reference(ext_target.product_reference, true)

# Add files to extension target
source_refs.each do |ref|
  ext_target.source_build_phase.add_file_reference(ref)
end

# Add assets to app target resources
asset_refs.each do |ref|
  watch_app_target.resources_build_phase.add_file_reference(ref)
end

project.save
puts "✅ Watch app + extension configured"
