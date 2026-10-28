"""Build a separate silent native QA app using production views and 1230 synthetic tracks."""
from pathlib import Path
import plistlib
import subprocess
root = Path(__file__).resolve().parents[1]
apple = root / 'apps/apple'
app = apple / '.build/checks/V8UIValidation.app'
contents = app / 'Contents'
(contents / 'MacOS').mkdir(parents=True, exist_ok=True)
(contents / 'Resources').mkdir(exist_ok=True)
(contents / 'Resources/changelog.json').write_bytes((root / 'planning/changelog.json').read_bytes())
(contents / 'Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'com.orca.player.v8-validation', 'CFBundleExecutable': 'V8UIValidation',
    'CFBundleName': 'Music Player V8 QA', 'CFBundlePackageType': 'APPL',
    'LSMinimumSystemVersion': '14.0', 'NSHighResolutionCapable': True,
}))
sources = sorted(p for p in (apple / 'OrcaPlayer').glob('*.swift') if p.name != 'OrcaPlayerApp.swift')
subprocess.run(['swiftc', '-swift-version', '6', '-target', 'arm64-apple-macos14.0',
                '-module-cache-path', str(apple / '.build/ModuleCache-v07.noindex'),
                *map(str, sources), str(apple / 'Tests/V8UIValidationApp.swift'),
                '-o', str(contents / 'MacOS/V8UIValidation')], check=True)
print(app)
