class_name Character
extends Resource
# One cast member, as data (CLAUDE.md rule 6). Status lives in the save, via Roster.

## What their death changes; the systems that care read this (Story 7.6).
const CONSEQUENCES: Array[StringName] = [&"", &"no_spotter", &"shop_closed", &"salvage_locked", &"city_locked"]
const SHAPES: Array[StringName] = [&"round", &"antenna", &"square", &"hardhat", &"ears", &"tall", &"tuft", &"visor", &"fin"]

@export var id: StringName
@export var name := ""
@export var role := ""
## Optional art. Without it the portrait is drawn from `shape` and `colors`.
@export var portrait: Texture2D
## Placeholder silhouette, one of SHAPES.
@export var shape: StringName = &"round"
## Two or three colors: body, accent, optional detail.
@export var colors: PackedColorArray = []
## Bark lines (Story 7.3): event -> {"active": [...], "injured": [...]}.
@export_file("*.json") var lines := ""
## Events this character speaks on even when not in the field, e.g. gate_passed
## for the spotter. Crew in the field speak on every event.
@export var speaks_on: Array[StringName] = []
@export var death_consequence: StringName
## False for anyone never in the field: the player's own pilot, Coach Rin.
@export var can_be_harmed := true
## E.g. pilot (a selectable avatar).
@export var tags: Array[StringName] = []
## A pilot avatar's one small stat tweak, applied once like a shop level
## (Story 7.2). None for the crew, and for Pip, the baseline.
@export var tweak: Upgrade

## Problems with this resource; empty when it is valid.
func validate() -> Array[String]:
	var out: Array[String] = []
	if id == &"":
		out.append("no id")
	if name.is_empty() or role.is_empty():
		out.append("%s: needs a name and a role" % id)
	if colors.size() < 2 or colors.size() > 3:
		out.append("%s: needs two or three colors" % id)
	if not shape in SHAPES:
		out.append("%s: unknown shape %s" % [id, shape])
	if lines != "res://data/dialogue/%s.json" % id:
		out.append("%s: lines should be data/dialogue/%s.json" % [id, id])
	if not death_consequence in CONSEQUENCES:
		out.append("%s: unknown consequence %s" % [id, death_consequence])
	if tweak and (not tweak.stat in Upgrade.STATS or tweak.step == 0.0):
		out.append("%s: tweak must change one of %s" % [id, Upgrade.STATS])
	return out
