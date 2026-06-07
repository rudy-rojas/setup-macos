# 10 · MySQL + DBeaver

Installs MySQL via **Homebrew** (managed with `brew services` — easy to start/stop, unlike the official installer) + DBeaver + services panel.

- `brew install mysql`; `brew services start mysql`; waits with `mysqladmin ping`.
- (Optional) set the root password with `MYSQL_ROOT_PASSWORD` (no secret is stored in the repo).
- Casks: `dbeaver-community`, `brewservicesmenubar`.

## Usage
```bash
./setup.sh 10
# set root to the password your .env uses (the one v1/tnb-backend expects):
MYSQL_ROOT_PASSWORD='<your-password>' ./setup.sh 10
```

## Notes
- MySQL from brew installs **without** a root password. Connect with `mysql -u root`. Set it with the env var or `mysql_secure_installation` (interactive).
- To restore your 3 databases (`tnb-db-develop`, `nexus_erp`, `testscript`): see `~/BackupsBeforeClean/RESTORE.md`.
- Major version jumps (`<8.4` → `9.x`) require starting `mysql@8.4` first; `brew install mysql` installs the current line.
- We chose brew over the official Oracle installer precisely to avoid the shutdown problem we had (PID file / launchd).
