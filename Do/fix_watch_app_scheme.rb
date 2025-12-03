#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Do.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔧 Fixing Watch App Configuration..."

# Find the watch app target
watch_target = project.targets.find { |t| t.name == 'Do Watch App' }
ios_target = project.targets.find { |t| t.name == 'Do' }

unless watch_target
  puts "❌ Watch app target not found!"
  exit 1
end

puts "✅ Found watch app target: #{watch_target.name}"

# Find or create the correct product reference for watch app
products_group = project.main_group.find_subpath('Products', true)
watch_app_ref = products_group.files.find { |f| f.path == 'Do Watch App.app' }

if watch_app_ref.nil?
  puts "📦 Creating new product reference for Do Watch App.app..."
  watch_app_ref = products_group.new_reference('Do Watch App.app')
  watch_app_ref.explicit_file_type = 'wrapper.application'
  watch_app_ref.include_in_index = 0
  watch_app_ref.source_tree = 'BUILT_PRODUCTS_DIR'
  puts "✅ Created product reference"
else
  puts "✅ Found existing product reference"
end

# Update watch target to use correct product reference
old_ref = watch_target.product_reference
if old_ref.path != 'Do Watch App.app'
  puts "🔧 Updating watch target product reference..."
  watch_target.product_reference = watch_app_ref
  puts "✅ Updated product reference from '#{old_ref.path}' to 'Do Watch App.app'"
else
  puts "✅ Product reference already correct"
end

# Remove duplicate Do.app reference if it exists and isn't used
ios_app_ref = products_group.files.find { |f| f.path == 'Do.app' && f != ios_target.product_reference }
if ios_app_ref && ios_app_ref != watch_target.product_reference
  # Check if it's used anywhere else
  used = false
  project.targets.each do |target|
    if target.product_reference == ios_app_ref && target != ios_target
      used = true
      break
    end
  end
  
  unless used
    puts "🧹 Removing unused duplicate Do.app reference..."
    ios_app_ref.remove_from_project
  end
end

# Fix the scheme
scheme_path = 'Do.xcodeproj/xcshareddata/xcschemes/Do Watch App.xcscheme'
if File.exist?(scheme_path)
  puts "🔧 Fixing watch app scheme..."
  scheme_content = File.read(scheme_path)
  
  # Replace incorrect BuildableName and path
  scheme_content.gsub!(/BuildableName = "Do\.app"/, 'BuildableName = "Do Watch App.app"')
  scheme_content.gsub!(/path = "Do\.app"/, 'path = "Do Watch App.app"')
  
  File.write(scheme_path, scheme_content)
  puts "✅ Fixed scheme file"
else
  puts "⚠️  Scheme file not found at #{scheme_path}"
end

# Save project
project.save
puts ""
puts "✅ Watch app configuration fixed!"
puts ""
puts "📋 Summary:"
puts "  - Watch target product reference: #{watch_target.product_reference.path}"
puts "  - Watch target product name: #{watch_target.product_name}"
puts ""
puts "💡 Next steps:"
puts "1. Clean build folder (Shift+Cmd+K)"
puts "2. Build iOS app first (Cmd+B on 'Do' scheme)"
puts "3. Then build/watch app (Cmd+B on 'Do Watch App' scheme)"
puts ""




