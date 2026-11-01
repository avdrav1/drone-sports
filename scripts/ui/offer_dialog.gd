class_name OfferDialog
extends ConfirmationDialog
# A team's offer: who, what they do, and which assists joining takes away.
# Accept joins, and plays the team's joining scene if it has one; decline
# closes it for good. One offer per dialog; `show_next`
# walks the pending ones.
# Story 30.4: an offer that removes assists also shows the shedding (Shiva's
# symbol, a heading and one line per assist let go naming what it unlocks, all
# from data/story/shedding.tres) and sounds Shiva's motif alone until answered.
# An offer that removes none shows only the offer, as before.

signal answered(team: Team, accepted: bool)

var team: Team

const SHEDDING := "res://data/story/shedding.tres"
## Shiva's symbol beside the shedding lines.
const SYMBOL := 64.0
## How wide the offer and the shedding are, so six lines still fit at 720 px.
const WIDTH := 640.0
## The heading, quieter than the lines under it.
const HEADING := Color(0.78, 0.8, 0.9)

## The shedding lines on show, one per assist the offer removes (tests read them).
var shed_lines: Array[String] = []
## Holds the offer text and the shedding while it shows; null otherwise, and
## the dialog's own text is used.
var content: VBoxContainer
# The music before the motif, put back on answering.
var _music_before: Score
var _mix_before: StringName
var _motif_on := false

func _ready() -> void:
	ok_button_text = "Join"
	cancel_button_text = "Decline"
	dialog_autowrap = true
	min_size = Vector2i(480, 0)
	process_mode = Node.PROCESS_MODE_ALWAYS
	confirmed.connect(func(): _answer(true))
	canceled.connect(func(): _answer(false))

## Pops up the first pending offer, if any. Returns whether it did.
func show_next() -> bool:
	var offers := Career.pending_offers()
	if offers.is_empty():
		return false
	show_offer(offers[0])
	return true

## Pops up `t`'s offer, with the shedding when joining removes assists.
func show_offer(t: Team) -> void:
	team = t
	title = "Offer: %s" % team.name
	dialog_text = offer_text(team)
	_build_shedding(Career.preset().removed_by(team.preset))
	popup_centered()

## Blurb, then what changes, e.g. "Joining means flying Act 2: GUARD off."
static func offer_text(t: Team) -> String:
	var gone := Career.preset().removed_by(t.preset).map(func(id): return FlightHud.ASSIST_NAMES[id])
	var change := "Joining means flying %s" % t.preset.label
	change += (": " + ", ".join(gone) + " off." if not gone.is_empty() else ".")
	return "%s\n\n%s\nDeclining is final: they won't ask again." % [t.blurb, change]

## The shedding below the offer for `removed`, or nothing when it is empty.
## The dialog's own label keeps the offer text but is hidden while `content`
## shows it.
func _build_shedding(removed: Array[StringName]) -> void:
	if content:
		remove_child(content)
		content.queue_free()
		content = null
	var shed: Shedding = load(SHEDDING)
	shed_lines = shed.lines(removed)
	get_label().visible = shed_lines.is_empty()
	if shed_lines.is_empty():
		_hush()
		return
	content = VBoxContainer.new()
	content.name = "Shedding"
	content.add_theme_constant_override("separation", 12)
	add_child(content)
	var offer := Label.new()
	offer.text = dialog_text
	offer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	offer.custom_minimum_size.x = WIDTH
	content.add_child(offer)
	content.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var symbol := DeitySymbol.new()
	symbol.deity = shed.deity
	symbol.custom_minimum_size = Vector2.ONE * SYMBOL
	symbol.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(symbol)
	var words := VBoxContainer.new()
	words.name = "Lines"
	words.add_theme_constant_override("separation", 6)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for text in [shed.heading] + shed_lines:
		var l := Label.new()
		l.text = text
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = WIDTH - SYMBOL - 14
		words.add_child(l)
	words.get_child(0).modulate = HEADING
	row.add_child(words)
	content.add_child(row)
	_sound(shed.deity)

## Shiva's motif alone of the Four's score, remembering what played before.
func _sound(d: Deity) -> void:
	var four: Score = load(Deity.MOTIF_SCORE)
	if not _motif_on:
		_music_before = Music.score
		_mix_before = MusicDirector.mix
		_motif_on = true
	MusicDirector.play_score(four, &"live")
	CutscenePlayer.sound_motif(d)

## Puts back the music from before the motif, if it sounded.
func _hush() -> void:
	if not _motif_on:
		return
	_motif_on = false
	MusicDirector.play_score(_music_before, _mix_before)

func _answer(accepted: bool) -> void:
	_hush()
	if accepted:
		Career.accept(team.id)
	else:
		Career.decline(team.id)
	answered.emit(team, accepted)
	# Joining a team with a scene plays it; the board asks any other offers after.
	if accepted and team.joining_scene != "" and is_inside_tree():
		get_tree().change_scene_to_file.call_deferred(team.joining_scene)
		return
	show_next.call_deferred()
