class_name Deity
extends Resource
# One of the Four (docs/DEITIES.md, Epic 30), as data. Not a character: no
# status, portrait, look, babble, edge or perk, and nothing about them is saved
# beyond vows kept. Never at risk, playable, sold or earned (the guard test in
# tests/test_the_four.gd).

@export var id: StringName
@export var name := ""
## Their principle in one plain line, original, never a quotation.
@export var principle := ""
## The symbols DeitySymbol draws (Story 30.2), e.g. lotus.
@export var symbols: Array[StringName] = []
@export var colour := Color.WHITE
## A second colour where the design names two (Shiva, Krishna); else colour.
@export var accent := Color.WHITE
## The id of their stem in the Four's score (MOTIF_SCORE, Story 30.2), e.g.
## motif_brahma.
@export var motif: StringName
## The act whose thread they lead (1 to 5). Krishna's is 5, though he rides
## through every act.
@export_range(1, 5) var thread_act := 1

## The score that holds the Four's motifs, written by tools/music/generate.py.
const MOTIF_SCORE := "res://data/music/four.tres"

## Their motif's stem, or null if it is missing.
func motif_stem() -> Stem:
	var sc: Score = load(MOTIF_SCORE)
	return sc.find(motif) if sc and motif != &"" else null
