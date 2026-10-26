extends RefCounted
# Story 1.2: raw stick input and mixer.

const Sim = preload("res://tests/sim.gd")
const DRONE := preload("res://scenes/drone/drone.tscn")

class FixedSource extends IntentSource:
	var value := Intent.new()
	func read_intent() -> Intent:
		return value.copy()

func _intent(throttle: float, pitch := 0.0, roll := 0.0, yaw := 0.0) -> Intent:
	var i := Intent.new()
	i.throttle = throttle
	i.pitch = pitch
	i.roll = roll
	i.yaw = yaw
	return i

func _spawn(intent: Intent, x := 0.0) -> Drone:
	var d: Drone = DRONE.instantiate()
	var src := FixedSource.new()
	src.value = intent
	d.add_child(src)
	d.intent_source = src
	Sim.add(d)
	d.assists.apply_stack(Sim.all_off())
	d.global_position = Vector3(x, 20, 0)
	return d

func _body_rate(d: Drone) -> Vector3:
	return d.global_transform.basis.inverse() * d.angular_velocity

# Mixer unit tests: known inputs, known outputs.

func test_mixer_centered_is_half_thrust() -> bool:
	var t := Mixer.mix(_intent(0.0), 4.0)
	return t == PackedFloat32Array([2.0, 2.0, 2.0, 2.0])

func test_mixer_extremes() -> bool:
	var full := Mixer.mix(_intent(1.0), 4.0)
	var off := Mixer.mix(_intent(-1.0), 4.0)
	return full == PackedFloat32Array([4.0, 4.0, 4.0, 4.0]) and off == PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

func test_mixer_pitch_forward_raises_rear() -> bool:
	var t := Mixer.mix(_intent(0.0, 1.0), 4.0)
	var d := Mixer.STICK_AUTHORITY * 4.0
	return is_equal_approx(t[0], 2.0 - d) and is_equal_approx(t[1], 2.0 - d) \
		and is_equal_approx(t[2], 2.0 + d) and is_equal_approx(t[3], 2.0 + d)

func test_mixer_roll_right_raises_left() -> bool:
	var t := Mixer.mix(_intent(0.0, 0.0, 1.0), 4.0)
	return t[0] > 2.0 and t[2] > 2.0 and t[1] < 2.0 and t[3] < 2.0

func test_mixer_yaw_right_raises_ccw_pair() -> bool:
	var t := Mixer.mix(_intent(0.0, 0.0, 0.0, 1.0), 4.0)
	return t[1] > 2.0 and t[2] > 2.0 and t[0] < 2.0 and t[3] < 2.0

func test_mixer_clamps() -> bool:
	var t := Mixer.mix(_intent(1.0, 1.0, 1.0, 1.0), 4.0)
	for v in t:
		if v < 0.0 or v > 4.0:
			return false
	return true

func test_mixer_is_pure() -> bool:
	var i := _intent(0.3, -0.2, 0.5, 0.1)
	var a := Mixer.mix(i, 4.0)
	var b := Mixer.mix(i, 4.0)
	return a == b and i.throttle == 0.3 and i.roll == 0.5

# Flight tests through the real drone.

func test_full_throttle_climbs() -> bool:
	var d := _spawn(_intent(1.0))
	await Sim.physics_frames(60)
	var ok := d.global_position.y > 21.0 and d.linear_velocity.y > 0.0
	d.free()
	return ok

func test_zero_throttle_falls() -> bool:
	var d := _spawn(_intent(-1.0))
	await Sim.physics_frames(60)
	var ok := d.global_position.y < 17.0
	d.free()
	return ok

func test_sticks_rotate_correct_axes() -> bool:
	var probe: Drone = DRONE.instantiate()
	var hover := Mixer.hover_throttle(probe.hover_thrust(), probe.max_thrust)
	probe.free()
	var nose_down := _spawn(_intent(hover, 0.5))
	var roll_right := _spawn(_intent(hover, 0.0, 0.5), 5.0)
	var yaw_right := _spawn(_intent(hover, 0.0, 0.0, 0.5), 10.0)
	await Sim.physics_frames(6)
	var p := _body_rate(nose_down)
	var r := _body_rate(roll_right)
	var y := _body_rate(yaw_right)
	nose_down.free()
	roll_right.free()
	yaw_right.free()
	# Nose down is negative about +X, roll right negative about +Z, yaw right negative about +Y.
	return p.x < -0.3 and r.z < -0.3 and y.y < -0.1 \
		and absf(p.y) + absf(p.z) < 0.05 and absf(r.x) + absf(r.y) < 0.05 and absf(y.x) + absf(y.z) < 0.05

func test_pilot_input_reads_actions() -> bool:
	var src := PilotInput.new()
	Input.action_press("throttle_up")
	Input.action_press("pitch_forward")
	Input.action_press("roll_left")
	Input.action_press("yaw_right")
	var i := src.read_intent()
	for a in ["throttle_up", "pitch_forward", "roll_left", "yaw_right"]:
		Input.action_release(a)
	src.free()
	return i.throttle == 1.0 and i.pitch == 1.0 and i.roll == -1.0 and i.yaw == 1.0
