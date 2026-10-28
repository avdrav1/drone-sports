extends RefCounted
# Story 6.2: command view. Click to select, click to queue, drop in and back out.

const Sim = preload("res://tests/sim.gd")
const VIEW := preload("res://scenes/fleet/command_view.tscn")
const RIG := preload("res://scenes/camera/camera_rig.tscn")

## A floor, three fleet drones at 10 m, a camera rig, and the command view.
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
	rig.name = "Rig"
	root.add_child(rig)
	var view: CommandView = VIEW.instantiate()
	view.drones = drones
	view.camera_rig = rig
	root.add_child(view)
	return view

func _click(view: CommandView, world: Vector3) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = view.camera.unproject_position(world)
	view.get_viewport().push_input(ev)

func _key(view: CommandView, action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	view.get_viewport().push_input(ev)

func test_click_selects_then_click_ground_queues() -> bool:
	var view := _fleet()
	await Sim.physics_frames(3)
	var target := view.drones[2]
	_click(view, target.global_position)
	var picked := view.selected == target
	var queued := []
	view.waypoint_queued.connect(func(d, p): queued.append([d, p]))
	var ground := Vector3(14, 0, -18)
	_click(view, ground)
	var auto := Autopilot.of(target)
	var ok: bool = picked and queued.size() == 1 and queued[0][0] == target \
		and auto.waypoints[-1].distance_to(ground + Vector3.UP * view.waypoint_altitude) < 0.5 \
		and Autopilot.of(view.drones[0]).waypoints.size() == 1
	# It flies there under autopilot.
	for k in 60 * 15:
		await Sim.physics_frames(1)
		if auto.done():
			break
	ok = ok and target.global_position.distance_to(auto.waypoints[-1]) < 2.0
	view.get_parent().free()
	return ok

func test_tab_cycles_selection() -> bool:
	var view := _fleet()
	await Sim.physics_frames(2)
	var first := view.selected == view.drones[0]
	_key(view, &"next_drone")
	var second := view.selected == view.drones[1]
	view.get_parent().free()
	return first and second

func test_drop_in_hands_over_and_leaving_resumes_autopilot() -> bool:
	var view := _fleet()
	await Sim.physics_frames(3)
	var d := view.drones[1]
	_click(view, d.global_position)
	var goal := Vector3(0, 10, -16)
	Autopilot.of(d).queue(goal)
	_key(view, &"drop_in")
	var rig := view.camera_rig
	var manual: bool = view.flown == d and d.intent_source is PilotInput and d.intent_source.get_parent() == d \
		and rig.target == d and rig.view == CameraRig.View.FPV and rig.camera.current \
		and d.assists.is_enabled(&"brake") == Career.preset().brake
	# Hands-off sticks: the autopilot is not steering toward the goal.
	await Sim.physics_frames(60)
	var still := d.global_position.distance_to(Vector3(0, 10, 0)) < 2.0
	_key(view, &"drop_in")
	var back: bool = view.flown == null and d.intent_source == Autopilot.of(d) and view.camera.current \
		and not d.assists.is_enabled(&"brake")
	for k in 60 * 12:
		await Sim.physics_frames(1)
		if Autopilot.of(d).done():
			break
	var resumed := d.global_position.distance_to(goal) < 2.0
	view.get_parent().free()
	if not (manual and still and back and resumed):
		print("        manual %s still %s back %s resumed %s" % [manual, still, back, resumed])
	return manual and still and back and resumed
