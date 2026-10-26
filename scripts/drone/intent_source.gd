class_name IntentSource
extends Node
# Something that decides what a drone should do: the pilot's sticks, an AI, a test script.
# Base returns a neutral intent.

func read_intent() -> Intent:
	return Intent.new()

## Override to forget held state (ramps, latched throttle) when the drone resets.
func reset() -> void:
	pass
