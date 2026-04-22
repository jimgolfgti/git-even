require 'rspec'
require 'pathname'
require 'fileutils'

if ENV['COVERAGE'] == 'true'
  begin
    require 'simplecov'
    require 'simplecov-lcov'
    SimpleCov.start do
      add_filter '/spec/'
      enable_coverage :branch
      formatter SimpleCov::Formatter::MultiFormatter.new([
        SimpleCov::Formatter::LcovFormatter,
        SimpleCov::Formatter::HTMLFormatter
      ])
      SimpleCov::Formatter::LcovFormatter.config do |config|
        config.report_with_single_file = true
        config.single_report_path = 'coverage/lcov.info'
      end
    end
  rescue LoadError
    # SimpleCov is optional, only used for coverage reports
  end
end

# Add lib to load path
$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))

require 'cli'
require 'github_client_wrapper'
require 'repository_syncer'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.expose_dsl_globally = true
  config.warnings = true

  original_stdout = $stdout
  original_stderr = $stderr

  config.before(:suite) do
    $stdout = File.open(File::NULL, 'w')
    $stderr = File.open(File::NULL, 'w')
  end

  config.after(:suite) do
    $stdout = original_stdout
    $stderr = original_stderr
  end
end
