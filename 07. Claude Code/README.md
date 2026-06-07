# 07 · Claude Code

Installs Claude Code with the **official native installer**.

- `curl -fsSL https://claude.ai/install.sh | bash` → binary at `~/.local/bin/claude` (self-updating).
- Ensures `~/.local/bin` on the PATH; runs `claude --version` and `claude doctor`.

## Usage
```bash
./setup.sh 07
```

## Notes
- Requires a **paid** account (Pro/Max/Team/Enterprise/Console) or an API provider (Bedrock/Vertex/Foundry); the free Claude.ai plan does **not** grant access.
- Do **not** mix with the npm version (`@anthropic-ai/claude-code`) or the Homebrew cask: they can shadow the native binary on the PATH. `claude doctor` detects this.
- The first time, run `claude` in a project to open the login in the browser.
