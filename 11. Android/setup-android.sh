#!/usr/bin/env bash
# =============================================================================
# 11. Android / React Native — watchman, JDK 17, Android SDK (cmdline-tools), EAS.
# Node lo provee el módulo 04 (fnm); aquí NO se instala node.
# JDK 17 (NO 21): RN/Expo fallan con Gradle/AGP en JDK 21+.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "Android / React Native"

need_cmd node || warn "Node no detectado: corre antes el módulo 04 (fnm) para tener node/npm/eas."

# 1. watchman (file watching para Metro).
brew_ensure watchman

# 2. JDK 17 (Azul Zulu) — REQUERIDO (no 21).
cask_ensure zulu@17
append_once "$ZSHRC" 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)'
export JAVA_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
[[ -n "$JAVA_HOME" ]] && ok "JAVA_HOME → $JAVA_HOME"

# 3. Android SDK headless (cmdline-tools; el cask 'android-sdk' fue retirado en 2024).
cask_ensure android-commandlinetools
ANDROID_HOME="$("$BREW" --prefix)/share/android-commandlinetools"
export ANDROID_HOME

# 4. Env vars de Android (idempotente).
append_once "$ZSHRC" "export ANDROID_HOME=\"$ANDROID_HOME\""
append_once "$ZSHRC" 'export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin"'
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin"

# 5. Paquetes del SDK (idempotente; ABI del system image según arquitectura).
ABI=$([ "$ARCH" = "arm64" ] && echo arm64-v8a || echo x86_64)
if need_cmd sdkmanager; then
  log "aceptando licencias del SDK…"
  yes | sdkmanager --licenses >/dev/null 2>&1 || true
  log "sdkmanager: platform-tools, emulator, android-36, build-tools 36.0.0, system-image ($ABI)…"
  sdkmanager "platform-tools" "emulator" "platforms;android-36" "build-tools;36.0.0" "system-images;android-36;google_apis;$ABI"
  ok "SDK de Android listo"
else
  warn "sdkmanager no está en el PATH todavía; abre una terminal nueva y reintenta, o revisa el cask android-commandlinetools."
fi

# 6. EAS CLI (global; usa el npm gestionado por fnm).
if need_cmd eas; then
  ok "eas ya instalado ($(eas --version 2>/dev/null | head -1))"
elif need_cmd npm; then
  log "npm install -g eas-cli@latest"; npm install -g eas-cli@latest
else
  warn "npm no disponible; instala el módulo 04 (fnm) y reintenta para EAS CLI."
fi

ok "Módulo Android/RN completado. (Para iOS: módulo 12.)"
