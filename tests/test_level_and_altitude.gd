extends RefCounted
# Story 1.5: altitude hold and auto-level.

const Sim = preload("res://tests/sim.gd")

func _stack(level: bool, alt: bool) -> AssistStack:
	var s := Sim.all_off()
	s.auto_level = level
	s.altitude_hold = alt
	return s

func test_release_returns_to_level_constant_height_within_1s() -> bool:
	var d := Sim.drone(Sim.intent(0.8, 0.9, -0.6, 0.3), Vector3(0, 10, 0), _stack(true, true))
	await Sim.physics_frames(90) # climbing, pitched, banked, yawing
	d.intent_source.value = Sim.intent() # release everything
	await Sim.physics_frames(60)
	var tilt := rad_to_deg(FlightControl.tilt(d))
	var vy := d.linear_velocity.y
	var h0 := d.global_position.y
	var spread := 0.0
	for i in 60:
		await Sim.physics_frames(1)
		spread = maxf(spread, absf(d.global_position.y - h0))
	print("        after 1 s: tilt %.2f deg, vy %.3f m/s, height drift next 1 s %.3f m" % [tilt, vy, spread])
	d.free()
	return tilt < 3.0 and absf(vy) < 0.15 and spread < 0.1

func test_bank_persists_without_auto_level() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(0, 10, 0), _stack(false, true))
	d.rotate_z(deg_to_rad(-20.0)) # right side down
	await Sim.physics_frames(60)
	var bank := rad_to_deg(FlightControl.roll_angle(d))
	d.free()
	return bank > 15.0

func test_auto_level_levels_same_bank() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(0, 10, 0), _stack(true, true))
	d.rotate_z(deg_to_rad(-20.0))
	await Sim.physics_frames(60)
	var bank := rad_to_deg(FlightControl.roll_angle(d))
	d.free()
	return absf(bank) < 2.0

func test_centered_throttle_sinks_without_altitude_hold() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(0, 10, 0), _stack(true, false))
	await Sim.physics_frames(60)
	var ok := d.global_position.y < 9.7 and d.linear_velocity.y < 0.0
	d.free()
	return ok

func test_centered_throttle_holds_with_altitude_hold() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(0, 10, 0), _stack(true, true))
	await Sim.physics_frames(120)
	var ok := absf(d.global_position.y - 10.0) < 0.05
	d.free()
	return ok

func test_throttle_stick_sets_climb_rate() -> bool:
	var d := Sim.drone(Sim.intent(0.5), Vector3(0, 10, 0), _stack(true, true))
	await Sim.physics_frames(90)
	var rate := d.linear_velocity.y
	d.free()
	return absf(rate - 2.0) < 0.2

func test_each_toggles_live() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(0, 10, 0), _stack(true, true))
	await Sim.physics_frames(30)
	d.assists.get_node("AltitudeHold").enabled = false
	await Sim.physics_frames(60)
	var sank := d.global_position.y < 9.7
	d.assists.get_node("AltitudeHold").enabled = true
	await Sim.physics_frames(60)
	var vy := d.linear_velocity.y
	d.free()
	return sank and absf(vy) < 0.2
