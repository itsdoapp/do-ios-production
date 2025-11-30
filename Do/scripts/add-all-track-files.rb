#!/usr/bin/env ruby

# Script to add all Track Infrastructure files to Xcode project
# Run from: iOS/Do/ directory

require 'xcodeproj'

begin
  project_path = File.join(__dir__, '..', 'Do.xcodeproj')
  project = Xcodeproj::Project.open(project_path)
  
  target = project.targets.find { |t| t.name == 'Do' }
  unless target
    puts "❌ Could not find 'Do' target"
    exit 1
  end
  
  def find_or_create_group(project, path)
    parts = path.split('/')
    group = project.main_group
    
    parts.each do |part|
      existing = group.children.find { |c| 
        (c.display_name == part || c.name == part) && 
        c.is_a?(Xcodeproj::Project::Object::PBXGroup)
      }
      if existing
        group = existing
      else
        group = group.new_group(part)
      end
    end
    
    group
  end
  
  base_path = File.join(__dir__, '..')
  
  # Find all Swift files in Track directory
  track_files = []
  Dir.glob(File.join(base_path, 'Features/Track/**/*.swift')).each do |file|
    relative_path = file.sub(base_path + '/', '')
    track_files << relative_path
  end
  
  # Add service files
  service_files = [
    'Core/Services/Activity/ActivityService.swift',
    'Core/Services/UserProfileService.swift',
    'Core/Services/WorkoutHistoryService.swift'
  ]
  
  service_files.each do |file|
    full_path = File.join(base_path, file)
    track_files << file if File.exist?(full_path)
  end
  
  puts "🔧 Adding #{track_files.count} Track Infrastructure files to Xcode project..."
  puts ""
  
  added = 0
  skipped = 0
  errors = 0
  
  track_files.each do |file_path|
    full_path = File.join(base_path, file_path)
    
    unless File.exist?(full_path)
      puts "⚠️  File not found: #{file_path}"
      skipped += 1
      next
    end
    
    dir_path = File.dirname(file_path)
    file_name = File.basename(file_path)
    
    group = find_or_create_group(project, dir_path)
    
    # Check if already exists
    existing = group.children.find { |f| 
      (f.path == file_name || f.path == file_path || f.name == file_name) &&
      f.is_a?(Xcodeproj::Project::Object::PBXFileReference)
    }
    
    if existing
      # Check if it's in the build phase
      compile_phase = target.build_phases.find { |bp| bp.is_a?(Xcodeproj::Project::Object::PBXSourcesBuildPhase) }
      in_build = compile_phase&.files&.any? { |f| f.file_ref == existing }
      
      if in_build
        puts "✓ Already in project: #{file_path}"
        skipped += 1
        next
      else
        # Add to build phase
        compile_phase.add_file_reference(existing) if compile_phase
        puts "✅ Added to build: #{file_path}"
        added += 1
        next
      end
    end
    
    # Create new file reference
    file_ref = group.new_reference(file_path)
    file_ref.name = file_name
    file_ref.last_known_file_type = 'sourcecode.swift'
    
    # Add to target
    target.add_file_references([file_ref])
    
    # Add to compile sources
    compile_phase = target.build_phases.find { |bp| bp.is_a?(Xcodeproj::Project::Object::PBXSourcesBuildPhase) }
    compile_phase.add_file_reference(file_ref) if compile_phase
    
    puts "✅ Added: #{file_path}"
    added += 1
    
  rescue => e
    puts "❌ Error: #{file_path} - #{e.message}"
    errors += 1
  end
  
  project.save
  
  puts ""
  puts "📊 Summary:"
  puts "   ✅ Added: #{added}"
  puts "   ⏭️  Skipped: #{skipped}"
  puts "   ❌ Errors: #{errors}"
  puts ""
  puts "✅ Project updated successfully!"
  
rescue LoadError => e
  puts "❌ Error: xcodeproj gem not installed"
  puts "   Install with: gem install xcodeproj"
  puts "   Or run: sudo gem install xcodeproj"
  exit 1
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end

