# 08 · PostgreSQL 16

Instala `postgresql@16`, lo deja en el PATH (keg-only, **arch-aware**), arranca el servicio y prepara extensiones.

- `brew install postgresql@16`; PATH vía `$(brew --prefix postgresql@16)/bin` con `\$PATH` **escapado** (no se congela).
- `brew services start postgresql@16`; espera con `pg_isready`.
- Crea bases (opcional) con `PG_DATABASES="..."` y aplica `citext`/`pgcrypto`/`pg_trgm` (`CREATE EXTENSION IF NOT EXISTS`).

## Uso
```bash
./setup.sh 08
PG_DATABASES="plus_dev tnb_dev" ./setup.sh 08   # además crea esas bases vacías + extensiones
```

## Notas
- Por defecto **no** crea bases: restaura tus datos reales desde `~/BackupsBeforeClean/RESTORE.md` (`globals.sql` + `pg_restore`).
- El superusuario es tu usuario de macOS (sin contraseña); **no** existe el rol `postgres` por defecto — lo crea `globals.sql` al restaurar.
- `postgresql@16` es keg-only por diseño (no es un fallo): por eso el PATH explícito. No uses `exec zsh -l` en scripts (reemplaza la shell y aborta lo que sigue).
