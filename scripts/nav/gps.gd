class_name Gps
extends Node
# The drone's GPS fix on a MapData grid. JammingZones lower the signal; a weak
# signal drifts the fix (seeded, so runs reproduce) and no signal loses it.
# Reads only: never moves the drone.

@export var map: MapData
@export var drone: Node3D
## Seeds the drift so a run reproduces.
@export var seed := 0
## Metres the fix wanders at zero signal; scales down to none at full signal.
@export var max_drift := 30.0
## How fast the drift wanders, in noise units per second.
@export var drift_rate := 0.4

## Seconds of physics since the GPS started; drives the drift.
var time := 0.0
var _noise: FastNoiseLite

func _physics_process(delta: float) -> void:
	time += delta

## 0 (no fix) to 1 (full): the weakest of the zones the drone is in.
func signal_strength() -> float:
	if drone == null or not is_inside_tree():
		return 1.0
	var scope: Node = owner if owner else (get_parent() if get_parent() else get_tree().root)
	var s := 1.0
	for z in JammingZone.collect(scope):
		s = minf(s, z.strength_at(drone.global_position))
	return s

func has_fix() -> bool:
	return signal_strength() > 0.0

## Ground offset of the fix from the truth, metres east (x) and south (z).
func drift() -> Vector3:
	var loss := 1.0 - signal_strength()
	if loss <= 0.0:
		return Vector3.ZERO
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.seed = seed
	var t := time * drift_rate * 100.0
	return Vector3(_noise.get_noise_2d(t, 0.0), 0.0, _noise.get_noise_2d(t, 1000.0)) * max_drift * loss

## Where the GPS thinks the drone is.
func fix_position() -> Vector3:
	return drone.global_position + drift()

func grid_ref() -> String:
	if map == null or drone == null:
		return "--"
	return map.grid_ref(fix_position()) if has_fix() else "--"

## Cell plus metres east and north, e.g. "C4  0123E 0456N".
func readout() -> String:
	if map == null or drone == null:
		return "NO MAP"
	if not has_fix():
		return "NO FIX"
	var p := fix_position()
	var m := map.grid_metres(p)
	return "%s  %04dE %04dN" % [map.grid_ref(p), roundi(m.x), roundi(m.y)]
