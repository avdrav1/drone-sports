class_name PilotSelect
extends Control
# Pick the pilot avatar (Story 7.2): one card per character tagged pilot, with
# portrait, role, and its edge: what they are best at, four bars computed from
# the edge, and the edge in plain words (Story 19.3). A full-screen layer over
# the job board; it opens on its own before the first job and from the board's
# footer after.
# Back only shows once a pilot has been chosen, so a new game must pick.

signal chosen(id: StringName)

const ACCENT := Color(1.0, 0.76, 0.25)
const DIM := Color(1, 1, 1, 0.55)
const BAR_NAMES := {&"speed": "SPEED", &"cornering": "CORNERING", &"climb": "CLIMB", &"endurance": "ENDURANCE"}
const BAR_BACK := Color(1, 1, 1, 0.1)
## Card width bounds; between them, cards share the screen's width.
const CARD_MIN := 206.0
const CARD_MAX := 300.0
const CARD_GAP := 12

## Character id -> its card.
var cards := {}
var _cards_box: HBoxContainer
var _back: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build()
	refresh()
	resized.connect(_fit_cards)
	visibility_changed.connect(_trap_focus)
	_trap_focus()

## While open, the board behind cannot take keyboard or pad focus, so a new
## game cannot reach a job without picking. Dialogs are Windows and unaffected.
func _trap_focus() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for c in parent.get_children():
		if c != self and c is Control:
			c.focus_behavior_recursive = FOCUS_BEHAVIOR_DISABLED if visible else FOCUS_BEHAVIOR_INHERITED

## Esc or pad B is Back, once there is a pilot to go back with (Story 23.3).
func _unhandled_input(event: InputEvent) -> void:
	if visible and _back.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()

func open() -> void:
	refresh()
	show()
	var b := choose_button(PlayerProfile.pilot().id)
	if b:
		b.grab_focus.call_deferred()

## The ids on offer, in list order.
func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for c in PlayerProfile.pilots():
		out.append(c.id)
	return out

func choose_button(id: StringName) -> Button:
	return cards[id].find_child("Choose", true, false) if cards.has(id) else null

func choose(id: StringName) -> void:
	if PlayerProfile.choose_pilot(id):
		hide()
		chosen.emit(id)

## Cards share the width, less a margin, between CARD_MIN and CARD_MAX.
func _card_width() -> float:
	var n := maxi(PlayerProfile.pilots().size(), 1)
	return clampf((size.x - 48.0 - CARD_GAP * (n - 1)) / n, CARD_MIN, CARD_MAX)

## Wider cards get bigger small print, up to a quarter bigger.
func _text_size(base: int) -> int:
	return roundi(base * clampf(_card_width() / CARD_MIN, 1.0, 1.25))

## On a resize, rebuild the cards at the new width, keeping focus where it was.
func _fit_cards() -> void:
	if cards.is_empty() or is_equal_approx(cards.values()[0].custom_minimum_size.x, _card_width()):
		return
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var had := focused != null and is_ancestor_of(focused)
	refresh()
	if had and visible:
		choose_button(PlayerProfile.pilot().id).grab_focus()

## E.g. "Best at cornering".
static func best_at_text(c: Character) -> String:
	return "Best at " + c.edge.best_at if c.edge else "The baseline drone"

## The edge in plain words, one line per setting, the stat steps last. Units
## like m/s never wrap at their slash (word joiners either side).
static func edge_text(c: Character) -> String:
	return "\n".join(c.edge.lines()).replace("/", "\u2060/\u2060") if c.edge else ""

## One bar: `fill`, in [0, 1], drawn over a dim track.
class Bar extends Control:
	var fill := 0.0
	var color := Color.WHITE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), BAR_BACK)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * fill, size.y)), color)

func refresh() -> void:
	for c in _cards_box.get_children():
		c.free()
	cards.clear()
	var current := PlayerProfile.pilot()
	for c in PlayerProfile.pilots():
		var card := _card(c, c == current)
		cards[c.id] = card
		_cards_box.add_child(card)
	_back.visible = PlayerProfile.has_pilot()

func _card(c: Character, current: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = String(c.id)
	card.custom_minimum_size.x = _card_width()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ACCENT, 0.12) if current else Color(1, 1, 1, 0.04)
	style.border_color = ACCENT if current else Color(1, 1, 1, 0.2)
	style.set_border_width_all(2)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	# Portrait beside name and role, to leave the card's height to the edge.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var face := CharacterPortrait.new()
	face.name = "Face"
	face.character = c
	face.custom_minimum_size = Vector2(64, 64)
	face.follow_mouse = true
	head.add_child(face)
	# Pointing at or focusing a pilot is picking them: they hop.
	card.mouse_entered.connect(face.hop)
	var who := VBoxContainer.new()
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(who)
	var name_label := Label.new()
	name_label.text = c.name.to_upper()
	name_label.add_theme_font_size_override("font_size", 20)
	who.add_child(name_label)
	var role := Label.new()
	role.text = c.role
	role.add_theme_color_override("font_color", DIM)
	role.add_theme_font_size_override("font_size", _text_size(13))
	who.add_child(role)
	if current:
		var tag := Label.new()
		tag.text = "FLYING" if PlayerProfile.has_pilot() else "DEFAULT"
		tag.add_theme_color_override("font_color", ACCENT)
		tag.add_theme_font_size_override("font_size", _text_size(11))
		who.add_child(tag)
	var best := Label.new()
	best.name = "BestAt"
	best.text = best_at_text(c)
	best.autowrap_mode = TextServer.AUTOWRAP_WORD
	best.add_theme_color_override("font_color", ACCENT)
	best.add_theme_font_size_override("font_size", _text_size(14))
	box.add_child(best)
	var bars := GridContainer.new()
	bars.name = "Bars"
	bars.columns = 2
	bars.add_theme_constant_override("h_separation", 8)
	bars.add_theme_constant_override("v_separation", 4)
	box.add_child(bars)
	var fills := c.edge.bars() if c.edge else {}
	for id in PilotEdge.BARS:
		var label := Label.new()
		label.text = BAR_NAMES[id]
		label.add_theme_color_override("font_color", DIM)
		label.add_theme_font_size_override("font_size", _text_size(11))
		bars.add_child(label)
		var bar := Bar.new()
		bar.name = String(id)
		bar.fill = fills.get(id, PilotEdge.BAR_STOCK)
		bar.color = ACCENT if current else Color(1, 1, 1, 0.7)
		bar.custom_minimum_size.y = _text_size(8)
		bar.size_flags_horizontal = SIZE_EXPAND_FILL
		bar.size_flags_vertical = SIZE_SHRINK_CENTER
		bars.add_child(bar)
	var edge := Label.new()
	edge.name = "Edge"
	edge.text = edge_text(c)
	edge.autowrap_mode = TextServer.AUTOWRAP_WORD
	edge.add_theme_color_override("font_color", DIM)
	edge.add_theme_font_size_override("font_size", _text_size(11))
	edge.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(edge)
	var b := Button.new()
	b.name = "Choose"
	b.text = "Fly as %s" % c.name
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(choose.bind(c.id))
	b.focus_entered.connect(face.hop)
	box.add_child(b)
	return card

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.09)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	center.add_child(page)
	var title := Label.new()
	title.text = "CHOOSE YOUR PILOT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	page.add_child(title)
	var sub := Label.new()
	sub.text = "Same drone, same physics. Each pilot sets up the assists their own way."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", DIM)
	page.add_child(sub)
	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", CARD_GAP)
	page.add_child(_cards_box)
	_back = Button.new()
	_back.name = "Back"
	_back.text = "Back"
	_back.size_flags_horizontal = SIZE_SHRINK_CENTER
	_back.pressed.connect(hide)
	page.add_child(_back)
