# Complete English translation: functionality and UI/UX

The ideas are divided into functionality and page layout.

## Page layout

The bottom navigation has Home, Now Playing, and Settings.

### Home

At the upper left, provide song search and recent search results. At the upper right, provide Import Music to add songs from local files.

The first section switches horizontally between library categories: Playlists, Artists, and All Songs.

Playlists: users can reorder the lists and add or remove them. System-created lists include Favorites, Recently Added, 5 Stars, 4 Stars, 3 Stars, 2 Stars, 1 Star, Preferred Songs, and Unfamiliar Songs. Also show user-created playlists. Place an Add Playlist button below the lists so users can create and name another playlist.

Artists: sort by criteria including song count, name stroke count, and preference level. Show artist names and avatars as a list. Tapping an artist expands a hierarchical list of all their works; it can be collapsed. Expanding a different artist collapses the previous one.

All Songs: show every song in the library.

The second section is Rankings, recording listening habits. Offer Monthly Rankings and Individual Song Rankings, both ordered by the user's listening count, descending by default. The exact distinction beyond the monthly scope is not yet specified.

### Now Playing

Place its navigation icon at the bottom center. Tapping it opens a single-page player. Above the artwork toward its upper right, show a row containing an equalizer label and star rating. Show the artwork in the upper middle, the song title below it, then playback position and duration. At the bottom, show play/pause and previous/next controls.

Functions:
- Favorite: tap to save to Favorites; long-press to enter 1–5-star rating mode.
- Add to Playlist: choose the destination playlist.
- Playback modes: replay, shuffle, and loop playlist.
- Equalizer/bass boost: select sound modes. Support one mode that uses the same equalizer for all music, and another that assigns a particular equalizer to a particular song.

### Settings

Provide duplicate-song search and the equalizer editing functionality from the current version.

## Functionality

Ratings: a maximum of five stars, used to filter playlists. Preferred mode includes songs rated three stars and above. Unfamiliar mode includes songs rated three stars and below. Users can change ratings while listening, reflecting changes in preference. Three-star songs therefore qualify for both modes. Handling unrated songs is not specified.

Classification: provide a per-song editing screen where users can change the title and author/artist. Add reusable artist tags so an existing artist can be selected for another song and songs can be grouped. Users can upload an artist avatar and rename the artist.

Unknown-song identification: possible future options are AI-assisted lookup/classification and manual entry. Implement the manual-entry version first.
