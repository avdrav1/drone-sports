#!/usr/bin/env python3
"""Generates the game's music into data/music/ (Epic 16).

Standard library only, plus ffmpeg for the Ogg Vorbis encode. Every score uses
fixed seeds, so running this again writes the same files byte for byte. Each
score is a set of stems of exactly the same length in samples, so Music can
start them on one frame and they stay in step while their volumes fade. The
generator writes WAV stems to build/music/ (not checked in), encodes each to
mono Ogg Vorbis in data/music/, and writes the score's .tres beside them.
Run from the repo root: python3 tools/music/generate.py
"""

import math
import os
import struct
import subprocess
import wave

RATE = 22050
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
WAV_DIR = os.path.join(ROOT, "build", "music")
OUT = os.path.join(ROOT, "data", "music")
# Vorbis quality (-q:a). Mono 22050 Hz keeps all of data/music/ under 8 MB.
QUALITY = "2"
BEATS_PER_BAR = 4
# Placeholder tonic (D3) until Story 16.2 moves the key to tools/music/key.py.
TONIC = 146.83


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


def write_score(score_id, tempo, tonic, bars, stems):
    """Writes each stem (id, samples, level_db) as WAV and Ogg, then the Score
    resource data/music/<score_id>.tres naming them."""
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
    write_score("placeholder", tempo, TONIC, bars, [("tonic", sine_loop(TONIC, n), -12.0)])


def main():
    placeholder()


if __name__ == "__main__":
    main()
