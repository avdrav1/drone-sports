class_name SuggestionList
extends Resource
# Free-flight suggestions (Story 17.10), and the crew who ride along in free
# flight, in order of preference: the first living one is the companion.

@export var companions: Array[StringName] = []
@export var suggestions: Array[Suggestion] = []
