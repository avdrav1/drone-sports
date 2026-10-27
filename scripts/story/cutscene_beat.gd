class_name CutsceneBeat
extends Resource
# One shot of a cutscene, as data: what to show, where the camera goes, and
# what the caption says.

enum Camera { ORBIT, CHASE, FIXED }

## Scene shown behind the caption. Empty keeps the previous beat's backdrop.
@export_file("*.tscn") var backdrop := ""
## For job scenes: run the job (unpaid, HUD hidden) so racers fly.
@export var live := false
@export var camera := Camera.ORBIT
## Node in the backdrop the camera circles or follows.
@export var focus: NodePath
## Orbit: radius and height above the focus, m; degrees per second.
@export var orbit_radius := 40.0
@export var orbit_height := 15.0
@export var orbit_speed := 6.0
## Chase and fixed: camera offset from the focus, in the focus's frame for chase.
@export var offset := Vector3(0, 2, 7)
## Small caption at the bottom.
@export_multiline var caption := ""
## Large centred text, e.g. the title card.
@export var title := ""
## Character shown beside the caption; `silhouette` blacks them out.
@export var portrait: StringName
@export var silhouette := false
## Frame the shot as the arcade home game.
@export var bezel := false
@export var duration := 8.0
