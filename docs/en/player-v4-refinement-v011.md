# Music Player v4 refinement — complete English requirements

User handoff: 2026-10-27. Product version for this iteration: 0.11.0 / build 14. Original user notes remain unchanged. This specification supersedes conflicting earlier UI details.

## Home
- Remove recent search; display search results directly under the field as song rows. Retain the music-import header shown in IMG_9770.
- Display all available playlists as rows like IMG_9784; remove the “All playlists” heading/button.
- Long press a playlist to edit its photo/name, edit/remove its songs, hide it, or delete it (red destructive label). Long press followed by vertical dragging reorders playlists. Deleting a custom playlist never deletes music files.
- Automatic playlists: Favorites; Recently Added (last seven days); 5, 4, 3, 2 and 1 star lists (use star glyphs in their default names); Liked songs; Unfamiliar songs. Show a list when it contains qualifying songs, rather than showing empty lists at startup. Recently Added appears upon importing an eligible file, even without a rating/favorite. Hidden system lists can be restored; custom lists can be hidden or deleted.
- The whole playlist row must expand/collapse, including blank space. The home page also needs current-song membership controls: a green check for membership, tapped again to remove it. Confirmed implementation: the full row expands/collapses; a separate 44-point control on the right toggles membership. The song-to-playlist picker also supports full-row membership toggling.
- Confirmed follow-up: automatic rating/date categories display membership only; they must not silently change ratings/import dates. Custom lists and Favorites support direct membership toggling. Unrated songs remain excluded from liked/unfamiliar lists; a 3-star song remains in both.
- Tapping an artist expands only its songs, closing the previous artist. Move editing into a long-press menu: Edit information and Reorder. Artist editing opens a photo/name dialog following the supplied 11:49 reference. Long-press/vertical dragging reorders artists; retain explicit move alternatives. Put sorting on the right and use white text instead of dark blue.
- Retain all songs.
- Rankings: monthly/cumulative choices use a horizontal segmented control. Each song card contains only a single-line title; rank sits outside the card on the far left and listening count outside on the far right. Sort descending by play count. Preserve the existing interpretation of the second ranking as cumulative.
- Home song cards have opaque white backgrounds (supersedes 50% opacity). Song editor retains title/artist fields; focusing artist shows keyboard and existing artist tags. Use the sheet style shown in IMG_9771.

## Now Playing
- Remove the top-left “Now Playing” title. Center the originating playlist name at the top as in IMG_9787. Searches/artists/rankings/all-songs playback show their actual queue context.
- First face: rating upper left (five outlined stars when unrated, assigned number when rated); current EQ mode upper right, default 原聲; album cover, title and artist.
- Initially show only a left chevron for the tools drawer. Confirmed: expanding it shows all SIX tools in order: edit song; sleep timer; playlist membership; favorite; playback mode; speaker/output selector. Favorite short press toggles favorite only; long press wiggles and opens a swipeable star panel. Playback mode cycles shuffle/playlist-repeat/repeat-one with distinct icons. Speaker selects available audio OUTPUT devices, including connected Bluetooth devices, rather than receiving Bluetooth input.
- Seek bar uses a small square normally and an enlarged square while dragging. Keep play/pause and previous/next; move them upward to leave a gap above bottom navigation.
- Second face: swipe album art left or tap the EQ mode to enter; swipe right to return, with an explicit back alternative.
- Bass is a ten-position horizontal slider; label left and slider right, the entire row white.
- EQ has response illustration, seven upright faders, and a horizontal mode strip. Swiping only browses; only tapping selects. Never expand the full list. Long-press drag reorders. Center the selected tag, including the first/last. A circular end-to-start presentation is an optional enhancement, not a prerequisite.
- Custom mode uses a centered themed naming dialog. Manual tuning shows “+新增模式”. Retain the twenty-custom-profile limit.
- Give EQ the region from below the centered queue title to above seek/transport. Hide stars on the second face. Approximately halve fader height and give the released space to the curve. No vertical scrolling; adapt layout to fit bass plus all seven faders and mode selection in one surface.

## Settings
- Retain EQ.
- Sleep supports minutes (5/10/20 presets, custom 1–120) and songs (3/5/10 presets, custom 1–100). Make whole preset rows tappable, including middle/trailing blank space. Show remaining countdown and estimated end time. Omit “Not set” beside the setting when inactive.
- Use the rounded sheet in IMG_9771 and minimal wheel in IMG_9772; green Start and red Cancel buttons. Fix the blue/black mismatch shown in the 11:39 screenshot by using one consistent neutral sheet surface.
- Retain sharing; prior feedback/privacy behavior remains available.

## Delivery and verification
Use PM and UI/UX skills, preserve user media/settings, record acceptance evidence in the interactive flow and journal. Build, run meaningful regression checks, inspect narrow/landscape layouts, then deploy to the connected iPhone. Back up the project to its private GitHub repository; verify remote SHA before claiming synchronization. Background playback/menu-clock fixes from v0.10 must be preserved. Actual iPhone gestures, Bluetooth and locked-screen tests must not be claimed from compilation alone.
