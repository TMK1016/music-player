"""Assessment-only synthetic benchmark; does not modify the product or user library."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
apple = root / 'apps/apple'
build = apple / '.build/v7-assessment'
build.mkdir(parents=True, exist_ok=True)
files = ['AudioPlayback', 'EQBands', 'EQHeadroom', 'SoundProfiles', 'LibraryStore', 'PlayerModel', 'MusicCollection', 'CollectionWriter']
command = ['swiftc', '-O', '-swift-version', '6', '-target', 'arm64-apple-macos14.0', '-module-cache-path', str(apple / '.build/ModuleCache-v07.noindex')]
command += [str(apple / 'OrcaPlayer' / (name + '.swift')) for name in files]
command += [str(apple / 'Tests/LibraryPerformanceProbe.swift'), '-o', str(build / 'library-probe')]
subprocess.run(command, check=True, timeout=180)
result = subprocess.run([str(build / 'library-probe')], check=True, text=True, capture_output=True, timeout=300)
(build / 'result.json').write_text(result.stdout)
print(result.stdout, end='')
