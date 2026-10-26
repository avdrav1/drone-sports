extends RefCounted
# Story 1.6a: speed governor.

const Sim = preload("res://tests/sim.gd")

func _stack(governor: bool, level := true) -> AssistStack:
	var s := Sim.all_off()
	s.auto_level = level
	s.altitude_hold = true
	s.speed_governor = governor
	return s

# Full forward stick for `seconds`; returns [min, max] horizontal speed over the last second.
func _full_stick(stack: AssistStack, seconds: float) -> Array:
	var d := Sim.drone(Sim.intent(0.0, 1.0), Vector3(0, 30, 0), stack)
	var frames := int(seconds * 60)
	var lo := INF
	var hi := 0.0
	for i in frames:
		await Sim.physics_frames(1)
		if i >= frames - 60:
			var s := FlightControl.horizontal_velocity(d).length()
			lo = minf(lo, s)
			hi = maxf(hi, s)
	d.free()
	return [lo, hi]

func test_full_stick_holds_cap_within_5_percent() -> bool:
	var r: Array = await _full_stick(_stack(true), 10.0)
	print("        governed speed %.2f..%.2f m/s (cap 12)" % r)
	return r[0] >= 12.0 * 0.95 and r[1] <= 12.0 * 1.05

func test_without_governor_exceeds_cap() -> bool:
	var r: Array = await _full_stick(_stack(false), 10.0)
	return r[0] > 12.0 * 1.05

func test_disable_live() -> bool:
	var d := Sim.drone(Sim.intent(0.0, 1.0), Vector3(0, 30, 0), _stack(true))
	await Sim.physics_frames(480)
	var governed := FlightControl.horizontal_velocity(d).length()
	d.assists.get_node("SpeedGovernor").enabled = false
	await Sim.physics_frames(180)
	var free := FlightControl.horizontal_velocity(d).length()
	d.free()
	return governed <= 12.6 and free > 13.0

func test_no_change_below_cap() -> bool:
	var d := Sim.drone(Sim.intent(0.0, 0.3, 0.2), Vector3(0, 30, 0), _stack(true, false))
	var ok := true
	for i in 20:
		await Sim.physics_frames(1)
		ok = ok and d.intent.pitch == 0.3 and d.intent.roll == 0.2
	d.free()
	return ok
