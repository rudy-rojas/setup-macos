# 11 · Android / React Native

Native toolchain for **React Native / Expo** (Android). Node is provided by module 04 (fnm) — node is **not** installed here.

- `watchman` (brew).
- **JDK 17 Azul Zulu** (`cask zulu@17`) — REQUIRED; JDK 21+ breaks Gradle/AGP on RN 0.81–0.85.
- `JAVA_HOME` via `/usr/libexec/java_home -v 17` (idempotent, arch-independent).
- **Headless Android SDK**: cask `android-commandlinetools` (the `android-sdk` cask was retired in 2024) + `sdkmanager` (platform-tools, emulator, `android-36`, `build-tools;36.0.0`, **arch-aware** system image).
- `ANDROID_HOME` + `PATH` (idempotent).
- **Android Studio** (cask `android-studio`, GUI) — **OPTIONAL** (~1.2 GB): opt-in with `INSTALL_ANDROID_STUDIO=1`. For RN/Expo with EAS it is not essential (cmdline-tools + SDK are enough); useful for the AVD Manager, the emulator, and debugging.
- **EAS CLI** (`npm -g`, uses fnm's npm).

## Usage
```bash
./setup.sh 11
# with Android Studio (GUI):
INSTALL_ANDROID_STUDIO=1 ./setup.sh 11
```

## Notes
- System image **ABI**: `arm64-v8a` on Apple Silicon, `x86_64` on Intel (using the wrong one gives an AVD that won't start).
- `ANDROID_HOME` points to the cask: `$(brew --prefix)/share/android-commandlinetools`.
- Run module 04 (fnm) **first** to have `node`/`npm`/`eas`.
- `eas-cli` is installed globally (not as a project dependency; Expo warns about this).
