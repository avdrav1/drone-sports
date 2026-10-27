class_name MapData
extends Resource
# A flying area as the map sees it: bounds, a GPS grid, and named landmarks.
# The grid origin is the south-west corner of `bounds`. Columns are letters
# running east, rows are numbers running north from 1. North is -Z.

@export var title := ""
## The area on the ground: position is the (min x, min z) corner, size in m.
@export var bounds := Rect2(-200, -200, 400, 400)
## Grid cell edge, m.
@export var cell_size := 50.0
## Landmark name -> world position.
@export var landmarks := {}

## Metres east and north of the grid origin.
func grid_metres(p: Vector3) -> Vector2:
	return Vector2(p.x - bounds.position.x, bounds.end.y - p.z)

func cell_of(p: Vector3) -> Vector2i:
	var m := grid_metres(p)
	return Vector2i(floori(m.x / cell_size), floori(m.y / cell_size))

## The cell as a letter and a number, e.g. "C4".
func grid_ref(p: Vector3) -> String:
	var c := cell_of(p)
	return "%s%d" % [char(65 + posmod(c.x, 26)), c.y + 1]
