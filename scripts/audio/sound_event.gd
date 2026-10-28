class_name SoundEvent
extends Resource
# One named sound: the files it can play (one is picked each time), how loud,
# how much the pitch varies, and which bus it goes through.

@export var id: StringName
@export var streams: Array[AudioStream] = []
@export var volume_db := 0.0
## Each play is pitched by a random factor within ± this.
@export var pitch_variance := 0.0
@export var bus: StringName = &"World"
