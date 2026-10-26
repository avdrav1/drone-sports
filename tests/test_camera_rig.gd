extends RefCounted
# Story 1.6: camera rig.

const Sim = preload("res://tests/sim.gd")
const RIG := preload("res://scenes/camera/camera_rig.tscn")

func _rig(target: Node3D) -> CameraRig:
	var rig: CameraRig = RIG.instantiate()
	rig.target = target
	Sim.add(rig)
	return rig

func _press_c(node: Node) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_C
	ev.pressed = true
	node.get_viewport().push_input(ev)
	var up := ev.duplicate()
	up.pressed = false
	node.get_viewport().push_input(up)

func test_cycle_order() -> bool:
	var t := Node3D.new()
	Sim.add(t)
	var rig := _rig(t)
	var seen: Array = [rig.view]
	for i in 4:
		_press_c(rig)
		seen.append(rig.view)
	rig.free()
	t.free()
	var V := CameraRig.View
	return seen == [V.CHASE, V.FPV, V.ORBIT, V.TOP_DOWN, V.CHASE]

# Runs after every other node's _process (rig included) and records the worst alignment.
class FpvProbe extends Node:
	var rig: CameraRig
	var drone: Drone
	var worst := 1.0
	var frames := 0
	func _init() -> void:
		process_priority = 1000
	func _process(_delta: float) -> void:
		frames += 1
		var cam_fwd := -rig.camera.global_transform.basis.z.normalized()
		var drone_fwd := -drone.global_transform.basis.z.normalized()
		worst = minf(worst, cam_fwd.dot(drone_fwd))

func test_fpv_forward_equals_drone_forward_every_frame() -> bool:
	var d := Sim.drone(Sim.intent(0.2, 0.4, 0.3, 0.6), Vector3(0, 20, 0))
	var rig := _rig(d)
	rig.set_view(CameraRig.View.FPV)
	var probe := FpvProbe.new()
	probe.rig = rig
	probe.drone = d
	Sim.add(probe)
	await Sim.process_frames(120)
	var ok := probe.frames >= 119 and probe.worst > 0.99999
	probe.free()
	rig.free()
	d.free()
	return ok

func test_chase_never_ends_frame_inside_wall() -> bool:
	# A wall occupying x < 0. The drone hugs it at x = 0.5, facing away (+X),
	# so the chase goal (behind the drone) is always inside the wall.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(20, 20, 200)
	wall.add_child(shape)
	Sim.add(wall)
	wall.global_position = Vector3(-10, 0, 0)
	var d := Sim.drone(Sim.intent(), Vector3(0.5, 2, 0))
	d.freeze = true
	d.look_at(Vector3(10, 2, 0))
	var rig := _rig(d)
	var space := d.get_world_3d().direct_space_state
	var inside := 0
	for i in 180:
		d.global_position = Vector3(0.5 + 0.3 * sin(i * 0.1), 2.0, -i * 0.15)
		d.rotation.y = -PI / 2 + 0.6 * sin(i * 0.05)
		await Sim.process_frames(1)
		var q := PhysicsPointQueryParameters3D.new()
		q.position = rig.camera.global_position
		q.exclude = [d.get_rid()]
		if not space.intersect_point(q).is_empty():
			inside += 1
	rig.free()
	d.free()
	wall.free()
	return inside == 0

func test_chase_sits_behind_and_above_in_open_space() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(0, 10, 0))
	d.freeze = true
	var rig := _rig(d)
	await Sim.process_frames(30)
	var rel := rig.camera.global_position - d.global_position
	rig.free()
	d.free()
	return rel.z > 2.5 and rel.y > 0.5

func test_orbit_and_top_down_follow() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(5, 10, -5))
	d.freeze = true
	var rig := _rig(d)
	rig.set_view(CameraRig.View.ORBIT)
	rig.orbit_yaw = 1.0
	await Sim.process_frames(2)
	var orbit_dist := rig.camera.global_position.distance_to(d.global_position)
	rig.set_view(CameraRig.View.TOP_DOWN)
	await Sim.process_frames(2)
	var top := rig.camera.global_position - d.global_position
	var looks_down := rig.camera.global_transform.basis.z.y > 0.99
	rig.free()
	d.free()
	return is_equal_approx(orbit_dist, 4.0) and is_equal_approx(top.y, 25.0) \
		and Vector2(top.x, top.z).length() < 0.001 and looks_down

func test_default_view_is_applied() -> bool:
	# The Briefing hook itself waits on JobRunner (Story 2.1); this covers the rig side.
	var t := Node3D.new()
	Sim.add(t)
	var rig: CameraRig = RIG.instantiate()
	rig.target = t
	rig.default_view = CameraRig.View.FPV
	Sim.add(rig)
	var on_ready := rig.view == CameraRig.View.FPV
	rig.cycle()
	rig.use_default_view()
	var restored := rig.view == CameraRig.View.FPV
	rig.free()
	t.free()
	return on_ready and restored

func test_debug_scene_uses_rig() -> bool:
	var scene: Node = Sim.add(load("res://scenes/debug_flight.tscn").instantiate())
	await Sim.process_frames(2)
	var ok: bool = scene.get_viewport().get_camera_3d() == scene.get_node("CameraRig/Camera")
	scene.free()
	return ok
