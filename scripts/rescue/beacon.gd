class_name Beacon
extends Node3D
# A distress beacon the player finds by ear and by a HUD arc, never by a marker.
# Strength is 1 at the beacon, falling smoothly to 0 at `range`. Pings come
# faster and louder as strength rises. The ping is a short tone made in code.

## Distance at which the beacon falls silent, m.
@export var range := 150.0
## Seconds between pings at zero and at full strength.
@export var slow_interval := 2.0
@export var fast_interval := 0.2
## The listener: usually the player's drone.
@export var listener: Node3D

signal pinged(strength: float)

var player: AudioStreamPlayer
var _since := 0.0

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.stream = _tone()
	add_child(player)

## 0..1 for a listener `distance` metres away.
func strength_at(distance: float) -> float:
	var t := clampf(1.0 - distance / range, 0.0, 1.0)
	return t * t

func strength() -> float:
	return strength_at(listener.global_position.distance_to(global_position)) if listener else 0.0

func interval() -> float:
	return lerpf(slow_interval, fast_interval, strength())

func _process(delta: float) -> void:
	var s := strength()
	if s <= 0.0:
		_since = 0.0
		return
	_since += delta
	if _since >= interval():
		_since = 0.0
		player.volume_db = linear_to_db(lerpf(0.15, 1.0, s))
		player.play()
		pinged.emit(s)

## A 90 ms 1.3 kHz blip with a quick decay.
static func _tone() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.09)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var v := sin(TAU * 1320.0 * t) * exp(-t * 40.0) * 0.6
		data.encode_s16(i * 2, int(v * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
