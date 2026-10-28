extends RefCounted
# Story 15.4: building surfaces. Each tower's walls take a library set from its
# seed; wetness and snow still change what the shader draws; the plan and
# collision are as before.

const Sim = preload("res://tests/sim.gd")
const CITY := preload("res://scenes/world/city.tscn")
const PROBE := "res://tests/city_render_probe.gd"
const PROBE_TIMEOUT_MS := 60000

func _city(layout: CityLayout = null) -> City:
	var c: City = CITY.instantiate()
	if layout:
		c.layout = layout
	return Sim.add(c)

func test_wall_set_comes_from_the_seed_and_repeats() -> bool:
	var a := _city()
	var follows: bool = a.seeds.size() == a.plan.lots.size() and a.wall_index.size() == a.plan.lots.size()
	for i in a.wall_index.size():
		follows = follows and a.wall_index[i] == City.wall_for(a.seeds[i], a.walls.size())
	# Built again from scratch, the same seed gives the same sets.
	var seeds := a.seeds
	var picks := a.wall_index
	a.free()
	City._cache.clear()
	var b := _city()
	var repeats: bool = b.seeds == seeds and b.wall_index == picks
	# Every set in the list is used somewhere, and another seed picks differently.
	var used := {}
	for k in b.wall_index:
		used[k] = true
	var varied := used.size() == b.walls.size()
	var other: CityLayout = b.layout.duplicate()
	other.seed += 1
	b.free()
	var c := _city(other)
	var differs: bool = c.wall_index != picks
	c.free()
	if not (follows and repeats and varied and differs):
		print("        %s %s %s %s" % [follows, repeats, varied, differs])
	return follows and repeats and varied and differs

func test_every_surface_comes_from_the_library() -> bool:
	var c := _city()
	var library := {}
	var textures := {}
	for id in SurfaceSet.ids():
		var s := SurfaceSet.named(id)
		library[s.resource_path] = true
		textures[s.albedo] = true
		textures[s.normal_rough] = true
	var ok: bool = c.walls.size() == 4 and c.roof != null and library.has(c.roof.resource_path)
	var ids := []
	for s in c.walls:
		ok = ok and s != null and library.has(s.resource_path)
		ids.append(s.id)
	# Concrete, brick, cladding, and stone, as the story names them.
	ok = ok and ids.has(&"concrete") and ids.has(&"brick") and ids.has(&"cladding") and ids.has(&"kerb")
	# Every texture the shader samples is one of the library's maps.
	var mat := c.material
	for u in mat.shader.get_shader_uniform_list():
		if u.type == TYPE_OBJECT:
			var tex = mat.get_shader_parameter(u.name)
			if tex == null or not textures.has(tex):
				print("        not from the library: %s" % u.name)
				ok = false
	c.free()
	return ok

func test_each_city_sets_its_own_material() -> bool:
	# The scene's ShaderMaterial is shared; a City must not write into it.
	var probe: City = CITY.instantiate()
	var shared: ShaderMaterial = probe.material
	probe.free()
	var shared_before: Variant = shared.get_shader_parameter("wall_albedo_0")
	var a := _city()
	var other: CityLayout = a.layout.duplicate()
	var b: City = CITY.instantiate()
	var brick_only: Array[SurfaceSet] = [SurfaceSet.named(&"brick")]
	b.walls = brick_only
	b.layout = other
	Sim.add(b)
	var brick: Texture2D = SurfaceSet.named(&"brick").albedo
	var ok: bool = a.material != shared and b.material != shared and a.material != b.material
	ok = ok and (a.get_node("Towers") as MultiMeshInstance3D).material_override == a.material
	ok = ok and shared.get_shader_parameter("wall_albedo_0") == shared_before
	ok = ok and b.material.get_shader_parameter("wall_albedo_0") == brick
	ok = ok and a.material.get_shader_parameter("wall_albedo_0") == a.walls[0].albedo
	ok = ok and a.material.get_shader_parameter("wall_albedo_0") != brick
	a.free()
	b.free()
	return ok

func test_plan_and_collision_unchanged() -> bool:
	var c := _city()
	var plan := CityPlan.build(c.layout)
	var ok: bool = plan.lots == c.plan.lots and plan.heights == c.plan.heights
	var i := 0
	for n in c.get_children():
		if n is CollisionShape3D:
			var lot := plan.lots[i]
			var h := plan.heights[i]
			ok = ok and (n.shape as BoxShape3D).size.is_equal_approx(Vector3(lot.size.x, h, lot.size.y)) \
				and n.position.is_equal_approx(Vector3(lot.get_center().x, h * 0.5, lot.get_center().y))
			i += 1
	ok = ok and i == plan.lots.size()
	c.free()
	return ok

func test_wetness_and_snow_change_the_rendered_city() -> bool:
	# The headless run draws nothing, so a child Godot renders one tower with
	# GL Compatibility (the web renderer) and reports what it saw.
	var out := ProjectSettings.globalize_path("user://city_probe_%d.json" % OS.get_process_id())
	DirAccess.remove_absolute(out)
	var args := ["--path", ProjectSettings.globalize_path("res://"), "--rendering-method", "gl_compatibility",
		"--rendering-driver", "opengl3", "--resolution", "320x180", "-s", PROBE, "--", out]
	var pid := OS.create_process(OS.get_executable_path(), args)
	if pid <= 0:
		print("        could not start the render probe")
		return false
	var start := Time.get_ticks_msec()
	while OS.is_process_running(pid) and Time.get_ticks_msec() - start < PROBE_TIMEOUT_MS:
		await Sim.tree().process_frame
	if OS.is_process_running(pid):
		OS.kill(pid)
	var text := FileAccess.get_file_as_string(out)
	DirAccess.remove_absolute(out)
	var r = JSON.parse_string(text)
	if not r is Dictionary:
		print("        the render probe wrote nothing (needs a display and OpenGL 3.3)")
		return false
	# Wet walls and roofs darken; snow whitens the roof.
	var ok: bool = r.wall_wet < r.wall_dry * 0.9 and r.roof_wet < r.roof_dry * 0.9 \
		and r.roof_snow > r.roof_dry * 1.2 and r.wall_dry > 0.02
	if not ok:
		print("        %s" % r)
	return ok
