extends RefCounted
# Story 15.9: street clutter. Cars, shelters, benches, signs, trees, AC units, and
# pipes placed from the seed, out of the lanes, clearings, and pads, the tall
# ones colliding, every model CC0 with its source listed.

const Sim = preload("res://tests/sim.gd")
const STREETS := preload("res://scenes/world/streets.tscn")
const ROOFTOPS := preload("res://scenes/world/rooftops.tscn")
const LICENSES := "res://data/LICENSES.md"
const K := StreetClutter.Kind

func _clutter(layout: CityLayout = null) -> StreetClutter:
	var s: Streets = STREETS.instantiate()
	if layout:
		s.layout = layout
	Sim.add(s)
	return s.get_node("Clutter")

func _flat(box: AABB) -> Rect2:
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)

func _done(c: StreetClutter) -> void:
	c.streets.free()

func _area(rects: Array) -> float:
	var a := 0.0
	for r: Rect2 in rects:
		a += r.get_area()
	return a

func test_every_kind_is_placed() -> bool:
	var c := _clutter()
	var ok := true
	for k in K.size():
		var n := c.pieces.filter(func(f): return f.kind == k).size()
		if n < 3:
			print("        too few of kind %s: %d" % [K.keys()[k], n])
			ok = false
	_done(c)
	return ok

func test_same_seed_same_placement() -> bool:
	StreetClutter._cache.clear()
	var a := _clutter()
	StreetClutter._cache.clear()
	var b := _clutter()
	var ok := a.pieces.size() == b.pieces.size() and a.pieces.size() > 100 and a.parking == b.parking
	for i in mini(a.pieces.size(), b.pieces.size()):
		if a.pieces[i].kind != b.pieces[i].kind or not a.pieces[i].xform.is_equal_approx(b.pieces[i].xform):
			ok = false
	var other: CityLayout = a.layout.duplicate()
	other.seed += 1
	var d := _clutter(other)
	var same := d.pieces.size() == a.pieces.size()
	for i in mini(a.pieces.size(), d.pieces.size()):
		same = same and d.pieces[i].xform.is_equal_approx(a.pieces[i].xform)
	_done(a)
	_done(b)
	_done(d)
	return ok and not same

func test_nothing_sits_in_a_lane() -> bool:
	var c := _clutter()
	var road := Streets.road_pieces(c.plan, c.layout)
	var road_rects := road.map(func(p): return p[0])
	# Lanes and parking strips cover the road exactly, and each strip is
	# park_width deep against one side of a road piece.
	var ok := not c.lanes.is_empty() and not c.parking.is_empty() \
		and absf(_area(c.lanes) + _area(c.parking) - _area(road_rects)) < 0.5
	for strip in c.parking:
		var on_side := false
		for p in road:
			var r: Rect2 = p[0]
			var ac: int = p[1]
			if p[3] != 2 and r.grow(0.001).encloses(strip) and is_equal_approx(strip.size[ac], c.park_width) \
					and (is_equal_approx(strip.position[ac], r.position[ac]) or is_equal_approx(strip.end[ac], r.end[ac])):
				on_side = true
		ok = ok and on_side
	for f in c.pieces:
		var flat := _flat(f.box).grow(-0.001)
		for lane in c.lanes:
			if lane.intersects(flat):
				print("        %s in a lane at %s" % [K.keys()[f.kind], f.box.get_center()])
				ok = false
				break
		if f.kind == K.CAR and not c.parking.any(func(s): return s.grow(0.01).encloses(_flat(f.box))):
			ok = false
	_done(c)
	return ok

func test_nothing_in_a_clearing() -> bool:
	var c := _clutter()
	var ok := not c.layout.clearings.is_empty()
	for f in c.pieces:
		if not CityPlan.clear_of(c.layout, _flat(f.box)):
			ok = false
	_done(c)
	return ok

func test_nothing_on_a_pad() -> bool:
	var c := _clutter()
	var roofs: Rooftops = Sim.add(ROOFTOPS.instantiate())
	var ok := roofs.pads.size() >= 3
	for f in c.pieces:
		var flat := _flat(f.box)
		for p in roofs.pads:
			var near := Vector2(clampf(p.x, flat.position.x, flat.end.x), clampf(p.z, flat.position.y, flat.end.y))
			if near.distance_to(Vector2(p.x, p.z)) < roofs.pad_radius + 0.5 and f.box.end.y > p.y - 0.5:
				ok = false
	roofs.free()
	_done(c)
	return ok

func test_pavement_pieces_stand_on_the_pavement() -> bool:
	var c := _clutter()
	var ok := true
	for f in c.pieces:
		if f.kind in [K.BENCH, K.SHELTER, K.SIGN, K.TREE]:
			var flat := _flat(f.box)
			var on := c.plan.blocks.any(func(b): return b.grow(-c.streets.kerb_width).encloses(flat))
			var off_lots := not c.plan.lots.any(func(l): return l.intersects(flat))
			if not on or not off_lots or not is_equal_approx(f.xform.origin.y, c.streets.kerb_height):
				ok = false
	_done(c)
	return ok

func test_wall_pieces_keep_off_ledges_and_parts() -> bool:
	var c := _clutter()
	var ok := true
	for f in c.pieces:
		if f.kind != K.AC and f.kind != K.PIPE:
			continue
		var shape: CityPlan.Shape = c.plan.shapes[f.lot]
		# Against a wall of its own lot (touching a box), inside nothing.
		var touches := false
		var clear: bool = f.box.position.y >= -0.001
		for b in shape.boxes:
			clear = clear and not b.intersects(f.box)
			touches = touches or b.grow(0.15).intersects(f.box)
		for t in shape.trims:
			clear = clear and not t.intersects(f.box)
		if not clear or not touches:
			print("        %s on lot %d at %s: clear %s, on a wall %s" % [K.keys()[f.kind], f.lot, f.box, clear, touches])
			ok = false
	_done(c)
	return ok

func test_taller_than_a_bench_collides_with_a_box() -> bool:
	var c := _clutter()
	await Sim.physics_frames(1)
	var bench := c.bench_height()
	var shapes: Array = c.get_children().filter(func(n): return n is CollisionShape3D)
	var tall := c.pieces.filter(func(f): return f.box.size.y > bench + 0.001)
	var ok := shapes.size() == tall.size() and tall.size() > 50 \
		and c.pieces.any(func(f): return f.kind == K.BENCH) \
		and not tall.any(func(f): return f.kind == K.BENCH or f.kind == K.PIT)
	for i in mini(tall.size(), shapes.size()):
		var box: AABB = tall[i].box
		var s: CollisionShape3D = shapes[i]
		ok = ok and s.position.is_equal_approx(box.get_center()) and (s.shape as BoxShape3D).size.is_equal_approx(box.size)
	# A car stops a ray dropped onto it.
	var car: Dictionary = c.pieces.filter(func(f): return f.kind == K.CAR)[0]
	var q := PhysicsRayQueryParameters3D.create(car.box.get_center() + Vector3.UP * 5.0, car.box.get_center())
	var hit := c.get_world_3d().direct_space_state.intersect_ray(q)
	ok = ok and not hit.is_empty() and hit.collider == c
	_done(c)
	return ok

func test_every_model_is_cc0_and_listed() -> bool:
	var c := _clutter()
	var listed := {}
	for line in FileAccess.get_file_as_string(LICENSES).split("\n"):
		var cells := line.split("|")
		if cells.size() >= 4:
			var file := cells[1].strip_edges().trim_prefix("`").trim_suffix("`")
			listed[file] = cells[2].contains("https://polyhaven.com/") and cells[3].strip_edges() == "CC0"
	var ok := true
	for scene: PackedScene in [c.car_model, c.bench_model, c.tree_model, c.aircon_model]:
		var dir := scene.resource_path.get_base_dir()
		ok = ok and dir.begins_with("res://data/models/")
		var files := DirAccess.get_files_at(dir)
		for f in files:
			if f.get_extension() in ["gltf", "bin", "jpg", "png"] and not listed.get(dir.trim_prefix("res://data/") + "/" + f, false):
				print("        unlisted model file: %s/%s" % [dir, f])
				ok = false
	_done(c)
	return ok
