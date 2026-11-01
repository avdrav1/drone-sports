class_name Vow
extends Resource
# An optional promise the player makes at launch (Story 30.5, docs/DEITIES.md
# "Vows"): their own conduct on one job, under one of the Four's threads. Never
# a prayer, offering or purchase; keeping one changes no pay, reputation,
# grade, unlock or physics, and breaking one has no penalty.

## The thread it belongs to.
@export var deity: Deity
## Which checker decides it: keeping (Vishnu), letting_go (Shiva), guiding
## (Krishna). 30.7 adds Brahma's.
@export var kind: StringName
## The promise in one plain line, e.g. "No one in the field is struck."
@export var text := ""
## Letting go (Story 30.6): the act presets in order, Act 2 to Act 4. The vow
## flies the job with the first one that takes an assist away from the stack it
## would fly with. Act 5's step is the fleet layer, which one drone cannot let
## go to, so it is not listed and Act 4 jobs are not offered the vow.
@export var steps: Array[AssistStack] = []

## "The vow of keeping", "The vow of letting go".
func title() -> String:
	return "The vow of %s" % String(kind).replace("_", " ")

## Whether the vow can be made on a job that would fly with `stack` (its
## assists after the career and the expert setting). Letting go needs an assist
## still on that the next act removes.
func offered_with(stack: AssistStack) -> bool:
	return kind != &"letting_go" or next_step(stack) != null

## Letting go: the next act's preset after `stack`, or null when no step takes
## anything more away.
func next_step(stack: AssistStack) -> AssistStack:
	for step in steps:
		if not stack.removed_by(step).is_empty():
			return step
	return null

## The assists to fly with under this vow: for letting go, `stack` with the
## next act's removals also off (never one turned on); for the others, `stack`.
func stack_for(stack: AssistStack) -> AssistStack:
	var step: AssistStack = next_step(stack) if kind == &"letting_go" else null
	return stack.intersect(step) if step else stack

## Whether the vow was kept on `runner`'s job, which has just completed. Each
## kind reads only what the runner already tracks.
func kept_on(runner: JobRunner) -> bool:
	match kind:
		&"keeping":
			return runner.strikes.is_empty()
		&"letting_go":
			# The runner flew it with stack_for() from launch; completing is keeping it.
			return true
		&"guiding":
			return runner.drop_ins == 0
	push_warning("No checker for the vow kind %s" % kind)
	return false
