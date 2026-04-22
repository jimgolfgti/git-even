describe 'Integration: Full sync workflow' do
  let(:temp_dir) { Dir.mktmpdir }
  let(:mock_github) { double('GitHubClientWrapper') }
  let(:syncer) { RepositorySyncer.new(mock_github, path: temp_dir, verbose: true) }

  after { FileUtils.rm_rf(temp_dir) }

  it 'clones multiple repositories and tracks stats' do
    repos = [
      double('repo',
        name: 'repo-1',
        description: 'First repo',
        owner: double(login: 'testuser'),
        ssh_url: 'git@github.com:testuser/repo-1.git',
        full_name: 'testuser/repo-1',
        default_branch: 'main'
      ),
      double('repo',
        name: 'repo-2',
        description: 'Second repo',
        owner: double(login: 'testuser'),
        ssh_url: 'git@github.com:testuser/repo-2.git',
        full_name: 'testuser/repo-2',
        default_branch: 'main'
      )
    ]

    allow(mock_github).to receive(:contributors).and_return([double('user')])
    mock_git = double('Git::Base')
    allow(mock_git).to receive_message_chain(:log, :execute, :first, :sha).and_return('abc123')
    allow(Git).to receive(:clone).and_return(mock_git)

    result = syncer.sync(repos)

    expect(result.total).to eq(2)
    expect(result.cloned).to eq(2)
    expect(result.updated).to eq(0)
  end

  it 'handles mixed clone and update operations' do
    # First repo - will be cloned
    repo1 = double('repo',
      name: 'new-repo',
      description: 'New repo',
      owner: double(login: 'testuser'),
      ssh_url: 'git@github.com:testuser/new-repo.git',
      full_name: 'testuser/new-repo',
      default_branch: 'main'
    )

    # Second repo - already exists locally
    repo2 = double('repo',
      name: 'existing-repo',
      description: 'Existing repo',
      owner: double(login: 'testuser'),
      ssh_url: 'git@github.com:testuser/existing-repo.git',
      full_name: 'testuser/existing-repo',
      default_branch: 'main'
    )

    # Pre-create the existing repo
    existing_dir = File.join(temp_dir, 'testuser', 'existing-repo')
    FileUtils.mkdir_p(existing_dir)

    allow(mock_github).to receive(:contributors).and_return([double('user')])

    # Mock for cloning new repo
    clone_git = double('Git::Base')
    allow(clone_git).to receive_message_chain(:log, :execute, :first, :sha).and_return('abc123')

    # Mock for updating existing repo
    update_git = double('Git::Base')
    allow(update_git).to receive_message_chain(:log, :execute, :first, :sha).and_return('old_sha', 'new_sha')
    allow(update_git).to receive(:fetch)

    allow(Git).to receive(:clone).and_return(clone_git)
    allow(Git).to receive(:bare).and_return(update_git)

    result = syncer.sync([repo1, repo2])

    expect(result.total).to eq(2)
    expect(result.cloned).to eq(1)
    expect(result.updated).to eq(1)
  end

  it 'creates directory structure with owner login' do
    repo = double('repo',
      name: 'my-repo',
      description: 'My repo',
      owner: double(login: 'my-org'),
      ssh_url: 'git@github.com:my-org/my-repo.git',
      full_name: 'my-org/my-repo',
      default_branch: 'main'
    )

    allow(mock_github).to receive(:contributors).and_return([double('user')])
    mock_git = double('Git::Base')
    allow(mock_git).to receive_message_chain(:log, :execute, :first, :sha).and_return('abc123')
    allow(Git).to receive(:clone).and_return(mock_git)

    syncer.sync_repository(repo)

    repo_dir = File.join(temp_dir, 'my-org', 'my-repo')
    expect(Dir.exist?(repo_dir)).to be_truthy
    expect(File.exist?(File.join(repo_dir, 'description'))).to be_truthy
  end
end
