extends RefCounted
# Story 26.9: ducts and pipes overhead. Spans cross streets wall to wall between
# facing buildings, single ducts and racks of two or three pipes. Every span
# starts and ends on a wall and passes through no building, rooftop piece, or
# other span; every gap under a span and between a rack's pipes meets the
# epic's collision-guard rule; every span collides, and a ray up from the
# street under it hits it at its clear height. Same seed, same spans. The
# sandbox at seed 7 has at least 15.

const Sim = preload("res://tests/sim.gd")
const Old = preload("res://tests/test_winding_old_town.gd")
const SANDBOX := preload("res://data/city/sandbox_city.tres")
const VARIETY := preload("res://data/city/free_flight_variety.tres")
const CITY := preload("res://scenes/world/city.tscn")
const STREETS := preload("res://scenes/world/streets.tscn")
const ROOFTOPS := preload("res://scenes/world/rooftops.tscn")
const SPANS := preload("res://scenes/world/overhead_spans.tscn")
const FREE_FLIGHT := "res://scenes/debug_flight.tscn"

## Seed 7's sandbox, then two rolled free-flight cities of each pattern.
static func _layouts() -> Array[CityLayout]:
	var out: Array[CityLayout] = [SANDBOX]
	for pattern in CityLayout.Pattern.values():
		for k in 2:
			var l := VARIETY.roll(SANDBOX, 2609 + pattern * 977 + k * 4127)
			l.pattern = pattern
			out.append(l)
	return out

## [city, streets, spans, rooftops] built from `l`, in the tree.
static func _build(l: CityLayout) -> Array:
	var city: City = CITY.instantiate()
	city.layout = l
	var streets: Streets = STREETS.instantiate()
	streets.layout = l
	var spans: OverheadSpans = SPANS.instantiate()
	streets.add_child(spans)
	var roofs: Rooftops = ROOFTOPS.instantiate()
	roofs.layout = l
	for n in [city, streets, roofs]:
		Sim.add(n)
	await Sim.physics_frames(2)
	return [city, streets, spans, roofs]

static func _done(built: Array) -> void:
	for n in [built[0], built[1], built[3]]:
		n.free()
	City.prune(SANDBOX)
	Streets.prune(SANDBOX)
	StreetClutter.prune(SANDBOX)
	OverheadSpans.prune(SANDBOX)
	Rooftops.prune(SANDBOX)
	CityPlan.prune(SANDBOX)

## The least gap the epic's rule allows: the width of a sphere round the
## drone's collision box plus the guard's margin, and half again to spare.
static func _need() -> float:
	return Old._guard_size() * 3.0

## True when footprint `poly` over heights `y` shares space with box `b`.
static func _meets(poly: PackedVector2Array, y: Vector2, b: AABB) -> bool:
	return b.end.y > y.x + 1e-4 and b.position.y < y.y - 1e-4 \
		and Streets.overlaps(poly, CityPlan.polygon(Rect2(b.position.x, b.position.z, b.size.x, b.size.z)))

## Spans start and end on a wall: along its axis, a ray from the span's middle
## at each part's height first meets the city at the span's own near distance,
## each end's face lies wholly inside a stacked box of its lot that stands
## taller than the span, and the two ends are different lots. Between the walls
## a part's box meets nothing that collides (the city, clutter, lights,
## rooftop pieces, other spans), and end to end it shares no space with any
## building box or trim but the two it ends in, any rooftop piece, or any other
## span's part. A box that does cross a building is caught, so the check sees.
func test_every_span_ends_on_walls_and_passes_through_nothing() -> bool:
	var ok := true
	var total := 0
	for l in _layouts():
		var built: Array = await _build(l)
		var city: City = built[0]
		var spans: OverheadSpans = built[2]
		var roofs: Rooftops = built[3]
		var plan := city.plan
		var space := city.get_world_3d().direct_space_state
		var bad := 0
		for si in spans.spans.size():
			var s := spans.spans[si]
			var good := s.lots.size() == 2 and s.lots[0] != s.lots[1]
			for side in 2:
				var lot := s.lots[side]
				var b := plan.shapes[lot].boxes[s.boxes[side]]
				good = good and b.end.y > s.top() and plan.heights[lot] > s.top() and b.position.y <= s.clear
				var tip := s.from if side == 0 else s.to
				var face := s.footprint(tip, tip)
				for q in face:
					good = good and Rect2(b.position.x, b.position.z, b.size.x, b.size.z).grow(-0.01).has_point(q)
				var dir := s.axis * (-1.0 if side == 0 else 1.0)
				var near := -s.near.x if side == 0 else s.near.y
				good = good and near < absf(tip)
				for p in s.parts:
					var y := (p.x + p.y) * 0.5
					var q := PhysicsRayQueryParameters3D.create(Vector3(s.at.x, y, s.at.y),
						Vector3(s.at.x + dir.x * 40.0, y, s.at.y + dir.y * 40.0))
					q.exclude = [spans.get_rid()]
					var hit := space.intersect_ray(q)
					var dist := Vector2(hit.position.x - s.at.x, hit.position.z - s.at.y).length() if hit else INF
					good = good and hit and hit.collider == city and dist >= near - 0.01 and dist < absf(tip)
			for k in s.parts.size():
				var y := s.parts[k]
				var box: Array = s.box(k)
				var shape := BoxShape3D.new()
				shape.size = Vector3(s.near.y - s.near.x - 0.06, (box[0] as Vector3).y - 0.02, s.width - 0.02)
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = shape
				var c := s.at + s.axis * (s.near.x + s.near.y) * 0.5
				q.transform = Transform3D((box[1] as Transform3D).basis, Vector3(c.x, (y.x + y.y) * 0.5, c.y))
				q.exclude = [spans.get_rid()]
				good = good and space.intersect_shape(q, 1).is_empty()
				var whole := s.footprint(s.from, s.to)
				for i in plan.lots.size():
					var sh := plan.shapes[i]
					for j in sh.boxes.size():
						if not ((i == s.lots[0] and j == s.boxes[0]) or (i == s.lots[1] and j == s.boxes[1])):
							good = good and not _meets(whole, y, sh.boxes[j])
					for t in sh.trims:
						good = good and not _meets(whole, y, t)
				for f in roofs.pieces:
					good = good and not _meets(whole, y, AABB(f.base - Vector3(f.size.x, 0, f.size.z) * 0.5, f.size))
				for oi in spans.spans.size():
					if oi != si:
						var o := spans.spans[oi]
						for p in o.parts:
							good = good and not (Streets.overlaps(whole, o.footprint(o.from, o.to))
								and p.y > y.x and p.x < y.y)
			if not good:
				bad += 1
				if bad <= 3:
					print("        seed %d: span %d at %s, %.1f m up, fails its walls or meets something" % [l.seed, si, s.at, s.clear])
		# The checks see: the same box run on through the far wall hits the city.
		var seen := false
		if not spans.spans.is_empty():
			var s := spans.spans[0]
			var shape := BoxShape3D.new()
			shape.size = Vector3(s.to - s.from + 8.0, 0.3, s.width)
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = shape
			var box: Array = s.box(0)
			var c := s.at + s.axis * ((s.from + s.to) * 0.5 + 4.0)
			q.transform = Transform3D((box[1] as Transform3D).basis, Vector3(c.x, s.clear + 0.4, c.y))
			q.exclude = [spans.get_rid()]
			seen = space.intersect_shape(q, 4).any(func(h): return h.collider == city)
		if bad > 0 or (not seen and not spans.spans.is_empty()):
			print("        seed %d (%s): %d of %d spans fail; checks see the city: %s" % [l.seed,
				CityLayout.Pattern.keys()[l.pattern], bad, spans.spans.size(), seen])
			ok = false
		total += spans.spans.size()
		_done(built)
	return ok and total > 0

## Every under-span gap and every gap in a rack is at least the width of the
## drone's guard sphere and half again, as is the layout's span_gap, and each
## span keeps span_gap off every other. A guard-sized sphere swept along the
## street under each span and through each rack gap, and across the street
## from wall to wall under it, hits nothing.
func test_every_gap_meets_the_collision_guard_rule() -> bool:
	var need := _need()
	var radius := Old._guard_size()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var ok := SANDBOX.span_gap >= need
	var racks := 0
	for l in _layouts():
		var built: Array = await _build(l)
		var spans: OverheadSpans = built[2]
		var space := spans.get_world_3d().direct_space_state
		var cast := func(from: Vector3, to: Vector3) -> bool:
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = sphere
			q.transform = Transform3D(Basis(), from)
			q.motion = to - from
			return space.intersect_shape(q, 1).is_empty() and space.cast_motion(q)[0] >= 1.0
		var bad := 0
		for si in spans.spans.size():
			var s := spans.spans[si]
			var good := s.clear >= need and l.span_gap >= need
			# Heights to fly through: under the span, then each gap in a rack.
			var through: Array[float] = [s.clear - radius - 0.05]
			for k in range(1, s.parts.size()):
				var gap := s.parts[k].x - s.parts[k - 1].y
				good = good and gap >= need
				through.append((s.parts[k].x + s.parts[k - 1].y) * 0.5)
			var reach := s.width * 0.5 + radius + 0.5
			var a := Vector3(s.along.x, 0.0, s.along.y) * reach
			var x := Vector3(s.axis.x, 0.0, s.axis.y)
			for y in through:
				var mid := Vector3(s.at.x, y, s.at.y)
				var along_ok: bool = cast.call(mid - a, mid + a)
				# Wall to wall, short of each wall by more than a sill or AC unit.
				var across_ok: bool = cast.call(mid + x * (s.near.x + radius + 1.0), mid + x * (s.near.y - radius - 1.0))
				if not (along_ok and across_ok):
					print("        a sphere at %.2f m (along %s, across %s) hits; parts %s" % [y, along_ok, across_ok, s.parts])
				good = good and along_ok and across_ok
			var room := s.bounds().grow(l.span_gap - 0.01)
			for oi in spans.spans.size():
				good = good and (oi == si or not spans.spans[oi].bounds().intersects(room))
			if s.kind == OverheadSpans.Kind.PIPE:
				racks += 1
				good = good and s.parts.size() >= 2 and s.parts.size() <= 3
			if not good:
				bad += 1
				if bad <= 3:
					print("        seed %d: span %d at %s, %.1f m up, leaves a gap the guard cannot pass" % [l.seed, si, s.at, s.clear])
		if bad > 0:
			ok = false
		_done(built)
	return ok and racks > 0

## Every duct and pipe has one collision box, and a ray straight up from the
## street at a span's middle first meets that span, at its clear height, which
## is never below the tallest street clutter or a street light's head.
func test_every_span_collides_and_a_ray_up_meets_it_at_its_clear_height() -> bool:
	var ok := true
	for l in _layouts():
		var built: Array = await _build(l)
		var streets: Streets = built[1]
		var spans: OverheadSpans = built[2]
		var space := spans.get_world_3d().direct_space_state
		var parts := 0
		var tallest := streets.pole_height
		for f in (streets.get_node("Clutter") as StreetClutter).pieces:
			if f.lot < 0:
				tallest = maxf(tallest, f.box.end.y)
		var bad := 0
		for s in spans.spans:
			parts += s.parts.size()
			var q := PhysicsRayQueryParameters3D.create(Vector3(s.at.x, Streets.ROAD_Y + 0.01, s.at.y),
				Vector3(s.at.x, 200.0, s.at.y))
			var hit := space.intersect_ray(q)
			if not hit or hit.collider != spans or absf(hit.position.y - s.clear) > 0.01 or s.clear < tallest:
				bad += 1
				if bad <= 3:
					print("        seed %d: ray up at %s meets %s, not the span at %.2f m" % [l.seed, s.at,
						hit.get("position", "nothing"), s.clear])
		var shapes := spans.get_children().filter(func(c): return c is CollisionShape3D and c.shape is BoxShape3D)
		if bad > 0 or shapes.size() != parts:
			print("        seed %d: %d bad rays, %d boxes for %d parts" % [l.seed, bad, shapes.size(), parts])
			ok = false
		_done(built)
	return ok

## Same seed, same spans: two builds from scratch match span for span.
func test_same_seed_same_spans() -> bool:
	var ok := true
	for l in [SANDBOX, VARIETY.roll(SANDBOX, 4242)]:
		var runs := []
		for n in 2:
			var built: Array = await _build(l)
			var out := []
			for s in (built[2] as OverheadSpans).spans:
				out.append([s.kind, s.at, s.axis, s.from, s.to, s.width, s.parts, s.lots, s.boxes])
			runs.append(str(out))
			_done(built)
			OverheadSpans._cache.clear()
		ok = ok and runs[0] == runs[1] and runs[0] != "[]"
	return ok

## The sandbox at seed 7 has at least 15 spans, ducts and racks both.
func test_the_sandbox_at_seed_7_has_at_least_15_spans() -> bool:
	var built: Array = await _build(SANDBOX)
	var spans: OverheadSpans = built[2]
	var n := spans.spans.size()
	var racks := spans.spans.filter(func(s): return s.kind == OverheadSpans.Kind.PIPE).size()
	_done(built)
	if n < 15 or racks == 0 or racks == n:
		print("        seed 7: %d spans, %d racks" % [n, racks])
	return SANDBOX.seed == 7 and n >= 15 and racks > 0 and racks < n

## Free flight builds spans for its city, and a reroll rebuilds them for the new
## one, keeping one layout's entries in the cache.
func test_free_flight_has_spans_and_a_reroll_rebuilds_them() -> bool:
	var s: Node = Sim.add(load(FREE_FLIGHT).instantiate())
	await Sim.physics_frames(2)
	var spans: OverheadSpans = s.get_node("Streets/Spans")
	var before := str(spans.spans.map(func(x): return x.at))
	var ok: bool = spans.layout == s.city.layout and spans.get_child_count() > 0
	s.reroll_city()
	await Sim.physics_frames(2)
	ok = ok and spans.layout == s.city.layout and str(spans.spans.map(func(x): return x.at)) != before
	ok = ok and OverheadSpans._cache.size() == 1
	var shapes := spans.get_children().filter(func(c): return c is CollisionShape3D)
	var parts := 0
	for x in spans.spans:
		parts += x.parts.size()
	ok = ok and shapes.size() == parts
	s.free()
	return ok
