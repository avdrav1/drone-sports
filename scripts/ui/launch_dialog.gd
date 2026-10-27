class_name LaunchDialog
extends ConfirmationDialog
# Asked before launching a job with injured crew in the field: it names who is
# at risk and what another strike does. Confirm launches; cancel backs out.

func _ready() -> void:
	title = "Crew at risk"
	ok_button_text = "Launch anyway"
	cancel_button_text = "Back out"
	dialog_autowrap = true
	min_size = Vector2i(460, 0)

func ask(hurt: Array[StringName], lethal: bool) -> void:
	dialog_text = risk_text(hurt, lethal)
	popup_centered()
	# Backing out is the default, so a held or doubled Enter never launches unread.
	get_cancel_button().grab_focus()

## E.g. "Marlo is injured and in the field. Another strike will kill them."
static func risk_text(hurt: Array[StringName], lethal: bool) -> String:
	var names: Array[String] = []
	for id in hurt:
		var c: Character = Roster.character(id)
		names.append(c.name if c else String(id))
	var who := names[0] if names.size() == 1 else ", ".join(names.slice(0, -1)) + " and " + names[-1]
	var verb := "is" if names.size() == 1 else "are"
	var cost := "This job is lethal: any strike kills." if lethal else "Another strike will kill them."
	return "%s %s injured and in the field. %s" % [who, verb, cost]
