class_name Character
extends Resource
# One cast member, as data (CLAUDE.md rule 6). Status lives in the save, via Roster.

## What their death changes; the systems that care read this (Story 7.6).
const CONSEQUENCES: Array[StringName] = [&"", &"no_spotter", &"shop_closed", &"salvage_locked", &"city_locked"]
## The formant voice's vowel syllables (tools/music/instruments.py VOWELS).
const VOWELS: PackedStringArray = ["ah", "oo", "ee", "mm"]
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
## Pitch of the chirp under their barks (Story 14.8): 1 is the sample as made,
## higher for a smaller, quicker voice. No voice acting; this is their voice.
## A ratio from the key's scale (Story 18.6), so their chirps stay in key.
@export_range(0.5, 2.0) var chirp_pitch := 1.0
## Their babble (Story 18.8): the gibberish voice that runs while their line
## types out, baked by tools/sfx/generate.py into babble_<id>.wav from these
## three. `babble_pitch` is a ratio from the key's scale on the tonic an octave
## up (higher is a smaller voice), `babble_rate` is syllables per second, and
## `babble_vowels` are the formant voice's vowel syllables they use, never words.
@export_range(0.5, 2.0) var babble_pitch := 1.0
@export_range(3.0, 14.0) var babble_rate := 8.0
@export var babble_vowels: PackedStringArray = ["ah", "ee"]
## Their face's idle bob (Story 18.2): x is bobs per second, y the phase as a
## fraction of a bob, so the crew never bob in unison.
@export var bounce := Vector2(0.7, 0.0)
## Events this character speaks on even when not in the field, e.g. gate_passed
## for the spotter. Crew in the field speak on every event.
@export var speaks_on: Array[StringName] = []
## Their names for you (Story 18.4), e.g. "ace" or "buddy": a line's {you}
## becomes one of these. Lower case, since it sits mid-sentence.
@export var calls_you: PackedStringArray = []
@export var death_consequence: StringName
## False for anyone never in the field: the player's own pilot, Coach Rin.
@export var can_be_harmed := true
## E.g. pilot (a selectable avatar).
@export var tags: Array[StringName] = []
## Their voice in the score (Story 16.10): the id of a stem in the act scores
## from the tryout on, e.g. motif_bea. The MusicDirector plays it only while
## they are active, quieter while injured, never again once dead. Empty for
## anyone who is not crew.
@export var motif: StringName
## A pilot avatar's edge (Story 19.1): stat steps and assist settings, applied
## to the player's drone by Garage.apply. None for the crew.
@export var edge: PilotEdge
## How they fly a fleet drone under autopilot (Story 18.11). Only for crew
## tagged can_fly; null flies the plain route.
@export var flight_style: FlightStyle

## The sound event of their babble loop in the bank.
func babble_event() -> StringName:
	return StringName("babble_%s" % id)

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
	if calls_you.is_empty():
		out.append("%s: needs at least one name in calls_you" % id)
	if chirp_pitch < 0.5 or chirp_pitch > 2.0:
		out.append("%s: chirp_pitch must be 0.5 to 2" % id)
	if babble_pitch < 0.5 or babble_pitch > 2.0 or babble_rate < 3.0 or babble_rate > 14.0:
		out.append("%s: babble needs a pitch of 0.5 to 2 and 3 to 14 syllables a second" % id)
	if babble_vowels.is_empty() or Array(babble_vowels).any(func(v): return not v in VOWELS):
		out.append("%s: babble_vowels must be some of %s" % [id, VOWELS])
	if bounce.x < 0.3 or bounce.x > 2.0 or bounce.y < 0.0 or bounce.y >= 1.0:
		out.append("%s: bounce needs 0.3 to 2 bobs a second and a phase in [0, 1)" % id)
	if not death_consequence in CONSEQUENCES:
		out.append("%s: unknown consequence %s" % [id, death_consequence])
	if motif != &"" and not can_be_harmed:
		out.append("%s: only crew have a motif" % id)
	if edge:
		for e in edge.validate():
			out.append("%s: %s" % [id, e])
	return out
