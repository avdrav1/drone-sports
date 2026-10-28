class_name Defender
extends IntentSource
# A shell defender: the AI racer's steering (3.3) with a target instead of a
# spline. Circles the trench entrance; when a fleet drone comes within `aggro`,
# chases it. The fight disables what it touches. Seeded: the same seed patrols
# the same way.

@export var seed := 1
## Patrol circle round `guard` (world), radius in metres.
@export var patrol_radius := 12.0
## Patrol speed round the circle, rad/s.
@export var patrol_rate := 0.25
@export var chase_speed := 7.0
@export var aggro := 14.0
@export var stack: AssistStack = preload("res://data/assists/autopilot.tres")

var drone: Drone
## The point it guards, and the plane it circles in (its normal).
var guard := Vector3.ZERO
var normal := Vector3.RIGHT
## Fleet drones it may chase.
var prey: Array[Drone] = []
var target: Drone
var _angle := 0.0
var _rate := 0.0
var _time := 0.0

func _ready() -> void:
	drone = get_parent() as Drone
	reseed(seed)
	engage.call_deferred()

## Where on its circle it starts, and which way and how fast it goes round.
func reseed(s: int) -> void:
	seed = s
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	_angle = rng.randf() * TAU
	_rate = patrol_rate * rng.randf_range(0.8, 1.2) * (1.0 if rng.randf() < 0.5 else -1.0)
	_time = 0.0

func engage() -> void:
	if drone and stack:
		drone.assists.apply_stack(stack)

## Where it patrols at time t.
func patrol_point(t: float) -> Vector3:
	var a := _angle + _rate * t
	var u := normal.cross(Vector3.UP if absf(normal.y) < 0.99 else Vector3.RIGHT).normalized()
	var v := normal.cross(u)
	return guard + (u * cos(a) + v * sin(a)) * patrol_radius

func read_intent() -> Intent:
	if drone == null:
		return Intent.new()
	_time += 1.0 / Engine.physics_ticks_per_second
	target = null
	var best := aggro
	for p in prey:
		if is_instance_valid(p) and p.is_inside_tree():
			var d := p.global_position.distance_to(drone.global_position)
			if d < best:
				best = d
				target = p
	if target:
		return AiPilot.steer(drone, target.global_position, chase_speed)
	var at := patrol_point(_time)
	return AiPilot.steer(drone, at, minf(chase_speed, drone.global_position.distance_to(at) * 0.8 + 2.0))
