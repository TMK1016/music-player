# V9 requirements — 2026-10-29

1. Switching the equalizer off must return the current sound and displayed mode to Original, rather than leaving the last selected Pop or other mode visible or ready to resume. Preserve saved custom presets and the user's library.
2. Fix the Home/Playlists scrolling loop that prevents scrolling upward from the bottom of the rankings.
3. Remove the blocking “Playback was interrupted by the system; restart playback when convenient” alert shown in IMG_9858.png, so returning users can continue operating the app. Keep necessary audio-session interruption handling; do not claim that iOS interruptions can be disabled.
4. Follow the supplied annotated reference images: playlist cover cards in a two-column grid, pull down to expand all playlists, a plus card for creation, and rankings following the playlist section. Tapping a playlist opens its own page with large cover, fading background, complete lazy song list and Play All.
5. Center the six-tool strip under the album artwork, independently of its right-side disclosure arrow; keep that arrow on the right.
6. Fix touch/scroll dead areas reported while custom artwork is active; make the mini-player play/pause icon white.
7. Replace the artist rows with a three-column circular portrait grid, including an Add Artist control. Tapping an artist opens the same detail-page pattern; preserve editing and reordering via long press.
8. Add compact song cover and artist information to ranking rows. Keep rank outside the left edge and numeric play count outside the right edge; omit the Chinese count suffix.

Image references were found in the workspace root and inspected. Do not copy the user's private screenshots/media into the source distribution. Original source ZIP22 remains a historical deliverable; package the next source version separately.
