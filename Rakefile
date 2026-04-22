#!/usr/bin/env rake

require 'rspec/core/rake_task'

task default: :spec

desc 'Run RSpec tests'
RSpec::Core::RakeTask.new(:spec) do |task|
  task.pattern = 'spec/**/*_spec.rb'
  task.rspec_opts = '--color --format progress'
end

desc 'Run RSpec with coverage'
task :spec_with_coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task['spec'].invoke
end
