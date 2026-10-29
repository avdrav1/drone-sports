#!/usr/bin/env python3
"""Profiles the song (Story 21.2): its musical fingerprint as data the music
generator reads, written to tools/music/song_profile.json.

Standard library only, plus ffmpeg to decode tools/music/source/song.flac to
raw PCM. The profile holds the tempo and beat grid, the tuning, the key (tonic
name, tonic in Hz in octave 3, mode), the local key of each stretch, a chord
per bar, the drum pattern as onset strength on the 16 steps of a bar, and a
spectral envelope per instrument role (bass, pads, lead, drums), with the
bass's and lead's harmonic profiles.

Hand corrections live in the JSON's "hand" block, which a run keeps: where it
names the bpm, tonic or mode, that value wins over the measured one (which is
still written under "measured"). Everything else is measured and rounded, so
running this again writes the same file byte for byte. Run from the repo root:
python3 tools/music/analyze.py
With --check it analyses again and exits nonzero unless the result matches the
committed JSON; without the FLAC it says so and passes.
"""

import array
import cmath
import json
import math
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SONG = os.path.join(HERE, "source", "song.flac")
PROFILE = os.path.join(HERE, "song_profile.json")
RATE = 22050
# One FFT frame per beat (0.375 s at 160 bpm): fine enough in frequency for
# chroma down to C2.
N = 8192
# Onset envelopes: one energy value per HOP samples (11.6 ms).
HOP = 256
BEATS_PER_BAR = 4
STEPS = 16
NAMES = ("C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B")
# Krumhansl-Kessler key profiles, from the tonic up.
MAJOR = (6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88)
MINOR = (6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17)
# Drum voices: the ffmpeg filter that isolates each before its onsets are taken.
DRUMS = {
    "kick": "lowpass=f=120,lowpass=f=120",
    "snare": "highpass=f=1500,lowpass=f=5000",
    "hat": "highpass=f=8000,highpass=f=8000",
}
# Third-octave band centres the role envelopes are given on.
BANDS = [round(1000 * 2 ** (k / 3)) for k in range(-15, 10)]
# Each role's range in Hz.
ROLES = {"bass": (35, 400), "pads": (150, 8000), "lead": (250, 6000), "drums": (35, 8000)}
HARMONICS = 8
# Envelopes stop at this many dB below their loudest band.
FLOOR_DB = -60.0
# Local keys are measured over this many bars at a time.
KEY_WINDOW = 16


def decode(af=None):
    """The song as mono floats at RATE, through ffmpeg filter `af` if given."""
    cmd = ["ffmpeg", "-loglevel", "error", "-i", SONG, "-map_metadata", "-1", "-ac", "1", "-ar", str(RATE)]
    if af:
        cmd += ["-af", af]
    pcm = subprocess.run(cmd + ["-f", "s16le", "-"], capture_output=True, check=True).stdout
    return [v / 32768.0 for v in array.array("h", pcm)]


_fft_plans = {}


def fft_mag(x):
    """Magnitudes of the first half of the FFT of `x` (length a power of 2)."""
    n = len(x)
    if n not in _fft_plans:
        bits = n.bit_length() - 1
        rev = [int(format(i, "0%db" % bits)[::-1], 2) for i in range(n)]
        tw = [cmath.exp(-2j * math.pi * k / n) for k in range(n // 2)]
        _fft_plans[n] = (rev, tw)
    rev, tw = _fft_plans[n]
    a = [complex(x[i]) for i in rev]
    size = 2
    while size <= n:
        half = size // 2
        step = n // size
        w = tw[::step]
        for start in range(0, n, size):
            for k in range(half):
                u = a[start + k]
                v = a[start + k + half] * w[k]
                a[start + k] = u + v
                a[start + k + half] = u - v
        size *= 2
    return [abs(v) for v in a[:n // 2]]


def hann(n):
    return [0.5 - 0.5 * math.cos(2 * math.pi * i / n) for i in range(n)]


def onset_flux(x):
    """Positive change in log energy per HOP block: how hard something starts."""
    env = []
    for i in range(0, len(x) - HOP, HOP):
        e = sum(v * v for v in x[i:i + HOP])
        env.append(math.log(1e-7 + e))
    return [0.0] + [max(0.0, env[i] - env[i - 1]) for i in range(1, len(env))]


def at(flux, t):
    """Onset strength at time t: the strongest block within one block of it."""
    i = int(round(t * RATE / HOP))
    return max(flux[max(0, i - 1):i + 2] or [0.0])


def tempo(flux):
    """(bpm, offset seconds): the beat grid the onsets line up with best. A coarse
    search by autocorrelation over 70-200 bpm, then a fine one by how much onset
    lands on the grid across the whole song."""
    fps = RATE / HOP
    m = sum(flux) / len(flux)
    o = [v - m for v in flux]

    def ac(lag):
        i0 = int(lag)
        f = lag - i0
        return sum(o[i] * (o[i + i0] * (1 - f) + o[i + i0 + 1] * f) for i in range(0, len(o) - i0 - 2, 2))

    coarse = []
    for b2 in range(140, 401):
        bpm = b2 / 2
        lag = fps * 60 / bpm
        # A beat lines up with the next one and with the bar.
        coarse.append((ac(lag) + 0.5 * ac(lag * 4), bpm))
    _, bpm = max(coarse)

    def grid(bpm, offset):
        beat = 60.0 / bpm
        k, s, t = 0, 0.0, offset
        end = len(flux) * HOP / RATE - 0.05
        while t < end:
            s += at(flux, t)
            k += 1
            t = offset + k * beat
        return s / max(1, k)

    best = None
    for d in range(-50, 51):
        b = round(bpm + d * 0.01, 2)
        beat = 60.0 / b
        for k in range(16):
            score = grid(b, beat * k / 16)
            if best is None or score > best[0] + 1e-12:
                best = (score, b, beat * k / 16)
    return best[1], best[2]


def tuning(frames):
    """How far the song sits from A440, in whole cents."""
    best = None
    for c in range(-50, 51):
        s = 0.0
        for mag in frames[::8]:
            for m in range(48, 90):
                b = 440 * 2 ** ((m - 69 + c / 100) / 12) * N / RATE
                i = int(b)
                f = b - i
                s += mag[i] * (1 - f) + mag[i + 1] * f
        if best is None or s > best[0]:
            best = (s, c)
    return best[1]


def pitch_hz(midi, cents):
    return 440.0 * 2 ** ((midi - 69 + cents / 100.0) / 12)


def magnitude(mag, hz):
    b = hz * N / RATE
    i = int(b)
    f = b - i
    return mag[i] * (1 - f) + mag[i + 1] * f


def chroma(mag, lo, hi, cents):
    """Energy per pitch class over MIDI notes lo..hi-1."""
    c = [0.0] * 12
    for m in range(lo, hi):
        c[m % 12] += magnitude(mag, pitch_hz(m, cents))
    return c


def normed(v):
    s = sum(v) or 1.0
    return [x / s for x in v]


def corr(a, b):
    ma, mb = sum(a) / len(a), sum(b) / len(b)
    num = sum((x - ma) * (y - mb) for x, y in zip(a, b))
    den = math.sqrt(sum((x - ma) ** 2 for x in a) * sum((y - mb) ** 2 for y in b))
    return num / den if den else 0.0


def keys(c):
    """Every key's fit to chroma `c`, best first: (score, tonic pc, mode)."""
    out = []
    for r in range(12):
        for prof, mode in ((MAJOR, "major"), (MINOR, "minor")):
            out.append((corr(c, [prof[(k - r) % 12] for k in range(12)]), r, mode))
    out.sort(key=lambda e: (-e[0], e[1], e[2]))
    return out


def chord(mid, bass):
    """The triad that best fits a bar: its notes in the mid chroma, its root in
    the bass. "N" when the bar is near silent."""
    m, b = normed(mid), normed(bass)
    best = None
    for r in range(12):
        for q, third in (("", 4), ("m", 3)):
            notes = (r, (r + third) % 12, (r + 7) % 12)
            s = sum(m[k] for k in notes) - 0.33 * sum(m[k] for k in range(12) if k not in notes) + 0.5 * b[r]
            if best is None or s > best[0] + 1e-12:
                best = (s, NAMES[r] + q)
    return best[1]


def percentile(v, p):
    v = sorted(v)
    return v[min(len(v) - 1, int(p * len(v)))]


def bands_db(mag):
    """Energy per third-octave band, in dB, of a spectrum of len(mag) bins."""
    n = 2 * len(mag)
    out = []
    for c in BANDS:
        lo, hi = c * 2 ** (-1 / 6) * n / RATE, c * 2 ** (1 / 6) * n / RATE
        e = sum(mag[i] ** 2 for i in range(int(lo), max(int(lo) + 1, int(hi))))
        out.append(10 * math.log10(1e-12 + e))
    return out


def envelope(db, role):
    """[[band Hz, dB]] over the role's range, its loudest band at 0 dB."""
    lo, hi = ROLES[role]
    pairs = [(c, v) for c, v in zip(BANDS, db) if lo <= c <= hi]
    top = max(v for _, v in pairs)
    return [[c, round(max(v - top, FLOOR_DB), 1)] for c, v in pairs]


def harmonics(frames, lo, hi, cents):
    """The tone of the strongest pitched voice between MIDI lo and hi: in each
    frame the note with the most energy over its first four harmonics, then the
    median level of harmonics 1..HARMONICS relative to the loudest, in dB."""
    per = [[] for _ in range(HARMONICS)]
    for mag in frames:
        best = None
        for m in range(lo, hi):
            f = pitch_hz(m, cents)
            s = sum(magnitude(mag, f * h) for h in range(1, 5))
            if best is None or s > best[0]:
                best = (s, f)
        f = best[1]
        amps = [magnitude(mag, f * h) if f * h < RATE / 2 - 50 else 0.0 for h in range(1, HARMONICS + 1)]
        top = max(amps) or 1e-12
        for h, a in enumerate(amps):
            per[h].append(20 * math.log10(max(a, 1e-9) / top))
    return [round(percentile(v, 0.5), 1) for v in per]


def analyse(hand):
    x = decode()
    seconds = len(x) / RATE
    rms = math.sqrt(sum(v * v for v in x) / len(x))
    flux = {name: onset_flux(decode(af)) for name, af in sorted(DRUMS.items())}
    whole = onset_flux(x)
    bpm, offset = tempo(whole)
    beat = 60.0 / bpm
    beats = [offset + k * beat for k in range(int((seconds - offset) / beat))]

    # One spectrum per beat.
    w = hann(N)
    frames = []
    for t in beats:
        i = int(round(t * RATE))
        seg = x[i:i + N]
        seg += [0.0] * (N - len(seg))
        frames.append(fft_mag([s * k for s, k in zip(seg, w)]))
    cents = tuning(frames)
    mid = [normed(chroma(f, 48, 84, cents)) for f in frames]
    low = [chroma(f, 36, 53, cents) for f in frames]
    # The downbeat: of the four beats, the one the harmony changes on most.
    change = [0.0] + [sum(abs(a - b) for a, b in zip(mid[k], mid[k - 1])) for k in range(1, len(mid))]
    phase = max(range(BEATS_PER_BAR), key=lambda p: (sum(change[p::BEATS_PER_BAR]), -p))
    bars = (len(beats) - phase) // BEATS_PER_BAR
    keep = slice(phase, phase + bars * BEATS_PER_BAR)
    beats, frames, mid, low = beats[keep], frames[keep], mid[keep], low[keep]
    bar0 = beats[0]
    loud = [sum(f) for f in frames]
    quiet = percentile(loud, 0.5) * 0.05

    # The key over the whole song, and over each stretch of KEY_WINDOW bars.
    total = normed([sum(c[k] for c in mid) for k in range(12)])
    ranked = keys(total)
    local = []
    for b in range(0, bars, KEY_WINDOW):
        cs = mid[b * BEATS_PER_BAR:(b + KEY_WINDOW) * BEATS_PER_BAR]
        _, r, md = keys(normed([sum(c[k] for c in cs) for k in range(12)]))[0]
        name = NAMES[r] + ("" if md == "major" else "m")
        if local and local[-1]["key"] == name:
            local[-1]["bars"] += min(KEY_WINDOW, bars - b)
        else:
            local.append({"bar": b, "bars": min(KEY_WINDOW, bars - b), "key": name})
    # The song moves between keys; its home key is the one it spends the most
    # bars in (the whole-song chroma, in key_scores, splits between them).
    held = {}
    for e in local:
        held[e["key"]] = held.get(e["key"], 0) + e["bars"]
    home = max(sorted(held), key=lambda k: held[k])
    pc, mode = NAMES.index(home.rstrip("m")), "minor" if home.endswith("m") else "major"

    chords = []
    for b in range(bars):
        sl = slice(b * BEATS_PER_BAR, (b + 1) * BEATS_PER_BAR)
        if sum(loud[sl]) / BEATS_PER_BAR < quiet:
            chords.append("N")
            continue
        chords.append(chord([sum(c[k] for c in mid[sl]) for k in range(12)],
                            [sum(c[k] for c in low[sl]) for k in range(12)]))

    # The groove: each drum voice's onset strength on the 16 steps of a bar,
    # averaged over every bar, quietest step 0.0 and loudest 1.0. Swing is where the offbeat
    # eighth falls within the beat (0.5 is straight).
    step = beat * BEATS_PER_BAR / STEPS
    drums = {}
    for name, fl in sorted(flux.items()):
        pat = [sum(at(fl, bar0 + b * BEATS_PER_BAR * beat + s * step) for b in range(bars)) / bars
               for s in range(STEPS)]
        lo, top = min(pat), max(pat)
        pat = [round((v - lo) / ((top - lo) or 1.0), 2) for v in pat]
        drums[name] = {"steps": pat, "onsets": [s for s, v in enumerate(pat) if v >= 0.6]}
    subs = 24
    hist = [sum(at(whole, t + beat * (k / subs)) for t in beats) for k in range(subs)]
    swing = max(range(subs // 3, subs * 5 // 6), key=lambda k: (hist[k], -k)) / subs

    # The instrument roles' tones.
    db = [bands_db(f) for f in frames if sum(f) >= quiet]
    med = [percentile([d[k] for d in db], 0.5) for k in range(len(BANDS))]
    p90 = [percentile([d[k] for d in db], 0.9) for k in range(len(BANDS))]
    lead = [p - m for p, m in zip(p90, med)]
    # Drums: what the spectrum gains over the half-beat before each strong onset.
    w2 = hann(1024)
    hits = []
    for name, d in sorted(drums.items()):
        for b in range(0, bars, 4):
            for s in d["onsets"]:
                hits.append(bar0 + b * BEATS_PER_BAR * beat + s * step)
    gain = [0.0] * len(BANDS)
    for t in sorted(hits):
        i, j = int(round(t * RATE)), int(round((t - beat / 2) * RATE))
        if j < 0 or i + 1024 > len(x):
            continue
        on = fft_mag([x[i + k] * w2[k] for k in range(1024)])
        off = fft_mag([x[j + k] * w2[k] for k in range(1024)])
        for k, (a, b) in enumerate(zip(bands_db(on), bands_db(off))):
            gain[k] += 10 ** (a / 10) - 10 ** (b / 10)
    drum_db = [10 * math.log10(max(g / max(1, len(hits)), 1e-12)) for g in gain]
    loudest = sorted(range(len(frames)), key=lambda k: (-loud[k], k))[:len(frames) // 2]
    tones = {
        "bass": {"envelope": envelope(med, "bass"), "harmonics_db": harmonics([frames[k] for k in loudest], 28, 53, cents)},
        "pads": {"envelope": envelope(med, "pads")},
        "lead": {"envelope": envelope(lead, "lead"), "harmonics_db": harmonics([frames[k] for k in loudest], 60, 85, cents)},
        "drums": {"envelope": envelope(drum_db, "drums")},
    }

    measured = {
        "bpm": bpm,
        "tonic": NAMES[pc],
        "mode": mode,
        "held": [[k, held[k]] for k in sorted(held, key=lambda k: (-held[k], k))],
        "key_scores": [[NAMES[r] + ("" if md == "major" else "m"), round(s, 3)] for s, r, md in ranked[:4]],
    }
    final_bpm = hand.get("bpm", bpm)
    tonic = hand.get("tonic", NAMES[pc])
    tonic_pc = NAMES.index(tonic)
    return {
        "song": "There's Only Love in My Heart (Avdrav)",
        "seconds": round(seconds, 3),
        "rms_dbfs": round(20 * math.log10(rms), 1),
        "bpm": final_bpm,
        "beats_per_bar": BEATS_PER_BAR,
        "first_bar": round(bar0, 4),
        "bars": bars,
        "tuning_cents": cents,
        "tonic": tonic,
        "tonic_hz": round(pitch_hz(48 + tonic_pc, cents), 2),
        "mode": hand.get("mode", mode),
        "measured": measured,
        "hand": hand,
        "keys": local,
        "chords": chords,
        "drums": dict(drums, swing=round(swing, 3)),
        "tones": tones,
    }


def dumps(profile):
    return json.dumps(profile, indent=1, sort_keys=True) + "\n"


def committed():
    if not os.path.exists(PROFILE):
        return None
    with open(PROFILE) as f:
        return f.read()


def main():
    old = committed()
    hand = json.loads(old).get("hand", {}) if old else {}
    if not os.path.exists(SONG):
        print("no %s: profile left as it is" % os.path.relpath(SONG))
        sys.exit(0)
    text = dumps(analyse(hand))
    if "--check" in sys.argv:
        if text != old:
            print("differs: tools/music/song_profile.json")
            sys.exit(1)
        return
    with open(PROFILE, "w") as f:
        f.write(text)


if __name__ == "__main__":
    main()
