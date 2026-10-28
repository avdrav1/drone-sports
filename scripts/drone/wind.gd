class_name Wind
extends Resource
# Per-scene wind: a steady base vector plus gusts along it, seeded turbulence on
# top, all growing with height by a power law and calmer in the lee of a city's
# buildings (Story 13.4). Deterministic in time, place, and seed.

## Steady wind velocity at REFERENCE_HEIGHT, m/s.
@export var base := Vector3.ZERO
## Peak gust speed added along the base direction, m/s.
@export var gust_amplitude := 0.0
## Seconds between gust peaks.
@export var gust_period := 5.0
## Random buffeting on top of gusts, m/s; 0 is smooth air.
@export var turbulence := 0.0
## Power-law exponent for wind growing with height; 0 is the same at every height.
@export var shear := 0.0
## Seeds the turbulence; the same seed buffets the same way.
@export var seed := 0

## Height where base and gusts are their set values, m.
const REFERENCE_HEIGHT := 10.0
## Shear stops weakening the wind below this height, m.
const MIN_HEIGHT := 1.0
## How far a building's lee reaches downwind, in building heights.
const LEE_LENGTH := 4.0
## Fraction of the wind left right behind a building's wall.
const LEE_FLOOR := 0.3
## Sine modes per axis of turbulence.
const MODES := 3

# [seed, frequencies (rad/s), phases, spatial wave vectors] per axis and mode.
var _turbulence_cache := []

## The wind at `time` and point `at`. Without a point it is the wind at
## REFERENCE_HEIGHT; with a `plan` (a city's, in its local space) a point in a
## building's lee gets less.
func sample(time: float, at := Vector3(0.0, REFERENCE_HEIGHT, 0.0), plan: CityPlan = null) -> Vector3:
	var dir := base.normalized() if base.length_squared() > 0.0 else Vector3.RIGHT
	# Two incommensurate sines so gusts do not feel metronomic.
	var w := TAU / maxf(gust_period, 0.01)
	var gust := 0.5 * (1.0 + 0.7 * sin(w * time) + 0.3 * sin(w * 2.37 * time + 1.3))
	var v := base + dir * gust_amplitude * gust
	if turbulence > 0.0:
		v += _buffet(time, at) * turbulence
	return v * height_factor(at.y) * shelter(at, dir, plan)

## How much stronger the wind is at `height` than at REFERENCE_HEIGHT.
func height_factor(height: float) -> float:
	return pow(maxf(height, MIN_HEIGHT) / REFERENCE_HEIGHT, shear)

## 1 in open air; down to LEE_FLOOR just downwind of a lot taller than `at`,
## recovering over LEE_LENGTH times the lot's height.
static func shelter(at: Vector3, dir: Vector3, plan: CityPlan) -> float:
	if plan == null:
		return 1.0
	var flat := Vector2(dir.x, dir.z)
	if flat.length_squared() < 1e-6:
		return 1.0
	flat = flat.normalized()
	var p := Vector2(at.x, at.z)
	var out := 1.0
	for i in plan.lots.size():
		var h := plan.heights[i]
		if at.y >= h:
			continue
		var lot := plan.lots[i]
		var reach := h * LEE_LENGTH
		if lot.get_center().distance_to(p) > reach + lot.size.length():
			continue
		var back := _upwind_distance(p, -flat, lot)
		if back >= 0.0 and back < reach:
			out = minf(out, lerpf(LEE_FLOOR, 1.0, back / reach))
	return out

## Distance from `p` along `ray` to `r`, or -1 when the ray misses it.
static func _upwind_distance(p: Vector2, ray: Vector2, r: Rect2) -> float:
	var t0 := 0.0
	var t1 := INF
	for a in 2:
		if absf(ray[a]) < 1e-6:
			if p[a] < r.position[a] or p[a] > r.end[a]:
				return -1.0
			continue
		var ta := (r.position[a] - p[a]) / ray[a]
		var tb := (r.end[a] - p[a]) / ray[a]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
	return t0 if t0 <= t1 else -1.0

## Unit-scale buffeting: a few seeded sines per axis, drifting with place so
## two points apart do not shake in step. Vertical is half as strong.
func _buffet(time: float, at: Vector3) -> Vector3:
	if _turbulence_cache.is_empty() or _turbulence_cache[0] != seed:
		_seed_turbulence()
	var freqs: PackedFloat32Array = _turbulence_cache[1]
	var phases: PackedFloat32Array = _turbulence_cache[2]
	var waves: PackedVector3Array = _turbulence_cache[3]
	var out := Vector3.ZERO
	for axis in 3:
		var s := 0.0
		for m in MODES:
			var k := axis * MODES + m
			s += sin(freqs[k] * time + phases[k] + waves[k].dot(at))
		out[axis] = s / MODES
	out.y *= 0.5
	return out

func _seed_turbulence() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var freqs := PackedFloat32Array()
	var phases := PackedFloat32Array()
	var waves := PackedVector3Array()
	for k in 3 * MODES:
		freqs.append(rng.randf_range(0.8, 6.0))
		phases.append(rng.randf_range(0.0, TAU))
		waves.append(Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)))
	_turbulence_cache = [seed, freqs, phases, waves]
