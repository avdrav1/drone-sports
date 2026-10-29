"""The instruments every score is built from (Story 16.2). Standard library only.

Each instrument renders one note to a list of samples at RATE: a frequency in
Hz (from key.hz, so everything sits in the one key), a length in seconds, and
for some an extra (the voice's vowel). A note may ring past its length; a
Track places notes by beat and wraps tails around the loop, so stems loop
without a click. Randomness comes from an explicit seed, so every render is
the same.
"""

import math
import random

import key

RATE = 22050

# Every instrument, in the order the demo score plays them.
INSTRUMENTS = (
    "tanpura", "reed", "voice", "frame_drum", "cymbals",
    "kick", "clap", "bass", "arp", "pad", "lead",
)
# The formant voice's vowel syllables: the only syllables any lyric may use.
VOWELS = ("ah", "oo", "ee", "mm")
# Formants per vowel: (centre Hz, bandwidth Hz, gain).
FORMANTS = {
    "ah": ((700, 130, 1.0), (1150, 150, 0.5), (2500, 200, 0.22)),
    "oo": ((320, 80, 1.0), (750, 120, 0.3), (2400, 200, 0.06)),
    "ee": ((280, 80, 1.0), (2250, 200, 0.35), (2950, 250, 0.25)),
    "mm": ((250, 90, 1.0), (1100, 300, 0.04), (2400, 300, 0.02)),
}
TABLE = 2048


class Track:
    """One stem being built: n samples, notes placed by beat at `tempo` bpm."""

    def __init__(self, n, tempo):
        self.n = n
        self.tempo = tempo
        self.buf = [0.0] * n

    def at(self, beat):
        return round(beat * 60.0 / self.tempo * RATE)

    def seconds(self, beats):
        return beats * 60.0 / self.tempo

    def add(self, beat, samples, gain=1.0):
        start = self.at(beat)
        n = self.n
        buf = self.buf
        for i, s in enumerate(samples):
            buf[(start + i) % n] += s * gain


def _envelope(n_on, attack, release):
    """Attack-hold-release gain over n_on samples plus the release tail."""
    a = max(1, int(attack * RATE))
    r = max(1, int(release * RATE))
    out = []
    for i in range(n_on + r):
        if i < n_on:
            g = min(1.0, i / a)
        else:
            g = min(1.0, n_on / a) * (1.0 - (i - n_on) / r)
        out.append(g)
    return out


_tables = {}


def _table(amps):
    """One cycle of a waveform with harmonic amplitudes `amps` (1-based)."""
    k = tuple(round(a, 6) for a in amps)
    if k not in _tables:
        t = [0.0] * TABLE
        for h, a in enumerate(k, 1):
            if a:
                w = 2 * math.pi * h / TABLE
                for i in range(TABLE):
                    t[i] += a * math.sin(w * i)
        peak = max(1e-9, max(abs(x) for x in t))
        _tables[k] = [x / peak for x in t]
    return _tables[k]


def _limit(freq):
    """Harmonics below Nyquist (with margin) for a note at freq."""
    return max(1, int(0.45 * RATE / freq))


def _saw_amps(freq):
    return [1.0 / h for h in range(1, _limit(freq) + 1)]


def _osc(table, freq, n, vibrato=0.0, rate=5.5, delay=0.0, phase=0.0):
    """Reads `table` at freq for n samples; vibrato is a depth ratio that fades
    in after `delay` seconds."""
    out = []
    inc = freq * TABLE / RATE
    p = phase * TABLE
    for i in range(n):
        d = 1.0
        if vibrato:
            t = i / RATE
            depth = vibrato * min(1.0, max(0.0, (t - delay) / 0.3))
            d = 1.0 + depth * math.sin(2 * math.pi * rate * t)
        out.append(table[int(p) % TABLE])
        p += inc * d
    return out


def _lowpass(samples, a):
    y = 0.0
    out = []
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def tanpura(freq, length, seed=0):
    """A plucked drone string: Karplus-Strong tuned with a fractional delay,
    ringing about four seconds, through a buzzing bridge (jawari) whose
    brightness swells and settles as the string rings."""
    rng = random.Random(seed)
    n = int((length + 3.0) * RATE)
    period = RATE / freq - 0.5  # the two-point average adds half a sample
    n0 = int(period)
    fr = period - n0
    g = 10 ** (-3.0 / (4.0 * freq))  # 60 dB down in four seconds
    y = [0.0] * n
    burst = _lowpass([rng.uniform(-1, 1) for _ in range(n0 + 2)], 0.5)
    for i in range(n0 + 2):
        y[i] = burst[i]
    for i in range(n0 + 2, n):
        a = 0.5 * (y[i - n0] + y[i - n0 - 1])
        b = 0.5 * (y[i - n0 - 1] + y[i - n0 - 2])
        y[i] = g * ((1 - fr) * a + fr * b)
    out = []
    for i, v in enumerate(y):
        t = i / RATE
        buzz = 0.6 * (1 - math.exp(-t * 3)) * math.exp(-t * 0.6)
        out.append((1 - buzz) * v + buzz * math.tanh(6 * v) * 0.4)
    return out


def reed(freq, length, seed=0):
    """A harmonium or shruti-box reed: two reeds a hair apart so they beat,
    each a reedy wave with strong odd harmonics, on a slow bellows swell."""
    amps = [(1.0 / h) * (1.0 if h % 2 else 0.55) for h in range(1, min(24, _limit(freq)) + 1)]
    tab = _table(amps)
    env = _envelope(int(length * RATE), 0.12, 0.25)
    n = len(env)
    a = _osc(tab, freq, n)
    b = _osc(tab, freq * 1.0025, n, phase=0.3)
    return [(a[i] + b[i]) * 0.5 * env[i] * (0.9 + 0.1 * math.sin(2 * math.pi * 0.4 * i / RATE))
            for i in range(n)]


def formant_table(freq, vowel):
    """One cycle of the voice at freq singing `vowel`: a glottal buzz
    (harmonics falling off) shaped by the vowel's formants."""
    amps = []
    for h in range(1, _limit(freq) + 1):
        f = h * freq
        g = sum(gain / (1.0 + ((f - c) / (bw / 2.0)) ** 2) for c, bw, gain in FORMANTS[vowel])
        amps.append(g / h ** 0.6)
    return _table(amps)


def voice(freq, length, vowel="ah", seed=0):
    """A sung vowel: the formant voice, with vibrato that comes in as the note
    is held."""
    tab = formant_table(freq, vowel)
    env = _envelope(int(length * RATE), 0.06, 0.15)
    s = _osc(tab, freq, len(env), vibrato=0.006, delay=0.25)
    return [s[i] * env[i] for i in range(len(env))]


def frame_drum(freq, length=0.4, seed=0):
    """A hand-struck frame drum: a low membrane tone that drops a little in
    pitch, a second mode above it, and the slap of the hand. A high freq
    makes the rim stroke: short and mostly slap."""
    rng = random.Random(seed)
    n = int(max(length, 0.35) * RATE)
    rim = freq > 200
    decay = 30.0 if rim else 9.0
    out = []
    ph1 = ph2 = 0.0
    hp = 0.0
    for i in range(n):
        t = i / RATE
        f = freq * (1.0 + 0.15 * math.exp(-t * 40))
        ph1 += 2 * math.pi * f / RATE
        ph2 += 2 * math.pi * f * 1.59 / RATE
        x = rng.uniform(-1, 1)
        hp += 0.2 * (x - hp)
        slap = (x - hp) * math.exp(-t * 70)
        tone = (math.sin(ph1) + 0.4 * math.sin(ph2)) * math.exp(-t * decay)
        out.append(tone * (0.3 if rim else 1.0) + slap * (0.9 if rim else 0.35))
    return out


def cymbals(freq, length=1.5, seed=0):
    """Finger cymbals: a few inharmonic partials over freq, a bright strike
    and a long shimmering ring."""
    partials = ((1.0, 1.0, 1.2), (1.47, 0.6, 1.6), (2.09, 0.4, 2.2), (2.56, 0.3, 2.8))
    n = int(max(length, 1.5) * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        s = sum(a * math.sin(2 * math.pi * freq * r * t + r) * math.exp(-t * d) for r, a, d in partials)
        out.append(s * min(1.0, t / 0.002) * (1 + 0.15 * math.sin(2 * math.pi * 6.5 * t)))
    return out


def kick(freq, length=0.4, seed=0):
    """The pop kick: a sine sweeping down onto freq, with a click on top."""
    n = int(0.4 * RATE)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / RATE
        f = freq + (170 - freq) * math.exp(-t * 30)
        ph += 2 * math.pi * f / RATE
        click = math.exp(-t * 400) * 0.5
        out.append((math.sin(ph) * math.exp(-t * 7) + click) * min(1.0, t / 0.001))
    return out


def clap(freq=0.0, length=0.3, seed=0):
    """The pop clap: three quick bursts of band-limited noise and a short tail."""
    rng = random.Random(seed)
    n = int(0.3 * RATE)
    lo = hi = 0.0
    out = []
    for i in range(n):
        t = i / RATE
        x = rng.uniform(-1, 1)
        lo += 0.08 * (x - lo)
        hi += 0.5 * (x - hi)
        band = hi - lo
        bursts = sum(math.exp(-(t - k * 0.011) * 180) for k in range(3) if t >= k * 0.011)
        out.append(band * (bursts + 0.6 * math.exp(-t * 18)))
    return out


def bass(freq, length, seed=0):
    """The synth bass: a saw through a low-pass that closes after each pluck."""
    tab = _table(_saw_amps(freq))
    env = _envelope(int(length * RATE), 0.005, 0.05)
    s = _osc(tab, freq, len(env))
    y = 0.0
    out = []
    for i, x in enumerate(s):
        a = 0.03 + 0.25 * math.exp(-i / RATE * 12)
        y += a * (x - y)
        out.append(y * env[i])
    return out


def arp(freq, length, seed=0):
    """The arpeggio: a short square-ish pluck."""
    amps = [(1.0 / h if h % 2 else 0.0) for h in range(1, min(15, _limit(freq)) + 1)]
    tab = _table(amps)
    n = int((length + 0.1) * RATE)
    s = _osc(tab, freq, n)
    return [s[i] * min(1.0, i / 40) * math.exp(-i / RATE * 14) for i in range(n)]


def pad(freq, length, seed=0):
    """The bright pad: three detuned saws, slow in and slow out."""
    tab = _table(_saw_amps(freq * 1.01))
    env = _envelope(int(length * RATE), 0.4, 0.6)
    n = len(env)
    voices = [_osc(tab, freq * d, n, phase=p) for d, p in ((1.0, 0.0), (1.006, 0.33), (0.994, 0.66))]
    s = [(voices[0][i] + voices[1][i] + voices[2][i]) / 3 * env[i] for i in range(n)]
    return _lowpass(s, 0.35)


def lead(freq, length, seed=0):
    """The saw lead: a bright saw with vibrato on held notes."""
    tab = _table(_saw_amps(freq * 1.01))
    env = _envelope(int(length * RATE), 0.01, 0.08)
    s = _osc(tab, freq, len(env), vibrato=0.005, delay=0.2)
    return _lowpass([s[i] * env[i] for i in range(len(env))], 0.5)


PLAY = {name: globals()[name] for name in INSTRUMENTS}


def note(instrument, freq, length, extra=None, seed=0):
    """One note on any instrument. `extra` is the voice's vowel."""
    if instrument == "voice":
        return voice(freq, length, extra or "ah", seed)
    return PLAY[instrument](freq, length, seed=seed)


def demo_bar(track, instrument, bar, seed):
    """Bar `bar` of `track`: one short phrase on `instrument`, in the key."""
    b = bar * 4
    beat = track.seconds(1)
    if instrument == "tanpura":
        # The classic four strings: fifth, tonic up, tonic up, tonic low.
        for k, (d, o) in enumerate(((5, -1), (1, 0), (1, 0), (1, -1))):
            track.add(b + k, tanpura(key.hz(d, o), beat, seed + k), 0.8)
    elif instrument == "reed":
        for d, o in ((1, 0), (5, 0), (1, 1)):
            track.add(b, reed(key.hz(d, o), 4 * beat - 0.3, seed), 0.35)
    elif instrument == "voice":
        for k, (v, d) in enumerate(zip(VOWELS, (1, 3, 5, 1))):
            track.add(b + k, voice(key.hz(d, 1), beat * 0.9, v, seed), 0.8)
    elif instrument == "frame_drum":
        for t, f in ((0, key.hz(1, -1)), (1, 520), (1.5, 520), (2, key.hz(1, -1)), (2.75, 520), (3, 520)):
            track.add(b + t, frame_drum(f, seed=seed + int(t * 4)), 0.8)
    elif instrument == "cymbals":
        for t in (0, 2):
            track.add(b + t, cymbals(key.hz(5, 4), seed=seed), 0.3)
    elif instrument == "kick":
        for t in range(4):
            track.add(b + t, kick(key.hz(5, -2)), 1.0)
    elif instrument == "clap":
        for t in (1, 3):
            track.add(b + t, clap(seed=seed + t), 0.8)
    elif instrument == "bass":
        for k in range(8):
            track.add(b + k * 0.5, bass(key.hz(1 if k < 6 else 5, -1), beat * 0.45), 0.8)
    elif instrument == "arp":
        for k in range(16):
            d = (1, 3, 5, 8)[k % 4]
            track.add(b + k * 0.25, arp(key.hz(d, 1), beat * 0.2), 0.5)
    elif instrument == "pad":
        for d in (1, 3, 5):
            track.add(b, pad(key.hz(d, 0), 4 * beat - 0.6), 0.4)
    elif instrument == "lead":
        for t, d, l in ((0, 5, 1), (1, 6, 0.5), (1.5, 5, 0.5), (2, 3, 1), (3, 1, 1)):
            track.add(b + t, lead(key.hz(d, 1), beat * l * 0.95), 0.5)
