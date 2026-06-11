# setup-macos

**Idempotent and modular** provisioning of a Mac for **web/mobile** development (TNB stack: PLUS, tnb-backend, tnb-mobile, v1). **Arch-aware**: works on Apple Silicon (`/opt/homebrew`) and Intel (`/usr/local`).

## How it works

- Each module is a `NN. Name/` folder with its own `setup-NN.sh` (+ `README.md`) and can be run independently.
- `lib/common.sh` provides the idempotent helpers: `append_once` (dotfiles without duplication), `brew_ensure`/`cask_ensure`/`service_ensure`, architecture detection, and ZDOTDIR-aware paths.
- `setup.sh` discovers and orchestrates the modules in order.

## Usage

```bash
./setup.sh              # all modules in order
./setup.sh 04           # only module 04
./setup.sh --from 05    # from module 05 onward
./setup.sh --skip 12    # skip a module
./setup.sh --list       # list detected modules
./setup.sh --dry-run    # show what would run, without executing
```

## Modules

| #  | Module       | What it does |
|----|--------------|----------|
| 00 | Inventory    | Snapshot of tools/versions (not executable) |
| 01 | Terminals    | Terminal · iTerm2 · Alacritty |
| 02 | Homebrew     | Arch-aware Homebrew + `shellenv` + base CLI |
| 03 | Python       | uv + Python 3.12 by default |
| 04 | Node         | fnm + Node LTS + pnpm (arch-aware) |
| 05 | Git          | git + gh + global TNB config |
| 06 | VS Code      | cask + extensions + settings (merge) |
| 07 | Claude Code  | native installer |
| 08 | PostgreSQL   | postgresql@16 + service + extensions |
| 09 | Redis        | redis + service |
| 10 | MySQL        | mysql (brew services) + DBeaver |
| 11 | Android      | watchman · JDK 17 · Android SDK · EAS (+ Android Studio **optional**) |
| 12 | iOS          | Xcode + CocoaPods (**opt-in**: `INSTALL_IOS=1`) |
| 13 | Ops/VPS      | sshpass |

## Configuration (`setup.env`)

For an **unattended** installation (no prompts mid-install), define the
parameters in a `setup.env` file at the root. `setup.sh` loads it at startup and
exports the variables to all modules:

```bash
cp setup.env.example setup.env   # plantilla versionada → tu copia (gitignored)
# edit setup.env with your values
./setup.sh
```

`setup.env` is in `.gitignore` (it may contain secrets such as `MYSQL_ROOT_PASSWORD`);
the `setup.env.example` template is versioned. Without the file, everything runs with the
default values. Variables can also be passed inline (`VAR=… ./setup.sh`).

| Variable | Module | Effect |
|---|---|---|
| `GIT_USER_NAME` / `GIT_USER_EMAIL` | 05 | Git identity. **Explicit override only**: an identity already set on the machine is kept; the TNB default applies only when none is configured |
| `PG_DATABASES="db1 db2"` | 08 | Creates those empty databases + extensions (Postgres uses no password) |
| `MYSQL_ROOT_PASSWORD` | 10 | Sets the MySQL root password (non-interactive; never shown in `ps` or `bash -x`) |
| `INSTALL_ANDROID_STUDIO=1` | 11 | Installs the Android Studio GUI (optional, ~1.2 GB) |
| `INSTALL_IOS=1` | 12 | Enables the iOS module (opt-in, ~12 GB) |
| `PG_VERSION` `PYTHON_VERSION` `JDK_VERSION` `ANDROID_API` `ANDROID_BUILD_TOOLS` | 08/03/11 | Pin a different toolchain version without editing modules (single source of truth: `lib/common.sh`) |
| `SETUP_TIMEOUT` | 08/09/10 | Seconds to wait for a service to become ready (default 30; raise on slow machines) |
| `NO_TERMINAL_HANDOFF=1` | 01 | Disable the automatic Terminal.app→iTerm2 hand-off (see Shell) |
| `SETUP_NO_CLEAR=1` | — | Don't clear the screen at startup (a real run shows a banner, `[N/M]` progress and per-module timing; `--list`/`--dry-run`/piped output stay plain) |

## Module dependencies & order

Modules are numbered in dependency order; running `./setup.sh` (or `--from NN`) respects it. When running a single module standalone, mind the prerequisites:

- **02 Homebrew** is the base for everything — every other module sources `lib/common.sh`, which fails fast with a clear message (`run module 02 first`) if `brew` is missing.
- **04 Node** provides `node`/`npm`, needed by **11 Android** for the EAS CLI.
- **06 VS Code** needs its `code` CLI (installed by its own cask).

Prerequisite checks are explicit (`load_brew`, `require_cmd`), so a missing dependency produces an actionable error instead of a cryptic failure deep inside a step.

## Shell

The modules write PATH/env to the **zsh** init files (`~/.zprofile`, `~/.zshrc`). If your login shell isn't zsh, `setup.sh` warns once up front; switch with `chsh -s /bin/zsh` or add those files to your shell's init.

### Terminal.app → iTerm2 hand-off

Terminal.app rewrites its own preferences when it quits, so a Gruvbox profile written while the launching Terminal.app is open is lost the moment you close it. To make it persist, the profile must be applied while Terminal.app is **not** running.

So when you run `./setup.sh` **from Terminal.app**, the work happens in two stages:

1. **Stage 1 (in Terminal.app):** module 01 installs iTerm2/Alacritty and configures everything **except** Terminal.app (it runs with `--no-terminal-app`), then setup relaunches the rest **inside iTerm2** (reusing the same `sudo` session — no second password prompt).
2. **Stage 2 (in iTerm2):** setup **closes Terminal.app**, applies the Terminal.app profile (now it sticks), and continues with modules 02→, dropping you into a configured login shell.

It only triggers on a multi-module run started from Terminal.app, runs once (guarded against re-entry), and if the hand-off can't happen (iTerm2 can't be launched, or module 01 is the only module to run) it configures Terminal.app in place instead — the profile is never skipped. Disable the hand-off with `NO_TERMINAL_HANDOFF=1`. Starting from iTerm2 (or any non-Terminal.app terminal) needs no hand-off — the profile persists normally.

## Idempotency

Everything is designed to be **re-run without side effects**: guarded installs (`brew list … || brew install`), dotfile lines added only once (`append_once`), services started only if not running, `createdb`/extensions with guards.

Test on the target machine (run it twice):

```bash
./setup.sh && ./setup.sh     # 2ª pasada: todo "ya instalado", sin duplicados
diff <(sort -u ~/.zprofile) <(sort ~/.zprofile)   # no duplicate lines
```

## Quality / CI

A quality gate keeps the scripts robust without running a full install:

```bash
scripts/check.sh    # shellcheck + bash -n syntax + --list/--dry-run smoke test
```

The same checks run in CI (`.github/workflows/ci.yml`) on every push/PR: **shellcheck** and **syntax** on Linux, the **`--list`/`--dry-run` smoke test** on macOS (where `lib/common.sh` is allowed to run). `shellcheck` locally: `brew install shellcheck`.

## Data and backups

Data (databases) and secrets do **not** live in git. The backup from the previous machine is in `~/BackupsBeforeClean/` along with its `RESTORE.md` (Postgres, MySQL, `.env`, dotfiles, inventory). The reproducible inventory is in `00. Inventory/` (`Brewfile`, versions, extensions).

## Requirements

- macOS **14+ (Sonoma)**. The Xcode Command Line Tools are installed by module 02.
