extends RefCounted
# Story 15.7: streets. Every block has a kerb on each street side, with
# collision; every crossing has crosswalks; decals repeat with the seed and sit
# on the road clear of the crosswalks; wetness and snow still change what the
# road shader draws. The road shader reads its markings and decals from vertex
# data Streets writes, so the tests check that data, not the render.

const Sim = preload("res://tests/sim.gd")
const STREETS := preload("res://scenes/world/streets.tscn")
const PROBE := "res://tests/streets_render_probe.gd"
const PROBE_TIMEOUT_MS := 60000

func _streets(layout: CityLayout = null) -> Streets:
	var s: Streets = STREETS.instantiate()
	if layout:
		s.layout = layout
	return Sim.add(s)

func _drawn_blocks(s: Streets) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for b in s.plan.blocks:
		if CityPlan.inside(b, s.layout.core_radius):
			out.append(b)
	return out

func _solid(s: Streets, p: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = p
	return s.get_world_3d().direct_space_state.intersect_point(q).any(func(h): return h.collider == s)

func test_every_block_has_a_kerb_on_each_side() -> bool:
	var s := _streets()
	await Sim.physics_frames(2)
	var blocks := _drawn_blocks(s)
	var ok: bool = blocks.size() > 10 and s.kerbs.size() == blocks.size() * 4 \
		and (s.get_node("Kerbs") as MultiMeshInstance3D).multimesh.instance_count == s.kerbs.size()
	var h := s.kerb_height
	for b in blocks:
		# Each side: a kerb along the whole edge, kerb_width deep, standing on
		# the street, solid in its middle and at both ends of the edge.
		var sides := [
			[Vector2(b.position.x, b.position.y), Vector2(b.end.x, b.position.y), Vector2(0, 1)],
			[Vector2(b.position.x, b.end.y), Vector2(b.end.x, b.end.y), Vector2(0, -1)],
			[Vector2(b.position.x, b.position.y), Vector2(b.position.x, b.end.y), Vector2(1, 0)],
			[Vector2(b.end.x, b.position.y), Vector2(b.end.x, b.end.y), Vector2(-1, 0)],
		]
		for side in sides:
			var inward: Vector2 = side[2] * s.kerb_width * 0.5
			var found := false
			for k in s.kerbs:
				var foot := Rect2(k.position.x, k.position.z, k.size.x, k.size.z)
				if foot.grow(0.001).has_point(side[0] + inward + (side[1] - side[0]).normalized() * 0.4) \
						and is_equal_approx(k.position.y, 0.0) and is_equal_approx(k.size.y, h) and b.grow(0.001).encloses(foot):
					found = true
			for t in [0.02, 0.5, 0.98]:
				var at: Vector2 = side[0].lerp(side[1], t) + inward
				found = found and _solid(s, Vector3(at.x, h * 0.5, at.y))
			ok = ok and found
		# The pavement behind the kerb is raised to its top and solid too.
		var c := b.get_center()
		ok = ok and _solid(s, Vector3(b.position.x + 1.0, h * 0.5, c.y)) and not _solid(s, Vector3(c.x, h + 0.05, c.y))
	# The road between blocks stays clear.
	for piece in Streets.road_pieces(s.plan, s.layout):
		var rc: Vector2 = (piece[0] as Rect2).get_center()
		ok = ok and not _solid(s, Vector3(rc.x, 0.05, rc.y))
	s.free()
	return ok

func test_every_crossing_has_crosswalks() -> bool:
	var s := _streets()
	var pieces := Streets.road_pieces(s.plan, s.layout)
	var crossings := 0
	var ok := s.crosswalks.size() > 0
	for c in pieces:
		if c[3] != 2:
			continue
		crossings += 1
		var square: Rect2 = c[0]
		var approaches := 0
		for piece in pieces:
			var r: Rect2 = piece[0]
			if piece[3] == 2 or not r.grow(0.01).intersects(square) or r.intersection(square.grow(0.01)).get_area() > 0.5:
				continue
			# A segment meeting this crossing: a crosswalk on it, across its whole
			# width, starting CROSSWALK_GAP from the crossing.
			approaches += 1
			var al := 1 - int(piece[1])
			var has := false
			for cw in s.crosswalks:
				if not r.grow(0.001).encloses(cw) or absf(cw.size[1 - al] - r.size[1 - al]) > 0.01:
					continue
				var gap := minf(absf(cw.position[al] - square.end[al]), absf(cw.end[al] - square.position[al]))
				if absf(gap - Streets.CROSSWALK_GAP) < 0.01:
					has = true
			ok = ok and has
		ok = ok and approaches >= 2
	ok = ok and crossings > 5
	s.free()
	return ok

## Decals as plain values, for comparing two builds.
func _decal_list(s: Streets) -> Array:
	var out := []
	for d in s.decals:
		out.append([d[0], d[1], d[2]])
	return out

func test_decal_placement_repeats_with_the_seed() -> bool:
	Streets._cache.clear()
	var a := _streets()
	var first := _decal_list(a)
	var walks := a.crosswalks.duplicate()
	var kinds := {}
	for d in first:
		kinds[d[0]] = true
	var pieces := Streets.road_pieces(a.plan, a.layout)
	# Every decal lies on one road segment; arrows, manholes, and drains miss
	# the crosswalks.
	var placed := true
	for d in a.decals:
		var on := false
		for piece in pieces:
			if piece[3] != 2 and (piece[0] as Rect2).grow(0.001).encloses(d[1]):
				on = true
		if d[0] != Streets.Mark.PATCH:
			for cw in a.crosswalks:
				on = on and not cw.intersects(d[1])
		placed = placed and on and d[2] >= 0
	# Each manhole reaches the shader: a road vertex carries it in CUSTOM1.
	var arrays: Array = (a.get_node("Road") as MeshInstance3D).mesh.surface_get_arrays(0)
	var custom1: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
	var centres := {}
	for v in range(0, custom1.size(), 4):
		if custom1[v + 3] > 0.5:
			centres[Vector2(snappedf(custom1[v], 0.01), snappedf(custom1[v + 1], 0.01))] = true
	var manholes := first.filter(func(d): return d[0] == Streets.Mark.MANHOLE)
	var reached := manholes.size() == centres.size()
	a.free()
	Streets._cache.clear()
	var b := _streets()
	var repeats: bool = _decal_list(b) == first and b.crosswalks == walks
	var other: CityLayout = b.layout.duplicate()
	other.seed += 1
	b.free()
	var c := _streets(other)
	var differs: bool = _decal_list(c) != first
	c.free()
	var all_kinds := kinds.size() == Streets.Mark.size()
	if not (placed and reached and repeats and differs and all_kinds):
		print("        %s %s %s %s %s" % [placed, reached, repeats, differs, all_kinds])
	return placed and reached and repeats and differs and all_kinds

func test_wetness_and_snow_still_apply() -> bool:
	# The headless run draws nothing, so a child Godot renders the road, a
	# pavement, and a kerb with GL Compatibility (the web renderer).
	var shader_ok := true
	var code := (load("res://scenes/world/streets.gdshader") as Shader).code
	for g in ["global uniform float wetness", "global uniform float snow_cover"]:
		shader_ok = shader_ok and code.contains(g)
	var out := ProjectSettings.globalize_path("user://streets_probe_%d.json" % OS.get_process_id())
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
	var ok: bool = shader_ok and (r.errors as Array).is_empty()
	for view in ["road", "walk", "kerb"]:
		ok = ok and r[view + "_dry"] > 0.02 and r[view + "_wet"] < r[view + "_dry"] * 0.9 \
			and r[view + "_snow"] > r[view + "_dry"] * 1.2
	if not ok:
		print("        %s" % r)
	return ok
