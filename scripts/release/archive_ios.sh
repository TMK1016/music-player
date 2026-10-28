#!/bin/zsh
# Local compilation readiness; does not sign, export, or upload to TestFlight.
set -euo pipefail
cd "${0:A:h:h:h}"
python3 scripts/generate_xcode_project.py
xcodebuild -project apps/apple/OrcaPlayer.xcodeproj -scheme OrcaPlayer-iOS \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath apps/apple/.build/testflight/MusicPlayer-0.15.0-22.xcarchive \
  -derivedDataPath apps/apple/.build/testflight/DerivedData \
  CODE_SIGNING_ALLOWED=NO archive
python3 scripts/release/check_archive.py
