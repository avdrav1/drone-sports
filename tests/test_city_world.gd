extends RefCounted
# Story 34.1: a city a job can fly in. `CityWorld` builds the same plan,
# spans, fences and cars as free flight at a layout; with a runner its cars
# hold still through the briefing and countdown and then drive, the same at the
# same live time on every run; a drone that meets a car records contact; the
# scene loads headless with no errors.

const Sim = preload("res://tests/sim.gd")
const SANDBOX := preload("res://data/city/sandbox_city.tres")
const WORLD := preload("res://scenes/world/city_world.tscn")
const FREE_FLIGHT := "res://scenes/debug_flight.tscn"
const ACT1 := preload("res://data/assists/act1.tres")

static func _prune(l: CityLayout) -> void:
	for c in [CityPlan, City, Streets, StreetClutter, OverheadSpans, Fences, Traffic, Rooftops]:
		c.prune(l)

## What a city built: its lots, spans, fence runs, roofs and cars where they stand.
static func _fingerprint(city: City, streets: Streets, rooftops: Rooftops) -> String:
	var t := ""
	t += str(city.plan.lots, city.plan.heights)
	for s: OverheadSpans.Span in (streets.get_node("Spans") as OverheadSpans).spans:
		t += str(s.kind, s.at, s.axis, s.from, s.to, s.width)
	for r: Fences.Run in (streets.get_node("Fences") as Fences).runs:
		t += str(r.a, r.d, r.length, r.height, r.panels.size())
	t += str(rooftops.get_child_count())
	t += str((streets.get_node("Traffic") as Traffic).transforms())
	return t

static func _world(l: CityLayout, runner: JobRunner = null) -> CityWorld:
	var w: CityWorld = WORLD.instantiate()
	w.layout = l
	w.runner = runner
	return w

func test_builds_what_free_flight_builds() -> bool:
	var ff: Node = load(FREE_FLIGHT).instantiate()
	ff.use_city_seed(7)
	Sim.add(ff)
	var layout: CityLayout = ff.city.layout
	var want := _fingerprint(ff.city, ff.streets, ff.rooftops)
	var w := _world(layout)
	Sim.add(w)
	var got := _fingerprint(w.city, w.streets, w.rooftops)
	var ok: bool = w.streets.layout == layout and w.rooftops.layout == layout \
		and w.traffic.cars.size() >= 20 and (w.streets.get_node("Spans") as OverheadSpans).spans.size() > 0 \
		and (w.streets.get_node("Fences") as Fences).runs.size() > 0 and got == want
	if not ok:
		print("        cars %d, same %s" % [w.traffic.cars.size(), got == want])
	w.free()
	ff.free()
	_prune(SANDBOX)
	return ok

## One run of a test job in the sandbox city: the cars when the job goes live,
## after a briefing and countdown, and again at 5 s of live time.
func _run() -> Array:
	var job := Job.new()
	job.time_limit = 60.0
	var root := Sim.job_setup(job)
	var runner: JobRunner = root.get_node("Runner")
	var w := _world(SANDBOX, runner)
	root.add_child(w)
	var spawn := w.traffic.transforms()
	var at_live := []
	runner.state_changed.connect(func(s, _p):
		if s == JobRunner.State.LIVE:
			at_live.append(w.traffic.transforms()))
	runner.begin()
	await Sim.physics_frames(30)
	var briefed := w.traffic.transforms()
	runner.launch()
	while runner.state != JobRunner.State.LIVE:
		await Sim.tree().physics_frame
	while runner.live_time < 5.0:
		await Sim.tree().physics_frame
	var later := w.traffic.transforms()
	root.free()
	_prune(SANDBOX)
	return [spawn, briefed, at_live[0] if at_live else [], later]

func test_cars_wait_for_live_and_match_run_to_run() -> bool:
	var a: Array = await _run()
	var b: Array = await _run()
	var ok: bool = a[0].size() >= 20 and a[1] == a[0] and a[2] == a[0] and a[3] != a[0] and a[3] == b[3]
	if not ok:
		print("        still in briefing %s, at live %s, moved %s, same %s" % [a[1] == a[0], a[2] == a[0], a[3] != a[0], a[3] == b[3]])
	return ok

## A drone hovering in a lane a little ahead of a car with clear road is hit
## by it, and AvoidContact counts it, as in free flight.
func test_a_car_hitting_the_drone_is_contact() -> bool:
	var avoid := AvoidContact.new()
	var job := Job.new()
	job.time_limit = 60.0
	var root := Sim.job_setup(job, [avoid])
	var runner: JobRunner = root.get_node("Runner")
	var w := _world(SANDBOX, runner)
	root.add_child(w)
	var traffic := w.traffic
	var d: Drone = root.get_node("Drone")
	var src := Sim.FixedSource.new()
	d.add_child(src)
	d.intent_source = src
	d.assists.apply_stack(ACT1)
	var pick := -1
	var spot := Vector2.ZERO
	var half := traffic.car_size.y * 0.5
	var occ := traffic._occupancy()
	for i in traffic.cars.size():
		var c := traffic.cars[i]
		var lane := traffic.graph.edges[c.path[0]]
		if lane.guarded() or lane.points.size() != 2 or lane.length - (c.pos + half) < 16.0:
			continue
		var clear := true
		for v: Vector3 in occ.get(c.path[0], []):
			if int(v.z) != i and v.x > c.pos:
				clear = false
		if clear:
			pick = i
			spot = lane.at(c.pos + half + 12.0)
			break
	if pick < 0:
		root.free()
		_prune(SANDBOX)
		return false
	await Sim.go_live(root)
	d.reset(Transform3D(d.global_basis, Vector3(spot.x, 0.7, spot.y)))
	var hits := []
	d.body_entered.connect(func(b): hits.append(b))
	await Sim.physics_frames(60 * 6)
	var ok: bool = hits.size() >= 1 and hits[0] == traffic.cars[pick].body and avoid.contacts >= 1
	if not ok:
		print("        hits %s, contacts %d" % [hits, avoid.contacts])
	root.free()
	_prune(SANDBOX)
	return ok

func test_scene_loads_without_errors() -> bool:
	# The runner's error logger fails this test on any engine or script error.
	var w: CityWorld = WORLD.instantiate()
	Sim.add(w)
	await Sim.process_frames(3)
	var ok := w.city.layout == SANDBOX and w.traffic.cars.size() > 0
	w.free()
	_prune(SANDBOX)
	return ok
