# 12 · iOS (opt-in)

**iOS** toolchain. **Opt-in** (~12 GB for Xcode): does not run in a normal `./setup.sh`; enable it with `INSTALL_IOS=1`.

- Full **Xcode**: install it from the **Mac App Store** (cannot be automated without an App Store session).
- Points the CLT to Xcode (`xcode-select --switch`), `-runFirstLaunch`, `-license accept`, `-downloadPlatform iOS`.
- **CocoaPods** via brew (ships its own Ruby; does not use the deprecated system Ruby).

## Usage
```bash
INSTALL_IOS=1 ./setup.sh 12
```

## Notes
- Uses `sudo` (`xcode-select`, `xcodebuild -license`).
- **EAS Build** builds the pods in the cloud; CocoaPods is only needed for local builds (`expo run:ios` / prebuild).
- After major macOS/Xcode updates, re-accept the license or native builds will break.
