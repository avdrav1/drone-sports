extends RefCounted
# Story 26.3: broken grids. A grid city drops street segments, so blocks merge
# into superblocks and streets end in T-junctions, and some blocks are paved
# squares. With both chances 0 the plan is the one from before; with drops on
# the network stays connected, every clearing touches a street, merged blocks
# are cut into lots, and nothing of the street stands where a street was dropped.

const Sim = preload("res://tests/sim.gd")
const Variety = preload("res://tests/test_city_variety.gd")
const SANDBOX := preload("res://data/city/sandbox_city.tres")
const VARIETY := preload("res://data/city/free_flight_variety.tres")
const DESERT := preload("res://scenes/world/desert.tscn")
const STREETS := preload("res://scenes/world/streets.tscn")

## A rolled free-flight layout for seed `s`, with drops and squares turned up so
## every seed exercises them.
static func _broken(s: int) -> CityLayout:
	var l := VARIETY.roll(SANDBOX, s)
	l.drop_chance = maxf(l.drop_chance, 0.3)
	l.square_chance = maxf(l.square_chance, 0.08)
	return l

static func _text(p: CityPlan) -> String:
	return "%s %s %s %s %s %s %s %s" % [p.lots, p.heights, p.streets, p.street_axis, p.blocks, p.dropped,
		p.squares, p.vacant]

func _flat_radius() -> float:
	var terrain: DesertTerrain = DESERT.instantiate()
	var flat := terrain.flat_radius
	terrain.free()
	return flat

func test_no_drops_no_squares_builds_the_plan_from_before() -> bool:
	var ok := SANDBOX.drop_chance == 0.0 and SANDBOX.square_chance == 0.0 \
		and SANDBOX.pattern == CityLayout.Pattern.GRID
	for s: int in Variety.BEFORE:
		var l: CityLayout = SANDBOX.duplicate()
		l.seed = s
		var p := CityPlan._generate(l)
		var axes_alternate := p.street_axis.size() == p.streets.size()
		for i in p.street_axis.size():
			axes_alternate = axes_alternate and p.street_axis[i] == i % 2
		if Variety._fingerprint(p) != Variety.BEFORE[s] or not p.dropped.is_empty() or not p.squares.is_empty() \
				or not axes_alternate:
			print("        seed %d differs from before" % s)
			ok = false
	return ok

func test_fifty_broken_seeds_stay_connected_and_pass_12_1() -> bool:
	var flat := _flat_radius()
	var ok := true
	var dropped := 0
	var squares := 0
	for k in 50:
		var s := 2000 + k * 7919
		var l := _broken(s)
		var p := CityPlan._generate(l)
		dropped += p.dropped.size()
		squares += p.squares.size()
		if not CityPlan.connected(p.streets):
			print("        seed %d: streets not connected" % s)
			ok = false
		for c in l.clearings:
			if not p.streets.any(func(st): return CityPlan.touches(c, st)):
				print("        seed %d: clearing %s touches no street" % [s, c])
				ok = false
		if not Variety._passes_12_1(l, p, flat):
			print("        seed %d fails the 12.1 checks" % s)
			ok = false
		# Blocks never overlap each other or a street, and each dropped segment
		# lies inside one block.
		for i in p.blocks.size():
			for j in range(i + 1, p.blocks.size()):
				if p.blocks[i].intersects(p.blocks[j]):
					print("        seed %d: blocks %s and %s overlap" % [s, p.blocks[i], p.blocks[j]])
					ok = false
			for st in p.streets:
				if st.grow(-0.01).intersects(p.blocks[i]):
					print("        seed %d: street %s runs into block %s" % [s, st, p.blocks[i]])
					ok = false
		for d in p.dropped:
			if not p.blocks.any(func(b): return b.encloses(d)):
				print("        seed %d: dropped %s in no block" % [s, d])
				ok = false
		for sq in p.squares:
			ok = ok and p.blocks.has(sq) and not p.lots.any(func(lot): return sq.intersects(lot))
	print("        %d segments dropped, %d squares over 50 seeds" % [dropped, squares])
	return ok and dropped > 100 and squares > 10

func test_merged_blocks_are_cut_into_lots() -> bool:
	var ok := true
	var merged := 0
	var across := 0
	for k in 20:
		var s := 300 + k * 104729
		var l := _broken(s)
		var p := CityPlan._generate(l)
		for b in p.blocks:
			var gone := p.dropped.filter(func(d): return b.encloses(d))
			if gone.is_empty() or not CityPlan.inside(b, l.core_radius) or p.squares.has(b):
				continue
			merged += 1
			var inner := b.grow(-l.sidewalk + 0.001)
			var mine := (p.lots + p.vacant).filter(func(lot): return b.intersects(lot))
			if mine.is_empty() and CityPlan.clear_of(l, b):
				print("        seed %d: superblock %s has no lots" % [s, b])
				ok = false
			for lot in mine:
				ok = ok and inner.encloses(lot)
				# A lot standing where the street was: the block is cut as one.
				for d in gone:
					across += int((d as Rect2).intersects(lot))
	print("        %d superblocks, %d lots over a dropped street" % [merged, across])
	return ok and merged > 20 and across > 20

func test_nothing_of_the_street_where_it_was_dropped() -> bool:
	var ok := true
	var checked := 0
	for k in 6:
		var s := 41 + k * 6151
		var l := _broken(s)
		var streets: Streets = STREETS.instantiate()
		streets.layout = l
		Sim.add(streets)
		var clutter: StreetClutter = streets.get_node("Clutter")
		var p := streets.plan
		var pieces := Streets.road_pieces(p, l)
		# Inside a dropped segment, back from the junctions at either end by a
		# sidewalk's depth, is the middle of a superblock.
		var middles: Array[Rect2] = []
		for d in p.dropped:
			var al := 1 if d.size.y > d.size.x else 0
			var m := d
			m.position[al] += l.sidewalk
			m.size[al] -= l.sidewalk * 2.0
			middles.append(m)
		checked += middles.size()
		for m in middles:
			for at in streets.lights:
				if m.has_point(Vector2(at.x, at.z)):
					print("        seed %d: light at %s in a dropped street" % [s, at])
					ok = false
			for f in clutter.pieces:
				if f.kind == StreetClutter.Kind.SIGN and m.intersects(Rect2(f.box.position.x, f.box.position.z, f.box.size.x, f.box.size.z)):
					print("        seed %d: sign in a dropped street" % s)
					ok = false
		for d in p.dropped:
			for piece in pieces:
				if (piece[0] as Rect2).intersects(d):
					print("        seed %d: road %s over dropped %s" % [s, piece[0], d])
					ok = false
			for c in streets.crosswalks:
				ok = ok and not c.intersects(d)
			for dec in streets.decals:
				ok = ok and not (dec[1] as Rect2).intersects(d)
		# Kerbs stay off the road: no pavement ends in mid-road.
		for kerb in streets.kerbs:
			var flat := Rect2(kerb.position.x, kerb.position.z, kerb.size.x, kerb.size.z).grow(-0.01)
			for piece in pieces:
				if flat.intersects(piece[0]):
					print("        seed %d: kerb %s in road %s" % [s, flat, piece[0]])
					ok = false
		# Every lane arrow points at a junction: the end of its segment it is
		# nearer meets another piece of road.
		for dec in streets.decals:
			if dec[0] != Streets.Mark.ARROW:
				continue
			var box: Rect2 = dec[1]
			var mine := pieces.filter(func(pc): return pc[3] != 2 and (pc[0] as Rect2).encloses(box))
			if mine.size() != 1:
				ok = false
				continue
			var r: Rect2 = mine[0][0]
			var al := 1 - int(mine[0][1])
			var c := box.get_center()[al]
			var end := r.position[al] if c - r.position[al] < r.end[al] - c else r.end[al]
			if not Streets.meets(pieces, mine[0], end):
				print("        seed %d: arrow %s points into a dead end" % [s, box])
				ok = false
		streets.free()
		Streets.prune(SANDBOX)
		StreetClutter.prune(SANDBOX)
		CityPlan.prune(SANDBOX)
	return ok and checked > 10

func test_same_seed_same_broken_plan() -> bool:
	var a := CityPlan._generate(_broken(777))
	var b := CityPlan._generate(_broken(777))
	var c := CityPlan._generate(_broken(778))
	return _text(a) == _text(b) and not a.dropped.is_empty() and _text(a) != _text(c)

## The rolled free-flight layouts drop segments too, inside their ranges.
func test_variety_rolls_the_new_fields() -> bool:
	var ok := CityVariety.FIELDS.has(&"drop_chance") and CityVariety.FIELDS.has(&"square_chance")
	var drops := 0
	for k in 20:
		var l := VARIETY.roll(SANDBOX, 9 + k * 31)
		ok = ok and l.drop_chance >= VARIETY.drop_chance.x and l.drop_chance <= VARIETY.drop_chance.y \
			and l.square_chance >= VARIETY.square_chance.x and l.square_chance <= VARIETY.square_chance.y
		drops += CityPlan._generate(l).dropped.size()
	return ok and drops > 0
