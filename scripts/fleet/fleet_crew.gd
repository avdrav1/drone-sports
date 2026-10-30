class_name FleetCrew
extends Node3D
# A fleet job's drones, one per living crew member tagged can_fly, in roster
# order, each the Drone scene under an Autopilot, placed at this node's Marker3D
# slots. A dead crew member is one fewer drone. Hands the fleet to the command
# view (with each drone's pilot, for portraits), the job runner (its first
# drone), and a relay, so it must sit before them in the scene. Pilots answer
# orders through `bark` (event "order").
# Story 18.11: each drone flies in its pilot's FlightStyle, and a pilot whose
# style gives advice radios the fleet some (event "advice") when a relay leg
# ends or goes wrong, or a drone reaches its last waypoint; never on a boss job.
# Story 27.6: drone N (from 1) is built from hangar slot N, its livery and
# parts only, by Garage.apply; the runner applies its own lead drone at the
# briefing, as ever, from the slot the drone carries. Slot 0, the player's
# drone (its parts, livery, upgrades and pilot's edge), never reaches a fleet
# drone.

const DRONE := preload("res://scenes/drone/drone.tscn")
const TAG := &"can_fly"

@export var command: CommandView
@export var runner: JobRunner
@export var relay: Relay
@export var bark: Bark
## Passed to each autopilot; above 0 it flies through waypoints (relays).
@export var corner_speed := 0.0
## The runner's drone is the fleet's first. Off when the pilot flies their own
## drone as well (the Lattice).
@export var lead_runner := true
## Least seconds between two pieces of advice.
@export var advice_gap := 8.0

var drones: Array[Drone] = []
## Drone -> the crew member flying it.
var pilots := {}
var _since_advice := INF

## Crew who fly, living or not, in roster order.
static func tagged() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in Roster.ids():
		var c: Character = Roster.character(id)
		if c and TAG in c.tags:
			out.append(id)
	return out

## Living crew who fly, in roster order.
static func flyers() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in tagged():
		if Roster.is_alive(id):
			out.append(id)
	return out

func _ready() -> void:
	var slots := get_children().filter(func(n): return n is Marker3D)
	var ids := flyers()
	for i in mini(ids.size(), slots.size()):
		var c: Character = Roster.character(ids[i])
		var d: Drone = DRONE.instantiate()
		d.name = c.name
		var auto := Autopilot.new()
		auto.name = "Autopilot"
		auto.corner_speed = corner_speed
		fly_as(auto, c)
		auto.finished.connect(advise)
		d.add_child(auto)
		d.intent_source = auto
		add_child(d)
		d.global_transform = slots[i].global_transform
		drones.append(d)
		pilots[d] = ids[i]
		d.set_meta(Garage.SLOT, i + 1)
		if not (runner and lead_runner and i == 0):
			Garage.apply(d)
		DroneFace.wear(d, c)
	if command:
		command.drones = drones
		for d in drones:
			command.pilots[d] = Roster.character(pilots[d])
		command.waypoint_queued.connect(func(d, _p): order(d))
		if command.camera_rig and not drones.is_empty():
			command.camera_rig.target = drones[0]
	if relay:
		relay.drones = drones
		relay.leg_done.connect(func(_l, _d, _t): advise())
		relay.lap_invalid.connect(func(_d, _why): advise())
	if runner and lead_runner and not drones.is_empty():
		runner.drone = drones[0]
	# The fleet first flown (Story 27.3's achievement) once a real run goes live.
	if runner and not drones.is_empty():
		runner.state_changed.connect(func(s, _p):
			if s == JobRunner.State.LIVE and runner.pays_out:
				StoryFlags.set_flag(Achievement.FLEET_FLAG))

## Gives `auto` the way `c` flies, swaying on their own phase.
static func fly_as(auto: Autopilot, c: Character) -> void:
	if c == null:
		return
	auto.style = c.flight_style
	auto.wobble_phase = float(hash(c.id) % 628) / 100.0

func _process(delta: float) -> void:
	_since_advice += delta

## The living pilot in this fleet whose style gives advice, or empty.
func adviser() -> StringName:
	for d in drones:
		var id := pilot_of(d)
		var c: Character = Roster.character(id)
		if is_instance_valid(d) and c and c.flight_style and c.flight_style.advice and Roster.is_alive(id):
			return id
	return &""

## The adviser radios a tip, at most once an advice_gap and never on a boss job.
func advise() -> Dictionary:
	var id := adviser()
	if bark == null or id == &"" or _since_advice < advice_gap:
		return {}
	if runner and runner.job and runner.job.job_type == &"boss":
		return {}
	var line := bark.say(&"advice", id)
	if not line.is_empty():
		_since_advice = 0.0
	return line

## The crew member flying `d`, or empty.
func pilot_of(d: Drone) -> StringName:
	return pilots.get(d, &"")

## The drone's pilot acknowledges an order.
func order(d: Drone) -> Dictionary:
	if bark == null or pilot_of(d) == &"":
		return {}
	return bark.say(&"order", pilot_of(d))
