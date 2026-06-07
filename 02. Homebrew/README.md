# 02 · Homebrew

Installs Homebrew **arch-aware** and adds it to the zsh PATH, idempotently.

- **Ensures the Xcode Command Line Tools first** (`ensure_clt`), a Homebrew dependency: unattended path (`softwareupdate`) with a fallback to the graphical installer (`xcode-select --install`). No-op if CLT or the full Xcode is already present.
- Detects the prefix by architecture: **arm64 → `/opt/homebrew`**, **x86_64 → `/usr/local`** (via `lib/common.sh`).
- Installs only if missing (`NONINTERACTIVE=1`, no prompts); re-running is a no-op.
- Adds `eval "$(<prefix>/bin/brew shellenv)"` to `${ZDOTDIR:-$HOME}/.zprofile` **exactly once** (`append_once`).
- Activates brew in the current session and installs the base CLI tools: `jq`, `tree` (jq is used by module 06).

## Usage
```bash
./setup.sh 02                       # from the repo root
"02. Homebrew/setup-homebrew.sh"    # or directly
```

## Notes
- On **Apple Silicon**, without the `shellenv` line you get `zsh: command not found: brew` because `/opt/homebrew/bin` is not on the PATH by default — this module fixes that.
- Minimum macOS supported by Homebrew: **14.0 (Sonoma)**.
- The Xcode Command Line Tools are installed automatically in step 0 (it can take several minutes and needs network/`sudo`). If the unattended path is unavailable, Apple's graphical installer opens and the script waits for you to finish.
- The **full Xcode** (~12 GB, e.g. from an `Xcode_*.xip`) is not touched here; that lives in the **`12. iOS`** module (opt-in), which is where it is actually needed.
- The complete set of packages you use today is in **`00. Inventory/Brewfile`** → reproducible with `brew bundle install --file="00. Inventory/Brewfile"`.
