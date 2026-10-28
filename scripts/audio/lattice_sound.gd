class_name LatticeSound
extends AudioStreamPlayer3D
# The Lattice's low drone and its power-down (Story 14.8). A child of the
# Lattice, so the drone comes from the shell and swells as you fly in. The drone
# loops from the start of the job; when the fight disables the boss it stops
# for good and the power-down plays once in its place.

const DRONE := &"lattice_drone"
const POWER_DOWN := &"lattice_power_down"

@export var fight: LatticeFight

## True while the drone loop runs; false for good once powered down.
var droning := false
var powered_down := false

func _ready() -> void:
	var e := Sfx.bank.find(DRONE) if Sfx.bank else null
	if e == null or e.streams.is_empty():
		push_warning("LatticeSound: no sound event '%s'" % DRONE)
		return
	stream = e.streams[0]
	bus = e.bus
	volume_db = e.volume_db
	if fight:
		fight.boss_disabled.connect(power_down)
	play()
	droning = true

## The drone stops and the power-down plays, once.
func power_down() -> void:
	if powered_down:
		return
	powered_down = true
	droning = false
	stop()
	Sfx.play(POWER_DOWN, global_position)
