class_name LatticeFight
extends Node
# The Lattice job's phases (docs/BOSS.md), one after another on a live job.
#
# 1. Reclaim: fleet drones fly to units covering the trench entrance and tag
#    them; a tagged unit drops out of the shell and joins the fleet. Defenders
#    disable fleet drones they touch, and each one lost is recaptured: the last
#    unit reclaimed goes back into the shell. When the gap units are all out,
#    the entrance opens. Losing the whole fleet fails the job.
#
# 2. The trench: the pilot's own drone goes live with the job's assists and
#    flies in through the entrance, round the trench, to the shutter. Sanjaya
#    calls the turns at invisible waypoints while alive. Shell contact is a
#    strike on the crew member calling (Sanjaya, else Bhima), through their
#    HazardZone, which warns first while the drone is near the shell. The
#    entrance closes trench_time seconds after it opened, failing the job.
#
# 3. Override: hold inside a small sphere at the core's port for hold_time while
#    the shell shakes and gusts blow down the trench (the wind sim, which the
#    Act 5 preset already has on). Drifting out for more than half a second
#    resets the hold. Completing it disables the Lattice: never damage.
# 4. Power-down: the shell lets go section by section; units fall free. The
#    crew's lost drones come home to the fleet, the living crew's only. Then
#    the job completes, the save records lattice_disabled, and the results
#    close with a word from every crew member, the dead by their memorial.
#
# Holds no flight code: drones fly through their intent sources, and every
# order goes to an Autopilot.

signal phase_started(phase: Phase)
signal phase_complete(phase: Phase)
signal unit_reclaimed(unit: int, by: Drone)
signal fleet_drone_lost(drone: Drone)
signal hold_complete
signal boss_disabled
## Sanjaya called a turn at trench waypoint `index`.
signal called(index: int, text: String)

enum Phase { BRIEFING, RECLAIM, TRENCH, OVERRIDE, POWER_DOWN, DONE }

const DRONE := preload("res://scenes/drone/drone.tscn")

@export var runner: JobRunner
@export var lattice: Lattice
@export var command: CommandView
## Shell defenders: Drone scenes with a Defender as intent source.
@export var defenders: Array[Drone] = []
## Seeds the defenders; the same seed fights the same way.
@export var seed := 1
## A fleet drone tags a unit by staying this close for tag_time.
@export var tag_range := 3.5
@export var tag_time := 0.5
## A defender this close disables a fleet drone.
@export var disable_range := 1.4
@export var camera_rig: CameraRig
@export var bark: Bark
## Who calls the turns, and who takes a strike when they cannot.
@export var callers: Array[StringName] = [&"marlo", &"bea"]
## Within this of the shell the calling crew member's warning runs, m.
@export var warn_distance := 2.5
## The drone's own size against the shell, m.
@export var contact_radius := 0.3
## A trench waypoint every this many points of the trench path.
@export var call_every := 3
## Phase 3's hold; the fight gives it the port and the boss's numbers.
@export var override: OverrideHold
@export var gusts: Wind = preload("res://data/wind/lattice_gusts.tres")
## How far the shell's units shake during the override, m. Look only.
@export var shake := 0.25
## Power-down: the shell lets go in this many sections, one every interval.
@export var sections := 8
@export var section_interval := 0.8
## Seconds a unit falls before it is gone.
@export var fall_time := 1.5

## Crew member -> their drone, home from the shell.
var returned := {}
var power_clock := 0.0
## Unit -> seconds since its section let go.
var _falling := {}
var _released := 0

var phase := Phase.BRIEFING
## Units reclaimed so far, in order.
var reclaimed: Array[int] = []
## Fleet drone -> the unit it was sent to tag.
var assigned := {}
var lost := 0
## Seconds since the entrance opened.
var trench_clock := 0.0
## Invisible gates along the trench, in order.
var waypoints: Array[Gate] = []
var contacts := 0
var _near := {}
var _touching := false
## Waypoints already called: one call each, however the drone wobbles.
var _called: Array[int] = []
var _last_pos := Vector3.ZERO

func _ready() -> void:
	for i in defenders.size():
		var def := _defender(defenders[i])
		def.reseed(seed + i)
		def.guard = lattice.to_global(Lattice.toward(0.0) * (lattice.r_out() + 6.0))
		def.normal = (def.guard - lattice.global_position).normalized()
		def.prey = command.drones
	runner.state_changed.connect(_on_runner_state)
	runner.finished.connect(_on_finished)
	# The Lattice sings (Story 16.11): the director follows the fight.
	MusicDirector.lattice(self)
	if override:
		var port := Node3D.new()
		port.name = "Port"
		lattice.add_child(port)
		port.position = lattice.port()
		override.center = port
		override.radius = boss().hold_radius
		override.hold_time = boss().hold_time
		override.grace = 0.5

static func _defender(d: Drone) -> Defender:
	for c in d.get_children():
		if c is Defender:
			return c
	return null

func boss() -> Boss:
	return lattice.boss

func _on_runner_state(state: JobRunner.State, _previous: JobRunner.State) -> void:
	match state:
		JobRunner.State.BRIEFING:
			for d in defenders:
				d.freeze = true
		JobRunner.State.LIVE:
			for d in defenders:
				d.freeze = false
			# The pilot's own drone waits until the trench is open.
			runner.drone.freeze = true
			_start(Phase.RECLAIM)

## At the override port (MusicDirector asks, so it never names this class).
func holding() -> bool:
	return phase == Phase.OVERRIDE

func _start(p: Phase) -> void:
	phase = p
	phase_started.emit(p)

# --- Phase 1: reclaim ------------------------------------------------------

## The units whose removal opens the entrance: side by side over the shaft.
func gap() -> Array[int]:
	return lattice.entrance_units.slice(0, boss().gap_units)

## World point just outside a unit, where a fleet drone tags it.
func approach(unit: int) -> Vector3:
	var p: Vector3 = lattice.units[unit].pos
	return lattice.to_global(p.normalized() * (lattice.r_out() + 1.5))

## The next gap unit nobody has reclaimed or been sent to; -1 when none.
func next_target() -> int:
	var taken := assigned.values()
	for u in gap():
		if not u in reclaimed and not u in taken:
			return u
	return -1

## Sends a fleet drone to tag a unit.
func tag(d: Drone, unit: int) -> void:
	if unit < 0 or d == null or not d in command.drones:
		return
	assigned[d] = unit
	_near[d] = 0.0
	Autopilot.of(d).go_to(PackedVector3Array([approach(unit)]))

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.RECLAIM and event.is_action_pressed("tag_unit") and command.selected and command.flown == null:
		tag(command.selected, next_target())
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if runner.state != JobRunner.State.LIVE:
		return
	match phase:
		Phase.RECLAIM:
			_reclaim_step(delta)
		Phase.TRENCH:
			_trench_step(delta)
		Phase.OVERRIDE:
			_override_step()
		Phase.POWER_DOWN:
			_power_down_step(delta)

func _reclaim_step(delta: float) -> void:
	for d in assigned.keys():
		var unit: int = assigned[d]
		if d.global_position.distance_to(lattice.to_global(lattice.units[unit].pos)) <= tag_range:
			_near[d] = _near.get(d, 0.0) + delta
			if _near[d] >= tag_time:
				reclaim(unit, d)
		else:
			_near[d] = 0.0
	for def in defenders:
		for d in command.drones.duplicate():
			if d.global_position.distance_to(def.global_position) <= disable_range:
				disable(d)
	if command.drones.is_empty():
		runner.fail("fleet lost")
		return
	if gap().all(func(u): return u in reclaimed):
		open_entrance()

## Takes a unit out of the shell; it flies on as part of the fleet.
func reclaim(unit: int, by: Drone = null) -> void:
	if unit in reclaimed:
		return
	reclaimed.append(unit)
	lattice.hide_unit(unit)
	if by:
		assigned.erase(by)
		Autopilot.of(by).go_to(PackedVector3Array([approach(unit) + (approach(unit) - lattice.global_position).normalized() * 6.0]))
	var freed: Drone = DRONE.instantiate()
	freed.name = "Freed%d" % reclaimed.size()
	var auto := Autopilot.new()
	auto.name = "Autopilot"
	freed.add_child(auto)
	freed.intent_source = auto
	command.get_parent().add_child(freed)
	# Above the tagger's way out, so the two don't meet.
	freed.global_position = approach(unit) + (approach(unit) - lattice.global_position).normalized() * 3.0 + Vector3.UP * 4.0
	command.add(freed)
	auto.go_to(PackedVector3Array([freed.global_position]))
	unit_reclaimed.emit(unit, by)

## A defender caught a fleet drone: it is gone, and the shell takes back the
## last unit reclaimed.
func disable(d: Drone) -> void:
	if not d in command.drones:
		return
	command.remove(d)
	assigned.erase(d)
	_near.erase(d)
	lost += 1
	fleet_drone_lost.emit(d)
	d.queue_free()
	if not reclaimed.is_empty():
		lattice.show_unit(reclaimed.pop_back())

## Opens the trench and hands the pilot their own drone.
func open_entrance() -> void:
	if lattice.entrance_open:
		return
	lattice.entrance_open = true
	for u in lattice.entrance_units:
		lattice.hide_unit(u)
	phase_complete.emit(Phase.RECLAIM)
	_start_trench()

# --- Phase 2: the trench ---------------------------------------------------

func _start_trench() -> void:
	trench_clock = 0.0
	var pilot := runner.drone
	pilot.freeze = false
	if command.flown:
		command.leave()
	command.process_mode = Node.PROCESS_MODE_DISABLED
	command.get_node("Overlay").visible = false
	if camera_rig:
		camera_rig.target = pilot
		camera_rig.set_view(CameraRig.View.CHASE)
		camera_rig.camera.make_current()
	_build_waypoints()
	_last_pos = pilot.global_position
	_start(Phase.TRENCH)

## Who is calling the turns: the first caller still alive, or empty.
func caller() -> StringName:
	for id in callers:
		if Roster.is_alive(id):
			return id
	return &""

func zone_of(id: StringName) -> HazardZone:
	for z in runner.hazard_zones():
		if z.character == id:
			return z
	return null

## The world point at the top of the shutter, where the trench run ends.
func shutter() -> Vector3:
	return lattice.to_global(Lattice.toward(lattice.arc()) * lattice.tunnel_span().x)

func _build_waypoints() -> void:
	var path := lattice.trench_path()
	# Skip the approach from outside; stop short of the shutter, where the
	# drone turns down out of the trench.
	for i in range(2, path.size() - 3, call_every):
		var g := Gate.new()
		g.name = "Call%d" % waypoints.size()
		g.size = Vector2(boss().trench_width, boss().tunnel_height) * 1.5
		g.collision_layer = 0
		g.collision_mask = 0
		g.visible = false
		lattice.add_child(g)
		var fwd := (path[i + 1] - path[i]).normalized()
		var up := (path[i] - lattice.global_position).normalized() if absf(fwd.dot(Vector3.UP)) > 0.9 else Vector3.UP
		g.global_transform = Transform3D(Basis.looking_at(fwd, up), path[i])
		g.index = waypoints.size()
		waypoints.append(g)

func _trench_step(delta: float) -> void:
	trench_clock += delta
	var pilot := runner.drone
	var p := pilot.global_position
	for g in waypoints:
		if g.crossing(_last_pos, p) == 1 and not g.index in _called:
			_called.append(g.index)
			_call(g.index)
	_last_pos = p
	# The calling crew member's warning runs while the drone is near the shell.
	var id := caller()
	var zone := zone_of(id)
	if zone and lattice.touching(p, warn_distance):
		zone.threaten()
	var touching := lattice.touching(p, contact_radius)
	if touching and not _touching:
		contacts += 1
		if zone:
			zone.strike(&"shell")
	_touching = touching
	if p.distance_to(shutter()) <= 3.0:
		phase_complete.emit(Phase.TRENCH)
		start_override()
		return
	if trench_clock >= boss().trench_time:
		lattice.entrance_open = false
		for u in lattice.entrance_units:
			lattice.show_unit(u)
		runner.fail("trench closed")

## Sanjaya's call at a waypoint, while Sanjaya is alive to make it.
func _call(index: int) -> void:
	if not Roster.is_alive(&"marlo"):
		return
	var lines: Array = Bark.lines_of(&"marlo").get("trench", {}).get("active", [])
	if lines.is_empty():
		return
	var text := Bark.text_of(lines[mini(index, lines.size() - 1)])
	called.emit(index, text)
	if bark:
		bark.spoke.emit(&"marlo", &"trench", text)

# --- Phase 3: override -----------------------------------------------------

func start_override() -> void:
	runner.drone.wind = gusts
	_start(Phase.OVERRIDE)

func _override_step() -> void:
	var units := lattice.get_node_or_null("Units") as Node3D
	if units:
		var t := Time.get_ticks_msec() * 0.001
		units.position = Vector3(sin(t * 23.0), sin(t * 31.0 + 1.0), sin(t * 19.0 + 2.0)) * shake
	if override and override.is_done():
		if units:
			units.position = Vector3.ZERO
		hold_complete.emit()
		phase_complete.emit(Phase.OVERRIDE)
		boss_disabled.emit()
		_start(Phase.POWER_DOWN)

# --- Power-down ------------------------------------------------------------

## Which section a unit is in: slices round the vertical axis from the entrance.
func section_of(unit: int) -> int:
	var a := posmod(Lattice.angle_of(lattice.units[unit].pos), TAU)
	return mini(int(a / TAU * sections), sections - 1)

func _power_down_step(delta: float) -> void:
	power_clock += delta
	while _released < sections and power_clock >= _released * section_interval:
		_release(_released)
		_released += 1
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	for u in _falling.keys():
		_falling[u] += delta
		var t: float = _falling[u]
		if t >= fall_time:
			_falling.erase(u)
			lattice.hide_unit(u)
		else:
			lattice.offset_unit(u, Vector3.DOWN * 0.5 * g * t * t)
	if _released >= sections and _falling.is_empty():
		_start(Phase.DONE)
		if runner.pays_out:
			StoryFlags.set_flag(&"lattice_disabled")

func _release(section: int) -> void:
	for u in lattice.units.size():
		if lattice.is_hidden(u) or section_of(u) != section:
			continue
		_falling[u] = 0.0
		var id: StringName = lattice.units[u].crew
		if id != &"" and Roster.is_alive(id):
			_bring_home(id, u)

## A crew member's lost drone drops out of the shell and rejoins the fleet.
func _bring_home(id: StringName, unit: int) -> void:
	var c: Character = Roster.character(id)
	var d: Drone = DRONE.instantiate()
	d.name = "%sHome" % c.name
	var auto := Autopilot.new()
	auto.name = "Autopilot"
	FleetCrew.fly_as(auto, c)
	d.add_child(auto)
	d.intent_source = auto
	command.get_parent().add_child(d)
	var at := lattice.to_global(lattice.units[unit].pos)
	# Out from the shell, clear of it.
	d.global_position = at + (at - lattice.global_position).normalized() * 6.0
	auto.go_to(PackedVector3Array([d.global_position]))
	command.add(d, c)
	returned[id] = d

func _on_finished(result: JobResult) -> void:
	if not result.completed or phase != Phase.DONE:
		return
	for id in Roster.ids():
		var alive := Roster.is_alive(id)
		var text := Bark.memorial(id)
		if alive:
			var lines: Array = Bark.lines_of(id).get("epilogue", {}).get("active", [])
			text = Bark.text_of(lines[0]) if not lines.is_empty() else ""
		result.epilogue.append({"id": id, "text": text, "alive": alive})
