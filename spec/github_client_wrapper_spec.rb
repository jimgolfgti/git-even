describe GitHubClientWrapper do
  let(:access_token) { 'test_token_123' }
  let(:mock_octokit) { double('Octokit::Client') }
  let(:client) { GitHubClientWrapper.new(access_token) }

  before do
    allow(Octokit::Client).to receive(:new).and_return(mock_octokit)
  end

  describe '#authenticate' do
    it 'returns user info on successful authentication' do
      user = double('user', login: 'testuser', name: 'Test User')
      allow(mock_octokit).to receive(:user).and_return(user)

      result = client.authenticate
      expect(result).to eq(login: 'testuser', name: 'Test User')
    end

    it 'raises error on unauthorized access' do
      allow(mock_octokit).to receive(:user).and_raise(Octokit::Unauthorized.new)

      expect { client.authenticate }.to raise_error(/Authentication failed/)
    end
  end

  describe '#organization_memberships' do
    it 'returns list of organizations' do
      org1 = double('org', organization: double(login: 'org1'))
      org2 = double('org', organization: double(login: 'org2'))
      allow(mock_octokit).to receive(:organization_memberships).and_return([org1, org2])

      result = client.organization_memberships
      expect(result).to eq(['org1', 'org2'])
    end

    it 'returns empty list when no organizations' do
      allow(mock_octokit).to receive(:organization_memberships).and_return([])

      result = client.organization_memberships
      expect(result).to be_empty
    end
  end

  describe '#repositories' do
    it 'returns user repositories excluding forks by default' do
      repo1 = double('repo', name: 'repo1', fork: false)
      repo2 = double('repo', name: 'repo2', fork: true)
      allow(mock_octokit).to receive(:repositories).and_return([repo1, repo2])

      result = client.repositories
      expect(result.length).to eq(1)
      expect(result.first.name).to eq('repo1')
    end

    it 'includes forks when requested' do
      repo1 = double('repo', name: 'repo1', fork: false)
      repo2 = double('repo', name: 'repo2', fork: true)
      allow(mock_octokit).to receive(:repositories).and_return([repo1, repo2])

      result = client.repositories(include_forks: true)
      expect(result.length).to eq(2)
    end
  end

  describe '#organization_repositories' do
    it 'returns organization repositories' do
      repo1 = double('repo', name: 'repo1', fork: false)
      repo2 = double('repo', name: 'repo2', fork: true)
      allow(mock_octokit).to receive(:organization_repositories).with('test-org', type: 'sources', sort: 'full_name').and_return([repo1])
      allow(mock_octokit).to receive(:organization_repositories).with('test-org', type: 'all', sort: 'full_name').and_return([repo1, repo2])

      result = client.organization_repositories('test-org')
      expect(result.length).to eq(1)

      result_with_forks = client.organization_repositories('test-org', include_forks: true)
      expect(result_with_forks.length).to eq(2)
    end
  end

  describe '#contributors' do
    it 'returns contributors for a repository' do
      contrib1 = double('contrib', login: 'user1', contributions: 5)
      contrib2 = double('contrib', login: 'user2', contributions: 3)
      allow(mock_octokit).to receive(:contributors).and_return([contrib1, contrib2])

      result = client.contributors('user/repo')
      expect(result.length).to eq(2)
    end

    it 'returns empty array on error' do
      allow(mock_octokit).to receive(:contributors).and_raise(StandardError)

      result = client.contributors('user/repo')
      expect(result).to be_empty
    end
  end
end
