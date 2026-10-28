extends RefCounted
# Story 12.1: city layout and plan. Streets and lots from a seeded layout.

const SANDBOX := preload("res://data/city/sandbox_city.tres")
const DESERT := preload("res://scenes/world/desert.tscn")

func _plan(seed := -1) -> CityPlan:
	var layout: CityLayout = SANDBOX.duplicate()
	if seed >= 0:
		layout.seed = seed
	return CityPlan.build(layout)

## A fresh generation, bypassing the cache.
func _fresh(layout: CityLayout) -> CityPlan:
	CityPlan._cache.clear()
	return CityPlan.build(layout)

func test_same_layout_same_plan() -> bool:
	var a := _fresh(SANDBOX)
	var b := _fresh(SANDBOX.duplicate())
	var cached := CityPlan.build(SANDBOX) == CityPlan.build(SANDBOX)
	return cached and a != b and a.lots == b.lots and a.heights == b.heights and a.streets == b.streets \
		and a.lots.size() > 50

func test_seed_changes_plan() -> bool:
	var a := _plan(7)
	var b := _plan(8)
	return a.lots != b.lots or a.heights != b.heights

func test_lots_clear_of_streets_lots_and_clearings() -> bool:
	var p := _plan()
	for i in p.lots.size():
		var lot := p.lots[i]
		if not CityPlan.clear_of(SANDBOX, lot):
			return false
		for s in p.streets:
			if lot.intersects(s):
				return false
		for j in range(i + 1, p.lots.size()):
			if lot.intersects(p.lots[j]):
				return false
	# The sandbox reserves a spawn plaza of at least 30 m and the jammer's ground.
	var plaza := false
	var jammer := false
	for c in SANDBOX.clearings:
		plaza = plaza or (Vector2(c.x, c.y).length() < 0.01 and c.z >= 30.0)
		jammer = jammer or Vector2(c.x, c.y).distance_to(Vector2(40, -40)) < 0.01
	return plaza and jammer

func test_lots_inside_core_and_flat_ground() -> bool:
	var terrain: DesertTerrain = DESERT.instantiate()
	var flat := terrain.flat_radius
	terrain.free()
	for lot in _plan().lots:
		if not CityPlan.inside(lot, SANDBOX.core_radius) or not CityPlan.inside(lot, flat):
			return false
	return true

func test_heights_in_range_and_tallest_downtown() -> bool:
	var p := _plan()
	var inner: Array[float] = []
	var outer: Array[float] = []
	for i in p.lots.size():
		var h := p.heights[i]
		if h < SANDBOX.height_min or h > SANDBOX.height_max:
			return false
		var d := p.lots[i].get_center().length()
		if d < SANDBOX.core_radius / 3.0:
			inner.append(h)
		elif d > SANDBOX.core_radius * 2.0 / 3.0:
			outer.append(h)
	if inner.is_empty() or outer.is_empty():
		return false
	var mean := func(xs: Array[float]) -> float:
		return xs.reduce(func(s, x): return s + x, 0.0) / xs.size()
	return mean.call(inner) > mean.call(outer)
