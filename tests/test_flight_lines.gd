extends RefCounted
# Story 17.9: flight lines. The flight events are bark events, every line for
# them makes a face, speaks_on decides who reacts from afar, and on a job with
# Marlo on comms a near miss puts Marlo on the radio, unless Marlo is dead.

const Sim = preload("res://tests/sim.gd")

func _fresh() -> void:
	SaveGame.write_section("roster", {})
	Roster.load_saved()

func test_flight_events_are_bark_events() -> bool:
	return FlightEvents.EVENTS.all(func(e): return e in Bark.EVENTS)

func test_every_new_line_has_a_valid_face() -> bool:
	var ok := true
	for id in Roster.ids():
		var lines := Bark.lines_of(id)
		for e in FlightEvents.EVENTS:
			var entry: Dictionary = lines.get(String(e), {})
			for line in entry.get("active", []) + entry.get("injured", []):
				var good: bool = line is Dictionary and Bark.text_of(line) != "" \
					and StringName(str(line.get("face", ""))) in CharacterPortrait.EXPRESSIONS
				if not good:
					print("        %s %s: %s" % [id, e, line])
				ok = ok and good
	return ok

func test_speaks_on_decides_who_reacts() -> bool:
	var marlo: Character = Roster.character(&"marlo")
	var dot: Character = Roster.character(&"dot")
	var rin: Character = Roster.character(&"rin")
	# Off the job, nobody is in the field: only speaks_on reacts.
	var b := Bark.new()
	var near := b.speakers(&"near_miss")
	var crash := b.speakers(&"crash")
	var fast := b.speakers(&"top_speed")
	b.free()
	return &"near_miss" in marlo.speaks_on and &"crash" in dot.speaks_on and &"battery_low" in dot.speaks_on \
		and &"top_speed" in rin.speaks_on and near == [&"marlo"] and crash == [&"dot"] and fast == [&"rin"]

## The inspection job (Marlo in the field) gone live, its drone coasting past a
## wall high above the site so the watcher sees a near miss. Returns the radio's
## lines from the near miss on, and what the panel showed.
func _near_miss_on_inspection() -> Dictionary:
	var scene: Node = load("res://scenes/jobs/inspection.tscn").instantiate()
	var runner: JobRunner = scene.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.confirm_risk = false
	Sim.add(scene)
	await Sim.process_frames(2)
	runner.launch(true)
	while runner.state == JobRunner.State.COUNTDOWN:
		await Sim.physics_frames(1)
	var box: BarkBox = scene.get_node("HUD/BarkBox")
	# The jump up to the wall can read as a takeoff; keep its chatter from
	# holding the near miss back (the gap itself is Story 17.7's test).
	box.chatter_gap = 0.0
	var bark: Bark = scene.get_node("Bark")
	var d: Drone = scene.get_node("Drone")
	# Coasting: no pilot, motors off, no gravity or drag.
	d.intent_source = null
	d.motor_thrusts = PackedFloat32Array([0, 0, 0, 0])
	d.gravity_scale = 0.0
	d.drag = 0.0
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(2, 20, 4)
	wall.add_child(shape)
	scene.add_child(wall)
	wall.global_position = Vector3(-1, 300, 0)
	await Sim.physics_frames(2)
	d.global_transform = Transform3D(Basis(), Vector3(1.6, 300, -8))
	d.linear_velocity = Vector3(0, 0, 9)
	d.angular_velocity = Vector3.ZERO
	var heard := []
	bark.said.connect(func(l): heard.append(l))
	var shown := []
	for i in 180:
		await Sim.physics_frames(1)
		if box.showing() and not box.current in shown:
			shown.append(box.current)
	scene.free()
	return {"heard": heard, "shown": shown}

func test_marlo_calls_a_near_miss_on_the_radio() -> bool:
	_fresh()
	var r: Dictionary = await _near_miss_on_inspection()
	var near: Array = r.heard.filter(func(l): return l.event == &"near_miss")
	var ok: bool = near.size() == 1 and near[0].id == &"marlo" and near[0] in r.shown \
		and near[0].text in Bark.pool(&"marlo", &"near_miss")
	if not ok:
		print("        heard %s, shown %s" % [r.heard, r.shown])
	return ok

func test_dead_marlo_calls_no_near_miss() -> bool:
	_fresh()
	Roster.kill(&"marlo")
	var r: Dictionary = await _near_miss_on_inspection()
	var ok: bool = not r.heard.any(func(l): return l.id == &"marlo") \
		and not r.shown.any(func(l): return l.id == &"marlo")
	_fresh()
	return ok
