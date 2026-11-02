extends RefCounted
# Story 32.1: with auto-level off the sticks ask for a rotation rate, as on a
# real quad; released, the drone stops rotating and holds its attitude. Before,
# a sixth of a second of full forward stick in Act 3 kept the drone turning past
# 90°.

const Sim = preload("res://tests/sim.gd")
# Act 4: auto-level and horizon mode both off, so the rate loop flies alone.
const RATE_ONLY := "res://data/assists/act4.tres"

func _deg(r: float) -> float:
	return rad_to_deg(r)

## Nose-down rate, deg/s.
func _pitch_rate(d: Drone) -> float:
	return _deg(-FlightControl.body_rate(d).x)

func test_half_stick_spins_at_the_set_rate() -> bool:
	var d := Sim.drone(Sim.intent(0.1, 0.5), Vector3(0, 40, 0), load(RATE_ONLY))
	await Sim.physics_frames(20)
	var rate := _pitch_rate(d)
	var rm: RateMode = d.assists.get_node("RateMode")
	var want := _deg(rm.wanted_rate(0.5))
	# Gentle in the middle, fast at the edge.
	var curve: bool = rm.wanted_rate(0.25) < 0.5 * rm.wanted_rate(0.5) and rm.wanted_rate(1.0) > 4.0 * rm.wanted_rate(0.5)
	print("        half stick after 1/3 s: %.0f deg/s (set %.0f, full %.0f)" % [rate, want, _deg(rm.wanted_rate(1.0))])
	d.free()
	return curve and absf(rate - want) < 0.15 * want

func test_a_short_push_no_longer_flips() -> bool:
	var d := Sim.drone(Sim.intent(0.1, 1.0), Vector3(0, 40, 0), load(RATE_ONLY))
	await Sim.physics_frames(10)
	d.intent_source.value = Sim.intent(0.1)
	await Sim.physics_frames(30)
	var tilt := _deg(FlightControl.tilt(d))
	var rate := absf(_pitch_rate(d))
	print("        1/6 s of full stick, then released: %.0f deg, %.1f deg/s" % [tilt, rate])
	d.free()
	# Before, it kept turning past 90 degrees; now it stops where it was let go.
	return tilt < 60.0 and rate < 5.0

func test_released_it_holds_the_lean() -> bool:
	var d := Sim.drone(Sim.intent(0.1, 0.5), Vector3(0, 40, 0), load(RATE_ONLY))
	await Sim.physics_frames(20)
	d.intent_source.value = Sim.intent(0.1)
	await Sim.physics_frames(15)
	var rate := absf(_pitch_rate(d))
	var lean := _deg(FlightControl.pitch_angle(d))
	await Sim.physics_frames(60)
	var drift := absf(_deg(FlightControl.pitch_angle(d)) - lean)
	print("        released: %.1f deg/s after 1/4 s, lean %.0f deg, drift %.1f deg over 1 s" % [rate, lean, drift])
	d.free()
	return rate < 5.0 and lean > 10.0 and drift < 3.0

func test_yaw_turns_at_a_rate_and_stops() -> bool:
	var d := Sim.drone(Sim.intent(0.1, 0.0, 0.0, 1.0), Vector3(0, 40, 0), load(RATE_ONLY))
	await Sim.physics_frames(30)
	var want := _deg((d.assists.get_node("RateMode") as RateMode).max_yaw_rate)
	var turning := _deg(-FlightControl.body_rate(d).y)
	d.intent_source.value = Sim.intent(0.1)
	await Sim.physics_frames(30)
	var after := absf(_deg(FlightControl.body_rate(d).y))
	d.free()
	print("        full yaw: %.0f deg/s (set %.0f), released: %.1f deg/s" % [turning, want, after])
	return absf(turning - want) < 0.15 * want and after < 5.0

func test_leaves_axes_an_assist_controls() -> bool:
	var d := Sim.drone(Sim.intent(), Vector3(0, 40, 0), load("res://data/assists/act1.tres"))
	await Sim.physics_frames(2)
	d.angular_velocity = Vector3(1, 1, 1)
	var i := Sim.intent(0.2, 0.3, -0.4, 0.5)
	var rm: RateMode = d.assists.get_node("RateMode")
	rm.apply(i, d, d.assists)
	var ok: bool = i.pitch == 0.3 and i.roll == -0.4 and i.yaw == 0.5 and i.throttle == 0.2
	# Not an assist: no act, vow or setting turns it off.
	ok = ok and not d.assists.assists().any(func(a): return a.name == rm.name)
	d.free()
	return ok

# Story 32.3: gentler in the middle. Owner, 2026-11-01: "too twitchy".
func test_middle_of_the_stick_is_gentle() -> bool:
	var rm := RateMode.new()
	var half := _deg(rm.wanted_rate(0.5))
	var three_q := _deg(rm.wanted_rate(0.75))
	var full := _deg(rm.wanted_rate(1.0))
	rm.free()
	print("        asks for: half %.0f, three-quarter %.0f, full %.0f deg/s" % [half, three_q, full])
	return half <= 60.0 and three_q <= 220.0 and is_equal_approx(full, 720.0)
