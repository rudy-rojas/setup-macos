#!/usr/bin/env bash
# =============================================================================
# 11. Android / React Native — watchman, JDK 17, Android SDK (cmdline-tools), EAS.
# Node is provided by module 04 (fnm); node is NOT installed here.
# Versions (JDK_VERSION / ANDROID_API / ANDROID_BUILD_TOOLS) are pinned in
# lib/common.sh. JDK 17 (NOT 21): RN/Expo fail with Gradle/AGP on JDK 21+.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "Android / React Native"

need_cmd node || warn "Node not detected: run module 04 (fnm) first to get node/npm/eas."

# 1. watchman (file watching for Metro).
brew_ensure watchman

# 2. JDK (Azul Zulu, JDK_VERSION — 17 by default; RN/Expo break on 21+).
#    The dotfile line keeps $(…) LITERAL (escaped \$) so it re-resolves per shell,
#    but bakes in the pinned major version.
cask_ensure "zulu@${JDK_VERSION}"
append_once "$ZSHRC" "export JAVA_HOME=\$(/usr/libexec/java_home -v ${JDK_VERSION})"
JAVA_HOME="$(/usr/libexec/java_home -v "${JDK_VERSION}" 2>/dev/null || true)"
export JAVA_HOME
[[ -n "$JAVA_HOME" ]] && ok "JAVA_HOME → $JAVA_HOME"

# 3. Headless Android SDK (cmdline-tools; the 'android-sdk' cask was retired in 2024).
cask_ensure android-commandlinetools
ANDROID_HOME="$("$BREW" --prefix)/share/android-commandlinetools"
export ANDROID_HOME

# 4. Android env vars (idempotent).
append_once "$ZSHRC" "export ANDROID_HOME=\"$ANDROID_HOME\""
append_once "$ZSHRC" 'export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin"'
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin"

# 5. SDK packages (idempotent; system image ABI depends on architecture).
ABI=$([ "$ARCH" = "arm64" ] && echo arm64-v8a || echo x86_64)
if need_cmd sdkmanager; then
  log "accepting SDK licenses…"
  yes | sdkmanager --licenses >/dev/null 2>&1 || true
  log "sdkmanager: platform-tools, emulator, android-${ANDROID_API}, build-tools ${ANDROID_BUILD_TOOLS}, system-image ($ABI)…"
  sdkmanager "platform-tools" "emulator" "platforms;android-${ANDROID_API}" "build-tools;${ANDROID_BUILD_TOOLS}" "system-images;android-${ANDROID_API};google_apis;$ABI"
  ok "Android SDK ready"
else
  warn "sdkmanager is not on the PATH yet; open a new terminal and retry, or check the android-commandlinetools cask."
fi

# 6. Android Studio (GUI) — OPTIONAL (~1.2 GB). For RN/Expo with EAS it is NOT
#    essential (cmdline-tools + SDK are enough); useful for the AVD Manager, the
#    emulator, and debugging. Opt-in with INSTALL_ANDROID_STUDIO=1 (or in setup.env).
if [[ "${INSTALL_ANDROID_STUDIO:-0}" == "1" ]]; then
  cask_ensure android-studio
else
  warn "Android Studio skipped (optional). Enable it with: INSTALL_ANDROID_STUDIO=1 ./setup.sh 11"
fi

# 7. EAS CLI (global; uses the npm managed by fnm).
if need_cmd eas; then
  ok "eas already installed ($(eas --version 2>/dev/null | head -1))"
elif need_cmd npm; then
  log "npm install -g eas-cli@latest"; npm install -g eas-cli@latest
else
  warn "npm not available; install module 04 (fnm) and retry for EAS CLI."
fi

ok "Android/RN module completed. (For iOS: module 12.)"
