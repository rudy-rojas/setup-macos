# 00 · Environment inventory

Snapshot of the tools and versions on the **current Mac**, taken on **2026-06-06**, before migrating/wiping the machine. It serves to (1) reproduce the environment on the new Mac and (2) provide a real baseline for optimizing the `setup-macos` scripts.

- **System:** macOS 15.7.1 · **Intel (x86_64)** · Homebrew at `/usr/local`
- ⚠️ If the new Mac is **Apple Silicon**, Homebrew will live at `/opt/homebrew`: the commands are the same, only the paths of the *keg-only* binaries change (e.g. `postgresql@16`).

## Files

| File | What it contains |
|---|---|
| `Brewfile` | **Top-level** Homebrew packages (formulae + casks). Reproducible with `brew bundle`. |
| `tool-versions.md` | Readable table of versions and paths for each tool. |
| `brew-formulae-versions.txt` | All installed formulae with version (includes dependencies). |
| `brew-casks-versions.txt` | Installed casks with version. |
| `vscode-extensions.txt` | 52 VS Code extensions with version. |
| `npm-global.txt` | Global npm packages. |

## Reproduce on the new Mac

```bash
# 1. Homebrew  →  see the repo's main script
# 2. Formulae + casks in a single pass:
brew bundle install --file="00. Inventory/Brewfile"

# 3. VS Code extensions:
while read -r ext; do code --install-extension "${ext%@*}"; done < "00. Inventory/vscode-extensions.txt"

# 4. Global npm packages (after installing Node): see npm-global.txt
#    → eas-cli, n8n, uipro-cli (claude@0.1.1 is leftover: use the native installer)
```

## What Homebrew does NOT manage (changing the manager on the new machine)

| Tool | Current state | Plan on the new machine |
|---|---|---|
| **Node.js** v24.11.1 | Official `.pkg` installer (root binary at `/usr/local/bin/node`) | Migrate to **fnm** |
| **Python** 3.14 | `python@3.11` + `python@3.14` via brew (`python3` → 3.14) | Migrate to **uv** (Python 3.12 pinned) |
| **MySQL** 8.0.44 | Official Oracle installer at `/usr/local/mysql` | To be decided (brew `mysql` vs installer) |
| **Java** 17.0.19 | `openjdk@17` via brew | Same (the draft mentioned `zulu@17`) |
| **Claude Code** 2.1.167 | Native installer at `~/.local/bin/claude` | Native installer |

## Databases and secrets

The **PostgreSQL/MySQL dumps**, the **dotfiles** (`.zshrc`, `.zprofile`, `.gitconfig`) and the `.env` files are **NOT** in git because they contain data/credentials. They live in `~/BackupsBeforeClean/` — the restore guide is in **`~/BackupsBeforeClean/RESTORE.md`**.
