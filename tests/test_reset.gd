extends RefCounted
# Story 1.11: reset in the debug scene.

const Sim = preload("res://tests/sim.gd")

func test_r_resets_drone() -> bool:
	var scene: Node = Sim.add(load("res://scenes/debug_flight.tscn").instantiate())
	await Sim.physics_frames(2)
	var d: Drone = scene.get_node("Drone")
	var spawn := d.global_transform
	d.global_position += Vector3(5, 8, -3)
	d.rotate_x(0.7)
	d.linear_velocity = Vector3(4, -2, 1)
	d.angular_velocity = Vector3(1, 2, 3)
	d.battery = 0.2
	await Sim.physics_frames(30)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_R
	ev.pressed = true
	scene.get_viewport().push_input(ev)
	var reset_ok := d.global_transform.is_equal_approx(spawn) and d.linear_velocity == Vector3.ZERO \
		and d.angular_velocity == Vector3.ZERO and d.battery == 1.0
	await Sim.physics_frames(120)
	var drift := d.global_position.distance_to(spawn.origin)
	scene.free()
	return reset_ok and drift < 0.05
