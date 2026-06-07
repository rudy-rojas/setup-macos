# 05 · Git & GitHub

Installs git + GitHub CLI, applies the TNB global config and authenticates `gh` only if missing.

- `brew install git gh jq`.
- `git config --global`: identity, `init.defaultBranch main`, `pull.rebase false`, `core.editor "code --wait"`.
- `gh`: web login **only if** `gh auth status` fails (never re-prompts an already authenticated user). In an orchestrated run (`./setup.sh`) this login is **deferred to the end**, after everything is installed, so as not to interrupt the process; when run alone (`./setup.sh 05`) it happens right away.

## Usage
```bash
./setup.sh 05
# custom identity:
GIT_USER_NAME="Your Name" GIT_USER_EMAIL="you@email.com" ./setup.sh 05
```

## Notes
- Default identity: `TheNationalBuilders <tnb@thenationalbuilders.com>` (override with the env vars).
- `gh auth login --web` opens the browser (interactive step).
- `gh auth status` is scoped to `--hostname github.com` so that an enterprise host with an expired token does not trigger a re-login.
