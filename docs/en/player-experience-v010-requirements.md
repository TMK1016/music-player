# Music Player v0.10 — translated user requirements

Source: user handoff dated 2026-10-26; original notes remain unchanged in `notes/專案主筆記.md`. Reference screenshots are in `docs/design/references/`. This request supersedes conflicting v0.9 interactions.

## Home
1. Search songs: remove recent-search functionality. Display matching songs as a list immediately below the search field.
2. Import music: retain the header design shown in IMG_9770.
3. Library area: show all playlists as full rows, following IMG_9784; retain artists and all songs.
4. Retain listening rankings.
5. Each song has its own white background at 50% opacity.
6. Edit song information: a text field for title and a text field for artist. Focusing the artist field opens the keyboard and shows tags for artists previously entered. Use the themed translucent sheet style in IMG_9771.

## Now Playing
1. Add an edit-song-information icon.
2. Rating at upper left: five outlined stars when unrated; show the assigned number of stars when rated.
3. EQ at upper right: default name Original Sound (原聲); show the current mode name, such as Vocals.
4. Show album cover, song title and artist.
5. Feature row: add/remove playlist membership; favorite; sleep timer. A short favorite press only toggles favorite. A long press wiggles the heart and opens a small panel where horizontal dragging chooses a star rating. Timer supports setting and cancelling.
6. Seek bar: small square thumb while playing; enlarged square while dragging.
7. Playback mode: exactly three icon states, switched by tapping the icon — shuffle, playlist repeat and repeat one.
8. Retain play/pause and previous/next track.
9. Second face: EQ and bass. Swipe album art left or tap the mode label to enter; swipe right on the second face to return to the cover.
10. Bass: horizontal slider with ten discrete positions; label left, slider right. Put the whole row on white to separate it from EQ.
11. EQ: response illustration and seven upright sliders, all visible. Mode tags form one horizontal row. Swiping only browses; a tag is selected only by tapping. Do not expand a full mode list. Long-press and drag a tag to reorder it.
12. Add custom mode: centered theme-matching name dialog. Manual changes reveal “+新增模式”. Preserve the existing maximum of 20 custom profiles.
13. Fit bass and EQ in one surface with no vertical scrolling, shrinking/reflowing appropriately.

## Settings
1. EQ adjustment.
2. Sleep mode: time countdown (5/10/20 minute presets, custom 1–120 minutes) or song countdown (3/5/10 song presets, custom 1–100 songs). Use IMG_9771 for the main bottom sheet and IMG_9772 for the minimal wheel picker. Start and cancel must be buttons, green and red respectively.
3. Share with friends.
4. Feedback: follow the email-composer layout in IMG_9783; recipient is admin@monstrai.com. The user sends from their mail account; implementing this feature does not authorize sending a test email.
5. Privacy: the supplied English text is already English and is preserved verbatim in the original note. It is an incomplete service agreement, ending at “criminal i”, referring to advertisements and commercial data sharing. Do not invent its missing ending or represent these clauses as implemented data practices. Keep an accurate local-build privacy disclosure, updated for user-initiated email feedback, until the operator supplies a complete applicable agreement.

## Reliability and delivery
Use the available PM and UI/UX skills to improve all specified areas. Fix playback stopping when returning to the Home screen or switching pages, and flashing menus (including sleep menus). Compile and run appropriate regression checks, update the interactive flow and journal, deploy automatically to the connected iPhone and back up to the private Git repository. Report actual verification separately from implementation and untested device behavior.
