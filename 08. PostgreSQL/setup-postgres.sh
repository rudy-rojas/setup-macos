#!/usr/bin/env bash
# =============================================================================
# 08. PostgreSQL 16 — installs, keg-only PATH (arch-aware), service, extensions.
# By default does NOT create databases: data is restored from ~/BackupsBeforeClean.
# Pass PG_DATABASES="db1 db2" to create empty databases with extensions.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "PostgreSQL 16"

brew_ensure postgresql@16

# postgresql@16 is keg-only → add its bin to the PATH (arch-agnostic via brew --prefix).
# Escape \$PATH so it stays LITERAL in ~/.zshrc (re-evaluated in every shell, not frozen).
PG_BIN="$("$BREW" --prefix postgresql@16)/bin"
append_once "$ZSHRC" "export PATH=\"$PG_BIN:\$PATH\""
export PATH="$PG_BIN:$PATH"        # in THIS session (do NOT use 'exec zsh -l': it would abort the script)

# Service.
service_ensure postgresql@16

# Wait until it accepts connections before using it.
log "waiting for PostgreSQL to accept connections…"
tries=0
until pg_isready -q; do
  tries=$((tries + 1)); [ "$tries" -ge 30 ] && die "PostgreSQL did not respond after 30s."; sleep 1
done
ok "PostgreSQL active ($(psql --version | awk '{print $3}'))"

# Create project databases (optional) + extensions, idempotent.
EXTS="citext pgcrypto pg_trgm"
if [[ -n "${PG_DATABASES:-}" ]]; then
  for DB in ${PG_DATABASES}; do
    if psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB'" | grep -q 1; then
      ok "database '$DB' (already exists)"
    else
      log "createdb $DB"; createdb "$DB"
    fi
    for e in $EXTS; do psql -d "$DB" -qc "CREATE EXTENSION IF NOT EXISTS $e;" >/dev/null; done
    ok "extensions on '$DB': $EXTS"
  done
else
  warn "No databases created (PG_DATABASES empty). Restore your data with ~/BackupsBeforeClean/RESTORE.md,"
  warn "or create empty databases with: PG_DATABASES=\"plus_dev tnb_dev\" ./setup.sh 08"
fi

ok "PostgreSQL module completed."
