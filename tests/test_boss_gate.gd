extends RefCounted
# Story 8.1: boss resource and kill switch. Off, the Lattice never reaches the
# board and nothing under scenes/boss/ loads; on, the board says why it can't
# be flown until it can.

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"

func _board() -> JobBoard:
	var b: JobBoard = load(BOARD).instantiate()
	Sim.add(b)
	return b

## The shipped boss with `enabled` set, installed for this test.
func _boss(on: bool) -> Boss:
	var b: Boss = (load(BossGate.DATA) as Boss).duplicate()
	b.enabled = on
	BossGate.boss = b
	BossGate.loads.clear()
	return b

## Every boss scene path, for the load spy.
func _boss_scene_paths() -> Array[String]:
	var out: Array[String] = [(load(BossGate.DATA) as Boss).job.scene]
	var dir := DirAccess.open("res://scenes/boss")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".tscn"):
				out.append("res://scenes/boss/" + f)
	return out

func _cached_boss_scenes() -> Array:
	return _boss_scene_paths().filter(func(p): return ResourceLoader.has_cached(p))

func test_shipped_data_is_the_flag() -> bool:
	var b: Boss = load(BossGate.DATA)
	return b.enabled and b.required_characters == [&"sanjaya"] and b.min_fleet == 2 and b.min_grade == "A" \
		and b.job.tags.has(&"lethal") and b.chorus.ends_with("lattice.json") and b.hold_time > 0.0

func test_disabled_never_listed_or_loaded() -> bool:
	_boss(false)
	# Everything met, so only the flag keeps it off.
	Career.job_completed(&"fleet_race")
	var b := _board()
	await Sim.process_frames(2)
	b.refresh()
	var ok := not b.job_rows.has(&"lattice") and not BossGate.listed() and not BossGate.open(Sim.tree()) \
		and BossGate.loads.is_empty() and _cached_boss_scenes().is_empty()
	b.free()
	BossGate.boss = null
	return ok

## Every board mission's id.
static func _missions() -> Array[StringName]:
	var out: Array[StringName] = []
	for job in (load("res://data/jobs/board.tres") as JobList).jobs:
		out.append(job.id)
	return out

func test_unmet_requirements_show_why() -> bool:
	_boss(true)
	var b := _board()
	await Sim.process_frames(1)
	var row: Node = b.job_rows.get(&"lattice")
	var first: String = row.get_node("Locked").text if row and row.has_node("Locked") else ""
	b.free()
	# Every mission at A but one, which is only a B.
	var missions := _missions()
	for id in missions:
		Career.job_flown(id, "B" if id == missions[0] else "A")
	Roster.kill(&"sanjaya")
	for id in [&"nala", &"sushena"]:
		Roster.kill(id)
	b = _board()
	await Sim.process_frames(1)
	row = b.job_rows.get(&"lattice")
	var second: String = row.get_node("Locked").text if row and row.has_node("Locked") else ""
	var ok := first.contains("A on every mission first, %d to go" % missions.size()) \
		and second.contains("A on every mission first, 1 to go") and second.contains("Sanjaya is gone") \
		and second.contains("needs 2 crew who fly, 1 left") \
		and b.fly_button(&"lattice") == null and BossGate.loads.is_empty()
	if not ok:
		print("        %s / %s" % [first, second])
	b.free()
	BossGate.boss = null
	return ok

## Ravana opens once every board mission has been graded A.
func test_all_met_is_flyable() -> bool:
	_boss(true)
	var shut := not BossGate.flyable()
	for id in _missions():
		Career.job_flown(id, "A")
	var b := _board()
	await Sim.process_frames(1)
	var ok := shut and b.fly_button(&"lattice") != null and BossGate.flyable() and BossGate.reasons().is_empty()
	b.free()
	BossGate.boss = null
	return ok
