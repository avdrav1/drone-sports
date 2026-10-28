class_name Autopilot
extends IntentSource
# Flies its drone through a queue of waypoints and holds at the last, through
# the same Intent and assists as a pilot. Steering is the AI racer's (3.3):
# tilt toward a wanted velocity, altitude hold for height. Slows on approach so
# it stops on the point instead of overshooting. Each fleet drone is the same
# Drone scene with one of these as its intent source.

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

var drone: Drone
var waypoints := PackedVector3Array()
## The waypoint being flown to; past the end once the last is reached.
var index := 0

## The autopilot among a drone's children, or null.
static func of(d: Drone) -> Autopilot:
	for c in d.get_children():
		if c is Autopilot:
			return c
	return null

func _ready() -> void:
	drone = get_parent() as Drone
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
	var passing := corner_speed > 0.0 and index < waypoints.size() - 1
	if not done() and drone.global_position.distance_to(t) < (pass_radius if passing else arrive_radius):
		index += 1
		arrived.emit(index - 1)
		if done():
			finished.emit()
		t = target()
		passing = corner_speed > 0.0 and index < waypoints.size() - 1
	var d: float = drone.global_position.distance_to(t)
	var speed := minf(cruise_speed, d * approach_gain)
	if passing:
		speed = maxf(speed, corner_speed)
	return AiPilot.steer(drone, t, speed)
