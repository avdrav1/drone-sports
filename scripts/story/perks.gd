class_name Perks
extends RefCounted
# The crew's perks in effect (Story 19.4, the table in BACKLOG.md Epic 19).
# Pay, the Garage, the job runner, and the Roster ask here for a kind, so none
# of them names a character (CLAUDE.md rule 6), as with Consequences.

## Fit to work: alive and not on the bench.
static func fit(id: StringName) -> bool:
	return Roster.status(id) == Roster.Status.ACTIVE

## The fit crew carrying a perk of `kind`.
static func owners(kind: StringName) -> Array[Character]:
	var out: Array[Character] = []
	for id in Roster.ids():
		var c: Character = Roster.character(id)
		if c.perk and c.perk.kind == kind and fit(id):
			out.append(c)
	return out

## The summed amount of every fit crew member's perk of `kind`; 0 with none.
static func amount(kind: StringName) -> float:
	var sum := 0.0
	for c in owners(kind):
		sum += c.perk.amount
	return sum
