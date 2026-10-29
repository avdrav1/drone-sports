class_name CrewProp
extends Node3D
# A crew member standing in the field, look only. No collision, so the drone and
# debris pass through it; the HazardZone around it does the work.
# With a `character`, it is that person (Story 20.2): their CrewFigure idles,
# turns to watch the drone, waves once per close pass, flinches while their
# zone warns, sits hurt after a strike, is gone at once after one that kills,
# and cheers when the job completes. It only reads the zone's and runner's
# signals and the drone's position.
# Without one, it is a plain capsule figure in `color`.

## Character id from data/characters/.
@export var character: StringName
## Used when no character is set.
@export var color := Color(0.3, 0.6, 0.9)
@export var height := 1.75
## The figure waves when the drone comes this close, m; once per pass.
@export var wave_distance := 6.0
## The drone has to go this far out again before the next wave, m.
@export var pass_distance := 10.0
## How long a wave lasts, s.
@export var wave_time := 1.4
## The figure turns to face a drone within this range, m.
@export var watch_distance := 30.0
## How fast the figure turns, rad/s.
@export var turn_speed := 2.0

## The person, when the character has a look.
var figure: CrewFigure
var runner: JobRunner
var zone: HazardZone
## What the figure does when nothing is happening: idle, cheer or hurt.
var _base: StringName = &"idle"
var _waved := false
var _wave_left := 0.0

func _ready() -> void:
	var c: Character = Roster.character(character) if character else null
	if c and c.look:
		figure = CrewFigure.build(c.look, height)
		add_child(figure)
		_hook_up.call_deferred()
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c.colors[0] if c else color
	var body := CapsuleMesh.new()
	body.radius = 0.22
	body.height = height * 0.78
	var head := SphereMesh.new()
	head.radius = 0.13
	head.height = 0.26
	for part in [[body, height * 0.39], [head, height * 0.88]]:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.material_override = mat
		mi.position.y = part[1]
		add_child(mi)

## The figure's action now, one of CrewBody.ACTIONS; idle without a figure.
func action() -> StringName:
	return figure.action if figure else &"idle"

## Finds this character's zone and the job's runner in the scene (the
## top node under the root) and listens.
func _hook_up() -> void:
	if not is_inside_tree():
		return
	var scope: Node = self
	while scope.get_parent() != get_tree().root:
		scope = scope.get_parent()
	for z: HazardZone in scope.find_children("*", "HazardZone", true, false):
		if z.character == character:
			zone = z
	var runners := scope.find_children("*", "JobRunner", true, false)
	runner = runners[0] if runners else null
	if zone:
		zone.warning_started.connect(_on_warning)
		zone.warning_ended.connect(_on_warning)
	if runner:
		runner.crew_struck.connect(_on_struck)
		runner.state_changed.connect(_on_state)

func _on_warning(_id: StringName) -> void:
	_show()

## A strike that kills takes the person out of the scene at once, the way the
## runner keeps the dead out of a job: the dead never move or appear.
func _on_struck(id: StringName, _before: Roster.Status) -> void:
	if id != character:
		return
	if not Roster.is_alive(character):
		hide()
		set_process(false)
		queue_free()
		return
	_base = &"hurt"
	_show()

func _on_state(s: JobRunner.State, _previous: JobRunner.State) -> void:
	if s == JobRunner.State.COMPLETE and _base != &"hurt":
		_base = &"cheer"
		_show()

## Plays what the figure should be doing now: hurt beats a warning, a warning
## beats everything else, and a wave runs out back to the base action.
func _show() -> void:
	var want := _base
	if _base != &"hurt" and zone and zone.warning():
		want = &"flinch"
	elif _base == &"idle" and _wave_left > 0.0:
		want = &"wave"
	if figure.action != want:
		figure.play(want)

func _process(delta: float) -> void:
	if figure == null:
		return
	var drone: Drone = runner.drone if runner else null
	if drone == null or not drone.is_inside_tree():
		return
	var to := drone.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if _wave_left > 0.0:
		_wave_left -= delta
		if _wave_left <= 0.0:
			_show()
	if d > pass_distance:
		_waved = false
	elif d <= wave_distance and not _waved and figure.action == &"idle":
		_waved = true
		_wave_left = wave_time
		_show()
	if d <= watch_distance and d > 0.01 and _base != &"hurt":
		var yaw := atan2(to.x, to.z) - global_rotation.y
		figure.rotation.y = rotate_toward(figure.rotation.y, yaw, turn_speed * delta)
