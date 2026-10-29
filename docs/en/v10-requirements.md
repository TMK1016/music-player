# V10 requirements — annotated references, 2026-10-29

1. Artist grid: replace the small add control with a full circular gray tile containing only a plus symbol. Keep an accessibility label without visible caption.
2. Artist detail: remove the library header so the page extends upward. Center the artist name below the portrait. Add a horizontally snapping cover carousel to select adjacent artists; dim the neighboring covers and restore normal brightness to the selected one. Provide icon-only Play All, Edit Artist (name/photo), and Add Songs with search. Pressing the Home tab must return to the library root.
3. Playlist detail: apply the same carousel and layout to adjacent playlists. Use an owned default image if no custom playlist cover exists, rather than borrowing the first song's artist image. Provide icon-only Play All, Edit Playlist and searchable Add Songs. Home returns to the library root.
4. Playlist grid: reduce placeholder symbols approximately 20 percent within their existing cards. Replace the small add button with a full rounded gray square containing only a plus symbol.
5. Create Playlist: show a default cover with a camera menu for selecting/cropping a user image, a white name field, and Cancel/Save controls. Save name and optional chosen image together. The supplied portrait is an example, not an asset to ship.
6. Remove developer journal access from the user app; continue maintaining the project's external interactive flowchart and development journal. Change Home's upper-right plus button to open the existing Settings/Local Music Search flow.
7. Keep the Playlists/Artists/All Songs segmented control at the same fixed position and height across all three sections.

Preserve music, ratings, saved sound profiles and compatibility identifiers. Keep automatic playlists governed by their existing date/rating rules: adding songs must not silently change ratings or import timestamps. Manual additions are supported for custom playlists, Favorites and artist assignment; artist assignment must disclose that it changes the song's artist classification. No Android port or TestFlight membership change is included.
