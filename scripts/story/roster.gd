extends Node
# Autoload "Roster": the cast and their status, kept in the save's "roster" section.
# Injured benches a character for INJURY_JOBS jobs, fewer with a fit medic's
# recovery perk (Story 19.6); a second injury while injured kills. Death is permanent: there is no way back (CLAUDE.md rule 7).
# For the dead, `jobs` counts the jobs finished since (Story 7.6: the shop).

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

## Jobs finished since this character died; 0 for the living.
func jobs_since_death(id: StringName) -> int:
	return _state[id].jobs if status(id) == Status.DEAD else 0

## Jobs an injury to `id` benches them for now: INJURY_JOBS less the fit
## crew's recovery perks, never their own, and at least one.
func injury_jobs(id: StringName) -> int:
	return maxi(1, INJURY_JOBS - roundi(Perks.amount(&"recovery", id)))

## First strike injures; a strike while injured kills.
func injure(id: StringName) -> void:
	if not _harmable(id):
		return
	match status(id):
		Status.ACTIVE:
			_record(id, Status.INJURED, injury_jobs(id))
		Status.INJURED:
			_record(id, Status.DEAD, 0)

func kill(id: StringName) -> void:
	if _harmable(id) and status(id) != Status.DEAD:
		_record(id, Status.DEAD, 0)

## A job ended: injured characters count down toward active again, and the
## dead count the jobs since. Anyone in `skip` was hurt on that job, so it does
## not count for them.
func job_done(skip: Array = []) -> void:
	for id in _state.keys():
		if _state[id].status == Status.INJURED and not id in skip:
			_state[id].jobs -= 1
			if _state[id].jobs <= 0:
				_state.erase(id)
				status_changed.emit(id, Status.ACTIVE)
		elif _state[id].status == Status.DEAD and not id in skip:
			_state[id].jobs += 1
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
