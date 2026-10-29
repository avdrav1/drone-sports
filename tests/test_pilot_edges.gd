extends RefCounted
# Story 19.1: pilot edges are data. Each pilot's edge round-trips from data;
# applying it changes only its listed drone stats and assist settings, in free
# flight and on a job; an assist the preset has switched off stays off and
# unchanged; every pilot gets the same assist list.

const Sim = preload("res://tests/sim.gd")
const FREE_FLIGHT := "res://scenes/debug_flight.tscn"
const ACT1 := preload("res://data/assists/act1.tres")
const ACT3 := preload("res://data/assists/act3.tres")
const ROUND_TRIP := "user://test_pilot_edge_round_trip.tres"

## Every exported number on the drone and on each assist, and which assists are on.
func _fingerprint(d: Drone) -> Dictionary:
	var out := {}
	_numbers(d, "", out)
	for a in d.assists.assists():
		_numbers(a, String(a.assist_id) + ".", out)
		out[String(a.assist_id) + ".enabled"] = a.enabled
	return out

func _numbers(o: Object, prefix: String, out: Dictionary) -> void:
	for p in o.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.usage & PROPERTY_USAGE_EDITOR \
				and p.type in [TYPE_FLOAT, TYPE_INT]:
			out[prefix + p.name] = o.get(p.name)

## The drone's fingerprint after a job with these assists begins.
func _on_job(stack: AssistStack) -> Dictionary:
	var job := Job.new()
	job.required_assists = stack
	var root := Sim.job_setup(job)
	(root.get_node("Runner") as JobRunner).begin()
	var out := _fingerprint(root.get_node("Drone"))
	root.free()
	return out

## The drone's fingerprint in free flight, after F2 cycles `cycles` presets on.
func _in_free_flight(cycles := 0) -> Dictionary:
	var scene: Node = Sim.add(load(FREE_FLIGHT).instantiate())
	for i in cycles:
		scene.cycle_preset()
	var out := _fingerprint(scene.get_node("Drone"))
	scene.free()
	return out

## `measure` flown as `pilot` with `edge` in place of their own.
func _as(pilot: StringName, edge: PilotEdge, measure: Callable) -> Dictionary:
	PlayerProfile.choose_pilot(pilot)
	var c := PlayerProfile.pilot()
	var own := c.edge
	c.edge = edge
	var out: Dictionary = await measure.call()
	c.edge = own
	return out

## What `base` becomes under `edge`: stats stepped, settings on assists that are on.
func _expected(base: Dictionary, edge: PilotEdge) -> Dictionary:
	var out := base.duplicate()
	for s in edge.stats if edge else []:
		out[String(s.stat)] += s.step
	for s in edge.assists if edge else []:
		if base[String(s.assist) + ".enabled"]:
			out["%s.%s" % [s.assist, s.property]] = s.setting()
	return out

func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.keys() != b.keys():
		return false
	for k in a:
		if not (is_equal_approx(a[k], b[k]) if a[k] is float else a[k] == b[k]):
			print("        %s: %s, expected %s" % [k, a[k], b[k]])
			return false
	return true

## An edge touching a stat and three assists: one that Act 3 leaves on, two it removes.
func _test_edge() -> PilotEdge:
	var e := PilotEdge.new()
	e.name = "Test edge"
	var s := StatStep.new()
	s.stat = &"drag"
	s.step = -0.05
	e.stats = [s]
	for row in [[&"speed_governor", &"max_speed", 15.0, false], [&"auto_level", &"max_angle", 45.0, true],
			[&"altitude_hold", &"climb_rate", 7.0, false]]:
		var a := AssistSetting.new()
		a.assist = row[0]
		a.property = row[1]
		a.value = row[2]
		a.degrees = row[3]
		e.assists.append(a)
	return e

func test_each_edge_round_trips_from_data() -> bool:
	var ok := true
	for c in PlayerProfile.pilots():
		ok = ok and c.validate().is_empty()
		if c.edge == null:
			continue
		ok = ok and ResourceSaver.save(c.edge, ROUND_TRIP) == OK
		var back: PilotEdge = ResourceLoader.load(ROUND_TRIP, "", ResourceLoader.CACHE_MODE_IGNORE)
		ok = ok and back.name == c.edge.name and back.stats.size() == c.edge.stats.size() \
			and back.assists.size() == c.edge.assists.size()
		for i in back.stats.size() if ok else 0:
			var a := back.stats[i]
			var b := c.edge.stats[i]
			ok = ok and a.stat == b.stat and a.step == b.step and a.unit == b.unit
		for i in back.assists.size() if ok else 0:
			var a := back.assists[i]
			var b := c.edge.assists[i]
			ok = ok and a.assist == b.assist and a.property == b.property and a.value == b.value \
				and a.degrees == b.degrees
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ROUND_TRIP))
	return ok

## Every setting names a real exported number on an assist the drone has.
func test_settings_name_real_assist_properties() -> bool:
	var d := Sim.drone(Sim.intent())
	var ok := true
	for c in PlayerProfile.pilots():
		for s in c.edge.assists if c.edge else []:
			var found := false
			for a in d.assists.assists():
				if a.assist_id == s.assist:
					found = a.get(s.property) is float
			ok = ok and found
	d.free()
	return ok

func test_on_a_job_an_edge_changes_only_what_it_lists() -> bool:
	var ok := true
	for stack in [ACT1, ACT3]:
		var base := await _as(&"arjuna", null, _on_job.bind(stack))
		for c in PlayerProfile.pilots():
			ok = ok and _same(await _as(c.id, c.edge, _on_job.bind(stack)), _expected(base, c.edge))
		var tuned := await _as(&"abhimanyu", _test_edge(), _on_job.bind(stack))
		ok = ok and _same(tuned, _expected(base, _test_edge()))
		# The governor is on in both acts and takes the setting.
		ok = ok and is_equal_approx(tuned["speed_governor.max_speed"], 15.0)
	return ok

func test_an_assist_the_preset_removed_stays_off_and_unchanged() -> bool:
	var base := await _as(&"arjuna", null, _on_job.bind(ACT3))
	var tuned := await _as(&"abhimanyu", _test_edge(), _on_job.bind(ACT3))
	return not tuned["altitude_hold.enabled"] and not tuned["auto_level.enabled"] \
		and tuned["altitude_hold.climb_rate"] == base["altitude_hold.climb_rate"] \
		and tuned["auto_level.max_angle"] == base["auto_level.max_angle"]

func test_in_free_flight_an_edge_changes_only_what_it_lists() -> bool:
	var ok := true
	# Act 1 (where the career starts), then F2 to Act 3 and on round to Act 1 again:
	# switching an assist off gives back its own value, switching it on the edge's.
	for cycles in [0, 2, 5]:
		var base := await _as(&"arjuna", null, _in_free_flight.bind(cycles))
		var tuned := await _as(&"abhimanyu", _test_edge(), _in_free_flight.bind(cycles))
		ok = ok and _same(tuned, _expected(base, _test_edge()))
		ok = ok and tuned["altitude_hold.enabled"] == (cycles != 2)
	return ok

func test_every_pilot_flies_the_same_assists() -> bool:
	var lists := []
	for c in PlayerProfile.pilots():
		PlayerProfile.choose_pilot(c.id)
		for stack in [ACT1, ACT3]:
			var f := _on_job(stack)
			var ids := []
			for k in f:
				if k.ends_with(".enabled"):
					ids.append([k, f[k]])
			lists.append([stack.label, ids])
	var ok := lists.size() == PlayerProfile.pilots().size() * 2
	for l in lists:
		ok = ok and l == (lists[0] if l[0] == ACT1.label else lists[1]) and l[1].size() == 6
	return ok

## Every pilot has an edge (Story 19.2): stat steps and assist settings both.
## The numbers themselves live only in the pilots' .tres files.
func test_every_pilot_has_an_edge() -> bool:
	var ok := true
	for c in PlayerProfile.pilots():
		ok = ok and c.edge != null and not c.edge.stats.is_empty() and not c.edge.assists.is_empty()
	return ok
