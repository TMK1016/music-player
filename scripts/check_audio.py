"""Run isolated library/player checks and build a GUI-hosted offline EQ verifier."""
from pathlib import Path
import plistlib
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
apple = root / "apps/apple"
build = apple / ".build/checks"
build.mkdir(parents=True, exist_ok=True)
common = ["swiftc", "-swift-version", "6", "-target", "arm64-apple-macos14.0", "-module-cache-path", str(apple / ".build/ModuleCache-v07.noindex")]
backend = apple / "OrcaPlayer/AudioPlayback.swift"
native_checks = apple / "Tests/NativeEQChecks.swift"
if "--native-only" not in sys.argv:
    cli = build / "audio-checks"
    subprocess.run(common + [str(apple / "Tests/BassPlanChecks.swift"), str(backend), str(apple / "OrcaPlayer/PeakControl.swift"), str(apple / "OrcaPlayer/AudioLevelMeter.swift"), str(apple / "OrcaPlayer/BassAnalysis.swift"), str(apple / "OrcaPlayer/EQBands.swift"), str(apple / "OrcaPlayer/EQHeadroom.swift"), str(apple / "OrcaPlayer/SoundProfiles.swift"), str(apple / "OrcaPlayer/LibraryStore.swift"), str(apple / "OrcaPlayer/PlayerModel.swift"), str(apple / "OrcaPlayer/NowPlaying.swift"), str(apple / "OrcaPlayer/PlaybackPolicy.swift"), str(apple / "OrcaPlayer/TrackMetadata.swift"), str(apple / "OrcaPlayer/HomeLibraryState.swift"), str(apple / "OrcaPlayer/MusicCollection.swift"), str(apple / "OrcaPlayer/LibraryIndex.swift"), str(apple / "OrcaPlayer/CollectionWriter.swift"), str(apple / "OrcaPlayer/LibraryScan.swift"), str(apple / "OrcaPlayer/CropGeometry.swift"), str(apple / "Tests/AudioChecks.swift"), str(apple / "Tests/LibraryIndexChecks.swift"), str(native_checks), str(apple / "Tests/V14Checks.swift"), "-o", str(cli)], check=True)
    result = subprocess.run([str(cli), str(build), str(apple / "Resources/Orca-Soundcheck.wav"), "--model-only"], text=True, capture_output=True)
    (build / "results.log").write_text(result.stdout + result.stderr)
    print(result.stdout, end="")
    if result.returncode:
        print(result.stderr, end="")
        result.check_returncode()
contents = build / "NativeEQValidation.app/Contents"
(contents / "MacOS").mkdir(parents=True, exist_ok=True)
info = {"CFBundleIdentifier": "com.orca.player.audio-validation", "CFBundleExecutable": "NativeEQValidation", "CFBundleName": "Orca EQ Validation", "CFBundlePackageType": "APPL", "LSMinimumSystemVersion": "14.0", "NSHighResolutionCapable": True, "ReportPath": str(build / "native-eq-result.txt")}
(contents / "Info.plist").write_bytes(plistlib.dumps(info))
subprocess.run(common + [str(apple / "Tests/BassPlanChecks.swift"), str(backend), str(apple / "OrcaPlayer/PeakControl.swift"), str(apple / "OrcaPlayer/AudioLevelMeter.swift"), str(apple / "OrcaPlayer/BassAnalysis.swift"), str(apple / "OrcaPlayer/EQBands.swift"), str(apple / "OrcaPlayer/EQHeadroom.swift"), str(apple / "OrcaPlayer/SoundProfiles.swift"), str(native_checks), str(apple / "Tests/V14Checks.swift"), str(apple / "Tests/ValidationApp.swift"), "-o", str(contents / "MacOS/NativeEQValidation")], check=True)
print("Open this native verifier to test real offline PCM without speaker output:")
print(contents.parent)
print("Result is written to: " + info["ReportPath"])
