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
| `GIT_USER_NAME` / `GIT_USER_EMAIL` | 05 | Git identity |
| `PG_DATABASES="db1 db2"` | 08 | Creates those empty databases + extensions (Postgres uses no password) |
| `MYSQL_ROOT_PASSWORD` | 10 | Sets the MySQL root password (non-interactive, no prompt) |
| `INSTALL_ANDROID_STUDIO=1` | 11 | Installs the Android Studio GUI (optional, ~1.2 GB) |
| `INSTALL_IOS=1` | 12 | Enables the iOS module (opt-in, ~12 GB) |

## Idempotency

Everything is designed to be **re-run without side effects**: guarded installs (`brew list … || brew install`), dotfile lines added only once (`append_once`), services started only if not running, `createdb`/extensions with guards.

Test on the target machine (run it twice):

```bash
./setup.sh && ./setup.sh     # 2ª pasada: todo "ya instalado", sin duplicados
diff <(sort -u ~/.zprofile) <(sort ~/.zprofile)   # no duplicate lines
```

## Data and backups

Data (databases) and secrets do **not** live in git. The backup from the previous machine is in `~/BackupsBeforeClean/` along with its `RESTORE.md` (Postgres, MySQL, `.env`, dotfiles, inventory). The reproducible inventory is in `00. Inventory/` (`Brewfile`, versions, extensions).

## Requirements

- macOS **14+ (Sonoma)**. The Xcode Command Line Tools are installed by module 02.
