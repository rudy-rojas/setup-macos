#!/usr/bin/env bash
# =============================================================================
# 08. PostgreSQL 16 — instala, PATH keg-only (arch-aware), servicio, extensiones.
# Por defecto NO crea bases: los datos se restauran desde ~/BackupsBeforeClean.
# Pasa PG_DATABASES="db1 db2" para crear bases vacías con extensiones.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "PostgreSQL 16"

brew_ensure postgresql@16

# postgresql@16 es keg-only → añade su bin al PATH (arch-agnóstico vía brew --prefix).
# Escapa \$PATH para que quede LITERAL en ~/.zshrc (se reevalúa en cada shell, no se congela).
PG_BIN="$("$BREW" --prefix postgresql@16)/bin"
append_once "$ZSHRC" "export PATH=\"$PG_BIN:\$PATH\""
export PATH="$PG_BIN:$PATH"        # en ESTA sesión (NO usar 'exec zsh -l': abortaría el script)

# Servicio.
service_ensure postgresql@16

# Esperar a que acepte conexiones antes de usarlo.
log "esperando a que PostgreSQL acepte conexiones…"
tries=0
until pg_isready -q; do
  tries=$((tries + 1)); [ "$tries" -ge 30 ] && die "PostgreSQL no respondió tras 30s."; sleep 1
done
ok "PostgreSQL activo ($(psql --version | awk '{print $3}'))"

# Crear bases del proyecto (opcional) + extensiones, idempotente.
EXTS="citext pgcrypto pg_trgm"
if [[ -n "${PG_DATABASES:-}" ]]; then
  for DB in ${PG_DATABASES}; do
    if psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB'" | grep -q 1; then
      ok "base '$DB' (ya existe)"
    else
      log "createdb $DB"; createdb "$DB"
    fi
    for e in $EXTS; do psql -d "$DB" -qc "CREATE EXTENSION IF NOT EXISTS $e;" >/dev/null; done
    ok "extensiones en '$DB': $EXTS"
  done
else
  warn "No se crearon bases (PG_DATABASES vacío). Restaura tus datos con ~/BackupsBeforeClean/RESTORE.md,"
  warn "o crea bases vacías con: PG_DATABASES=\"plus_dev tnb_dev\" ./setup.sh 08"
fi

ok "Módulo PostgreSQL completado."
