#!/usr/bin/env bash
# =============================================================================
# 10. MySQL (brew + brew services) + DBeaver + panel de servicios.
# Sin secretos en el repo: la contraseña de root se pasa por MYSQL_ROOT_PASSWORD.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "MySQL + DBeaver"

brew_ensure mysql
service_ensure mysql

# mysql/mysqladmin al PATH de la sesión (la fórmula los expone vía brew shellenv,
# pero lo reforzamos por si el bin es keg-only en alguna versión).
MYSQL_BIN="$("$BREW" --prefix mysql)/bin"
export PATH="$MYSQL_BIN:$PATH"

# Esperar a que el servidor arranque (ping no requiere credenciales válidas).
log "esperando a que MySQL arranque…"
tries=0
until mysqladmin ping --silent >/dev/null 2>&1; do
  tries=$((tries + 1)); [ "$tries" -ge 30 ] && { warn "MySQL no respondió tras 30s."; break; }; sleep 1
done

# (Opcional) fijar la contraseña de root si se indica MYSQL_ROOT_PASSWORD.
if [[ -n "${MYSQL_ROOT_PASSWORD:-}" ]]; then
  if mysql -u root -e "SELECT 1" >/dev/null 2>&1; then
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'; FLUSH PRIVILEGES;"
    ok "contraseña de root de MySQL establecida"
  elif MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -u root -e "SELECT 1" >/dev/null 2>&1; then
    ok "root de MySQL ya usa la contraseña indicada"
  else
    warn "No pude conectar a MySQL (ni sin contraseña ni con MYSQL_ROOT_PASSWORD). Revísalo a mano."
  fi
else
  warn "MySQL quedó SIN contraseña de root (default de brew). Fíjala con:"
  warn "  MYSQL_ROOT_PASSWORD='...' ./setup.sh 10   (o corre 'mysql_secure_installation')"
fi

# DBeaver (cliente GUI) + panel de servicios brew en la barra de menú.
cask_ensure dbeaver-community brewservicesmenubar

ok "Módulo MySQL + DBeaver completado."
