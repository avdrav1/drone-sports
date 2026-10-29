class_name CourseData
extends Resource
# A race course as data: gate placements in order, gate size, laps, and bounds.
# Gate 0 is the start/finish line of a closed course; an open course starts at
# gate 0 and finishes at its last gate, once. Each gate is passed along its -Z axis.

@export var title := ""
@export var gates: Array[Transform3D] = []
## Opening width and height, m.
@export var gate_size := Vector2(4.0, 3.0)
@export var laps := 2
## False for a point-to-point path: one run from gate 0 to the last gate, no laps.
@export var closed := true
## Racers must stay inside this box.
@export var bounds := AABB(Vector3(-100, 0, -150), Vector3(200, 40, 200))
