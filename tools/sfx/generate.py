#!/usr/bin/env python3
"""Generates the game's synthesized sounds into data/audio/generated/.

Standard library only. Every sound uses a fixed seed, so running this again
writes the same files. Output: mono, 16-bit, 22050 Hz .wav. Loops are built to
join seamlessly: tones use whole cycles per loop, noise is filtered around the
loop until it settles. Run from the repo root: python3 tools/sfx/generate.py
"""

import json
import math
import os
import random
import struct
import sys
import wave

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "music"))
import key  # noqa: E402  (tools/music/key.py: the game's one key, Story 16.2)

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "data", "audio", "generated")
# Sounds tuned to the key (Story 16.2): name -> (scale degree, octave). Written
# with their frequencies to pitches.json, which tests/test_music_key.gd checks.
PITCHED = {
    "drone_hum": (1, 0),
    "lattice_drone": (1, -2),
    "lattice_tone": (5, 0),
    # Story 16.9: the countdown beeps on the fifth and launches on the tonic; the
    # gate blip is the tonic, played at each mantra note's ratio by JobCues.
    "job_countdown": (5, 2),
    "job_go": (1, 3),
    "job_gate": (1, 2),
}


def loop_len(freq, seconds):
    """Samples in about `seconds` that hold a whole number of cycles of freq,
    and that number, so a loop at freq joins seamlessly."""
    cycles = max(1, round(freq * seconds))
    return round(cycles * RATE / freq), cycles


def write_pitches():
    """pitches.json: each tuned sound's degree, octave and base pitch in Hz."""
    out = {name: {"degree": d, "octave": o, "hz": round(key.hz(d, o), 4)} for name, (d, o) in PITCHED.items()}
    with open(os.path.join(OUT, "pitches.json"), "w") as f:
        json.dump(out, f, indent=1, sort_keys=True)
        f.write("\n")


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


def muffled(samples):
    """Snow's hush (Story 14.7): a loop heard through falling snow, its highs
    gone. Four passes of a ~300 Hz low-pass around the loop, baked, since the
    web build has no live bus effects."""
    for _ in range(2):
        samples = lowpass_loop(samples, 0.08)
    return samples


def drone_hum():
    """About a second of four motors' blade-pass buzz, slightly apart so they
    beat, the first on the key's tonic (Story 16.2). Played pitched up and down
    by thrust (DroneSound), so at pitch 1 it sits on the tonic."""
    rng = random.Random(1402)
    n, c = loop_len(key.hz(*PITCHED["drone_hum"]), 1.0)
    motors = [(c, 0.0), (c + 1, 1.3), (c - 1, 2.1), (c + 2, 0.7)]  # whole cycles per loop
    noise = lowpass_loop([rng.uniform(-1, 1) for _ in range(n)], 0.25)
    out = []
    for i in range(n):
        s = 0.0
        for cycles, ph in motors:
            # Blade pass plus a few harmonics: a buzzy, slightly nasal whine.
            for h, amp in ((1, 1.0), (2, 0.55), (3, 0.3), (4, 0.18), (6, 0.08)):
                s += amp * math.sin(2 * math.pi * cycles * h * i / n + ph * h)
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


def tone_seq(notes, shape="sine", decay=18.0, gap=0.0):
    """Short beeps one after another: (freq Hz, length s) each, with a quick
    attack and exponential decay. `shape` "square" is a softened square."""
    out = []
    for f, length in notes:
        n = int(RATE * length)
        for i in range(n):
            t = i / RATE
            s = math.sin(2 * math.pi * f * t)
            if shape == "square":
                s = math.tanh(4 * s) + 0.3 * math.sin(2 * math.pi * f * 2 * t)
            env = min(1.0, t / 0.004) * math.exp(-t * decay)
            out.append(s * env)
        out.extend([0.0] * int(RATE * gap))
    return out


def flight_recovered():
    """A rising three-note chime: back upright, carry on."""
    return tone_seq([(660, 0.09), (880, 0.09), (1320, 0.28)], decay=10.0)


def flight_low_battery():
    """Two falling square beeps: the battery bar just turned red."""
    return tone_seq([(988, 0.16), (740, 0.24)], shape="square", decay=8.0, gap=0.05)


def flight_guard():
    """A quick sharp double blip: the collision guard grabbed the sticks."""
    return tone_seq([(1760, 0.06), (1760, 0.12)], shape="square", decay=30.0, gap=0.03)


def flight_brake():
    """A soft falling swoop: the brake is pulling the drone to a stop."""
    rng = random.Random(1431)
    n = int(RATE * 0.35)
    y = 0.0
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = 520 * math.exp(-t * 4.0)
        phase += 2 * math.pi * f / RATE
        y += 0.1 * (rng.uniform(-1, 1) - y)
        env = min(1.0, t / 0.01) * math.exp(-t * 9.0)
        out.append((math.sin(phase) * 0.8 + y * 0.6) * env)
    return out


def camera_view():
    """A small shutter click for a camera view change."""
    rng = random.Random(1432)
    n = int(RATE * 0.08)
    out = []
    for i in range(n):
        t = i / RATE
        click = math.sin(2 * math.pi * 2400 * t) * math.exp(-t * 120)
        tick = rng.uniform(-1, 1) * math.exp(-t * 200)
        out.append(click * 0.7 + tick * 0.5)
    return out


def job_briefing():
    """A soft two-note call: the job is on the board, waiting for launch."""
    return tone_seq([(523, 0.14), (784, 0.36)], decay=7.0)


def job_countdown():
    """One countdown beep, played on each whole second of the countdown: the
    key's fifth (Story 16.9)."""
    return tone_seq([(key.hz(*PITCHED["job_countdown"]), 0.16)], shape="square", decay=14.0)


def job_go():
    """The launch beep: the tonic above the countdown's fifth, held longer."""
    return tone_seq([(key.hz(*PITCHED["job_go"]), 0.45)], shape="square", decay=5.0)


def job_gate():
    """A bright blip for a gate passed, on the tonic (Story 16.9): JobCues plays
    it at each mantra note's pitch in turn, so a clean run plays the hook. A
    short scoop up into the note, then held on it."""
    rng = random.Random(1440)
    f0 = key.hz(*PITCHED["job_gate"])
    n = int(RATE * 0.18)
    phase = 0.0
    out = []
    for i in range(n):
        t = i / RATE
        f = f0 * (0.94 + 0.06 * min(1.0, t / 0.012))
        phase += 2 * math.pi * f / RATE
        env = min(1.0, t / 0.003) * math.exp(-t * 16.0)
        out.append((math.sin(phase) + 0.25 * math.sin(2 * phase) + 0.05 * rng.uniform(-1, 1)) * env)
    return out


def job_hold_tick():
    """A soft wooden tick for each quarter of a hold."""
    return tone_seq([(1200, 0.07)], decay=45.0)


def job_hold_done():
    """Two quick rising notes: the hold is done."""
    return tone_seq([(988, 0.08), (1319, 0.22)], decay=12.0)


def job_complete():
    """A major arpeggio and a held top note: job complete."""
    return tone_seq([(523, 0.11), (659, 0.11), (784, 0.11), (1047, 0.6)], decay=5.0)


def job_fail():
    """A falling minor line ending in a low buzz: job failed."""
    return tone_seq([(466, 0.18), (392, 0.18), (311, 0.6)], shape="square", decay=4.5)


def job_payout():
    """The pay counting up: coin ticks that speed up, then a closing ding."""
    rng = random.Random(1441)
    out = []
    gap = 0.11
    for k in range(12):
        f = 2000 + rng.uniform(-150, 150) + 40 * k
        n = int(RATE * gap)
        for i in range(n):
            t = i / RATE
            out.append(math.sin(2 * math.pi * f * t) * math.exp(-t * 70) * 0.6)
        gap = max(0.035, gap * 0.85)
    return out + tone_seq([(2637, 0.4)], decay=8.0)


def hazard_warning():
    """A two-tone warble: crew ahead, a strike is coming."""
    out = []
    for k in range(4):
        f = 880 if k % 2 == 0 else 660
        n = int(RATE * 0.13)
        for i in range(n):
            t = i / RATE
            s = math.tanh(3 * math.sin(2 * math.pi * f * t))
            env = min(1.0, t / 0.005) * min(1.0, (n - i) / (RATE * 0.01))
            out.append(s * env)
    return out


def hazard_strike():
    """A heavy hit: a low thud under a harsh burst of noise."""
    rng = random.Random(1442)
    n = int(RATE * 0.7)
    y = 0.0
    out = []
    for i in range(n):
        t = i / RATE
        y += 0.2 * (rng.uniform(-1, 1) - y)
        thud = math.sin(2 * math.pi * (55 + 40 * math.exp(-t * 12)) * t) * math.exp(-t * 6)
        buzz = math.tanh(3 * math.sin(2 * math.pi * 110 * t)) * math.exp(-t * 9)
        out.append(thud * 1.0 + buzz * 0.35 + y * 1.2 * math.exp(-t * 10))
    return out


def ui_click():
    """A short dry tick: a button pressed."""
    rng = random.Random(1450)
    n = int(RATE * 0.05)
    out = []
    for i in range(n):
        t = i / RATE
        tone = math.sin(2 * math.pi * 1800 * t) * math.exp(-t * 160)
        tick = rng.uniform(-1, 1) * math.exp(-t * 400)
        out.append(tone * 0.6 + tick * 0.3)
    return out


def ui_focus():
    """A faint high blip: focus moved to another button."""
    return [s * 0.5 for s in tone_seq([(2640, 0.04)], decay=90.0)]


def ui_confirm():
    """Two quick rising notes: a dialog accepted."""
    return tone_seq([(880, 0.06), (1320, 0.16)], decay=22.0)


def coin_chime():
    """The cabinet's PRESS START (Story 17.6): a coin dropping in, two bright
    metallic clinks of inharmonic partials, then a soft rising three-note bell."""
    out = []
    for f0, length in ((3100, 0.07), (3500, 0.12)):
        n = int(RATE * length)
        for i in range(n):
            t = i / RATE
            s = sum(math.sin(2 * math.pi * f0 * r * t) / (k + 1) for k, r in enumerate((1.0, 1.47, 2.09, 2.76)))
            out.append(0.45 * s * min(1.0, t / 0.002) * math.exp(-t * 45))
    bell = tone_seq([(784, 0.08), (988, 0.08), (1568, 0.5)], decay=7.0)
    return out + [s * 0.7 for s in bell]


def city_hum():
    """Three seconds of a city heard from above: a low traffic rumble that
    swells, mains hum from the towers, and a faint airy hiss."""
    rng = random.Random(1460)
    n = RATE * 3
    rumble = lowpass_loop(lowpass_loop([rng.uniform(-1, 1) for _ in range(n)], 0.02), 0.05)
    hiss = lowpass_loop([rng.uniform(-1, 1) for _ in range(n)], 0.3)
    out = []
    for i in range(n):
        t = i / RATE
        swell = 0.75 + 0.25 * math.sin(2 * math.pi * t / 3.0)  # one swell per loop
        mains = math.sin(2 * math.pi * 60 * t) + 0.4 * math.sin(2 * math.pi * 120 * t)
        out.append(rumble[i] * 3.0 * swell + mains * 0.05 + hiss[i] * 0.08)
    return out


def desert_wind():
    """Three seconds of open-desert wind: soft low noise with gusts that rise
    and fall twice per loop, and a faint whistle riding the gusts."""
    rng = random.Random(1461)
    n = RATE * 3
    body = lowpass_loop([rng.uniform(-1, 1) for _ in range(n)], 0.04)
    air = lowpass_loop([rng.uniform(-1, 1) for _ in range(n)], 0.15)
    out = []
    for i in range(n):
        t = i / RATE
        gust = 0.6 + 0.4 * math.sin(2 * math.pi * t * 2 / 3.0) ** 2
        whistle = math.sin(2 * math.pi * 620 * t + 3 * math.sin(2 * math.pi * t / 3.0))
        out.append(body[i] * 2.0 * gust + air[i] * 0.4 * gust * gust + whistle * 0.015 * gust)
    return out


def room_tone():
    """Two seconds of the job board's room: ventilation hush and a faint
    fluorescent buzz."""
    rng = random.Random(1462)
    n = RATE * 2
    vent = lowpass_loop([rng.uniform(-1, 1) for _ in range(n)], 0.06)
    out = []
    for i in range(n):
        t = i / RATE
        buzz = math.sin(2 * math.pi * 120 * t) + 0.3 * math.sin(2 * math.pi * 240 * t)
        out.append(vent[i] * 1.5 + buzz * 0.04)
    return out


def debris_impact(seed):
    """A chunk of masonry landing: a dull thud and a gritty crumble."""
    rng = random.Random(seed)
    n = int(RATE * 0.45)
    thud_f = rng.uniform(50, 70)
    y = 0.0
    out = []
    for i in range(n):
        t = i / RATE
        y += 0.5 * (rng.uniform(-1, 1) - y)
        thud = math.sin(2 * math.pi * thud_f * t) * math.exp(-t * 14)
        grit = y * math.exp(-t * 9) * (0.6 + 0.4 * (rng.random() < 0.08))
        out.append(thud * 1.0 + grit * 0.7)
    return out


def crew_chirp():
    """A two-blip chirp under a crew bark, in place of a voice. One sample,
    pitched per speaker from Character.chirp_pitch."""
    out = []
    for f0, f1, length in ((700, 980, 0.06), (900, 760, 0.08)):
        n = int(RATE * length)
        phase = 0.0
        for i in range(n):
            t = i / RATE
            phase += 2 * math.pi * (f0 + (f1 - f0) * t / length) / RATE
            s = math.tanh(2 * math.sin(phase)) + 0.3 * math.sin(2 * phase)
            env = min(1.0, t / 0.004) * min(1.0, (n - i) / (RATE * 0.01))
            out.append(s * env)
        out.extend([0.0] * int(RATE * 0.02))
    return out


def radio_static():
    """A short burst of radio static as a crew line opens (Story 17.7): band-
    limited hiss with a few crackles, cut off sharply like a keyed mic."""
    rng = random.Random(1770)
    n = int(RATE * 0.16)
    lo = hi = 0.0
    out = []
    for i in range(n):
        t = i / RATE
        x = rng.uniform(-1, 1)
        hi += 0.6 * (x - hi)
        lo += 0.08 * (hi - lo)
        s = hi - lo
        if rng.random() < 0.01:
            s += rng.choice((-1, 1)) * 2.5
        env = min(1.0, t / 0.003) * min(1.0, (n - i) / (RATE * 0.02))
        out.append(s * env)
    return out


def lattice_tone():
    """The chorus under each of its lines: a flat cluster of close sine tones,
    many voices on the key's fifth with the tonic and fifth above, swelling in
    and fading out."""
    n = int(RATE * 1.2)
    f = key.hz(*PITCHED["lattice_tone"])
    t8 = key.hz(1, 1)
    voices = [(f, 0.0), (f + 1.5, 1.1), (f - 1.3, 2.3), (t8, 0.4), (t8 + 1.2, 1.9), (2 * f + 0.6, 2.8)]
    out = []
    for i in range(n):
        t = i / RATE
        s = sum(math.sin(2 * math.pi * f * t + ph) for f, ph in voices)
        env = min(1.0, t / 0.15) * min(1.0, (n - i) / (RATE * 0.4))
        out.append(s * env)
    return out


def lattice_drone():
    """About two seconds of the Lattice's low drone: a deep hum on the tonic two
    octaves down, with slow beating partials and a faint grain of noise. Whole
    cycles, so it loops."""
    rng = random.Random(1480)
    n, c = loop_len(key.hz(*PITCHED["lattice_drone"]), 2.0)
    grain = lowpass_loop([rng.uniform(-1, 1) for _ in range(n)], 0.03)
    out = []
    for i in range(n):
        x = 2 * math.pi * i / n
        s = math.sin(c * x) + 0.7 * math.sin((c + 1) * x + 1.0)
        s += 0.35 * math.sin(2 * c * x) + 0.2 * math.sin((3 * c + 1) * x + 0.5)
        out.append(s + grain[i] * 1.5)
    return out


def lattice_power_down():
    """The Lattice letting go: its drone sliding down and fading to nothing."""
    n = int(RATE * 3.0)
    phase = 0.0
    out = []
    for i in range(n):
        t = i / RATE
        f = 82 * math.exp(-t * 0.7)
        phase += 2 * math.pi * f / RATE
        env = min(1.0, t / 0.05) * (1.0 - t / 3.0) ** 2
        out.append((math.sin(phase) + 0.5 * math.sin(2 * phase) + 0.25 * math.sin(3 * phase)) * env)
    return out


def bed(seed, chord, hiss):
    """Three seconds of a cutscene's bed: a soft held chord (whole cycles per
    loop, so it loops) over a hush of air. Not music: no melody, no beat."""
    rng = random.Random(seed)
    n = RATE * 3
    air = lowpass_loop([rng.uniform(-1, 1) for _ in range(n)], 0.05)
    out = []
    for i in range(n):
        t = i / RATE
        swell = 0.8 + 0.2 * math.sin(2 * math.pi * t / 3.0)
        s = sum(math.sin(2 * math.pi * f * t + k) for k, f in enumerate(chord))
        out.append(s * 0.3 * swell + air[i] * hiss)
    return out


def main():
    write("drone_hum.wav", drone_hum(), loop=True)
    write("drone_wash.wav", drone_wash(), loop=True)
    for k in range(3):
        write("drone_impact_%d.wav" % (k + 1), drone_impact(1410 + k))
    write("flight_recovered.wav", flight_recovered())
    write("flight_low_battery.wav", flight_low_battery())
    write("flight_guard.wav", flight_guard())
    write("flight_brake.wav", flight_brake())
    write("camera_view.wav", camera_view())
    for name in ("job_briefing", "job_countdown", "job_go", "job_gate", "job_hold_tick",
                 "job_hold_done", "job_complete", "job_fail", "job_payout",
                 "hazard_warning", "hazard_strike", "ui_click", "ui_focus", "ui_confirm"):
        write(name + ".wav", globals()[name]())
    for name in ("city_hum", "desert_wind", "room_tone"):
        write(name + ".wav", globals()[name](), loop=True)
    for name in ("city_hum", "desert_wind"):
        write(name + "_muffled.wav", muffled(globals()[name]()), loop=True)
    for k in range(3):
        write("debris_impact_%d.wav" % (k + 1), debris_impact(1465 + k))
    for name in ("crew_chirp", "radio_static", "lattice_tone", "lattice_power_down"):
        write(name + ".wav", globals()[name]())
    write("lattice_drone.wav", lattice_drone(), loop=True)
    write("coin_chime.wav", coin_chime())
    # Frequencies in whole Hz (whole cycles per 3 s loop).
    write("bed_intro.wav", bed(1490, (110, 165, 220, 277), 2.0), loop=True)
    write("bed_recruited.wav", bed(1491, (98, 147, 196, 247), 1.2), loop=True)
    write_pitches()


if __name__ == "__main__":
    main()
