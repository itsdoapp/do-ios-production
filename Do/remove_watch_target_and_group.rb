#!/usr/bin/env ruby
require 'xcodeproj'
project = Xcodeproj::Project.open('Do.xcodeproj')

watch_targets = project.targets.select { |t| t.name.include?('Watch') }
watch_targets.each do |t|
  puts "Removing target #{t.name}"
  t.remove_from_project
end

ios_target = project.targets.find { |t| t.name == 'Do' }
if ios_target
  ios_target.dependencies.select { |d| d.target&.name&.include?('Watch') }.each do |dep|
    ios_target.dependencies.delete(dep)
  end
  ios_target.build_phases.select { |p| p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) && (p.name&.include?('Watch') || p.dst_path&.include?('Watch')) }.each do |phase|
    ios_target.build_phases.delete(phase)
  end
end

watch_groups = project.groups.select { |g| g.path == 'Do Watch App' || g.display_name == 'Do Watch App' }
watch_groups.each do |g|
  puts "Removing group #{g.display_name || g.path}"
  g.remove_from_project
end

project.save
puts 'Done.'
