class_name RouteSource
extends Node
# Where the job wants the drone next, as world points in order. A job scene
# places one subclass (CourseRoute, ReachRoute); the radar, map, and route
# ribbon draw what the job's guidance setting allows, and nothing without a GPS
# fix. Never steers the drone.

## Optional: supplies the job's guidance. Without one the full route shows.
@export var runner: JobRunner
@export var drone: Node3D
## Optional: when set, the route hides while the GPS has no fix (jamming).
@export var gps: Gps

## Every point still ahead, in order. Subclasses fill this in.
func points() -> PackedVector3Array:
	return PackedVector3Array()

func guidance() -> Job.Guidance:
	return runner.guidance() if runner else Job.Guidance.FULL

## What to draw: the drone's position, then the points guidance allows. Empty for
## none, or without a GPS fix.
func guided() -> PackedVector3Array:
	if gps and not gps.has_fix():
		return PackedVector3Array()
	var g := guidance()
	var p := points()
	if g == Job.Guidance.NONE or drone == null or p.is_empty():
		return PackedVector3Array()
	if g == Job.Guidance.NEXT_LEG:
		p = p.slice(0, 1)
	p.insert(0, drone.global_position)
	return p

## Calls draw(at) every `step` along a polyline, in order. For dotted lines.
static func walk(line: PackedVector3Array, step: float, draw: Callable) -> void:
	var carry := 0.0
	for i in line.size() - 1:
		var a := line[i]
		var seg := line[i + 1] - a
		var length := seg.length()
		var t := carry
		while t < length:
			draw.call(a + seg * (t / length))
			t += step
		carry = t - length
