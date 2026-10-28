extends RefCounted
# Story 14.2: the drone's sound. Hum pitch follows thrust and falls at idle; a
# contact plays exactly one impact, louder when faster; a frozen drone is silent.

const Sim = preload("res://tests/sim.gd")

## A drone with no intent source, so motor thrusts stay where they are set.
func _drone(at: Vector3) -> Drone:
	var d: Drone = Sim.DRONE.instantiate()
	Sim.add(d)
	d.global_position = at
	return d

func _floor() -> StaticBody3D:
	var f := StaticBody3D.new()
	var s := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	s.shape = box
	f.add_child(s)
	Sim.add(f)
	f.global_position = Vector3(0, -0.5, 0)
	return f

func _thrust(d: Drone, fraction: float) -> DroneSound:
	var t := d.max_thrust * fraction
	d.set_motor_thrusts(PackedFloat32Array([t, t, t, t]))
	var s: DroneSound = d.get_node("Sound")
	s.update_sound(1.0)
	return s

func test_hum_pitch_rises_with_thrust_and_falls_at_idle() -> bool:
	var d := _drone(Vector3(0, 50, 0))
	var s := _thrust(d, 0.9)
	var high_pitch := s.hum_pitch
	var high_db := s.hum_db
	var ok: bool = s.humming and s.hum.playing and is_equal_approx(s.hum.pitch_scale, high_pitch)
	s = _thrust(d, 0.3)
	ok = ok and s.hum_pitch < high_pitch
	s = _thrust(d, 0.02)
	ok = ok and s.humming and s.hum_pitch < high_pitch and absf(s.hum_pitch - s.idle_pitch) < 0.05 \
		and s.hum_db < high_db and is_equal_approx(s.hum.pitch_scale, s.hum_pitch)
	s = _thrust(d, 0.0)
	ok = ok and not s.humming and not s.hum.playing
	d.free()
	return ok

func test_contact_plays_one_impact_louder_when_faster() -> bool:
	var f := _floor()
	var slow := _drone(Vector3(-5, 0.6, 0))
	var fast := _drone(Vector3(5, 5.0, 0))
	Sfx.clear_log()
	await Sim.physics_frames(150)
	var a: DroneSound = slow.get_node("Sound")
	var b: DroneSound = fast.get_node("Sound")
	var gains := Sfx.log.filter(func(l): return l.id == &"drone_impact").map(func(l): return l.gain_db)
	var ok: bool = a.impacts == 1 and b.impacts == 1 and Sfx.count(&"drone_impact") == 2 \
		and b.last_impact_speed > a.last_impact_speed and b.last_impact_db > a.last_impact_db \
		and gains.has(a.last_impact_db) and gains.has(b.last_impact_db)
	if not ok:
		print("        impacts %d/%d speeds %.2f/%.2f" % [a.impacts, b.impacts, a.last_impact_speed, b.last_impact_speed])
	slow.free()
	fast.free()
	f.free()
	return ok

func test_frozen_drone_is_silent() -> bool:
	var f := _floor()
	var d := _drone(Vector3(0, 0.3, 0))
	var s := _thrust(d, 0.8)
	await Sim.physics_frames(2)
	var ok: bool = s.humming and s.washing and s.wash.playing
	d.freeze = true
	Sfx.clear_log()
	s.update_sound(1.0)
	s._on_body_entered(f)
	ok = ok and not s.humming and not s.hum.playing and not s.washing and not s.wash.playing \
		and s.impacts == 0 and Sfx.count(&"drone_impact") == 0
	d.free()
	f.free()
	return ok

func test_wash_only_near_the_ground() -> bool:
	var d := _drone(Vector3(0, 40, 0))
	var s := _thrust(d, 0.8)
	await Sim.physics_frames(2)
	var ok: bool = s.humming and not s.washing and s.wash_level_db <= DroneSound.QUIET_DB
	d.free()
	return ok
