class_name DeitySymbolArt
extends Resource
# How DeitySymbol draws the Four's symbols (Story 30.2), as data
# (data/deities/symbol_art.tres): line weights, counts, and where each symbol
# sits on the disc. The shapes are original, built from simple curves; they
# trace no temple art, poster or game.

## The light ink on a dark field.
@export var ivory := Color(0.97, 0.94, 0.86)
## The border ring's width, as a fraction of the disc's radius.
@export var ring := 0.06
## A stroke's width, as a fraction of the disc's radius, and never thinner
## than min_line pixels.
@export var line := 0.05
@export var min_line := 1.0
## Below this size (px) the fine details (barbs, holes, whorls) are left out
## and only the symbols in `small` are drawn, where it places them.
@export var detail_below := 48.0
@export var petals := 5
@export var vedas := 4
@export var spokes := 8
@export var teeth := 16
@export var flute_holes := 6
## Symbol -> Vector4(x, y, scale, degrees): its centre on the unit disc, its
## size (1 fills the disc) and its turn.
@export var placements: Dictionary = {}
## The same, below detail_below: one symbol per god, larger, so it still reads.
@export var small: Dictionary = {}
## Symbols in the order they are drawn, back to front.
@export var order: Array[StringName] = []
