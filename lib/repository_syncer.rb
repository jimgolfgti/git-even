require 'git'
require 'pathname'

class RepositorySyncer
  class SyncResult
    attr_reader :total, :cloned, :updated

    def initialize(total, cloned, updated)
      @total = total
      @cloned = cloned
      @updated = updated
    end
  end

  def initialize(github_client, config = {})
    @client = github_client
    @base_path = Pathname.new(config[:path] || '.')
    @include_forks = config[:forks] || false
    @org = config[:org]
    @verbose = config[:verbose] || false
    @log_commits = config[:log] || false

    @total = 0
    @cloned = 0
    @updated = 0
  end

  def sync(repositories)
    repositories.each { |repo| sync_repository(repo) }
    SyncResult.new(@total, @cloned, @updated)
  end

  def sync_repository(repo)
    @total += 1

    begin
      log("Processing #{repo.name} - #{repo.description}")

      repo_dir = repository_path(repo)
      git = nil

      if @client.contributors(repo.full_name).empty?
        log("Skipping #{repo.name} - repository is empty")
        return
      end

      if Dir.exist?(repo_dir)
        git = update_repository(repo, repo_dir)
      else
        git = clone_repository(repo, repo_dir)
      end

      write_description(repo_dir, repo.description || repo.name)

      if @log_commits
        log_last_commit(repo, git)
      end

      git
    rescue => e
      raise "Failed to sync #{repo.name}: #{e.message}"
    end
  end

  private

  def repository_path(repo)
    parent_dir = @base_path.join(repo.owner.login)
    parent_dir.mkpath
    parent_dir.join(repo.name).to_s
  end

  def clone_repository(repo, repo_dir)
    log("Cloning #{repo.name} to #{repo_dir}")

    git = Git.clone(repo.ssh_url, repo_dir, bare: true)
    @cloned += 1

    log("Remote SHA #{git.log.execute.first.sha}")
    git
  end

  def update_repository(repo, repo_dir)
    log("Fetching commits from #{repo.default_branch} for #{repo.name}")

    git = Git.bare(repo_dir)
    local_sha = git.log.execute.first.sha

    git.fetch('origin', {ref: "#{repo.default_branch}:#{repo.default_branch}", prune: true, force: true})

    log("Local SHA #{local_sha}\nRemote SHA #{git.log.execute.first.sha}")

    if git.log.execute.first.sha != local_sha
      @updated += 1
      log("Updated #{repo.name}")
    end
    git
  end

  def write_description(repo_dir, description)
    FileUtils.mkdir_p(repo_dir)
    description_file = Pathname.new(File.join(repo_dir, 'description'))
    description_file.write(description)
  end

  def log_last_commit(repo, git)
    commit = git.log.execute.first
    puts "Last commit for #{repo.name}:".white
    puts "#{commit.author.name} (#{commit.author.email}) - #{commit.date.strftime('%d %B %Y %H:%M')}".light_blue.indent 2
    puts commit.message.yellow.indent 4
  end

  def log(message)
    puts message.light_cyan if @verbose
  end
end

String.class_eval do
  def indent(count, char = ' ')
    gsub(/([^\n]*)(\n|$)/) do |match|
      last_iteration = ($1 == "" && $2 == "")
      line = ""
      line << (char * count) unless last_iteration
      line << $1
      line << $2
      line
    end
  end
end
