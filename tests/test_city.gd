extends RefCounted
# Story 12.2: buildings. Box towers from the plan, one collision box per lot.

const Sim = preload("res://tests/sim.gd")
const CITY := preload("res://scenes/world/city.tscn")

func _city() -> City:
	return Sim.add(CITY.instantiate())

func _boxes(c: City) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	for n in c.get_children():
		if n is CollisionShape3D:
			out.append(n)
	return out

func test_one_collision_box_per_lot() -> bool:
	var c := _city()
	var boxes := _boxes(c)
	var ok := boxes.size() == c.plan.lots.size() and boxes.size() > 0
	for i in mini(boxes.size(), c.plan.lots.size()):
		var lot := c.plan.lots[i]
		var h := c.plan.heights[i]
		var box := boxes[i].shape as BoxShape3D
		var want := Vector3(lot.get_center().x, h * 0.5, lot.get_center().y)
		ok = ok and box != null and box.size.is_equal_approx(Vector3(lot.size.x, h, lot.size.y)) \
			and boxes[i].global_position.is_equal_approx(want)
	c.free()
	return ok

func test_ray_down_hits_roof() -> bool:
	var c := _city()
	await Sim.physics_frames(2)
	var space := c.get_world_3d().direct_space_state
	var ok := true
	for i in c.plan.lots.size():
		var at := c.plan.lots[i].get_center()
		var from := Vector3(at.x + 0.13, 200.0, at.y + 0.07)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 400.0))
		if hit.is_empty() or absf(hit.position.y - c.plan.heights[i]) > 0.01:
			ok = false
	c.free()
	return ok

func test_flying_into_a_wall_is_contact() -> bool:
	var avoid := AvoidContact.new()
	var job := Job.new()
	job.time_limit = 60.0
	var root := Sim.job_setup(job, [avoid])
	var c: City = CITY.instantiate()
	root.add_child(c)
	await Sim.go_live(root)
	# The tallest lot, approached from its south face, flying north (-z).
	var best := 0
	for i in c.plan.lots.size():
		if c.plan.heights[i] > c.plan.heights[best]:
			best = i
	var lot := c.plan.lots[best]
	var d: Drone = root.get_node("Drone")
	var hit := []
	d.body_entered.connect(func(b): hit.append(b))
	d.global_position = Vector3(lot.get_center().x, 5.0, lot.end.y + 2.0)
	d.linear_velocity = Vector3(0, 0, -6)
	await Sim.physics_frames(60)
	var ok := avoid.contacts >= 1 and hit.has(c)
	root.free()
	return ok

func test_renders_through_few_multimeshes() -> bool:
	var c := _city()
	var meshes := c.find_children("*", "MultiMeshInstance3D", true, false)
	var total := 0
	for m in meshes:
		total += (m as MultiMeshInstance3D).multimesh.instance_count
	var ok := meshes.size() >= 1 and meshes.size() <= 4 and total == c.plan.lots.size()
	c.free()
	return ok

func test_same_layout_reuses_cache() -> bool:
	var a := _city()
	var size := City._cache.size()
	var b := _city()
	var ok: bool = City._cache.size() == size \
		and a.get_node("Towers").multimesh == b.get_node("Towers").multimesh \
		and (_boxes(a)[0].shape == _boxes(b)[0].shape)
	a.free()
	b.free()
	return ok

func test_scene_loads_without_errors() -> bool:
	# The runner's error logger fails this test on any engine or script error.
	var c := _city()
	await Sim.process_frames(3)
	var ok := c.get_node_or_null("Towers") is MultiMeshInstance3D
	c.free()
	return ok
