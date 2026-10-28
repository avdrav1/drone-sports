class_name FlightWatcher
extends Node
# Turns what the drone is doing into crew events (Story 17.8): takeoff, near
# miss, low pass, top speed, battery low, crash, reset, weather change, and long
# hover, with thresholds and cooldowns from a FlightEvents resource. Reads the
# drone, the ground under it (a ray down to whatever it would land on), and the
# weather the drone flies in; never writes to any of them (CLAUDE.md rules 1
# and 2). Contacts come from the drone's body_entered, which its Sound node
# turns on. Nothing is graded on these events.

signal flight_event(event: StringName)

## The drone to watch. Without one, the runner's drone (a fleet job's lead).
@export var drone: Drone
@export var runner: JobRunner
@export var rules: FlightEvents = preload("res://data/radio/flight_events.tres")

## Seconds this watcher has run; cooldowns count in it.
var time := 0.0
## Event -> the time it last fired.
var last := {}
## Height above the ground, m; INF with nothing below.
var height := INF

var _watched: Drone
var _velocity := Vector3.ZERO
var _on_ground := false
var _low := false
var _fast := false
var _still_for := 0.0
var _battery_armed := false
var _passing := false
var _touched := false
var _weather := ""

func watched() -> Drone:
	if drone:
		return drone
	return runner.drone if runner and is_instance_valid(runner.drone) else null

func _physics_process(delta: float) -> void:
	time += delta
	var d := watched()
	if d != _watched:
		_watch(d)
	if d == null:
		return
	observe(delta)
	_velocity = d.linear_velocity

## Follows a new drone. Whatever state it is already in is not an event.
func _watch(d: Drone) -> void:
	if is_instance_valid(_watched):
		for s in [[_watched.body_entered, _on_contact], [_watched.was_reset, _on_reset], [_watched.recovered, _on_reset]]:
			if s[0].is_connected(s[1]):
				s[0].disconnect(s[1])
	_watched = d
	if d == null:
		return
	d.body_entered.connect(_on_contact)
	d.was_reset.connect(_on_reset)
	d.recovered.connect(_on_reset)
	_velocity = d.linear_velocity
	height = ground_height(d)
	_on_ground = height <= rules.grounded_height
	_low = false
	_fast = false
	_still_for = 0.0
	_battery_armed = d.battery > rules.battery_low
	_passing = false
	_weather = _weather_of(d)

## Reads one frame of the drone and raises what it meets.
func observe(delta: float) -> void:
	var d := _watched
	var speed := d.linear_velocity.length()
	height = ground_height(d)
	# Takeoff: off the ground and past the takeoff height.
	if height <= rules.grounded_height:
		_on_ground = true
	elif _on_ground and height >= rules.takeoff_height:
		_on_ground = false
		raise(&"takeoff")
	# Low pass and top speed fire as the drone gets there, not every frame there.
	var low := height < rules.low_pass_height and speed >= rules.low_pass_speed
	if low and not _low:
		raise(&"low_pass")
	_low = low
	var fast := speed >= rules.top_speed
	if fast and not _fast:
		raise(&"top_speed")
	_fast = fast
	# Battery low once per charge: it re-arms only once it is above the line again.
	if d.battery > rules.battery_low:
		_battery_armed = true
	elif _battery_armed:
		_battery_armed = false
		raise(&"battery_low")
	# Near miss: a fast pass close by that ends without touching anything.
	var close := speed >= rules.near_miss_speed and near_geometry(d)
	if close and not _passing:
		_passing = true
		_touched = false
	elif not close and _passing:
		_passing = false
		if not _touched:
			raise(&"near_miss")
	# Long hover: still in the air for hover_time.
	if speed < rules.hover_speed and height > rules.grounded_height:
		_still_for += delta
		if _still_for >= rules.hover_time and _still_for - delta < rules.hover_time:
			raise(&"long_hover")
	else:
		_still_for = 0.0
	var w := _weather_of(d)
	if w != _weather:
		_weather = w
		raise(&"weather_change")

## Emits `event` unless it fired within its cooldown. True when it went out.
func raise(event: StringName) -> bool:
	if time - float(last.get(event, -INF)) < rules.cooldown(event):
		return false
	last[event] = time
	flight_event.emit(event)
	return true

## Height of `d` above whatever is straight below it, m; INF with nothing there.
func ground_height(d: Drone) -> float:
	var space := d.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(d.global_position, d.global_position + Vector3.DOWN * 500.0)
	q.exclude = [d.get_rid()]
	var hit := space.intersect_ray(q)
	return d.global_position.y - hit.position.y if hit else INF

## True when static geometry is within near_miss_distance beside or above `d`.
## What is underneath is the ground, a low pass, not a near miss.
func near_geometry(d: Drone) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = rules.near_miss_distance
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis(), d.global_position)
	q.exclude = [d.get_rid()]
	var space := d.get_world_3d().direct_space_state
	# Only static geometry: other drones and moving things are left out.
	var any_static := false
	var exclude: Array[RID] = [d.get_rid()]
	for hit in space.intersect_shape(q, 32):
		if hit.collider is StaticBody3D:
			any_static = true
		else:
			exclude.append(hit.rid)
	if not any_static:
		return false
	q.exclude = exclude
	var points := space.collide_shape(q, 32)
	for i in range(1, points.size(), 2):
		var to: Vector3 = points[i] - d.global_position
		if to.length() < 0.001 or to.normalized().y > -0.7:
			return true
	return false

func _weather_of(d: Drone) -> String:
	return d.weather.label if d.weather else "Clear"

func _on_contact(_body: Node) -> void:
	_touched = true
	if not _watched.freeze and _velocity.length() >= rules.crash_speed:
		raise(&"crash")

func _on_reset() -> void:
	_passing = false
	_on_ground = false
	_still_for = 0.0
	raise(&"reset")
