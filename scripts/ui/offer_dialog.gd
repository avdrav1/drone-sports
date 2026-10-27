class_name OfferDialog
extends ConfirmationDialog
# A team's offer: who, what they do, and which assists joining takes away.
# Accept joins; decline closes it for good. One offer per dialog; `show_next`
# walks the pending ones.

signal answered(team: Team, accepted: bool)

var team: Team

func _ready() -> void:
	ok_button_text = "Join"
	cancel_button_text = "Not now"
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
	team = offers[0]
	title = "Offer: %s" % team.name
	dialog_text = offer_text(team)
	popup_centered()
	return true

## Blurb, then what changes, e.g. "Joining means flying Act 2: GUARD off."
static func offer_text(t: Team) -> String:
	var gone := Career.preset().removed_by(t.preset).map(func(id): return FlightHud.ASSIST_NAMES[id])
	var change := "Joining means flying %s" % t.preset.label
	change += (": " + ", ".join(gone) + " off." if not gone.is_empty() else ".")
	return "%s\n\n%s\nDeclining is final: they won't ask again." % [t.blurb, change]

func _answer(accepted: bool) -> void:
	if accepted:
		Career.accept(team.id)
	else:
		Career.decline(team.id)
	answered.emit(team, accepted)
	show_next.call_deferred()
