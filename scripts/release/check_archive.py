"""Check the actual unsigned release archive. Apple validation is still required."""
import json
import plistlib
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[2]
app = root / 'apps/apple/.build/testflight/MusicPlayer-0.15.0-22.xcarchive/Products/Applications/OrcaPlayer.app'
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'com.orca.player.preview.ios'
assert (info['CFBundleShortVersionString'], info['CFBundleVersion']) == ('0.15.0', '22')
assert set(info['UIDeviceFamily']) == {1, 2}
assert info['MinimumOSVersion'] == '17.0'
assert info['CFBundleIcons']['CFBundlePrimaryIcon']['CFBundleIconName'] == 'AppIcon'
assert 'audio' in info['UIBackgroundModes']
assert (app / 'Assets.car').is_file()
assert (app / 'Orca-Soundcheck.wav').is_file()
assert json.loads((app / 'changelog.json').read_text()) == json.loads((root / 'planning/changelog.json').read_text())
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
print('PASS: Release 0.15.0/22, iPhone+iPad, background audio, opaque icon, privacy manifest, bundled journal and demo.')
print('Signing:', 'present; requires Apple validation' if (app / '_CodeSignature').exists() else 'UNSIGNED — not installable/distributed via TestFlight')
