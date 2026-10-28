class_name FleetCrew
extends Node3D
# A fleet job's drones, one per living crew member tagged can_fly, in roster
# order, each the Drone scene under an Autopilot, placed at this node's Marker3D
# slots. A dead crew member is one fewer drone. Hands the fleet to the command
# view (with each drone's pilot, for portraits), the job runner (its first
# drone), and a relay, so it must sit before them in the scene. Pilots answer
# orders through `bark` (event "order").

const DRONE := preload("res://scenes/drone/drone.tscn")
const TAG := &"can_fly"

@export var command: CommandView
@export var runner: JobRunner
@export var relay: Relay
@export var bark: Bark
## Passed to each autopilot; above 0 it flies through waypoints (relays).
@export var corner_speed := 0.0

var drones: Array[Drone] = []
## Drone -> the crew member flying it.
var pilots := {}

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
		d.add_child(auto)
		d.intent_source = auto
		add_child(d)
		d.global_transform = slots[i].global_transform
		drones.append(d)
		pilots[d] = ids[i]
	if command:
		command.drones = drones
		for d in drones:
			command.pilots[d] = Roster.character(pilots[d])
		command.waypoint_queued.connect(func(d, _p): order(d))
		if command.camera_rig and not drones.is_empty():
			command.camera_rig.target = drones[0]
	if relay:
		relay.drones = drones
	if runner and not drones.is_empty():
		runner.drone = drones[0]

## The crew member flying `d`, or empty.
func pilot_of(d: Drone) -> StringName:
	return pilots.get(d, &"")

## The drone's pilot acknowledges an order.
func order(d: Drone) -> Dictionary:
	if bark == null or pilot_of(d) == &"":
		return {}
	return bark.say(&"order", pilot_of(d))
