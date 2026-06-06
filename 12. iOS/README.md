# 12 · iOS (opt-in)

Toolchain de **iOS**. **Opt-in** (~12 GB de Xcode): no corre en un `./setup.sh` normal; actívalo con `INSTALL_IOS=1`.

- **Xcode** completo: instálalo desde la **Mac App Store** (no automatizable sin sesión de App Store).
- Apunta las CLT a Xcode (`xcode-select --switch`), `-runFirstLaunch`, `-license accept`, `-downloadPlatform iOS`.
- **CocoaPods** vía brew (trae su propio Ruby; no usa el Ruby del sistema, deprecado).

## Uso
```bash
INSTALL_IOS=1 ./setup.sh 12
```

## Notas
- Usa `sudo` (`xcode-select`, `xcodebuild -license`).
- **EAS Build** hace los pods en la nube; CocoaPods solo hace falta para builds locales (`expo run:ios` / prebuild).
- Tras actualizaciones mayores de macOS/Xcode, re-acepta la licencia o los builds nativos se rompen.
