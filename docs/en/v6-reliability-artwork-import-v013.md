# V6 — continuity, artwork and library controls

User request translated in full, 2026-10-27. Current implementation version: 0.13.1 / build 17. Delivery and verification are recorded separately in the Traditional Chinese acceptance document.

1. Fix the brief speaker noise when tapping the `<` tools button on Now Playing.
2. Put that button on the right edge.
3. Add persistent custom ordering to All Songs on Home, using the same long-press/reorder interaction as Artists.
4. Fix brief noise during listening when changing an artist photo, taking a screenshot, or doing similar operations. Record all previously reported problems and their status in the development log. Do not claim hardware noise elimination based solely on a successful build.
5. Add album-cover replacement to song metadata editing. If a song has no individual cover, use the associated artist's photo as its default. Keep individual cover priority and allow returning to the artist fallback.
6. After selecting an image, open a crop editor. Clearly show the centered crop frame; allow positioning and zooming before confirmation. Apply to songs, artists and playlists. Cancellation must retain the previous image.
7. Match IMG_9806.jpg's artist-row composition: larger circular portrait, name and secondary artist information. Highlight the selected/expanded row with a glowing white border, including playlist rows.
8. The annotated Settings reference (20261027142852) requires Source and Output to use the same row format as the other settings. Remove the highlighted lower Song Binding / More Settings group from this page. Keep existing data and the Now Playing EQ song-binding control. Development Log remains reachable through the Home sidebar.
9. Add Find Local Songs to Settings. Ask for a directory the system permits the app to read, scan its downloaded audio recursively, exclude already imported byte content and duplicates, then show the complete candidate list with selection checkboxes. Import only checked candidates after an explicit action. Show a rotating radar during scanning and stop it when results arrive. Never imply unrestricted access to the entire iPhone. Do not automatically fetch remote cloud content.
10. The annotated song-menu reference (20261027144258) requests a plain ellipsis at the right of each song and moves Favorites into the action sheet. Keep: Favorite toggle, five outlined/fillable rating stars, song editing, add/remove playlist membership, and deletion of the app's audio copy with a second confirmation. Preserve external source files.
11. The mini-player reference (20261027144542) requests stronger visual separation from the background. Use the established blue palette with an inset rounded elevated bar, border and visible transport controls.

Engineering acceptance: no UI drawer action should load/stop/reconnect audio or rebuild its native output picker; image decode/downsampling/cropping and collection serialization/writes stay off the main actor. Persist song ordering/covers without renaming content IDs or legacy storage. Test empty scans, corrupt audio, duplicated bytes, cloud placeholders, cancellation, source permission failure, crop bounds/orientation, artist fallback and restart persistence. iPhone speaker/Bluetooth noise reproduction remains a distinct device acceptance step.
