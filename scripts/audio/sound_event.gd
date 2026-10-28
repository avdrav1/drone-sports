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
## A baked low-passed copy of a loop, for snow's hush (Story 14.7); null if none.
## Same length as the loop, so the two play in step and crossfade.
@export var muffled: AudioStream
## Added to volume_db for the muffled copy.
@export var muffled_db := 0.0
