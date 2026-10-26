"""Original, quiet stereo route-identification fixtures; never Dolby material."""
from pathlib import Path
import math
import struct
import wave
root = Path(__file__).resolve().parents[1] / 'apps/apple/Resources'
for name, active in [('Left', (1, 0)), ('Right', (0, 1)), ('Center', (1, 1))]:
    frames = bytearray()
    for i in range(88200):
        t = i / 44100
        envelope = min(1, t / .1, (2-t) / .2)
        value = int(32767 * .025 * envelope * sum(math.sin(2*math.pi*f*t) for f in (500, 1000, 2000)) / 3)
        frames.extend(struct.pack('<hh', value * active[0], value * active[1]))
    with wave.open(str(root / f'Orca-Check-{name}.wav'), 'wb') as out:
        out.setparams((2, 2, 44100, 0, 'NONE', 'not compressed'))
        out.writeframes(frames)
    samples = list(struct.iter_unpack('<hh', frames))
    assert all(s[1] == 0 for s in samples) if name == 'Left' else True
    assert all(s[0] == 0 for s in samples) if name == 'Right' else True
    assert max(abs(v) for s in samples for v in s) < 820
print('Generated and checked three original 2-second stereo fixtures')
