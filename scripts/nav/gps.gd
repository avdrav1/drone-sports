class_name Gps
extends Node
# The drone's GPS fix on a MapData grid. Signal is always full for now;
# jamming zones (Story 10.5) will lower it. Reads only: never moves the drone.

@export var map: MapData
@export var drone: Node3D

## 0 (no fix) to 1 (full).
func signal_strength() -> float:
	return 1.0

func grid_ref() -> String:
	return map.grid_ref(drone.global_position) if map and drone else "--"

## Cell plus metres east and north, e.g. "C4  0123E 0456N".
func readout() -> String:
	if map == null or drone == null:
		return "NO MAP"
	var m := map.grid_metres(drone.global_position)
	return "%s  %04dE %04dN" % [grid_ref(), roundi(m.x), roundi(m.y)]
