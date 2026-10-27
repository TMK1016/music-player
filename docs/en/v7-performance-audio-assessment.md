# V7 requirements — audio continuity and large-library performance

2026-10-28. This is an assessment and proposed next design, not a shipped app release. Product baseline remains 0.13.1 / build 17. User-authored Chinese notes are preserved separately.

## Full translation of the request

1. Unwanted noise still occurs while operating the app. This is a technical priority and may involve an architectural problem. Investigate it instead of assuming the earlier mitigation has solved it.
2. More than 1,000 songs have been imported. Severe stuttering occurs both when switching Home and other main pages, and when switching Playlists / Artists / All Songs within Home. Loading songs is the user's suspected cause, not an established fact. Find a fast, smooth approach suitable for normal use.
3. In Home / All Songs:
   - The Custom Order control at the upper right cannot be pressed. Design it as a functional control, following the Artists sorting interaction.
   - Consider this idea: opening Home should not load everything if the user does not need All Songs. After selecting All Songs, initially show 50 songs; at the bottom, offer a way to load the remaining songs. Evaluate this against common approaches first, then proceed to the next design step. The idea is a candidate, not a mandated solution.
4. Reference 20261028011733: use a plain ellipsis at the right of each song and place Favorites inside the resulting action sheet. Retain Favorite toggle, five-star rating, song edit, playlist addition and deletion of the app's audio copy. Much of this reference repeats V6; verify current behavior rather than treating it as an entirely new feature.
5. Reference 20261028011738: give the mini-player stronger separation from the background. The later 011814 reference supersedes its visual direction.
6. Reference 20261028011743: redesign the expanded six-tool strip, while preserving the current position of its right-side expand/collapse arrow.
7. Reference 20261028011748: redesign song editing. Use a centered cover with a camera control on it; tapping the control opens Choose Photo / Remove Photo actions. Put labelled Song and Artist fields below, and Cancel / Save actions at the bottom. Keep crop selection and artist-photo fallback behavior. Removing the individual song cover means returning to the established artist fallback, unless the user explicitly changes that rule.
8. Reference 20261028011753: remove the textual Clear Rating button. Show a trash icon to the right of the five-star row only when a rating exists; hide it for an unrated song and immediately after clearing. This icon clears the rating, not the music file.
9. Reference 20261028011802: the lock-screen media widget is missing the in-app cover. Supply the correct current artwork to the system media metadata, including when the song or applicable artist photo changes.
10. Reference 20261028011808: reduce spacing and padding around EQ mode tags, both vertically and horizontally. Preserve accessible hit areas and tap-to-select / long-press reorder behavior.
11. Reference 20261028011814: propose a more refined mini-player, optionally using the current cover as a blurred background, and separate it visually from the tab bar below. This is a proposed art direction; performance is a higher priority than a costly live blur.

## Assessment boundaries

Use only synthetic data for reproducible isolated probes. Distinguish source-code findings, desktop computation probes, device UI traces and audible device playback. A smaller displayed batch does not fix expensive whole-library aggregation, and a desktop probe is not a phone latency measurement. No production playback, data schema or native UI changes are part of this assessment delivery. Proposed migrations or audio backend changes require review of concrete scope and evidence first.

Implementation authorized by the user on 2026-10-28: complete all V7 changes and install on the connected iPhone. See the separate v0.14 implementation/verification document; this assessment remains historical.
