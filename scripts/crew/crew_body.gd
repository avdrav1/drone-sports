class_name CrewBody
extends Resource
# One rigged body from the CC0 pack in data/models/crew/ (Story 20.1). The pack
# supplies only the body, its hair and its animations; colours come from the
# CrewLook that wears it. tools/models/crew_bodies.py makes the model files.

## What a crew figure does; each names a clip in `clips`.
const ACTIONS: Array[StringName] = [&"idle", &"wave", &"cheer", &"flinch", &"hurt"]

@export var id: StringName
## The body's .glb in data/models/crew/.
@export var model: PackedScene
## The hair the body comes with, e.g. twin_buns or crop.
@export var hair_style: StringName
## Top of the hair over the front of the head, in model units: where a hat
## sits (tools/models/crew_bodies.py prints it).
@export var crown := 0.67
## Action (one of ACTIONS) -> the pack's clip that plays it, the closest it has.
@export var clips: Dictionary[StringName, StringName] = {}

## Problems with this resource; empty when it is valid.
func validate() -> Array[String]:
	var out: Array[String] = []
	if id == &"" or hair_style == &"":
		out.append("body needs an id and a hair style")
	if model == null:
		out.append("%s: no model" % id)
	for a in ACTIONS:
		if not clips.has(a):
			out.append("%s: no clip for %s" % [id, a])
	return out
