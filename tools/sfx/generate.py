#!/usr/bin/env python3
"""Generates the game's synthesized sounds into data/audio/generated/.

Standard library only. Every sound uses a fixed seed, so running this again
writes the same files. Output: mono, 16-bit, 22050 Hz .wav. Loops are built to
join seamlessly: tones use whole cycles per loop, noise is filtered around the
loop until it settles. Run from the repo root: python3 tools/sfx/generate.py
"""

import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "data", "audio", "generated")


def write(name, samples, loop=False):
    """Writes a .wav. A loop gets a RIFF "smpl" chunk over the whole file, which
    Godot's importer reads as a forward loop (.import files are not checked in)."""
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.9 / peak
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * scale * 32767)) for s in samples))
    if loop:
        smpl = struct.pack("<9I", 0, 0, 1000000000 // RATE, 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(samples), 0, 0)
        with open(path, "r+b") as f:
            f.seek(0, 2)
            f.write(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
            size = f.tell()
            f.seek(4)
            f.write(struct.pack("<I", size - 8))


def lowpass_loop(samples, a):
    """One-pole low-pass run twice around a loop, so its end meets its start."""
    y = 0.0
    out = list(samples)
    for _ in range(2):
        for i, x in enumerate(samples):
            y += a * (x - y)
            out[i] = y
    return out


def drone_hum():
    """One second of four motors' blade-pass buzz, slightly apart so they beat.
    Played pitched up and down by thrust (DroneSound)."""
    rng = random.Random(1402)
    n = RATE
    motors = [(190, 0.0), (193, 1.3), (187, 2.1), (196, 0.7)]  # Hz: whole cycles per second
    noise = lowpass_loop([rng.uniform(-1, 1) for _ in range(n)], 0.25)
    out = []
    for i in range(n):
        t = i / RATE
        s = 0.0
        for f, ph in motors:
            # Blade pass plus a few harmonics: a buzzy, slightly nasal whine.
            for h, amp in ((1, 1.0), (2, 0.55), (3, 0.3), (4, 0.18), (6, 0.08)):
                s += amp * math.sin(2 * math.pi * f * h * t + ph * h)
        out.append(s * 0.25 + noise[i] * 0.6)
    return out


def drone_wash():
    """Two seconds of rushing air: low-passed noise with a slow swell."""
    rng = random.Random(1403)
    n = RATE * 2
    noise = lowpass_loop([rng.uniform(-1, 1) for _ in range(n)], 0.08)
    return [noise[i] * (0.8 + 0.2 * math.sin(2 * math.pi * 1.0 * i / RATE)) for i in range(n)]


def drone_impact(seed):
    """A short knock: a low thump under a plastic clack, fast decay."""
    rng = random.Random(seed)
    n = int(RATE * 0.3)
    thump_f = rng.uniform(70, 95)
    clack_f = rng.uniform(900, 1400)
    noise = [rng.uniform(-1, 1) for _ in range(n)]
    y = 0.0
    out = []
    for i in range(n):
        t = i / RATE
        y += 0.35 * (noise[i] - y)
        thump = math.sin(2 * math.pi * thump_f * t) * math.exp(-t * 22)
        clack = math.sin(2 * math.pi * clack_f * t) * math.exp(-t * 60)
        crunch = y * math.exp(-t * 35)
        out.append(thump * 1.0 + clack * 0.35 + crunch * 0.6)
    return out


def main():
    write("drone_hum.wav", drone_hum(), loop=True)
    write("drone_wash.wav", drone_wash(), loop=True)
    for k in range(3):
        write("drone_impact_%d.wav" % (k + 1), drone_impact(1410 + k))


if __name__ == "__main__":
    main()
