class_name Emote
extends Resource
# A little cartoon emote by a crew member's face (Story 18.3): what sets it off,
# how long it stays, and which drawing EmoteBubble makes of it.

## The event (e.g. near_miss, clean_finish, best) or the expression (one of
## CharacterPortrait.EXPRESSIONS) that shows this emote.
@export var key: StringName
## One of EmoteBubble.DRAWINGS.
@export var drawing: StringName = &"hearts"
## Seconds it shows before it clears.
@export var time := 2.0
## Its fill colour, under a dark ink outline.
@export var color := Color(1.0, 0.4, 0.55)
## Waits for the face to stop talking before it shows, e.g. notes when idle and happy.
@export var idle := false
