class_name Score
extends Resource
# A piece of music as data (data/music/*.tres, written by tools/music/generate.py):
# its tempo, key, length, and the same-length stems Music starts together.

@export var id: StringName
## Beats per minute; bars are 4/4.
@export var tempo := 120.0
## The key's tonic in Hz.
@export var tonic := 146.83
## Length of the loop in bars.
@export var bars := 4
@export var stems: Array[Stem] = []

func find(stem_id: StringName) -> Stem:
	for s in stems:
		if s.id == stem_id:
			return s
	return null
