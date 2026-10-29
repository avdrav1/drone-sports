class_name ArcadeFraming
extends Resource
# The Act 1 "home video game" dressing, as data: bezel text, a fake leaderboard,
# and the scout's one-line message after the player's first top-three finish.

## Jobs carrying this tag get the framing.
@export var tag: StringName = &"act1"
@export var title := ""
@export var footer := ""
## Fake leaderboard: handle -> race time in seconds.
@export var leaderboard := {}
## Character id of the scout, and the name shown until characters are data (Epic 7).
@export var scout_id: StringName = &"drona"
@export var scout_name := ""
@export_multiline var scout_line := ""
## Story flag set when the scout message fires.
@export var scout_flag: StringName = &"scouted"
## Finishing at this place or better earns the message.
@export var scout_place := 3
