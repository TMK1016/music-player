"""Original synthetic soundcheck; no external recording or copyrighted source."""
import math
import struct
import wave
from pathlib import Path

output = Path(__file__).resolve().parents[1] / "apps/apple/Resources/Orca-Soundcheck.wav"
output.parent.mkdir(parents=True, exist_ok=True)
rate, duration = 44100, 18
notes = [220, 277.18, 329.63, 415.30, 369.99, 329.63, 246.94, 277.18]
with wave.open(str(output), "wb") as audio:
    audio.setparams((2, 2, rate, 0, "NONE", "not compressed"))
    chunk = bytearray()
    for frame in range(rate * duration):
        t = frame / rate
        phase = t % 0.75
        note = notes[int(t / 0.75) % len(notes)]
        envelope = min(1, phase / 0.025) * math.exp(-phase * 2.8)
        edge = min(1, t / 0.5, (duration - t) / 0.8)
        bass = 0.045 * math.sin(2 * math.pi * 55 * t)
        melody = envelope * (0.10 * math.sin(2 * math.pi * note * t) + 0.025 * math.sin(2 * math.pi * note * 2 * t))
        left = edge * (bass + melody)
        right = edge * (bass + melody * 0.88 + 0.012 * math.sin(2 * math.pi * 440 * t))
        chunk.extend(struct.pack("<hh", int(left * 32767), int(right * 32767)))
        if len(chunk) >= 65536:
            audio.writeframesraw(chunk)
            chunk.clear()
    audio.writeframesraw(chunk)
print(f"Generated {output.name}: {duration}s / stereo / 44.1kHz / original synthesis")
