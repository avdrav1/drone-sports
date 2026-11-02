extends RefCounted
# Story 32.2: horizon mode in Act 3. The sticks still ask for a rate, so the
# drone banks and flips, but released it drifts back to level instead of
# holding its lean and running off.

const Sim = preload("res://tests/sim.gd")
const ACT3 := "res://data/assists/act3.tres"

func _deg(r: float) -> float:
	return rad_to_deg(r)

func test_released_it_drifts_back_to_level() -> bool:
	var d := Sim.drone(Sim.intent(0.1, 0.5), Vector3(0, 40, 0), load(ACT3))
	await Sim.physics_frames(20)
	var leaned := _deg(FlightControl.tilt(d))
	d.intent_source.value = Sim.intent(0.1)
	await Sim.physics_frames(60)
	var after := _deg(FlightControl.tilt(d))
	var rate := _deg(FlightControl.body_rate(d).length())
	print("        leaned %.0f deg, 1 s after release %.1f deg, %.1f deg/s" % [leaned, after, rate])
	d.free()
	return leaned > 10.0 and after < 3.0 and rate < 10.0

func test_a_small_stick_holds_a_small_lean() -> bool:
	var d := Sim.drone(Sim.intent(0.1, 0.2, -0.2), Vector3(0, 40, 0), load(ACT3))
	await Sim.physics_frames(120)
	var tilt := _deg(FlightControl.tilt(d))
	await Sim.physics_frames(30)
	var drift := absf(_deg(FlightControl.tilt(d)) - tilt)
	print("        a fifth of a stick for 2 s: %.0f deg, drift %.1f deg over 1/2 s" % [tilt, drift])
	d.free()
	return tilt > 3.0 and tilt < 30.0 and drift < 2.0

func test_full_stick_still_flips() -> bool:
	var d := Sim.drone(Sim.intent(0.1, 1.0), Vector3(0, 40, 0), load(ACT3))
	var turned := 0.0
	var frames := 0
	while turned < TAU and frames < 120:
		await Sim.physics_frames(1)
		frames += 1
		turned += -FlightControl.body_rate(d).x / 60.0
	print("        full-stick flip: %.2f s" % (frames / 60.0))
	d.free()
	return turned >= TAU and frames <= 48

func test_rights_itself_from_steep_tilt() -> bool:
	var d := Sim.drone(Sim.intent(0.1), Vector3(0, 60, 0), load(ACT3))
	d.rotate_z(deg_to_rad(120.0))
	await Sim.physics_frames(90)
	var after := _deg(FlightControl.tilt(d))
	print("        from 120 deg of roll, 1.5 s later: %.1f deg" % after)
	d.free()
	return after < 5.0

func test_off_from_act_4_and_quiet_under_auto_level() -> bool:
	var act4: AssistStack = load("res://data/assists/act4.tres")
	var d := Sim.drone(Sim.intent(), Vector3(0, 40, 0), load("res://data/assists/act1.tres"))
	await Sim.physics_frames(2)
	d.rotate_x(0.5)
	var i := Sim.intent(0.2, 0.3, -0.4)
	var h: Horizon = d.assists.get_node("Horizon")
	h.apply(i, d, 1.0 / 60.0)
	var rm: RateMode = d.assists.get_node("RateMode")
	var inverse := absf(rm.stick_for_rate(rm.wanted_rate(0.37)) - 0.37) < 0.001
	var ok: bool = h.enabled and i.pitch == 0.3 and i.roll == -0.4 and not act4.horizon and inverse
	d.free()
	return ok
