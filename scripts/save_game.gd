class_name SaveGame
extends RefCounted
# One JSON save file, split into sections that each system owns. A file that
# will not parse is moved aside to `<path>.corrupt` and the game starts fresh,
# with `warning` set for the job board to show.

static var path := "user://save.json"
## Set when a corrupt save was moved aside; the board shows it once.
static var warning := ""

static func read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary:
		return json.data
	_set_aside()
	return {}

static func read_section(key: String, fallback = null):
	return read().get(key, fallback)

static func write_section(key: String, value) -> void:
	var data := read()
	data[key] = value
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write the save: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "\t"))

## Every system reads its section again, as on a fresh launch.
static func load_all(tree: SceneTree) -> void:
	GameSettings.load_saved()
	for autoload in ["Wallet", "Reputation", "Roster", "Career"]:
		var node := tree.root.get_node_or_null(autoload)
		if node:
			node.load_saved()

static func _set_aside() -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.remove_absolute(abs_path + ".corrupt")
	DirAccess.rename_absolute(abs_path, abs_path + ".corrupt")
	warning = "Your save file could not be read, so this is a new game. The old file was kept as %s.corrupt." % path.get_file()
	push_warning(warning)
