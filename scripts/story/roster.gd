extends Node
# Autoload "Roster": the cast and their status, kept in the save's "roster" section.
# Injured benches a character for INJURY_JOBS jobs; a second injury while
# injured kills. Death is permanent: there is no way back (CLAUDE.md rule 7).

enum Status { ACTIVE, INJURED, DEAD }

signal status_changed(id: StringName, status: Status)

const CAST := preload("res://data/characters/cast.tres")
const INJURY_JOBS := 2

## id -> Character
var characters := {}
## id -> {status, jobs}; only characters that are not active appear.
var _state := {}

func _ready() -> void:
	for c in CAST.characters:
		characters[c.id] = c
	load_saved()

func character(id: StringName) -> Character:
	return characters.get(id)

func ids() -> Array:
	return characters.keys()

func status(id: StringName) -> Status:
	return _state[id].status if _state.has(id) else Status.ACTIVE

func is_alive(id: StringName) -> bool:
	return status(id) != Status.DEAD

## Jobs left on the bench while injured; 0 otherwise.
func jobs_benched(id: StringName) -> int:
	return _state[id].jobs if status(id) == Status.INJURED else 0

## First strike injures; a strike while injured kills.
func injure(id: StringName) -> void:
	if not _harmable(id):
		return
	match status(id):
		Status.ACTIVE:
			_record(id, Status.INJURED, INJURY_JOBS)
		Status.INJURED:
			_record(id, Status.DEAD, 0)

func kill(id: StringName) -> void:
	if _harmable(id) and status(id) != Status.DEAD:
		_record(id, Status.DEAD, 0)

## A job ended: injured characters count down toward active again.
func job_done() -> void:
	for id in _state.keys():
		if _state[id].status == Status.INJURED:
			_state[id].jobs -= 1
			if _state[id].jobs <= 0:
				_state.erase(id)
				status_changed.emit(id, Status.ACTIVE)
	save()

func _harmable(id: StringName) -> bool:
	var c := character(id)
	return c != null and c.can_be_harmed

func _record(id: StringName, s: Status, jobs: int) -> void:
	_state[id] = {"status": s, "jobs": jobs}
	save()
	status_changed.emit(id, s)

func save() -> void:
	var out := {}
	for id in _state:
		out[String(id)] = {"status": Status.keys()[_state[id].status].to_lower(), "jobs": _state[id].jobs}
	SaveGame.write_section("roster", out)

func load_saved() -> void:
	_state.clear()
	var saved = SaveGame.read_section("roster", {})
	if not saved is Dictionary:
		return
	for key in saved:
		var entry = saved[key]
		var id := StringName(key)
		if not characters.has(id) or not entry is Dictionary:
			continue
		var name := String(entry.get("status", "active")).to_upper()
		if name in ["INJURED", "DEAD"]:
			_state[id] = {"status": Status[name], "jobs": int(entry.get("jobs", 0))}
