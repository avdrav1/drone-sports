extends RefCounted
# Story 9.4: speed cues. FOV widens with speed; dust only near the ground with thrust on.

const Sim = preload("res://tests/sim.gd")
const RIG := preload("res://scenes/camera/camera_rig.tscn")

## A body coasting at `speed` along -Z with no gravity or drag.
func _coaster(speed: float) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.gravity_scale = 0.0
	b.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.linear_damp = 0.0
	Sim.add(b)
	b.global_position = Vector3(0, 50, 0)
	b.linear_velocity = Vector3(0, 0, -speed)
	return b

func test_fov_widens_with_speed_and_returns() -> bool:
	var b := _coaster(20.0)
	var rig: CameraRig = RIG.instantiate()
	rig.target = b
	Sim.add(rig)
	var rest := rig.base_fov
	await Sim.process_frames(90)
	var fast := rig.camera.fov
	b.linear_velocity = Vector3.ZERO
	await Sim.process_frames(120)
	var after := rig.camera.fov
	rig.free()
	b.free()
	return fast > rest + 8.0 and absf(after - rest) < 0.5

func test_fov_unchanged_in_top_down() -> bool:
	var b := _coaster(20.0)
	var rig: CameraRig = RIG.instantiate()
	rig.target = b
	Sim.add(rig)
	rig.set_view(CameraRig.View.TOP_DOWN)
	await Sim.process_frames(60)
	var ok := is_equal_approx(rig.camera.fov, rig.base_fov)
	rig.free()
	b.free()
	return ok

func _floor() -> StaticBody3D:
	var f := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(50, 1, 50)
	f.add_child(shape)
	Sim.add(f)
	f.global_position = Vector3(0, -0.5, 0)
	return f

## Frozen drone at `height` with every motor at `thrust` N; reports whether dust emits.
func _dust_at(height: float, thrust: float) -> bool:
	var d: Drone = Sim.DRONE.instantiate()
	Sim.add(d)
	d.freeze = true
	d.global_position = Vector3(0, height, 0)
	d.set_motor_thrusts(PackedFloat32Array([thrust, thrust, thrust, thrust]))
	await Sim.physics_frames(3)
	var wash: PropWash = d.get_node("PropWash")
	var on := wash.emitting
	d.free()
	return on

func test_dust_only_low_with_thrust() -> bool:
	var f := _floor()
	var low_on: bool = await _dust_at(1.0, 2.5)
	var high: bool = await _dust_at(10.0, 2.5)
	var low_off: bool = await _dust_at(1.0, 0.0)
	f.free()
	return low_on and not high and not low_off
