"""Allowlisted friend source ZIP, without local signing or workspace state."""
import hashlib
import json
import re
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[2]
apple = root / 'apps/apple'
output = root / 'deliverables/MusicPlayer-0.15.0-build22-Friend-Source.zip'
files = {}
# Only tracked source and explicitly named original resources are eligible.
for p in sorted((apple / 'OrcaPlayer').glob('*.swift')):
    files['Apple/OrcaPlayer/' + p.name] = p.read_bytes()
for name in ['iOS-Info.plist', 'PrivacyInfo.xcprivacy', 'changelog.json', 'Orca-Soundcheck.wav']:
    files['Apple/Resources/' + name] = (apple / 'Resources' / name).read_bytes()
for name in ['Contents.json', 'AppIcon.appiconset/Contents.json', 'AppIcon.appiconset/AppIcon.png']:
    files['Apple/Resources/Assets.xcassets/' + name] = (apple / 'Resources/Assets.xcassets' / name).read_bytes()
project = (apple / 'OrcaPlayer.xcodeproj/project.pbxproj').read_text()
project = re.sub(r'\s*DEVELOPMENT_TEAM\s*=\s*"[^"]*";', '', project)
assert 'DEVELOPMENT_TEAM' not in project
files['Apple/OrcaPlayer.xcodeproj/project.pbxproj'] = project.encode()
for name in ['OrcaPlayer-iOS', 'OrcaPlayer-macOS']:
    rel = f'OrcaPlayer.xcodeproj/xcshareddata/xcschemes/{name}.xcscheme'
    files['Apple/' + rel] = (apple / rel).read_bytes()
files['請先閱讀-安裝指南.md'] = (root / 'docs/release/朋友免費帳號安裝指南.md').read_bytes()
for name, data in files.items():
    assert not any(x in name for x in ['Signing.local', '.build', 'xcuserdata', '.git/', '.p12', '.mobileprovision'])
    if name.endswith(('.swift', '.json', '.plist', '.xcprivacy', '.pbxproj', '.xcscheme', '.md')):
        text = data.decode()
        assert not re.search(r'/Users/|PRIVATE KEY|@gmail\.com|@icloud\.com|PROVISIONING_PROFILE\s*=', text), name
manifest = {name: hashlib.sha256(data).hexdigest() for name, data in files.items()}
files['SHA256-MANIFEST.json'] = (json.dumps(manifest, ensure_ascii=False, indent=2)+'\n').encode()
output.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as z:
    for name, data in files.items():
        z.writestr('MusicPlayer-Friend-Test/' + name, data)
with zipfile.ZipFile(output) as z:
    assert z.testzip() is None
    assert len(z.namelist()) == len(files)
    for name, checksum in manifest.items():
        assert hashlib.sha256(z.read('MusicPlayer-Friend-Test/' + name)).hexdigest() == checksum
print(f'PASS: {len(files)} allowlisted files, ZIP integrity and manifest verified')
print(output)
print('ZIP SHA256:', hashlib.sha256(output.read_bytes()).hexdigest())
