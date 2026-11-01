class_name Shedding
extends Resource
# Story 30.4: the Shiva-thread beat on a promotion offer that removes assists.
# It names each assist let go and what that unlocks (from AssistUnlocks), under
# Shiva's symbol and motif. An offer that removes none shows nothing of it.

## Whose thread it is (Shiva).
@export var deity: Deity
## Above the lines, one plain sentence.
@export var heading := ""
## One line per assist let go; {assist} is its name, {unlock} what it opens.
@export var line := ""
@export var unlocks: AssistUnlocks

## One line per removed assist, in the order given; empty when none is removed.
func lines(removed: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for id in removed:
		out.append(line.format({"assist": unlocks.names.get(id, String(id)), "unlock": unlocks.unlocks.get(id, "")}))
	return out
