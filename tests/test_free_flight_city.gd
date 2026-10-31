extends RefCounted
# Story 26.1: a new city every launch. Free flight builds its city from a fresh
# seed on a copy of the sandbox layout, shows the seed on the HUD, and
# reroll_city builds a new one; jobs keep the layout's own seed 7, and the city
# caches keep one layout's builds however often it rerolls.

const Sim = preload("res://tests/sim.gd")
const Obstacles = preload("res://tests/test_obstacle_structures.gd")
const SANDBOX := "res://scenes/debug_flight.tscn"
const LAYOUT := "res://data/city/sandbox_city.tres"
const JOB_WITH_CITY := "res://scenes/jobs/fleet_inspection.tscn"
const BOSS_JOB := "res://scenes/boss/lattice_job.tscn"

func _launch() -> Node:
	var s: Node = Sim.add(load(SANDBOX).instantiate())
	await Sim.process_frames(2)
	return s

## Every lot, height, and street of a plan, for comparing plans.
static func _plan_text(p: CityPlan) -> String:
	return "%s %s %s" % [p.lots, p.heights, p.streets]

func _press(scene: Node, code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	scene.get_viewport().push_input(ev)
	var up := ev.duplicate()
	up.pressed = false
	scene.get_viewport().push_input(up)

func test_two_launches_build_different_plans() -> bool:
	var a: Node = await _launch()
	var seed_a: int = a.city_seed
	var plan_a := _plan_text((a.get_node("City") as City).plan)
	a.free()
	var b: Node = await _launch()
	var seed_b: int = b.city_seed
	var city: City = b.get_node("City")
	var plan_b := _plan_text(city.plan)
	# The three builders share one copy; the shared resource is not it.
	var shared: bool = (b.get_node("Streets") as Streets).layout == city.layout \
		and (b.get_node("Rooftops") as Rooftops).layout == city.layout and city.layout != load(LAYOUT) \
		and city.layout.seed == seed_b
	b.free()
	return seed_a != seed_b and plan_a != plan_b and shared and seed_a > 0 and seed_b > 0

func test_a_seed_builds_the_same_plan_every_time() -> bool:
	var ok := true
	for s in [7, 12345, 999999]:
		var l: CityLayout = load(LAYOUT).duplicate()
		l.seed = s
		var again: CityLayout = load(LAYOUT).duplicate()
		again.seed = s
		ok = ok and _plan_text(CityPlan._generate(l)) == _plan_text(CityPlan._generate(again)) \
			and not CityPlan._generate(l).lots.is_empty()
	return ok

## Every scene under `dir` but free flight that places the city, streets, or
## rooftops at its root, found from the scene files.
static func _city_scenes(dir := "res://scenes/") -> Array[String]:
	var out: Array[String] = []
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with("/"):
			out.append_array(_city_scenes(dir + f))
		elif f.get_extension() == "tscn" and dir + f != SANDBOX:
			var text := FileAccess.get_file_as_string(dir + f)
			if ["City", "Streets", "Rooftops"].any(func(n): return text.contains('[node name="%s" parent="."' % n)):
				out.append(dir + f)
	return out

func test_jobs_still_build_seed_7() -> bool:
	var s: Node = await _launch()
	var rolled: int = s.city_seed
	s.reroll_city()
	s.free()
	var shared: CityLayout = load(LAYOUT)
	var expected := _plan_text(CityPlan._generate(shared))
	var found := _city_scenes()
	var ok := shared.seed == 7 and rolled != 7 and JOB_WITH_CITY in found and BOSS_JOB in found
	# City, streets, clutter, and rooftops in every scene that shows the city
	# build from the shared layout, seed 7, not a copy free flight made.
	for path in found:
		var job: Node = Sim.add(load(path).instantiate())
		await Sim.process_frames(2)
		var builders := [job.get_node_or_null("City"), job.get_node_or_null("Streets"),
			job.get_node_or_null("Streets/Clutter"), job.get_node_or_null("Rooftops")]
		var good := true
		for b in builders:
			good = good and b != null and b.layout == shared and b.layout.seed == 7 \
				and _plan_text(b.plan) == expected
		if not good:
			print("        %s does not build seed 7" % path)
		ok = ok and good
		job.free()
	# Every job scene's obstacles are as fingerprinted.
	for path in Obstacles.scenes():
		var scene: Node = Sim.add(load(path).instantiate())
		var md5 := Obstacles.fingerprint(scene).md5_text()
		scene.free()
		if Obstacles.FINGERPRINTS.get(path, "") != md5:
			print("        %s: %s" % [path, md5])
			ok = false
	return ok

func test_reroll_changes_the_city_and_puts_the_drone_back() -> bool:
	var s: Node = await _launch()
	var city: City = s.get_node("City")
	var streets: Streets = s.get_node("Streets")
	var rooftops: Rooftops = s.get_node("Rooftops")
	var clutter: StreetClutter = streets.get_node("Clutter")
	var drone: Drone = s.get_node("Drone")
	var hud: FlightHud = s.get_node("HUD/Flight")
	var radar: Radar = s.get_node("HUD/Radar")
	var map: MapScreen = s.get_node("MapLayer/Map")
	var spawn := drone.global_position
	var before_seed: int = s.city_seed
	var before_plan := _plan_text(city.plan)
	var before_lots := Radar.footprints(city)
	var before_radar := radar.texture.get_image().get_data()
	var before_map := map.texture.get_image().get_data()
	var before_status: String = hud.panel().state
	var counts := [city.get_child_count(), streets.get_child_count(), clutter.get_child_count(),
		rooftops.get_child_count()]
	drone.global_position = spawn + Vector3(30, 20, 10)
	_press(s, KEY_B)
	await Sim.process_frames(3)
	var ok: bool = s.city_seed != before_seed and city.layout.seed == s.city_seed
	ok = ok and _plan_text(city.plan) != before_plan and streets.plan == city.plan \
		and rooftops.plan == city.plan and clutter.plan == city.plan
	ok = ok and Radar.footprints(city) != before_lots and Radar.footprints(city) == city.plan.lots
	ok = ok and radar.texture.get_image().get_data() != before_radar and map.texture.get_image().get_data() != before_map
	ok = ok and hud.panel().state != before_status and hud.panel().state.contains(str(s.city_seed))
	ok = ok and drone.global_position.distance_to(spawn) < 0.5
	# The old city is gone, not built over: one set of each builder's nodes.
	ok = ok and city.get_node_or_null("Ambience") != null and streets.get_node_or_null("Clutter") == clutter
	var after := [city.get_child_count(), streets.get_child_count(), clutter.get_child_count(),
		rooftops.get_child_count()]
	# A fresh launch at the new seed builds the same node counts; a build stacked
	# on the old one would have more. (Seeds roll proportions since Story 26.2,
	# so counts differ between cities.)
	var fresh: Node = load(SANDBOX).instantiate()
	fresh.use_city_seed(s.city_seed)
	Sim.add(fresh)
	await Sim.process_frames(2)
	var want := [fresh.get_node("City").get_child_count(), fresh.get_node("Streets").get_child_count(),
		fresh.get_node("Streets/Clutter").get_child_count(), fresh.get_node("Rooftops").get_child_count()]
	fresh.free()
	ok = ok and after == want
	if not ok:
		print("        counts %s -> %s, fresh %s" % [counts, after, want])
	s.free()
	return ok

func test_ten_rerolls_keep_one_layout_in_each_cache() -> bool:
	var s: Node = await _launch()
	var images := TerrainImage._cache.size()
	for i in 10:
		s.reroll_city()
	await Sim.process_frames(2)
	var p: Array = (s.get_node("City") as City).layout.params()
	var ok := CityPlan._cache.size() == 1
	for cache: Dictionary in [CityPlan._cache, City._cache, Streets._cache, StreetClutter._cache, Rooftops._cache]:
		ok = ok and not cache.is_empty()
		for key: Array in cache:
			ok = ok and key.slice(0, p.size()) == p
	# The radar and map keep their ground images; rerolls add none.
	ok = ok and TerrainImage._cache.size() == images
	s.free()
	return ok

func test_reroll_city_is_listed_and_on_the_pad() -> bool:
	return &"reroll_city" in ControlsHelp.listed_actions() and InputPrompt.key_text(&"reroll_city") == "B" \
		and InputMap.action_get_events(&"reroll_city").any(func(e): return e is InputEventJoypadButton \
			and e.button_index == JOY_BUTTON_X)

func test_seed_on_the_hud_at_960_and_1080() -> bool:
	var s: Node = await _launch()
	var hud: FlightHud = s.get_node("HUD/Flight")
	var radar: Radar = s.get_node("HUD/Radar")
	var ok: bool = hud.panel().state.contains("SEED %d" % s.city_seed)
	for screen in [Vector2(960, 720), Vector2(1920, 1080)]:
		hud.size = screen
		radar.size = screen
		var panel := hud.panel_rect()
		# The state line, where _draw_panel puts it: 12 px text at (42, 86).
		var w := hud.font.get_string_size(hud.panel().state, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var line := Rect2(42, 74, w, 16)
		var tape_w := minf(screen.x * 0.42, 560.0)
		var tape := Rect2(screen.x * 0.5 - tape_w * 0.5, 0, tape_w, 82)
		var pilot := Rect2(screen.x - 228.0 - 56.0 - 28.0, 0, 284.0, 90)
		var fits := Rect2(Vector2.ZERO, screen).encloses(panel) and panel.encloses(line) \
			and not line.intersects(tape) and not line.intersects(pilot) and not line.intersects(radar.rect())
		if not fits:
			print("        %s: seed line %s" % [screen, line])
		ok = ok and fits
	s.free()
	return ok
