class_name LaunchDialog
extends ConfirmationDialog
# Asked before launching a job with injured crew in the field: it names who is
# at risk, what another strike does, and the perks a death would take for
# good (Story 19.7). Confirm launches; cancel backs out.

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
