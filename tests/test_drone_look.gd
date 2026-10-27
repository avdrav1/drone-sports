extends RefCounted
# Story 9.3: drone look. Props and motor glow follow thrust; physics is untouched.

const Sim = preload("res://tests/sim.gd")

func _drone_with_thrust(t: float) -> Drone:
	var d: Drone = Sim.DRONE.instantiate()
	Sim.add(d)
	d.freeze = true
	d.set_motor_thrusts(PackedFloat32Array([t, t, t, t]))
	d.get_node("Look").update_look(1.0 / 60.0)
	return d

func test_still_at_zero_thrust() -> bool:
	var d := _drone_with_thrust(0.0)
	var look: DroneLook = d.get_node("Look")
	var ok := true
	for i in Drone.MOTOR_COUNT:
		ok = ok and look.spin_rates[i] == 0.0 and look.glows[i] == 0.0
	d.free()
	return ok

func test_spin_and_glow_rise_with_thrust() -> bool:
	var low := _drone_with_thrust(1.0)
	var high := _drone_with_thrust(4.0)
	var a: DroneLook = low.get_node("Look")
	var b: DroneLook = high.get_node("Look")
	var ok := true
	for i in Drone.MOTOR_COUNT:
		ok = ok and absf(b.spin_rates[i]) > absf(a.spin_rates[i]) and absf(a.spin_rates[i]) > 0.0
		ok = ok and b.glows[i] > a.glows[i] and a.glows[i] > 0.0
	# Diagonal pairs spin opposite ways, like the motors.
	ok = ok and signf(a.spin_rates[0]) == -signf(a.spin_rates[1])
	low.free()
	high.free()
	return ok

func test_physics_unchanged() -> bool:
	var d: Drone = Sim.DRONE.instantiate()
	var shape: CollisionShape3D = d.get_node("Shape")
	var box := shape.shape as BoxShape3D
	var shapes := d.find_children("*", "CollisionShape3D", true, false)
	var ok := box != null and box.size == Vector3(0.4, 0.12, 0.4) and d.mass == 1.0 and shapes.size() == 1 and shape.transform == Transform3D.IDENTITY
	d.free()
	return ok
