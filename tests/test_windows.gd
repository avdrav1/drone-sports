extends RefCounted
# Story 15.5: windows. Each building lights a whole number of its windows that
# keeps the fraction within lit_min to lit_max; every window's choice (lit,
# blind, room, lamp) repeats with the seed; the shader compiles under GL
# Compatibility. City.window_at mirrors the shader's choice, since a MultiMesh
# cannot be read back. Story 15.6 lays windows out per stacked box (part).

const Sim = preload("res://tests/sim.gd")
const CITY := preload("res://scenes/world/city.tscn")
const PROBE := "res://tests/city_render_probe.gd"
const PROBE_TIMEOUT_MS := 60000

func _city(layout: CityLayout = null) -> City:
	var c: City = CITY.instantiate()
	if layout:
		c.layout = layout
	return Sim.add(c)

func _count(c: City, i: int) -> int:
	return c.window_count(c.parts[i].size, c.parts[i].position.y)

## Every window choice of a city, part by part.
func _choices(c: City) -> Array:
	var out := []
	for i in c.parts.size():
		var row := []
		for k in _count(c, i):
			row.append(c.window_at(i, k))
		out.append(row)
	return out

func test_lit_fraction_stays_within_range() -> bool:
	var c := _city()
	var ok := true
	var windowed := 0
	# Per building: windows and lit windows over all its parts.
	var totals := {}
	for i in c.parts.size():
		var n := _count(c, i)
		# The shader reads counts and seeds as whole numbers from custom data;
		# keep them where even half floats are exact.
		ok = ok and n < 2048 and c.lit_counts[i] < 2048 and c.window_seeds[i] < 2048
		if n == 0:
			continue
		windowed += 1
		var lit := 0
		for k in n:
			lit += c.window_at(i, k).x
		var fraction := float(lit) / n
		if lit != c.lit_counts[i] or fraction < c.lit_min or fraction > c.lit_max:
			print("        part %d: %d of %d lit, want %d" % [i, lit, n, c.lit_counts[i]])
			ok = false
		var t: Vector2i = totals.get(c.part_lot[i], Vector2i.ZERO)
		totals[c.part_lot[i]] = t + Vector2i(lit, n)
	for lot in totals:
		var f: float = float(totals[lot].x) / totals[lot].y
		ok = ok and f >= c.lit_min and f <= c.lit_max
	# Most towers have windows, and lit counts differ between them.
	ok = ok and totals.size() > c.plan.lots.size() / 2 and windowed > c.parts.size() / 2
	var counts := {}
	for k in c.lit_counts:
		counts[k] = true
	ok = ok and counts.size() > 3
	c.free()
	return ok

func test_window_count_matches_the_grid() -> bool:
	var c := _city()
	# 12 m wide, 9 m deep, 25 m tall: 4 and 3 columns, 6 storeys above 4 m.
	var g := c.window_grid(Vector3(12.0, 25.0, 9.0))
	var ok: bool = g == Vector3i(3, 4, 6) and c.window_count(Vector3(12.0, 25.0, 9.0)) == 2 * 6 * 7
	# A tower no taller than the ground floor has none.
	ok = ok and c.window_count(Vector3(12.0, 4.0, 9.0)) == 0
	# A box standing on a 7.5 m podium has the storeys above it: rows 1 to 5.
	ok = ok and c.window_grid(Vector3(12.0, 17.5, 9.0), 7.5) == Vector3i(3, 4, 5)
	# The shader gets the same grid.
	ok = ok and c.material.get_shader_parameter("window_cell") == c.window_cell \
		and c.material.get_shader_parameter("ground_floor") == c.ground_floor
	c.free()
	return ok

func test_window_choice_repeats_with_the_seed() -> bool:
	var a := _city()
	var first := _choices(a)
	var seeds := a.window_seeds
	var other: CityLayout = a.layout.duplicate()
	other.seed += 1
	a.free()
	City._cache.clear()
	var b := _city()
	var repeats: bool = _choices(b) == first and b.window_seeds == seeds
	# Blinds, rooms, and lamps all vary across the city.
	var kinds := [{}, {}, {}, {}]
	for row in first:
		for w: Vector4i in row:
			for j in 4:
				kinds[j][w[j]] = true
	var varied: bool = kinds[0].size() == 2 and kinds[1].size() == 8 and kinds[2].size() == 4 and kinds[3].size() == 3
	b.free()
	var c := _city(other)
	var differs: bool = c.window_seeds != seeds
	c.free()
	if not (repeats and varied and differs):
		print("        %s %s %s" % [repeats, varied, differs])
	return repeats and varied and differs

func test_shader_compiles_under_gl_compatibility() -> bool:
	# The headless run compiles no shaders, so a child Godot loads the city with
	# GL Compatibility (the web renderer) and reports what it logged and saw.
	var out := ProjectSettings.globalize_path("user://window_probe_%d.json" % OS.get_process_id())
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
	if not r is Dictionary or not r.has("errors"):
		print("        the render probe wrote nothing (needs a display and OpenGL 3.3)")
		return false
	# No shader (or other) errors, and the facade drew.
	var ok: bool = (r.errors as Array).is_empty() and r.windows_dry > 0.02
	if not ok:
		print("        %s" % r)
	return ok
