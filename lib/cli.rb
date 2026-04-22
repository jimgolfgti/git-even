require 'slop'
require 'pathname'
require 'highline'
require 'colorize'
require 'github_client_wrapper'
require 'repository_syncer'

# Slop configuration for path parsing
module Slop
  class PathOption < Option
    def call(value)
      Pathname.new(value)
    end
  end
end

class CLI
  def initialize(argv = ARGV)
    @argv = argv
    @options = nil
  end

  def run
    parse_options
    authenticate
    repositories = fetch_repositories
    sync_repositories(repositories)
  end

  private

  attr_reader :options

  def parse_options
    @options = Slop.parse @argv do |o|
      o.string '-k', '--key', 'GitHub API Key (Use \'-\' to read from stdin)', required: true
      o.bool '-l', '--login', 'Sync login repositories'
      o.string '-o', '--org', 'Sync specific Organisation repositories'
      o.separator ''
      o.separator 'Extra options:'
      o.path '--path', 'Base path to clone into', default: Pathname.new('.')
      o.bool '--forks', 'Include Forked repositories', default: false
      o.bool '--last-commit', 'Output last commit message', default: false
      o.bool '-v', '--verbose', 'Additional logging', default: false
      o.on '-h', '--help', 'Show help' do
        puts o
        exit
      end
    end
  rescue Slop::MissingRequiredOption, Slop::UnknownOption, Slop::MissingArgument => e
    puts e.message.red
    exit 1
  end

  def validate_options
    if options.login? && !options[:org].nil?
      puts "incompatible options `-login' and `--org' cannot be used together".red
      exit 1
    end
  end

  def read_key
    return options[:key] if options[:key] != "-"

    if STDIN.tty?
      puts "Please enter your key:"
      key = $stdin.noecho(&:gets)
      options[:key] = key.strip!
    else
      options[:key] = $stdin.gets.strip!
    end
  end

  def authenticate
    validate_options
    read_key

    @client = GitHubClientWrapper.new(options[:key])
    user_info = @client.authenticate
    @user = user_info
    puts "Authenticated as #{@user[:login]} (#{@user[:name]})".magenta
  rescue => e
    puts e.message.red
    exit 1
  end

  def fetch_repositories
    org_names = options.login? ? [] : @client.organization_memberships

    if options.login?
      puts 'Syncing login repositories'.blue
      @client.repositories(include_forks: options.forks?)
    elsif org_names.empty?
      puts 'Not a member of an organisation - syncing login repositories'.blue
      @client.repositories(include_forks: options.forks?)
    elsif !options[:org].nil?
      org = org_names.find { |name| name.casecmp(options[:org]) == 0 }
      if org.nil?
        puts "Given Org '#{options[:org]}' not accessible by login".red
        exit 1
      end
      puts "Syncing #{org} repositories".blue
      @client.organization_repositories(org, include_forks: options.forks?)
    else
      cli = HighLine.new
      org = cli.choose do |menu|
        menu.prompt = 'Which login do you want to synchronise?'.green
        menu.choices @user[:login], *org_names
      end
      puts "Syncing #{org} repositories".blue

      if org == @user[:login]
        @client.repositories(include_forks: options.forks?)
      else
        @client.organization_repositories(org, include_forks: options.forks?)
      end
    end
  end

  def sync_repositories(repositories)
    config = {
      path: options[:path].expand_path,
      forks: options.forks?,
      verbose: options.verbose?,
      log: options[:'last-commit']
    }

    syncer = RepositorySyncer.new(@client, config)
    result = syncer.sync(repositories)

    puts
    puts "Found: #{result.total}\nCloned: #{result.cloned}\nUpdated: #{result.updated}"
  rescue => e
    puts e.message.red
    exit 1
  end
end
