#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Do.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target_name = "Do Watch App"
target = project.targets.find { |t| t.name == target_name }

unless target
  puts "❌ Target #{target_name} not found!"
  exit 1
end

files_to_add = [
  'Features/Track/Auth/WatchAuthService.swift',
  'Features/Track/Models/GymWorkoutMetrics.swift',
  'Features/Track/Models/WorkoutMetrics.swift'
]

puts "🔧 Fixing dependencies for #{target_name}..."

files_to_add.each do |file_path|
  # 1. Find or create file reference
  # We search by path suffix to be safe, or name
  file_ref = project.files.find { |f| f.path && f.path.end_with?(file_path) }
  
  unless file_ref
    puts "   ➕ Adding file to project: #{file_path}"
    # Add to main group if not found. 
    # Ideally we put it in the correct group structure but for now getting it in the project is priority.
    # Let's try to put it in the group matching the folder structure if possible, otherwise main group.
    
    # For simplicity, adding to main group's children or finding the group
    # Let's just add to main group with the path, Xcode usually handles organization visually
    file_ref = project.main_group.new_file(file_path)
  end
  
  # 2. Add to target
  if file_ref
    unless target.source_build_phase.files_references.include?(file_ref)
      target.source_build_phase.add_file_reference(file_ref)
      puts "   ✅ Added to target: #{file_path}"
    else
      puts "   ℹ️  Already in target: #{file_path}"
    end
  else
    puts "   ❌ Failed to create reference for: #{file_path}"
  end
end

project.save
puts "💾 Project saved."

