require 'octokit'

class GitHubClientWrapper
  def initialize(access_token)
    @client = Octokit::Client.new(access_token: access_token, auto_paginate: true)
  end

  def authenticate
    user = @client.user
    { login: user.login, name: user.name }
  rescue Octokit::Unauthorized => e
    raise "Authentication failed: #{e.message}"
  end

  def organization_memberships
    @client.organization_memberships(state: 'active').map { |org| org.organization.login }
  end

  def repositories(type: 'owner', sort: 'full_name', include_forks: false)
    @client.repositories(nil, type: type, sort: sort).filter do |repo|
      include_forks || !repo.fork
    end
  end

  def organization_repositories(org, include_forks: false)
    type = include_forks ? 'all' : 'sources'
    @client.organization_repositories(org, type: type, sort: 'full_name')
  end

  def contributors(repo_full_name)
    @client.contributors(repo_full_name, true)
  rescue
    []
  end
end
