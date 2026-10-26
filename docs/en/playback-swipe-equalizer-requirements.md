# Playback redesign requirements

New skills have been installed for the upcoming UI/UX upgrade. The two screenshots, “Screenshot 2026-10-26 15.30.45” and “Screenshot 2026-10-26 15.30.53,” show the user's intended layout. The second represents swiping the album artwork to the right. Redesign according to these references so users can adjust the equalizer while listening.

Annotations on the first screenshot: remove the technical playback status row and the upper equalizer-mode label; when unrated, show five outlined stars and allow swipe rating. Group Add to Playlist, Favorite and Sleep Timer into one action row. Consolidate repeat-one, loop-playlist and shuffle into one playback-mode control. The second screenshot replaces the artwork area with the seven-band equalizer while progress and playback controls remain below.

Implementation: keep a shared PlayerModel and uninterrupted audio while switching artwork/EQ faces. Restrict the reveal gesture to the artwork; provide explicit buttons and accessibility alternatives. Keep the progress and transport outside the scrollable content. Existing global/per-song profile policy is moved to Settings rather than removed. No new audio algorithm, vehicle settings or Bluetooth input is introduced.
