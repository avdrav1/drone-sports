class_name HazardZone
extends Area3D
# Where a crew member stands during a hazard job: a sphere of `radius`.
# Strikes come from the player's drone entering at speed, debris landing in it,
# or a job calling strike() (e.g. a rescue timer running out). A strike only
# lands after the zone has been warning for at least `min_warning` seconds, and
# only on a live job that lists the character in Job.crew_in_field (CLAUDE.md
# rule 7). The JobRunner arms its zones on Briefing and counts the strikes.
# While it warns, the music strips to its drone and pulse (MusicDirector tension).

## The warning just started: the HUD flashes the character's portrait.
signal warning_started(character: StringName)
signal warning_ended(character: StringName)
signal struck(character: StringName, cause: StringName)
## Debris entered the zone, struck or not.
signal debris_in_zone(debris: Debris)

## Character id from data/characters/, set per job scene.
@export var character: StringName
@export var radius := 3.0
## Entering slower than this is not a strike, m/s.
@export var speed_threshold := 4.0
## How far ahead a threat is seen coming, s.
@export var lookahead := 1.5
## A strike needs a warning at least this old, s.
@export var min_warning := 1.0
## Seconds without a threat before the warning clears.
@export var clear_after := 0.5

## Set by the runner on Briefing.
var runner: JobRunner
## Strikes landed this job, by cause.
var strikes: Array[StringName] = []
var _clock := 0.0
var _warning_since := -1.0
var _last_threat := -INF
var _external_threat := false
var _was_inside := false
var _last_pos := Vector3.ZERO
var _velocity := Vector3.ZERO
var _struck_debris := {}

func _ready() -> void:
	monitoring = true
	if find_children("*", "CollisionShape3D", false, false).is_empty():
		var shape := CollisionShape3D.new()
		shape.shape = SphereShape3D.new()
		shape.shape.radius = radius
		add_child(shape)
	body_entered.connect(_on_body_entered)

func _exit_tree() -> void:
	MusicDirector.set_tension(self, false)

## A live job that lists this character: the only time a strike can land.
func armed() -> bool:
	return runner != null and runner.job != null and runner.state == JobRunner.State.LIVE \
		and character in runner.crew_in_field()

func warning() -> bool:
	return _warning_since >= 0.0

## Seconds the current warning has run; -1 with no warning.
func warning_age() -> float:
	return _clock - _warning_since if warning() else -1.0

func contains(p: Vector3) -> bool:
	return p.distance_to(global_position) <= radius

## Called every frame by a job while something scripted is about to strike.
func threaten() -> void:
	_external_threat = true

## A strike from the job itself (e.g. a timer). Lands only after a full warning.
func strike(cause: StringName) -> bool:
	if not armed() or warning_age() < min_warning:
		return false
	strikes.append(cause)
	struck.emit(character, cause)
	return true

func _physics_process(delta: float) -> void:
	_clock += delta
	var drone: Drone = runner.drone if runner else null
	var threat := _external_threat
	_external_threat = false
	if drone:
		var p := drone.global_position
		_velocity = (p - _last_pos) / delta if delta > 0.0 else Vector3.ZERO
		_last_pos = p
		threat = threat or _drone_threat(p)
	threat = threat or _debris_threat()
	if armed() and threat:
		_last_threat = _clock
		if not warning():
			_warning_since = _clock
			warning_started.emit(character)
			MusicDirector.set_tension(self, true)
	elif warning() and _clock - _last_threat > clear_after:
		_warning_since = -1.0
		warning_ended.emit(character)
		MusicDirector.set_tension(self, false)
	if drone:
		var inside := contains(drone.global_position)
		if inside and not _was_inside and _velocity.length() >= speed_threshold:
			strike(&"contact")
		_was_inside = inside

## Inside at speed, or on a line that enters within the lookahead at speed.
func _drone_threat(p: Vector3) -> bool:
	if _velocity.length() < speed_threshold:
		return false
	if contains(p):
		return true
	var t := _ray_sphere(p, _velocity)
	return t >= 0.0 and t <= lookahead

## Time until p + v t first touches the sphere, or -1.
func _ray_sphere(p: Vector3, v: Vector3) -> float:
	var oc := p - global_position
	var a := v.dot(v)
	var b := 2.0 * oc.dot(v)
	var c := oc.dot(oc) - radius * radius
	var disc := b * b - 4.0 * a * c
	if a <= 0.0 or disc < 0.0:
		return -1.0
	var t := (-b - sqrt(disc)) / (2.0 * a)
	return t if t >= 0.0 else -1.0

## Loose debris whose ballistic path reaches the zone within the lookahead.
func _debris_threat() -> bool:
	var g := Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	for d in get_tree().get_nodes_in_group(Debris.GROUP):
		if d.freeze or _struck_debris.has(d):
			continue
		var p: Vector3 = d.global_position
		var v: Vector3 = d.linear_velocity
		var t := 0.0
		while t <= lookahead:
			if contains(p + v * t + 0.5 * g * t * t):
				return true
			t += 0.05
	return false

func _on_body_entered(body: Node3D) -> void:
	if body is Debris:
		debris_in_zone.emit(body)
		if not _struck_debris.has(body):
			_struck_debris[body] = true
			strike(&"debris")
