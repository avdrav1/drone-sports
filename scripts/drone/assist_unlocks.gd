class_name AssistUnlocks
extends Resource
# Each assist in plain words and what removing it unlocks (the assist table in
# CLAUDE.md), as data for the shedding (Story 30.4). Words only: which assists
# are on stays with the act presets (AssistStack).

## Assist id (one of AssistStack.IDS) -> its name mid-sentence, e.g. "collision guard".
@export var names: Dictionary[StringName, String] = {}
## Assist id -> what flying without it opens, e.g. "tight gaps and interior flying".
@export var unlocks: Dictionary[StringName, String] = {}
