class_name CharacterPortrait
extends Control
# A character's face. Uses the portrait texture when there is one; otherwise a
# placeholder in the cast's shape language: a round body, big eyes, two or three
# colors, and one silhouette feature per character. Readable at 64 px.
# Greyed out when the character is dead.

@export var character: Character
## Drawn greyed, e.g. for a dead character on the roster.
@export var greyed := false

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(64, 64)

func _draw() -> void:
	if character == null:
		return
	var s := minf(size.x, size.y)
	var c := size * 0.5
	if character.portrait:
		draw_texture_rect(character.portrait, Rect2(c - Vector2.ONE * s * 0.5, Vector2.ONE * s), false, _tone(Color.WHITE))
		return
	var body := _tone(character.colors[0])
	var accent := _tone(character.colors[1])
	var detail := _tone(character.colors[2]) if character.colors.size() > 2 else accent
	var r := s * 0.36
	var center := c + Vector2(0, s * 0.06)
	_draw_feature(center, r, body, accent, detail)
	draw_circle(center, r, body)
	draw_circle(center + Vector2(0, r * 0.45), r * 0.5, accent)
	if character.shape == &"square":
		# Goggles strap across the eyes.
		draw_rect(Rect2(center - Vector2(r * 1.08, r * 0.38), Vector2(r * 2.16, r * 0.46)), detail)
	elif character.shape == &"visor":
		# Racing visor pushed up on the forehead.
		draw_rect(Rect2(center - Vector2(r * 0.95, r * 0.82), Vector2(r * 1.9, r * 0.32)), detail)
	for side in [-1.0, 1.0]:
		var eye := center + Vector2(side * r * 0.4, -r * 0.15)
		draw_circle(eye, r * 0.26, Color.WHITE)
		draw_circle(eye + Vector2(0, r * 0.05), r * 0.13, _tone(Color(0.1, 0.08, 0.12)))

func _draw_feature(center: Vector2, r: float, body: Color, accent: Color, detail: Color) -> void:
	match character.shape:
		&"antenna":
			draw_line(center - Vector2(0, r * 0.9), center - Vector2(0, r * 1.45), detail, maxf(r * 0.08, 1.5))
			draw_circle(center - Vector2(0, r * 1.5), r * 0.16, accent)
		&"hardhat":
			draw_rect(Rect2(center - Vector2(r * 1.1, r * 0.75), Vector2(r * 2.2, r * 0.2)), detail)
			draw_circle(center - Vector2(0, r * 0.7), r * 0.75, detail)
		&"ears":
			for side in [-1.0, 1.0]:
				draw_circle(center + Vector2(side * r * 0.75, -r * 0.8), r * 0.38, body)
				draw_circle(center + Vector2(side * r * 0.75, -r * 0.8), r * 0.2, accent)
		&"tall":
			draw_rect(Rect2(center - Vector2(r * 0.55, r * 1.55), Vector2(r * 1.1, r * 0.7)), detail)
		&"tuft":
			for x in [-0.3, 0.0, 0.3]:
				draw_circle(center + Vector2(r * x, -r * (1.0 - absf(x) * 0.4)), r * 0.24, detail)
		&"fin":
			draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 0.45, -r * 0.7), center + Vector2(r * 0.1, -r * 1.5), center + Vector2(r * 0.5, -r * 0.7)]), detail)

func _tone(col: Color) -> Color:
	if not greyed:
		return col
	var v := col.get_luminance() * 0.7 + 0.15
	return Color(v, v, v, col.a)
