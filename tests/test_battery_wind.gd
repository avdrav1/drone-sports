extends RefCounted
# Story 1.7: battery and wind.

const Sim = preload("res://tests/sim.gd")

func _stack(env_assist: bool) -> AssistStack:
	var s := Sim.all_off()
	s.auto_level = true
	s.altitude_hold = true
	s.battery_wind = env_assist
	return s

func _wind(x: float) -> Wind:
	var w := Wind.new()
	w.base = Vector3(x, 0, 0)
	return w

func test_wind_drifts_drone_when_assist_off() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(0, 10, 0), _stack(false))
	d.wind = _wind(4.0)
	await Sim.physics_frames(180)
	var x := d.global_position.x
	d.free()
	return x > 2.0

func test_pilot_can_correct_for_wind() -> bool:
	var d := Sim.drone(Sim.intent(0.0, 0.0, -0.2), Vector3(0, 10, 0), _stack(false))
	d.wind = _wind(4.0)
	await Sim.physics_frames(180)
	var x := d.global_position.x
	d.free()
	return x < 2.0

func test_no_wind_when_assist_on() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(0, 10, 0), _stack(true))
	d.wind = _wind(4.0)
	await Sim.physics_frames(180)
	var x := d.global_position.x
	d.free()
	return absf(x) < 0.05

func test_gusts_vary_with_time() -> bool:
	var w := _wind(3.0)
	w.gust_amplitude = 2.0
	var a := w.sample(0.0).x
	var b := w.sample(1.5).x
	return a != b and w.sample(7.0).x >= 3.0 and w.sample(7.0).x <= 5.0

func test_battery_empties_after_flight_time_then_fades_over_3s() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(0, 50, 0), _stack(false))
	d.battery_flight_time = 2.0
	await Sim.physics_frames(114) # 1.9 s
	var before := d.battery > 0.0
	await Sim.physics_frames(12) # 2.1 s
	var empty := d.battery == 0.0
	await Sim.physics_frames(84) # 1.5 s after empty (roughly)
	var half := d.power()
	await Sim.physics_frames(96) # past 3 s after empty
	var off := d.power() == 0.0
	await Sim.physics_frames(30)
	var falling := d.linear_velocity.y < -1.0
	d.free()
	return before and empty and half > 0.35 and half < 0.65 and off and falling

func test_battery_holds_when_assist_on() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(0, 50, 0), _stack(true))
	d.battery_flight_time = 2.0
	await Sim.physics_frames(300)
	var ok := d.battery == 1.0 and d.power() == 1.0 and absf(d.global_position.y - 50.0) < 0.1
	d.free()
	return ok
