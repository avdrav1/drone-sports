extends RefCounted
# Story 13.4: real wind. Shear makes it stronger with height, a tower's lee is
# calmer than its upwind side, and turbulence repeats with its seed.

const Sim = preload("res://tests/sim.gd")

static func _wind(shear := 0.0, turbulence := 0.0, turb_seed := 0) -> Wind:
	var w := Wind.new()
	w.base = Vector3(6.0, 0.0, 0.0)
	w.gust_amplitude = 2.0
	w.shear = shear
	w.turbulence = turbulence
	w.seed = turb_seed
	return w

## One 20 m square tower, 60 m tall, on the origin.
static func _tower_plan() -> CityPlan:
	var plan := CityPlan.new()
	plan.lots.append(Rect2(-10.0, -10.0, 20.0, 20.0))
	plan.heights.append(60.0)
	return plan

func test_shear_makes_40m_windier_than_5m() -> bool:
	var w := _wind(0.2)
	var t := 1.7
	var by_sample: bool = w.sample(t, Vector3(0, 40, 0)).length() > w.sample(t, Vector3(0, 5, 0)).length()
	# Measured by the flight model at those heights, sim on.
	var high := Sim.drone(Sim.intent(), Vector3(0, 40, 0))
	var low := Sim.drone(Sim.intent(), Vector3(0, 5, 0))
	high.wind = w
	low.wind = w
	var measured: bool = high.wind_velocity().length() > low.wind_velocity().length() * 1.2
	high.free()
	low.free()
	# No shear is the same at every height.
	var flat := _wind(0.0)
	var same: bool = flat.sample(t, Vector3(0, 40, 0)).is_equal_approx(flat.sample(t, Vector3(0, 5, 0)))
	if not (by_sample and measured and same):
		print("        %s %s %s" % [by_sample, measured, same])
	return by_sample and measured and same

func test_lee_of_tower_is_calmer_than_upwind() -> bool:
	var w := _wind()
	var plan := _tower_plan()
	var t := 0.4
	var upwind := w.sample(t, Vector3(-25, 20, 0), plan).length()
	var lee := w.sample(t, Vector3(25, 20, 0), plan).length()
	var above := w.sample(t, Vector3(25, 70, 0), plan).length()
	var calmer: bool = lee < upwind * 0.8 and is_equal_approx(above, upwind)
	# The drone reads a real city's lee: just downwind of its tallest tower.
	var city: City = load("res://scenes/world/city.tscn").instantiate()
	Sim.add(city)
	var tall := 0
	for i in city.plan.heights.size():
		if city.plan.heights[i] > city.plan.heights[tall]:
			tall = i
	var lot := city.plan.lots[tall]
	var behind := Vector3(lot.end.x + 0.5, city.plan.heights[tall] * 0.5, lot.get_center().y)
	var d := Sim.drone(Sim.intent(), behind)
	d.wind = w
	var open: float = w.sample(0.0, behind).length()
	var felt: float = d.wind_velocity().length()
	var in_city: bool = felt < open * 0.5
	d.free()
	city.free()
	if not (calmer and in_city):
		print("        upwind %.2f lee %.2f above %.2f; city %.2f of %.2f" % [upwind, lee, above, felt, open])
	return calmer and in_city

func test_same_seed_same_turbulence() -> bool:
	var a := _wind(0.0, 3.0, 7)
	var b := _wind(0.0, 3.0, 7)
	var other := _wind(0.0, 3.0, 8)
	var smooth := _wind()
	var same := true
	var differs := false
	var buffets := false
	for i in 50:
		var t := i * 0.13
		var p := Vector3(i, 12, -i)
		same = same and a.sample(t, p).is_equal_approx(b.sample(t, p))
		differs = differs or not a.sample(t, p).is_equal_approx(other.sample(t, p))
		buffets = buffets or a.sample(t, p).distance_to(smooth.sample(t, p)) > 0.5
	if not (same and differs and buffets):
		print("        %s %s %s" % [same, differs, buffets])
	return same and differs and buffets
