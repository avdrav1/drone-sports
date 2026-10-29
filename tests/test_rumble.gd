extends RefCounted
# Story 23.7: rumble. A hit (harder shakes more), a gate, a hazard warning and
# strike, and a job's end each ask the pad in hand for one vibration with the
# listed strength and length. Nothing is asked with rumble off or after a key
# press, and a job plays out the same either way.

const Sim = preload("res://tests/sim.gd")
const TEST_COURSE := "res://data/courses/test_loop.tres"

func _pad() -> void:
	GameSettings.rumble = true
	InputPrompt.use_pad(0, "Xbox Controller")
	Rumble.clear_log()

func _done() -> void:
	GameSettings.rumble = true
	InputPrompt.use_keys()
	Rumble.clear_log()

## A job rig that neither pays out nor shows results.
func _setup(job: Job) -> Array:
	var root := Sim.job_setup(job)
	var runner: JobRunner = root.get_node("Runner")
	runner.pays_out = false
	runner.results_scene = null
	return [root, runner]

func test_each_event_asks_once_with_its_strength_and_length() -> bool:
	_pad()
	var ok := true
	for id in Rumble.EVENTS:
		Rumble.clear_log()
		ok = ok and Rumble.play(id) and Rumble.log.size() == 1
		var e: Dictionary = Rumble.last()
		ok = ok and e.id == id and e.device == 0 and is_equal_approx(e.weak, Rumble.EVENTS[id][0]) \
			and is_equal_approx(e.strong, Rumble.EVENTS[id][1]) and is_equal_approx(e.duration, Rumble.EVENTS[id][2])
	# A gate is a short tick next to a strike.
	ok = ok and Rumble.EVENTS[&"gate"][2] < 0.1 and Rumble.EVENTS[&"gate"][0] < Rumble.EVENTS[&"strike"][0]
	_done()
	return ok

func test_a_harder_hit_asks_for_more() -> bool:
	_pad()
	var ok := not Rumble.hit(0.5) and Rumble.log.is_empty()
	Rumble.hit(2.0)
	var soft: Dictionary = Rumble.last()
	Rumble.hit(6.0)
	var hard: Dictionary = Rumble.last()
	Rumble.hit(30.0)
	var hardest: Dictionary = Rumble.last()
	ok = ok and Rumble.count(&"hit") == 3 and soft.strong < hard.strong and soft.weak < hard.weak \
		and soft.duration < hard.duration and hard.strong < hardest.strong \
		and is_equal_approx(hardest.strong, Rumble.EVENTS[&"hit"][1])
	_done()
	return ok

func test_nothing_with_rumble_off_or_after_a_key() -> bool:
	_pad()
	GameSettings.rumble = false
	var ok := not Rumble.play(&"strike") and not Rumble.hit(10.0) and Rumble.log.is_empty()
	GameSettings.rumble = true
	# A key press puts the keyboard in hand: no more requests.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SHIFT
	key.pressed = true
	Input.parse_input_event(key)
	var up := key.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await Sim.process_frames(2)
	ok = ok and not InputPrompt.pad and not Rumble.play(&"gate") and Rumble.log.is_empty()
	# A pad button puts the pad back in hand.
	var b := InputEventJoypadButton.new()
	b.device = 0
	b.button_index = JOY_BUTTON_RIGHT_STICK
	b.pressed = true
	Input.parse_input_event(b)
	var b_up := b.duplicate()
	b_up.pressed = false
	Input.parse_input_event(b_up)
	await Sim.process_frames(2)
	ok = ok and Rumble.play(&"gate") and Rumble.count(&"gate") == 1
	_done()
	return ok

func test_the_flown_drones_hits_shake_the_pad() -> bool:
	_pad()
	var d := Sim.drone(Sim.intent(), Vector3(0, 30, 0))
	var other := Sim.drone(Sim.intent(), Vector3(20, 30, 0))
	var rig: CameraRig = load("res://scenes/camera/camera_rig.tscn").instantiate()
	rig.target = d
	Sim.add(rig)
	await Sim.physics_frames(2)
	Rumble.clear_log()
	var sound: DroneSound = d.get_node("Sound")
	sound.impact(3.0)
	await Sim.physics_frames(2)
	sound.impact(7.0)
	await Sim.physics_frames(2)
	# Someone else's drone hitting something is not felt.
	other.get_node("Sound").impact(7.0)
	await Sim.physics_frames(2)
	var ok: bool = Rumble.count(&"hit") == 2 and Rumble.log[0].strong < Rumble.log[1].strong
	# A real crash: the flown drone dropped onto the ground.
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(20, 1, 20)
	floor.add_child(shape)
	Sim.add(floor)
	floor.global_position = Vector3(0, 0, 0)
	d.global_position = Vector3(0, 6, 0)
	d.linear_velocity = Vector3(0, -12, 0)
	d.intent_source.value = Sim.intent(-1.0)
	Rumble.clear_log()
	for i in 60:
		await Sim.physics_frames(1)
		if Rumble.count(&"hit") > 0:
			break
	ok = ok and Rumble.count(&"hit") >= 1
	if not ok:
		print("        hits: ", Rumble.log, " impacts ", sound.impacts)
	for n in [rig, d, other, floor]:
		n.free()
	_done()
	return ok

func test_gates_hazards_and_the_end_shake_the_pad() -> bool:
	_pad()
	var job := Job.new()
	job.crew_in_field = [&"sanjaya"]
	var s := _setup(job)
	var root: Node = s[0]
	var runner: JobRunner = s[1]
	var zone := HazardZone.new()
	zone.character = &"sanjaya"
	root.add_child(zone)
	zone.global_position = Vector3(0, 5, -60)
	var course := Course.new()
	course.data = load(TEST_COURSE)
	root.add_child(course)
	await Sim.go_live(root)
	var d: Drone = runner.drone
	d.freeze = true
	course.add_racer(d)
	course.start()
	await Sim.physics_frames(30)
	Rumble.clear_log()
	for i in [0, 1, 2]:
		var g: Gate = course.gates[i]
		for p in [Vector3(0, 20, 1.5), Vector3(0, 0, 1.5), Vector3(0, 0, -1.5)]:
			d.global_position = g.global_transform * p
			await Sim.physics_frames(1)
	var gates := Rumble.count(&"gate")
	for i in 70:
		zone.threaten()
		await Sim.physics_frames(1)
	zone.threaten()
	zone.strike(&"test")
	await Sim.physics_frames(2)
	runner.complete()
	var ok: bool = gates == 3 and Rumble.count(&"warning") == 1 and Rumble.count(&"strike") == 1 \
		and Rumble.count(&"complete") == 1 and Rumble.count(&"failed") == 0
	if not ok:
		print("        ", Rumble.log.map(func(l): return l.id))
	root.free()
	# A failed job ends on its own shake.
	s = _setup(Job.new())
	await Sim.go_live(s[0])
	Rumble.clear_log()
	s[1].fail("test")
	ok = ok and Rumble.count(&"failed") == 1 and Rumble.log.size() == 1
	s[0].free()
	_done()
	return ok

func test_play_is_the_same_without_rumble() -> bool:
	var runs := []
	for on in [true, false]:
		_pad()
		GameSettings.rumble = on
		var s := _setup(Job.new())
		var states := []
		s[1].state_changed.connect(func(st, _p): states.append(st))
		await Sim.go_live(s[0])
		s[1].complete()
		runs.append(states)
		s[0].free()
	var ok: bool = runs[0] == runs[1] and Rumble.log.is_empty()
	_done()
	return ok
