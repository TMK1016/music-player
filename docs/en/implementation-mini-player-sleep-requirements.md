# Implementation, song cards, persistent mini player, source selection and sleep limits

Start implementation of the previously specified functionality and UI/UX. Make every song its own separate cell, with a 50% transparent effect. When a song is playing, retain a compact player at the bottom while the user visits other pages, like Spotify or similar music players. The supplied image reference is an Obsidian embed string; no actual image content was available in this request.

Add a choice of audio source, allowing local playback or other sources such as Bluetooth. Add a sleep/listening limit based on either listening duration or a number of songs.

Engineering interpretation: 50% opacity applies to each cell's background, keeping text and controls opaque. Local files are the implemented content source; Bluetooth speakers/headphones are output routes chosen through the system picker, not incoming music sources. Timer minutes are a wall-clock countdown including pauses; song limits count natural completions, include the current song, count repeat completions, and do not decrement for manual skips. Source direction was asked for clarification; external Bluetooth reception is not implemented.


## Superseding request: remove vehicle settings

After reevaluation, remove the vehicle settings feature entirely and clear its related data from the app. Implementation removes UI, navigation, vehicle models, identification tests and bundled tones; startup scrubs vehicle fields from active preferences and the migration snapshot while preserving music and sound settings. Historical project documents and releases remain historical records. Cleanup on the phone requires installing and launching the updated app.
