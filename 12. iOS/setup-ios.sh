#!/usr/bin/env bash
# =============================================================================
# 12. iOS — Xcode (manual, App Store) + CLT + CocoaPods. OPT-IN (~12 GB).
# No corre en un ./setup.sh normal: actívalo con INSTALL_IOS=1.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "iOS (opt-in)"

if [[ "${INSTALL_IOS:-0}" != "1" ]]; then
  warn "Módulo iOS omitido (opt-in, ~12 GB). Actívalo con:  INSTALL_IOS=1 ./setup.sh 12"
  exit 0
fi

# Xcode completo: se instala desde la Mac App Store (no automatizable sin sesión).
if [[ -d "/Applications/Xcode.app" ]]; then
  ok "Xcode.app presente"
  log "apuntando las Command Line Tools a Xcode (requiere sudo)…"
  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -runFirstLaunch
  sudo xcodebuild -license accept
  log "descargando la plataforma iOS (simuladores)…"
  xcodebuild -downloadPlatform iOS
else
  warn "Xcode.app no está instalado. Instálalo desde la Mac App Store (~12 GB) y vuelve a correr: INSTALL_IOS=1 ./setup.sh 12"
fi

# CocoaPods (brew trae su propio Ruby; no usa el Ruby del sistema, deprecado).
brew_ensure cocoapods

ok "Módulo iOS completado."
