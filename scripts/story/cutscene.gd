class_name Cutscene
extends Resource
# A run of beats played by CutscenePlayer, then a scene to go to.

@export var beats: Array[CutsceneBeat] = []
@export_file("*.tscn") var next_scene := ""
## Set when the cutscene ends, played through or skipped.
@export var seen_flag: StringName

func total_time() -> float:
	var t := 0.0
	for b in beats:
		t += b.duration
	return t
