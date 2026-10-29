extends RefCounted
# Story 19.2: four pilots, four edges. The real drone, flown headless with
# scripted sticks: every pilot side by side in their own lane, plus one with no
# edge at all. In Act 1 each specialist is best at their thing and Arjuna is never
# last; in Act 5, with no assists, each stat bump still shows.

const Sim = preload("res://tests/sim.gd")
const ACT1 := preload("res://data/assists/act1.tres")
const ACT5 := preload("res://data/assists/act5.tres")
const LANE := 15.0
const HEIGHT := 20.0
const BASELINE := &"none"

## Holds a forward tilt and level height whatever happens: a steady hand with
## no assists, so top speed is set by drag alone.
class TiltPilot extends IntentSource:
	var drone: Drone
	var tilt := deg_to_rad(30.0)
	func read_intent() -> Intent:
		var i := Intent.new()
		var sticks := FlightControl.attitude_sticks(drone, tilt, 0.0)
		i.pitch = sticks.x
		i.roll = sticks.y
		var lift := drone.mass * (drone.gravity() - 2.0 * drone.linear_velocity.y) / maxf(cos(FlightControl.tilt(drone)), 0.5)
		i.throttle = Mixer.hover_throttle(lift / Drone.MOTOR_COUNT, drone.max_thrust)
		return i

## Pilot id (or BASELINE) -> a drone flown as them under `stack`, each in its
## own lane along x, facing -z. `source` makes each drone's IntentSource.
func _lanes(stack: AssistStack, source: Callable) -> Dictionary:
	var out := {}
	var ids: Array[StringName] = [BASELINE]
	for c in PlayerProfile.pilots():
		ids.append(c.id)
	for i in ids.size():
		var id := ids[i]
		PlayerProfile.choose_pilot(&"arjuna" if id == BASELINE else id)
		var c := PlayerProfile.pilot()
		var own := c.edge
		if id == BASELINE:
			c.edge = null
		var d := Sim.drone(Sim.intent(), Vector3(i * LANE, HEIGHT, 0), stack)
		Garage.apply(d)
		c.edge = own
		var src: IntentSource = source.call(d)
		d.add_child(src)
		d.intent_source = src
		out[id] = d
	return out

func _sticks(i: Intent) -> Callable:
	return func(_d: Drone) -> IntentSource:
		var s := Sim.FixedSource.new()
		s.value = i
		return s

## Fly every lane until `done` is true for each drone or `seconds` pass. Returns
## id -> seconds to done (INF if never), and calls `watch` on each drone each frame.
func _race(lanes: Dictionary, seconds: float, done: Callable, watch := Callable()) -> Dictionary:
	var out := {}
	for id in lanes:
		out[id] = INF
	var frames := int(seconds * 60.0)
	for f in frames:
		await Sim.physics_frames(1)
		var left := false
		for id in lanes:
			if watch.is_valid():
				watch.call(id, lanes[id])
			if out[id] == INF and done.call(lanes[id]):
				out[id] = (f + 1) / 60.0
			left = left or out[id] == INF
		if not left:
			break
	return out

func _free(lanes: Dictionary, extra: Array = []) -> void:
	for d in lanes.values():
		d.free()
	for n in extra:
		n.free()

## The pilots (no baseline) ranked by `score`, best first.
func _ranked(score: Dictionary, higher_is_better: bool) -> Array:
	var ids := score.keys().filter(func(id): return id != BASELINE)
	ids.sort_custom(func(a, b): return score[a] > score[b] if higher_is_better else score[a] < score[b])
	return ids

func _print(what: String, score: Dictionary) -> void:
	var parts := PackedStringArray()
	for id in score:
		parts.append("%s %.2f" % [id, score[id]])
	print("        %s: %s" % [what, ", ".join(parts)])

## Abhimanyu tops out fastest on a 150 m straight at full stick, and covers it first.
func test_act1_straight_is_abhimanyus() -> bool:
	var lanes := _lanes(ACT1, _sticks(Sim.intent(0.0, 1.0)))
	var top := {}
	for id in lanes:
		top[id] = 0.0
	var watch := func(id: StringName, d: Drone) -> void:
		top[id] = maxf(top[id], FlightControl.horizontal_velocity(d).length())
	var times := await _race(lanes, 25.0, func(d: Drone) -> bool: return d.global_position.z <= -150.0, watch)
	_free(lanes)
	_print("150 m straight, s", times)
	_print("top speed, m/s", top)
	var by_time := _ranked(times, false)
	var by_top := _ranked(top, true)
	return by_time[0] == &"abhimanyu" and by_top[0] == &"abhimanyu" and top[&"abhimanyu"] > top[by_top[1]] + 0.5 \
		and by_time[-1] != &"arjuna" and times[&"abhimanyu"] < INF

## Jatayu turns through 180° first at full roll and yaw stick.
func test_act1_turn_is_jatayu() -> bool:
	var lanes := _lanes(ACT1, _sticks(Sim.intent(0.0, 0.0, 1.0, 1.0)))
	var turned := {}
	for id in lanes:
		turned[id] = 0.0
	var watch := func(id: StringName, d: Drone) -> void:
		turned[id] += absf(d.angular_velocity.y) / 60.0
	var times := await _race(lanes, 5.0, func(d: Drone) -> bool: return turned[_id(lanes, d)] >= PI, watch)
	_free(lanes)
	_print("180° turn, s", times)
	var ranked := _ranked(times, false)
	return ranked[0] == &"jatayu" and ranked[-1] != &"arjuna" and times[ranked[-1]] < INF

## Hanuman climbs 30 m first at full throttle stick.
func test_act1_climb_is_hanumans() -> bool:
	var lanes := _lanes(ACT1, _sticks(Sim.intent(1.0)))
	var times := await _race(lanes, 10.0, func(d: Drone) -> bool: return d.global_position.y >= HEIGHT + 30.0)
	_free(lanes)
	_print("30 m climb, s", times)
	var ranked := _ranked(times, false)
	return ranked[0] == &"hanuman" and ranked[-1] != &"arjuna" and times[ranked[-1]] < INF

## Flown at a wall at full stick, the collision guard stops Arjuna furthest from it
## and stops everyone short of it.
func test_act1_wall_stop_is_arjunas() -> bool:
	var wall_z := -40.0
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(200, 60, 2)
	wall.add_child(shape)
	Sim.add(wall)
	wall.global_position = Vector3(50, HEIGHT, wall_z - 1.0)
	var lanes := _lanes(ACT1, _sticks(Sim.intent(0.0, 1.0)))
	# Where each first comes to a stop; held at full stick, they then creep in.
	var stop := {}
	for id in lanes:
		stop[id] = INF
	var moving := func(d: Drone) -> bool:
		return d.global_position.z > wall_z + 10.0 or d.linear_velocity.z < -0.05
	var watch := func(id: StringName, d: Drone) -> void:
		if stop[id] == INF and not moving.call(d):
			stop[id] = d.global_position.z - wall_z - 0.2  # the drone is 0.4 m across
	await _race(lanes, 8.0, func(d: Drone) -> bool: return not moving.call(d), watch)
	_free(lanes, [wall])
	_print("stopped short of the wall, m", stop)
	return _ranked(stop, true)[0] == &"arjuna" and stop.values().all(func(g): return g > 0.0 and g < INF)

## With no assists: Abhimanyu climbs fastest, Jatayu tops out fastest, Hanuman's battery
## lasts longest; each beats the drone with no edge.
func test_act5_stat_bumps_show() -> bool:
	var lanes := _lanes(ACT5, _sticks(Sim.intent(1.0)))
	await Sim.physics_frames(30)
	var climb := {}
	for id in lanes:
		climb[id] = lanes[id].linear_velocity.y
	_free(lanes)
	lanes = _lanes(ACT5, func(d: Drone) -> IntentSource:
		var p := TiltPilot.new()
		p.drone = d
		return p)
	await Sim.physics_frames(240)
	var speed := {}
	var battery := {}
	for id in lanes:
		speed[id] = FlightControl.horizontal_velocity(lanes[id]).length()
		battery[id] = lanes[id].battery
	_free(lanes)
	_print("climb rate after 0.5 s, m/s", climb)
	_print("speed after 4 s at 30°, m/s", speed)
	_print("battery after 4 s", battery)
	return _ranked(climb, true)[0] == &"abhimanyu" and climb[&"abhimanyu"] > climb[BASELINE] \
		and _ranked(speed, true)[0] == &"jatayu" and speed[&"jatayu"] > speed[BASELINE] \
		and _ranked(battery, true)[0] == &"hanuman" and battery[&"hanuman"] > battery[BASELINE]

func _id(lanes: Dictionary, d: Drone) -> StringName:
	return lanes.find_key(d)
