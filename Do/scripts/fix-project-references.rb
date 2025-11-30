#!/usr/bin/env ruby

# Script to fix file references in Xcode project
# Specifically fixes issues where files appear as full paths instead of filenames
# Requires: gem install xcodeproj

require 'xcodeproj'

project_path = File.join(__dir__, '..', 'Do.xcodeproj')
project = Xcodeproj::Project.open(project_path)

puts "🔍 Scanning project for broken file references..."

fixed_count = 0
total_files = 0

# Helper to process groups recursively
def process_group(group, level = 0)
  count = 0
  
  group.children.each do |child|
    if child.is_a?(Xcodeproj::Project::Object::PBXGroup)
      count += process_group(child, level + 1)
    elsif child.is_a?(Xcodeproj::Project::Object::PBXFileReference)
      # Check if it's a source file (Swift, etc)
      next unless child.path && (child.path.end_with?('.swift') || child.path.end_with?('.xib') || child.path.end_with?('.storyboard'))
      
      file_name = File.basename(child.path)
      needs_fix = false
      
      # Fix 1: Name should be the filename
      if child.name.nil? || child.name != file_name
        child.name = file_name
        needs_fix = true
      end
      
      if needs_fix
        puts "🔧 Fixing display name for: #{file_name} (was: #{child.name || 'nil'})"
        count += 1
      end
    end
  end
  
  count
end

fixed_count = process_group(project.main_group)

puts "\n📊 Summary:"
puts "   ✨ Fixed #{fixed_count} file references"

if fixed_count > 0
  project.save
  puts "✅ Project saved successfully!"
else
  puts "✅ No fixes needed."
end


