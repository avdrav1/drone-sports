class_name DeitySymbol
extends Control
# One of the Four shown by their symbols (Story 30.2, docs/DEITIES.md "How they
# appear"): a disc in their colour, a ring, and their symbols drawn on it from
# simple shapes, original to this game: Brahma's lotus over the four Vedas,
# Vishnu's conch and chakra, Shiva's trident with the damaru tied to it under
# the crescent moon, Krishna's flute across a peacock feather. Drawn in code
# so it stays sharp at 32, 64 or 128 px; below DeitySymbolArt.detail_below only
# one symbol per god is drawn, larger, without its fine details. Never a face
# or a figure.

const ART := "res://data/deities/symbol_art.tres"

@export var deity: Deity:
	set(v):
		deity = v
		queue_redraw()

## The symbols the last draw drew, in order, and polygons it had to skip
## (tests read both).
var drawn: Array[StringName] = []
var skipped := 0

var _art: DeitySymbolArt
# The symbol being drawn: its transform from the unit disc, ink colours, width.
var _xf := Transform2D.IDENTITY
var _field := Color.BLACK
var _ink := Color.WHITE
var _second := Color.WHITE
var _w := 1.0
var _detail := true

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(64, 64)

func art() -> DeitySymbolArt:
	if _art == null:
		_art = load(ART)
	return _art

## The ink that reads on `field`: Shiva's ash white where the accent is light,
## else ivory on a dark field and the field's own colour, darkened, on a light one.
func ink_for(d: Deity) -> Color:
	if d.accent != d.colour and d.accent.get_luminance() > 0.5:
		return d.accent
	return art().ivory if d.colour.get_luminance() < 0.5 else d.colour.darkened(0.72)

func _draw() -> void:
	drawn.clear()
	skipped = 0
	if deity == null:
		return
	var a := art()
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var r := s * 0.48
	_field = deity.colour
	_ink = ink_for(deity)
	_second = deity.accent if deity.accent != deity.colour and deity.accent != _ink else _ink
	_detail = s >= a.detail_below
	_w = maxf(a.min_line, a.line * r)
	draw_circle(c, r, _field, true, -1.0, true)
	draw_arc(c, r * (1.0 - a.ring * 0.5), 0.0, TAU, 64, _ink, maxf(a.min_line, a.ring * r), true)
	var places: Dictionary = a.placements if _detail else a.small
	for sym in a.order:
		if not sym in deity.symbols or not places.has(sym):
			continue
		var p: Vector4 = places[sym]
		_xf = Transform2D(deg_to_rad(p.w), Vector2(p.z * r, p.z * r), 0.0, c + Vector2(p.x, p.y) * r)
		match sym:
			&"lotus": _lotus()
			&"vedas": _vedas()
			&"conch": _conch()
			&"chakra": _chakra()
			&"trident": _trident()
			&"crescent": _crescent()
			&"damaru": _damaru()
			&"flute": _flute()
			&"peacock_feather": _feather()
			_: continue
		drawn.append(sym)

# --- helpers: every point is in the symbol's own unit space (about -1..1) ---

func _pts(local: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in local:
		out.append(_xf * (v as Vector2))
	return out

## A filled shape with a soft edge. A polygon that cannot be filled is skipped
## and counted, never drawn broken.
func _fill(local: Array, col: Color) -> void:
	var pts := _pts(local)
	if Geometry2D.triangulate_polygon(pts).is_empty():
		skipped += 1
		return
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, col, 1.0, true)

## A filled shape with an outline in the field's colour, which parts it from
## what is drawn behind.
func _cut(local: Array, col: Color, outline := 0.8) -> void:
	_fill(local, col)
	var pts := _pts(local)
	pts.append(pts[0])
	draw_polyline(pts, _field, maxf(1.0, _w * outline), true)

func _line(local: Array, col: Color, width := 1.0) -> void:
	draw_polyline(_pts(local), col, maxf(1.0, _w * width), true)

func _dot(at: Vector2, radius: float, col: Color) -> void:
	draw_circle(_xf * at, maxf(0.75, radius * _xf.get_scale().x), col, true, -1.0, true)

## A closed loop through `ctrl`, rounded (Catmull-Rom, `steps` per span).
func _smooth(ctrl: Array, steps := 6) -> Array:
	var out := []
	var n := ctrl.size()
	for i in n:
		var p0: Vector2 = ctrl[(i - 1 + n) % n]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[(i + 1) % n]
		var p3: Vector2 = ctrl[(i + 2) % n]
		for k in steps:
			out.append(p1.cubic_interpolate(p2, p0, p3, float(k) / steps))
	return out

## An ellipse round `at`, `rx` by `ry`.
func _oval(at: Vector2, rx: float, ry: float, n := 24) -> Array:
	var out := []
	for i in n:
		var t := TAU * i / n
		out.append(at + Vector2(cos(t) * rx, sin(t) * ry))
	return out

## A pointed petal or leaf from `base` along `axis` (unit), `length` long and
## `width` at its widest, a little past a third of the way out.
func _leaf(base: Vector2, axis: Vector2, length: float, width: float, n := 10) -> Array:
	var side := Vector2(-axis.y, axis.x)
	var right := []
	var left := []
	for i in n + 1:
		var t := float(i) / n
		var half := width * 0.5 * sin(PI * pow(t, 0.75))
		var at := base + axis * length * t
		right.append(at + side * half)
		left.push_front(at - side * half)
	left.pop_back()
	left.pop_front()
	return right + left

# --- the symbols ---

## A lotus seen from the side: petals fanned from one base, the middle one
## tallest, over a shallow cup.
func _lotus() -> void:
	var base := Vector2(0, 0.55)
	var pairs := int((art().petals - 1) / 2.0)
	for k in range(pairs, 0, -1):
		var f := float(k) / maxf(1.0, pairs)
		var length := 1.25 - 0.42 * f
		for sgn in [-1.0, 1.0]:
			var axis := Vector2.UP.rotated(sgn * deg_to_rad(64.0 * f))
			_cut(_leaf(base, axis, length, 0.56 - 0.1 * f), _ink)
	_cut(_leaf(base, Vector2.UP, 1.25, 0.6), _ink)
	if _detail:
		_line([base + Vector2(0, -0.2), base + Vector2(0, -0.95)], _field, 0.6)
	var cup := []
	for i in 13:
		var x := -0.8 + 1.6 * i / 12.0
		cup.append(Vector2(x, 0.5 + 0.22 * (1.0 - pow(x / 0.8, 2))))
	for i in range(12, -1, -1):
		cup.append(Vector2(-0.8 + 1.6 * i / 12.0, 0.5 - 0.02))
	cup.pop_back()
	_cut(cup, _ink)

## The four Vedas as palm-leaf books, stacked, each with its two cord holes.
func _vedas() -> void:
	var n := art().vedas
	var h := 1.56 / (n * 1.4 - 0.4)
	for i in n:
		var y := -0.78 + i * h * 1.4 + h * 0.5
		var leaf := []
		for k in 9:
			var t := PI * 0.5 + PI * k / 8.0
			leaf.append(Vector2(-0.9 + h * 0.5 + cos(t) * h * 0.5, y + sin(t) * h * 0.5))
		for k in 9:
			var t := -PI * 0.5 + PI * k / 8.0
			leaf.append(Vector2(0.9 - h * 0.5 + cos(t) * h * 0.5, y + sin(t) * h * 0.5))
		_fill(leaf, _ink)
		if _detail:
			_dot(Vector2(-0.42, y), h * 0.22, _field)
			_dot(Vector2(0.42, y), h * 0.22, _field)

## A conch: its spire at the top, the body swelling to a flared lip on the
## right, the canal tapering below, with its whorls and opening.
func _conch() -> void:
	var outline := _smooth([Vector2(0, -0.97), Vector2(0.17, -0.74), Vector2(0.34, -0.56), Vector2(0.56, -0.34),
		Vector2(0.64, -0.04), Vector2(0.58, 0.26), Vector2(0.4, 0.52), Vector2(0.16, 0.76), Vector2(0.05, 0.97),
		Vector2(-0.08, 0.8), Vector2(-0.26, 0.6), Vector2(-0.44, 0.3), Vector2(-0.5, -0.05), Vector2(-0.44, -0.36),
		Vector2(-0.28, -0.56), Vector2(-0.15, -0.74)])
	_cut(outline, _ink)
	_line([Vector2(-0.24, -0.58), Vector2(0.02, -0.5), Vector2(0.32, -0.58)], _field, 0.8)
	if _detail:
		_line([Vector2(-0.12, -0.76), Vector2(0.02, -0.71), Vector2(0.15, -0.76)], _field, 0.7)
	_line([Vector2(0.26, -0.34), Vector2(0.36, -0.06), Vector2(0.32, 0.22), Vector2(0.14, 0.56)], _field, 1.2)

## A wheel: rim, hub and spokes, with points round the rim.
func _chakra() -> void:
	var a := art()
	for i in a.teeth:
		var t := TAU * i / a.teeth
		var u := Vector2.from_angle(t)
		var v := Vector2.from_angle(t + PI / a.teeth)
		var tip := Vector2.from_angle(t + PI * 0.5 / a.teeth) * 1.0
		_fill([u * 0.8, tip, v * 0.8], _ink)
	draw_arc(_xf.origin, 0.74 * _xf.get_scale().x, 0.0, TAU, 48, _ink, maxf(1.0, 0.16 * _xf.get_scale().x), true)
	for i in a.spokes:
		var u := Vector2.from_angle(TAU * i / a.spokes + PI / a.spokes)
		_line([u * 0.2, u * 0.68], _ink, 0.9)
	_dot(Vector2.ZERO, 0.24, _ink)
	if _detail:
		_dot(Vector2.ZERO, 0.09, _field)

## A trident: the shaft, the middle blade, and two side prongs curving up from
## the crossing.
func _trident() -> void:
	_fill([Vector2(-0.05, -0.3), Vector2(0.05, -0.3), Vector2(0.05, 1.0), Vector2(-0.05, 1.0)], _ink)
	var arm := []
	for i in 13:
		var x := -0.5 + i / 12.0
		arm.append(Vector2(x, -0.28 - 0.5 * pow(x / 0.5, 2)))
	_line(arm, _ink, 2.0)
	_fill(_leaf(Vector2(0, -0.2), Vector2.UP, 0.88, 0.24), _ink)
	for sgn in [-1.0, 1.0]:
		var top := Vector2(sgn * 0.5, -0.78)
		_fill([top + Vector2(-0.08, 0.02), top + Vector2(sgn * 0.06, -0.22), top + Vector2(0.08, 0.02)], _ink)
	_fill(_oval(Vector2(0, -0.26), 0.12, 0.07, 16), _ink)

## The crescent moon, horns up and to the right.
func _crescent() -> void:
	var tip1 := Vector2.from_angle(deg_to_rad(-70.0))
	var tip2 := Vector2.from_angle(deg_to_rad(20.0))
	var pts := []
	var n := 24
	for i in n + 1:
		pts.append(Vector2.from_angle(deg_to_rad(20.0 + 270.0 * i / n)))
	var mid := Vector2.from_angle(deg_to_rad(155.0)) * 0.55
	var ctrl := mid * 2.0 - (tip1 + tip2) * 0.5
	for i in range(1, n):
		var t := float(i) / n
		pts.append(tip1.lerp(ctrl, t).lerp(ctrl.lerp(tip2, t), t))
	_fill(pts, _second)

## A damaru: two drum heads joined at a narrow waist.
func _damaru() -> void:
	_cut([Vector2(-0.48, -0.8), Vector2(0.48, -0.8), Vector2(0.07, 0), Vector2(0.48, 0.8),
		Vector2(-0.48, 0.8), Vector2(-0.07, 0)], _ink, 0.7)
	_line([Vector2(-0.5, -0.66), Vector2(0.5, -0.66)], _field, 0.6)
	_line([Vector2(-0.5, 0.66), Vector2(0.5, 0.66)], _field, 0.6)

## A bamboo flute: a long rounded rod, its mouth hole and finger holes.
func _flute() -> void:
	var rod := []
	for k in 9:
		var t := PI * 0.5 + PI * k / 8.0
		rod.append(Vector2(-0.94 + cos(t) * 0.07, sin(t) * 0.07))
	for k in 9:
		var t := -PI * 0.5 + PI * k / 8.0
		rod.append(Vector2(0.94 + cos(t) * 0.07, sin(t) * 0.07))
	_cut(rod, _ink, 0.7)
	_dot(Vector2(-0.58, 0), 0.04, _field)
	if _detail:
		var n := art().flute_holes
		for i in n:
			_dot(Vector2(0.05 + 0.62 * i / maxf(1.0, n - 1), 0), 0.035, _field)
		for x in [-0.82, -0.74]:
			_line([Vector2(x, -0.07), Vector2(x, 0.07)], _field, 0.5)

## A peacock feather: a curved quill, its barbs, and the eye at its tip
## (green, then ivory, then the deep blue of the field at its heart).
func _feather() -> void:
	var quill := []
	for i in 11:
		var t := i / 10.0
		quill.append(Vector2(0.12 * sin(t * PI * 0.8), 1.0 - 1.4 * t))
	if _detail:
		for i in range(1, 10):
			var q: Vector2 = quill[i]
			var reach := 0.12 + 0.1 * i / 10.0
			_line([q, q + Vector2(-reach, -reach * 0.6)], _second, 0.45)
			_line([q, q + Vector2(reach, -reach * 0.6)], _second, 0.45)
	_line(quill, _second, 0.8)
	var eye := Vector2(0.06, -0.62)
	var outer := []
	for i in 24:
		var t := TAU * i / 24.0
		var k := 1.0 + 0.35 * maxf(0.0, sin(t))
		outer.append(eye + Vector2(cos(t) * 0.34, sin(t) * 0.38 * k))
	_fill(outer, _second)
	_fill(_oval(eye + Vector2(0, 0.04), 0.22, 0.26), _ink)
	_fill(_oval(eye + Vector2(0, 0.06), 0.12, 0.15), _field)
