#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Do/Do.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "📱 Opening project: #{project_path}"

# 1. Update file references for moved files
moved_files = {
  'WatchAuthService.swift' => 'Do/Do Watch App/Services/WatchAuthService.swift',
  'GymWorkoutMetrics.swift' => 'Do/Do Watch App/Models/GymWorkoutMetrics.swift',
  'WorkoutMetrics.swift' => 'Do/Do Watch App/Models/WorkoutMetrics.swift'
}

moved_files.each do |filename, new_path|
  # Find all references to this file
  refs = project.files.select { |f| f.name == filename || (f.path && f.path.end_with?(filename)) }
  
  if refs.empty?
    puts "⚠️ Reference not found for #{filename}, creating new one..."
    # Add to the correct group
    group_path = File.dirname(new_path)
    group_name = File.basename(group_path)
    
    # Find group by name (simplification)
    group = project.main_group.recursive_children.find { |c| c.isa == 'PBXGroup' && c.name == group_name }
    unless group
       # Fallback to main group or "Do Watch App" group
       group = project.main_group.find_subpath('Do Watch App', false) || project.main_group
    end
    
    file_ref = group.new_file(new_path)
    puts "   + Created reference: #{new_path}"
  else
    refs.each do |ref|
      # Update path
      ref.set_path(new_path)
      puts "   + Updated reference path: #{ref.path}"
      
      # If it's in the wrong group, we might want to move it, but updating path is often enough for Xcode to find it
      # Ideally we move the reference to the correct group too
    end
  end
end

# 2. Ensure they are in the Watch App target
watch_target = project.targets.find { |t| t.name == 'Do Watch App' }
if watch_target
  moved_files.keys.each do |filename|
    ref = project.files.find { |f| f.path && f.path.end_with?(filename) }
    if ref
      unless watch_target.source_build_phase.files_references.include?(ref)
        watch_target.source_build_phase.add_file_reference(ref)
        puts "   + Added to Watch Target: #{filename}"
      end
    end
  end
else
  puts "❌ Watch App target not found"
end

# 3. Ensure they are ALSO in the iOS App target (since they are shared models/services used by iOS app too)
# Wait, WatchAuthService is likely watch-only, but the Metrics models are definitely shared.
ios_target = project.targets.find { |t| t.name == 'Do' }
if ios_target
  ['GymWorkoutMetrics.swift', 'WorkoutMetrics.swift'].each do |filename|
    ref = project.files.find { |f| f.path && f.path.end_with?(filename) }
    if ref
      unless ios_target.source_build_phase.files_references.include?(ref)
        ios_target.source_build_phase.add_file_reference(ref)
        puts "   + Added to iOS Target: #{filename}"
      end
    end
  end
end

project.save
puts "✅ Project updated."

