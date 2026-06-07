#!/usr/bin/env bash
# =============================================================================
# 10. MySQL (brew + brew services) + DBeaver + services panel.
# No secrets in the repo: the root password is passed via MYSQL_ROOT_PASSWORD.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "MySQL + DBeaver"

brew_ensure mysql
service_ensure mysql

# mysql/mysqladmin onto the session PATH (the formula exposes them via brew shellenv,
# but we reinforce it in case the bin is keg-only in some version).
MYSQL_BIN="$("$BREW" --prefix mysql)/bin"
export PATH="$MYSQL_BIN:$PATH"

# Wait for the server to start (ping does not require valid credentials).
log "waiting for MySQL to start…"
tries=0
until mysqladmin ping --silent >/dev/null 2>&1; do
  tries=$((tries + 1)); [ "$tries" -ge 30 ] && { warn "MySQL did not respond after 30s."; break; }; sleep 1
done

# (Optional) set the root password if MYSQL_ROOT_PASSWORD is provided.
if [[ -n "${MYSQL_ROOT_PASSWORD:-}" ]]; then
  if mysql -u root -e "SELECT 1" >/dev/null 2>&1; then
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'; FLUSH PRIVILEGES;"
    ok "MySQL root password set"
  elif MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -u root -e "SELECT 1" >/dev/null 2>&1; then
    ok "MySQL root already uses the provided password"
  else
    warn "Could not connect to MySQL (neither without a password nor with MYSQL_ROOT_PASSWORD). Check it manually."
  fi
else
  warn "MySQL was left WITHOUT a root password (brew default). Set it with:"
  warn "  MYSQL_ROOT_PASSWORD='...' ./setup.sh 10   (or run 'mysql_secure_installation')"
fi

# DBeaver (GUI client) + brew services panel in the menu bar.
cask_ensure dbeaver-community brewservicesmenubar

ok "MySQL + DBeaver module completed."
