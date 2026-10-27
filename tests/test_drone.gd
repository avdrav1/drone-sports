extends RefCounted
# Story 1.1: quadcopter rigid body.

const Sim = preload("res://tests/sim.gd")
const DRONE := preload("res://scenes/drone/drone.tscn")

func _spawn(height := 10.0) -> Drone:
	var d: Drone = DRONE.instantiate()
	Sim.add(d)
	d.global_position = Vector3(0, height, 0)
	return d

func _all(value: float) -> PackedFloat32Array:
	return PackedFloat32Array([value, value, value, value])

# Angular velocity in body axes.
func _body_rate(d: Drone) -> Vector3:
	return d.global_transform.basis.inverse() * d.angular_velocity

func test_hover_holds_height_for_10_s() -> bool:
	var d := _spawn(10.0)
	d.set_motor_thrusts(_all(d.hover_thrust()))
	var worst := 0.0
	for i in 600:
		await Sim.physics_frames(1)
		worst = maxf(worst, absf(d.global_position.y - 10.0))
	d.free()
	return worst < 0.1

func test_stats_are_exported() -> bool:
	var exported := []
	var d := Drone.new()
	for p in d.get_property_list():
		if p.usage & PROPERTY_USAGE_EDITOR:
			exported.append(p.name)
	d.free()
	return exported.has("mass") and exported.has("drag") and exported.has("max_thrust")

func test_more_front_thrust_pitches_nose_up() -> bool:
	var d := _spawn()
	var h := d.hover_thrust()
	d.set_motor_thrusts(PackedFloat32Array([h + 0.3, h + 0.3, h - 0.3, h - 0.3]))
	await Sim.physics_frames(10)
	var rate := _body_rate(d)
	d.free()
	return rate.x > 0.5 and absf(rate.y) < 0.05 and absf(rate.z) < 0.05

func test_more_left_thrust_rolls_right() -> bool:
	var d := _spawn()
	var h := d.hover_thrust()
	d.set_motor_thrusts(PackedFloat32Array([h + 0.3, h - 0.3, h + 0.3, h - 0.3]))
	await Sim.physics_frames(10)
	var rate := _body_rate(d)
	d.free()
	# Rolling right (right side down) is negative rotation about +Z.
	return rate.z < -0.5 and absf(rate.x) < 0.05 and absf(rate.y) < 0.05

func test_diagonal_thrust_yaws() -> bool:
	var d := _spawn()
	var h := d.hover_thrust()
	# Motors 1 and 2 up, 0 and 3 down: net reaction torque turns the nose right (clockwise from above).
	d.set_motor_thrusts(PackedFloat32Array([h - 0.5, h + 0.5, h + 0.5, h - 0.5]))
	await Sim.physics_frames(10)
	var rate := _body_rate(d)
	d.free()
	return rate.y < -0.2 and absf(rate.x) < 0.05 and absf(rate.z) < 0.05

func test_pitched_drone_moves_forward() -> bool:
	var d := _spawn()
	d.rotate_x(deg_to_rad(-15.0)) # nose down
	d.set_motor_thrusts(_all(d.hover_thrust() * 1.05))
	await Sim.physics_frames(30)
	var forward_speed := d.linear_velocity.dot(Vector3.FORWARD)
	d.free()
	return forward_speed > 0.5

## Found in Story 3.3: forces queued while frozen used to fire all at once on unfreeze.
func test_frozen_drone_queues_no_force() -> bool:
	var d := Sim.drone(Sim.intent(0.2), Vector3(40, 50, 40))
	d.freeze = true
	await Sim.physics_frames(180)
	d.freeze = false
	await Sim.physics_frames(5)
	var ok := d.linear_velocity.length() < 1.0 and d.angular_velocity.length() < 0.5
	d.free()
	return ok
