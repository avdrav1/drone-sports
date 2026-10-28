"""The game's one key (Epic 16). Every score, the motor hum and the Lattice's
sounds are tuned from TONIC here; tools/music/generate.py and
tools/sfx/generate.py both import this file.

Just intonation over the tonic: a held drone note sounds clean against the
fifth and the major third. Degrees are 1-based (1 is the tonic, 5 the fifth);
degree 8 is the tonic an octave up and degree 0 the seventh an octave down.
"""

# D3.
TONIC = 146.83
FIFTH = TONIC * 3 / 2
# Ratios to the tonic for degrees 1..7.
SCALE = (1.0, 9 / 8, 5 / 4, 4 / 3, 3 / 2, 5 / 3, 15 / 8)


def hz(degree, octave=0):
    """The frequency of a scale degree, `octave` octaves from the tonic's."""
    octs, k = divmod(degree - 1, len(SCALE))
    return TONIC * SCALE[k] * 2.0 ** (octs + octave)
