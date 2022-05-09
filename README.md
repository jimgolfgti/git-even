# Git-Even
A script for synchronising repositories hosted on GitHub.com

## Getting started
Clone the repository and install dependencies (requires bundler)
``` console
$ bundle install
```
### Optional
Make `git-even` a Git command  
Add the repository directory to your `PATH`
``` console
$ echo "export PATH=$PWD:\$PATH" >>~/.zshrc
```

## Usage
Run `git-even` with `--help` to see all available options

The only mandatory argument is `--key`, or short `-k` to specify a [GitHub Personal Access Token](https://github.com/settings/tokens)  
You will need to have a token with a minimum of `repo` permission  
This can be given directly `-k ghp_xxxxxxxxxxxxxxxx`, piped to stdin `cat keyfile | git even -k -` or when prompted
``` console
git even -k -
Please input your key:
```

Repositories are cloned to folders based on the owner login name by default into the current directory  
Pass `--path` to override the base directory

Forks are not cloned by default, pass `--forks` to include them

By default if the login the token belongs to is not a member of an organisation then only the login's repositories are cloned  
If the token's login does belong to at least one organisation then you will be prompted to choose which login to clone  
You can automate this by passing either `--login` or `--org an-org`, but obviously not both!

### Example Usage
``` console
$ cat my-ghp-token | git even --key - --login --path ~/repos
Authenticated as jimgolfgti (James Hopper)
Syncing login repositories

Cloning git-even to /Users/jimgolfgti/repos/jimgolfgti/git-even
$ docker run -d --rm --name gitlist -p 8888:80 -v ~/repos:/repos zoredache/gitlist
8ef4fc79213281ef7905448d6556e8bb1c9e37772aeb498061028a04dc2f3ea4
$ open http://localhost:8888
$ docker stop gitlist
```

## Limitations
 * Currently does not synchronise Collaborator repositories belonging to the logged in user
 * All repositories are cloned/updated using SSH+GIT protocol (Who uses HTTPS?)
