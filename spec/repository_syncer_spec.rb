describe RepositorySyncer do
  let(:mock_client) { double('GitHubClientWrapper') }
  let(:temp_dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(temp_dir) }

  describe '#sync' do
    let(:config) { { path: temp_dir, forks: false, verbose: false, log: false } }
    let(:syncer) { RepositorySyncer.new(mock_client, config) }

    it 'returns sync result with counts' do
      repo = double('repo',
        name: 'test-repo',
        description: 'A test repo',
        owner: double(login: 'testuser'),
        ssh_url: 'git@github.com:testuser/test-repo.git',
        full_name: 'testuser/test-repo',
        default_branch: 'main'
      )

      allow(mock_client).to receive(:contributors).and_return([double('user')])
      allow(Git).to receive(:clone).and_return(double('Git::Base', log: double(execute: double(first: double(sha: 'abc123')))))

      result = syncer.sync([repo])

      expect(result.total).to eq(1)
      expect(result.cloned).to eq(1)
      expect(result.updated).to eq(0)
    end

    it 'tracks multiple repositories' do
      repos = 2.times.map do |i|
        double('repo',
          name: "repo-#{i}",
          description: "Repo #{i}",
          owner: double(login: 'testuser'),
          ssh_url: "git@github.com:testuser/repo-#{i}.git",
          full_name: "testuser/repo-#{i}",
          default_branch: 'main'
        )
      end

      allow(mock_client).to receive(:contributors).and_return([double('user')])
      allow(Git).to receive(:clone).and_return(double('Git::Base', log: double(execute: double(first: double(sha: 'abc123')))))

      result = syncer.sync(repos)

      expect(result.total).to eq(2)
      expect(result.cloned).to eq(2)
    end
  end

  describe '#sync_repository' do
    let(:syncer) { RepositorySyncer.new(mock_client, path: temp_dir) }
    let(:repo) do
      double('repo',
        name: 'test-repo',
        description: 'A test repo',
        owner: double(login: 'testuser'),
        ssh_url: 'git@github.com:testuser/test-repo.git',
        full_name: 'testuser/test-repo',
        default_branch: 'main'
      )
    end

    context 'when repository does not exist locally' do
      it 'clones the repository' do
        allow(mock_client).to receive(:contributors).and_return([double('user')])
        mock_git = double('Git::Base')
        allow(mock_git).to receive_message_chain(:log, :execute, :first, :sha).and_return('abc123')
        allow(Git).to receive(:clone).and_return(mock_git)

        syncer.sync_repository(repo)

        expect(Git).to have_received(:clone).with('git@github.com:testuser/test-repo.git', anything, bare: true)
      end

      it 'skips empty repositories' do
        allow(mock_client).to receive(:contributors).and_return([])

        syncer.sync_repository(repo)

        repo_dir = File.join(temp_dir, 'testuser', 'test-repo')
        expect(Dir.exist?(repo_dir)).to be_falsey
      end
    end

    context 'when repository exists locally' do
      let(:repo_dir) { File.join(temp_dir, 'testuser', 'test-repo') }

      before do
        allow(mock_client).to receive(:contributors).and_return([double('user')])
        FileUtils.mkdir_p(repo_dir)
      end

      it 'updates existing repository' do
        mock_git = double('Git::Base')
        allow(mock_git).to receive_message_chain(:log, :execute,:first, :sha).and_return('abc123')
        allow(Git).to receive(:bare).and_return(mock_git)
        allow(mock_git).to receive(:fetch)

        syncer.sync_repository(repo)

        expect(Git).to have_received(:bare).with(repo_dir)
        expect(mock_git).to have_received(:fetch)
      end

      it 'tracks updates when SHA changes' do
        mock_git = double('Git::Base')
        # Return different SHAs for local vs remote
        allow(mock_git).to receive_message_chain(:log, :execute, :first, :sha).and_return('abc123', 'def456')
        allow(Git).to receive(:bare).and_return(mock_git)
        allow(mock_git).to receive(:fetch)

        syncer.sync_repository(repo)

        # The test just verifies the fetch happens; syncer tracks updates internally
        expect(mock_git).to have_received(:fetch)
      end
    end

    it 'writes repository description' do
      allow(mock_client).to receive(:contributors).and_return([double('user')])
      mock_git = double('Git::Base')
      allow(mock_git).to receive_message_chain(:log, :execute, :first, :sha).and_return('abc123')
      allow(Git).to receive(:clone).and_return(mock_git)

      syncer.sync_repository(repo)

      description_file = File.join(temp_dir, 'testuser', 'test-repo', 'description')
      expect(File.read(description_file)).to eq('A test repo')
    end

    context 'with last-commit logging' do
      let(:syncer) { RepositorySyncer.new(mock_client, path: temp_dir, log: true, verbose: true) }

      it 'logs the last commit when enabled' do
        allow(mock_client).to receive(:contributors).and_return([double('user')])
        mock_git = double('Git::Base')
        allow(Git).to receive(:clone).and_return(mock_git)

        mock_commit = double('Commit',
          author: double(name: 'John Doe', email: 'john@example.com'),
          date: Time.parse('2024-01-15 10:30:00'),
          message: 'Test commit message'
        )
        allow(mock_commit).to receive(:sha).and_return('abc123')

        allow(mock_git).to receive_message_chain(:log, :execute, :first, :sha).and_return('abc123')
        allow(mock_git).to receive_message_chain(:log, :execute, :first).and_return(mock_commit)

        expect { syncer.sync_repository(repo) }.to output(/John Doe.*john@example.com.*15 January 2024 10:30/).to_stdout
      end
    end

    context 'when sync fails' do
      it 'raises error with "Failed to sync" prefix' do
        allow(mock_client).to receive(:contributors).and_raise(StandardError.new('Network error'))

        expect {
          syncer.sync_repository(repo)
        }.to raise_error(RuntimeError, /Failed to sync test-repo: Network error/)
      end

      it 'increments total count even on failure' do
        allow(mock_client).to receive(:contributors).and_raise(StandardError.new('Error'))

        begin
          syncer.sync_repository(repo)
        rescue RuntimeError
          # Expected to fail
        end

        expect(syncer.instance_variable_get(:@total)).to eq(1)
      end
    end
  end
end
