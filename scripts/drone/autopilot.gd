class_name Autopilot
extends IntentSource
# Flies its drone through a queue of waypoints and holds at the last, through
# the same Intent and assists as a pilot. Steering is the AI racer's (3.3):
# tilt toward a wanted velocity, altitude hold for height. Slows on approach so
# it stops on the point instead of overshooting. Each fleet drone is the same
# Drone scene with one of these as its intent source.
# Story 18.11: a crew pilot's FlightStyle bends the route they fly (pace,
# corners, spacing, wobble, late turns); it changes only the Intent written.

signal arrived(index: int)
signal finished

## Assists the drone flies with under autopilot; needs auto-level and altitude hold.
@export var stack: AssistStack = preload("res://data/assists/autopilot.tres")
@export var cruise_speed := 8.0
## Speed per metre of distance left; sets how early it slows down.
@export var approach_gain := 0.8
## A waypoint counts as reached inside this distance, m.
@export var arrive_radius := 1.0
## Above 0, it flies through every waypoint but the last at no less than this
## speed instead of stopping on each, counting it reached inside pass_radius.
@export var corner_speed := 0.0
@export var pass_radius := 1.5
## How its pilot flies; null flies the plain route.
@export var style: FlightStyle
## Where the style's wobble starts, radians, so two pilots never sway together.
@export var wobble_phase := 0.0

const GROUP := &"autopilots"
## Wobble fades out within this of the point flown to, m, so every pilot
## still lines up through a gate or settles on a station.
const CALM := 4.0

var drone: Drone
var waypoints := PackedVector3Array()
## The waypoint being flown to; past the end once the last is reached.
var index := 0
var _time := 0.0
## Seconds left holding the last sticks after a waypoint (style.delay).
var _late := 0.0
var _last := Intent.new()

## The autopilot among a drone's children, or null.
static func of(d: Drone) -> Autopilot:
	for c in d.get_children():
		if c is Autopilot:
			return c
	return null

func _ready() -> void:
	drone = get_parent() as Drone
	add_to_group(GROUP)
	engage.call_deferred()

## Puts the autopilot's assists on the drone. Call after a pilot hands it back.
func engage() -> void:
	if drone and stack:
		drone.assists.apply_stack(stack)

## Replaces the route.
func go_to(points: PackedVector3Array) -> void:
	waypoints = points
	index = 0

## Adds a waypoint after the others.
func queue(point: Vector3) -> void:
	if done():
		# Holding at the last: fly on from here.
		index = waypoints.size()
	waypoints.append(point)

func done() -> bool:
	return index >= waypoints.size()

## Where it is flying to or holding at, or null with no route.
func target() -> Variant:
	if waypoints.is_empty():
		return null
	return waypoints[mini(index, waypoints.size() - 1)]

func reset() -> void:
	index = 0

func read_intent() -> Intent:
	var t: Variant = target()
	if drone == null or t == null:
		# Nowhere to go: hold where it is.
		return Intent.new()
	_time += 1.0 / Engine.physics_ticks_per_second
	var passing := corner_speed > 0.0 and index < waypoints.size() - 1
	var cut := style.cut if style and passing else 0.0
	if not done() and drone.global_position.distance_to(t) < (pass_radius + cut if passing else arrive_radius):
		index += 1
		_late = style.delay if style else 0.0
		arrived.emit(index - 1)
		if done():
			finished.emit()
		t = target()
		passing = corner_speed > 0.0 and index < waypoints.size() - 1
	if _late > 0.0:
		# Slow to react: the old sticks a moment longer, so the turn runs wide.
		_late -= 1.0 / Engine.physics_ticks_per_second
		return _last.copy()
	var d: float = drone.global_position.distance_to(t)
	var push := style.push if style else 1.0
	var speed := minf(cruise_speed * push, d * approach_gain)
	if passing:
		speed = maxf(speed, corner_speed * (style.corner_speed if style else 1.0))
	if style:
		t += _styled(t, d)
	_last = AiPilot.steer(drone, t, speed)
	return _last

## The style's sway off the line and its gap from other fleet drones, as an
## offset to the aim point. The sway calms down near the point, and the gap
## gives way on the point itself, so every pilot still lands where sent.
func _styled(t: Vector3, d: float) -> Vector3:
	var pos := drone.global_position
	var to := Vector3(t.x - pos.x, 0.0, t.z - pos.z)
	var side := Vector3(-to.z, 0.0, to.x).normalized()
	var sway := sin(_time * 1.3 + wobble_phase) * 0.7 + sin(_time * 3.1 + wobble_phase * 2.0) * 0.3
	# Swung from a point CALM ahead rather than the far target, so it shows.
	var out := side * style.wobble * sway * clampf((d - 1.0) / CALM, 0.0, 1.0) * maxf(1.0, d / CALM)
	if style.spacing > 0.0:
		var give := clampf(d / 2.0, 0.0, 1.0)
		for other in get_tree().get_nodes_in_group(GROUP):
			var o: Drone = (other as Autopilot).drone
			if other == self or not is_instance_valid(o):
				continue
			var away := pos - o.global_position
			away.y = 0.0
			var gap := away.length()
			if gap < style.spacing and gap > 0.01:
				out += away / gap * (style.spacing - gap) * give
	return out
