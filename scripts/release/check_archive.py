"""Check the actual unsigned release archive. Apple validation is still required."""
import json
import re
import plistlib
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[2]
project = (root / 'apps/apple/OrcaPlayer.xcodeproj/project.pbxproj').read_text()
version = re.search(r'MARKETING_VERSION = "([^";]+)"', project).group(1)
build = re.search(r'CURRENT_PROJECT_VERSION = "([^";]+)"', project).group(1)
app = root / f'apps/apple/.build/testflight/MusicPlayer-{version}-{build}.xcarchive/Products/Applications/OrcaPlayer.app'
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'com.orca.player.preview.ios'
assert (info['CFBundleShortVersionString'], info['CFBundleVersion']) == (version, build)
assert set(info['UIDeviceFamily']) == {1, 2}
assert info['MinimumOSVersion'] == '17.0'
assert info['CFBundleIcons']['CFBundlePrimaryIcon']['CFBundleIconName'] == 'AppIcon'
assert 'audio' in info['UIBackgroundModes']
assert (app / 'Assets.car').is_file()
assert (app / 'Orca-Soundcheck.wav').is_file()
assert not (app / 'changelog.json').exists(), 'Developer journal must not ship in the user app'
privacy = plistlib.loads((app / 'PrivacyInfo.xcprivacy').read_bytes())
assert privacy['NSPrivacyTracking'] is False
assert privacy['NSPrivacyCollectedDataTypes'] == []
assert {x['NSPrivacyAccessedAPIType']: x['NSPrivacyAccessedAPITypeReasons'] for x in privacy['NSPrivacyAccessedAPITypes']} == {
    'NSPrivacyAccessedAPICategoryUserDefaults': ['CA92.1'],
    'NSPrivacyAccessedAPICategorySystemBootTime': ['35F9.1'],
}
png = (root / 'apps/apple/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png').read_bytes()
assert png[:8] == b'\x89PNG\r\n\x1a\n'
w, h, depth, color = struct.unpack('>IIBB', png[16:26])
assert (w, h, depth, color) == (1024, 1024, 8, 2), 'Icon must be opaque RGB PNG'
print(f'PASS: Release {version}/{build}, iPhone+iPad, background audio, opaque icon, privacy manifest, developer journal excluded and demo present.')
print('Signing:', 'present; requires Apple validation' if (app / '_CodeSignature').exists() else 'UNSIGNED — not installable/distributed via TestFlight')
