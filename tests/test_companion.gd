extends RefCounted
# Story 17.10: free-flight companion. The first living companion greets within
# 3 s of spawn; after 45 s of radio quiet a suggestion plays and lights its
# target on the radar; reaching it gets a reaction and puts the light out. No
# suggestion in a job or under the title, never the same one twice in a row, and
# nothing graded or saved.

const Sim = preload("res://tests/sim.gd")
const SANDBOX := "res://scenes/debug_flight.tscn"
const LIST := preload("res://data/radio/suggestions.tres")

func _fresh() -> void:
	SaveGame.write_section("roster", {})
	Roster.load_saved()

## A light free-flight rig: a drone on the sandbox map, a pad and a jammer
## marker, a Bark, and a Companion. Returns the root; the companion is "Companion".
func _rig(seed := 1) -> Node3D:
	var root := Node3D.new()
	var d := Sim.drone(Sim.intent(-1.0), Vector3(150, 40, 150))
	d.gravity_scale = 0.0
	d.reparent(root)
	d.name = "Drone"
	for k in [[&"pad", Vector3(60, 20, 0)], [&"jammer", Vector3(-120, 0, 90)]]:
		var m := MapMarker.new()
		m.kind = k[0]
		m.position = k[1]
		root.add_child(m)
	var gps := Gps.new()
	gps.name = "Gps"
	gps.map = load("res://data/maps/sandbox.tres")
	gps.drone = d
	root.add_child(gps)
	var bark := Bark.new()
	bark.name = "Bark"
	bark.seed = seed
	root.add_child(bark)
	var c := Companion.new()
	c.name = "Companion"
	c.bark = bark
	c.gps = gps
	c.seed = seed
	root.add_child(c)
	Sim.add(root)
	return root

## Every line on the radio, logged as it goes out.
func _log(bark: Bark) -> Array:
	var heard := []
	bark.said.connect(func(l): heard.append(l))
	return heard

func _first_greeting(dead: Array[StringName]) -> Dictionary:
	_fresh()
	for id in dead:
		Roster.kill(id)
	var s: Node = load(SANDBOX).instantiate()
	var heard := []
	(s.get_node("Bark") as Bark).said.connect(func(l): heard.append(l))
	Sim.add(s)
	var frames := 0
	while heard.is_empty() and frames < 200:
		await Sim.process_frames(1)
		frames += 1
	var greet: Dictionary = heard.filter(func(l): return l.event == &"free_greet").front() if heard.any(func(l): return l.event == &"free_greet") else {}
	var box: BarkBox = s.get_node("HUD/BarkBox")
	await Sim.process_frames(2)
	var shown: bool = not greet.is_empty() and box.current.get("text") == greet.text
	s.free()
	_fresh()
	return {"greet": greet, "seconds": frames / 60.0, "shown": shown}

func test_free_flight_greets_with_first_living_companion() -> bool:
	var r: Dictionary = await _first_greeting([])
	var first: StringName = LIST.companions[0]
	return not r.greet.is_empty() and r.greet.id == first and r.seconds <= 3.0 and r.shown \
		and r.greet.text in Bark.pool(first, &"free_greet")

func test_next_companion_greets_when_first_is_dead() -> bool:
	var r: Dictionary = await _first_greeting([LIST.companions[0]])
	return not r.greet.is_empty() and r.greet.id == LIST.companions[1] and r.seconds <= 3.0

func test_suggestion_after_45_quiet_seconds_lights_the_radar() -> bool:
	_fresh()
	var root := _rig()
	var c: Companion = root.get_node("Companion")
	var heard := _log(root.get_node("Bark"))
	# Through the greeting and 44 quiet seconds: nothing yet.
	await Sim.process_frames(roundi((c.greet_after + 44.0) * 60.0))
	var early: bool = heard.size() == 1 and heard[0].event == &"free_greet" and c.target == null
	await Sim.process_frames(90)
	var s: Array = heard.filter(func(l): return l.event == &"suggest")
	var ok: bool = early and s.size() == 1 and c.target != null and c.target.highlighted \
		and LIST.suggestions.any(func(x): return x.text == s[0].text)
	# The radar shows it lit.
	var radar := Radar.new()
	radar.gps = root.get_node("Gps")
	root.add_child(radar)
	ok = ok and radar.blips().any(func(b): return b.lit and b.marker == c.target)
	root.free()
	return ok

func test_no_suggestion_in_the_first_ten_seconds() -> bool:
	_fresh()
	var root := _rig()
	var c: Companion = root.get_node("Companion")
	c.quiet_gap = 2.0
	var heard := _log(root.get_node("Bark"))
	await Sim.process_frames(9 * 60)
	var early: bool = not heard.any(func(l): return l.event == &"suggest")
	await Sim.process_frames(90)
	var ok: bool = early and heard.any(func(l): return l.event == &"suggest")
	root.free()
	return ok

func test_reaching_the_target_reacts_and_clears() -> bool:
	_fresh()
	var root := _rig()
	var c: Companion = root.get_node("Companion")
	var heard := _log(root.get_node("Bark"))
	await Sim.process_frames(3)
	c.age = 20.0
	var ok := c.suggest()
	var lit := c.target
	ok = ok and lit != null and lit.highlighted
	(root.get_node("Drone") as Drone).global_position = lit.global_position + Vector3(0, 2, 0)
	await Sim.process_frames(3)
	var arrive: Array = heard.filter(func(l): return l.event == &"free_arrive")
	ok = ok and arrive.size() == 1 and arrive[0].id == c.id and c.target == null \
		and (not is_instance_valid(lit) or not lit.highlighted)
	root.free()
	return ok

func test_every_reached_target_reacts_past_the_line_pool() -> bool:
	_fresh()
	var root := _rig(3)
	var c: Companion = root.get_node("Companion")
	var heard := _log(root.get_node("Bark"))
	await Sim.process_frames(3)
	c.age = 20.0
	var n: int = Bark.pool(c.id, &"free_arrive").size() * 2 + 1
	var ok := n > 3
	for i in n:
		ok = ok and c.suggest()
		(root.get_node("Drone") as Drone).global_position = c.target.global_position + Vector3(0, 2, 0)
		await Sim.process_frames(2)
	var arrive: Array = heard.filter(func(l): return l.event == &"free_arrive")
	ok = ok and arrive.size() == n
	for i in range(1, arrive.size()):
		ok = ok and arrive[i].text != arrive[i - 1].text
	root.free()
	return ok

func test_flight_reactions_keep_coming_past_the_line_pool() -> bool:
	_fresh()
	var root := _rig(4)
	var c: Companion = root.get_node("Companion")
	var heard := _log(root.get_node("Bark"))
	await Sim.process_frames(3)
	var ok := true
	for event in [&"near_miss", &"crash"]:
		var n: int = Bark.pool(c.id, event).size() * 2 + 1
		ok = ok and n > 3
		for i in n:
			c._on_flight_event(event)
		var got: Array = heard.filter(func(l): return l.event == event)
		ok = ok and got.size() == n
		for i in range(1, got.size()):
			ok = ok and got[i].text != got[i - 1].text
	root.free()
	return ok

func test_next_suggestion_moves_the_light_and_never_repeats() -> bool:
	_fresh()
	var root := _rig(5)
	var c: Companion = root.get_node("Companion")
	var heard := _log(root.get_node("Bark"))
	await Sim.process_frames(3)
	var ok := true
	var last := ""
	var lit: Array = []
	for i in 12:
		ok = ok and c.suggest()
		var text: String = heard.back().text
		ok = ok and text != last and c.target.highlighted
		for m in lit:
			ok = ok and (not is_instance_valid(m) or m == c.target or not m.highlighted)
		lit.append(c.target)
		last = text
		await Sim.process_frames(1)
	root.free()
	return ok

func test_no_suggestion_during_a_job() -> bool:
	_fresh()
	var job := Job.new()
	var root := Sim.job_setup(job)
	var bark := Bark.new()
	root.add_child(bark)
	var c := Companion.new()
	c.bark = bark
	root.add_child(c)
	var heard := _log(bark)
	c.quiet_gap = 1.0
	c.first_suggestion = 0.0
	await Sim.process_frames(180)
	var ok: bool = c.silenced() and heard.is_empty()
	root.free()
	# And no job scene carries a companion.
	for f in DirAccess.get_files_at("res://scenes/jobs"):
		if f.ends_with(".tscn"):
			var s: Node = load("res://scenes/jobs/" + f).instantiate()
			ok = ok and s.find_children("*", "Node", true, false).all(func(n): return not n is Companion)
			s.free()
	return ok

func test_silent_under_the_title() -> bool:
	_fresh()
	var title: Node = load("res://scenes/ui/title.tscn").instantiate()
	Sim.add(title)
	await Sim.process_frames(4 * 60)
	var player: CutscenePlayer = title.get_node("Backdrop")
	var c: Companion = player.backdrop.get_node("Companion")
	var ok: bool = c.silenced() and not c.greeted and c.target == null
	title.free()
	return ok

func test_nothing_saved_from_free_flight() -> bool:
	_fresh()
	var before := JSON.stringify(SaveGame.read())
	var wallet := Wallet.balance if "balance" in Wallet else 0
	var root := _rig()
	var c: Companion = root.get_node("Companion")
	await Sim.process_frames(3 * 60)
	c.age = 20.0
	c.suggest()
	(root.get_node("Drone") as Drone).global_position = c.target.global_position
	await Sim.process_frames(3)
	root.free()
	return JSON.stringify(SaveGame.read()) == before and (Wallet.balance if "balance" in Wallet else 0) == wallet

## Free flight opens with the controls panel up and the companion greets within
## seconds, so the radio has to draw above the panel or the greeting is cut off.
func test_radio_draws_above_the_controls_panel() -> bool:
	var s: Node = Sim.add(load(SANDBOX).instantiate())
	var hud: CanvasLayer = s.get_node("HUD")
	var ok: bool = s.get_node("HUD/Help").visible \
		and hud.get_node("BarkBox").get_index() > hud.get_node("Help").get_index()
	s.free()
	return ok
