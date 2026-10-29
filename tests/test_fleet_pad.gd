extends RefCounted
# Story 23.4: fleet command on the pad. RB / LB walk the fleet both ways and
# wrap, A drops in and back out, X sends a relay leg or tags a Lattice unit.
# A mouse click still selects.

const Sim = preload("res://tests/sim.gd")
const VIEW := preload("res://scenes/fleet/command_view.tscn")
const RIG := preload("res://scenes/camera/camera_rig.tscn")

## Three fleet drones at 10 m over a floor, a camera rig, and the command view.
func _fleet() -> CommandView:
	var root: Node3D = Sim.add(Node3D.new())
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	floor.add_child(shape)
	floor.position = Vector3(0, -0.5, 0)
	root.add_child(floor)
	var drones: Array[Drone] = []
	for i in 3:
		var d: Drone = Sim.DRONE.instantiate()
		d.name = "Fleet%d" % (i + 1)
		var auto := Autopilot.new()
		d.add_child(auto)
		d.intent_source = auto
		root.add_child(d)
		d.global_position = Vector3(-8 + i * 8, 10, 0)
		auto.go_to(PackedVector3Array([d.global_position]))
		drones.append(d)
	var rig: CameraRig = RIG.instantiate()
	root.add_child(rig)
	var view: CommandView = VIEW.instantiate()
	view.drones = drones
	view.camera_rig = rig
	root.add_child(view)
	return view

## Presses and releases a pad button, as pad 0.
func _button(node: Node, index: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = index
	ev.pressed = true
	node.get_viewport().push_input(ev)
	var up := ev.duplicate()
	up.pressed = false
	node.get_viewport().push_input(up)

func _job(path: String) -> Node:
	var s: Node = load(path).instantiate()
	var runner: JobRunner = s.get_node("JobRunner")
	runner.pays_out = false
	runner.results_scene = null
	runner.back_scene = ""
	runner.confirm_risk = false
	Sim.add(s)
	return s

func _live(s: Node) -> void:
	var runner: JobRunner = s.get_node("JobRunner")
	await Sim.process_frames(2)
	runner.launch(true)
	while runner.state != JobRunner.State.LIVE:
		await Sim.physics_frames(1)

func test_shoulders_walk_the_fleet_both_ways_and_wrap() -> bool:
	var view := _fleet()
	await Sim.physics_frames(2)
	var seen: Array[Drone] = [view.selected]
	for i in 3:
		_button(view, JOY_BUTTON_RIGHT_SHOULDER)
		seen.append(view.selected)
	for i in 3:
		_button(view, JOY_BUTTON_LEFT_SHOULDER)
		seen.append(view.selected)
	InputPrompt.use_keys()
	var d := view.drones
	var want: Array[Drone] = [d[0], d[1], d[2], d[0], d[2], d[1], d[0]]
	view.get_parent().free()
	if seen != want:
		print("        selected %s" % [seen.map(func(x): return x.name)])
	return seen == want

func test_shift_tab_selects_the_previous_drone() -> bool:
	var view := _fleet()
	await Sim.physics_frames(2)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_TAB
	ev.shift_pressed = true
	ev.pressed = true
	view.get_viewport().push_input(ev)
	var last := view.selected == view.drones[2]
	view.get_parent().free()
	return last

func test_a_drops_in_and_back_out() -> bool:
	var view := _fleet()
	await Sim.physics_frames(2)
	_button(view, JOY_BUTTON_RIGHT_SHOULDER)
	var d := view.drones[1]
	_button(view, JOY_BUTTON_A)
	var flying: bool = view.flown == d and d.intent_source is PilotInput
	# Shoulders do nothing while flying: the pad's sticks are the drone's.
	_button(view, JOY_BUTTON_RIGHT_SHOULDER)
	var kept := view.selected == d
	_button(view, JOY_BUTTON_A)
	InputPrompt.use_keys()
	var back: bool = view.flown == null and d.intent_source == Autopilot.of(d) and view.camera.current
	view.get_parent().free()
	return flying and kept and back

func test_mouse_click_still_selects() -> bool:
	var view := _fleet()
	await Sim.physics_frames(3)
	var target := view.drones[2]
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = view.camera.unproject_position(target.global_position)
	view.get_viewport().push_input(ev)
	var picked := view.selected == target
	view.get_parent().free()
	return picked

func test_x_sends_a_relay_leg() -> bool:
	var s := _job("res://scenes/jobs/fleet_race.tscn")
	var relay: Relay = s.get_node("Relay")
	await _live(s)
	var view := relay.command
	_button(s, JOY_BUTTON_RIGHT_SHOULDER)
	var d := view.selected
	_button(s, JOY_BUTTON_X)
	InputPrompt.use_keys()
	var auto := Autopilot.of(d)
	# 22.2: on the open path X sends the drone along its own leg.
	var route := relay.lap_route(d) if relay.course.is_closed() else relay.leg_route(relay.drones.find(d))
	var sent: bool = d == relay.drones[1] and not auto.done() and auto.waypoints.size() == route.size() \
		and auto.waypoints[-1].distance_to(route[-1]) < 0.5
	s.free()
	return sent

func test_x_tags_a_lattice_unit() -> bool:
	var s := _job("res://scenes/boss/lattice_job.tscn")
	var fight: LatticeFight = s.get_node("Fight")
	await _live(s)
	var view: CommandView = s.get_node("CommandView")
	_button(s, JOY_BUTTON_LEFT_SHOULDER)
	var d := view.selected
	var target := fight.next_target()
	_button(s, JOY_BUTTON_X)
	InputPrompt.use_keys()
	var tagged: bool = d == view.drones[-1] and target >= 0 and fight.assigned.get(d, -1) == target
	s.free()
	return tagged
