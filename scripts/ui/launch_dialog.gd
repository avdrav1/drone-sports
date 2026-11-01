class_name LaunchDialog
extends ConfirmationDialog
# Asked before launching a job with injured crew in the field: it names who is
# at risk, what another strike does, and the perks a death would take for
# good (Story 19.7). Confirm launches; cancel backs out.
# Story 30.5: on a job whose data lists vows it also offers them, each with its
# thread's symbol. None is chosen by default and at most one can be; `chosen`
# is the one made, or null.

## Above the vows: a vow is the player's own promise and moves nothing else.
const VOW_INTRO := "You may make one vow for this job, or none. It is a promise of your own and changes nothing else."
## The symbol beside each vow.
const SYMBOL := 32.0

var chosen: Vow
## The vows on offer, and their check boxes, in the same order.
var vows: Array[Vow] = []
var boxes: Array[CheckBox] = []
## Holds the risk text, VOW_INTRO and the vow rows when vows are offered; with
## none the dialog's own text is used, as before.
var content: VBoxContainer
var _text: Label

func _ready() -> void:
	ok_button_text = "Launch anyway"
	cancel_button_text = "Back out"
	dialog_autowrap = true
	min_size = Vector2i(460, 0)

## `offered` empty asks about the crew alone, as before Story 30.5.
func ask(hurt: Array[StringName], lethal: bool, offered: Array[Vow] = []) -> void:
	title = "Crew at risk" if not hurt.is_empty() else "Launch"
	ok_button_text = "Launch anyway" if not hurt.is_empty() else "Launch"
	var risk := risk_text(hurt, lethal) if not hurt.is_empty() else ""
	chosen = null
	vows = offered.duplicate()
	_build_vows()
	if vows.is_empty():
		dialog_text = risk
	else:
		dialog_text = ""
		_text.text = (risk + "\n\n" if risk else "") + VOW_INTRO
	popup_centered()
	# Backing out is the default with crew at risk, so a held or doubled Enter
	# never launches unread. With vows alone, launching makes none.
	if hurt.is_empty():
		get_ok_button().grab_focus()
	else:
		get_cancel_button().grab_focus()

## Makes `vow` (one of those offered), or none with null.
func choose(vow: Vow) -> void:
	for i in vows.size():
		boxes[i].set_pressed_no_signal(vows[i] == vow)
	chosen = vow if vow in vows else null

func _build_vows() -> void:
	if content:
		remove_child(content)
		content.queue_free()
		content = null
	boxes.clear()
	if vows.is_empty():
		return
	content = VBoxContainer.new()
	content.name = "Vows"
	content.add_theme_constant_override("separation", 10)
	add_child(content)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 420
	content.add_child(_text)
	for vow in vows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var symbol := DeitySymbol.new()
		symbol.deity = vow.deity
		symbol.custom_minimum_size = Vector2.ONE * SYMBOL
		symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(symbol)
		var box := CheckBox.new()
		box.text = "%s: %s" % [vow.title(), vow.text]
		box.toggled.connect(_on_toggled.bind(vow))
		row.add_child(box)
		boxes.append(box)
		content.add_child(row)

## Check boxes, not a radio group, so making none stays plain; checking one
## clears the others.
func _on_toggled(on: bool, vow: Vow) -> void:
	choose(vow if on else null)

## E.g. "Sanjaya is injured and in the field. Another strike will kill them.
## You would lose Sanjaya's spotting (route guidance one step better on every job)."
static func risk_text(hurt: Array[StringName], lethal: bool) -> String:
	var names: Array[String] = []
	var perks: Array[String] = []
	for id in hurt:
		var c: Character = Roster.character(id)
		names.append(c.name if c else String(id))
		if c and c.perk:
			perks.append("%s's %s (%s)" % [c.name, c.perk.name, c.perk.effect_text().to_lower()])
	var who := _and(names)
	var verb := "is" if names.size() == 1 else "are"
	var cost := "This job is lethal: any strike kills." if lethal else "Another strike will kill them."
	var lose := "" if perks.is_empty() else "\nYou would lose %s." % _and(perks)
	return "%s %s injured and in the field. %s%s" % [who, verb, cost, lose]

## "a", "a and b", "a, b and c".
static func _and(items: Array[String]) -> String:
	return items[0] if items.size() == 1 else ", ".join(items.slice(0, -1)) + " and " + items[-1]
