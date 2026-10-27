class_name Debris
extends RigidBody3D
# A loose piece of a hazard: held frozen until its event, then a free body.
# Pre-authored, never generated at runtime. HazardZones notice it landing.

const GROUP := &"debris"

## Event that lets it fall. Empty means it is loose from the start.
@export var release_on: StringName
## Held until the drone touches it, then knocked loose with a share of its velocity.
@export var release_on_contact := false
## Share of the drone's velocity a knock passes on.
@export var knock := 0.3
## Velocity and spin given on release, so a supported piece topples or falls in.
@export var release_velocity := Vector3.ZERO
@export var release_spin := Vector3.ZERO

func _ready() -> void:
	add_to_group(GROUP)
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
