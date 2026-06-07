#!/usr/bin/env bash
# =============================================================================
# setup.sh — orquestador idempotente de setup-macos
#
# Uso:
#   ./setup.sh                  Corre todos los módulos en orden
#   ./setup.sh 04               Corre solo el módulo 04
#   ./setup.sh --from 03        Desde el módulo 03 en adelante
#   ./setup.sh --skip 11 --skip 12
#   ./setup.sh --list           Lista los módulos detectados
#   ./setup.sh --dry-run        Muestra qué correría, sin ejecutar
#
# Un módulo = carpeta "NN. Nombre/" que contiene un "setup-*.sh".
# Cada módulo también puede ejecutarse por separado.
#
# Si algún módulo a ejecutar usa sudo (02 Homebrew/CLT, 11 Android, 12 iOS), se
# pide la contraseña UNA vez al inicio. Mientras dura el setup se instala un
# drop-in temporal en /etc/sudoers.d (validado con visudo) para que tampoco la
# pidan los instaladores .pkg de los casks; se elimina SIEMPRE al salir.
# --list y --dry-run no piden nada.
#
# Las autenticaciones INTERACTIVAS de apps (p. ej. el login web de GitHub) se
# difieren al FINAL, tras instalar todo, para no interrumpir el proceso.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/lib/common.sh"

# Configuración local (gitignored): si existe setup.env, se carga y se EXPORTA
# todo (set -a) para que los módulos hereden GIT_USER_*, PG_DATABASES,
# MYSQL_ROOT_PASSWORD, INSTALL_IOS, etc. sin prompts a media instalación.
# Plantilla: setup.env.example. Sin el archivo, se usan los valores por defecto.
if [[ -f "$HERE/setup.env" ]]; then
  set -a; source "$HERE/setup.env"; set +a
  ok "configuración cargada desde setup.env"
fi

ONLY=""; FROM=""; DRY=0; LIST=0; SKIPS=" "
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)        FROM="${2:-}"; shift 2 ;;
    --skip)        SKIPS="${SKIPS}${2:-} "; shift 2 ;;
    --list|-l)     LIST=1; shift ;;
    --dry-run|-n)  DRY=1; shift ;;
    -h|--help)     sed -n '3,23p' "$0"; exit 0 ;;
    [0-9][0-9])    ONLY="$1"; shift ;;
    *)             die "Opción no reconocida: '$1' (usa --help)" ;;
  esac
done

# ── Descubrir módulos: carpetas "NN. *" con un setup-*.sh dentro ─────────────
mods=()
for dir in "$HERE"/[0-9][0-9].*/; do
  [[ -d "$dir" ]] || continue
  script=""
  for s in "$dir"setup-*.sh; do [[ -f "$s" ]] && { script="$s"; break; }; done
  [[ -n "$script" ]] || continue          # p. ej. "00. Inventory" no tiene script
  mods+=("$dir|$script")
done
[[ ${#mods[@]} -gt 0 ]] || die "No se encontraron módulos ('NN. Nombre/setup-*.sh') en $HERE."

[[ "$LIST" == 1 ]] && echo "Módulos detectados:"

# ── Preparación de la corrida (solo si vamos a ejecutar de verdad) ───────────
if [[ "$LIST" == 0 && "$DRY" == 0 ]]; then
  # Marca para los módulos: corren orquestados, NO en solitario. Cada módulo es
  # un paso de varios, así que ninguno debe anunciar "instalación completa" — eso
  # lo declara setup.sh al final (p. ej. el módulo 01 acota su resumen).
  export SETUP_ORCHESTRATED=1

  # Cola de autenticaciones diferidas: los logins interactivos (GitHub, etc.) se
  # ejecutan al FINAL, tras instalar todo, para no interrumpir el proceso. Un
  # único trap EXIT cierra la sesión de sudo (borra el drop-in) y borra la cola.
  SETUP_AUTH_QUEUE="$(mktemp -t setup-macos-auth)"; export SETUP_AUTH_QUEUE
  trap 'sudo_session_end; rm -f "${SETUP_AUTH_QUEUE:-}"' EXIT

  # Abre la sesión de sudo (una sola contraseña) si algún módulo a ejecutar la
  # necesita: 02 (Homebrew/CLT), 11 (Android: cask zulu@17 .pkg) y 12 (iOS). El
  # sudo NO se difiere: hace falta DURANTE la instalación.
  for m in "${mods[@]}"; do
    nn="$(basename "${m%%|*}")"; nn="${nn:0:2}"
    [[ -n "$ONLY" && "$nn" != "$ONLY" ]] && continue
    [[ -n "$FROM" && "$nn" < "$FROM" ]] && continue
    case "$SKIPS" in *" $nn "*) continue ;; esac
    case " 02 11 12 " in *" $nn "*) sudo_session_begin; break ;; esac
  done
fi

ran=0
for m in "${mods[@]}"; do
  dir="${m%%|*}"; script="${m#*|}"
  name="$(basename "$dir")"; nn="${name:0:2}"

  [[ -n "$ONLY" && "$nn" != "$ONLY" ]] && continue
  [[ -n "$FROM" && "$nn" < "$FROM" ]] && continue
  case "$SKIPS" in *" $nn "*) warn "saltando $name"; continue ;; esac

  if [[ "$LIST" == 1 ]]; then printf '  %s  →  %s\n' "$nn" "$name"; continue; fi
  if [[ "$DRY"  == 1 ]]; then printf '  (dry-run) %s\n' "$script"; continue; fi

  step "Módulo $name"
  bash "$script"
  ok "Módulo $name completado"
  ran=$((ran + 1))
done

[[ "$LIST" == 1 || "$DRY" == 1 ]] && exit 0
[[ -n "$ONLY" && "$ran" == 0 ]] && die "No existe el módulo '$ONLY'."

# Autenticaciones interactivas diferidas (GitHub, etc.): al final, ya instalado todo.
run_deferred_auth

step "Instalación completa"
ok "setup-macos finalizado — $ran módulo(s) ejecutado(s)."
