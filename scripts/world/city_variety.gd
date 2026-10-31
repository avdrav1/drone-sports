class_name CityVariety
extends Resource
# The proportions free flight rolls for each city (Story 26.2): a range for each
# CityLayout field that varies, rolled from the city's seed so one number still
# names one city. Fields left out (the core, sidewalks, storeys, clearings) keep
# the layout's own values. Keep the ranges inside what CityPlan handles: a block
# deep enough for a lot inside its sidewalks, lot_min below lot_max, streets
# narrower than avenues.

## The CityLayout fields rolled, in roll order. Each has a range below.
const FIELDS: Array[StringName] = [&"block_size", &"street_width", &"avenue_width", &"avenue_every",
	&"lot_min", &"lot_max", &"height_min", &"height_max", &"height_falloff", &"vacant_chance",
	&"drop_chance", &"square_chance"]
## Fields rolled as whole numbers.
const WHOLE: Array[StringName] = [&"avenue_every"]
## Fields snapped to a twentieth rather than to `step`.
const FINE: Array[StringName] = [&"height_falloff", &"vacant_chance", &"drop_chance", &"square_chance"]

## (least, most) for each field; metres unless noted.
@export var block_size := Vector2(30, 40)
@export var street_width := Vector2(7, 10)
@export var avenue_width := Vector2(12, 18)
## Every Nth street is an avenue.
@export var avenue_every := Vector2(2, 4)
@export var lot_min := Vector2(11, 13)
@export var lot_max := Vector2(20, 24)
@export var height_min := Vector2(5, 8)
@export var height_max := Vector2(55, 110)
@export var height_falloff := Vector2(0.8, 1.4)
## A chance, 0 to 1.
@export var vacant_chance := Vector2(0, 0.25)
## Chances a grid street segment is dropped and a block is a square (Story 26.3).
@export var drop_chance := Vector2(0.05, 0.3)
@export var square_chance := Vector2(0, 0.1)
## Rolled lengths snap to this many metres, chances and falloff to a twentieth.
@export var step := 0.5
## How often each street pattern comes up (Story 26.6), indexed by
## CityLayout.Pattern; picked from its own stream so the fields above roll as
## before.
@export var pattern_weights := PackedFloat32Array([1.0, 1.0])

## A copy of `base` with seed `s` and every field rolled from it.
func roll(base: CityLayout, s: int) -> CityLayout:
	var out: CityLayout = base.duplicate()
	out.seed = s
	var rng := RandomNumberGenerator.new()
	rng.seed = s + 11
	for f in FIELDS:
		var r: Vector2 = get(f)
		if f in WHOLE:
			out.set(f, rng.randi_range(int(r.x), int(r.y)))
		else:
			var unit := 0.05 if f in FINE else step
			out.set(f, clampf(snappedf(rng.randf_range(r.x, r.y), unit), r.x, r.y))
	out.pattern = pick_pattern(s)
	return out

## The street pattern seed `s` picks, by `pattern_weights` (Story 26.6).
func pick_pattern(s: int) -> CityLayout.Pattern:
	var rng := RandomNumberGenerator.new()
	rng.seed = s + 23
	return rng.rand_weighted(pattern_weights) as CityLayout.Pattern
