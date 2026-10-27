"""Reproduce the frozen pre-V7 baseline; does not modify product/user data."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
apple = root / 'apps/apple'
build = apple / '.build/v7-assessment'
sources = build / 'baseline-source'
sources.mkdir(parents=True, exist_ok=True)
baseline = '330020e'
files = ['AudioPlayback', 'EQBands', 'EQHeadroom', 'SoundProfiles', 'LibraryStore', 'PlayerModel', 'MusicCollection', 'CollectionWriter']
paths = ['apps/apple/OrcaPlayer/' + name + '.swift' for name in files] + ['apps/apple/Tests/LibraryPerformanceProbe.swift']
inputs = []
for path in paths:
    result = subprocess.run(['git', 'show', baseline + ':' + path], cwd=root, check=True, capture_output=True)
    target = sources / Path(path).name
    target.write_bytes(result.stdout)
    inputs.append(str(target))
command = ['swiftc', '-O', '-swift-version', '6', '-target', 'arm64-apple-macos14.0', '-module-cache-path', str(apple / '.build/ModuleCache-v07.noindex')]
command += inputs + ['-o', str(build / 'library-probe')]
subprocess.run(command, check=True, timeout=180)
result = subprocess.run([str(build / 'library-probe')], check=True, text=True, capture_output=True, timeout=300)
(build / 'result.json').write_text(result.stdout)
print(result.stdout, end='')
