extends RefCounted
# Story 13.5: lightning. Strike times and places repeat with the seed, a strike
# raises ambient light and returns it within 0.5 s without touching the shared
# Environment, and no strike lands inside the strike range's minimum.

const Sim = preload("res://tests/sim.gd")
const ENV := preload("res://data/world/golden_hour.tres")

static func _storm(per_minute: float, storm_seed: int, range_m := Vector2(400.0, 2000.0)) -> Weather:
	var w := Weather.new()
	w.precipitation = Weather.Precipitation.RAIN
	w.intensity = 0.8
	w.lightning_per_minute = per_minute
	w.storm_seed = storm_seed
	w.strike_distance = range_m
	return w

func _scene() -> Node3D:
	var root := Node3D.new()
	var we := WorldEnvironment.new()
	we.name = "Env"
	we.environment = ENV
	root.add_child(we)
	Sim.add(root)
	return root

func _lightning(root: Node) -> Lightning:
	return WeatherState.of(root).get_node("Lightning")

## Times and places of the strikes a node lands over `seconds`.
func _played(w: Weather, seconds: float) -> Array:
	var root := _scene()
	var lightning := _lightning(root)
	var out := []
	lightning.struck.connect(func(s: Lightning.Strike) -> void: out.append([s.time, s.position]))
	Weather.apply(w, null, root)
	for i in roundi(seconds / 0.05):
		lightning.advance(0.05)
	root.free()
	return out

static func _flat(strikes: Array) -> Array:
	var out := []
	for s in strikes:
		out.append([s.time, s.position])
	return out

func test_strikes_repeat_with_seed() -> bool:
	var a := _flat(Lightning.plan(_storm(12.0, 7), 120.0))
	var b := _flat(Lightning.plan(_storm(12.0, 7), 120.0))
	var c := _flat(Lightning.plan(_storm(12.0, 8), 120.0))
	var played_a := _played(_storm(12.0, 7), 60.0)
	var played_b := _played(_storm(12.0, 7), 60.0)
	var planned_60 := _flat(Lightning.plan(_storm(12.0, 7), 60.0))
	# Rate is roughly per minute; no storm means no strikes.
	var none: bool = Lightning.plan(_storm(0.0, 7), 600.0).is_empty() and _played(_storm(0.0, 7), 10.0).is_empty()
	var ok: bool = a.size() > 10 and a == b and a != c and played_a.size() > 3 \
		and played_a == played_b and played_a == planned_60 and none
	if not ok:
		print("        %d %s %s %d %s %s %s" % [a.size(), a == b, a != c, played_a.size(), played_a == played_b, played_a == planned_60, none])
	return ok

func test_strike_raises_ambient_then_returns_within_half_second() -> bool:
	var before := [ENV.ambient_light_energy, ENV.background_energy_multiplier]
	var root := _scene()
	var lightning := _lightning(root)
	var we: WorldEnvironment = root.get_node("Env")
	Weather.apply(_storm(6.0, 3), null, root)
	var base: float = we.environment.ambient_light_energy
	var sky_base: float = we.environment.background_energy_multiplier
	var hits := [0]
	lightning.struck.connect(func(_s: Lightning.Strike) -> void: hits[0] += 1)
	# Run up to the first strike.
	var guard := 0
	while hits[0] == 0 and guard < 4000:
		lightning.advance(0.01)
		guard += 1
	var raised: bool = hits[0] == 1 and we.environment.ambient_light_energy > base * 1.5 \
		and we.environment.background_energy_multiplier > sky_base
	var has_bolt: bool = lightning.bolt != null
	var after_hits: int = hits[0]
	for i in 50:
		lightning.advance(0.01)
	var back: bool = is_equal_approx(we.environment.ambient_light_energy, base) \
		and is_equal_approx(we.environment.background_energy_multiplier, sky_base)
	var bolt_gone: bool = lightning.bolt == null
	# No second strike inside that half second muddied the check.
	var single: bool = hits[0] == after_hits
	var shared_ok: bool = before == [ENV.ambient_light_energy, ENV.background_energy_multiplier] \
		and we.environment != ENV
	root.free()
	var ok: bool = raised and has_bolt and back and bolt_gone and single and shared_ok
	if not ok:
		print("        %s %s %s %s %s %s" % [raised, has_bolt, back, bolt_gone, single, shared_ok])
	return ok

func test_no_strike_inside_minimum_distance() -> bool:
	var range_m := Vector2(800.0, 1200.0)
	var centre := Vector3(50.0, 0.0, -30.0)
	var strikes := Lightning.plan(_storm(60.0, 11, range_m), 600.0, centre)
	var ok: bool = strikes.size() > 200
	var nearest := INF
	for s in strikes:
		var d := Vector2(s.position.x - centre.x, s.position.z - centre.z).length()
		nearest = minf(nearest, d)
		ok = ok and d >= range_m.x - 0.01 and d <= range_m.y + 0.01
	# Live strikes too, centred on the scene's own origin.
	for p in _played(_storm(60.0, 11, range_m), 30.0):
		var d := Vector2(p[1].x, p[1].z).length()
		ok = ok and d >= range_m.x - 0.01 and d <= range_m.y + 0.01
	if not ok:
		print("        %d strikes, nearest %.1f" % [strikes.size(), nearest])
	return ok
