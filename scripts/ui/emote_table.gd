class_name EmoteTable
extends Resource
# Which emote shows for which event or expression (Story 18.3), and when none
# ever does: serious events (warnings, strikes, injuries, memorials) and whole
# job types (the Lattice) stay sincere.

@export var emotes: Array[Emote] = []
## Lines on these events never show an emote, whatever their face.
@export var quiet_events: Array[StringName] = []
## No line on a job of these types shows an emote.
@export var quiet_job_types: Array[StringName] = []

## The emote for `key` (an event or an expression), or null.
func find(key: StringName) -> Emote:
	for e in emotes:
		if e.key == key:
			return e
	return null

## The emote for a line on `event` with `face`, on a job of `job_type`: none for
## a quiet event or job, else the event's emote, else the face's.
func for_line(event: StringName, face: StringName, job_type: StringName = &"") -> Emote:
	if event in quiet_events or job_type in quiet_job_types:
		return null
	var e := find(event)
	return e if e else find(face)
