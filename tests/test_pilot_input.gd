extends RefCounted
# Story 1.9: keyboard feel.

const Sim = preload("res://tests/sim.gd")
const DT := 1.0 / 60.0

func _axes(throttle := 0.0, pitch := 0.0, roll := 0.0, yaw := 0.0) -> Dictionary:
	return {&"throttle": throttle, &"pitch": pitch, &"roll": roll, &"yaw": yaw}

# Feeds the same input for n frames, returns the last intent.
func _hold(p: PilotInput, keys: Dictionary, pad: Dictionary, frames: int, latch := false) -> Intent:
	var i: Intent
	for f in frames:
		i = p.shape(keys, pad, DT, latch)
	return i

func test_held_key_ramps_to_full_in_0_15_s() -> bool:
	var p := PilotInput.new()
	var first := _hold(p, _axes(0, 1), _axes(), 1).pitch
	var at_9 := _hold(p, _axes(0, 1), _axes(), 8).pitch # 9 frames = 0.15 s
	p.free()
	return first > 0.0 and first < 0.3 and is_equal_approx(at_9, 1.0)

func test_release_returns_to_center_in_0_15_s() -> bool:
	var p := PilotInput.new()
	_hold(p, _axes(0, 0, -1), _axes(), 20)
	var mid := _hold(p, _axes(), _axes(), 4).roll
	var done := _hold(p, _axes(), _axes(), 5).roll
	p.free()
	return mid < -0.05 and done == 0.0

func test_pad_passes_through_without_ramp() -> bool:
	var p := PilotInput.new()
	var i := _hold(p, _axes(), _axes(0.7, 0.5, -1.0, 0.2), 1)
	var ok := is_equal_approx(i.throttle, 0.7) and is_equal_approx(i.pitch, p.curve(0.5)) \
		and is_equal_approx(i.roll, -1.0) and is_equal_approx(i.yaw, p.curve(0.2))
	p.free()
	return ok

func test_expo_keeps_ends_and_softens_middle() -> bool:
	var p := PilotInput.new()
	var ok := p.curve(0.0) == 0.0 and is_equal_approx(p.curve(1.0), 1.0) \
		and is_equal_approx(p.curve(-1.0), -1.0) and p.curve(0.5) < 0.5 \
		and is_equal_approx(p.curve(-0.5), -p.curve(0.5))
	p.free()
	return ok

func test_springy_throttle_with_altitude_hold() -> bool:
	var p := PilotInput.new()
	var up := _hold(p, _axes(1), _axes(), 20).throttle
	var released := _hold(p, _axes(), _axes(), 20).throttle
	var latched := p.throttle_latched()
	p.free()
	return is_equal_approx(up, 1.0) and released == 0.0 and not latched

func test_latched_throttle_starts_at_hover_and_holds() -> bool:
	var d := Sim.drone(Sim.intent())
	var p := PilotInput.new()
	d.add_child(p)
	var hover := Mixer.hover_throttle(d.hover_thrust(), d.max_thrust)
	var start := _hold(p, _axes(), _axes(), 1, true).throttle
	var nudged := _hold(p, _axes(1), _axes(), 60, true).throttle # 1 s of W
	var held := _hold(p, _axes(), _axes(), 60, true).throttle
	var down := _hold(p, _axes(-1), _axes(), 30, true).throttle # 0.5 s of S
	d.free()
	return is_equal_approx(start, hover) and is_equal_approx(nudged, hover + 0.5) \
		and is_equal_approx(held, nudged) and is_equal_approx(down, hover + 0.25)

func test_pad_throttle_takes_over_latch() -> bool:
	var p := PilotInput.new()
	_hold(p, _axes(1), _axes(), 30, true)
	var pad := _hold(p, _axes(), _axes(-0.6), 1, true).throttle
	var after := _hold(p, _axes(), _axes(), 1, true).throttle
	var keys_back := _hold(p, _axes(1), _axes(), 1, true).throttle
	p.free()
	return is_equal_approx(pad, -0.6) and after == 0.0 and keys_back > 0.0

func test_latch_follows_altitude_hold_in_debug_scene() -> bool:
	var scene: Node = Sim.add(load("res://scenes/debug_flight.tscn").instantiate())
	var pilot: PilotInput = scene.get_node("Drone/PilotInput")
	await Sim.physics_frames(2)
	var act1 := pilot.throttle_latched()
	scene.preset_index = 2 # Act 3: altitude hold off
	scene.apply_preset()
	await Sim.physics_frames(2)
	var act3 := pilot.throttle_latched()
	scene.free()
	return not act1 and act3

func test_real_key_events_drive_pitch() -> bool:
	var d := Sim.drone(Sim.intent())
	var p := PilotInput.new()
	d.add_child(p)
	var ev := InputEventKey.new()
	ev.keycode = KEY_UP
	ev.pressed = true
	Input.parse_input_event(ev)
	await Sim.physics_frames(2)
	var i := p.read_intent()
	ev.pressed = false
	Input.parse_input_event(ev)
	await Sim.physics_frames(2)
	d.free()
	return i.pitch > 0.0
