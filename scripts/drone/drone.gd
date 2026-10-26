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

## Current thrust per motor in newtons, clamped to [0, max_thrust] when applied.
var motor_thrusts := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

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

func set_motor_thrusts(thrusts: PackedFloat32Array) -> void:
	motor_thrusts = thrusts

# Forces are queued here, before the physics step that integrates them, so thrust
# set on a frame acts on that same frame's step.
func _physics_process(_delta: float) -> void:
	var basis := global_transform.basis
	var up := basis.y
	var yaw := 0.0
	for i in MOTOR_COUNT:
		var t := clampf(motor_thrusts[i], 0.0, max_thrust)
		apply_force(up * t, basis * motor_offset(i, arm_length))
		yaw += motor_spin(i) * t * yaw_torque_per_thrust
	apply_torque(up * yaw)
	apply_central_force(-drag * linear_velocity)
	apply_torque(-angular_drag * angular_velocity)
