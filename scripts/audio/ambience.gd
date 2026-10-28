class_name Ambience
extends AudioStreamPlayer
# A place's background loop (Story 14.6): desert wind, city hum, the job board's
# room tone. One sits in each place's scene (desert.tscn, city.tscn, the board),
# so every scene built on that place sounds like it with no extra wiring. Plays
# the first stream of a SoundEvent on that event's bus, looping, from the start.
# Snow hushes it (Story 14.7): when the event has a baked muffled copy, a second
# player runs it in step and `hush` crossfades between the two.

## SoundEvent id of the loop.
@export var event: StringName

## 0 the loop as recorded, 1 fully muffled. WeatherSound sets it in snow.
var hush := 0.0:
	set(value):
		hush = clampf(value, 0.0, 1.0)
		_mix()
## The muffled copy's player, or null when the event has none.
var muffled: AudioStreamPlayer
var _base_db := 0.0
var _muffled_db := 0.0

func _ready() -> void:
	var e := Sfx.bank.find(event) if Sfx.bank else null
	if e == null or e.streams.is_empty():
		push_warning("Ambience: no sound event '%s'" % event)
		return
	stream = e.streams[0]
	bus = e.bus
	_base_db = e.volume_db
	if e.muffled:
		muffled = AudioStreamPlayer.new()
		muffled.name = "Muffled"
		muffled.stream = e.muffled
		muffled.bus = e.bus
		_muffled_db = e.volume_db + e.muffled_db
		add_child(muffled)
		muffled.play()
	_mix()
	play()

## Equal-power crossfade from the loop to its muffled copy by `hush`.
func _mix() -> void:
	if muffled == null:
		volume_db = _base_db
		return
	volume_db = _base_db + linear_to_db(maxf(sqrt(1.0 - hush), 0.0001))
	muffled.volume_db = _muffled_db + linear_to_db(maxf(sqrt(hush), 0.0001))
