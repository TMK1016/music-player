# Music Player project instructions

Read ../../TMK準則.md and ../../AGENTS.md first. These rules apply only to this project.

For `projects/music-player`, read `README.md`, `docs/zh-TW/需求與開發路徑.md`, `docs/zh-TW/本機音訊實作與驗收.md`, and `planning/flow.json`. Native SwiftUI local import/playback and Apple EQ now exist under `apps/apple/`; Rust DSP is not implemented. The user approved the technology-blue style and authorized the next local-audio stage. Final in-car platform and hardware routing still require confirmation. Keep the native backend isolated behind `AudioPlayback`; do not claim it is Rust. Historical v0.1 documents describe UI-only behavior.

Keep task status and evidence accurate. A planning graph is not runtime monitoring. Repair work within an agreed node can proceed; discuss changes to scope, topology, major dependencies, or hardware assumptions with the user before implementing those changes. User instructions override these workspace defaults.

Every project update must also update the interactive flow and its development journal. For Music Player, append an entry/change to `planning/changelog.json`, map changes to existing stable node IDs and real source/evidence paths, update `planning/flow.json` as warranted, run `planning/build_inspector.py` and `planning/validate_plan.py`, and synchronize the native journal bundle through `scripts/generate_xcode_project.py` before packaging. Preserve historical scope. A change is not ready for delivery until its journal/location links match the final implementation.

Current Music Player v0.4.1 retains native bass shelf/reverb, 13 factory and at most 20 custom sound profiles, per-song bindings, and persisted vehicle configuration. Read `projects/music-player/docs/zh-TW/音效模式與車輛調音.md` and `音效模式驗收.md` before extending audio or calibration. Confirmed car is a 2017 Ford Fiesta B299-7v connected by Bluetooth without an external DSP. The app remains stereo; speaker inventory must never be represented as active per-driver routing/crossover/calibration. No measured Fiesta correction or Dolby implementation exists.

The user explicitly removed seat-distance entry and delay references in v0.4.1 because ordinary users do not need them. Do not reintroduce that UI or calculation without a new request. See `projects/music-player/docs/zh-TW/車輛設定簡化.md`.

Music Player v0.5 replaces positive-gain summation with `EQHeadroom.swift` combined-response estimation plus a 3 dB margin; nonzero reverb mix retains 6 dB reserve. It is not loudness matching, a limiter, or a true-peak guarantee. Read `docs/zh-TW/EQ音量處理技術.md` relative to the project. Regenerate the interactive technical examples with `scripts/generate_eq_technical.py` whenever the estimator changes, and validate against native PCM. The user requests one audio strategy at a time; B/C/D remain options, not authorized simultaneous implementation.

Obsidian is now the user’s project-note entry point. Read `projects/music-player/notes/專案主筆記.md` when taking a note-based task. Preserve user-authored content; append clearly separated results. A saved note alone is not an instruction to run tasks; the user hands it over after editing. Keep source Markdown and export only to requested formats.

Current Music Player v0.6 uses 7 bands via `EQBands.swift` (50/125/315/800/2000/5000/12500 Hz; 4/3-octave bandwidth). Do not retain hard-coded ten-band counts in current audio/UI. v3 settings migrate v1/v2 and preserve a raw preferences backup in the app. Read `projects/music-player/docs/zh-TW/七段等化器與模式管理.md`. The mode strip and full picker share `modeOptions`; custom additions/deletions, builtin removal/restore and song-binding cleanup must stay consistent.

Music Player v0.6.1 expands modes inline below the horizontal strip; do not restore the modal mode browser. Manual EQ slider edits offer a nonblocking save-new-mode button. Naming remains a sheet opened explicitly. See docs/zh-TW/模式內嵌展開與儲存提示.md in the project.

Public project name: Music Player. Legacy OrcaPlayer Xcode/source identifiers, app bundle IDs, library paths, preference keys and annotation storage keys are compatibility identifiers; do not rename them without a data migration.

## PM workflow

For major planning, new features, scope changes and delivery acceptance, read `../../Github/PM-skill/project-pm/SKILL.md`. Current product baseline: docs/product/PRD-music-player.md; PM task source: planning/pm-plan.json; engineering state: planning/flow.json. Map tasks using stable node_ids, preserve user notes, and update PM acceptance/changes when scope changes. Candidate notes are not implementation authorization. Validate PM mappings with planning/validate_plan.py. Small fixes reuse existing scope.
