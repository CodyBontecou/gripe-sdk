#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Add GripeSDK as a Swift Package dependency to an .xcodeproj and link it
# to the named app target.
#
# Usage:
#   ruby add-package-xcodeproj.rb --project /path/App.xcodeproj --target App \
#                                 --source git|local [--local-path <path>]
#
# Installs the `xcodeproj` gem to the user gem dir if it isn't already available.

require 'optparse'

GIT_URL = 'https://github.com/CodyBontecou/gripe-sdk.git'
VERSION = '0.1.0'
PRODUCT = 'GripeSDK'

opts = { source: 'git' }
OptionParser.new do |o|
  o.on('--project PATH')    { |v| opts[:project]    = v }
  o.on('--target NAME')     { |v| opts[:target]     = v }
  o.on('--source KIND')     { |v| opts[:source]     = v }
  o.on('--local-path PATH') { |v| opts[:local_path] = v }
end.parse!

abort 'ERROR: --project required' unless opts[:project]
abort 'ERROR: --target required'  unless opts[:target]
abort "ERROR: --source must be git|local" unless %w[git local].include?(opts[:source])
abort "ERROR: project not found at #{opts[:project]}" unless File.directory?(opts[:project])

if opts[:source] == 'local'
  abort 'ERROR: --source local requires --local-path <path-to-gripe-sdk>' unless opts[:local_path]
  abort "ERROR: --local-path '#{opts[:local_path]}' is not a directory" unless File.directory?(opts[:local_path])
end

begin
  require 'xcodeproj'
rescue LoadError
  warn 'Installing xcodeproj gem (user scope)...'
  system('gem', 'install', '--user-install', 'xcodeproj') || abort('failed to install xcodeproj gem')
  user_gem_dir = `gem env user_gemdir`.strip
  Gem.paths = { 'GEM_PATH' => "#{user_gem_dir}:#{ENV['GEM_PATH']}" }
  require 'xcodeproj'
end

project = Xcodeproj::Project.open(opts[:project])
target  = project.targets.find { |t| t.name == opts[:target] }
abort "ERROR: target '#{opts[:target]}' not found in project. Available: #{project.targets.map(&:name).join(', ')}" unless target

existing = project.root_object.package_references.find do |ref|
  (ref.respond_to?(:repositoryURL) && ref.repositoryURL == GIT_URL) ||
    (ref.respond_to?(:path)        && opts[:local_path] && ref.path == opts[:local_path])
end

if existing && target.package_product_dependencies.any? { |d| d.product_name == PRODUCT }
  warn "GripeSDK already linked to #{target.name}; nothing to do"
  exit 0
end

ref = existing
unless ref
  if opts[:source] == 'git'
    ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
    ref.repositoryURL = GIT_URL
    ref.requirement = { 'kind' => 'upToNextMajorVersion', 'minimumVersion' => VERSION }
  else
    ref = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
    ref.path = opts[:local_path]
  end
  project.root_object.package_references << ref
end

unless target.package_product_dependencies.any? { |d| d.product_name == PRODUCT }
  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.package      = ref
  dep.product_name = PRODUCT
  target.package_product_dependencies << dep

  link_phase = target.frameworks_build_phase
  unless link_phase.files_references.any? { |f| f.respond_to?(:product_name) && f.product_name == PRODUCT }
    build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
    build_file.product_ref = dep
    link_phase.files << build_file
  end
end

project.save
puts "Added #{PRODUCT} to target #{target.name} in #{opts[:project]}"
