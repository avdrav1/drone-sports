class_name SaveGame
extends RefCounted
# One JSON save file, split into sections that each system owns.

static var path := "user://save.json"

static func read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func read_section(key: String, fallback = null):
	return read().get(key, fallback)

static func write_section(key: String, value) -> void:
	var data := read()
	data[key] = value
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
