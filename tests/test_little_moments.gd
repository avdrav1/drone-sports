extends RefCounted
# Story 18.5: little moments. A hello on the board, a cheer on a streak of clean
# gates, encouragement on relaunching the job just failed, a cheer on an upgrade
# or an unlock, and a goodbye on leaving. Only the living say them, a streak
# cheers once, retry is only the failed job again, and cooldowns hold.

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"

func _bark(seed := 1) -> Bark:
	Bark.moment_times.clear()
	var b := Bark.new()
	b.seed = seed
	Sim.add(b)
	return b

## Events said on `b` from now on, in order.
func _record(b: Bark) -> Array:
	var heard := []
	b.said.connect(func(line): heard.append(line))
	return heard

## True when anything `b` said this job is one of `event`'s lines.
func _said(b: Bark, event: StringName) -> bool:
	for id in b.used:
		for t in b.used[id]:
			if t in Bark.pool(id, event):
				return true
	return false

func _board() -> JobBoard:
	Sim.tree().change_scene_to_file(BOARD)
	await Sim.process_frames(3)
	return Sim.tree().current_scene

func _close() -> void:
	Sim.tree().unload_current_scene()
	await Sim.process_frames(1)

func test_every_moment_has_lines_faces_and_emotes() -> bool:
	var table: EmoteTable = load("res://data/crew/emotes.tres")
	var ok := true
	for e in Bark.MOMENTS:
		ok = ok and e in Bark.EVENTS and Bark.DEFAULT_FACES.get(e, &"") in CharacterPortrait.EXPRESSIONS
		ok = ok and table.for_line(e, &"neutral") != null and table.for_line(e, &"neutral", &"boss") == null
	# Lines in every character's file, the pilot avatars too.
	for path in DirAccess.get_files_at("res://data/characters"):
		var c = load("res://data/characters/" + path)
		if not c is Character:
			continue
		var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(c.lines))
		for e in Bark.MOMENTS:
			var entry: Dictionary = lines.get(String(e), {})
			ok = ok and entry.get("active", []).size() >= 3
			if c.can_be_harmed:
				ok = ok and entry.get("injured", []).size() >= 3
	return ok

func test_each_moment_is_said_by_the_living_never_the_dead() -> bool:
	var b := _bark(4)
	var ok := true
	for e in Bark.MOMENTS:
		Bark.moment_times.clear()
		var line := b.say(e)
		ok = ok and not line.is_empty() and Roster.is_alive(line.id) and line.text in Bark.pool(line.id, e)
		# Never the pilot you fly as.
		ok = ok and line.id != PlayerProfile.pilot().id
	for id in [&"marlo", &"dot", &"bea", &"ozzie"]:
		Roster.kill(id)
	for i in 40:
		for e in Bark.MOMENTS:
			Bark.moment_times.clear()
			b.used.clear()
			var line := b.say(e)
			ok = ok and not line.is_empty() and Roster.is_alive(line.id)
			ok = ok and b.say(e, &"marlo").is_empty()
	b.free()
	return ok

func test_board_says_hello_unless_someone_just_died() -> bool:
	PlayerProfile.choose_pilot(&"pip")
	Bark.moment_times.clear()
	var board: JobBoard = await _board()
	var ok: bool = _said(board.bark, &"hello") and board.radio.current.get("event") == &"hello"
	await _close()
	Bark.moment_times.clear()
	Roster.kill(&"marlo")
	board = await _board()
	ok = ok and not _said(board.bark, &"hello") and JobBoard.death_on_last_job()
	await _close()
	return ok

func test_board_cheers_an_upgrade_and_an_unlock() -> bool:
	PlayerProfile.choose_pilot(&"pip")
	var board: JobBoard = await _board()
	Bark.moment_times.clear()
	board.bark.used.clear()
	board.shop.purchased.emit()
	var ok := _said(board.bark, &"unlock")
	Bark.moment_times.clear()
	board.bark.used.clear()
	# Nothing new: no cheer.
	board.refresh()
	ok = ok and not _said(board.bark, &"unlock")
	# Joining a team opens its jobs.
	Career.pending.append(&"cannery_row")
	Career.accept(&"cannery_row")
	board.refresh()
	ok = ok and _said(board.bark, &"unlock")
	await _close()
	return ok

func test_no_cheer_for_jobs_a_death_opens() -> bool:
	PlayerProfile.choose_pilot(&"pip")
	Career.pending.append(&"cannery_row")
	Career.accept(&"cannery_row")
	var board: JobBoard = await _board()
	board.refresh()
	await _close()
	var before := JobBoard.flyable_seen.duplicate()
	# Bea's death locks salvage, so the home jobs open again: nobody cheers that.
	Roster.kill(&"bea")
	Bark.moment_times.clear()
	board = await _board()
	var ok: bool = JobBoard.death_on_last_job() and Career.team_locked()
	ok = ok and JobBoard.flyable_seen.any(func(id): return not id in before)
	ok = ok and not _said(board.bark, &"unlock") and not _said(board.bark, &"hello")
	ok = ok and board.radio.current.get("event", &"") != &"unlock"
	# Nor a garage purchase right after.
	board.shop.purchased.emit()
	ok = ok and not _said(board.bark, &"unlock")
	await _close()
	return ok

func test_no_goodbye_off_a_board_held_quiet_for_a_death() -> bool:
	PlayerProfile.choose_pilot(&"pip")
	Roster.kill(&"marlo")
	var board: JobBoard = await _board()
	Bark.moment_times.clear()
	board.to_title()
	await Sim.process_frames(3)
	var title: Node = Sim.tree().current_scene
	var ok: bool = title is TitleScreen and title.bark == null and not TitleScreen.wave_goodbye
	await _close()
	return ok

func test_leaving_the_board_waves_goodbye() -> bool:
	PlayerProfile.choose_pilot(&"pip")
	var board: JobBoard = await _board()
	Bark.moment_times.clear()
	board.to_title()
	await Sim.process_frames(3)
	var title: Node = Sim.tree().current_scene
	var ok: bool = title is TitleScreen and title.bark != null and _said(title.bark, &"goodbye") \
		and title.radio.current.get("event") == &"goodbye" and not TitleScreen.wave_goodbye
	await _close()
	return ok

func test_streak_fires_once_per_streak() -> bool:
	var b := _bark(2)
	var heard := _record(b)
	var gate := Node3D.new()
	var streaks := func(): return heard.filter(func(l): return l.event == &"streak").size()
	for i in b.streak_gates - 1:
		b._on_gate(gate, i)
	var ok: bool = streaks.call() == 0
	b._on_gate(gate, 0)
	ok = ok and streaks.call() == 1
	for i in b.streak_gates * 3:
		b._on_gate(gate, i)
	ok = ok and streaks.call() == 1
	# A crash ends the streak; the next one cheers again.
	b._on_flight_event(&"crash")
	for i in b.streak_gates:
		b._on_gate(gate, i)
	ok = ok and streaks.call() == 2
	b._on_struck(&"marlo", Roster.Status.ACTIVE)
	for i in b.streak_gates - 1:
		b._on_gate(gate, i)
	ok = ok and streaks.call() == 2
	gate.free()
	b.free()
	return ok

func test_no_streak_once_the_crew_is_hurt() -> bool:
	var runner := JobRunner.new()
	runner.casualties[&"marlo"] = Roster.Status.DEAD
	var b := _bark(2)
	b.runner = runner
	var heard := _record(b)
	for i in b.streak_gates * 2:
		b._on_gate(null, i)
	var ok: bool = heard.filter(func(l): return l.event == &"streak").is_empty()
	b.free()
	runner.free()
	return ok

## A Bark on a runner for `job_id`, put through `states`; returns its lines.
func _run(job_id: StringName, states: Array, job_type := &"race", hurt := false) -> Array:
	var runner := JobRunner.new()
	runner.job = Job.new()
	runner.job.id = job_id
	runner.job.job_type = job_type
	if hurt:
		runner.casualties[&"marlo"] = Roster.Status.INJURED
	var b := Bark.new()
	b.seed = 5
	b.runner = runner
	Sim.add(b)
	var heard := _record(b)
	for s in states:
		b._on_state(s, JobRunner.State.IDLE)
	b.free()
	runner.free()
	return heard.map(func(l): return l.event)

func test_retry_only_on_relaunching_the_job_just_failed() -> bool:
	Bark.moment_times.clear()
	Bark.last_failed = &""
	var S := JobRunner.State
	var ok := true
	_run(&"a", [S.BRIEFING, S.FAILED])
	ok = ok and &"retry" in _run(&"a", [S.BRIEFING])
	# Only once: the relaunch after that is a plain briefing.
	Bark.moment_times.clear()
	ok = ok and not &"retry" in _run(&"a", [S.BRIEFING])
	# Another job in between, or a finish, is not a retry.
	_run(&"a", [S.BRIEFING, S.FAILED])
	ok = ok and not &"retry" in _run(&"b", [S.BRIEFING])
	ok = ok and not &"retry" in _run(&"a", [S.BRIEFING])
	_run(&"a", [S.BRIEFING, S.FAILED])
	_run(&"a", [S.BRIEFING, S.COMPLETE])
	Bark.moment_times.clear()
	ok = ok and not &"retry" in _run(&"a", [S.BRIEFING])
	# Never after someone was hurt, and never on the Lattice.
	_run(&"a", [S.BRIEFING, S.FAILED], &"race", true)
	ok = ok and not &"retry" in _run(&"a", [S.BRIEFING])
	_run(&"boss", [S.BRIEFING, S.FAILED], &"boss")
	ok = ok and not &"retry" in _run(&"boss", [S.BRIEFING], &"boss")
	# A fresh new game never starts with a retry.
	ok = ok and not &"retry" in _run(&"c", [S.BRIEFING])
	return ok

func test_cooldowns_hold() -> bool:
	var b := _bark(6)
	var ok: bool = not b.say(&"hello", &"marlo").is_empty()
	ok = ok and b.say(&"hello", &"marlo").is_empty() and not Bark.cooled(&"marlo", &"hello")
	# Another moment, or another character, is not held back.
	ok = ok and not b.say(&"goodbye", &"marlo").is_empty() and not b.say(&"hello", &"dot").is_empty()
	# Held across scenes: a new Bark (the board built again) still waits.
	var again := Bark.new()
	Sim.add(again)
	ok = ok and again.say(&"hello", &"marlo").is_empty()
	# Everyone greets at most once a minute.
	var who := []
	for i in 20:
		var line := again.say(&"hello")
		if not line.is_empty():
			ok = ok and not line.id in who
			who.append(line.id)
	ok = ok and again.say(&"hello").is_empty()
	# A minute on, they may again.
	Bark.moment_times["marlo/hello"] = Bark.now() - Bark.MOMENT_COOLDOWN - 0.1
	ok = ok and Bark.cooled(&"marlo", &"hello") and not again.say(&"hello", &"marlo").is_empty()
	# Ordinary events have no cooldown.
	ok = ok and not b.say(&"gate_passed", &"marlo").is_empty() and not b.say(&"gate_passed", &"marlo").is_empty()
	again.free()
	b.free()
	Bark.moment_times.clear()
	return ok
