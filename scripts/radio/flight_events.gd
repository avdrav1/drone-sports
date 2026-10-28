class_name FlightEvents
extends Resource
# Thresholds for the crew's flight events (Story 17.8): what counts as a takeoff,
# a near miss, a low pass, top speed, low battery, a crash, and a long hover, and
# how long each event waits before it can fire again. Read by FlightWatcher.

const EVENTS: Array[StringName] = [&"takeoff", &"near_miss", &"low_pass", &"top_speed", &"battery_low",
	&"crash", &"reset", &"weather_change", &"long_hover"]

## Height above ground, m, at or under which the drone is on the ground.
@export var grounded_height := 0.3
## Height above ground, m, a grounded drone must climb past to take off.
@export var takeoff_height := 1.5
## Static geometry within this many metres, beside or above, is a close pass.
@export var near_miss_distance := 2.0
## Speed, m/s, a close pass needs to be a near miss.
@export var near_miss_speed := 8.0
## Height above ground, m, under which a fast pass is low.
@export var low_pass_height := 3.0
## Speed, m/s, a low pass needs.
@export var low_pass_speed := 10.0
## Speed, m/s, that counts as flat out.
@export var top_speed := 25.0
## Battery fraction at which the battery is low.
@export_range(0.0, 1.0) var battery_low := 0.25
## Speed, m/s, just before a contact, at or above which it is a crash.
@export var crash_speed := 4.0
## Seconds held still in the air that make a long hover.
@export var hover_time := 20.0
## Speed, m/s, under which the drone is still.
@export var hover_speed := 0.5
## Event -> seconds before it may fire again. Events not listed use default_cooldown.
@export var cooldowns := {}
@export var default_cooldown := 15.0

func cooldown(event: StringName) -> float:
	return float(cooldowns.get(event, cooldowns.get(String(event), default_cooldown)))
