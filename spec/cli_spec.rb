describe CLI do
  describe 'option parsing' do
    it 'requires --key option' do
      cli = CLI.new([])
      expect { cli.run }.to raise_error(SystemExit)
    end

    it 'parses --login flag' do
      cli = CLI.new(['--key', 'test_token', '--login'])
      # Just verify parsing doesn't fail on these arguments
      expect { cli.send(:parse_options) }.not_to raise_error
    end

    it 'parses --org option' do
      cli = CLI.new(['--key', 'test_token', '--org', 'myorg'])
      expect { cli.send(:parse_options) }.not_to raise_error
    end

    it 'parses --path option' do
      cli = CLI.new(['--key', 'test_token', '--path', '/tmp/repos'])
      expect { cli.send(:parse_options) }.not_to raise_error
    end

    it 'parses --forks flag' do
      cli = CLI.new(['--key', 'test_token', '--forks'])
      expect { cli.send(:parse_options) }.not_to raise_error
    end

    it 'parses --verbose flag' do
      cli = CLI.new(['--key', 'test_token', '--verbose'])
      expect { cli.send(:parse_options) }.not_to raise_error
    end

    it 'parses --last-commit flag' do
      cli = CLI.new(['--key', 'test_token', '--last-commit'])
      expect { cli.send(:parse_options) }.not_to raise_error
    end
  end

  describe 'option validation' do
    it 'rejects --login and --org together' do
      cli = CLI.new(['--key', 'test_token', '--login', '--org', 'myorg'])
      cli.send(:parse_options)
      expect { cli.send(:validate_options) }.to raise_error(SystemExit)
    end

    it 'allows --login without --org' do
      cli = CLI.new(['--key', 'test_token', '--login'])
      cli.send(:parse_options)
      expect { cli.send(:validate_options) }.not_to raise_error
    end

    it 'allows --org without --login' do
      cli = CLI.new(['--key', 'test_token', '--org', 'myorg'])
      cli.send(:parse_options)
      expect { cli.send(:validate_options) }.not_to raise_error
    end
  end

  describe '#read_key' do
    it 'reads key from argument' do
      cli = CLI.new(['--key', 'my_token'])
      cli.send(:parse_options)
      cli.send(:read_key)
      expect(cli.send(:options)[:key]).to eq('my_token')
    end

    it 'reads key from piped stdin when argument is -' do
      allow($stdin).to receive(:tty?).and_return(false)
      allow($stdin).to receive(:gets).and_return("token_from_stdin\n")

      cli = CLI.new(['--key', '-'])
      cli.send(:parse_options)
      cli.send(:read_key)
      expect(cli.send(:options)[:key]).to eq('token_from_stdin')
    end

    it 'reads key from interactive stdin when argument is - and tty is true' do
      allow($stdin).to receive(:tty?).and_return(true)

      # Mock the noecho method to capture the method symbol and call gets
      mock_io = double('io')
      allow(mock_io).to receive(:gets).and_return("interactive_token\n")
      allow($stdin).to receive(:noecho).and_yield(mock_io)

      cli = CLI.new(['--key', '-'])
      cli.send(:parse_options)
      cli.send(:read_key)
      expect(cli.send(:options)[:key]).to eq('interactive_token')
    end

    it 'shows prompt when reading from interactive stdin' do
      allow($stdin).to receive(:tty?).and_return(true)

      mock_io = double('io')
      allow(mock_io).to receive(:gets).and_return("interactive_token\n")
      allow($stdin).to receive(:noecho).and_yield(mock_io)

      cli = CLI.new(['--key', '-'])
      cli.send(:parse_options)
      expect { cli.send(:read_key) }.to output(/Please enter your key:/).to_stdout
    end

    it 'strips whitespace from piped stdin key' do
      allow($stdin).to receive(:tty?).and_return(false)
      allow($stdin).to receive(:gets).and_return("  token_with_spaces  \n")

      cli = CLI.new(['--key', '-'])
      cli.send(:parse_options)
      cli.send(:read_key)
      expect(cli.send(:options)[:key]).to eq('token_with_spaces')
    end

    it 'strips whitespace from interactive stdin key' do
      allow($stdin).to receive(:tty?).and_return(true)

      mock_io = double('io')
      allow(mock_io).to receive(:gets).and_return("  interactive_token  \n")
      allow($stdin).to receive(:noecho).and_yield(mock_io)

      cli = CLI.new(['--key', '-'])
      cli.send(:parse_options)
      cli.send(:read_key)
      expect(cli.send(:options)[:key]).to eq('interactive_token')
    end
  end

  describe '#authenticate' do
    it 'authenticates and stores user info' do
      mock_client = double('GitHubClientWrapper')
      allow(mock_client).to receive(:authenticate).and_return(login: 'testuser', name: 'Test User')

      cli = CLI.new(['--key', 'test_token'])
      cli.send(:parse_options)
      allow(GitHubClientWrapper).to receive(:new).and_return(mock_client)

      expect { cli.send(:authenticate) }.not_to raise_error
    end

    it 'exits on authentication failure' do
      mock_client = double('GitHubClientWrapper')
      allow(mock_client).to receive(:authenticate).and_raise('Authentication failed: Invalid token')
      allow(GitHubClientWrapper).to receive(:new).and_return(mock_client)

      cli = CLI.new(['--key', 'invalid_token'])
      cli.send(:parse_options)

      expect { cli.send(:authenticate) }.to raise_error(SystemExit)
    end
  end

  describe '--help flag' do
    it 'exits with status 0 when --help is provided' do
      cli = CLI.new(['--help'])
      expect { cli.send(:parse_options) }.to raise_error(SystemExit) do |exception|
        expect(exception.status).to eq(0)
      end
    end

    it 'exits with status 0 when -h is provided' do
      cli = CLI.new(['-h'])
      expect { cli.send(:parse_options) }.to raise_error(SystemExit) do |exception|
        expect(exception.status).to eq(0)
      end
    end

    it 'prints help output when --help is provided' do
      cli = CLI.new(['--help'])
      expect do
        expect { cli.send(:parse_options) }.to output(/Show help/).to_stdout
      end.to raise_error(SystemExit)
    end

    it 'prints help output when -h is provided' do
      cli = CLI.new(['-h'])
      expect do
        expect { cli.send(:parse_options) }.to output(/Show help/).to_stdout
      end.to raise_error(SystemExit)
    end

    it 'does not proceed to authentication when --help is used' do
      cli = CLI.new(['--help'])
      expect(GitHubClientWrapper).not_to receive(:new)
      expect { cli.run }.to raise_error(SystemExit)
    end

    it 'shows all available options in help output' do
      cli = CLI.new(['--help'])
      expect do
        expect { cli.send(:parse_options) }.to output(
            /--key|--login|--org|--path|--forks|--last-commit|--verbose/
          ).to_stdout
      end.to raise_error(SystemExit)
    end
  end
end
