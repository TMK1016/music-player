# Home continuous scrolling requirements

Version 0.19.0 / build 26 — 2026-10-29

The user reports jerky scrolling in the three Home categories, with accidental content activation during swipes. Preserve horizontal category navigation while keeping vertical scrolling native and continuous. Avoid opening songs or collections during a drag or deceleration.

Playlists must remain a single continuous grid, rather than suddenly replacing a compact preview with the complete list. Aim to reveal part of the third row on typical phone layouts so users can discover additional content; do not truncate the underlying list. Place Add Playlist after every visible playlist.

Use the same count-and-sort row across Playlists, Artists and All Songs: counts on the left, sorting on the right, matching width, height and spacing. Remove the oversized blank region above Artists. Preserve the music library, manual ordering, playback and existing metadata.

Acceptance: lazy full-library presentation; normal stationary taps work; scrolling does not publish whole-Home state updates for every position; drag/deceleration suppresses accidental activation; playlist sorting persists with backward-compatible data. Model checks and native UI inspection are engineering evidence, not measured phone frame-rate or an audio glitch-free guarantee.
