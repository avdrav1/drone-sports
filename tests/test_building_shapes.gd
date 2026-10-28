extends RefCounted
# Story 15.6: building shapes. Each lot's shape (stacked boxes plus parapets,
# ledges, and plant rooms) comes from the seed, stays on its lot, and collides
# box for box; wind shelter and the radar still read the lot and its height.

const Sim = preload("res://tests/sim.gd")
const SANDBOX := preload("res://data/city/sandbox_city.tres")
const CITY := preload("res://scenes/world/city.tscn")

## A fresh generation, bypassing the cache.
func _fresh(layout: CityLayout) -> CityPlan:
	CityPlan._cache.clear()
	return CityPlan.build(layout)

## Everything a shape is, for comparing plans.
func _dump(p: CityPlan) -> Array:
	var out := []
	for s in p.shapes:
		out.append([s.boxes, s.trims, s.trim_kinds, s.roof_clear])
	return out

func _flat(b: AABB) -> Rect2:
	return Rect2(b.position.x, b.position.z, b.size.x, b.size.z)

func test_same_seed_same_shapes() -> bool:
	var a := _dump(_fresh(SANDBOX))
	var b := _dump(_fresh(SANDBOX.duplicate()))
	var other: CityLayout = SANDBOX.duplicate()
	other.seed += 1
	var c := _fresh(other)
	var p := _fresh(SANDBOX)
	var same: bool = a == b and a.size() == p.lots.size()
	var differs: bool = _dump(c) != a
	# Every kind of shape turns up: podiums or setbacks, several setbacks,
	# ledges, parapets, and plant rooms; and towers differ from one another.
	var stacked := 0
	var tall := 0
	var kinds := {}
	var distinct := {}
	for s in p.shapes:
		stacked += 1 if s.boxes.size() > 1 else 0
		tall += 1 if s.boxes.size() > 2 else 0
		for k in s.trim_kinds:
			kinds[k] = true
		var rel := []
		for box in s.boxes:
			rel.append(snappedf(box.size.y, 0.1))
		rel.append(s.trim_kinds.size())
		distinct[str(rel)] = true
	var varied: bool = stacked > p.lots.size() / 5 and tall > 3 and kinds.size() == CityPlan.Trim.size() \
		and distinct.size() > p.lots.size() * 3 / 4
	if not (same and differs and varied):
		print("        %s %s %s (stacked %d, three or more %d, kinds %d, distinct %d of %d)" % [same, differs,
			varied, stacked, tall, kinds.size(), distinct.size(), p.lots.size()])
	return same and differs and varied

func test_no_part_leaves_its_lot() -> bool:
	var p := CityPlan.build(SANDBOX)
	var ok := p.shapes.size() == p.lots.size()
	for i in p.lots.size():
		var s := p.shapes[i]
		var lot := p.lots[i].grow(0.001)
		var parts: Array[AABB] = s.boxes.duplicate()
		parts.append_array(s.trims)
		for b in parts:
			if not lot.encloses(_flat(b)) or b.position.y < 0.0 or not b.has_volume():
				print("        lot %d: %s leaves %s" % [i, b, p.lots[i]])
				ok = false
		# Boxes stack: each stands on the last, inside its footprint, from the
		# street to the lot's height.
		ok = ok and is_zero_approx(s.boxes[0].position.y) and is_equal_approx(s.top().end.y, p.heights[i])
		for j in range(1, s.boxes.size()):
			ok = ok and is_equal_approx(s.boxes[j].position.y, s.boxes[j - 1].end.y) \
				and _flat(s.boxes[j - 1]).grow(0.001).encloses(_flat(s.boxes[j]))
		ok = ok and _flat(s.top()).grow(0.001).encloses(s.roof_clear)
	return ok

func test_collision_matches_each_stacked_box() -> bool:
	var c: City = Sim.add(CITY.instantiate())
	await Sim.physics_frames(2)
	var shapes: Array[CollisionShape3D] = []
	for n in c.get_children():
		if n is CollisionShape3D:
			shapes.append(n)
	var boxes := 0
	var plants := 0
	var parapets := 0
	var ok := true
	for s in c.plan.shapes:
		for j in s.trims.size():
			if s.trim_kinds[j] == CityPlan.Trim.PLANT or s.trim_kinds[j] == CityPlan.Trim.PARAPET:
				if s.trim_kinds[j] == CityPlan.Trim.PLANT:
					plants += 1
				else:
					parapets += 1
				ok = ok and shapes.any(func(n): return n.position.is_equal_approx(s.trims[j].get_center()) \
					and (n.shape as BoxShape3D).size.is_equal_approx(s.trims[j].size))
		for b in s.boxes:
			boxes += 1
			ok = ok and shapes.any(func(n): return n.position.is_equal_approx(b.get_center()) \
				and (n.shape as BoxShape3D).size.is_equal_approx(b.size))
	ok = ok and plants > 0 and parapets > 0 and shapes.size() == boxes + plants + parapets
	# The drone can land on a setback: a ray down onto a lower box's roof,
	# beside the box above and inside the parapet, stops on that roof.
	var space := c.get_world_3d().direct_space_state
	var landed := 0
	for s in c.plan.shapes:
		for j in s.boxes.size() - 1:
			var low := _flat(s.boxes[j]).grow(-1.0)
			var high := _flat(s.boxes[j + 1]).grow(0.5)
			for at in [low.position, low.end, Vector2(low.position.x, low.end.y), Vector2(low.end.x, low.position.y)]:
				if high.has_point(at):
					continue
				var from := Vector3(at.x, 200.0, at.y)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 400.0))
				if hit.is_empty() or hit.collider != c:
					continue
				ok = ok and is_equal_approx(hit.position.y, s.boxes[j].end.y)
				landed += 1
				break
	ok = ok and landed > 5
	# Parapets are solid: a ray flown level across a roof, halfway up the
	# parapet, stops on the parapet's outer face, never on the roof inside.
	var walled := 0
	for s in c.plan.shapes:
		for j in s.trims.size():
			if s.trim_kinds[j] != CityPlan.Trim.PARAPET or walled >= 40:
				continue
			var t := s.trims[j]
			var mid := t.get_center()
			var thin_x := t.size.x < t.size.z
			var out := Vector3.RIGHT if thin_x else Vector3.BACK
			# Out past the roof's edge: away from the middle of the box it stands on.
			var under := s.boxes[0]
			for b in s.boxes:
				if is_equal_approx(b.end.y, t.position.y):
					under = b
			if (mid - under.get_center()).dot(out) < 0.0:
				out = -out
			var face := mid + out * (t.size.x if thin_x else t.size.z) * 0.5
			var from := face + out * 3.0
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, face - out * 3.0))
			if hit.is_empty() or hit.collider != c:
				ok = false
				continue
			# Either the parapet's face or something nearer (a neighbour's wall).
			ok = ok and (hit.position - from).dot(-out) <= 3.0 + 0.001
			walled += 1
	ok = ok and walled > 20
	c.free()
	return ok

func test_wind_shelter_and_radar_read_the_lot() -> bool:
	var c: City = Sim.add(CITY.instantiate())
	var p := c.plan
	# The plan's lots and heights, without shapes, shelter exactly as the full plan.
	var bare := CityPlan.new()
	bare.lots = p.lots
	bare.heights = p.heights
	var ok := true
	var tallest := 0
	for i in p.lots.size():
		ok = ok and is_equal_approx(p.heights[i], p.shapes[i].top().end.y)
		for b in p.shapes[i].boxes:
			ok = ok and b.end.y <= p.heights[i] + 0.001
		if p.heights[i] > p.heights[tallest]:
			tallest = i
	var lot := p.lots[tallest]
	var h := p.heights[tallest]
	for y in [h * 0.5, h - 0.5, h + 0.5]:
		var at := Vector3(lot.end.x + 1.0, y, lot.get_center().y)
		ok = ok and Wind.shelter(at, Vector3.RIGHT, p) == Wind.shelter(at, Vector3.RIGHT, bare)
	# Sheltered just under the tallest height, open just above it.
	var lee := Vector3(lot.end.x + 1.0, h - 0.5, lot.get_center().y)
	ok = ok and Wind.shelter(lee, Vector3.RIGHT, p) < 0.5 and Wind.shelter(lee + Vector3.UP, Vector3.RIGHT, p) == 1.0
	# The radar's footprints are the ground lots.
	ok = ok and Radar.footprints(c) == p.lots
	c.free()
	return ok

func test_pads_and_clutter_on_the_top_box() -> bool:
	var r: Rooftops = Sim.add(load("res://scenes/world/rooftops.tscn").instantiate())
	var ok := r.pads.size() >= 3
	for pad in r.pads:
		var on := false
		for i in r.plan.lots.size():
			var s := r.plan.shapes[i]
			var clear := s.roof_clear.grow(-r.pad_radius)
			if is_equal_approx(pad.y, r.plan.heights[i]) and clear.grow(0.001).has_point(Vector2(pad.x, pad.z)):
				on = true
		ok = ok and on
	for f in r.pieces:
		var s: CityPlan.Shape = r.plan.shapes[f.lot]
		for j in s.trims.size():
			if s.trim_kinds[j] == CityPlan.Trim.PLANT and _flat(s.trims[j]).intersects(f.foot):
				ok = false
	r.free()
	return ok

## No trim's top face lies in a roof's plane over that roof (coplanar faces
## z-fight), and no two ledges overlap.
func test_cornices_do_not_cover_roofs() -> bool:
	var p := CityPlan.build(SANDBOX)
	var ok := true
	var cornices := 0
	for i in p.shapes.size():
		var s := p.shapes[i]
		var ledges: Array[AABB] = []
		for j in s.trims.size():
			var t := s.trims[j]
			if s.trim_kinds[j] != CityPlan.Trim.LEDGE:
				continue
			for prev in ledges:
				if prev.intersects(t):
					print("        lot %d: ledges %s and %s overlap" % [i, prev, t])
					ok = false
			ledges.append(t)
			for b in s.boxes:
				if not is_equal_approx(t.end.y, b.end.y):
					continue
				cornices += 1
				var under := _flat(b).grow(-0.001)
				if under.intersects(_flat(t)):
					print("        lot %d: cornice %s lies on roof %s" % [i, t, b])
					ok = false
	if cornices == 0:
		print("        no cornices to check")
	return ok and cornices > 0
