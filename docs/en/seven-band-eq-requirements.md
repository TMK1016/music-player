# Seven-band EQ and mode selection

2026-10-24 — Full English translation of the user's request:

“Please reduce the number of adjustable equalizer bars from ten to seven. The seven frequency bands must be selected professionally and reasonably, and all seven bars must fit completely within the screen without horizontal scrolling. Arrange the screen from top to bottom as follows: the equalizer on/off control, the current distribution, the seven adjustable bars, and mode selection. Mode selection should be one horizontally scrollable row; when the user swipes horizontally, expand the full selection area so the user can choose a mode, retaining the current full-block presentation. Add a custom-mode button at the upper-right of the mode-selection area. After the user creates a new custom mode, show it in the mode list. Users must be able to add or delete modes themselves.”

Implementation choices: 50/125/315/800/2000/5000/12500 Hz, approximately logarithmic spacing, 4/3-octave peaking-filter bandwidth. Keep the existing 20-custom-mode limit and song bindings. Convert legacy ten-band settings approximately in log-frequency space and preserve a raw preferences backup before first migration. User-created modes can be deleted; builtin modes can be removed from the list and restored. Do not reintroduce seat-distance controls or implement another loudness strategy in this change.
