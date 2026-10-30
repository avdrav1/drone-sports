extends RefCounted
# Story 7.6: story consequences. Each death in the CHARACTERS.md table changes
# the game: no spotter, a closed and dearer shop, locked factions. The board
# drops a locked faction's jobs, closes a job whose crew is dead, and keeps a
# memorial line for every death.

const Sim = preload("res://tests/sim.gd")
const BOARD := "res://scenes/ui/job_board.tscn"

func _board() -> JobBoard:
	var b: JobBoard = load(BOARD).instantiate()
	Sim.add(b)
	return b

func test_consequences_are_data_on_the_cast() -> bool:
	var tags := {}
	for id in Roster.ids():
		var c: Character = Roster.character(id)
		if c.death_consequence != &"":
			tags[c.death_consequence] = id
	var none_yet := true
	for tag in tags:
		none_yet = none_yet and not Consequences.in_effect(tag)
	return tags.size() == 4 and none_yet and Consequences.price_factor() == 1.0 \
		and Consequences.shop_closed_jobs() == 0

func test_sanjaya_dead_no_gate_callouts_or_split_delta() -> bool:
	var hud := RaceHud.new()
	hud.split_delta = -0.4
	var before := hud.split_visible()
	var scene: Node = load("res://scenes/jobs/test_race.tscn").instantiate()
	var runner: JobRunner = scene.get_node("JobRunner")
	runner.pays_out = false
	Sim.add(scene)
	await Sim.process_frames(3)
	var bark: Bark = scene.get_node("Bark")
	var heard := []
	bark.spoke.connect(func(id, e, _t): heard.append([id, e]))
	var course: Course = scene.get_node("Course")
	var gate := func() -> int:
		heard.clear()
		bark._since_gate = INF
		course.gate_passed.emit(scene.get_node("Drone"), 1)
		return heard.filter(func(h): return h[1] == &"gate_passed").size()
	var alive_calls: int = gate.call()  # control: Sanjaya alive calls the gate
	Roster.kill(&"sanjaya")
	var after := hud.split_visible()
	hud.free()
	# A living character who would call gates stays silent too: no spotter, no callout.
	var nala: Character = Roster.character(&"nala")
	var speaks: Array[StringName] = nala.speaks_on.duplicate()
	var lines := Bark.lines_of(&"nala").duplicate()
	var stand_in := lines.duplicate()
	stand_in["gate_passed"] = {"active": ["Gate."]}
	nala.speaks_on.append(&"gate_passed")
	Bark._cache[&"nala"] = stand_in
	var stand_in_can := not Bark.pool(&"nala", &"gate_passed").is_empty()
	var dead_calls: int = gate.call()
	nala.speaks_on = speaks
	Bark._cache[&"nala"] = lines
	scene.free()
	return before and not after and Consequences.in_effect(&"no_spotter") \
		and alive_calls == 1 and stand_in_can and dead_calls == 0

func test_nala_dead_closes_shop_for_three_jobs_then_dearer() -> bool:
	# The list price: Nala's discount ends with Nala (Story 19.5).
	var stock: int = Garage.upgrade(&"thrust").prices[0]
	var discounted := Garage.price(&"thrust") < stock
	Wallet.balance = 100000
	Roster.kill(&"nala")
	var closed := Consequences.shop_closed_jobs() == 3 and not Garage.can_buy(&"thrust") \
		and not Garage.buy(&"thrust") and Garage.level(&"thrust") == 0 and Wallet.balance == 100000
	var b := _board()
	await Sim.process_frames(1)
	var button: Button = b.menu_button(&"Garage")
	var shown := button.disabled and button.text.contains("3 more jobs") and button.tooltip_text.contains("Nala")
	b.free()
	Roster.job_done()
	Roster.job_done()
	var still := Consequences.shop_closed_jobs() == 1 and not Garage.buy(&"thrust")
	Roster.job_done()
	var dearer := Garage.price(&"thrust") == ceili(stock * 1.25) and Garage.price(&"thrust") > stock
	var bought := Garage.buy(&"thrust") and Wallet.balance == 100000 - ceili(stock * 1.25)
	b = _board()
	await Sim.process_frames(1)
	button = b.menu_button(&"Garage")
	var open := not button.disabled and button.text == "GARAGE"
	b.free()
	Wallet.balance = 0
	return discounted and closed and shown and still and dearer and bought and open

func test_nalas_own_job_does_not_count_toward_reopening() -> bool:
	Roster.kill(&"nala")
	Roster.job_done([&"nala"])
	var counted_after := Consequences.shop_closed_jobs() == 3
	Roster.job_done()
	SaveGame.load_all(Sim.tree())
	return counted_after and Roster.jobs_since_death(&"nala") == 1 and Consequences.shop_closed_jobs() == 2

func test_bhima_dead_locks_salvage() -> bool:
	Reputation.add(&"salvage", 100)
	Career.team_id = &"harbor_couriers"
	Roster.kill(&"bhima")
	var offers := Career.check_offers()
	var salvage_offer := offers.any(func(t): return t.faction == &"salvage")
	var b := _board()
	await Sim.process_frames(1)
	var listed: bool = b.job_rows.has(&"demolition")
	var city: bool = b.job_rows.has(&"inspection")
	b.free()
	Career.team_id = &""
	return Consequences.faction_locked(&"salvage") and not Consequences.faction_locked(&"city") \
		and not salvage_offer and not listed and city \
		and not Career.can_fly(load("res://data/jobs/demolition.tres"))

func test_sushena_dead_locks_city_services() -> bool:
	Reputation.add(&"city", 100)
	Roster.kill(&"sushena")
	var offers := Career.check_offers()
	var b := _board()
	await Sim.process_frames(1)
	var gone := true
	for id in [&"sample_delivery", &"inspection", &"rescue"]:
		gone = gone and not b.job_rows.has(id)
	var others: bool = b.job_rows.has(&"test_race") and b.job_rows.has(&"demolition")
	b.free()
	return Consequences.faction_locked(&"city") and offers.all(func(t): return t.faction != &"city") \
		and gone and others

func test_pending_offer_from_locked_faction_is_withdrawn() -> bool:
	Reputation.add(&"city", 10)
	var made := Career.check_offers()
	var asked := Career.pending.has(&"harbor_couriers")
	Roster.kill(&"sushena")
	Career.check_offers()
	return made.size() == 1 and asked and Career.pending.is_empty()

func test_pilot_on_a_locked_team_flies_home_jobs_and_can_move_on() -> bool:
	Career.team_id = &"cannery_row"
	var race: Job = load("res://data/jobs/test_race.tres")
	var before := Career.can_fly(race)
	Roster.kill(&"bhima")
	Reputation.add(&"city", 100)
	var after := Career.can_fly(race)
	var rescue_air := Career.wants(Career.teams.by_id(&"city_rescue_air"))
	var deadweight := Career.wants(Career.teams.by_id(&"deadweight"))
	var kept := Career.preset().label == "Act 3"
	Career.team_id = &""
	return not before and after and kept and rescue_air and not deadweight

func test_job_needs_its_living_crew() -> bool:
	var drill: Job = load("res://data/jobs/spotter_drill.tres")
	var scene: Node = load(drill.scene).instantiate()
	var runs_it: bool = (scene.get_node("JobRunner") as JobRunner).job == drill
	scene.free()
	var listed := false
	for j in (load("res://data/jobs/board.tres") as JobList).jobs:
		listed = listed or j == drill
	Career.team_id = &"skyline_juniors"
	var b := _board()
	await Sim.process_frames(1)
	var flies := b.fly_button(&"spotter_drill") != null
	b.free()
	Roster.kill(&"sanjaya")
	b = _board()
	await Sim.process_frames(1)
	var row: Node = b.job_rows.get(&"spotter_drill")
	var closed: bool = row != null and b.fly_button(&"spotter_drill") == null \
		and b.lock_label(&"spotter_drill").text.contains("Sanjaya")
	b.fly(drill)
	await Sim.process_frames(1)
	var stayed: bool = Sim.tree().current_scene == null or Sim.tree().current_scene.scene_file_path != drill.scene
	b.free()
	Career.team_id = &""
	return listed and runs_it and drill.requires_living == [&"sanjaya"] and flies and closed and stayed \
		and not Career.can_fly(drill) and ResourceLoader.exists(drill.scene)

func test_memorial_line_per_dead_character() -> bool:
	var dead := [&"sanjaya", &"nala", &"bhima", &"sushena"]
	for id in dead:
		Roster.kill(id)
	var b := _board()
	await Sim.process_frames(1)
	var ok := true
	for id in dead:
		var line := Bark.memorial(id)
		var text: String = (b.crew_rows[id].get_node("Info/Status") as Label).text
		ok = ok and not line.is_empty() and text.contains("Died.") and text.contains(line)
	ok = ok and not (b.crew_rows[&"drona"].get_node("Info/Status") as Label).text.contains("Died.")
	b.free()
	return ok

func test_locked_job_cannot_be_retried_from_results() -> bool:
	var screen: Control = load("res://scenes/ui/results.tscn").instantiate()
	Sim.add(screen)
	var r := JobResult.new()
	r.job = load("res://data/jobs/demolition.tres")
	r.completed = true
	r.letter = "B"
	screen.show_result(r)
	var open_before: bool = not screen.retry_button.disabled
	var fired := []
	screen.retry_pressed.connect(func(): fired.append(true))
	Roster.kill(&"bhima")
	screen.show_result(r)
	var closed: bool = screen.retry_button.disabled
	screen.retry()
	var drill := JobResult.new()
	drill.job = load("res://data/jobs/spotter_drill.tres")
	drill.letter = "C"
	var drill_open: bool = Consequences.missing_crew(drill.job).is_empty()
	Roster.kill(&"sanjaya")
	screen.show_result(drill)
	var drill_closed: bool = screen.retry_button.disabled
	screen.free()
	return open_before and closed and fired.is_empty() and drill_open and drill_closed
