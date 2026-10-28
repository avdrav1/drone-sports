class_name Ambience
extends AudioStreamPlayer
# A place's background loop (Story 14.6): desert wind, city hum, the job board's
# room tone. One sits in each place's scene (desert.tscn, city.tscn, the board),
# so every scene built on that place sounds like it with no extra wiring. Plays
# the first stream of a SoundEvent on that event's bus, looping, from the start.

## SoundEvent id of the loop.
@export var event: StringName

func _ready() -> void:
	var e := Sfx.bank.find(event) if Sfx.bank else null
	if e == null or e.streams.is_empty():
		push_warning("Ambience: no sound event '%s'" % event)
		return
	stream = e.streams[0]
	bus = e.bus
	volume_db = e.volume_db
	play()
