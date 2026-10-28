class_name JobList
extends Resource
# Every job the board can show, in board order. A list rather than a folder
# scan, so exported builds (where .tres files are remapped) find them too.

@export var jobs: Array[Job] = []

func by_id(id: StringName) -> Job:
	for j in jobs:
		if j.id == id:
			return j
	return null
