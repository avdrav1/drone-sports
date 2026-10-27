extends RefCounted
# Story 1.12: brake and heading hold. Released sticks stop the drift and the
# turn; held sticks ask for a speed and a turn rate. On in Acts 1 and 2.

const Sim = preload("res://tests/sim.gd")

func _stack(brake: bool) -> AssistStack:
	var s := Sim.all_off()
	s.auto_level = true
	s.altitude_hold = true
	s.brake = brake
	return s

## Coasting at 10 m/s forward with the sticks released; returns [speed, metres travelled] after `seconds`.
func _coast(brake: bool, seconds: float) -> Array:
	var d := Sim.drone(Sim.intent(), Vector3(0, 30, 0), _stack(brake))
	await Sim.physics_frames(2)
	d.linear_velocity = Vector3(0, 0, -10)
	var start := d.global_position
	await Sim.physics_frames(int(seconds * 60))
	var out := [FlightControl.horizontal_velocity(d).length(), (d.global_position - start).length()]
	d.free()
	return out

func test_released_sticks_stop_the_drift() -> bool:
	var braked: Array = await _coast(true, 3.0)
	var coasting: Array = await _coast(false, 3.0)
	print("        after 3 s: braked %.2f m/s, %.1f m; coasting %.2f m/s, %.1f m" % (braked + coasting))
	return braked[0] < 0.5 and braked[1] < 15.0 and coasting[0] > 3.0

func test_full_stick_holds_max_speed() -> bool:
	var d := Sim.drone(Sim.intent(0.0, 1.0), Vector3(0, 30, 0), _stack(true))
	await Sim.physics_frames(360)
	var v := FlightControl.horizontal_velocity(d)
	var fwd := -d.global_transform.basis.z
	var top: float = (d.assists.get_node("Brake") as Brake).max_speed
	d.free()
	print("        full stick %.2f m/s (asks %.1f)" % [v.length(), top])
	return absf(v.length() - top) < top * 0.1 and v.normalized().dot(fwd) > 0.95

## Yaw rate right in rad/s (clockwise seen from above).
func _yaw_rate(d: Drone) -> float:
	return -d.angular_velocity.y

func test_released_yaw_stops_the_turn() -> bool:
	var d := Sim.drone(Sim.intent(0.0, 0.0, 0.0, 1.0), Vector3(0, 30, 0), _stack(true))
	await Sim.physics_frames(90)
	var top: float = (d.assists.get_node("Brake") as Brake).max_yaw_rate
	var turning := _yaw_rate(d)
	d.intent_source.value = Sim.intent()
	var heading := d.global_transform.basis.z
	await Sim.physics_frames(30)
	var after := absf(_yaw_rate(d))
	await Sim.physics_frames(60)
	var overshoot := rad_to_deg(heading.signed_angle_to(d.global_transform.basis.z, Vector3.UP))
	d.free()
	print("        turning %.0f°/s; 0.5 s after release %.1f°/s; turned %.0f° more" % [rad_to_deg(turning), rad_to_deg(after), absf(overshoot)])
	return absf(turning - top) < top * 0.1 \
		and after < deg_to_rad(5.0) and absf(overshoot) < 30.0

func test_off_from_act_3() -> bool:
	var on := []
	for act in range(1, 6):
		on.append((load("res://data/assists/act%d.tres" % act) as AssistStack).is_on(&"brake"))
	return on == [true, true, false, false, false]
