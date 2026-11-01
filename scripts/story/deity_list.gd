class_name DeityList
extends Resource
# The Four, in thread order. A list rather than a folder scan, so exported
# builds (where .tres files are remapped) find them too.

@export var deities: Array[Deity] = []

func by_id(id: StringName) -> Deity:
	for d in deities:
		if d.id == id:
			return d
	return null

func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for d in deities:
		out.append(d.id)
	return out
