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
## Weather this drone flies in: rain, cold, and snow (Story 13.8). Set by
## Weather.apply. Null is clear. Like wind, felt only with the environment sim on.
@export var weather: Weather

## Extra air drag in full rain, N per m/s; scales with intensity.
@export var rain_drag := 0.15
## Weight of water on the frame in full rain, N; scales with intensity.
@export var rain_load := 0.3
## Battery capacity lost per °C below COLD_BELOW, as a fraction of full.
@export var cold_capacity_loss := 0.02
## Seconds of full snow below freezing to ice the props completely.
@export var ice_build_time := 20.0
## Seconds to shed full ice once out of snow or above freezing.
@export var ice_shed_time := 8.0
## Fraction of max thrust full ice takes away (the cap).
@export var ice_thrust_loss := 0.3

## Seconds an empty battery takes to fade thrust to zero.
const BATTERY_FADE_TIME := 3.0
## Batteries lose capacity below this temperature, °C.
const COLD_BELOW := 10.0
## Cold never takes a battery below this fraction of its capacity.
const MIN_COLD_CAPACITY := 0.4

## Crash recovery put the drone back upright (see CrashRecovery).
signal recovered

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
## Ice on the props, 0 clear to 1 at the thrust-loss cap.
var icing := 0.0
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
	icing = 0.0
	_empty_for = 0.0
	var recovery := get_node_or_null("Recovery") as CrashRecovery
	if recovery:
		recovery.reset()
	if assists:
		assists.reset()
	if intent_source:
		intent_source.reset()

## Puts the drone at `xform`, at rest, after a crash it could not fly out of.
## Unlike reset, the battery is untouched. Assists and the intent source forget
## held state, as on reset.
func recover(xform: Transform3D) -> void:
	global_transform = xform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if assists:
		assists.reset()
	if intent_source:
		intent_source.reset()
	recovered.emit()

func assist_summary() -> String:
	return assists.summary() if assists else "(none)"

func set_motor_thrusts(thrusts: PackedFloat32Array) -> void:
	motor_thrusts = thrusts

## Fraction of commanded thrust the motors can deliver: 1, fading to 0 after the battery empties.
func power() -> float:
	return clampf(1.0 - _empty_for / BATTERY_FADE_TIME, 0.0, 1.0)

## The wind where the drone is: stronger with height, calmer in a city's lee (Story 13.4).
func wind_velocity() -> Vector3:
	if not intent.environment_sim:
		return Vector3.ZERO
	return measured_wind()

## The wind where the drone is, whether or not the sim lets it push: what the
## air is doing there (weather sound hears it, Story 14.7). Zero in still air.
func measured_wind() -> Vector3:
	if wind == null:
		return Vector3.ZERO
	var city: City = get_tree().get_first_node_in_group(City.SHELTER_GROUP) if is_inside_tree() else null
	if city and city.plan:
		return wind.sample(_time, city.to_local(global_position), city.plan)
	return wind.sample(_time, global_position)

## The rain's intensity where the sim feels it; 0 with the sim off or no rain.
func rain() -> float:
	if weather == null or not intent.environment_sim or weather.precipitation != Weather.Precipitation.RAIN:
		return 0.0
	return weather.intensity

## Fraction of the battery's rated capacity at the air temperature: 1 at
## COLD_BELOW and up, less in the cold. Always 1 with the sim off.
func battery_capacity() -> float:
	if weather == null or not intent.environment_sim:
		return 1.0
	return clampf(1.0 - cold_capacity_loss * (COLD_BELOW - weather.temperature), MIN_COLD_CAPACITY, 1.0)

## Max thrust per motor after ice. Ice only costs thrust with the sim on.
func iced_max_thrust() -> float:
	if not intent.environment_sim:
		return max_thrust
	return max_thrust * (1.0 - ice_thrust_loss * icing)

# Snow below freezing builds ice at its intensity; anything else sheds it.
func _update_icing(delta: float) -> void:
	if not intent.environment_sim:
		return
	var snowing: bool = weather != null and weather.precipitation == Weather.Precipitation.SNOW and weather.intensity > 0.0
	if snowing and weather.temperature < 0.0:
		icing = minf(icing + weather.intensity * delta / ice_build_time, 1.0)
	else:
		icing = maxf(icing - delta / ice_shed_time, 0.0)

func _drain_battery(delta: float) -> void:
	if not intent.environment_sim:
		return
	if battery <= 0.0:
		_empty_for += delta
		return
	var draw := 0.0
	for t in motor_thrusts:
		draw += clampf(t, 0.0, max_thrust)
	battery = maxf(battery - draw / (hover_thrust() * MOTOR_COUNT) * delta / (battery_flight_time * battery_capacity()), 0.0)

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
	_update_icing(delta)
	# A frozen body keeps forces queued while frozen and releases them all on unfreeze.
	if freeze:
		return
	var basis := global_transform.basis
	var up := basis.y
	var yaw := 0.0
	var p := power()
	var top := iced_max_thrust()
	for i in MOTOR_COUNT:
		var t := clampf(motor_thrusts[i], 0.0, top) * p
		apply_force(up * t, basis * motor_offset(i, arm_length))
		yaw += motor_spin(i) * t * yaw_torque_per_thrust
	apply_torque(up * yaw)
	var wet := rain()
	apply_central_force(-(drag + rain_drag * wet) * (linear_velocity - wind_velocity()))
	if wet > 0.0:
		apply_central_force(Vector3.DOWN * rain_load * wet)
	apply_torque(-angular_drag * angular_velocity)
