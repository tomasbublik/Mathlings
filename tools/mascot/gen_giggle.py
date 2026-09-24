#!/usr/bin/env python3
"""Procedural 'giggle' for the Mathling mascot: three quick, bouncy chirps
falling slightly in pitch (hee-hee-hee), soft sine + a touch of 2nd/3rd
harmonic, 44.1 kHz mono 16-bit."""
import math, struct, sys, wave

SR = 44100
out = sys.argv[1]
samples = [0.0] * int(SR * 0.42)

def chirp(start, dur, f0, f1, amp):
    n = int(dur * SR)
    phase = 0.0
    for i in range(n):
        t = i / n
        # quick rise then fall: a little "hee" contour
        f = f0 + (f1 - f0) * math.sin(math.pi * t) + 25 * math.sin(2 * math.pi * 28 * i / SR)
        phase += 2 * math.pi * f / SR
        env = min(1.0, t / 0.08) * (1 - t) ** 1.6
        v = math.sin(phase) + 0.28 * math.sin(2 * phase) + 0.10 * math.sin(3 * phase)
        j = int(start * SR) + i
        if j < len(samples):
            samples[j] += amp * env * v

chirp(0.00, 0.10, 980, 1380, 0.42)
chirp(0.12, 0.10, 900, 1280, 0.38)
chirp(0.24, 0.14, 820, 1180, 0.34)

peak = max(abs(s) for s in samples) or 1.0
scale = 0.45 / peak
with wave.open(out, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))
print("wrote", out)
