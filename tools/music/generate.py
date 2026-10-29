#!/usr/bin/env python3
"""Generates the game's music into data/music/ (Epic 16).

Standard library only, plus ffmpeg for the Ogg Vorbis encode. Every score uses
fixed seeds, so running this again writes the same files byte for byte. Each
score is a set of stems of exactly the same length in samples, so Music can
start them on one frame and they stay in step while their volumes fade. The
generator writes WAV stems to build/music/ (not checked in), encodes each to
mono Ogg Vorbis in data/music/, and writes the score's .tres beside them.
It also writes data/music/manifest.json: the key, the instruments, and each
score's tempo, tonic, bars and stems (and for the demo, which instrument plays
in which bar). Since Story 21.3 every score is in the song's sound: its tempo
(SONG_BPM, or half: TEMPO_MULTIPLE), its tonic (key.py), its chords
(song_chords), its groove (groove) and its instruments' tones (instruments.py),
all read from tools/music/song_profile.json. Run from the repo root: python3 tools/music/generate.py
With --check it renders everything into build/music/check/ instead and exits
nonzero unless every file there matches data/music/ byte for byte.
"""

import array
import filecmp
import json
import math
import os
import random
import struct
import subprocess
import sys
import wave

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import key  # noqa: E402
import instruments  # noqa: E402

RATE = 22050
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
WAV_DIR = os.path.join(ROOT, "build", "music")
OUT = os.path.join(ROOT, "data", "music")
# Vorbis quality (-q:a). Mono 22050 Hz keeps all of data/music/ under 10 MB.
QUALITY = "2"
BEATS_PER_BAR = 4
# The chant hook every act arranges (Story 16.3).
MANTRA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "mantra.json")
MANTRA_BARS = 8
# Octave each instrument plays the hook in.
MANTRA_OCTAVE = {"voice": 0, "lead": 1, "tanpura": 0, "reed": 1}
# Everything the generator wrote this run, for manifest.json.
MANIFEST = {"scores": {}}
# The song's fingerprint (Story 21.2): tempo, chords per bar, groove, tones.
with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "song_profile.json")) as _f:
    PROFILE = json.load(_f)
SONG_BPM = PROFILE["bpm"]
# Story 21.3: every score's tempo is the song's times one of these. The song
# runs at 160 with a half-time feel, so the slow acts take the half-time pulse.
TEMPO_MULTIPLES = (0.5, 1.0)


def bar_samples(tempo, bars):
    """Samples in `bars` bars of 4/4 at `tempo` bpm."""
    return round(bars * BEATS_PER_BAR * 60.0 / tempo * RATE)


def keep_out_of_godot(path):
    """A WAV under build/ is an intermediate: a .gdignore in build/ keeps Godot
    from importing it into the project and the web export."""
    build = os.path.join(ROOT, "build")
    if os.path.abspath(path).startswith(os.path.abspath(build) + os.sep):
        open(os.path.join(build, ".gdignore"), "a").close()


def write_wav(path, samples, peak=None, channels=1, rate=RATE):
    """Writes `samples` (interleaved if `channels` is 2) normalized so `peak`
    (their own by default) is 0.9."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    keep_out_of_godot(path)
    peak = peak or max(1e-9, max(abs(s) for s in samples))
    scale = 0.9 / peak
    with wave.open(path, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", int(s * scale * 32767)) for s in samples))


def encode(wav_path, ogg_path, channels=1, rate=RATE, quality=QUALITY):
    """WAV -> Ogg Vorbis, mono by default. bitexact keeps the stream serial and
    headers fixed, so the output is the same on every run."""
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
                    "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
                    "-c:a", "libvorbis", "-q:a", quality, "-ac", str(channels), "-ar", str(rate), ogg_path],
                   check=True)


def lowpass_loop(samples, a):
    """One-pole low-pass run twice around a loop, so its end meets its start."""
    y = 0.0
    out = list(samples)
    for _ in range(2):
        for i, x in enumerate(samples):
            y += a * (x - y)
            out[i] = y
    return out


def muffle(samples, rate=RATE):
    """Snow's hush for music (Story 16.8), as tools/sfx/generate.py muffles the
    ambience loops: the stem with its highs gone, baked (the web build has no
    live filters). Same length, so it plays in step with the stem. The filter
    keeps its cutoff at any sample `rate`."""
    a = 0.08 if rate == RATE else 1.0 - 0.92 ** (RATE / rate)
    for _ in range(2):
        samples = lowpass_loop(samples, a)
    return samples


def write_score(score_id, tempo, tonic, bars, stems, extra=None):
    """Writes each stem (id, samples, level_db) as WAV and Ogg, and its muffled
    copy (<score>_<stem>_muffled.ogg, normalized with the stem so it is as much
    quieter as the highs it lost), then the Score resource
    data/music/<score_id>.tres naming them, and lists the score (plus `extra`
    fields) in the manifest."""
    assert tempo / SONG_BPM in TEMPO_MULTIPLES and tonic == key.TONIC, score_id
    MANIFEST["scores"][score_id] = dict({"tempo": float(tempo), "tonic": float(tonic), "bars": bars,
                                         "tempo_multiple": tempo / SONG_BPM,
                                         "stems": [stem_id for stem_id, _, _ in stems]}, **(extra or {}))
    if score_id.startswith("act_"):
        # Every act arranges the mantra: a stem named mantra..., whole hooks long.
        assert any(stem_id.startswith("mantra") for stem_id, _, _ in stems), "%s: no mantra stem" % score_id
        assert bars % MANTRA_BARS == 0, "%s: %d bars is not whole hooks" % (score_id, bars)
    lengths = {len(s) for _, s, _ in stems}
    assert len(lengths) == 1, "%s: stems differ in length %s" % (score_id, lengths)
    os.makedirs(OUT, exist_ok=True)
    for stem_id, samples, level_db in stems:
        name = "%s_%s" % (score_id, stem_id)
        wav = os.path.join(WAV_DIR, name + ".wav")
        write_wav(wav, samples)
        encode(wav, os.path.join(OUT, name + ".ogg"))
        wav = os.path.join(WAV_DIR, name + "_muffled.wav")
        write_wav(wav, muffle(samples), max(1e-9, max(abs(x) for x in samples)))
        encode(wav, os.path.join(OUT, name + "_muffled.ogg"))
    write_tres(score_id, tempo, tonic, bars, [(stem_id, level_db) for stem_id, _, level_db in stems])


def write_tres(score_id, tempo, tonic, bars, stems):
    """data/music/<score_id>.tres: a Score of `stems` (id, level_db), each
    playing <score>_<stem>.ogg with <score>_<stem>_muffled.ogg for snow."""
    ext, subs, refs = [], [], []
    for k, (stem_id, level_db) in enumerate(stems):
        name = "%s_%s" % (score_id, stem_id)
        ext.append('[ext_resource type="AudioStream" path="res://data/music/%s.ogg" id="%d"]' % (name, k + 1))
        ext.append('[ext_resource type="AudioStream" path="res://data/music/%s_muffled.ogg" id="m%d"]' % (name, k + 1))
        subs.append('[sub_resource type="Resource" id="stem_%d"]\nscript = ExtResource("stem")\n'
                    'id = &"%s"\nstream = ExtResource("%d")\nlevel_db = %s\nmuffled = ExtResource("m%d")\n'
                    % (k + 1, stem_id, k + 1, float(level_db), k + 1))
        refs.append('SubResource("stem_%d")' % (k + 1))
    text = '[gd_resource type="Resource" script_class="Score" load_steps=%d format=3]\n\n' % (len(stems) * 3 + 3)
    text += '[ext_resource type="Script" path="res://scripts/audio/stem.gd" id="stem"]\n'
    text += '[ext_resource type="Script" path="res://scripts/audio/score.gd" id="score"]\n'
    text += "\n".join(ext) + "\n\n" + "\n".join(subs) + "\n"
    text += ('[resource]\nscript = ExtResource("score")\nid = &"%s"\ntempo = %s\ntonic = %s\nbars = %d\n'
             'stems = Array[ExtResource("stem")]([%s])\n' % (score_id, float(tempo), float(tonic), bars, ", ".join(refs)))
    with open(os.path.join(OUT, score_id + ".tres"), "w") as f:
        f.write(text)


def sine_loop(freq, n):
    """A sine as close to `freq` as whole cycles over n samples allow, so it loops."""
    cycles = max(1, round(freq * n / RATE))
    return [math.sin(2 * math.pi * cycles * i / n) for i in range(n)]


def placeholder():
    """Story 16.1: a single sine on the tonic, four bars at the song's tempo. Not music."""
    tempo, bars = SONG_BPM, 4
    n = bar_samples(tempo, bars)
    write_score("placeholder", tempo, key.TONIC, bars, [("tonic", sine_loop(key.TONIC, n), -12.0)])


def demo():
    """Story 16.2: every instrument in turn, one bar each, in the key, at the
    song's half-time pulse (each bar's phrase is written in quarters)."""
    tempo = SONG_BPM / 2
    bars = len(instruments.INSTRUMENTS)
    track = instruments.Track(bar_samples(tempo, bars), tempo)
    for bar, name in enumerate(instruments.INSTRUMENTS):
        instruments.demo_bar(track, name, bar, 1600 + bar * 10)
    order = [{"bar": bar, "instrument": name} for bar, name in enumerate(instruments.INSTRUMENTS)]
    write_score("demo", tempo, key.TONIC, bars, [("demo", track.buf, -6.0)], {"instruments": order})


def load_mantra():
    """mantra.json, checked: invented vowel syllables only, scale degrees, and
    16 beats (4 bars) in each half."""
    with open(MANTRA) as f:
        m = json.load(f)
    for half in ("call", "answer"):
        assert sum(n["beats"] for n in m[half]) == MANTRA_BARS // 2 * BEATS_PER_BAR, half
        for n in m[half]:
            assert n["syllable"] in instruments.VOWELS, n
            assert isinstance(n["degree"], int) and n["beats"] > 0, n
    return m


def render_mantra(instrument, tempo, half=None, octave=None, seed=1700):
    """The hook on any instrument (sung by the voice on its syllables, played by
    the lead, plucked by the tanpura...) at `tempo`: exactly 8 bars, or 4 for
    one `half` ("call" or "answer"), so it loops with any score at that tempo."""
    m = load_mantra()
    notes = m[half] if half else m["call"] + m["answer"]
    bars = MANTRA_BARS // 2 if half else MANTRA_BARS
    octave = MANTRA_OCTAVE.get(instrument, 0) if octave is None else octave
    track = instruments.Track(bar_samples(tempo, bars), tempo)
    beat = 0
    for k, n in enumerate(notes):
        length = track.seconds(n["beats"]) * 0.95
        track.add(beat, instruments.note(instrument, key.hz(n["degree"], octave), length, n["syllable"], seed + k))
        beat += n["beats"]
    assert beat == bars * BEATS_PER_BAR and len(track.buf) == bar_samples(tempo, bars)
    return track.buf


def mantra():
    """Story 16.3: the hook alone, sung, on the lead and on the tanpura, at the
    song's half-time pulse."""
    tempo = SONG_BPM / 2
    stems = [("mantra_" + name, render_mantra(name, tempo), -6.0) for name in ("voice", "lead", "tanpura")]
    write_score("mantra", tempo, key.TONIC, MANTRA_BARS, stems)


# Story 21.3: the harmony is the song's. HARMONY_BAR is the bar (of the song's
# 160 bpm bars) where the theme loop's chord cycle starts on the tonic: F Bb Gm
# F Bb Dm F Bb (I IV ii I IV vi I IV), one chord every two song bars. A score
# plays one chord per bar of its own, the song's harmonic rhythm at half time
# and twice it at full tempo. The call ends on the fifth over F and the answer
# on the tonic over Bb, the song's IV-I running on round the loop.
HARMONY_BAR = 254
NOTE_NAMES = ("C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B")
# Just ratios over the tonic for a chord root `semitones` above it. The minor
# chord on the second degree sits on 10/9, so its fifth is pure (5/3 over it).
ROOT_RATIOS = {0: 1.0, 2: 9 / 8, 3: 6 / 5, 4: 5 / 4, 5: 4 / 3, 7: 3 / 2, 8: 8 / 5, 9: 5 / 3, 10: 9 / 5, 11: 15 / 8}


def chord_ratios(name):
    """A chord name from the profile ("F", "Gm", "Bb") as (root, third, fifth)
    ratios over the tonic, root within the octave above it."""
    minor = name.endswith("m")
    root = name[:-1] if minor else name
    semis = (NOTE_NAMES.index(root) - NOTE_NAMES.index(PROFILE["tonic"])) % 12
    r = 10 / 9 if minor and semis == 2 else ROOT_RATIOS[semis]
    return (r, r * (6 / 5 if minor else 5 / 4), r * 3 / 2)


def song_chords(bars):
    """`bars` chords, one per score bar: every other song bar's chord from
    HARMONY_BAR on, as (name, (root, third, fifth) ratios)."""
    names = [PROFILE["chords"][HARMONY_BAR + 2 * k] for k in range(bars)]
    assert names[0] == PROFILE["tonic"], names
    return [(n, chord_ratios(n)) for n in names]


def chord_hz(ratios, i, octave=0):
    """Note i of a chord (0 root, 1 third, 2 fifth, 3 root up) in Hz."""
    return key.TONIC * (ratios + (ratios[0] * 2,))[i] * 2.0 ** octave


def bass_octave(ratio):
    """The octave that puts a bass root in the song's bass band (65-130 Hz;
    its envelope peaks at 99-125)."""
    f = key.TONIC * ratio
    o = 0
    while f * 2.0 ** o >= 130:
        o -= 1
    return o


def groove(tempo):
    """The song's groove (profile `drums`) on a score at `tempo`, as beats
    within one song bar and gains: {kick, snare, hat: [(beat, gain)]}. A song
    bar (16 steps, 1.5 s) is four beats at the song's tempo and two at half.
    The snare plays its strongest step (the half-time backbeat), the kick the
    steps it hits at 0.85 or more besides that one, and the hat every step it
    is heard on (0.05 or more) at its strength. Off-beat eighths swing late
    by the profile's swing."""
    d = PROFILE["drums"]
    span = BEATS_PER_BAR * tempo / SONG_BPM
    swing = d["swing"]

    def beat(step):
        q, r = divmod(step, 4)
        return (q + (swing * 2 * r / 4 if r == 2 else r / 4)) * span / 4

    back = max(range(16), key=lambda k: d["snare"]["steps"][k])
    return {"snare": [(beat(back), 1.0)],
            "kick": [(beat(k), v) for k, v in enumerate(d["kick"]["steps"]) if v >= 0.85 and k != back],
            "hat": [(beat(k), v) for k, v in enumerate(d["hat"]["steps"]) if v >= 0.05],
            "span": span}


def act_1():
    """Story 16.4, in the song's sound (21.3): the home game, fully produced.
    The song's groove (kick, snare backbeat, shaker for its hats, a clap on
    the snare) under the song's chords on the pad, keys stabs, strings, an
    arpeggio and the synth bass in eighths; a counter line on the chords'
    thirds (a melody drawn from the song's harmony), a fill into the loop, the
    hook on the lead and the tanpura drone underneath. One hook long at the
    song's tempo."""
    tempo, bars = SONG_BPM, MANTRA_BARS
    n = bar_samples(tempo, bars)
    order = ("drone", "pad", "keys", "strings", "arp", "bass", "kick", "snare", "shaker", "clap", "fill", "counter")
    tracks = {k: instruments.Track(n, tempo) for k in order}
    beat = tracks["pad"].seconds(1)
    g = groove(tempo)
    chords = song_chords(bars)
    for bar, (_, chord) in enumerate(chords):
        b = bar * BEATS_PER_BAR
        seed = 1800 + bar * 10
        # The tanpura's four strings, every bar: fifth, tonic up, tonic up, tonic low.
        for k, (d, o) in enumerate(((5, -1), (1, 0), (1, 0), (1, -1))):
            tracks["drone"].add(b + k, instruments.tanpura(key.hz(d, o), beat, seed + k), 0.8)
        for i in range(3):
            tracks["pad"].add(b, instruments.pad(chord_hz(chord, i), 4 * beat - 0.6), 0.4)
        for t in (0.5, 1.5, 2.5, 3.5):
            for i in range(3):
                tracks["keys"].add(b + t, instruments.keys(chord_hz(chord, i, 1), beat * 0.3), 0.3)
        for i in (0, 2):
            tracks["strings"].add(b, instruments.strings(chord_hz(chord, i, 1), 4 * beat - 0.4), 0.3)
        for k in range(8):
            tracks["arp"].add(b + k * 0.5, instruments.arp(chord_hz(chord, k % 4, 1), beat * 0.4), 0.5)
        low = bass_octave(chord[0])
        for k in range(8):
            tracks["bass"].add(b + k * 0.5, instruments.bass(chord_hz(chord, 0, low), beat * 0.45), 0.8)
        for at in range(0, BEATS_PER_BAR, round(g["span"])):
            for t, v in g["kick"]:
                tracks["kick"].add(b + at + t, instruments.kick(key.hz(1, -1)), v)
            for t, v in g["snare"]:
                tracks["snare"].add(b + at + t, instruments.snare(key.hz(1, 0), seed=seed + 5), v)
                tracks["clap"].add(b + at + t, instruments.clap(seed=seed + 6), 0.8)
            for k, (t, v) in enumerate(g["hat"]):
                tracks["shaker"].add(b + at + t, instruments.shaker(seed=seed + k), v)
        tracks["counter"].add(b, instruments.lead(chord_hz(chord, 1, 1), 4 * beat * 0.95, seed), 0.5)
    for k in range(8):
        # Sixteenths into the loop's top, rising.
        tracks["fill"].add((bars - 1) * BEATS_PER_BAR + 2 + k * 0.25, instruments.snare(key.hz(1, 0), seed=1890 + k),
                           0.4 + 0.08 * k)
    levels = {"drone": -10.0, "pad": -12.0, "keys": -16.0, "strings": -17.0, "arp": -17.0, "bass": -9.0, "kick": -8.0,
              "snare": -11.0, "shaker": -18.0, "clap": -16.0, "fill": -14.0, "counter": -18.0}
    stems = [(k, tracks[k].buf, levels[k]) for k in order]
    stems.append(("mantra_lead", render_mantra("lead", tempo), -10.0))
    stems.append(("pulse", pulse(tempo, bars, 1880), PULSE_DB))
    plays = {"drone": "tanpura", "pad": "pad", "keys": "keys", "strings": "strings", "arp": "arp", "bass": "bass",
             "kick": "kick", "snare": "snare", "shaker": "shaker", "clap": "clap", "fill": "snare", "counter": "lead",
             "mantra_lead": "lead", "pulse": "frame_drum"}
    write_score("act_1", tempo, key.TONIC, bars, stems, {"plays": plays, "chords": [c for c, _ in chords]})


# Story 16.8: the level of every act's `pulse` stem, a heartbeat on the low
# frame drum that, with the drone, is all that plays through a hazard warning.
PULSE_DB = -12.0


def pulse(tempo, bars, seed):
    """Two heartbeats a bar on the low frame drum (lub on the beat, dub an
    eighth after), on beats one and three."""
    track = instruments.Track(bar_samples(tempo, bars), tempo)
    for bar in range(bars):
        for t in (0, 2):
            b = bar * BEATS_PER_BAR + t
            track.add(b, instruments.frame_drum(key.hz(1, -1), seed=seed + bar * 4 + t), 1.0)
            track.add(b + 0.5, instruments.frame_drum(key.hz(1, -1), seed=seed + bar * 4 + t + 1), 0.6)
    return track.buf


# The pop kit's synths. From Act 2 on no act score has a stem played on one.
SYNTHS = ("bass", "arp", "pad", "lead")


def act_2():
    """Story 16.5, in the song's sound (21.3): the tryout. The same hook and
    the song's chords move from synths to real instruments: the harmonium
    takes the pad's chords (stem `reed`), strings hold over them, the tanpura
    plucks the arpeggio (`pluck`) over its drone, a frame drum takes the
    song's backbeat, the shaker keeps its hats, the kick is lighter, and the
    hook is on the harmonium. No bass. One hook long at the song's tempo."""
    tempo, bars = SONG_BPM, MANTRA_BARS
    n = bar_samples(tempo, bars)
    plays = {"drone": "tanpura", "reed": "reed", "strings": "strings", "pluck": "tanpura", "kick": "kick",
             "frame_drum": "frame_drum", "shaker": "shaker", "mantra_reed": "reed", "pulse": "frame_drum"}
    order = ("drone", "reed", "strings", "pluck", "kick", "frame_drum", "shaker")
    tracks = {k: instruments.Track(n, tempo) for k in order}
    beat = tracks["reed"].seconds(1)
    g = groove(tempo)
    chords = song_chords(bars)
    for bar, (_, chord) in enumerate(chords):
        b = bar * BEATS_PER_BAR
        seed = 1900 + bar * 10
        for k, (d, o) in enumerate(((5, -1), (1, 0), (1, 0), (1, -1))):
            tracks["drone"].add(b + k, instruments.tanpura(key.hz(d, o), beat, seed + k), 0.8)
        for i in range(3):
            tracks["reed"].add(b, instruments.reed(chord_hz(chord, i), 4 * beat - 0.3, seed), 0.35)
        for i in (0, 2):
            tracks["strings"].add(b, instruments.strings(chord_hz(chord, i, 1), 4 * beat - 0.4), 0.3)
        for k in range(8):
            tracks["pluck"].add(b + k * 0.5, instruments.tanpura(chord_hz(chord, k % 4, 1), beat * 0.5, seed + 4 + k), 0.5)
        for at in range(0, BEATS_PER_BAR, round(g["span"])):
            for t, v in g["kick"]:
                tracks["kick"].add(b + at + t, instruments.kick(key.hz(1, -1)), 0.6 * v)
            for t, v in g["snare"]:
                tracks["frame_drum"].add(b + at + t, instruments.frame_drum(key.hz(1, -1), seed=seed + 2), 0.8 * v)
            tracks["frame_drum"].add(b + at + g["span"] * 7 / 8, instruments.frame_drum(520, seed=seed + 3), 0.6)
            for k, (t, v) in enumerate(g["hat"]):
                tracks["shaker"].add(b + at + t, instruments.shaker(seed=seed + k), v)
    levels = {"drone": -10.0, "reed": -12.0, "strings": -17.0, "pluck": -14.0, "kick": -14.0, "frame_drum": -12.0,
              "shaker": -19.0}
    stems = [(k, tracks[k].buf, levels[k]) for k in order]
    stems.append(("mantra_reed", render_mantra("reed", tempo), -11.0))
    stems.append(("pulse", pulse(tempo, bars, 1980), PULSE_DB))
    crew = add_motifs("act_2", stems, plays, tempo, bars, 1990)
    assert not set(plays.values()) & set(SYNTHS)
    write_score("act_2", tempo, key.TONIC, bars, stems, {"plays": plays, "motifs": crew, "chords": [c for c, _ in chords]})


# Story 16.10: crew motifs. Each crew member's voice in the score, a stem named
# by their Character.motif (data/characters/), in every act score from the
# tryout on (MOTIF_ACTS), at MOTIF_DB. Stem id -> the instrument that plays it.
MOTIFS = {"motif_bea": "reed", "motif_dot": "frame_drum", "motif_marlo": "tanpura", "motif_ozzie": "voice"}
MOTIF_ACTS = ("act_2", "act_3", "act_4", "act_5")
MOTIF_DB = -13.0


def motifs(tempo, bars, seed):
    """Each MOTIFS stem, once per half of the hook: Bea's harmonium line rising
    into the half's last bar, Dot's frame drum fill over its last two beats,
    Marlo's high plucked look-out call in its second bar, and Ozzie humming
    "mm" on the third under its third bar. {stem id: samples}."""
    n = bar_samples(tempo, bars)
    t = {k: instruments.Track(n, tempo) for k in MOTIFS}
    beat = t["motif_bea"].seconds(1)
    for half in range(bars * BEATS_PER_BAR // 16):
        b = half * 16
        sd = seed + half * 40
        for k, (at, d, beats) in enumerate(((12, 3, 1), (13, 5, 1), (14, 6, 2))):
            t["motif_bea"].add(b + at, instruments.reed(key.hz(d, 1), beats * beat * 0.95, sd + k), 0.5)
        for k in range(8):
            f = 520 if k % 2 else key.hz(1, -1)
            t["motif_dot"].add(b + 14 + k * 0.25, instruments.frame_drum(f, seed=sd + 10 + k), 0.5 + 0.06 * k)
        for k, (at, d) in enumerate(((4, 8), (4.5, 6), (5, 5), (6, 8))):
            t["motif_marlo"].add(b + at, instruments.tanpura(key.hz(d, 1), beat, sd + 20 + k), 0.6)
        t["motif_ozzie"].add(b + 8, instruments.voice(key.hz(3, 0), 3 * beat * 0.95, "mm", sd + 30), 0.6)
    return {k: t[k].buf for k in MOTIFS}


def add_motifs(score_id, stems, plays, tempo, bars, seed):
    """Appends the crew motif stems to an act's `stems` and `plays`; returns
    the manifest's extra field naming them."""
    assert score_id in MOTIF_ACTS
    for k, buf in motifs(tempo, bars, seed).items():
        stems.append((k, buf, MOTIF_DB))
        plays[k] = MOTIFS[k]
    return list(MOTIFS)


def soft_clip(samples, drive):
    """`samples` normalized, then driven into tanh: rougher, with no hard edge."""
    peak = max(1e-9, max(abs(x) for x in samples))
    return [math.tanh(drive * x / peak) for x in samples]


# Story 16.6: Act 3's tempo, and Act 4's, faster, for when the governor comes
# off. Since 21.3 the song's half-time pulse and its full tempo.
ACT_3_TEMPO = SONG_BPM / 2
ACT_4_TEMPO = SONG_BPM


def hand_and_voice(score_id, tempo, rough, seed):
    """Story 16.6, in the song's sound (21.3): Acts 3 and 4. No kick and no
    bass: the tanpura drone, the harmonium on the song's chords, hand
    percussion (frame drum, finger cymbals) and the hook sung by the formant
    voice. Act 3 plucks the chords on the tanpura and keeps the song's groove
    on the frame drum (low on its kicks, rim on its backbeat) and its hats on
    the shaker. `rough` (Act 4) drops the shaker, plays the drum in busy
    eighths with rim strokes, the cymbals on every beat, the pluck in eighths,
    and drives every stem into a soft clip. One hook long."""
    bars = MANTRA_BARS
    n = bar_samples(tempo, bars)
    plays = {"drone": "tanpura", "reed": "reed", "pluck": "tanpura", "frame_drum": "frame_drum",
             "cymbals": "cymbals", "mantra_voice": "voice", "pulse": "frame_drum"}
    order = ("drone", "reed", "pluck", "frame_drum", "cymbals")
    if not rough:
        order += ("shaker",)
        plays["shaker"] = "shaker"
    tracks = {k: instruments.Track(n, tempo) for k in order}
    beat = tracks["reed"].seconds(1)
    low, rim = key.hz(1, -1), 520
    g = groove(tempo)
    if rough:
        drum = ((0, low), (0.5, rim), (1, rim), (1.5, low), (2, low), (2.5, rim), (3, rim), (3.25, rim), (3.5, low), (3.75, rim))
    else:
        drum = sorted([(at + t, low) for at in range(0, BEATS_PER_BAR, round(g["span"])) for t, _ in g["kick"]] +
                      [(at + t, rim) for at in range(0, BEATS_PER_BAR, round(g["span"])) for t, _ in g["snare"]])
    chords = song_chords(bars)
    for bar, (_, chord) in enumerate(chords):
        b = bar * BEATS_PER_BAR
        sd = seed + bar * 20
        for k, (d, o) in enumerate(((5, -1), (1, 0), (1, 0), (1, -1))):
            tracks["drone"].add(b + k, instruments.tanpura(key.hz(d, o), beat, sd + k), 0.8)
        for i in range(3):
            tracks["reed"].add(b, instruments.reed(chord_hz(chord, i), 4 * beat - 0.3, sd), 0.35)
        steps = 8 if rough else 4
        for k in range(steps):
            tracks["pluck"].add(b + k * 4 / steps, instruments.tanpura(chord_hz(chord, k % 4, 1), beat * 4 / steps, sd + 4 + k), 0.5)
        for k, (t, f) in enumerate(drum):
            tracks["frame_drum"].add(b + t, instruments.frame_drum(f, seed=sd + 12 + k), 0.8)
        for t in (range(4) if rough else (0, 2)):
            tracks["cymbals"].add(b + t, instruments.cymbals(key.hz(5, 4), seed=sd), 0.3)
        if not rough:
            for at in range(0, BEATS_PER_BAR, round(g["span"])):
                for k, (t, v) in enumerate(g["hat"]):
                    tracks["shaker"].add(b + at + t, instruments.shaker(seed=sd + k), v)
    stems = [(k, tracks[k].buf) for k in order] + [("mantra_voice", render_mantra("voice", tempo, seed=seed)),
                                                   ("pulse", pulse(tempo, bars, seed + 180))]
    if rough:
        stems = [(k, soft_clip(buf, 2.5)) for k, buf in stems]
    levels = {"drone": -10.0, "reed": -12.0, "pluck": -14.0, "frame_drum": -10.0, "cymbals": -16.0, "shaker": -19.0,
              "mantra_voice": -9.0, "pulse": PULSE_DB}
    stems = [(k, buf, levels[k]) for k, buf in stems]
    crew = add_motifs(score_id, stems, plays, tempo, bars, seed + 190)
    assert not set(plays.values()) & set(SYNTHS + ("kick", "bass"))
    write_score(score_id, tempo, key.TONIC, bars, stems, {"plays": plays, "motifs": crew, "chords": [c for c, _ in chords]})


def act_3():
    hand_and_voice("act_3", ACT_3_TEMPO, False, 2000)


def act_4():
    hand_and_voice("act_4", ACT_4_TEMPO, True, 2100)


# Story 16.7: Act 5, the fleet. Kirtan tempo (since 21.3 the song's half-time
# pulse), and the choir sizes the answer is baked at (stems choir_<size>),
# chosen by how many drones are under command.
ACT_5_TEMPO = SONG_BPM / 2
CHOIR_SIZES = (3, 10, 50)


def detune(samples, ratio):
    """`samples` played back `ratio` times faster (linear interpolation)."""
    n = int((len(samples) - 1) / ratio)
    out = []
    for i in range(n):
        x = i * ratio
        k = int(x)
        f = x - k
        out.append(samples[k] * (1 - f) + samples[k + 1] * f)
    return out


def choirs(tempo, bars, sizes, seed):
    """The answer half of the hook in bars 5-8, sung by a choir at each of
    `sizes` voices: {size: samples}. Each voice is the formant voice detuned a
    few cents, a few milliseconds late and at its own gain, and every third
    sings an octave down. The bigger choirs are the smaller plus more voices."""
    m = load_mantra()
    rng = random.Random(seed)
    track = instruments.Track(bar_samples(tempo, bars), tempo)
    start = MANTRA_BARS // 2 * BEATS_PER_BAR
    sung = {}
    out = {}
    for v in range(max(sizes)):
        octave = -1 if v % 3 == 2 else 0
        ratio = 2 ** (rng.uniform(-14, 14) / 1200.0) if v else 1.0
        late = rng.uniform(0.0, 0.03) / track.seconds(1) if v else 0.0
        gain = rng.uniform(0.6, 1.0)
        beat = start
        for k, n in enumerate(m["answer"]):
            got = (k, octave)
            if got not in sung:
                sung[got] = instruments.note("voice", key.hz(n["degree"], octave), track.seconds(n["beats"]) * 0.95,
                                             n["syllable"], seed + k)
            track.add(beat + late, detune(sung[got], ratio) if v else sung[got], gain)
            beat += n["beats"]
        if v + 1 in sizes:
            out[v + 1] = list(track.buf)
    return out


def act_5():
    """Story 16.7: the fleet, in kirtan form. One lead voice sings the call
    half of the hook (bars 1-4, stem mantra_lead) and a choir answers (bars
    5-8), baked at CHOIR_SIZES voices (choir_3, choir_10, choir_50) so the
    director can let the choir grow with the fleet. Since 21.3, stripped back
    from Act 4: under them only the tanpura drone (and the pulse), at the
    song's half-time pulse."""
    tempo, bars = ACT_5_TEMPO, MANTRA_BARS
    n = bar_samples(tempo, bars)
    plays = {"drone": "tanpura", "mantra_lead": "voice", "pulse": "frame_drum"}
    drone = instruments.Track(n, tempo)
    beat = drone.seconds(1)
    for bar in range(bars):
        b = bar * BEATS_PER_BAR
        sd = 2200 + bar * 20
        for k, (d, o) in enumerate(((5, -1), (1, 0), (1, 0), (1, -1))):
            drone.add(b + k, instruments.tanpura(key.hz(d, o), beat, sd + k), 0.8)
    stems = [("drone", drone.buf, -10.0)]
    call = render_mantra("voice", tempo, half="call", seed=2300)
    stems.append(("mantra_lead", call + [0.0] * (n - len(call)), -9.0))
    for size, buf in sorted(choirs(tempo, bars, CHOIR_SIZES, 2400).items()):
        stems.append(("choir_%d" % size, buf, -9.0))
        plays["choir_%d" % size] = "voice"
    stems.append(("pulse", pulse(tempo, bars, 2280), PULSE_DB))
    crew = add_motifs("act_5", stems, plays, tempo, bars, 2290)
    write_score("act_5", tempo, key.TONIC, bars, stems, {"plays": plays, "choirs": list(CHOIR_SIZES), "motifs": crew})


# Story 16.11: the Lattice. Slow (the song's half-time pulse), and the voices its choir is baked at: the
# smallest is sung voice by voice, each larger one is the last stacked
# LATTICE_STACK times at its own small delay and gain, up to thousands.
LATTICE_TEMPO = SONG_BPM / 2
LATTICE_BASE = 12
LATTICE_STACK = 8
LATTICE_DENSITIES = 4
# The drone stem's pitch: lattice_drone's (tools/sfx/generate.py PITCHED).
LATTICE_DRONE = (1, -2)


def lattice_choirs(tempo, bars, seed):
    """The whole hook sung by the Lattice's captured machines at
    LATTICE_DENSITIES densities: [(voices, samples)], sparsest first. The
    sparsest is LATTICE_BASE formant voices, each detuned a few cents, a few
    ms late, every third an octave down; each denser one is the last stacked
    LATTICE_STACK times, every copy shifted round the loop by up to 60 ms."""
    m = load_mantra()
    notes = m["call"] + m["answer"]
    rng = random.Random(seed)
    track = instruments.Track(bar_samples(tempo, bars), tempo)
    sung = {}
    for v in range(LATTICE_BASE):
        octave = -1 if v % 3 == 2 else 0
        ratio = 2 ** (rng.uniform(-18, 18) / 1200.0) if v else 1.0
        late = rng.uniform(0.0, 0.03) / track.seconds(1) if v else 0.0
        gain = rng.uniform(0.6, 1.0)
        beat = 0
        for k, n in enumerate(notes):
            got = (k, octave)
            if got not in sung:
                sung[got] = instruments.note("voice", key.hz(n["degree"], octave), track.seconds(n["beats"]) * 0.95,
                                             n["syllable"], seed + k)
            track.add(beat + late, detune(sung[got], ratio) if v else sung[got], gain)
            beat += n["beats"]
    out = [(LATTICE_BASE, track.buf)]
    for _ in range(LATTICE_DENSITIES - 1):
        last = out[-1][1]
        n = len(last)
        buf = [0.0] * n
        for _ in range(LATTICE_STACK):
            shift = int(rng.uniform(0.0, 0.06) * RATE)
            gain = rng.uniform(0.6, 1.0)
            rolled = last[-shift:] + last[:-shift] if shift else last
            buf = [a + b * gain for a, b in zip(buf, rolled)]
        out.append((out[-1][0] * LATTICE_STACK, buf))
    return out


def lattice():
    """Story 16.11: the Lattice sings. Over the tonic drone (two octaves down,
    in tune with lattice_drone, with the octave above) a choir of the whole
    hook at four densities (density_1 the sparsest to density_4, thousands of
    voices), and one formant voice alone (`voice`), which is all that is left
    at the override port. One hook long at LATTICE_TEMPO. No stinger."""
    tempo, bars = LATTICE_TEMPO, MANTRA_BARS
    n = bar_samples(tempo, bars)
    low, up = sine_loop(key.hz(*LATTICE_DRONE), n), sine_loop(key.hz(LATTICE_DRONE[0], LATTICE_DRONE[1] + 1), n)
    stems = [("drone", [a + 0.5 * b for a, b in zip(low, up)], -10.0),
             ("voice", render_mantra("voice", tempo, seed=2500), -9.0)]
    plays = {"drone": "sine", "voice": "voice"}
    densities = {}
    for k, (voices, buf) in enumerate(lattice_choirs(tempo, bars, 2600)):
        stems.append(("density_%d" % (k + 1), buf, -9.0))
        plays["density_%d" % (k + 1)] = "voice"
        densities["density_%d" % (k + 1)] = voices
    drone = {"degree": LATTICE_DRONE[0], "octave": LATTICE_DRONE[1], "hz": key.hz(*LATTICE_DRONE)}
    write_score("lattice", tempo, key.TONIC, bars, stems, {"plays": plays, "densities": densities, "drone": drone})


# The main title (Story 21.1): the user's own song, "There's Only Love in My
# Heart" by Avdrav, used with their permission. Its FLAC (from their own
# upload) sits in tools/music/source/, gitignored and never committed; the
# theme is one stretch of it cut on bar lines, so the score's one stem is
# audio data, not generated. The song sits on a 160 bpm grid from 0:00 (bars
# every 1.5 s). The loop is 6:00 to 7:12 of the last chorus, 48 bars, where
# the music either side of the cut matches best (chroma and level, measured
# around every 4-bar line); its last half beat crossfades into the half beat
# before 6:00, so the end runs on into the start without a gap or a click.
# Stereo 44.1 kHz, unlike the generated mono stems: it is a finished mix.
SONG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "source", "song.flac")
SONG_RATE = 44100
SONG_QUALITY = "4"
SONG_TEMPO = SONG_BPM
SONG_START = 360.0
SONG_BARS = 48
SONG_SEAM = 0.1875
# Matches the act 1 full mix's loudness (the song is mastered loud).
SONG_DB = -3.0


def song_theme():
    """Story 21.1: data/music/theme.tres, one stem `song`. The .tres and the
    manifest entry are written even without the FLAC; the Oggs need it."""
    tempo, bars = SONG_TEMPO, SONG_BARS
    MANIFEST["scores"]["theme"] = {"tempo": float(tempo), "tonic": float(key.TONIC), "bars": bars, "stems": ["song"],
                                   "tempo_multiple": tempo / SONG_BPM,
                                   "song": "There's Only Love in My Heart (Avdrav)", "start": SONG_START,
                                   "seam": SONG_SEAM, "rate": SONG_RATE}
    write_tres("theme", tempo, key.TONIC, bars, [("song", SONG_DB)])
    if not os.path.exists(SONG):
        print("no %s: theme audio left as it is" % os.path.relpath(SONG, ROOT))
        return
    pcm = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", SONG, "-map_metadata", "-1", "-ac", "2",
                          "-ar", str(SONG_RATE), "-f", "s16le", "-"], capture_output=True, check=True).stdout
    frames = array.array("h", pcm)
    n = round(bars * BEATS_PER_BAR * 60.0 / tempo * SONG_RATE)
    start, seam = round(SONG_START * SONG_RATE), round(SONG_SEAM * SONG_RATE)
    loops = []
    for ch in range(2):
        x = frames[ch::2]
        loop = [v / 32768.0 for v in x[start:start + n]]
        for i in range(seam):
            t = (i + 0.5) / seam * math.pi / 2
            loop[n - seam + i] = loop[n - seam + i] * math.cos(t) + x[start - seam + i] / 32768.0 * math.sin(t)
        loops.append(loop)
    peak = max(1e-9, max(abs(v) for loop in loops for v in loop))
    for suffix, chans in (("", loops), ("_muffled", [muffle(loop, SONG_RATE) for loop in loops])):
        wav = os.path.join(WAV_DIR, "theme_song%s.wav" % suffix)
        write_wav(wav, [v for pair in zip(*chans) for v in pair], peak, 2, SONG_RATE)
        encode(wav, os.path.join(OUT, "theme_song%s.ogg" % suffix), 2, SONG_RATE, SONG_QUALITY)


def write_manifest():
    MANIFEST.update({
        "tonic": key.TONIC,
        "fifth": key.FIFTH,
        "scale": list(key.SCALE),
        "instruments": list(instruments.INSTRUMENTS),
        "vowels": list(instruments.VOWELS),
        "synths": list(SYNTHS),
        "song_bpm": SONG_BPM,
        "tempo_multiples": list(TEMPO_MULTIPLES),
        "mantra": {"bars": MANTRA_BARS,
                   "call_beats": sum(n["beats"] for n in load_mantra()["call"]),
                   "answer_beats": sum(n["beats"] for n in load_mantra()["answer"])},
    })
    with open(os.path.join(OUT, "manifest.json"), "w") as f:
        json.dump(MANIFEST, f, indent=1, sort_keys=True)
        f.write("\n")


def check():
    """Renders into build/music/check/ and compares with data/music/."""
    global OUT
    real = OUT
    OUT = os.path.join(WAV_DIR, "check")
    if os.path.isdir(OUT):
        for f in os.listdir(OUT):
            os.remove(os.path.join(OUT, f))
    generate()
    made = sorted(os.listdir(OUT))
    have = sorted(f for f in os.listdir(real) if not f.endswith(".import"))
    if not os.path.exists(SONG):
        # Without the song's FLAC the theme's audio is not rebuilt (Story 21.1).
        have = [f for f in have if not f.startswith("theme_song")]
    bad = sorted(set(made) ^ set(have))
    bad += [f for f in made if f in have and not filecmp.cmp(os.path.join(OUT, f), os.path.join(real, f), shallow=False)]
    for f in bad:
        print("differs: data/music/%s" % f)
    return not bad


def generate():
    MANIFEST["scores"].clear()
    placeholder()
    demo()
    mantra()
    act_1()
    act_2()
    act_3()
    act_4()
    act_5()
    lattice()
    song_theme()
    write_manifest()


def main():
    if "--check" in sys.argv:
        sys.exit(0 if check() else 1)
    generate()


if __name__ == "__main__":
    main()
