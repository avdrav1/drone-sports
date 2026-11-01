class_name LaunchDialog
extends ConfirmationDialog
# Asked before launching a job with injured crew in the field: it names who is
# at risk, what another strike does, and the perks a death would take for
# good (Story 19.7). Confirm launches; cancel backs out.
# Story 30.5: on a job whose data lists vows it also offers them, each with its
# thread's symbol. None is chosen by default and at most one can be; `chosen`
# is the one made, or null.
# Story 30.10: on the final job (Counsel.applies_to) the dialog becomes Krishna's
# counsel: his symbol, Sanjaya relaying the lines (no speaker once Sanjaya is
# dead) and his motif alone, above any crew risk and vows. Launching stays the
# player's choice; "Not yet" backs out as before.

## Above the vows: a vow is the player's own promise and moves nothing else.
const VOW_INTRO := "You may make one vow for this job, or none. It is a promise of your own and changes nothing else."
## The symbol beside each vow.
const SYMBOL := 32.0
## Krishna's symbol beside the counsel, and how wide the counsel is.
const COUNSEL_SYMBOL := 64.0
const COUNSEL_WIDTH := 560.0
## The counsel's heading, quieter than the lines under it.
const HEADING := Color(0.78, 0.8, 0.9)

var chosen: Vow
## The vows on offer, and their check boxes, in the same order.
var vows: Array[Vow] = []
var boxes: Array[CheckBox] = []
## Holds the risk text, VOW_INTRO and the vow rows when vows are offered; with
## none the dialog's own text is used, as before.
var content: VBoxContainer
## The counsel on show (Story 30.10), its heading and lines; null and empty
## when the job has none.
var counsel: Counsel
var counsel_heading := ""
var counsel_lines: Array[String] = []
var _text: Label
# The music before Krishna's motif, put back by hush().
var _music_before: Score
var _mix_before: StringName
var _motif_on := false

func _ready() -> void:
	ok_button_text = "Launch anyway"
	cancel_button_text = "Back out"
	dialog_autowrap = true
	min_size = Vector2i(460, 0)

## `offered` empty asks about the crew alone, as before Story 30.5. With
## `with_counsel` (and `job`, the final job) the counsel heads the dialog.
func ask(hurt: Array[StringName], lethal: bool, offered: Array[Vow] = [], with_counsel: Counsel = null, job: Job = null) -> void:
	title = "Crew at risk" if not hurt.is_empty() else "Launch"
	ok_button_text = "Launch anyway" if not hurt.is_empty() else "Launch"
	cancel_button_text = "Back out"
	var risk := risk_text(hurt, lethal) if not hurt.is_empty() else ""
	chosen = null
	vows = offered.duplicate()
	counsel = with_counsel
	counsel_heading = counsel.title() if counsel else ""
	counsel_lines = counsel.lines(job) if counsel else ([] as Array[String])
	_build_vows()
	if vows.is_empty() and counsel == null:
		dialog_text = risk
	else:
		dialog_text = ""
		_text.text = (risk + "\n\n" if risk else "") + (VOW_INTRO if not vows.is_empty() else "")
		_text.text = _text.text.strip_edges()
		_text.visible = _text.text != ""
		if counsel:
			content.get_node("Rule").visible = _text.visible
	if counsel:
		title = counsel.dialog_title
		ok_button_text = counsel.launch_text
		cancel_button_text = counsel.decline_text
		_sound(counsel.deity)
	else:
		hush()
	popup_centered()
	# Backing out is the default with crew at risk or the counsel, so a held or
	# doubled Enter never launches unread. With vows alone, launching makes none.
	if hurt.is_empty() and counsel == null:
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
	if vows.is_empty() and counsel == null:
		return
	content = VBoxContainer.new()
	content.name = "Vows"
	content.add_theme_constant_override("separation", 10)
	add_child(content)
	if counsel:
		_build_counsel()
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = COUNSEL_WIDTH if counsel else 420.0
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

## Krishna's symbol beside the heading and lines, then a rule above the rest.
func _build_counsel() -> void:
	var row := HBoxContainer.new()
	row.name = "Counsel"
	row.add_theme_constant_override("separation", 14)
	var symbol := DeitySymbol.new()
	symbol.deity = counsel.deity
	symbol.custom_minimum_size = Vector2.ONE * COUNSEL_SYMBOL
	symbol.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(symbol)
	var words := VBoxContainer.new()
	words.name = "Lines"
	words.add_theme_constant_override("separation", 8)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for text in [counsel_heading] + counsel_lines:
		var l := Label.new()
		l.text = text
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = COUNSEL_WIDTH - COUNSEL_SYMBOL - 14
		words.add_child(l)
	words.get_child(0).modulate = HEADING
	row.add_child(words)
	content.add_child(row)
	var rule := HSeparator.new()
	rule.name = "Rule"
	content.add_child(rule)

## Krishna's motif alone of the Four's score, remembering what played before.
func _sound(d: Deity) -> void:
	if not _motif_on:
		_music_before = Music.score
		_mix_before = MusicDirector.mix
		_motif_on = true
	MusicDirector.play_score(load(Deity.MOTIF_SCORE), &"live")
	CutscenePlayer.sound_motif(d)

## Puts back the music from before the motif, if it sounded. The runner calls
## it before acting on the answer, so the launch's own mix wins.
func hush() -> void:
	if not _motif_on:
		return
	_motif_on = false
	MusicDirector.play_score(_music_before, _mix_before)

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
