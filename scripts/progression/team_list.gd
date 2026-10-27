class_name TeamList
extends Resource
# Every team, in the order the career meets them. A list rather than a folder
# scan, so exported builds (where .tres files are remapped) find them too.

@export var teams: Array[Team] = []

func by_id(id: StringName) -> Team:
	for t in teams:
		if t.id == id:
			return t
	return null

func in_faction(faction: StringName) -> Array[Team]:
	var out: Array[Team] = []
	for t in teams:
		if t.faction == faction:
			out.append(t)
	return out
