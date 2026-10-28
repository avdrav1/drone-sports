class_name Suggestion
extends Resource
# Something to try in free flight (Story 17.10): a line the companion says and
# where it points, either the nearest MapMarker of a kind (a rooftop pad, the
# jammer) or a named landmark on the map (the plaza, downtown).

@export_multiline var text := ""
## One of CharacterPortrait.EXPRESSIONS.
@export var face: StringName = &"happy"
## The nearest visible MapMarker of this kind is the target. Empty to use `landmark`.
@export var kind: StringName
## A key of the map's landmarks, used when `kind` is empty.
@export var landmark := ""
## Metres from the target that count as reaching it.
@export var reach := 15.0
