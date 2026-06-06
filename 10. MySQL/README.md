# 10 · MySQL + DBeaver

Instala MySQL vía **Homebrew** (gestionado con `brew services` — fácil de arrancar/parar, a diferencia del instalador oficial) + DBeaver + panel de servicios.

- `brew install mysql`; `brew services start mysql`; espera con `mysqladmin ping`.
- (Opcional) fija la contraseña de root con `MYSQL_ROOT_PASSWORD` (no se guarda ningún secreto en el repo).
- Casks: `dbeaver-community`, `brewservicesmenubar`.

## Uso
```bash
./setup.sh 10
# dejar root con la contraseña que use tu .env (la que espera v1/tnb-backend):
MYSQL_ROOT_PASSWORD='<tu-password>' ./setup.sh 10
```

## Notas
- MySQL de brew se instala **sin** contraseña de root. Conéctate con `mysql -u root`. Fíjala con la env var o `mysql_secure_installation` (interactivo).
- Restaurar tus 3 bases (`tnb-db-develop`, `nexus_erp`, `testscript`): ver `~/BackupsBeforeClean/RESTORE.md`.
- Saltos de versión mayor (`<8.4` → `9.x`) requieren arrancar `mysql@8.4` primero; `brew install mysql` instala la línea actual.
- Elegimos brew en vez del instalador oficial Oracle justamente para evitar el problema de apagado que tuvimos (PID file / launchd).
