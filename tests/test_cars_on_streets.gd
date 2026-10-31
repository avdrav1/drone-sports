extends RefCounted
# Story 26.11: cars on the streets. Over two minutes of simulated time no two
# cars overlap (moving or parked), every car stays on a lane, and every car
# keeps moving (none stuck for more than 10 s), on the sandbox at seed 7 and
# one rolled city of each pattern. A drone hovering in a lane is pushed by the
# first car to reach it and records the contact, as with a wall. Same seed,
# same cars in the same places at the same time. Parked cars and street
# clutter are unchanged. Free flight at seed 7 has at least 20 cars.

const Sim = preload("res://tests/sim.gd")
const SANDBOX := preload("res://data/city/sandbox_city.tres")
const VARIETY := preload("res://data/city/free_flight_variety.tres")
const STREETS := preload("res://scenes/world/streets.tscn")
const TRAFFIC := preload("res://scenes/world/traffic.tscn")
const FREE_FLIGHT := "res://scenes/debug_flight.tscn"
const ACT1 := preload("res://data/assists/act1.tres")

## Seed 7's sandbox clutter, before traffic: every piece's kind, transform,
## box and tint, then the lanes and parking strips.
const CLUTTER_MD5 := "bb9dc95e4b3cf0635a7676832decdf14"
const LANES_MD5 := "9fe3e4cb740aa531c95da81a4b4c568a"

## The sandbox at seed 7 (a grid), then one rolled city of each other pattern,
## and diagonal 13, where cars crossing behind one another once met a car
## standing on the lane past a junction.
static func _layouts() -> Array[CityLayout]:
	var out: Array[CityLayout] = [SANDBOX]
	for pick in [[CityLayout.Pattern.DIAGONAL, 5555], [CityLayout.Pattern.RADIAL, 222],
			[CityLayout.Pattern.OLD_TOWN, 222], [CityLayout.Pattern.DIAGONAL, 13]]:
		var l := VARIETY.roll(SANDBOX, pick[1])
		l.pattern = pick[0]
		out.append(l)
	return out

## Streets (with their clutter) and traffic built from `l`, in the tree. The
## traffic is stepped by hand: its physics processing is off.
static func _build(l: CityLayout) -> Array:
	var streets: Streets = STREETS.instantiate()
	streets.layout = l
	var traffic: Traffic = TRAFFIC.instantiate()
	streets.add_child(traffic)
	Sim.add(streets)
	await Sim.physics_frames(2)
	traffic.set_physics_process(false)
	return [streets, traffic]

static func _done(streets: Streets) -> void:
	streets.free()
	Streets.prune(SANDBOX)
	StreetClutter.prune(SANDBOX)
	Traffic.prune(SANDBOX)
	CityPlan.prune(SANDBOX)

## True when `p`, or a point 5 cm from it, lies in one of `polys`.
static func _on(p: Vector2, polys: Array[PackedVector2Array]) -> bool:
	for d in [Vector2.ZERO, Vector2(0.05, 0), Vector2(-0.05, 0), Vector2(0, 0.05), Vector2(0, -0.05)]:
		for poly in polys:
			if Geometry2D.is_point_in_polygon(p + d, poly):
				return true
	return false

## Two minutes at 60 steps a second, checked every tenth of a second: no two
## cars' footprints overlap, nor a car and a parked car; every car's centre
## lies on the lanes StreetClutter keeps clear, and on its lane's line; and no
## car stands still for more than 10 s.
func test_two_minutes_no_overlap_on_lanes_and_moving() -> bool:
	var ok := true
	for l in _layouts():
		var built: Array = await _build(l)
		var streets: Streets = built[0]
		var traffic: Traffic = built[1]
		var clutter: StreetClutter = streets.get_node("Clutter")
		# Parked cars by 8 m cell.
		var parked := {}
		for f in clutter.pieces:
			if f.kind == StreetClutter.Kind.CAR:
				var q := clutter._corners(f)
				var cell := Vector2i(((q[0] + q[2]) * 0.125).floor())
				if not parked.has(cell):
					parked[cell] = []
				parked[cell].append(q)
		var n := traffic.cars.size()
		var still := PackedFloat32Array()
		still.resize(n)
		var last := traffic.footprints()
		var worst := 0.0
		var overlaps := 0
		var off_lane := 0
		for tick in 7200:
			traffic.step(1.0 / 60.0)
			if tick % 6 != 5:
				continue
			var feet := traffic.footprints()
			for i in n:
				var a := feet[i]
				var ca := (a[0] + a[2]) * 0.5
				for j in range(i + 1, n):
					if ca.distance_to((feet[j][0] + feet[j][2]) * 0.5) < 6.0 and Streets.overlaps(a, feet[j]):
						overlaps += 1
				var cell := Vector2i((ca * 0.125).floor())
				for x in range(cell.x - 1, cell.x + 2):
					for y in range(cell.y - 1, cell.y + 2):
						for q: PackedVector2Array in parked.get(Vector2i(x, y), []):
							if Streets.overlaps(a, q):
								overlaps += 1
				var c := traffic.cars[i]
				var at := traffic._point(c, c.pos)
				var xf := traffic._pose(c)
				if not _on(at, clutter.lanes) or Vector2(xf.origin.x, xf.origin.z).distance_to(at) > 0.01:
					off_lane += 1
				still[i] = still[i] + 0.1 if ca.distance_to((last[i][0] + last[i][2]) * 0.5) < 0.001 else 0.0
				worst = maxf(worst, still[i])
			last = feet
		var good := n > 0 and overlaps == 0 and off_lane == 0 and worst <= 10.0
		if not good:
			print("        pattern %d seed %d: %d cars, %d overlaps, %d off lane, longest still %.1f s" % [
				l.pattern, l.seed, n, overlaps, off_lane, worst])
		ok = ok and good
		_done(streets)
	return ok

## A route that crosses one junction edge twice holds it for both visits: the
## rear leaving the first lets go of that one only, so the car is never left
## on the second without it.
func test_an_edge_crossed_twice_is_held_for_both_visits() -> bool:
	var edges: Array[Traffic.Edge] = []
	for k in 4:
		var ed := Traffic.Edge.new()
		ed.points = PackedVector2Array([Vector2(k * 4.0, 0), Vector2(k * 4.0 + 4.0, 0)])
		ed.finish()
		edges.append(ed)
	# Edges 1 and 2 are held, and the route runs 0, 1, 2, 1, 3.
	var path := PackedInt32Array([0, 1, 2, 1, 3])
	var claim := PackedInt32Array([1, 2, 1])
	var ok := Traffic._still_held(claim, path, edges, 2.0) == claim
	# Rear past the first visit of 1 (it ends at 8 m along the route).
	ok = ok and Traffic._still_held(claim, path, edges, 9.0) == PackedInt32Array([2, 1])
	# Rear past 2 (12 m): the second visit of 1 is still held.
	ok = ok and Traffic._still_held(claim, path, edges, 13.0) == PackedInt32Array([1])
	return ok and Traffic._still_held(claim, path, edges, 17.0).is_empty()

## Two builds of one layout, stepped alike, put every car in the same place;
## another seed puts them elsewhere.
func test_same_seed_same_cars_at_the_same_time() -> bool:
	var runs := []
	for l in [SANDBOX, SANDBOX, _layouts()[1]]:
		var built: Array = await _build(l)
		var traffic: Traffic = built[1]
		for tick in 900:
			traffic.step(1.0 / 60.0)
		runs.append(traffic.transforms())
		_done(built[0])
	return runs[0].size() >= 20 and runs[0] == runs[1] and runs[0] != runs[2]

## A drone hovering in a lane, a little ahead of a car with clear road to it,
## is pushed on by that car (the first to reach it) and records the contact,
## as flying into a wall does.
func test_a_drone_hovering_in_a_lane_is_pushed() -> bool:
	var avoid := AvoidContact.new()
	var job := Job.new()
	job.time_limit = 60.0
	var root := Sim.job_setup(job, [avoid])
	var streets: Streets = STREETS.instantiate()
	streets.layout = SANDBOX
	var traffic: Traffic = TRAFFIC.instantiate()
	streets.add_child(traffic)
	root.add_child(streets)
	var d: Drone = root.get_node("Drone")
	var src := Sim.FixedSource.new()
	d.add_child(src)
	d.intent_source = src
	d.assists.apply_stack(ACT1)
	await Sim.go_live(root)
	# A car on a straight run of lane with nothing ahead of it for 20 m.
	var pick := -1
	var spot := Vector2.ZERO
	var heading := Vector2.ZERO
	var half := traffic.car_size.y * 0.5
	var occ := traffic._occupancy()
	for i in traffic.cars.size():
		var c := traffic.cars[i]
		var lane := traffic.graph.edges[c.path[0]]
		var ahead := lane.length - (c.pos + half)
		if lane.guarded() or lane.points.size() != 2 or ahead < 16.0:
			continue
		var clear := true
		for v: Vector3 in occ.get(c.path[0], []):
			if int(v.z) != i and v.x > c.pos:
				clear = false
		if clear:
			pick = i
			spot = lane.at(c.pos + half + 12.0)
			heading = (lane.points[1] - lane.points[0]).normalized()
			break
	if pick < 0:
		root.free()
		return false
	var start := Vector3(spot.x, 0.7, spot.y)
	d.reset(Transform3D(d.global_basis, start))
	var hits := []
	d.body_entered.connect(func(b): hits.append(b))
	await Sim.physics_frames(60 * 6)
	var moved := Vector2(d.global_position.x - start.x, d.global_position.z - start.z)
	var ok: bool = hits.size() >= 1 and hits[0] == traffic.cars[pick].body and avoid.contacts >= 1 \
		and moved.dot(heading) > 1.0
	if not ok:
		print("        hits %s, contacts %d, pushed %.2f m" % [hits, avoid.contacts, moved.dot(heading)])
	root.free()
	Traffic.prune(SANDBOX)
	return ok

## Every car is an AnimatableBody3D with one box, drawn through one MultiMesh
## of the parked-car model, tinted per car from the parked cars' tints.
func test_cars_are_moving_bodies_drawn_through_one_multimesh() -> bool:
	var built: Array = await _build(SANDBOX)
	var streets: Streets = built[0]
	var traffic: Traffic = built[1]
	var clutter: StreetClutter = streets.get_node("Clutter")
	var meshes := traffic.find_children("*", "MultiMeshInstance3D", false, false)
	var ok := meshes.size() == 1 and traffic.cars.size() >= 20
	if ok:
		var mm: MultiMesh = (meshes[0] as MultiMeshInstance3D).multimesh
		ok = mm.instance_count == traffic.cars.size() and mm.use_colors \
			and mm.mesh == clutter._mesh(StreetClutter.Kind.CAR)
		for i in traffic.cars.size():
			var body := traffic.cars[i].body
			var shapes := body.get_children().filter(func(n): return n is CollisionShape3D)
			ok = ok and body is AnimatableBody3D and shapes.size() == 1 and shapes[0].shape is BoxShape3D \
				and clutter.car_tints.has(traffic.cars[i].tint)
	_done(streets)
	return ok

## Seed 7's parked cars, clutter, lanes and parking strips are as they were
## before traffic, with traffic driving among them.
func test_parked_cars_and_clutter_unchanged() -> bool:
	var built: Array = await _build(SANDBOX)
	var streets: Streets = built[0]
	var traffic: Traffic = built[1]
	for tick in 120:
		traffic.step(1.0 / 60.0)
	var clutter: StreetClutter = streets.get_node("Clutter")
	var text := ""
	for f in clutter.pieces:
		text += "%d %s %s %s|" % [f.kind, f.xform, f.box, f.tint]
	var strips := ""
	for q in clutter.lanes:
		strips += str(q)
	for q in clutter.parking:
		strips += str(q)
	var ok := text.md5_text() == CLUTTER_MD5 and strips.md5_text() == LANES_MD5
	_done(streets)
	return ok

## Free flight at seed 7 drives at least 20 cars; a reroll drives the new
## city's and keeps one layout in the cache. No job scene has traffic.
func test_free_flight_at_seed_7_has_20_cars_and_jobs_have_none() -> bool:
	var s: Node = load(FREE_FLIGHT).instantiate()
	s.use_city_seed(7)
	Sim.add(s)
	await Sim.physics_frames(3)
	var traffic: Traffic = s.get_node("Streets/Traffic")
	var ok: bool = traffic.layout == s.city.layout and traffic.cars.size() >= 20
	s.reroll_city()
	await Sim.physics_frames(3)
	ok = ok and traffic.layout == s.city.layout and traffic.cars.size() > 0 and Traffic._cache.size() == 1 \
		and traffic.find_children("*", "AnimatableBody3D", false, false).size() == traffic.cars.size()
	s.free()
	for file in DirAccess.get_files_at("res://scenes/jobs"):
		if file.ends_with(".tscn"):
			ok = ok and not FileAccess.get_file_as_string("res://scenes/jobs/" + file).contains("traffic.tscn")
	return ok
