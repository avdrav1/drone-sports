extends RefCounted
# A soft shadow straight below the drone, so a pilot can judge a landing.

const Sim = preload("res://tests/sim.gd")

## A 200 m floor with its top at y = 0, tilted by `tilt`.
func _floor(tilt := Vector3.ZERO) -> StaticBody3D:
	var f := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(200, 1, 200)
	shape.position = Vector3(0, -0.5, 0)
	f.add_child(shape)
	Sim.add(f)
	f.rotation = tilt
	return f

## A frozen drone at `at`, once its shadow has had time to find the ground.
func _drone_at(at: Vector3) -> Drone:
	var d: Drone = Sim.DRONE.instantiate()
	Sim.add(d)
	d.freeze = true
	d.global_position = at
	await Sim.physics_frames(3)
	return d

func _shadow(d: Drone) -> GroundShadow:
	return d.get_node("GroundShadow")

func _darkness(s: GroundShadow) -> float:
	return (s.material_override as StandardMaterial3D).albedo_color.a

func test_lies_on_the_ground_straight_below_the_drone() -> bool:
	var f := _floor()
	var d: Drone = await _drone_at(Vector3(7, 12, -4))
	var s := _shadow(d)
	var at := s.global_position
	var ok: bool = s.visible and is_equal_approx(at.x, 7.0) and is_equal_approx(at.z, -4.0) \
		and at.y > 0.0 and at.y < 0.1 and is_equal_approx(s.height, 12.0)
	d.free()
	f.free()
	return ok

func test_stays_flat_and_below_when_the_drone_banks() -> bool:
	var f := _floor()
	var d: Drone = await _drone_at(Vector3(0, 5, 0))
	d.rotation = Vector3(0.6, 0.0, 0.5)
	await Sim.physics_frames(3)
	var s := _shadow(d)
	var ok: bool = s.global_transform.basis.y.normalized().is_equal_approx(Vector3.UP) \
		and is_zero_approx(s.global_position.x) and is_zero_approx(s.global_position.z)
	d.free()
	f.free()
	return ok

func test_darker_and_tighter_on_the_way_down() -> bool:
	var f := _floor()
	var high: Drone = await _drone_at(Vector3(0, 30, 0))
	var high_dark := _darkness(_shadow(high))
	var high_size := _shadow(high).global_transform.basis.get_scale().x
	high.free()
	var low: Drone = await _drone_at(Vector3(0, 1, 0))
	var low_dark := _darkness(_shadow(low))
	var low_size := _shadow(low).global_transform.basis.get_scale().x
	low.free()
	f.free()
	return low_dark > high_dark + 0.3 and low_size < high_size - 1.0 and high_dark > 0.0

func test_lies_along_a_slope() -> bool:
	var f := _floor(Vector3(0, 0, 0.3))
	var d: Drone = await _drone_at(Vector3(0, 5, 0))
	var up := _shadow(d).global_transform.basis.y.normalized()
	var ok := up.is_equal_approx(f.global_transform.basis.y.normalized())
	d.free()
	f.free()
	return ok

func test_gone_with_no_ground_in_reach() -> bool:
	var f := _floor()
	var d: Drone = await _drone_at(Vector3(0, 1, 0))
	var s := _shadow(d)
	var low := s.visible
	d.global_position = Vector3(0, s.max_height + 5.0, 0)
	await Sim.physics_frames(3)
	var ok := low and not s.visible
	d.free()
	f.free()
	return ok

func test_a_drone_does_not_shade_itself() -> bool:
	# Its own body is under the ray's start: the ray must pass through to the floor.
	var f := _floor()
	var d: Drone = await _drone_at(Vector3(0, 0.02, 0))
	var ok := _shadow(d).global_position.y < 0.1 and _shadow(d).visible
	d.free()
	f.free()
	return ok

func test_has_no_body_of_its_own() -> bool:
	var f := _floor()
	var d: Drone = await _drone_at(Vector3(0, 2, 0))
	var s := _shadow(d)
	var ok: bool = s.get_child_count() == 0 and s.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.free()
	f.free()
	return ok

# Owner, 2026-11-02: "when i did the parcel mission, i still wasn't seeing the
# shadow of the drone". The chase camera sat 1.5 m back and 0.45 m up, so the
# ground below the drone left the frame above about 1.6 m.
func test_in_the_chase_view_of_the_parcel_job() -> bool:
	var scene: Node = Sim.add(load("res://scenes/jobs/sample_delivery.tscn").instantiate())
	var d: Drone = scene.get_node("Drone")
	await Sim.physics_frames(2)
	var ok := true
	for h in [1.0, 2.5, 3.5]:
		d.freeze = true
		d.global_position = Vector3(20, h, -40)
		await Sim.physics_frames(60)
		var cam := scene.get_viewport().get_camera_3d()
		var s := _shadow(d)
		var at := s.global_position
		var seen := s.visible and cam.is_position_in_frustum(at)
		print("        drone at %.1f m: shadow in the chase view %s" % [h, seen])
		ok = ok and seen
	scene.free()
	return ok
