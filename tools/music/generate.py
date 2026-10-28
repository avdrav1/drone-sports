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
in which bar). Run from the repo root: python3 tools/music/generate.py
With --check it renders everything into build/music/check/ instead and exits
nonzero unless every file there matches data/music/ byte for byte.
"""

import filecmp
import json
import math
import os
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
# Vorbis quality (-q:a). Mono 22050 Hz keeps all of data/music/ under 8 MB.
QUALITY = "2"
BEATS_PER_BAR = 4
# The chant hook every act arranges (Story 16.3).
MANTRA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "mantra.json")
MANTRA_BARS = 8
# Octave each instrument plays the hook in.
MANTRA_OCTAVE = {"voice": 0, "lead": 1, "tanpura": 0}
# Everything the generator wrote this run, for manifest.json.
MANIFEST = {"scores": {}}


def bar_samples(tempo, bars):
    """Samples in `bars` bars of 4/4 at `tempo` bpm."""
    return round(bars * BEATS_PER_BAR * 60.0 / tempo * RATE)


def write_wav(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.9 / peak
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * scale * 32767)) for s in samples))


def encode(wav_path, ogg_path):
    """WAV -> mono Ogg Vorbis. bitexact keeps the stream serial and headers
    fixed, so the output is the same on every run."""
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
                    "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
                    "-c:a", "libvorbis", "-q:a", QUALITY, "-ac", "1", "-ar", str(RATE), ogg_path],
                   check=True)


def write_score(score_id, tempo, tonic, bars, stems, extra=None):
    """Writes each stem (id, samples, level_db) as WAV and Ogg, then the Score
    resource data/music/<score_id>.tres naming them, and lists the score (plus
    `extra` fields) in the manifest."""
    MANIFEST["scores"][score_id] = dict({"tempo": float(tempo), "tonic": float(tonic), "bars": bars,
                                         "stems": [stem_id for stem_id, _, _ in stems]}, **(extra or {}))
    if score_id.startswith("act_"):
        # Every act arranges the mantra: a stem named mantra..., whole hooks long.
        assert any(stem_id.startswith("mantra") for stem_id, _, _ in stems), "%s: no mantra stem" % score_id
        assert bars % MANTRA_BARS == 0, "%s: %d bars is not whole hooks" % (score_id, bars)
    lengths = {len(s) for _, s, _ in stems}
    assert len(lengths) == 1, "%s: stems differ in length %s" % (score_id, lengths)
    os.makedirs(OUT, exist_ok=True)
    ext, subs, refs = [], [], []
    for k, (stem_id, samples, level_db) in enumerate(stems):
        name = "%s_%s" % (score_id, stem_id)
        wav = os.path.join(WAV_DIR, name + ".wav")
        write_wav(wav, samples)
        encode(wav, os.path.join(OUT, name + ".ogg"))
        ext.append('[ext_resource type="AudioStream" path="res://data/music/%s.ogg" id="%d"]' % (name, k + 1))
        subs.append('[sub_resource type="Resource" id="stem_%d"]\nscript = ExtResource("stem")\n'
                    'id = &"%s"\nstream = ExtResource("%d")\nlevel_db = %s\n' % (k + 1, stem_id, k + 1, float(level_db)))
        refs.append('SubResource("stem_%d")' % (k + 1))
    text = '[gd_resource type="Resource" script_class="Score" load_steps=%d format=3]\n\n' % (len(stems) * 2 + 3)
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
    """Story 16.1: a single sine on the tonic, four bars at 120 bpm. Not music."""
    tempo, bars = 120, 4
    n = bar_samples(tempo, bars)
    write_score("placeholder", tempo, key.TONIC, bars, [("tonic", sine_loop(key.TONIC, n), -12.0)])


def demo():
    """Story 16.2: every instrument in turn, one bar each, in the key."""
    tempo = 120
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
    """Story 16.3: the hook alone, sung, on the saw lead and on the tanpura."""
    tempo = 120
    stems = [("mantra_" + name, render_mantra(name, tempo), -6.0) for name in ("voice", "lead", "tanpura")]
    write_score("mantra", tempo, key.TONIC, MANTRA_BARS, stems)


def write_manifest():
    MANIFEST.update({
        "tonic": key.TONIC,
        "fifth": key.FIFTH,
        "scale": list(key.SCALE),
        "instruments": list(instruments.INSTRUMENTS),
        "vowels": list(instruments.VOWELS),
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
    write_manifest()


def main():
    if "--check" in sys.argv:
        sys.exit(0 if check() else 1)
    generate()


if __name__ == "__main__":
    main()
