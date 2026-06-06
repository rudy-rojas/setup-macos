# setup-macos

Provisión **idempotente y modular** de un Mac para desarrollo **web/móvil** (stack TNB: PLUS, tnb-backend, tnb-mobile, v1). **Arch-aware**: funciona en Apple Silicon (`/opt/homebrew`) e Intel (`/usr/local`).

## Cómo funciona

- Cada módulo es una carpeta `NN. Nombre/` con su `setup-NN.sh` (+ `README.md`) y se puede correr por separado.
- `lib/common.sh` aporta los helpers idempotentes: `append_once` (dotfiles sin duplicar), `brew_ensure`/`cask_ensure`/`service_ensure`, detección de arquitectura y rutas ZDOTDIR-aware.
- `setup.sh` descubre y orquesta los módulos en orden.

## Uso

```bash
./setup.sh              # todos los módulos en orden
./setup.sh 04           # solo el módulo 04
./setup.sh --from 05    # del módulo 05 en adelante
./setup.sh --skip 12    # omitir un módulo
./setup.sh --list       # listar módulos detectados
./setup.sh --dry-run    # ver qué correría, sin ejecutar
```

## Módulos

| #  | Módulo       | Qué hace |
|----|--------------|----------|
| 00 | Inventory    | Snapshot de herramientas/versiones (no ejecutable) |
| 01 | Terminals    | Terminal · iTerm2 · Alacritty |
| 02 | Homebrew     | Homebrew arch-aware + `shellenv` + CLI base |
| 03 | Python       | uv + Python 3.12 por defecto |
| 04 | Node         | fnm + Node LTS + pnpm (arch-aware) |
| 05 | Git          | git + gh + config global TNB |
| 06 | VS Code      | cask + extensiones + settings (merge) |
| 07 | Claude Code  | instalador nativo |
| 08 | PostgreSQL   | postgresql@16 + servicio + extensiones |
| 09 | Redis        | redis + servicio |
| 10 | MySQL        | mysql (brew services) + DBeaver |
| 11 | Android      | watchman · JDK 17 · Android SDK · EAS |
| 12 | iOS          | Xcode + CocoaPods (**opt-in**: `INSTALL_IOS=1`) |
| 13 | Ops/VPS      | sshpass |

## Variables opcionales

| Variable | Módulo | Efecto |
|---|---|---|
| `GIT_USER_NAME` / `GIT_USER_EMAIL` | 05 | Identidad de git |
| `PG_DATABASES="db1 db2"` | 08 | Crea esas bases vacías + extensiones |
| `MYSQL_ROOT_PASSWORD` | 10 | Fija la contraseña de root de MySQL |
| `INSTALL_IOS=1` | 12 | Activa el módulo iOS (opt-in) |

## Idempotencia

Todo está diseñado para **re-ejecutarse sin efectos secundarios**: instalaciones guardadas (`brew list … || brew install`), líneas de dotfiles añadidas una sola vez (`append_once`), servicios iniciados solo si no corren, `createdb`/extensiones con guardas.

Prueba en el equipo destino (correr dos veces):

```bash
./setup.sh && ./setup.sh     # 2ª pasada: todo "ya instalado", sin duplicados
diff <(sort -u ~/.zprofile) <(sort ~/.zprofile)   # sin líneas repetidas
```

## Datos y backups

Los datos (bases de datos) y secretos **no** viven en git. El respaldo del equipo anterior está en `~/BackupsBeforeClean/` con su `RESTORE.md` (Postgres, MySQL, `.env`, dotfiles, inventario). El inventario reproducible está en `00. Inventory/` (`Brewfile`, versiones, extensiones).

## Requisitos

- macOS **14+ (Sonoma)**. Los Command Line Tools de Xcode los instala el módulo 02.
