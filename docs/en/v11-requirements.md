# V11 requirements — 2026-10-29

The user handed over six annotated reference images:

1. Standardize Edit Playlist and Edit Artist to match the song editor: upper-left heading, a camera menu at the top-right of the picture for photo/file actions, no separate photo-action text row, a white text field, and Cancel/Save text controls without blue backgrounds. Apply the plain footer style to the song editor too.
2. Redesign Add Artist using the same editor layout and photo selection, rather than a centered heading and a single dark name field.
3. Reduce the empty area above the artist grid and display “N artists” on the left, in the same visual style as All Songs' count. Keep sorting on the right.
4. On Home, pull downward over playlists to reveal all playlists automatically; remove the visible Show All Playlists button. Support horizontal swipes to select Playlists, Artists and All Songs. Keep a compact preview when returning Home, and preserve accessible expand/collapse actions.
5. Fix the initial playlist detail carousel offset: selecting the second or later playlist must center its own cover, not retain a dimmed previous playlist cover while the title and tracks have already changed.
6. Fix the same initial offset mismatch for artist detail; cover, title, brightness and song list must refer to the same selected artist.

Preserve existing music, IDs, ratings, sound profiles, automatic classification and background audio. Use owned color fixtures for regression checks; do not ship the user's screenshots or private covers. Continue external development journals while keeping them excluded from the user-facing app per V10. Validate behavior and update the device/source test package, with GitHub synchronization reported only after remote verification.
