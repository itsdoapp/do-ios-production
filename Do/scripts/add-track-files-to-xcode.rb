#!/usr/bin/env ruby

# Script to add all Track Infrastructure files to Xcode project
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

# Base path
base_path = File.join(__dir__, '..')

# Dynamically find all Swift files in Track directory
track_base = File.join(base_path, 'Features/Track')
files_to_add = []

if Dir.exist?(track_base)
  Dir.glob(File.join(track_base, '**/*.swift')).each do |file|
    relative_path = file.sub(base_path + '/', '')
    files_to_add << relative_path
  end
end

# Add service files
service_files = [
  'Core/Services/Activity/ActivityService.swift',
  'Core/Services/UserProfileService.swift',
  'Core/Services/WorkoutHistoryService.swift'
]

service_files.each do |file|
  full_path = File.join(base_path, file)
  if File.exist?(full_path)
    files_to_add << file
  end
end

puts "🔧 Adding Track Infrastructure files to Xcode project..."
puts "📁 Found #{files_to_add.count} files to add"
puts ""

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
  
  # Check if file already exists in project
  existing_ref = group.children.find { |f| 
    f.path == file_name || f.path == file_path
  }
  
  # Remove existing reference if found (for clean add)
  if existing_ref
    puts "🗑️  Removing existing reference: #{file_path}"
    
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
  
  # Create new file reference
  file_ref = project.new(Xcodeproj::Project::Object::PBXFileReference)
  file_ref.name = file_name
  file_ref.path = file_path
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

puts ""
puts "📊 Summary:"
puts "   ✅ Added: #{added_count}"
puts "   ⏭️  Skipped: #{skipped_count}"
puts "   ❌ Errors: #{error_count}"
puts ""
puts "✅ Project saved successfully!"
puts "💡 Open Do.xcodeproj in Xcode to verify files are added correctly."

