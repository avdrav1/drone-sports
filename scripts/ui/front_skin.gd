class_name FrontSkin
extends Resource
# How the front end looks (Story 17.6): colors, fonts, panel style, and sounds,
# worn by the title, the board, its menu, and the CREW page. Act 1 is a home
# arcade cabinet (chunky type, scanlines, a coin chime on Start, the bezel's
# amber); from Act 2 it is the team's ops console (the flight HUD's thin lines
# in the team's colors). current() picks one; theme() turns it into a Theme.

const CABINET := "res://data/ui/skins/cabinet.tres"
const OPS := "res://data/ui/skins/ops.tres"

@export var id: StringName
@export var background := Color(0.07, 0.07, 0.09)
@export var panel := Color(0.08, 0.09, 0.12, 0.92)
@export var border := Color(0.35, 0.8, 0.95)
@export var border_width := 2
@export var corner_radius := 6
@export var button := Color(0.16, 0.2, 0.26)
@export var text := Color.WHITE
@export var dim := Color(1, 1, 1, 0.55)
@export var accent := Color(1.0, 0.76, 0.25)
## Section headings and the title's best score.
@export var heading := Color(0.35, 0.8, 0.95)
## Body text; null keeps the engine's font.
@export var font: Font
## Big type: titles and menu items. Null uses `font`.
@export var display_font: Font
## Scanlines over the whole screen, like a CRT.
@export var scanlines := false
## Played on PRESS START; empty plays the usual confirm.
@export var start_sound: StringName
## Ops: border, accent and heading come from the current team's colors.
@export var team_colors := false

## The skin for where the career is: the cabinet in Act 1, the ops console
## in the team's colors from Act 2.
static func current() -> FrontSkin:
	return for_act(Career.act(), Career.team())

static func for_act(act: int, team: Team = null) -> FrontSkin:
	var s: FrontSkin = load(CABINET if act <= 1 else OPS)
	if s.team_colors and team and team.colors.size() >= 2:
		s = s.duplicate()
		s.accent = team.colors[0]
		s.border = Color(team.colors[0], 0.8)
		s.heading = team.colors[1]
	return s

func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	if font:
		t.default_font = font
	var big := display_font if display_font else font
	var p := _box(panel, border, border_width)
	p.set_content_margin(SIDE_LEFT, 24)
	p.set_content_margin(SIDE_RIGHT, 24)
	p.set_content_margin(SIDE_TOP, 20)
	p.set_content_margin(SIDE_BOTTOM, 20)
	t.set_stylebox("panel", "PanelContainer", p)
	var normal := _box(button, border, border_width)
	if border_width > 1:
		# The cabinet's buttons sit on a lit bottom edge, like the old board.
		normal.set_border_width_all(0)
		normal.border_width_bottom = border_width
	normal.set_content_margin(SIDE_LEFT, 18)
	normal.set_content_margin(SIDE_RIGHT, 18)
	normal.set_content_margin(SIDE_TOP, 8)
	normal.set_content_margin(SIDE_BOTTOM, 8)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = button.lightened(0.12)
	var off: StyleBoxFlat = normal.duplicate()
	off.bg_color.a *= 0.35
	off.border_color.a *= 0.25
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = accent
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(corner_radius)
	focus.set_expand_margin_all(2)
	for kind in ["Button", "OptionButton"]:
		t.set_stylebox("normal", kind, normal)
		t.set_stylebox("hover", kind, hover)
		t.set_stylebox("pressed", kind, hover)
		t.set_stylebox("disabled", kind, off)
		t.set_stylebox("focus", kind, focus)
		t.set_color("font_color", kind, text)
		t.set_color("font_hover_color", kind, text)
		t.set_color("font_focus_color", kind, accent)
		t.set_color("font_pressed_color", kind, accent)
		t.set_color("font_disabled_color", kind, dim)
		if big:
			t.set_font("font", kind, big)
	t.set_color("font_color", "Label", text)
	# Labels that want the big type set theme_type_variation = &"Display".
	t.set_type_variation(&"Display", &"Label")
	if big:
		t.set_font("font", &"Display", big)
	return t

func _box(fill: Color, edge: Color, width: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = edge
	b.set_border_width_all(width)
	b.set_corner_radius_all(corner_radius)
	return b
