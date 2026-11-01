class_name Vow
extends Resource
# An optional promise the player makes at launch (Story 30.5, docs/DEITIES.md
# "Vows"): their own conduct on one job, under one of the Four's threads. Never
# a prayer, offering or purchase; keeping one changes no pay, reputation,
# grade, unlock or physics, and breaking one has no penalty.

## The thread it belongs to.
@export var deity: Deity
## Which checker decides it: keeping (Vishnu). 30.6 and 30.7 add the others.
@export var kind: StringName
## The promise in one plain line, e.g. "No one in the field is struck."
@export var text := ""

## "The vow of keeping".
func title() -> String:
	return "The vow of %s" % String(kind)

## Whether the vow was kept on `runner`'s job, which has just completed. Each
## kind reads only what the runner already tracks.
func kept_on(runner: JobRunner) -> bool:
	match kind:
		&"keeping":
			return runner.strikes.is_empty()
	push_warning("No checker for the vow kind %s" % kind)
	return false
