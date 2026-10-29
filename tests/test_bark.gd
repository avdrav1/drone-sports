extends RefCounted
# Story 7.3: crew lines. Three lines per event for every cast member, injured
# variants, silence from the dead, no repeats within a job, and the lines reach
# the HUD and the results screen.

const Sim = preload("res://tests/sim.gd")
const Results = preload("res://scripts/ui/results.gd")

func _fresh() -> void:
	SaveGame.write_section("roster", {})
	Roster.load_saved()

func _bark(seed := 1) -> Bark:
	var b := Bark.new()
	b.seed = seed
	Sim.add(b)
	return b

func test_every_member_has_three_lines_per_event() -> bool:
	_fresh()
	var ok: bool = Roster.ids().size() == 6
	for id in Roster.ids():
		var c: Character = Roster.character(id)
		var lines := Bark.lines_of(id)
		for e in Bark.EVENTS:
			var entry: Dictionary = lines.get(String(e), {})
			ok = ok and entry.get("active", []).size() >= 3
			if c.can_be_harmed:
				ok = ok and entry.get("injured", []).size() >= 1
	return ok

func test_injured_uses_injured_variant() -> bool:
	_fresh()
	var b := _bark()
	var active: Array = Bark.lines_of(&"sanjaya").strike.active
	var injured: Array = Bark.lines_of(&"sanjaya").strike.injured
	var before := b.say(&"strike", &"sanjaya")
	Roster.injure(&"sanjaya")
	var after := b.say(&"strike", &"sanjaya")
	var ok: bool = before.text in active and after.text in injured
	b.free()
	_fresh()
	return ok

func test_dead_never_speak() -> bool:
	_fresh()
	var b := _bark()
	Roster.kill(&"sanjaya")
	var ok := true
	for e in Bark.EVENTS:
		ok = ok and b.say(e, &"sanjaya").is_empty() and not &"sanjaya" in b.speakers(e).filter(func(id): return not b.available(id, e).is_empty())
	# Gate callouts belong to the spotter alone, so a dead spotter means silence.
	ok = ok and b.say(&"gate_passed").is_empty()
	b.free()
	_fresh()
	return ok

func test_no_repeat_within_a_job() -> bool:
	_fresh()
	var b := _bark(7)
	var pool := Bark.pool(&"sanjaya", &"gate_passed")
	var said := []
	for i in pool.size():
		said.append(b.say(&"gate_passed", &"sanjaya").get("text", ""))
	var exhausted := b.say(&"gate_passed", &"sanjaya")
	var distinct := true
	for t in said:
		distinct = distinct and said.count(t) == 1 and t in pool
	b.free()
	return distinct and exhausted.is_empty()

func test_single_line_may_repeat() -> bool:
	_fresh()
	var saved: Dictionary = Bark.lines_of(&"sanjaya")
	Bark._cache[&"sanjaya"] = {"gate_passed": {"active": ["Only this."]}}
	var b := _bark()
	var a := b.say(&"gate_passed", &"sanjaya")
	var c := b.say(&"gate_passed", &"sanjaya")
	Bark._cache[&"sanjaya"] = saved
	b.free()
	return a.get("text", "") == "Only this." and c.get("text", "") == "Only this."

func test_job_events_reach_hud_and_results() -> bool:
	_fresh()
	var scene: Node = load("res://scenes/jobs/sample_delivery.tscn").instantiate()
	var runner: JobRunner = scene.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	Sim.add(scene)
	await Sim.process_frames(3)
	var box: BarkBox = scene.get_node("HUD/BarkBox")
	var briefed: bool = box.showing() and box.current.event == &"briefing"
	runner.fail("test")
	await Sim.process_frames(2)
	var failed: bool = box.current.event == &"fail"
	var closing: Dictionary = runner.result.bark
	var row := Results.bark_row(closing) if not closing.is_empty() else null
	var ok: bool = briefed and failed and closing.get("event") == &"results" \
		and row != null and (row.get_child(1) as Label).text.ends_with(closing.text)
	if row:
		row.free()
	scene.free()
	return ok

func test_race_gate_callout() -> bool:
	_fresh()
	var scene: Node = load("res://scenes/jobs/test_race.tscn").instantiate()
	var runner: JobRunner = scene.get_node("JobRunner")
	runner.pays_out = false
	Sim.add(scene)
	await Sim.process_frames(3)
	var bark: Bark = scene.get_node("Bark")
	var heard := []
	bark.spoke.connect(func(id, e, _t): heard.append([id, e]))
	var course: Course = scene.get_node("Course")
	course.gate_passed.emit(scene.get_node("Drone"), 1)
	course.gate_passed.emit(course.racers()[1], 2)
	scene.free()
	return heard == [[&"sanjaya", &"gate_passed"]]

# Story 17.4: every pitch line names a face the rig can make.
func test_pitch_lines_set_a_valid_face() -> bool:
	_fresh()
	var ok := true
	for id in Roster.ids():
		var e: Dictionary = Bark.lines_of(id).get("pitch", {})
		for line in e.get("active", []) + e.get("injured", []):
			ok = ok and line is Dictionary and StringName(line.get("face", "")) in CharacterPortrait.EXPRESSIONS
		ok = ok and not Bark.pitch(id, &"test_race").is_empty()
	Roster.kill(&"sanjaya")
	ok = ok and Bark.pitch(&"sanjaya", &"test_race").is_empty()
	_fresh()
	return ok
