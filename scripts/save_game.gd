class_name SaveGame
extends RefCounted
# One JSON save file, split into sections that each system owns. A file that
# will not parse is moved aside to `<path>.corrupt` and the game starts fresh,
# with `warning` set for the job board to show.

static var path := "user://save.json"
## The game's name before Story 24.1. On desktop, user:// is a folder named
## after the game, so older saves are in the folder of this name beside it.
const OLD_NAME := "Drone Sports"
## Left in the new folder once a save is carried over, so it is carried once.
const CARRIED := "carried_over.txt"
## Set in the environment to skip carrying over. The test runner sets it before
## the autoloads boot, and the Godot processes it starts inherit it, so tests
## keep away from the player's folders.
const NO_CARRY := "DRONE_NO_CARRY"
## Set when a corrupt save was moved aside; the board shows it once.
static var warning := ""
## Story 25.2: each character's id before the cast took names from the epics,
## and the id it has now. The only place the old ids live.
const RENAMED_IDS := {"pip": "arjuna", "rin": "drona", "marlo": "sanjaya", "dot": "nala", "bea": "bhima",
	"ozzie": "sushena", "fen": "abhimanyu", "moss": "jatayu", "tally": "hanuman"}

static func read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary:
		if migrate_ids(json.data):
			_store(json.data)
		return json.data
	_set_aside()
	return {}

static func read_section(key: String, fallback = null):
	return read().get(key, fallback)

static func write_section(key: String, value) -> void:
	var data := read()
	data[key] = value
	_store(data)

static func _store(data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write the save: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "\t"))

## Story 25.2: a save from before the ids were renamed holds the old ones, as
## the roster's keys (status, injuries, the dead) and the chosen pilot. Renames
## them in `data` once, at load; true if anything changed, so read() stores it
## and the old ids are gone from the file. An entry already under the new id
## wins over one under the old.
static func migrate_ids(data: Dictionary) -> bool:
	var changed := false
	var roster = data.get("roster")
	if roster is Dictionary:
		for old in RENAMED_IDS:
			if roster.has(old):
				var new_id: String = RENAMED_IDS[old]
				# Both kept (only by a hand-edited save): the worse status wins, so
				# no one dead comes back (rule 7).
				if not roster.has(new_id) or _hurt(roster[old]) > _hurt(roster[new_id]):
					roster[new_id] = roster[old]
				roster.erase(old)
				changed = true
	var profile = data.get("profile")
	if profile is Dictionary and RENAMED_IDS.has(str(profile.get("pilot", ""))):
		profile["pilot"] = RENAMED_IDS[str(profile["pilot"])]
		changed = true
	return changed

## 0 active, 1 injured, 2 dead.
static func _hurt(entry) -> int:
	var status := String(entry.get("status", "active")) if entry is Dictionary else "active"
	return ["active", "injured", "dead"].find(status.to_lower())

## Every system reads its section again, as on a fresh launch.
static func load_all(tree: SceneTree) -> void:
	GameSettings.load_saved()
	for autoload in ["Wallet", "Reputation", "Roster", "Career", "Garage", "Hangar", "Sfx"]:
		var node := tree.root.get_node_or_null(autoload)
		if node:
			node.load_saved()

## Story 24.2: renaming the game moved user:// on desktop. At boot, before
## anything reads the save, a save left in the old folder is copied into the
## new one. On the web user:// does not follow the name, so nothing moves.
static func carry_over_on_boot() -> void:
	if OS.has_environment(NO_CARRY) or OS.has_feature("web"):
		return
	var here := OS.get_user_data_dir()
	carry_over(here.get_base_dir().path_join(OLD_NAME), here, path.get_file())

## Copies `file` from `old_dir` into `new_dir` when the new folder has none and
## never had one carried over. Never deletes or overwrites. True if it copied.
static func carry_over(old_dir: String, new_dir: String, file := "save.json") -> bool:
	var from := old_dir.path_join(file)
	var to := new_dir.path_join(file)
	if old_dir == new_dir or not FileAccess.file_exists(from) or FileAccess.file_exists(to) \
			or FileAccess.file_exists(new_dir.path_join(CARRIED)):
		return false
	DirAccess.make_dir_recursive_absolute(new_dir)
	var err := DirAccess.copy_absolute(from, to)
	if err != OK:
		push_warning("Could not carry the save over from %s: %s" % [from, error_string(err)])
		return false
	var note := FileAccess.open(new_dir.path_join(CARRIED), FileAccess.WRITE)
	if note:
		note.store_string(from)
	return true

static func _set_aside() -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.remove_absolute(abs_path + ".corrupt")
	DirAccess.rename_absolute(abs_path, abs_path + ".corrupt")
	warning = "Your save file could not be read, so this is a new game. The old file was kept as %s.corrupt." % path.get_file()
	push_warning(warning)
