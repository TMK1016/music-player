#!/bin/zsh
# Local compilation readiness; does not sign, export, or upload to TestFlight.
set -euo pipefail
cd "${0:A:h:h:h}"
python3 scripts/generate_xcode_project.py
release_name=$(python3 <<'PYMETA'
import re
from pathlib import Path
text = Path('apps/apple/OrcaPlayer.xcodeproj/project.pbxproj').read_text()
version = re.search('MARKETING_VERSION = "([^";]+)"', text)[1]
build = re.search('CURRENT_PROJECT_VERSION = "([^";]+)"', text)[1]
print(f'MusicPlayer-{version}-{build}')
PYMETA
)
xcodebuild -project apps/apple/OrcaPlayer.xcodeproj -scheme OrcaPlayer-iOS \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "apps/apple/.build/testflight/${release_name}.xcarchive" \
  -derivedDataPath apps/apple/.build/testflight/DerivedData \
  CODE_SIGNING_ALLOWED=NO archive
python3 scripts/release/check_archive.py
