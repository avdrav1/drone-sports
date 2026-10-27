class_name Drone
extends RigidBody3D
# The only flight model in the game. Four motor thrusts on a RigidBody3D.
# Body axes: forward is -Z, right is +X, up is +Y. Motors sit in an X:
# 0 front-left, 1 front-right, 2 back-left, 3 back-right.
# Motors 0 and 3 spin one way, 1 and 2 the other; their drag torque is yaw.

const MOTOR_COUNT := 4

## Linear air drag, N per m/s of airspeed.
@export var drag := 0.3
## Rotational drag, N·m per rad/s.
@export var angular_drag := 0.08
## Max thrust per motor, N.
@export var max_thrust := 4.5
## Distance from body center to each motor along X and Z, m.
@export var arm_length := 0.15
## Yaw torque per newton of motor thrust, N·m/N.
@export var yaw_torque_per_thrust := 0.05

## Flight time on a full battery at hover thrust, s.
@export var battery_flight_time := 300.0
## Wind this drone flies in. Set by the scene. Null is still air.
@export var wind: Wind

## Seconds an empty battery takes to fade thrust to zero.
const BATTERY_FADE_TIME := 3.0

## Where intent comes from. Null means motor thrusts are set directly.
@export var intent_source: IntentSource

## Assists that rewrite intent before the mixer. Optional.
@onready var assists: AssistPipeline = get_node_or_null("Assists")

## The intent the mixer used this frame.
var intent := Intent.new()
## Current thrust per motor in newtons, clamped to [0, max_thrust] when applied.
var motor_thrusts := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
## Battery charge, 1 full to 0 empty.
var battery := 1.0
var _empty_for := 0.0
var _time := 0.0

func _init() -> void:
	can_sleep = false
	# Drag is applied explicitly below so the project's default damping never leaks in.
	linear_damp_mode = DAMP_MODE_REPLACE
	angular_damp_mode = DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0

static func motor_offset(i: int, arm: float) -> Vector3:
	var x := -arm if i % 2 == 0 else arm
	var z := -arm if i < 2 else arm
	return Vector3(x, 0.0, z)

static func motor_spin(i: int) -> float:
	return 1.0 if i == 0 or i == 3 else -1.0

func gravity() -> float:
	return ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_scale

## Thrust per motor that exactly balances gravity when level.
func hover_thrust() -> float:
	return mass * gravity() / MOTOR_COUNT

## Puts the drone back at `xform`, at rest, with a full battery. Assists and the
## intent source forget anything they were holding.
func reset(xform: Transform3D) -> void:
	global_transform = xform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	motor_thrusts = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	battery = 1.0
	_empty_for = 0.0
	if assists:
		assists.reset()
	if intent_source:
		intent_source.reset()

func assist_summary() -> String:
	return assists.summary() if assists else "(none)"

func set_motor_thrusts(thrusts: PackedFloat32Array) -> void:
	motor_thrusts = thrusts

## Fraction of commanded thrust the motors can deliver: 1, fading to 0 after the battery empties.
func power() -> float:
	return clampf(1.0 - _empty_for / BATTERY_FADE_TIME, 0.0, 1.0)

func wind_velocity() -> Vector3:
	return wind.sample(_time) if wind and intent.environment_sim else Vector3.ZERO

func _drain_battery(delta: float) -> void:
	if not intent.environment_sim:
		return
	if battery <= 0.0:
		_empty_for += delta
		return
	var draw := 0.0
	for t in motor_thrusts:
		draw += clampf(t, 0.0, max_thrust)
	battery = maxf(battery - draw / (hover_thrust() * MOTOR_COUNT) * delta / battery_flight_time, 0.0)

# Forces are queued here, before the physics step that integrates them, so thrust
# set on a frame acts on that same frame's step.
func _physics_process(delta: float) -> void:
	if intent_source:
		intent = intent_source.read_intent()
		if assists:
			assists.run(intent, self, delta)
		motor_thrusts = Mixer.mix(intent, max_thrust)
	_time += delta
	_drain_battery(delta)
	# A frozen body keeps forces queued while frozen and releases them all on unfreeze.
	if freeze:
		return
	var basis := global_transform.basis
	var up := basis.y
	var yaw := 0.0
	var p := power()
	for i in MOTOR_COUNT:
		var t := clampf(motor_thrusts[i], 0.0, max_thrust) * p
		apply_force(up * t, basis * motor_offset(i, arm_length))
		yaw += motor_spin(i) * t * yaw_torque_per_thrust
	apply_torque(up * yaw)
	apply_central_force(-drag * (linear_velocity - wind_velocity()))
	apply_torque(-angular_drag * angular_velocity)
