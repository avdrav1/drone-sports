class_name PilotSelect
extends Control
# Pick the pilot avatar (Story 7.2): one card per character tagged pilot, with
# portrait, role, and its edge (Story 19.1). A full-screen layer over the job board;
# it opens on its own before the first job and from the board's footer after.
# Back only shows once a pilot has been chosen, so a new game must pick.

signal chosen(id: StringName)

const ACCENT := Color(1.0, 0.76, 0.25)
const DIM := Color(1, 1, 1, 0.55)

## Character id -> its card.
var cards := {}
var _cards_box: HBoxContainer
var _back: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build()
	refresh()
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

## Each card names its edge and its stat steps, e.g. "+15 s flight time".
## Without an edge, the baseline drone.
static func tweak_text(c: Character) -> String:
	if c.edge == null:
		return "No edge\nthe baseline drone"
	var steps := PackedStringArray()
	for s in c.edge.stats:
		steps.append(s.effect_text())
	return "%s\n%s" % [c.edge.name, ", ".join(steps)]

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
	card.custom_minimum_size.x = 210
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ACCENT, 0.12) if current else Color(1, 1, 1, 0.04)
	style.border_color = ACCENT if current else Color(1, 1, 1, 0.2)
	style.set_border_width_all(2)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var face := CharacterPortrait.new()
	face.name = "Face"
	face.character = c
	face.custom_minimum_size = Vector2(96, 96)
	face.follow_mouse = true
	box.add_child(face)
	# Pointing at or focusing a pilot is picking them: they hop.
	card.mouse_entered.connect(face.hop)
	var name_label := Label.new()
	name_label.text = c.name.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	box.add_child(name_label)
	var role := Label.new()
	role.text = c.role + ("  ·  " + ("FLYING" if PlayerProfile.has_pilot() else "DEFAULT") if current else "")
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.add_theme_color_override("font_color", ACCENT if current else DIM)
	role.add_theme_font_size_override("font_size", 13)
	box.add_child(role)
	var tweak := Label.new()
	tweak.name = "Tweak"
	tweak.text = tweak_text(c)
	tweak.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tweak.add_theme_font_size_override("font_size", 14)
	box.add_child(tweak)
	var b := Button.new()
	b.name = "Choose"
	b.text = "Fly as %s" % c.name
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
	page.add_theme_constant_override("separation", 18)
	center.add_child(page)
	var title := Label.new()
	title.text = "CHOOSE YOUR PILOT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	page.add_child(title)
	var sub := Label.new()
	sub.text = "Same drone, same physics. Each pilot brings one small edge."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", DIM)
	page.add_child(sub)
	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 16)
	page.add_child(_cards_box)
	_back = Button.new()
	_back.name = "Back"
	_back.text = "Back"
	_back.size_flags_horizontal = SIZE_SHRINK_CENTER
	_back.pressed.connect(hide)
	page.add_child(_back)
