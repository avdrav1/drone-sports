extends RefCounted
# Story 18.3: emotes. Each mapped event or expression shows its emote for its
# time, then clears; one at a time, the newest replacing the oldest. Warnings,
# strikes, injuries, deaths, memorials and the Lattice show none, and the dead
# never emote.

const Sim = preload("res://tests/sim.gd")
const TABLE := preload("res://data/crew/emotes.tres")
const STEP := 1.0 / 60.0

func _fresh() -> void:
	SaveGame.write_section("roster", {})
	Roster.load_saved()

func _face(id := &"marlo") -> CharacterPortrait:
	var p := CharacterPortrait.new()
	p.character = Roster.character(id)
	p.size = Vector2(64, 64)
	return p

## Advances `b` by `seconds` in frame-sized steps.
func _run(b: EmoteBubble, seconds: float) -> void:
	for i in roundi(seconds / STEP):
		b._process(STEP)

func test_every_mapped_event_shows_for_its_time_then_clears() -> bool:
	_fresh()
	var face := _face()
	var b := EmoteBubble.attach(face)
	var keys := {}
	var ok := TABLE.emotes.size() >= 6
	for e in TABLE.emotes:
		ok = ok and e.drawing in EmoteBubble.DRAWINGS and e.time > 0.0
		keys[e.key] = e.drawing
		b.play(e.key)
		ok = ok and b.current == e and b.showing()
		_run(b, e.time - 0.1)
		ok = ok and b.current == e and b.showing()
		_run(b, 0.2)
		ok = ok and b.current == null and not b.showing()
	# The story's six: hearts on a clean finish, sparkles on a best, sweat when
	# worried, "!" on a near miss, notes when happy, stars after a crash.
	ok = ok and keys.get(&"clean_finish") == &"hearts" and keys.get(&"best") == &"sparkles" \
		and keys.get(&"worried") == &"sweat" and keys.get(&"near_miss") == &"bang" \
		and keys.get(&"happy") == &"notes" and keys.get(&"crash") == &"stars"
	face.free()
	return ok

func test_idle_emote_waits_until_the_face_stops_talking() -> bool:
	_fresh()
	var face := _face()
	var b := EmoteBubble.attach(face)
	var happy := TABLE.find(&"happy")
	face.talking = true
	b.play(&"happy")
	_run(b, happy.time + 0.5)
	var ok: bool = happy.idle and b.current == happy and not b.showing()
	face.talking = false
	ok = ok and b.showing()
	_run(b, happy.time + 0.1)
	ok = ok and b.current == null
	face.free()
	return ok

func test_newest_replaces_oldest() -> bool:
	_fresh()
	var face := _face()
	var b := EmoteBubble.attach(face)
	b.play(&"crash")
	_run(b, 0.5)
	b.play(&"near_miss")
	var ok: bool = b.current == TABLE.find(&"near_miss") and b.age == 0.0
	# A line with no emote clears the last one.
	b.play_line(&"briefing", &"determined")
	ok = ok and b.current == null
	face.free()
	return ok

func test_lines_pick_event_then_face() -> bool:
	return TABLE.for_line(&"near_miss", &"happy") == TABLE.find(&"near_miss") \
		and TABLE.for_line(&"battery_low", &"worried") == TABLE.find(&"worried") \
		and TABLE.for_line(&"gate_passed", &"happy") == TABLE.find(&"happy") \
		and TABLE.for_line(&"briefing", &"determined") == null

func test_serious_lines_show_no_emote() -> bool:
	_fresh()
	var face := _face()
	var b := EmoteBubble.attach(face)
	var ok := true
	for event in [&"warning", &"strike", &"hurt", &"memorial", &"epilogue"]:
		for expr in CharacterPortrait.EXPRESSIONS:
			b.play(&"crash")
			b.play_line(event, expr)
			ok = ok and b.current == null and not b.showing()
	face.free()
	return ok

func test_every_lattice_line_shows_no_emote() -> bool:
	_fresh()
	var lattice: Job = load("res://data/boss/lattice_job.tres")
	var ok := lattice.job_type in TABLE.quiet_job_types
	# Every crew line on the Lattice job, Marlo's trench calls too, through the radio.
	var runner := JobRunner.new()
	runner.job = lattice
	var bark := Bark.new()
	bark.seed = 1
	bark.runner = runner
	Sim.add(bark)
	var box := BarkBox.new()
	box.bark = bark
	Sim.add(box)
	var events: Array = Bark.EVENTS.duplicate()
	events.append(&"trench")
	for chorus_event in Chorus.load_lines("res://data/dialogue/lattice.json"):
		events.append(StringName(chorus_event))
	for event in events:
		for expr in CharacterPortrait.EXPRESSIONS:
			box._open({"id": &"marlo", "event": event, "text": "Line.", "face": expr})
			ok = ok and box.portrait.character != null and not box.emote.showing()
			ok = ok and TABLE.for_line(event, expr, lattice.job_type) == null
	box.free()
	bark.free()
	runner.free()
	return ok

func test_radio_shows_emotes_and_hearts_only_on_a_clean_finish() -> bool:
	_fresh()
	var runner := JobRunner.new()
	runner.job = Job.new()
	var bark := Bark.new()
	bark.seed = 1
	bark.runner = runner
	Sim.add(bark)
	var box := BarkBox.new()
	box.bark = bark
	Sim.add(box)
	box._open({"id": &"marlo", "event": &"near_miss", "text": "Whoa.", "face": &"shocked"})
	var ok: bool = box.emote.current == TABLE.find(&"near_miss")
	box._open({"id": &"marlo", "event": &"complete", "text": "Done.", "face": &"happy"})
	ok = ok and box.emote.current == TABLE.find(&"clean_finish")
	box._open({"id": &"marlo", "event": &"warning", "text": "Careful.", "face": &"worried"})
	ok = ok and box.emote.current == null
	runner.strikes[&"marlo"] = 1
	box._open({"id": &"marlo", "event": &"complete", "text": "Done.", "face": &"neutral"})
	ok = ok and box.emote.current == null
	# Once someone is hurt the radio stays sincere.
	runner.casualties[&"marlo"] = Roster.Status.INJURED
	box._open({"id": &"marlo", "event": &"crash", "text": "Ow.", "face": &"worried"})
	ok = ok and box.emote.current == null
	box.free()
	bark.free()
	runner.free()
	return ok

func test_results_sparkle_on_best_hearts_on_clean_quiet_after_casualty() -> bool:
	_fresh()
	var Results = load("res://scripts/ui/results.gd")
	var r := JobResult.new()
	r.job = Job.new()
	r.completed = true
	var line := {"id": &"rin", "event": &"results", "text": "Nice.", "face": &"neutral"}
	var ok: bool = Results.emote_event(r) == &"clean_finish"
	r.new_best = true
	var row: HBoxContainer = Results.bark_row(line, r)
	var bubble: EmoteBubble = row.get_child(0).get_child(0)
	ok = ok and bubble.current == TABLE.find(&"best")
	row.free()
	r.casualties[&"marlo"] = Roster.Status.DEAD
	row = Results.bark_row(line, r)
	ok = ok and (row.get_child(0).get_child(0) as EmoteBubble).current == null
	row.free()
	r.casualties.clear()
	r.new_best = false
	r.job.job_type = &"boss"
	row = Results.bark_row(line, r)
	ok = ok and (row.get_child(0).get_child(0) as EmoteBubble).current == null
	row.free()
	return ok

func test_the_dead_never_emote() -> bool:
	_fresh()
	var face := _face()
	var b := EmoteBubble.attach(face)
	b.play(&"crash")
	var ok := b.showing()
	# Dying mid-emote clears it.
	Roster.kill(&"marlo")
	b._process(STEP)
	ok = ok and b.current == null
	for e in TABLE.emotes:
		b.play(e.key)
		ok = ok and b.current == null and not b.showing()
	face.free()
	# Greyed (e.g. on the roster) is dead too.
	_fresh()
	var grey := _face(&"rin")
	grey.greyed = true
	var gb := EmoteBubble.attach(grey)
	gb.play(&"best")
	ok = ok and gb.current == null
	grey.free()
	_fresh()
	return ok

func test_every_emote_draws_at_32_64_128() -> bool:
	_fresh()
	var ok := true
	for s in [32.0, 64.0, 128.0]:
		var face := _face()
		face.size = Vector2(s, s)
		Sim.add(face)
		var b := EmoteBubble.attach(face)
		for e in TABLE.emotes:
			b.play(e.key)
			_run(b, 0.3)
			b.queue_redraw()
			await Sim.process_frames(2)
			ok = ok and b.showing()
		face.free()
	return ok

class Fixed extends Objective:
	var value := 1.0
	func score() -> float:
		return value

## Flies the test job through JobRunner to its end with one objective scoring
## `value` (a fail when `complete` is false); returns the result.
func _fly(value: float, complete := true) -> JobResult:
	var o := Fixed.new()
	o.value = value
	var j: Job = load("res://data/jobs/test_job.tres").duplicate()
	j.countdown = 0.1
	var root := Sim.job_setup(j, [o])
	await Sim.go_live(root)
	var runner: JobRunner = root.get_node("Runner")
	if complete:
		runner.complete()
	else:
		runner.fail("test")
	var r := runner.result
	root.free()
	return r

func test_job_runner_flags_new_best_only_on_a_better_grade() -> bool:
	var real_path := SaveGame.path
	SaveGame.path = "user://test_emotes_best.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path))
	Career.load_saved()
	var first: JobResult = await _fly(0.65)
	var better: JobResult = await _fly(0.95)
	var equal: JobResult = await _fly(0.95)
	var worse: JobResult = await _fly(0.65)
	var failed: JobResult = await _fly(1.0, false)
	var Results = load("res://scripts/ui/results.gd")
	var ok: bool = first.letter == "C" and not first.new_best \
		and better.letter == "A" and better.new_best \
		and equal.letter == "A" and not equal.new_best \
		and worse.letter == "C" and not worse.new_best \
		and failed.letter == "F" and not failed.new_best \
		and Results.emote_event(better) == &"best" and Results.emote_event(equal) == &"clean_finish"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path))
	SaveGame.path = real_path
	Career.load_saved()
	Wallet.load_saved()
	Reputation.load_saved()
	Roster.load_saved()
	return ok
