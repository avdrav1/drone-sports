class_name SoundBank
extends Resource
# Every sound event the game can play, as data (data/audio/bank.tres). A list,
# not a folder scan, so exported builds find them.

@export var events: Array[SoundEvent] = []

func find(id: StringName) -> SoundEvent:
	for e in events:
		if e.id == id:
			return e
	return null
