# V8 requirements — user request, 2026-10-28

1. Show rankings only in Home → Playlists. Hide them in Artists and All Songs.
2. Remove the initial 50-song display limit in Home → All Songs.
3. Replace the All Songs sorting choices with: stroke order (ascending by default), preference/rating (highest stars first), and recently added (newest first). Selecting the currently selected mode again reverses its direction. Ascending ratings start with unrated songs, treated as zero stars. Persist the selected mode and direction.
4. The user reports a quota reset at 06:25 and requests resuming pending work at 06:30, preserving at least 5% beforehand. Use the Astra model to review and rewrite/refactor the complete project so architecture and flows become consistent after repeated incremental edits. Apply relevant skills. The objective is a smooth, complete app. Current features/UI are mostly settled; preserve approved behavior while restructuring.

Execution date: 2026-10-28 06:30 Asia/Taipei. Do not claim the model, quota refresh, wake-from-sleep or eventual success is guaranteed merely because a schedule was saved.

## Execution and acceptance contract

The run must execute once, write a timestamp to backups/local/v8-0630-started, and disable its automation. Confirm gpt-6-astra/high; do not silently switch models. Preserve at least 5% of readable service quota; save an actionable handover before crossing the reserve. Continue independent work when device/external conditions are unavailable and record the limitation.

Use PM and engineering skills; complete the three V8 features first, inventory the entire project, then refactor in tested stages. Preserve user data, existing features, AudioPlayback isolation, seven-band EQ/headroom and v0.14.1 asynchronous session/Sendable artwork fixes. Update flow/journal at each stage, build, update the connected phone, commit/push the project repository and verify the remote SHA.

Stroke means Traditional Chinese per-character zh_Hant_TW stroke collation, with numeric comparison, empty titles first and stable ID ties. Rating and date ties use title/ID order; reversal reverses the complete order. Optional songSortAscending preserves collection-v1 compatibility. Legacy title sorting maps to stroke; legacy artist/custom ordering remains until a new choice is made. The old songOrder is never erased by the menu. Execution evidence is maintained in docs/zh-TW/V8實作與架構驗收.md.
