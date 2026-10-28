class_name Stem
extends Resource
# One part of a Score (Story 16.1): a looping stream and the level it plays at.
# Every stem of a score has the same length in samples, so they stay in step.

@export var id: StringName
@export var stream: AudioStream
## Where the stem sits when nothing has set it (dB).
@export var level_db := 0.0
## A baked low-passed copy of the stream for snow's hush (Story 16.8), the same
## length so the two play in step; Music crossfades to it by Music.hush.
@export var muffled: AudioStream
