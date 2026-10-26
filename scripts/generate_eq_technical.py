"""Export interactive examples using the exact Swift estimator used by the app."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
build = root/'apps/apple/.build/checks'
build.mkdir(parents=True, exist_ok=True)
exe = build/'export-eq-technical'
subprocess.run(['swiftc', '-module-cache-path', str(root/'apps/apple/.build/ModuleCache.noindex'), str(root/'apps/apple/OrcaPlayer/SoundProfiles.swift'), str(root/'apps/apple/OrcaPlayer/EQBands.swift'), str(root/'apps/apple/OrcaPlayer/EQHeadroom.swift'), str(root/'scripts/export_eq_technical.swift'), '-o', str(exe)], check=True)
subprocess.run([str(exe), str(root/'planning/eq-technical-source.json'), str(root/'planning/eq-technical.json')], check=True)
print('Exported EQ technical examples from production Swift estimator')
