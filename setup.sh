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
# Si algún módulo a ejecutar usa sudo (02 Homebrew/CLT, 12 iOS), se pide la
# contraseña UNA vez al inicio y se mantiene viva la sesión de sudo (no se
# almacena: se usa el timestamp propio de sudo). --list y --dry-run no la piden.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/lib/common.sh"

ONLY=""; FROM=""; DRY=0; LIST=0; SKIPS=" "
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)        FROM="${2:-}"; shift 2 ;;
    --skip)        SKIPS="${SKIPS}${2:-} "; shift 2 ;;
    --list|-l)     LIST=1; shift ;;
    --dry-run|-n)  DRY=1; shift ;;
    -h|--help)     sed -n '3,18p' "$0"; exit 0 ;;
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

# ── Cachear sudo una vez si algún módulo a ejecutar lo requiere ──────────────
# Módulos que usan sudo (directa o internamente): 02 (Homebrew + CLT) y 12 (iOS).
# Así se pide la contraseña al inicio y no a mitad del proceso. Nunca en list/dry.
if [[ "$LIST" == 0 && "$DRY" == 0 ]]; then
  for m in "${mods[@]}"; do
    nn="$(basename "${m%%|*}")"; nn="${nn:0:2}"
    [[ -n "$ONLY" && "$nn" != "$ONLY" ]] && continue
    [[ -n "$FROM" && "$nn" < "$FROM" ]] && continue
    case "$SKIPS" in *" $nn "*) continue ;; esac
    case " 02 12 " in *" $nn "*) sudo_keep_alive; break ;; esac
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
ok "setup-macos completado ($ran módulo(s))."
