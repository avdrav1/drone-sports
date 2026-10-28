class_name Cutscene
extends Resource
# A run of beats played by CutscenePlayer, then a scene to go to.

@export var beats: Array[CutsceneBeat] = []
@export_file("*.tscn") var next_scene := ""
## SoundEvent id of the loop under the whole cutscene (Story 14.8). Not music.
@export var bed: StringName
## Set when the cutscene ends, played through or skipped.
@export var seen_flag: StringName

func total_time() -> float:
	var t := 0.0
	for b in beats:
		t += b.duration
	return t
