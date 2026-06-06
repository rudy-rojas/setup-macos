# 11 · Android / React Native

Toolchain nativo para **React Native / Expo** (Android). Node lo provee el módulo 04 (fnm) — aquí **no** se instala node.

- `watchman` (brew).
- **JDK 17 Azul Zulu** (`cask zulu@17`) — REQUERIDO; JDK 21+ rompe Gradle/AGP en RN 0.81–0.85.
- `JAVA_HOME` vía `/usr/libexec/java_home -v 17` (idempotente, arch-independiente).
- **Android SDK headless**: cask `android-commandlinetools` (el cask `android-sdk` fue retirado en 2024) + `sdkmanager` (platform-tools, emulator, `android-36`, `build-tools;36.0.0`, system image **arch-aware**).
- `ANDROID_HOME` + `PATH` (idempotente).
- **EAS CLI** (`npm -g`, usa el npm de fnm).

## Uso
```bash
./setup.sh 11
```

## Notas
- **ABI** del system image: `arm64-v8a` en Apple Silicon, `x86_64` en Intel (usar el incorrecto da un AVD que no arranca).
- `ANDROID_HOME` apunta al cask: `$(brew --prefix)/share/android-commandlinetools`.
- Corre **antes** el módulo 04 (fnm) para tener `node`/`npm`/`eas`.
- `eas-cli` se instala global (no como dependencia de proyecto; Expo lo advierte).
