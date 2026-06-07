# 08 · PostgreSQL 16

Installs `postgresql@16`, adds it to the PATH (keg-only, **arch-aware**), starts the service, and prepares extensions.

- `brew install postgresql@16`; PATH via `$(brew --prefix postgresql@16)/bin` with `\$PATH` **escaped** (not frozen).
- `brew services start postgresql@16`; waits with `pg_isready`.
- Creates databases (optional) with `PG_DATABASES="..."` and applies `citext`/`pgcrypto`/`pg_trgm` (`CREATE EXTENSION IF NOT EXISTS`).

## Usage
```bash
./setup.sh 08
PG_DATABASES="plus_dev tnb_dev" ./setup.sh 08   # also creates those empty databases + extensions
```

## Notes
- By default it does **not** create databases: restore your real data from `~/BackupsBeforeClean/RESTORE.md` (`globals.sql` + `pg_restore`).
- The superuser is your macOS user (no password); the `postgres` role does **not** exist by default — `globals.sql` creates it during the restore.
- `postgresql@16` is keg-only by design (not a bug): hence the explicit PATH. Do not use `exec zsh -l` in scripts (it replaces the shell and aborts everything after it).
