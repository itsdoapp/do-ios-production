#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Do.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔍 Removing ALL watch targets and starting fresh"

# Find all targets
puts "\n📋 Current targets:"
project.targets.each_with_index do |target, idx|
  puts "  #{idx + 1}. #{target.name} (#{target.product_type})"
end

# Find ALL watch-related targets
watch_targets = project.targets.select { |t| 
  t.name.include?('Watch') || 
  t.name.include?('watch') ||
  t.product_type&.include?('watchapp')
}

puts "\n🗑️  Found #{watch_targets.count} watch target(s) to remove:"
watch_targets.each do |target|
  puts "  - #{target.name}"
end

if watch_targets.count > 0
  puts "\n🔧 Removing all watch targets..."
  watch_targets.each do |target|
    puts "  Removing: #{target.name}..."
    target.remove_from_project
  end
  puts "  ✅ Removed #{watch_targets.count} watch target(s)"
else
  puts "  ✅ No watch targets found (good!)"
end

# Find iOS target
ios_target = project.targets.find { |t| t.name == 'Do' }
if ios_target.nil?
  puts "❌ Could not find iOS target"
  exit 1
end

puts "\n✅ iOS target: #{ios_target.name}"

# Remove ALL watch-related dependencies from iOS target
puts "\n🧹 Cleaning iOS target..."
watch_deps = ios_target.dependencies.select { |d| 
  d.target&.name&.include?('Watch') || d.target&.name&.include?('watch')
}
watch_deps.each do |dep|
  ios_target.dependencies.delete(dep)
end
puts "  Removed #{watch_deps.count} watch dependencies"

# Remove ALL watch-related embed phases
watch_phases = ios_target.build_phases.select { |p| 
  p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) && 
  (p.name&.include?('Watch') || p.name&.include?('watch') || p.dst_path&.include?('Watch'))
}
watch_phases.each do |phase|
  ios_target.build_phases.delete(phase)
end
puts "  Removed #{watch_phases.count} watch embed phases"

# Save project without watch targets
puts "\n💾 Saving project (without watch targets)..."
project.save

puts "\n✅ SUCCESS! All watch targets removed."
puts ""
puts "📋 Remaining targets:"
project.targets.each_with_index do |target, idx|
  puts "  #{idx + 1}. #{target.name}"
end
puts ""
puts "🎯 Next step: Run setup_watch_target.rb to create ONE clean watch target"
puts ""

