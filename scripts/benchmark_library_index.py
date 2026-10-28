"""Measure the production V7 metadata index with synthetic data and no speaker output."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
apple = root / 'apps/apple'
build = apple / '.build/v7-index-benchmark'
build.mkdir(parents=True, exist_ok=True)
files = ['AudioPlayback', 'EQBands', 'EQHeadroom', 'SoundProfiles', 'LibraryStore', 'PlayerModel', 'NowPlaying', 'PlaybackPolicy', 'TrackMetadata', 'HomeLibraryState', 'MusicCollection', 'CollectionWriter', 'LibraryIndex']
command = ['swiftc', '-O', '-swift-version', '6', '-target', 'arm64-apple-macos14.0', '-module-cache-path', str(apple / '.build/ModuleCache-v07.noindex')]
command += [str(apple / 'OrcaPlayer' / (name + '.swift')) for name in files]
command += [str(apple / 'Tests/LibraryIndexBenchmark.swift'), '-o', str(build / 'index-benchmark')]
subprocess.run(command, check=True, timeout=180)
result = subprocess.run([str(build / 'index-benchmark')], check=True, text=True, capture_output=True, timeout=120)
(build / 'result.json').write_text(result.stdout)
print(result.stdout, end='')
