#!/usr/bin/env bash
# =============================================================================
# 12. iOS — Xcode (manual, App Store) + CLT + CocoaPods. OPT-IN (~12 GB).
# Does not run in a normal ./setup.sh: enable it with INSTALL_IOS=1.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "iOS (opt-in)"

if [[ "${INSTALL_IOS:-0}" != "1" ]]; then
  warn "iOS module skipped (opt-in, ~12 GB). Enable it with:  INSTALL_IOS=1 ./setup.sh 12"
  exit 0
fi

# Full Xcode: installed from the Mac App Store (cannot be automated without a session).
if [[ -d "/Applications/Xcode.app" ]]; then
  ok "Xcode.app present"
  log "pointing the Command Line Tools to Xcode (requires sudo)…"
  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -runFirstLaunch
  sudo xcodebuild -license accept
  log "downloading the iOS platform (simulators)…"
  xcodebuild -downloadPlatform iOS
else
  warn "Xcode.app is not installed. Install it from the Mac App Store (~12 GB) and run again: INSTALL_IOS=1 ./setup.sh 12"
fi

# CocoaPods (brew ships its own Ruby; it does not use the deprecated system Ruby).
brew_ensure cocoapods

ok "iOS module completed."
