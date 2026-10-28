class_name Debris
extends RigidBody3D
# A loose piece of a hazard: held frozen until its event, then a free body.
# Pre-authored, never generated at runtime. HazardZones notice it landing.
# Each impact knocks once (Story 14.6), louder the harder it hit.

const GROUP := &"debris"
const IMPACT := &"debris_impact"

## Event that lets it fall. Empty means it is loose from the start.
@export var release_on: StringName
## Held until the drone touches it, then knocked loose with a share of its velocity.
@export var release_on_contact := false
## Share of the drone's velocity a knock passes on.
@export var knock := 0.3
## Velocity and spin given on release, so a supported piece topples or falls in.
@export var release_velocity := Vector3.ZERO
@export var release_spin := Vector3.ZERO
## Change in speed (m/s) an impact needs to sound at all, and to sound at full volume.
@export var quiet_impact := 1.0
@export var loud_impact := 10.0
## A body touching again within this many seconds is the same contact.
@export var contact_gap := 0.15

## Impacts this piece has played, and the speed of the last one.
var impacts := 0
var last_impact_speed := 0.0

var _velocity := Vector3.ZERO
var _time := 0.0
var _touched := {}  # body instance id -> time of its last contact

func _ready() -> void:
	add_to_group(GROUP)
	contact_monitor = true
	max_contacts_reported = maxi(max_contacts_reported, 4)
	body_entered.connect(_on_body_entered)
	if release_on or release_on_contact:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true
	if release_on_contact:
		_add_sensor()

## An area a little larger than the piece that notices the drone touching it.
func _add_sensor() -> void:
	var sensor := Area3D.new()
	sensor.name = "Sensor"
	for c in get_children():
		if c is CollisionShape3D:
			var s := CollisionShape3D.new()
			s.shape = c.shape
			s.transform = c.transform.scaled_local(Vector3.ONE * 1.15)
			sensor.add_child(s)
	add_child(sensor)
	sensor.body_entered.connect(func(body: Node3D) -> void:
		if body is Drone and freeze:
			release()
			linear_velocity = body.linear_velocity * knock)

func release() -> void:
	freeze = false
	linear_velocity = release_velocity
	angular_velocity = release_spin

func _physics_process(delta: float) -> void:
	_time += delta
	_velocity = linear_velocity

## One knock per contact. A drone plays its own; between two loose pieces only
## one of them plays, so each impact is heard once.
func _on_body_entered(body: Node) -> void:
	if freeze or body is Drone:
		return
	if body is Debris and not body.freeze and body.get_instance_id() < get_instance_id():
		return
	var id := body.get_instance_id()
	var again := _time - float(_touched.get(id, -INF)) < contact_gap
	_touched[id] = _time
	if again:
		return
	var speed := (_velocity - linear_velocity).length()
	if body is Debris:
		speed = maxf(speed, (body._velocity - body.linear_velocity).length())
	if speed < quiet_impact:
		return
	impacts += 1
	last_impact_speed = speed
	Sfx.play(IMPACT, global_position, linear_to_db(clampf(speed / loud_impact, 0.05, 1.0)))
