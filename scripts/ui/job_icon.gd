class_name JobIcon
extends Control
# A job type's icon on its board card (Story 17.4), drawn in code like the faces
# so it stays sharp at any size: a flag for a race, a parcel for a delivery, a
# lens for an inspection, a cracked block for demolition, a cross for rescue,
# a formation for fleet work, a baton pass for a relay, a lattice for the boss.
# `locked` draws a padlock. Unknown kinds draw a plain ring.

## A Job.job_type, or `locked`.
@export var kind: StringName = &"":
	set(v):
		kind = v
		queue_redraw()
@export var color := Color(1.0, 0.76, 0.25):
	set(v):
		color = v
		queue_redraw()

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(48, 48)

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var r := s * 0.42
	var w := maxf(s * 0.07, 1.5)
	match kind:
		&"race":
			draw_line(c + Vector2(-r * 0.7, r), c + Vector2(-r * 0.7, -r), color, w, true)
			for i in 3:
				for j in 4:
					if (i + j) % 2 == 0:
						draw_rect(Rect2(c + Vector2(-r * 0.7 + j * r * 0.4, -r + i * r * 0.36), Vector2(r * 0.4, r * 0.36)), color)
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r), Vector2(r * 1.6, r * 1.08)), color, false, w * 0.6)
		&"delivery":
			var box := Rect2(c - Vector2(r * 0.85, r * 0.7), Vector2(r * 1.7, r * 1.5))
			draw_rect(box, color, false, w)
			draw_line(Vector2(c.x, box.position.y), Vector2(c.x, box.end.y), color, w)
			draw_line(Vector2(box.position.x, c.y - r * 0.1), Vector2(box.end.x, c.y - r * 0.1), color, w)
		&"inspection":
			draw_arc(c - Vector2(r * 0.2, r * 0.2), r * 0.6, 0.0, TAU, 32, color, w, true)
			draw_line(c + Vector2(r * 0.25, r * 0.25), c + Vector2(r * 0.9, r * 0.9), color, w * 1.6, true)
		&"demolition":
			draw_rect(Rect2(c + Vector2(-r * 0.9, -r * 0.1), Vector2(r * 0.9, r * 1.0)), color)
			draw_rect(Rect2(c + Vector2(r * 0.1, r * 0.3), Vector2(r * 0.8, r * 0.6)), color)
			# A block mid-fall, tipped.
			var pts := PackedVector2Array()
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				pts.append(c + Vector2(r * 0.35, -r * 0.6) + (corner * r * 0.3).rotated(0.5))
			draw_colored_polygon(pts, color)
		&"rescue":
			draw_rect(Rect2(c - Vector2(r * 0.28, r * 0.85), Vector2(r * 0.56, r * 1.7)), color)
			draw_rect(Rect2(c - Vector2(r * 0.85, r * 0.28), Vector2(r * 1.7, r * 0.56)), color)
		&"fleet":
			for p in [Vector2(0, -0.55), Vector2(-0.6, 0.45), Vector2(0.6, 0.45)]:
				_drone(c + p * r, r * 0.32, w * 0.7)
		&"relay":
			draw_circle(c + Vector2(-r * 0.6, 0), r * 0.3, color)
			draw_circle(c + Vector2(r * 0.6, 0), r * 0.3, color)
			draw_line(c + Vector2(-r * 0.25, -r * 0.45), c + Vector2(r * 0.25, -r * 0.45), color, w, true)
			draw_line(c + Vector2(r * 0.25, -r * 0.45), c + Vector2(r * 0.05, -r * 0.65), color, w, true)
			draw_line(c + Vector2(r * 0.25, r * 0.45), c + Vector2(-r * 0.25, r * 0.45), color, w, true)
			draw_line(c + Vector2(-r * 0.25, r * 0.45), c + Vector2(-r * 0.05, r * 0.65), color, w, true)
		&"boss":
			var ring := PackedVector2Array()
			for i in 7:
				ring.append(c + Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * r)
			draw_polyline(ring, color, w, true)
			for i in 3:
				draw_line(ring[i], ring[i + 3], color, w * 0.6, true)
		&"locked":
			draw_arc(c - Vector2(0, r * 0.15), r * 0.42, PI, TAU, 16, color, w * 1.2, true)
			draw_line(c + Vector2(-r * 0.42, -r * 0.15), c + Vector2(-r * 0.42, r * 0.05), color, w * 1.2)
			draw_line(c + Vector2(r * 0.42, -r * 0.15), c + Vector2(r * 0.42, r * 0.05), color, w * 1.2)
			draw_rect(Rect2(c + Vector2(-r * 0.7, 0), Vector2(r * 1.4, r * 0.95)), color)
		_:
			draw_arc(c, r * 0.8, 0.0, TAU, 32, color, w, true)

## A little quad seen from above: four rotor rings on an x.
func _drone(at: Vector2, size: float, w: float) -> void:
	for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		draw_line(at, at + d * size * 0.7, color, w, true)
		draw_arc(at + d * size * 0.7, size * 0.38, 0.0, TAU, 12, color, w, true)
